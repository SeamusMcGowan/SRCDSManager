require("gwsockets")

SRCDS = SRCDS or {}

--Networking Stuff

util.AddNetworkString("SRCDS_JoinServer")

--Websocket Communication

local handlerFunctions = {
	handshake = function(self,data)
		SRCDS:storeServer(data)
	end,
	sendlua = function(self,data)
		RunString(data.lua)
	end,
	map = function(self,data)
		RunConsoleCommand("changelevel",data.map)
	end,
}

function SRCDS:initializeSocket()

	SRCDS.activeSocket = GWSockets.createWebSocket("ws://127.0.0.1:9000/",false)

	function SRCDS.activeSocket:onMessage(txt)
		local data = util.JSONToTable(txt)
		local action = handlerFunctions[data.action]

		action(_,data)
	end

	SRCDS.activeSocket:open()

end

function SRCDS:writeToSocket(data)
	if (!self.activeSocket or !self.activeSocket:isConnected()) then
		self:initializeSocket()
	end

	local data = util.TableToJSON(data)

	self.activeSocket:write(data)
end

--SRCDS Functions

SRCDS.activeServers = SRCDS.activeServers or {}

local newServerMeta = {
	connect = function(self, player)
		SRCDS:writeToSocket({
			action = "sendlua",
			id = self.id,
			lua = "addToWhitelist('"..player:SteamID64().."')"
		})

		player:SendLua("permissions.AskToConnect('"..self.ip.."')")
	end,
	sendLua = function(self,lua)
		SRCDS:writeToSocket({
			id = self.id,
			action = "sendlua",
			lua = lua,
		})
	end,
	changeMap = function(self,map)
		SRCDS:writeToSocket({
			id = self.id,
			action = "map",
			map = map,
		})
	end,
	stop = function(self)
		SRCDS.activeServers[self.id] = nil

		SRCDS:writeToSocket({
			id = self.id,
			action = "stop"
		})
	end,
}
newServerMeta.__index = newServerMeta

local handshakeCallbacks = {}

function SRCDS:createNewServer(map, players, gamemode, collection, callback)
	local newID = tostring(table.Count(self.activeServers) + 1)
	self:writeToSocket({ 
		action = "start", 
		id = newID, 
		map = map or "gm_flatgrass",
		numPlayers = players or 4,
		gamemode = gamemode or engine.ActiveGamemode(),
		collection = collection,
	})

	if (callback) then
		handshakeCallbacks[newID] = callback
	end

	return newID
end

function SRCDS:storeServer(data)
	local newServer = {}
	setmetatable(newServer, newServerMeta)

	newServer.ip = data.ip
	newServer.id = data.id
	newServer.handShook = true

	self.activeServers[data.id] = newServer

	local callback = handshakeCallbacks[data.id]

	if (callback) then
		callback(self.activeServers[data.id])

		handshakeCallbacks[data.id] = nil
	end
end

hook.Add("Think","Handshake_Think",function()
	local ip = game.GetIPAddress()

	if (!ip:find("0.0.0.0")) then
		local serverName = GetHostName()

		if (serverName:find("SRCDSServerInstance")) then
			local id = serverName:sub(21)

			local handshakeData = {
				action = "handshake",
				id = id,
				ip = ip,
			}

			SRCDS:writeToSocket(handshakeData)
		end

		hook.Remove("Think","Handshake_Think")
	end
end)