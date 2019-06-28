using Observables

abstract type AbstractWidget{T} <: Observables.AbstractObservable{T} end

uuid_string() = string(uuid4())

# Common api  for widgets
uuid(x::AbstractWidget) = x.id
Observables.observe(x::AbstractWidget) = x.value


struct Slider{T <: AbstractRange, ET} <: AbstractWidget{T}
    id::String
    range::Observable{T}
    value::Observable{ET}
    attributes::Dict{Symbol, Any}
end

function Slider(range::T, value = first(range); kw...) where T <: AbstractRange
    Slider{T, eltype(range)}(
        uuid_string(),
        Observable(range),
        Observable(value),
        Dict{Symbol, Any}(kw)
    )
end

function jsrender(slider::Slider)
    return input(
        type = "range",
        min = map(first, slider.range),
        max = map(last, slider.range),
        value = slider.value,
        step = map(step, slider.range),
        dataJscallId = uuid(slider),
        oninput = js"update_obs($(slider.value), parseInt(value))";
        slider.attributes...
    )
end

@enum Orientation vertical horizontal


struct RangeSlider{T <: AbstractRange, ET <: AbstractArray} <: AbstractWidget{T}
    id::String
    range::Observable{T}
    value::Observable{ET}
    attributes::Dict{Symbol, Any}
    connect::Observable{Bool}
    orientation::Observable{Orientation}
end

function RangeSlider(range::T; value = [first(range)], kw...) where T <: AbstractRange
    RangeSlider{T, typeof(value)}(
        uuid_string(),
        Observable(range),
        Observable(value),
        Dict{Symbol, Any}(kw),
        Observable(true),
        Observable(horizontal)
    )
end


const noUiSlider = Dependency(
    :noUiSlider,
    [
        "https://cdn.jsdelivr.net/gh/leongersen/noUiSlider/distribute/nouislider.min.js",
        "https://cdn.jsdelivr.net/gh/leongersen/noUiSlider/distribute/nouislider.min.css"
    ]
)

function jsrender(session::Session, slider::RangeSlider)
    rangediv = div()
    onload(session, rangediv, js"""
        function create_slider(range){
            $(noUiSlider).create(range, {

                range: {
                    'min': $(fill(slider.range[][1], length(slider.value[]))),
                    'max': $(fill(slider.range[][end], length(slider.value[])))
                },

                step: $(step(slider.range[])),

                // Handles start at ...
                start: $(slider.value[]),
                // Display colored bars between handles
                connect: $(slider.connect[]),
                tooltips: true,

                // Put '0' at the bottom of the slider
                direction: 'ltr',
                orientation: $(string(slider.orientation[])),
            })

            range.noUiSlider.on('update', function (values, handle, unencoded, tap, positions){
                update_obs($(slider.value), [parseInt(values[0]), parseInt(values[1])])
            })
        }
    """)
    return rangediv
end

struct Button{T} <: AbstractWidget{Bool}
    id::String
    content::Observable{T}
    value::Observable{Bool}
    attributes::Dict{Symbol, Any}
end

function Button(content; kw...)
    return Button(
        uuid_string(), Observable(content), Observable(false), Dict{Symbol, Any}(kw)
    )
end

function jsrender(button::Button)
    return input(
        type = "button",
        value = button.content,
        dataJscallId = uuid(button),
        onclick = js"update_obs($(button.value), true)";
        button.attributes...
    )
end

struct TextField <: AbstractWidget{String}
    id::String
    value::Observable{String}
    attributes::Dict{String, Any}
end

function TextField(value::String; kw...)
    TextField(uuid_string(), Observable(value), Dict{Symbol, Any}(kw))
end

function jsrender(tf::TextField)
    return input(
        type = "textfield",
        value = tf.value,
        dataJscallId = tf.id,
        onchange = js"update_obs($(tf.value),  this.value)";
        tf.attributes...
    )
end
