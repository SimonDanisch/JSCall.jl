
"""
Function used to interpolate into dom/javascript
"""
tojsstring(x) = sprint(io-> tojsstring(io, x))
tojsstring(io::IO, x) = JSON.print(io, x)
tojsstring(io::IO, x::Observable) = print(io, "'", x.id, "'")

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
jsrender(::Session, x::Any) = jsrender(x)

jsrender(::Session, x::String) = x
jsrender(::Session, x::Hyperscript.Styled) = x

# jsrender(session, x) will be called anywhere...
# if there is nothing sessions specific in the dom, fallback to jsrender without session
function jsrender(session::Session, obs::Observable)
    html = map(obs) do value
        dom = jsrender(session, value)
        repr(MIME"text/html"(), dom)
    end
    onjs(session, html, js"""
        function (html){
            var dom = document.getElementById($(obs.id))
            if(dom){
                dom.innerHTML = html
                return true
            }else{
                //deregister the callback if the obs dom is gone
                return false
            }
        }
    """)
    return div(html[], id = obs.id)
end

function update_dom!(session::Session, dom)
    dom = jsrender(session, dom)
    register_resource!(session, dom)
    innerhtml = repr(MIME"text/html"(), dom)
    update_script = js"""
    var dom = document.getElementById('application-dom')
    dom.innerHTML = $(innerhtml)
    """
    evaljs(session, update_script)
end
