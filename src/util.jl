
function only_html(io::IO, dom)
    rtcx = Hyperscript.RenderContext(true, "    ", 0, Hyperscript.NoScripts)
    Hyperscript.render(io, rtcx, dom)
end

function extract_scripts(vec::AbstractVector, result = Union{JSSource, Any}[])
    for elem in vec
        extract_scripts(elem, result)
    end
    return result
end

function extract_scripts(jss::JSSource, result = Union{JSSource, Any}[])
    append_source!(result, jss)
    return result
end

function extract_scripts(node::Hyperscript.Node, result = Union{JSSource, Any}[])
    if Hyperscript.tag(node) == "script"
        childs = Hyperscript.children(node)
        if length(childs) != 1
            error("Scripts need to have one chield only")
        end
        append_source!(result, first(childs))
        return result
    end
    for elem in Hyperscript.children(node)
        extract_scripts(elem, result)
    end
    return result
end


function add_observables!(session::Session, x::Observable, visited = IdDict())
    # If we already have a connection immediately register with frontend:
    if isopen(session)
        register_obs!(session, x)
    else
        # only add to session. Will register with fronted on websocket connect!
        session.observables[x.id] = (false, x)
    end
end

function add_observables!(session::Session, x::JSString, visited = IdDict())
    add_observables!(session, x.source, visited)
end
function add_observables!(session::Session, x, visited = IdDict())
 #nothing to do here
end
function add_observables!(session::Session, x::Union{Tuple, AbstractVector, Pair}, visited = IdDict()) where T
    get!(visited, x, nothing) !== nothing && return
    for elem in x
        add_observables!(session, elem, visited)
    end
end
function add_observables!(session::Session, x::Hyperscript.Node, visited = IdDict())
    get!(visited, x, nothing) !== nothing && return
    for elem in Hyperscript.children(x)
        add_observables!(session, elem, visited)
    end
    for (name, elem) in Hyperscript.attrs(x)
        add_observables!(session, elem, visited)
    end
end
