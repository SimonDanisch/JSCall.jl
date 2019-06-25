using Hyperscript
using JSCall, Hyperscript, Observables
using JSCall: Application, Session, evaljs, Widget, linkjs, update_dom!, div, active_sessions
using JSCall: @js_str, font, onjs, Button, TextField

function dom_handler(session, request)
    tf = JSCall.TextField("hi")
    test_db = [
        "Batti",
        "Schorsch",
        "Simon"
    ]
    result = map(tf.value) do str
        s = filter(x-> occursin(str, x), test_db)
        if isempty(s)
            "Nothing found!"
        else
            first(s)
        end
    end
    return JSCall.div(tf, result)
end
app = Application(
    dom_handler, "127.0.0.1", 8081,
    verbose = true
)
app.sessions
id, session = last(active_sessions(app))
JSCall.send_queued(session)
# open browser, go to http://127.0.0.1:8081/
# Test if connection is working:



update_dom!(session, )
JSCall.jsrender(session, tf)
update_dom!(session, )
# display a widget
w1 = Widget(1:100)
w2 = Widget(1:100)
b = Button("Click me!")
b.content[] = "Dont click me"
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


searchfield = TextInput()
search_result = map(searchfield.onfinished) do search_string
    result = search(application.database, search_string)
    return build_search_dom(result)
end
div(searchfield, search_result)
x = Observable(1)
y = map(x) do val
    return val ^ 2
end
y[]
x[] = 22

struct Test2
    x
end
x = (2,3,4)
x = (a = 2, b = 2)
abstract type AbstractType end

struct Test3 <: AbstractType
    x::String
end
get_data(x::Test3) = x.x

struct Test5 <: AbstractType
    x::String
end
function test(x::AbstractType)
    get_data(x) * " Battie"
end

function test(x::Test3)
    x.x * " Simon"
end

Test5(x)
test(Test5("hi"))

macro test_str(input)
    tokens = split(input, ' ')
    x = :([$(tokens...)])
    println(x)
    return x
end

@macroexpand(test"hi batti")
obs = Observable(1)
using UUIDs
function JSCall.tojsstring(io::IO, dom::Node)
    print(io, "document.querySelector('[data-jscal-id=$(hash(dom))]')")
end
dom1 = div("hi")
dom2 = div("hi")

objectid(dom1)
objectid(dom2)

x = js"""
update_htm($dom, newhtml)
"""
sprint(io-> JSCall.tojsstring(io, x))
x.source

using DataFrames

x = [
    (hi = "hi", bla = "bla"),
    (hi = 22, bla = rand(10)),
    (hi = 33, bla = rand(10)),
    (bla = rand(10), hi = 222),
]

open("test.csv", "w") do io
    show(io, MIME"text/csv"(), x)
end
