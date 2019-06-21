
struct Widget{T <: AbstractRange, ET}
    id::String
    range::Observable{T}
    value::Observable{ET}
    attributes::Dict{Symbol, Any}
end

uuid(x::Widget) = x.id

function Widget(range::T, value = first(range)) where T <: AbstractRange
    Widget{T, eltype(range)}(
        string(UUIDs.uuid4()),
        Observable(range),
        Observable(value),
        Dict{Symbol, Any}()
    )
end

function jsrender(session::Session, w::Widget)
    return jsrender(session, input(
        type = "range",
        min = map(first, w.range),
        max = map(last, w.range),
        value = w.value,
        step = map(step, w.range),
        class = "slider", id = uuid(w),
        oninput = js"update_obs($(w.value), parseInt(value))"
    ))
end


struct Button{T}
    id::String
    content::Observable{T}
    onclick::Observable{Bool}
    attributes::Dict{Symbol, Any}
end
Button(content) = Button(
    string(uuid4()), Observable(content), Observable(false), Dict{Symbol, Any}()
)

function jsrender(session::Session, w::Button)
    return jsrender(session, input(
        type = "button",
        value = w.content,
        id = w.id,
        onclick = js"update_obs($(w.onclick), true)";
        w.attributes...
    ))
end
