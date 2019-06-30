module JSCall

import AssetRegistry, Sockets
using UUIDs, Hyperscript, Hyperscript, JSON, Observables
import Sockets: send
using Hyperscript: Node, children, tag
using HTTP
using HTTP: Response, Request
using HTTP.Streams: Stream
using HTTP.WebSockets: WebSocket
using Base64

include("types.jl")
include("js_source.jl")
include("session.jl")
include("observables.jl")
include("dependencies.jl")
include("http.jl")
include("util.jl")
include("widgets.jl")
include("hyperscript_integration.jl")


const global_application = Ref{Application}()

const plotpane_pages = Dict{String, Any}()

function atom_dom_handler(session::Session, request::Request)
    target = request.target[2:end]
    if haskey(plotpane_pages, target)
        return plotpane_pages[target]
    else
        return  "Can't find page"
    end
end

function Base.show(io::IO, m::MIME"application/prs.juno.plotpane+html", dom::Node)
    if !isassigned(global_application)
        global_application[] = Application(
            atom_dom_handler,
            get(ENV, "WEBIO_SERVER_HOST_URL", "127.0.0.1"),
            parse(Int, get(ENV, "WEBIO_HTTP_PORT", "8081")),
            verbose = true
        )
    end
    application = global_application[]
    sessionid = string(uuid4())
    session = Session(Ref{WebSocket}())
    application.sessions[sessionid] = session
    plotpane_pages[sessionid] = dom
    print(io, "<iframe src=\"http://localhost:8081/$(sessionid)\" frameBorder=\"0\" width=\"100%\" height=\"100%\"></iframe>")
end


end # module
