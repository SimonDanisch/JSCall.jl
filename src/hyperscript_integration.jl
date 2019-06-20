@tags div input font
@tags_noescape style script

# default turn attributes into strings
attribute_render(session, parent_id, attribute, x) = string(x)
function attribute_render(session, parent_id, attribute, obs::Observable)
    onjs(session, obs, js"""
    function (value){
        var node = document.querySelector('[data-jscall-id=$parent_id]')
        if(node){
            if(node[$attribute] != value){
                node[$attribute] = value
            }
            return true
        }else{
            return false //deregister
        }
    }
    """)
    return attribute_render(session, parent_id, attribute, obs[])
end

function attribute_render(session, parent_id, attribute, jss::JSString)
    add_observables!(session, jss)
    return tojsstring(jss)
end


function jsrender(session::Session, x::Hyperscript.Node)
    return x
end

function jsrender(session::Session, node::Hyperscript.Node)
    # give each node a unique id inside the dom
    node_id = string(uuid4())
    newchildren = map(Hyperscript.children(node)) do elem
        x = jsrender(session, elem)
        add_observables!(session, x)
        return x
    end

    node_attributes = Hyperscript.attrs(node)
    new_attributes = Dict{String, Any}(map(collect(keys(node_attributes))) do k
        k => attribute_render(session, node_id, k, node_attributes[k])
    end)
    get!(new_attributes, "data-jscall-id", node_id)
    return Hyperscript.Node(
        Hyperscript.context(node),
        Hyperscript.tag(node),
        newchildren,
        new_attributes
    )
end
