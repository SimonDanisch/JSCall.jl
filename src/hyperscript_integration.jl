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

render_node(session::Session, x) = x

function render_node(session::Session, node::Node)
    # give each node a unique id inside the dom
    node_id = string(uuid4())
    new_attributes = Dict{String, Any}(
        "data-jscall-id" => node_id
    )
    newchildren = map(children(node)) do elem
        childnode = jsrender(session, elem)
        # if a transform elem::Any -> ::Node happens, we need to
        # render the resulting node again, since the attr/children won't be
        # lowered yet!
        if !(elem isa Node)
            childnode = render_node(session, childnode)
        end
        return childnode
    end
    for (k, v) in Hyperscript.attrs(node)
        new_attributes[k] = attribute_render(session, node_id, k, v)
    end
    return Node(
        Hyperscript.context(node),
        Hyperscript.tag(node),
        newchildren,
        new_attributes
    )
end

function jsrender(session::Session, node::Node)
    render_node(session, node)
end
