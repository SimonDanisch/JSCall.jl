using JSCall, WebIO, JSExpr
using Test
using JSExpr: jsexpr
using JSCall
using WebIO
THREE, document = JSModule(
    :THREE,
    "https://cdnjs.cloudflare.com/ajax/libs/three.js/103/three.js",
)

scene = THREE.new.Scene()
width, height = 500, 500
# Create a basic perspective camera
camera = THREE.new.PerspectiveCamera(75, width / height, 0.1, 1000)
camera.position.z = 4
renderer = THREE.new.WebGLRenderer(Dict(:antialias => true))
renderer.setClearColor("#ffffff")
geometry = THREE.new.BoxGeometry(1, 1, 1)
material = THREE.new.MeshBasicMaterial(color = "#433F81")
cube = THREE.new.Mesh(geometry, material);
scene.add(cube)
container = document.querySelector("#container")
container.appendChild(renderer.domElement)
display((scope(THREE))(dom"div#container"()))

@jsfun function render(unused)
    @var cube = $cube
    @var renderer = $renderer
    @var scene = $scene
    @var camera = $camera
    cube.rotation.x += 0.01
    cube.rotation.y += 0.01
    renderer.render(scene, camera)
    requestAnimationFrame(render)
end

render(scene)
