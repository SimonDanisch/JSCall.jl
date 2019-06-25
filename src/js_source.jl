struct JSSource
    source::String
end

struct JSString
    source::Vector{Union{JSSource, Any}}
end

function iterate_interpolations(source::String)
    result = Union{Expr, JSSource, Symbol}[]
    lastidx = 1; i = 1; lindex = lastindex(source)
    while true
        c = source[i]
        if c == '$'
            if !isempty(lastidx:(i - 1))
                push!(result, JSSource(source[lastidx:(i - 1)]))
            end
            expr, i2 = Meta.parse(source, i + 1, greedy = false, raise = false)
            if i2 >= lindex && expr === nothing
                error("Invalid interpolation at index $(i)-$(lindex): $(source[i:lindex])")
            end
            i = i2
            push!(result, esc(expr))
            lastidx = i
        else
            if i == lindex
                if !isempty(lastidx:lindex)
                    push!(result, JSSource(source[lastidx:lindex]))
                end
                break
            end
            i = Base.nextind(source, i)
        end
    end
    return result
end
macro js_str(js_source)
    value_array = :([])
    append!(value_array.args, iterate_interpolations(js_source))
    return :(JSString($value_array))
end

append_source!(x::JSSource, value::String) = push!(x.source, JSSource(value))
append_source!(x::JSSource, value::JSString) = push!(x.source, value)
append_source!(x::JSSource, value::JSSource) = append!(x.source, value.source)
