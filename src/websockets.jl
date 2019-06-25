
function upgrade_websocket(application::Application, stream::Stream)
    check_upgrade(stream)
    if !hasheader(stream, "Sec-WebSocket-Version", "13")
        setheader(stream, "Sec-WebSocket-Version" => "13")
        setstatus(stream, 400)
        startwrite(stream)
        return
    end
    if hasheader(stream, "Sec-WebSocket-Protocol")
        requestedprotocol = header(stream, "Sec-WebSocket-Protocol")
        if !hasprotocol(requestedprotocol)
            setheader(stream, "Sec-WebSocket-Protocol" => requestedprotocol)
            setstatus(stream, 400)
            startwrite(stream)
            return
        else
            setheader(stream, "Sec-WebSocket-Protocol" => requestedprotocol)
        end
    end
    key = header(stream, "Sec-WebSocket-Key")
    decoded = UInt8[]
    try
        decoded = base64decode(key)
    catch
        setstatus(stream, 400)
        startwrite(stream)
        return
    end
    if length(decoded) != 16 # Key must be 16 bytes
        setstatus(stream, 400)
        startwrite(stream)
        return
    end
    # This upgrade is acceptable. Send the response.
    setheader(stream, "Sec-WebSocket-Accept" => generate_websocket_key(key))
    setheader(stream, "Upgrade" => "websocket")
    setheader(stream, "Connection" => "Upgrade")
    setstatus(stream, 101)
    startwrite(stream)
    # Pass the connection on as a WebSocket.
    io = getrawstream(stream)
    ws = WebSocket(io, true)
    # If the callback function f has two methods,
    # prefer the more secure one which takes (request, websocket)
    try
        websocket_handler(application, stream.message, ws)
    catch e
        @error "Error while applying websocket" exception=e
    finally
        close(ws)
    end
end
