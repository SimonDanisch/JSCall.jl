
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
            if(dom){
                dom.innerHTML = html
                return true
            }else{
                return false
            }
        }
    """)
    return div(id = obs.id, string(obs[]))
end

function update_dom!(session::Session, dom)
    dom = jsrender(session, dom)
    add_observables!(session, dom)
    for (n, (reg, obs)) in session.observables
        reg || register_obs!(session, obs)
    end
    innerhtml = repr(MIME"text/html"(), dom)
    update_script = js"""
    var dom = document.getElementById('application-dom')
    dom.innerHTML = $(innerhtml)
    """
    evaljs(session, update_script)
end
