using Hyperscript
using JSCall, Hyperscript, Observables
using JSCall: Application, Session, evaljs, linkjs, update_dom!, div, active_sessions
using JSCall: @js_str, font, onjs, Button, TextField, Slider, JSString, Dependency, with_session

const THREE = JSCall.Dependency(
    :THREE,
    [
        "https://cdn.jsdelivr.net/gh/mrdoob/three.js/build/three.min.js",
    ]
)

struct ThreeScene
end

function JSCall.jsrender(session::Session, ::ThreeScene)
    dom = div(width = 500, height = 500)
    JSCall.onload(session, dom, js"""
        function three_div(container){
            console.log(container)
            var scene = new $(THREE).Scene()
            var width = 500
            var height = 500
            // Create a basic perspective camera
            var camera = new $(THREE).PerspectiveCamera(75, width / height, 0.1, 1000)
            camera.position.z = 4
            var renderer = new $(THREE).WebGLRenderer({antialias: true})
            renderer.setSize(width, height)
            renderer.setClearColor("#ffffff")
            var geometry = new $(THREE).BoxGeometry(1.0, 1.0, 1.0)
            var material = new $(THREE).MeshBasicMaterial({color: "#433F81"})
            var cube = new $(THREE).Mesh(geometry, material);
            scene.add(cube)
            container.appendChild(renderer.domElement);
            // var controls = new $THREE.OrbitControls(camera, renderer.domElement);
            // controls.addEventListener( 'change', render );
            renderer.render(scene, camera)
        }
    """)
    return dom
end


using JSCall, Observables
using JSCall: Dependency, div, @js_str, font, onjs, Button, TextField, Slider, JSString, with_session, linkjs

function dom_handler(session, request)
    global s_value
    s1 = Slider(1:100)
    s2 = Slider(1:100)
    b = Button("hi")
    t = TextField("lol")
    s_value = s1.value
    linkjs(session, s1.value, s2.value)
    onjs(session, s1.value, js"(v)=> console.log(v)")
    on(t) do text
        println(text)
    end
    return JSCall.div(s1, s2, b, t)
end
# id, session = last(active_sessions(app))

app = JSCall.Application(
    dom_handler,
    get(ENV, "WEBIO_SERVER_HOST_URL", "127.0.0.1"),
    parse(Int, get(ENV, "WEBIO_HTTP_PORT", "8081")),
    verbose = false
)

d = with_session() do session
    s1 = Slider(1:100)
    s2 = Slider(1:100)
    b = Button("hi")
    t = TextField("lol")
    linkjs(session, s1.value, s2.value)
    onjs(session, s1.value, js"(v)=> console.log(v)")
    on(t) do text
        println(text)
    end
    return JSCall.div(s1, s2, b, t)
end
