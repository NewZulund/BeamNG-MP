--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}
print("inputsGE Initialising...")



local function tick() -- Update electrics values of all vehicles - The server check if the player own the vehicle itself
	local ownMap = vehicleGE.getOwnMap() -- Get map of own vehicles
	for i,v in pairs(ownMap) do -- For each own vehicle
		local veh = be:getObjectByID(i) -- Get vehicle
		if veh then
			veh:queueLuaCommand("inputsVE.getInputs()") -- Send electrics values
		end
	end
end



local function sendInputs(data, gameVehicleID) -- Called by vehicle lua
	if GameNetwork.connectionStatus() == 1 then -- If TCP connected
		local serverVehicleID = vehicleGE.getServerVehicleID(gameVehicleID) -- Get serverVehicleID
		if serverVehicleID and vehicleGE.isOwn(gameVehicleID) then -- If serverVehicleID not null and player own vehicle
			GameNetwork.send('Vi:'..serverVehicleID..":"..data)--Network.buildPacket(0, 2130, serverVehicleID, data))
		end
	end
end

local function applyInputs(data, serverVehicleID)
	local gameVehicleID = vehicleGE.getGameVehicleID(serverVehicleID) or -1 -- get gameID
	local veh = be:getObjectByID(gameVehicleID)
	if veh and electricsGE.isReady(gameVehicleID) then
		veh:queueLuaCommand("inputsVE.applyInputs(\'"..data.."\')")
	end
end

local function handle(rawData)
	--print("inputsGE.handle: "..rawData)
	rawData = string.sub(rawData,3)
	local serverVehicleID = string.match(rawData,"^.-:")
	serverVehicleID = serverVehicleID:sub(1, #serverVehicleID - 1)
	local data = string.match(rawData,":(.*)")
	--print(serverVehicleID)
	--print(data)
	applyInputs(data, serverVehicleID)
end



M.tick        = tick
M.handle      = handle
M.sendInputs  = sendInputs
M.applyInputs = applyInputs



print("inputsGE Loaded.")
return M
