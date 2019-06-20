using Sockets
import AssetRegistry
using WebSockets, UUIDs, Hyperscript, Hyperscript, JSON, Observables
using WebSockets: is_upgrade, upgrade, writeguarded
using WebSockets: HTTP, ServerWS

@tags div input font
@tags_noescape style script

include("js_source.jl")
include("http.jl")
include("util.jl")
include("widgets.jl")

"""
Function used to interpolate into dom/javascript
"""
tojsstring(x) = sprint(io-> tojsstring(io, x))
tojsstring(io::IO, x) = JSON.print(io, x)
tojsstring(io::IO, x::JSSource) = print(io, x.source)
tojsstring(io::IO, x::Observable) = print(io, "'", x.id, "'")
function tojsstring(io::IO, jss::JSString)
    for elem in jss.source
        tojsstring(io, elem)
    end
end

const mime_order = MIME.((
    "text/html", "text/latex", "image/svg+xml", "image/png",
    "image/jpeg", "text/markdown", "application/javascript", "text/plain"
))

function richest_mime(val)
    for mimetype in mime_order
        showable(mimetype, val) && return mimetype
    end
    error("value not writable for any mimetypes")
end
repr_richest(x) = repr(richest_mime(x), x)
"""
    jsrender([::Session], x::Any)
Internal render method to create a valid dom. Registers used observables with a session
And makes sure the dom only contains valid elements. Overload jsrender(::YourType)
To enable putting YourType into a dom element/div.
You can also overload it to take a session as first argument, to register
messages with the current web session (e.g. via onjs).
"""
jsrender(x::Any) = div(repr(richest_mime(x), x))
# jsrender(session, x) will be called anywhere...
# if there is nothing sessions specific in the dom, fallback to jsrender without session
jsrender(::Session, x::Any) = jsrender(x)

function jsrender(session::Session, obs::Observable)
    onjs(session, obs, js"""
        function (html){
            var dom = document.getElementById($(obs.id))
            dom.innerHTML = html
        }
    """)
    return div(id = obs.id, string(obs[]))
end

# default turn attributes into strings
attribute_render(session, parent_id, attribute, x) = string(x)
function attribute_render(session, parent_id, attribute, obs::Observable)
    onjs(session, obs, js"""
    function (value){
        var node = document.querySelector('[data-jscall-id=$parent_id]')
        if(node[$attribute] != value){
            node[$attribute] = value
        }
    }
    """)
    return attribute_render(session, parent_id, attribute, obs[])
end

function attribute_render(session, parent_id, attribute, jss::JSString)
    add_observables!(session, jss)
    return tojsstring(jss)
end


function jsrender(session::Session, node::Hyperscript.Node)
    newchildren = map(Hyperscript.children(node)) do elem
        jsrender(session, elem)
    end
    node_id = string(uuid4())
    node_attributes = Hyperscript.attrs(node)
    new_attributes = Dict{String, Any}(map(collect(keys(node_attributes))) do k
        k => attribute_render(session, node_id, k, node_attributes[k])
    end)
    new_attributes["data-jscall-id"] = node_id
    return Hyperscript.Node(
        Hyperscript.context(node),
        Hyperscript.tag(node),
        newchildren,
        new_attributes
    )
end


function update_dom!(session::Session, dom)
    dom = jsrender(session, dom)
    add_observables!(session, dom)
    for (n, obs) in session.observables
        register_obs!(session, obs)
    end
    innerhtml = repr(MIME"text/html"(), dom)
    update_script = js"""
    var dom = document.getElementById('application-dom')
    dom.innerHTML = $(innerhtml)
    """
    evaljs(session, update_script)
end

function jsrender(session::Session, x::Hyperscript.Node)
    add_observables!(session, x)
    return x
end
Base.show(io::IO, m::MIME"text/html", jss::JSString) = tojsstring(io, jss)

app = Application(
    "127.0.0.1", 8081,
    verbose = true,
    dom = "hi"
)

id, session = last(collect(filter(app.sessions) do (k, v)
    isopen(v) # leave not yet started connections
end))
# open browser, go to http://127.0.0.1:8081/

# Test if connection is working:
evaljs(session, js"alert('hi')")
# display a widget
w1 = Widget(1:100)
w2 = Widget(1:100)
linkjs(session, w1.value, w2.value)
update_dom!(session, div(w1, w1.value, w2, w2.value))

# you can now also update attributes dynamically inplace
w1.range[] = 10:20

# Or insert observables as attributes and change them dynamically
color = Observable("red")
update_dom!(session, font(color = color, "spicy"))
color[] = "green"
