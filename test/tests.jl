using WebSockets, JSCall, Observables
using JSCall, Hyperscript, Observables
using JSCall: Application, Session, evaljs, linkjs, update_dom!, div, active_sessions
using JSCall: @js_str, font, onjs, Button, TextField, Slider, JSString, Dependency, with_session
using Test

@testset "register resources" begin
   session = Session()
   obs1 = Observable(1)
   obs2 = Observable(2.0)
   obs3 = Observable("3.0")
   func = js"$obs2"
   func2 = js"$func $obs3"
   JSCall.register_resource!(session, (obs1, func2))
   @test all(x-> x in keys(session.observables), (obs1.id, obs2.id, obs3.id))
end


@testset "queuing messages" begin
   session = Session()
   obs = Observable(1)
   onjs(session, obs, js"(x)=> console.log(x)")
   msg = session.message_queue[1]
   @test obs.id in keys(session.observables)
   @test msg[:id] == obs.id
   @test msg[:payload] == "((x)=> console.log(x))"
   @test msg[:type] == JSCall.OnjsCallback
   script = JSCall.queued_as_script(session)
   @test script == """<script>process_message({"payload":"((x)=> console.log(x))","id":"$(obs.id)","type":"1"})</script>"""
   @test isempty(session.message_queue)
end


@testset "queuing messages" begin
   session = Session()
   a = Observable(1)
   b = Observable(1)
   linkjs(session, a, b)
   msg = session.message_queue[1]
   @test a.id in keys(session.observables)
   @test b.id in keys(session.observables)
   @test msg[:id] == a.id
   @test msg[:payload] == """(function (value){
       // update_obs will return false once b is gone,
       // so this will automatically deregister the link!
       return update_obs('$(b.id)', value)
   }
   )"""
   @test msg[:type] == JSCall.OnjsCallback
   script = JSCall.queued_as_script(session)
   @test script == """<script>process_message({"payload":"(function (value){\\n    // update_obs will return false once b is gone,\\n    // so this will automatically deregister the link!\\n    return update_obs('$(b.id)', value)\\n}\\n)","id":"$(a.id)","type":"1"})</script>"""
end

@testset "jsrender" begin
   session = Session()
   s1 = Slider(1:100)
   s2 = Slider(1:100)
   b = Button("hi")
   t = TextField("lol")
   linkjs(session, s1.value, s2.value)
   onjs(session, s1.value, js"(v)=> console.log(v)")
   dom = JSCall.div(s1, s2, b, t)
end
