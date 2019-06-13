using Sockets
import AssetRegistry
using WebSockets
using WebSockets: is_upgrade, upgrade, writeguarded
using WebSockets: HTTP, ServerWS
using Hyperscript
using Observables
x = Observable(1)

@tags div
@tags_noescape style script

struct Session
    connection::WebSocket
    observables::Dict{String, Observable}
end
Session(connection) = Session(connection, Dict{String, Observable}())

struct Application
    url::String
    port::Int
    dependencies::Vector{String}
    sessions::Vector{Session}
    websocket_route::String
    websocket_url::String
    server::Ref{ServerWS}
    server_task::Ref{Task}
    http_handler::Ref{Function}
    ws_handler::Ref{Function}
    dom::Ref{Any}
end

function handler(application, request)
    # response = default_response(request)
    # response !== missing && return response
    # return serve_assets(request)
    return sprint(io-> show(io, MIME"text/html"(), application.dom[]))
end

function wshandler(application, request, websocket)
    if request.target == application.websocket_route
        session = Session(websocket)
        push!(application.sessions, session)
        while isopen(websocket)
            try
                json = WebSockets.read(websocket)
                data = JSON.parse(String(json))
                @show data
                if data["type"] == "obs"
                    obs = session.observables[data["id"]]
                    obs[] = data["payload"]
                end
            catch e
                @show e
            end
        end
    end
end

function js_source(websocket_url)
    src = read(joinpath(@__DIR__, "core.js"), String)
    script(replace(src, "__websock_url__" => repr(websocket_url)))
end

function Application(
        url::String, port::Int;
        dependencies = String[],
        websocket_route = "/webio_websocket/",
        websocket_url = string("ws://", url, ":", port, websocket_route),
        verbose = false,
        dom = nothing
    )
    websocket_script = js_source(websocket_url)
    my_app = div(websocket_script, dom)
    application = Application(
        url, port, dependencies, Session[], websocket_route, websocket_url,
        Ref{ServerWS}(), Ref{Task}(),
        Ref{Function}(handler), Ref{Function}(wshandler),
        Ref{Any}(my_app),
    )
    function inner_handler(request)
        application.http_handler[](application, request)
    end
    function inner_wshandler(request, websocket)
        application.ws_handler[](application, request, websocket)
    end

    application.server[] = WebSockets.ServerWS(inner_handler, inner_wshandler)
    application.server_task[] = @async WebSockets.serve(application.server[], url, port, verbose)
    return application
end
using JSON
function Sockets.send(x::Session; kw...)
    write(x.connection, JSON.json(kw))
end
function register_obs!(session::Session, obs::Observable)
    send(session, type = "obs", id = obs.id, payload = obs[])
    session.observables[obs.id] = obs
    return
end

app = Application(
    "127.0.0.1", 8081,
    verbose = true,
    dom = "hi"
)

send(app.sessions[1], type = "eval", payload = "console.log('hi')")
obs = Observable(1)
register_obs!(app.sessions[1], obs)

send(app.sessions[1], type = "eval", payload = "console.log(get_observable($(repr(obs.id))))")

send(app.sessions[1], type = "eval", payload = "update_obs($(repr(obs.id)), 232)")
obs[]
# open browser, go to http://127.0.0.1:8081/
# then after everything connected, talk:
# write(app.sessions[1].connection, "console.log('boi')")
const obs_used_in_js = Dict{String, Observable}()

function js_obs_get!(obs::Observable)
    obs_used_in_js[obs.id] = obs
    return string("get_observable(", repr(obs.id), ")")
end

function js_obs_get!(any)
    return JSON.json(any)
end

macro js_str(js_source)
    escape_regex = r"\$\(([\u00A0-\uFFFF\w_!´\.]*@?[\u00A0-\uFFFF\w_!´]+)\)|\$([\u00A0-\uFFFF\w_!´\.]*@?[\u00A0-\uFFFF\w_!´]+)"
    esc_symbols = map(eachmatch(escape_regex, js_source)) do x
        x[1] !== nothing ? x[1] : x[2] # find the match that matched
    end
    non_esc = split(js_source, escape_regex)
    @show esc_symbols non_esc
    result = :(string($(non_esc[1])))
    for i in 2:length(non_esc)
        push!(result.args, :(js_obs_get!($(esc(Symbol(esc_symbols[i-1]))))))
        push!(result.args, non_esc[i])
    end
    result
end


send(app.sessions[1], type = "eval", payload = js"console.log($obs)")
