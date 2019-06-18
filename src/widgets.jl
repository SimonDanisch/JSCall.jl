
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

function jsrender(w::Widget)
    return input(
        type = "range",
        min = string(first(w.range[])),
        max = string(last(w.range[])),
        value = string(w.value[]),
        step = string(step(w.range[])),
        class = "slider", id = uuid(w),
        oninput = js"update_obs($(w.value), parseInt(value))"
    )
end
