using WebSockets: check_upgrade, WebSocket, is_upgrade, generate_websocket_key
import HTTP:Response,   # For upgrade
            Request,    # For upgrade, target, origin, subprotocol
            Header,     # benchmarks, client_test, handshaketest
            header,     # For upgrade, subprotocol
            hasheader,  # For upgrade and check_upggrade
            setheader,  # For upgrade
            setstatus,  # For upgrade
            startwrite, # For upgrade
            startread  # For _openstream
import HTTP.ConnectionPool: getrawstream                    # For _openstream
import HTTP.Streams: Stream                          # For is_upgrade, handshaketest
using Base64
# Save some bytes by using ints for switch variable
const UpdateObservable = "0"
const OnjsCallback = "1"
const EvalJavascript = "2"
const JavascriptError = "3"
const JavascriptWarning = "4"

"""
A web session with a user
"""
struct Session
    connection::Ref{WebSocket}
    observables::Dict{String, Tuple{Bool, Observable}} # Bool -> if already registered with Frontend
end
Session(connection) = Session(connection, Dict{String, Tuple{Bool, Observable}}())

"""
Send values to the frontend via JSON for now
"""
function Sockets.send(x::Session; kw...)
    write(x.connection[], JSON.json(kw))
end
Base.isopen(x::Session) = isassigned(x.connection) && isopen(x.connection[])

struct Application
    url::String
    port::Int
    dependencies::Vector{String}
    sessions::Dict{String, Session}
    websocket_url::String
    server_task::Ref{Task}
    dom::Ref{Any}
end

include("websockets.jl")


"""
Functor to update JS part when an observable changes.
We make this a Functor, so we can clearly identify it and don't sent
any updates, if the JS side requires to update an Observable
(so we don't get an endless update cycle)
"""
struct JSUpdateObservable
    session::Session
    id::String
end

function (x::JSUpdateObservable)(value)
    # Sent an update event
    send(x.session, payload = value, id = x.id, type = UpdateObservable)
end

"""
Update the value of an observable, without sending changes to the JS frontend.
This will be used to update updates from the forntend.
"""
function update_nocycle!(obs::Observable, value)
    setindex!(
        obs, value,
        notify = (f-> !(f isa JSUpdateObservable))
    )
end

"""
Registers an Observable with a Javascript session,
so that it updates the values on the JS side accordingly,
and in turn can be updated from JS
"""
function register_obs!(session::Session, obs::Observable)
    registered = false
    if haskey(session.observables, obs.id)
        registered, _  = session.observables[obs.id]
    else
        session.observables[obs.id] = (true, obs)
    end
    if !registered
        # Register on the JS side by sending the current value
        send(session, type = UpdateObservable, id = obs.id, payload = obs[])
        updater = JSUpdateObservable(session, obs.id)
        # Make sure we update the Javascript values!
        on(updater, obs)
    end
    return
end

function stream_handler(application::Application, stream::Stream)
    try
        if is_upgrade(stream.message)
            upgrade_websocket(application, stream)
        else
            f = HTTP.Handlers.RequestHandlerFunction() do req
                http_handler(application, req)
            end
            HTTP.handle(f, stream)
        end
    catch err
        @error "error in upgrade" exception=err
    end
end


function http_handler(application::Application, request::Request)
    try
        sessionid = string(uuid4())
        session = Session(Ref{WebSocket}())
        application.sessions[sessionid] = session
        return string(
            """
            <!doctype html>
            <html>
            <head>
            <meta charset="UTF-8">
            """,
            "<script>\n",
            js_source(application.websocket_url, sessionid),
            "</script>\n",
            """
            <meta name="viewport" content="width=device-width, initial-scale=1">
            </head>
            <body>
            """,
            "<div id='application-dom'>\n",
            repr(MIME"text/html"(), jsrender(session, application.dom[])),
            "\n</div>\n",
            "<script>setup_connection()</script>\n",
            "</body>\n</html>\n"
        )
    catch e
        @warn "error in handler" exception=e
        return "error :(\n$e"
    end
end


function websocket_handler(application, request, websocket)
    if length(request.target) > 2 # for /id/
        sessionid = request.target[2:end-1] # remove the '/' id '/'
        # Look up the connection in our sessions
        if haskey(application.sessions, sessionid)
            session = application.sessions[sessionid]
            # Close already open connections
            # TODO, actually, if the connection is open, we should
            # just not allow a new connection!? Need to figure out if that would
            # be less reliable...Definitely sounds more secure to not allow a new conenction
            if isassigned(session.connection) && isopen(session.connection[])
                close(session.connection[])
            end
            session.connection[] = websocket
            if isopen(websocket)
                # Register all Observables that got put in our session
                # via e.g. display/jsrender
                for (id, obs) in session.observables
                    register_obs!(session, obs)
                end
            else
                @error "Websocket not open, can't register observables"
            end
            while isopen(websocket)
                try
                    json = String(WebSockets.read(websocket))
                    data = JSON.parse(json)
                    typ = data["type"]
                    if data["type"] == UpdateObservable
                        reg, obs = session.observables[data["id"]]
                        # Make sure we don't notify our JS updater, since
                        # otherwise we would get into a an endless cycle
                        Base.invokelatest(update_nocycle!, obs, data["payload"])
                    elseif data["type"] == JavascriptError
                        @error "Error in Javascript: $(data["message"])\n with exception:\n$(data["exception"])"
                    else
                        @error "Unrecognized message: $(typ) with type: $(typeof(type))"
                    end
                catch e
                    if e isa WebSockets.WebSocketClosedError
                        delete!(application.sessions, sessionid)
                    else
                        @error "Websocket error:" exception = e
                    end
                end
            end
        end
    end
    @warn "Unrecognized Websocket route: $(request.target)"
end


function Application(
        url::String, port::Int;
        dependencies = String[],
        websocket_url = string("ws://", url, ":", port),
        verbose = false,
        dom = nothing
    )
    application = Application(
        url, port, dependencies, Dict{String, Session}(), websocket_url,
        Ref{Task}(), Ref{Any}(dom),
    )
    application.server_task[] = @async HTTP.listen(url, port, verbose = verbose) do stream::Stream
        Base.invokelatest(stream_handler, application, stream)
    end
    return application
end


"""
    onjs(session::Session, obs::Observable, func::JSString)

Register a javascript function with `session`, that get's called when `obs` gets a new value.
If the observable gets updated from the JS side, the calling of `func` will be triggered
entirely in javascript, without any communication with the Julia `session`.
"""
function onjs(session::Session, obs::Observable, func::JSString)
    # register the callback with the JS session
    register_obs!(session, obs)
    # TODO
    # Does this need to be recursive? I don't think it does,
    # since source should just be a flat list
    for o in func.source
        o isa Observable || continue
        register_obs!(session, o)
    end
    send(
        session,
        type = OnjsCallback,
        id = obs.id,
        # eval requires functions to be wrapped in ()
        payload = "(" * tojsstring(func) * ")"
    )
end

"""
    linkjs(session::Session, a::Observable, b::Observable)

for an open session, link a and b on the javascript side. This will also
Link the observables in Julia, but only as long as the session is active.
"""
function linkjs(session::Session, a::Observable, b::Observable)
    # register the callback with the JS session
    onjs(
        session,
        a,
        js"""
        function (value){
            // update_obs will return false once b is gone,
            // so this will automatically deregister the link!
            return update_obs($b, value)
        }
        """
    )
end

"""
    evaljs(session::Session, jss::JSString)

Evaluate a javascript script in `session`.
"""
function evaljs(session::Session, jss::JSString)
    add_observables!(session, jss)
    jssss = tojsstring(jss)
    send(session, type = EvalJavascript, payload = jssss)
end

function js_source(websocket_url, sessionid)
    src = read(joinpath(@__DIR__, "core.js"), String)
    return replace(
        src,
        "__session_id__" => repr(sessionid)
    )
end

function active_sessions(app::Application)
    collect(filter(app.sessions) do (k, v)
        isopen(v) # leave not yet started connections
    end)
end
