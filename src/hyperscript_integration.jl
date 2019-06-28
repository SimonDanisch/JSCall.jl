@tags div input font
@tags_noescape style script

# default turn attributes into strings
attribute_render(session, parent, attribute, x) = string(x)
function attribute_render(session, parent, attribute, obs::Observable)
    onjs(session, obs, js"""
    function (value){
        var node = $(parent)
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
    return attribute_render(session, parent, attribute, obs[])
end

function attribute_render(session, parent, attribute, jss::JSString)
    return tojsstring(jss)
end

render_node(session::Session, x) = x

function render_node(session::Session, node::Node)
    # give each node a unique id inside the dom
    node_id = string(uuid4())
    # pretty hacky, but this is the only way I can think of right now
    # to make sure that we always have a unique id for a node
    get!(Hyperscript.attrs(node), "data-jscall-id", node_id)
    new_attributes = Dict{String, Any}()
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

function uuid(node::Node)
    get(Hyperscript.attrs(node), "data-jscall-id") do
        error("Node $(node) doesn't have a unique id. Call jsrender(session, node) first!")
    end
end

# Handle interpolating into Javascript
function tojsstring(io::IO, node::Node)
    # This relies on jsrender to give each node a unique id under the
    # attribute data-jscall-id. This is a bit brittle
    # improving this would be nice
    print(io, "(document.querySelector('[data-jscall-id=$(repr(uuid(node)))]'))")
end
