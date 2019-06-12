(function () {
    window.observables = {}
    function get_observable(id){
        return window.observables[id]
    }
    function update_obs(id, value){
        window.observables[id] = value
        window.send({
            type: "obs",
            id: id,
            payload: value
        })
    }
    function tryconnect(url) {
        var ws = new WebSocket(url);
        window.send = function (data){
            ws.send(JSON.stringify(data))
        }
        ws.onopen = function () {
            ws.onmessage = function (evt) {
                var data = JSON.parse(evt.data)
                switch(data.type) {
                    case "eval":
                        console.log(data.payload);
                        eval(data.payload);
                        break;
                    case "obs":
                        window.observables[data.id] = data.payload
                        break;
                }
            }
        }
        ws.onclose = function (evt) {
            if (evt.code === 1005) {
                // TODO handle this!?
                //tryconnect(url)
            }
        }
    }
    tryconnect(__websock_url__)
})();
