import asyncio
import websockets
import warnings
import ast
import subprocess
import json

active_servers = {}
server_process = {}

f = open("config.txt","r")
jsonConfig = f.read()
f.close()

settings = json.loads(jsonConfig)

def ConstructStartArgs(data):
    newData = [
        settings["srcds_path"],
        "-console",
        "-game garrysmod",
        "+map "+data["map"],
        "+maxplayers "+str(int(data["numPlayers"])),
        "+gamemode "+data["gamemode"],
        "+sv_allowcslua 1",
        "+hostname SRCDSServerInstance-"+str(data.get("id", 0))
    ]

    if ("collection" in data):
        newData.append("+host_workshop_collection "+data["collection"])

    return newData

async def killServer(main_socket,websocket,data):
    server_process[data["id"]].kill()

    await main_socket.send(json.dumps({
        "action" : "stop",
        "id" : data["id"]
    }))

async def startServer(main_socket,websocket,data):
    newProcess = subprocess.Popen(ConstructStartArgs(data))

    server_process[data["id"]] = newProcess

async def handshakeServer(main_socket,websocket,data):
    server_id = data["id"]

    active_servers[server_id] = websocket

    await main_socket.send(json.dumps({ 
        "action" : "handshake", 
        "id" : server_id,
        "ip" : data["ip"]
    }))

async def sendLuaToServer(main_socket,websocket,data):
    server_id = data["id"]

    await active_servers[server_id].send(json.dumps({ 
        "action" : "sendlua", 
        "id" : server_id,
        "lua" : data["lua"]
    }))

async def changeMap(main_socket,websocket,data):
    server_id = data["id"]

    await active_servers[server_id].send(json.dumps({
        "action" : "map",
        "id" : server_id,
        "map" : data["map"]
    }))

actions = {
    "start" : startServer,
    "handshake" : handshakeServer,
    "stop" : killServer,
    "sendlua" : sendLuaToServer
}

async def handleData(main_socket, websocket, data):
    print(data)
    await actions[data["action"]](main_socket,websocket,data)

main_socket = None

async def handler(websocket, path):
    global main_socket

    if (main_socket is None):
        main_socket = websocket

    while True:
        try:
            data = await websocket.recv()
            dataTable = ast.literal_eval(data)

            if (type(dataTable) is not dict):
                continue

            await handleData(main_socket, websocket, dataTable)

        except websockets.exceptions.ConnectionClosedError:

            break

start_server = websockets.serve(handler, 'localhost', 9000)

with warnings.catch_warnings():
    warnings.simplefilter("ignore")
    
    asyncio.get_event_loop().run_until_complete(start_server)
    asyncio.get_event_loop().run_forever()
