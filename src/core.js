const observables = {}
const observable_callbacks = {}
websocket = null

// Save some bytes by using ints for switch variable
const UpdateObservable = '0'
const OnjsCallback = '1'
const EvalJavascript = '2'

function get_observable(id){
    if(id in observables){
        return observables[id]
    }else{
        throw ("Can't find observable with id: " + id)
    }
}

function update_obs(id, value){
    console.log(id + " " + value);
    observables[id] = value
    // call onjs callbacks
    if(id in observable_callbacks){
        var callbacks = observable_callbacks[id]
        for (var i = 0; i < callbacks.length; i++) {
            console.log("updating inside onjs: " + value)
            callbacks[i](value)
        }
    }
    // update Julia side!
    websocket_send({
        type: UpdateObservable,
        id: id,
        payload: value
    })
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
                        var value = data.payload
                        observables[data.id] = value
                        if(data.id in observable_callbacks){
                            var callbacks = observable_callbacks[data.id]
                            for (var i = 0; i < callbacks.length; i++) {
                                console.log("updating onjs: " + value)
                                callbacks[i](value)
                            }
                        }
                        break;
                    case OnjsCallback:
                        // register a callback that will executed on js side
                        // when observable updates
                        var f = eval(data.payload);
                        observable_callbacks[data.id] = [f];
                        break;
                    case EvalJavascript:
                        console.log(data.payload)
                        eval(data.payload);
                        break;
                    default:
                        throw ("Unrecognized message type: " + data.id)
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
