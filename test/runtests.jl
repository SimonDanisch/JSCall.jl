using JSCall, WebIO, JSExpr
using Test

THREE, document = JSModule(
    :THREE,
    "https://cdnjs.cloudflare.com/ajax/libs/three.js/103/three.js",
)
(scope(THREE))(dom"div#container"())

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
