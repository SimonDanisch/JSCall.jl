module JSCall

using WebIO, JSExpr
import WebIO: tojs
using JSON

"""
References objects stored in Javascript.
Maps the following expressions to actual calls on the Javascript side:
```julia
jso = JSObject(name, scope, typ)
# getfield:
x = jso.property # returns a new JSObject
# setfield
jso.property = "newval" # Works with JSObjects or Julia objects as newval
# call:
result = jso.func(args...) # works with julia objects and other JSObjects as args

# constructors are wrapped this way:
scene = jso.new.Scene() # same as in JS: scene = new jso.Scene()
```
"""
mutable struct JSObject
    # fields are private and not accessible via jsobject.field
    name::Symbol
    scope::Scope
    typ::Symbol
    # transporting the UUID allows us to have a uuid different from the objectid
    # which will help to better capture === equivalence on the js side.
    uuid::UInt64

    function JSObject(name::Symbol, scope::Scope, typ::Symbol)
        obj = new(name, scope, typ)
        setfield!(obj, :uuid, objectid(obj))
        #finalizer(remove_js_reference, obj)
        return obj
    end

    function JSObject(name::Symbol, scope::Scope, typ::Symbol, uuid::UInt64)
        obj = new(name, scope, typ, uuid)
        #finalizer(remove_js_reference, obj)
        return obj
    end
end

"""
WebIO seems to purposefully not show symbols as variables, so we need our own Sym
"""
struct Sym
    symbol::Symbol
    Sym(x) = new(Symbol(x))
end

const object_pool_identifier = Sym("window.object_pool")

"""
Removes an JSObject from the object pool!
"""
function remove_js_reference(jso::JSObject)
    evaljs(jso, "delete $(object_pool_identifier)[$(uuid(jso))]")
end

# define accessors
for name in (:name, :scope, :typ, :uuid)
    @eval $(name)(jso::JSObject) = getfield(jso, $(QuoteNode(name)))
end

"""
    uuidstr(jso::JSObject)

Returns the uuid as a string
"""
uuidstr(jso::JSObject) = string(uuid(jso))

"""
    JSObject(jso::JSObject, typ::Symbol)

Copy constructor with a new `typ`
"""
function JSObject(jso::JSObject, typ::Symbol)
    jsonew = JSObject(name(jso), scope(jso), typ)
    # point new object to old one on the javascript side:
    evaljs(jso, js"$jsonew = $jso; undefined;")
    return jsonew
end

tojsexpr(x::String) = JSString(x)
tojsexpr(x::JSString) = x
tojsexpr(x) = error("$(typeof(x)) is not convertible to a JS string / expression")

"""
    evaljs(
        jso::JSObject, js::Union{JSString, String};
        try_fetch = false, try_seconds = 2
    )

Evaluates Javascript in the scope of JSObject
"""
function WebIO.evaljs(
        jso::JSObject, js::Union{JSString, AbstractString};
        try_fetch = false, try_seconds = 2
    )
    jse = tojsexpr(js)
    task = evaljs(scope(jso), jse)
    if try_fetch
        start = time()
        while (time() - start) <= try_seconds
            if istaskdone(task)
                return fetch(task)
            end
        end
    end
    return nothing
end

WebIO.showjs(io::IO, sym::Sym) = print(io, sym.symbol)
# Make interpolation work for JSObject
function WebIO.tojs(jso::JSObject)
    return js"$(object_pool_identifier)[$(uuidstr(jso))]"
end
function JSON.lower(jso::JSObject)
    return js"$(object_pool_identifier)[$(uuidstr(jso))]"
end

"""
Overloading getproperty to allow the same semantic as Javascript.
Since there is no `new` keyword in Julia like in JS, we missuse
jsobject.new, to return an instance of jsobject with a new modifier.

So this Javascript:
```js
obj = new Module.Constructor()
```

Will translates to the following Julia code:
```Julia
obj = Module.new.Constructor()
```
"""
function Base.getproperty(jso::JSObject, field::Symbol)
    if field === :new
        # Create a new instance of jso, with the `new` modifier
        return JSObject(jso, :new)
    else
        # allocate result object:
        result = JSObject(field, scope(jso), typ(jso))
        js = js"""
        var object = $jso
        var result = object.$(Sym(field))
        // if result is a class method, we need to bind it to the parent object
        if(result.bind != undefined){
            result = result.bind(object)
        }
        $(object_pool_identifier)[$(uuidstr(result))] = result
        undefined
        """
        evaljs(jso, js)
        return result
    end
end

function Base.setproperty!(jso::JSObject, name::Symbol, val)
    evaljs(jso, js"$(jso).$(Sym(name)) = $val; undefined;")
    return val
end

modifier(jso::JSObject) = getfield(jso, :typ) === :new ? "new " : ""

"""
Constructs the arguments for a JS call
"""
function get_args(args, kw_args)
    if isempty(kw_args)
        return join(map(x-> sprint(io-> WebIO.showjs(io, tojs(x))), args), ", ")
    elseif isempty(args)
        # tojs isn't recursive bug:
        return sprint() do io
            print(io, '{')
            for (k, v) in kw_args
                print(io, k, ':')
                WebIO.showjs(io, tojs(v))
                print(io, ',')
            end
            print(io, '}')
        end
    else
        # TODO: I'm not actually sure about this :D
        error("""
        Javascript only supports keyword arguments OR arguments.
        Found posititional arguments and keyword arguments
        """)
    end
end

"""
    jsobject(args...; kw_args...)

Call overload for JSObjects.
Only supports keyword arguments OR positional arguments.
"""
function (jso::JSObject)(args...; kw_args...)
    result = JSObject(:result, scope(jso), :call)
    input_args = get_args(args, kw_args)
    js = """
    var func = $(tojs(jso))
    var result = $(modifier(jso))func(
        $input_args
    )
    $(object_pool_identifier.symbol)[\"$(uuid(result))\"] = result
    undefined;
    """
    evaljs(jso, js)
    return result
end

"""
Indicates that no value is in an observable.
Sentinel needed to check if an Observable got a new value.
Can't use nothing, since the value itself could be nothing.
"""
struct NoValue end

JSON.lower(x::NoValue) = ""

"""
    Module(name::Symbol, url::String)

Wraps a Javascript library.
"""
function JSModule(name::Symbol, url::String)
    scope = Scope(imports = [url])
    Observable{Any}(scope, "_jscall_value_comm", NoValue())
    mod = JSObject(name, scope, :module)
    document = JSObject(:document, scope, :module)
    window = JSObject(:window, scope, :module)

    js = js"""
    function (mod){
        $(object_pool_identifier) = {}
        $(object_pool_identifier)[$(uuidstr(mod))] = mod
        $(object_pool_identifier)[$(uuidstr(document))] = document
        $(object_pool_identifier)[$(uuidstr(window))] = window
    }
    """
    onimport(scope, js)
    return mod, document, window
end

using JSExpr: jsexpr

macro jsfun(expr)
    func = copy(expr.args[1].args)
    arguments = func[2:end]
    jss = JSCall.JSExpr.jsstring(expr)
    expr = quote
        args = ($(arguments...),)
        idx = findfirst(x-> x isa JSObject, args)
        idx === nothing && error("At least one argument needs to be of type JSObject")
        jso = args[idx]
        s = scope(jso)
        any(x-> x isa JSObject && (scope(x) !== s), args) && error("All JSObjects need to come from the same Scope")
        argstr = join(map(x-> sprint(io-> WebIO.showjs(io, WebIO.tojs(x))), args), ", ")
        result = JSObject(:result, scope(jso), :object)
        result_js = WebIO.tojs(result)
        jss = JSString(string($(jss...)))
        jss = "$result_js = ($jss)($argstr)"
        evaljs(jso, jss)
        return result
    end
    return Expr(:function, Expr(:call, esc(func[1]), func[2:end]...), expr)
end

"""
    jlvalue(jso::JSObject)

Fetches the Julia value representing a certin JSObject
"""
function jlvalue(jso::JSObject)
    obs, sync = scope(jso).observs["_jscall_value_comm"]
    obs[] = NoValue()
    evaljs(jso, @js($obs[] = $jso))
    timeout = 5 # wait at most 5 seconds
    start = time()
    yield() # maybe we can already get the value on first iteration
    while time() - start < timeout
        obs[] !== NoValue() && return obs[]
        sleep(0.001)
    end
    error("Timed out while trying to fetch value")
end

export JSObject, JSModule, scope, @jsfun, jlvalue

end # module
