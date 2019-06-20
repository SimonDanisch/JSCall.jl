const observables = {}
const observable_callbacks = {}
websocket = null

// Save some bytes by using ints for switch variable
const UpdateObservable = '0'
const OnjsCallback = '1'
const EvalJavascript = '2'
const JavascriptError = '3'
const JavascriptWarning = '4'


function get_observable(id){
    if(id in observables){
        return observables[id]
    }else{
        throw ("Can't find observable with id: " + id)
    }
}

function send_error(message, exception){
    websocket.send({
        type: JavascriptError,
        message: message,
        exception: exception
    })
}


function send_warning(message){
    websocket.send({
        type: JavascriptWarning,
        payload: message
    })
}

function run_js_callbacks(id, value){
    if(id in observable_callbacks){
        var callbacks = observable_callbacks[id]
        var deregister_calls = []
        for (var i = 0; i < callbacks.length; i++) {
            // onjs can return false to deregister itself
            try{
                var register = callbacks[i](value)
                if(register == false){
                    deregister_calls.push(i)
                }
            }catch(exception){
                 send_error("Error during running onjs callback", exception)
            }
        }
        for (var i = 0; i < deregister_calls.length; i++) {
            callbacks.splice(deregister_calls[i], 1)
        }
    }
}




function update_obs(id, value){
    console.log("js update obs " + id)
    if(id in observables){
        try{
            observables[id] = value
            // call onjs callbacks
            run_js_callbacks(id, value)
            // update Julia side!
            websocket_send({
                type: UpdateObservable,
                id: id,
                payload: value
            })
        }catch(exception){
             send_error("Error during update_obs", exception)
        }
        return true
    }else{
        return false
    }

}

function websocket_send(data){
    websocket.send(JSON.stringify(data))
}



function setup_connection(){
    function tryconnect(url) {
        websocket = new WebSocket(url);
        websocket.onopen = function () {
            websocket.onmessage = function (evt) {
                var data = JSON.parse(evt.data)
                switch(data.type) {
                    case UpdateObservable:
                        try{
                            console.log("jl update obs " + data.id)
                            var value = data.payload
                            observables[data.id] = value
                            // update all onjs callbacks
                            run_js_callbacks(data.id, value)
                        }catch(exception){
                            send_error("Error while running an observable update from Julia", exception)
                        }
                        break;
                    case OnjsCallback:
                        try{
                            // register a callback that will executed on js side
                            // when observable updates
                            var id = data.id
                            var f = eval(data.payload);
                            var callbacks = observable_callbacks[id] || []
                            callbacks.push(f)
                            observable_callbacks[id] = callbacks
                        }catch(exception){
                            send_error("Error while registering an onjs callback", exception)
                        }
                        break;
                    case EvalJavascript:
                        try{
                            eval(data.payload);
                        }catch(exception){
                            send_error("Error while evaling JS from Julia", exception)
                        }
                        break;
                    default:
                        send_error("Unrecognized message type: " + data.id, "")
                }
            }
        }
        websocket.onclose = function (evt) {
            if (evt.code === 1005) {
                // TODO handle this!?
                //tryconnect(url)
            }
        }
    }
    var url = __websock_url__
    console.log("Trying to connect to " + url)
    tryconnect(url)
}
