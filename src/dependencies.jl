struct Asset
    media_type::Symbol
    # We try to always have online & local files for assets
    # If you only give an online resource, we will download it
    # to also be able to host it locally
    online_path::String
    local_path::String
    onload::Union{Nothing, JSString}
end
mediatype(asset::Asset) = asset.media_type
url(asset::Asset) = asset.online_path

"""
    Asset(path_onload::Pair{String, JSString})

Convenience constructor to make `Asset.(["path/to/asset" => js"onload"])`` work!
"""
Asset(path_onload::Pair{String, JSString}) = Asset(path_onload...)

function Asset(online_path::String, onload::Union{Nothing, JSString} = nothing)
    local_path = ""; real_online_path = ""
    if is_online(online_path)
        local_path = try
            download(online_path)
        catch e
            @warn "Download for $online_path failed" exception=e
            ""
        end
        real_online_path = online_path
    else
        loca_path = online_path
    end
    return Asset(Symbol(getextension(online_path)), real_online_path, local_path, onload)
end

"""
    getextension(path)
Get the file extension of the path.
The extension is defined to be the bit after the last dot, excluding any query
string.
# Examples
```julia-repl
julia> WebIO.getextension("foo.bar.js")
"js"
julia> WebIO.getextension("https://my-cdn.net/foo.bar.css?version=1")
"css"
```
"""
getextension(path) = lowercase(last(split(first(split(path, "?")), ".")))

"""
    islocal(path)
Determine whether or not the specified path is a local filesystem path (and not
a remote resource that is hosted on, for example, a CDN).
"""
is_online(path) = any(startswith.(path, ("//", "https://", "http://", "ftp://")))


struct Dependency
    name::Symbol
    assets::Vector{Asset}
end

function Dependency(name::Symbol, urls::AbstractVector)
    Dependency(
        name,
        Asset.(urls),
    )
end

function tojsstring(io::IO, assets::Set{Asset})
    for asset in assets
        tojsstring(io, asset)
        println(io)
    end
end
function tojsstring(io::IO, asset::Asset)
    if mediatype(asset) == :js
        println(
            io,
            "<script type=\"text/javascript\" charset=\"utf-8\" src = $(repr(url(asset)))></script>"
        )
    elseif mediatype(asset) == :css
        println(
            io,
            "<link href = $(repr(url(asset))) rel = \"stylesheet\",  type=\"text/css\">"
        )
    else
        error("Unrecognized asset media type: $(mediatype(asset))")
    end
end


function tojsstring(io::IO, dependency::Dependency)
    print(io, dependency.name)
end
