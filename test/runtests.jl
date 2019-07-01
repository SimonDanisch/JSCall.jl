using Hyperscript
using JSCall, Hyperscript, Observables
using JSCall: Application, Session, evaljs, linkjs, update_dom!, div, active_sessions
using JSCall: @js_str, font, onjs, Button, TextField, Slider, JSString, Dependency

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

div(ThreeScene())
JSCall.plotpane_pages |> first |> first
JSCall.plotpane_pages |> first




using JSCall, Observables
using JSCall: Dependency, div, @js_str, font, onjs, Button, TextField, Slider, JSString

s = Slider(1:10)
b = Button("hi")
t = TextField("lol")
on(s) do value
    println(value)
end
on(t) do text
    println(text)
end
bulma = Dependency(
    :Bulma,
    [
        "https://cdnjs.cloudflare.com/ajax/libs/bulma/0.7.5/css/bulma.min.css",
        "https://wikiki.github.io/css/documentation.css?v=201904261505"
    ]
)

JSCall.div(bulma, s, b, t)
