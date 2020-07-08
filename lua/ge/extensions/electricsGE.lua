--====================================================================================
-- All work by Jojos38 & Titch2000.
-- You have no permission to edit, redistrobute or upload. Contact us for more info!
--====================================================================================



local M = {}

local readyMap = {}

print("electricsGE Initialising...")

local function isReady(gameVehicleID)
    return readyMap[tostring(gameVehicleID)] ~= nil
end


local function tick() -- Update electrics values of all vehicles - The server check if the player own the vehicle itself
	local ownMap = vehicleGE.getOwnMap() -- Get map of own vehicles
	for i,v in pairs(ownMap) do -- For each own vehicle
		local veh = be:getObjectByID(i) -- Get vehicle
		if veh then
			veh:queueLuaCommand("electricsVE.getElectrics()") -- Send electrics values
			veh:queueLuaCommand("electricsVE.getGear()") -- Send gears values
		end
	end
end



local function sendElectrics(data, gameVehicleID) -- Called by vehicle lua
	if GameNetwork.connectionStatus() == 1 then -- If TCP connected
		local serverVehicleID = vehicleGE.getServerVehicleID(gameVehicleID) -- Get serverVehicleID
		if serverVehicleID and vehicleGE.isOwn(gameVehicleID) then -- If serverVehicleID not null and player own vehicle
			GameNetwork.send('We:'..serverVehicleID..":"..data)--Network.send(Network.buildPacket(0, 2131, serverVehicleID, data))
			--print("Electrics sent "..serverVehicleID)
		end
	end
end



local function applyElectrics(data, serverVehicleID)
	--print("gameVehicleID: "..vehicleGE.getGameVehicleID(serverVehicleID))
	local gameVehicleID = vehicleGE.getGameVehicleID(serverVehicleID) or -1 -- get gameID
	local veh = be:getObjectByID(gameVehicleID)
	if veh and isReady(gameVehicleID) then
		if not vehicleGE.isOwn() then
			veh:queueLuaCommand("electricsVE.applyElectrics(\'"..data.."\')")
		end
	end
end



local function sendGear(data, gameVehicleID)
	if GameNetwork.connectionStatus() == 1 then -- If TCP connected
		local serverVehicleID = vehicleGE.getServerVehicleID(gameVehicleID) -- Get serverVehicleID
		if serverVehicleID and vehicleGE.isOwn(gameVehicleID) then -- If serverVehicleID not null and player own vehicle
			GameNetwork.send('Wg:'..serverVehicleID..":"..data)--Network.buildPacket(0, 2135, serverVehicleID, data))
			--print("Gear sent "..serverVehicleID)
		end
	end
end

local function applyGear(data, serverVehicleID)
	local gameVehicleID = vehicleGE.getGameVehicleID(serverVehicleID) or -1 -- get gameID
	local veh = be:getObjectByID(gameVehicleID)
	if veh and isReady(gameVehicleID) then
		if not vehicleGE.isOwn() then
			veh:queueLuaCommand("electricsVE.applyGear(\'"..data.."\')")
		end
	end
end

local function handle(rawData)
	--print("electricsGE.handle: "..rawData)
	local code = string.sub(rawData, 1, 1)
	local rawData = string.sub(rawData, 3)
	if code == "e" then
		local serverVehicleID = string.match(rawData,"^.-:")
		serverVehicleID = serverVehicleID:sub(1, #serverVehicleID - 1)
		local data = string.match(rawData,":(.*)")
		applyElectrics(data, serverVehicleID)
	elseif code == "g" then
		local serverVehicleID = string.match(rawData,"^.-:")
		serverVehicleID = serverVehicleID:sub(1, #serverVehicleID - 1)
		local data = string.match(rawData,":(.*)")
		applyGear(data, serverVehicleID)
	end
end

local function setReady(gameVehicleID)
	readyMap[tostring(gameVehicleID)] = 1 -- Insert vehicle in ready map
end


M.tick 			 = tick
M.handle		 = handle
M.isReady		 = isReady
M.setReady		 = setReady
M.sendGear		 = sendGear
M.applyGear		 = applyGear
M.sendElectrics  = sendElectrics
M.applyElectrics = applyElectrics


print("electricsGE Loaded.")
return M
