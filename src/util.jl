
function walk_dom(f, session::Session, x::JSString, visited = IdDict())
    walk_dom(f, session, x.source, visited)
end

walk_dom(f, session::Session, x, visited = IdDict()) = f(x)

function walk_dom(f, session::Session, x::Union{Tuple, AbstractVector, Pair}, visited = IdDict()) where T
    get!(visited, x, nothing) !== nothing && return
    for elem in x
        walk_dom(f, session, elem, visited)
    end
end
function walk_dom(f, session::Session, x::Node, visited = IdDict())
    get!(visited, x, nothing) !== nothing && return
    for elem in children(x)
        walk_dom(f, session, elem, visited)
    end
    for (name, elem) in Hyperscript.attrs(x)
        walk_dom(f, session, elem, visited)
    end
end


register_resource!(session::Session, @nospecialize(jss)) = nothing # do nothing for unknown type

function register_resource!(session::Session, list::Union{Tuple, AbstractVector, Pair})
    for elem in list
        register_resource!(session, elem)
    end
end

function register_resource!(session::Session, jss::JSString)
    register_resource!(session, jss.source)
end
function register_resource!(session::Session, asset::Union{Asset, Dependency, Observable})
    push!(session, asset)
end

function register_resource!(session::Session, node::Node)
    walk_dom(session, node) do x
        register_resource!(session, x)
    end
end
