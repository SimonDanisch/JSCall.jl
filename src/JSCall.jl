module JSCall

import AssetRegistry, Sockets
using WebSockets, UUIDs, Hyperscript, Hyperscript, JSON, Observables
using WebSockets: is_upgrade, upgrade, writeguarded
using WebSockets: HTTP, ServerWS
import Sockets: send
using Hyperscript: Node, children, tag

include("js_source.jl")
include("http.jl")
include("util.jl")
include("widgets.jl")
include("hyperscript_integration.jl")
include("core.jl")

end # module
