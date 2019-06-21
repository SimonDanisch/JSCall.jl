using JSCall, Hyperscript, Observables
using JSCall: Application, Session, evaljs, Widget, linkjs, update_dom!, div, active_sessions
using JSCall: @js_str, font, onjs, Button


app = Application(
    "127.0.0.1", 8081,
    verbose = true,
    dom = "hi"
)

id, session = last(active_sessions(app))
# open browser, go to http://127.0.0.1:8081/
# Test if connection is working:

# display a widget
w1 = Widget(1:100)
w2 = Widget(1:100)
b = Button("Click me!")
linkjs(session, w1.value, w2.value)
update_dom!(session, div(w1, font(w1.value, color = "red"), w2, w2.value, b))
on(b.onclick) do _
    println("heheeh")
end
# you can now also update attributes dynamically inplace
w1.range[] = 10:20

# Or insert observables as attributes and change them dynamically
color = Observable("red")
update_dom!(session, font(color = color, "spicy"))
color[] = "green"

using Makie

w = 3
X, Y = (-w:w:100), ((-w:w:100)')
U = -1 .- X .^ 2 .+ Y
V = 1 .+ X .- Y.^2
speed = sqrt.(U.^2 .+ V.^2)

contour(X, Y', V)
help(arrows)

using AbstractPlotting
using ImageFiltering

x = range(-2, stop = 2, length = 21)
y = x
z = x .* exp.(-x .^ 2 .- (y') .^ 2)
u, v = ImageFiltering.imgradients(z, KernelFactors.ando3)
arrows(x, y, u, v)

Y
