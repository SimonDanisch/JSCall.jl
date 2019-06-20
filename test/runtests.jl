using JSCall, Hyperscript, Observables
using JSCall: Application, Session, evaljs, Widget, linkjs, update_dom!, div, active_sessions
using JSCall: @js_str, font


app = Application(
    "127.0.0.1", 8081,
    verbose = true,
    dom = "hi"
)

id, session = last(active_sessions(app))
# open browser, go to http://127.0.0.1:8081/

# Test if connection is working:
evaljs(session, js"alert('hi')")
# display a widget
w1 = Widget(1:100)
w2 = Widget(1:100)
linkjs(session, w1.value, w2.value)
update_dom!(session, div(w1, w1.value, w2, w2.value))

# you can now also update attributes dynamically inplace
w1.range[] = 10:20

# Or insert observables as attributes and change them dynamically
color = Observable("red")
update_dom!(session, font(color = color, "spicy"))
color[] = "green"
