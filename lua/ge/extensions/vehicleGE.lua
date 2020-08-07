--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================

-- HOW DOES IT WORK :
-- When player connect to server for the first time, it send all his spawned vehicles to the server
-- The server add all vehicles create ID for them and then send them back to the client with client ID
-- If the received vehicle is the one that have been spawned by the client (check using client ID) then
	-- It sync the client in-game vehicle ID with the server ID
-- Else
	-- It spawn the received vehicle and then get the spawned vehicle ID and sync it with the received one



local M = {}
print("vehicleGE Initialising...")


-- ============= VARIABLES =============
local ownMap = {}
local first = true
local vehiclesMap = {}
local nicknameMap = {}
local invertedVehiclesMap = {}
local onVehicleSpawnedAllowed = true
local onVehicleDestroyedAllowed = true
local syncTimer = 0
local syncVehIDs = {}
local currentVehicle = nil
local nextSpawnIsNotRemote = false
-- ============= VARIABLES =============



--============== SOME FUNCTIONS ==============
local function println(stringToPrint)
	print("[BeamMP] | "..stringToPrint)
end

local function tableInvert(t)
   local s = {}
   for k,v in pairs(t) do
     s[v] = k
   end
   return s
end

local function getGameVehicleID(serverVehicleID)
	return invertedVehiclesMap[tostring(serverVehicleID)]
end

local function getServerVehicleID(gameVehicleID)
	return vehiclesMap[tostring(gameVehicleID)]
end

local function insertVehicleMap(gameVehicleID, serverVehicleID)
	vehiclesMap[tostring(gameVehicleID)] = tostring(serverVehicleID)
	invertedVehiclesMap[tostring(serverVehicleID)] = tostring(gameVehicleID)
end

local function isOwn(gameVehicleID)
    return ownMap[tostring(gameVehicleID)] ~= nil
end

local function getOwnMap()
    return ownMap
end
--============== SOME FUNCTIONS ==============



--============================ DELETE ALL VEHICLES ==============================
local function deleteAllVehicles()
	if be:getObjectCount() == 0 then return end -- If no vehicle do nothing
	commands.setFreeCamera()
	for i = 0, be:getObjectCount() do -- For each vehicle
		local veh = be:getObject(0) --  Get vehicle
		if veh then -- For loop always return one empty vehicle ?
			onVehicleDestroyedAllowed = false
			veh:delete()
		end
	end
end
--============================ DELETE ALL VEHICLES ==============================



--============================ SEND ALL VEHICLES ==============================
local function sendAllVehicles()
	if be:getObjectCount() == 0 then return end -- If no vehicle do nothing
	for i = 0, be:getObjectCount() do -- For each vehicle
		local veh = be:getObject(i) --  Get vehicle
		if veh then -- For loop always return one empty vehicle ?
			veh:queueLuaCommand("obj:queueGameEngineLua(\"vehicleGE.sendVehicleData("..veh:getID()..", '\"..jsonEncode(v.config)..\"')\")") -- Get config
		end
	end
end
--============================ SEND ALL VEHICLES ==============================



--============================ SEND ONE VEHICLE ==============================
local function sendVehicle(gameVehicleID)
	local veh = be:getObjectByID(gameVehicleID) -- Get spawned vehicle ID
	if veh then -- In case of bug
		veh:queueLuaCommand("obj:queueGameEngineLua(\"vehicleGE.sendVehicleData("..gameVehicleID..", '\"..jsonEncode(v.config)..\"')\")") -- Get config
		print("VEHICLE SENT")
	end
end
--============================ SEND ONE VEHICLE ==============================



--=========================================== SEND VEHICLE DATA =============================================
local function sendVehicleData(gameVehicleID, vehicleConfig)
	local vehicleTable    = {} -- Vehicle table
	local veh             = be:getObjectByID(gameVehicleID)
	local c               = veh.color
	local p0              = veh.colorPalette0
	local p1              = veh.colorPalette1

	vehicleTable[1]  = mpConfig.getPlayerServerID()
	vehicleTable[2]  = tostring(gameVehicleID)
	vehicleTable[3]  = veh:getJBeamFilename()
	vehicleTable[4]  = vehicleConfig
	vehicleTable[5]  = jsonEncode({c.x, c.y, c.z, c.w})
	vehicleTable[6]  = jsonEncode({p0.x, p0.y, p0.z, p0.w})
	vehicleTable[7]  = jsonEncode({p1.x, p1.y, p1.z, p1.w})
	vehicleTable[8]  = getServerVehicleID(gameVehicleID) or ""
	vehicleTable[9]  = jsonEncode(be:getObjectByID(gameVehicleID):getPosition())
	vehicleTable[10] = jsonEncode(be:getObjectByID(gameVehicleID):getRotation())

	local stringToSend = jsonEncode(vehicleTable) -- Encode table to send it as json string
	GameNetwork.send('Os:0:'..stringToSend)--Network.buildPacket(1, 2020, 0, stringToSend))	-- Send table that contain all vehicle informations for each vehicle
end
--=========================================== SEND VEHICLE DATA =============================================

--=========================================== SEND MODIFIED VEHICLE DATA =============================================
local function sendCustomVehicleData(gameVehicleID, vehicleConfig)
	local vehicleTable    = {} -- Vehicle table
	local veh             = be:getObjectByID(gameVehicleID)
	local c               = veh.color
	local p0              = veh.colorPalette0
	local p1              = veh.colorPalette1

	vehicleTable[1]  = mpConfig.getPlayerServerID()
	vehicleTable[3]  = veh:getJBeamFilename()
	vehicleTable[4]  = vehicleConfig
	vehicleTable[5]  = jsonEncode({c.x, c.y, c.z, c.w})
	vehicleTable[6]  = jsonEncode({p0.x, p0.y, p0.z, p0.w})
	vehicleTable[7]  = jsonEncode({p1.x, p1.y, p1.z, p1.w})

	local stringToSend = jsonEncode(vehicleTable) -- Encode table to send it as json string
	GameNetwork.send('Oc:'..getServerVehicleID(gameVehicleID)..':'..stringToSend)--Network.buildPacket(1, 2020, 0, stringToSend))	-- Send table that contain all vehicle informations for each vehicle

	syncTimer = 0
	syncVehIDs[gameVehicleID] = 0
	print("clearing id "..gameVehicleID.." from the sync table")
end
--=========================================== RECEIVE MODIFIED VEHICLE DATA =============================================

--=========================================== UPDATE SEND VEHICLE DATA =============================================
local function UpdateVehicle(sid, data)
	local currentVeh = be:getPlayerVehicle(0) -- Camera fix

	local gameVehicleID = getGameVehicleID(sid)
	local veh = be:getObjectByID(gameVehicleID)
	local decodedData     = jsonDecode(data)
	local vehicleName     = decodedData[3] -- Vehicle name
	local vehicleConfig   = decodedData[4] -- Vehicle config
	local c               = jsonDecode(decodedData[5]) -- Vehicle color
	local cP0             = jsonDecode(decodedData[6]) -- Vehicle colorPalette0
	local cP1             = jsonDecode(decodedData[7]) -- Vehicle colorPalette1
	if vehicleName == veh:getJBeamFilename() then
		veh:queueLuaCommand("vehicleVE.applyPartConfig(\'"..vehicleConfig.."\')") -- Get config
	else
		print("RECEIVE MODIFIED DATA FOR A VEHICLE THAT IS NOT OF THE SAME TYPE!!!")
	end

	if currentVeh then be:enterVehicle(0, currentVeh) end -- Camera fix
end
--=========================================== UPDATE SEND VEHICLE DATA =============================================


local function onDisconnect()
	-- Clear ownMap and vehiclesMap
	ownMap = {}
	vehiclesMap = {}
	invertedVehiclesMap = {}
	first = true
end


--================================= ON VEHICLE SPAWNED (SERVER) ===================================
local function onServerVehicleSpawned(playerRole, playerNickname, serverVehicleID, data)
	local currentVeh = be:getPlayerVehicle(0) -- Camera fix
	local decodedData     = jsonDecode(data)
	local playerServerID  = decodedData[1] -- Server ID of the player that sent the vehicle
	local gameVehicleID   = decodedData[2] -- gameVehicleID of the player that sent the vehicle
	--local serverVehicleID = decodedData[3] -- Server ID of the vehicle
	local vehicleName     = decodedData[3] -- Vehicle name
	local vehicleConfig   = jsonDecode(decodedData[4]) -- Vehicle config
	local c               = jsonDecode(decodedData[5]) -- Vehicle color
	local cP0             = jsonDecode(decodedData[6]) -- Vehicle colorPalette0
	local cP1             = jsonDecode(decodedData[7]) -- Vehicle colorPalette1


	print("onServerVehicleSpawned ID's:  "..mpConfig.getPlayerServerID().." == "..playerServerID)
	if mpConfig.getPlayerServerID() == playerServerID then -- If player ID = received player ID seems it's his own vehicle then sync it
		insertVehicleMap(gameVehicleID, serverVehicleID) -- Insert new vehicle ID in map
		ownMap[tostring(gameVehicleID)] = 1 -- Insert vehicle in own map
		println("ID is same as received ID, syncing vehicle gameVehicleID: "..gameVehicleID.." with ServerID: "..serverVehicleID)
	else
		if not vehicleName then return end
		println("New vehicle : "..vehicleName)
		--if decodedData[9] == "null" then print("oh no meow 3:") return end

		local pos = vec3(jsonDecode(decodedData[9]))
		local rot = quat(jsonDecode(decodedData[10]))
		local spawnedVeh = spawn.spawnVehicle(vehicleName, serialize(vehicleConfig), pos, rot, ColorF(c[1],c[2],c[3],c[4]), ColorF(cP0[1],cP0[2],cP0[3],cP0[4]), ColorF(cP1[1],cP1[2],cP1[3],cP1[4]), "multiplayerVeh", true)
		--insertVehicleMap(spawnedVeh:getID(), serverVehicleID) -- Insert new vehicle ID in map
		--dump(vehiclesMap[spawnedVeh:getID()])
		nicknameMap[tostring(spawnedVeh:getID())] = {}
		nicknameMap[tostring(spawnedVeh:getID())].nickname = playerNickname
		nicknameMap[tostring(spawnedVeh:getID())].role = playerRole
		insertVehicleMap(spawnedVeh:getID(), serverVehicleID) -- Insert new vehicle ID in map
	end

	if currentVeh then be:enterVehicle(0, currentVeh) end -- Camera fix
end
--================================= ON VEHICLE SPAWNED (SERVER) ===================================

--================================= ON VEHICLE SPAWNED (CLIENT) ===================================
local function onVehicleSpawned(gameVehicleID)
	local veh = be:getObjectByID(gameVehicleID)
	print(veh.isMP)
	print(ownMap[tostring(gameVehicleID)])
	print(vehiclesMap[tostring(gameVehicleID)])
	if ownMap[tostring(gameVehicleID)] ~= 1 and vehiclesMap[tostring(gameVehicleID)] == nil then		print("[BeamMP] Vehicle Spawned: "..gameVehicleID)
		local veh = be:getObjectByID(gameVehicleID)
		if first then
			first = false
			--commands.setFreeCamera() -- Fix camera
			--veh:delete() -- Remove it
			print("[BeamMP] First Session Vehicle Removed, Maybe now request the vehicles in the game?")
			--if commands.isFreeCamera(player) then commands.setGameCamera() end -- Fix camera
			UI.ready("FIRSTVEH") -- Solve session setup without UI sending ready status
			--onMPSessionInit()
		else
			veh:queueLuaCommand("extensions.addModulePath('lua/vehicle/extensions/BeamMP')") -- Load lua files
			veh:queueLuaCommand("extensions.loadModulesInDirectory('lua/vehicle/extensions/BeamMP')")
			--if Network.getStatus() > 0 and not getServerVehicleID(gameVehicleID) then -- If is connecting or connected
			if GameNetwork.connectionStatus() == 1 and not getServerVehicleID(gameVehicleID) then -- If TCP connected
				sendVehicle(gameVehicleID) -- Send it to the server
				if isOwn(gameVehicleID) then
					veh:queueLuaCommand("powertrainVE.sendAllPowertrain()")
				end
			end
		end
	else
		print("[BeamMP] Vehicle Edited: "..gameVehicleID)
		syncTimer=0
		syncVehIDs[gameVehicleID] = 1
	end
end
--================================= ON VEHICLE SPAWNED (CLIENT) ===================================



--================================= ON VEHICLE REMOVED (SERVER) ===================================
local function onServerVehicleRemoved(serverVehicleID)
	local gameVehicleID = getGameVehicleID(serverVehicleID) -- Get game ID
	if gameVehicleID then
		local veh = be:getObjectByID(gameVehicleID) -- Get associated vehicle
		if veh and gameVehicleID then
			onVehicleDestroyedAllowed = false
			commands.setFreeCamera() -- Fix camera
			veh:delete() -- Remove it
			if commands.isFreeCamera(player) then commands.setGameCamera() end -- Fix camera
		end
	else
		println("gameVehicleID for serverVehicleID "..serverVehicleID.." not found. (onServerVehicleRemoved)")
		--data = Network.split(data, ":")                                                                   -- TODO Solve How this works
		--[[if playerServerID and gameVehicleID then -- 1:host playerID - 2:host gameVehicleID
			if CoreNetwork.getPlayerServerID() == playerServerID then
				be:getObjectByID(gameVehicleID):delete()
			end
		end]]
	end
end
--================================= ON VEHICLE REMOVED (SERVER) ===================================



--================================= ON VEHICLE REMOVED (CLIENT) ===================================
local function onVehicleDestroyed(gameVehicleID)
	print("Vehicle destroyed : "..gameVehicleID)
	if GameNetwork.connectionStatus() == 1 then -- If TCP connected
		if onVehicleDestroyedAllowed then -- If function is not coming from onServerVehicleRemoved then
			local serverVehicleID = getServerVehicleID(tostring(gameVehicleID)) -- Get the serverVehicleID
			if serverVehicleID then
				GameNetwork.send('Od:'..serverVehicleID)--Network.buildPacket(1, 2121, serverVehicleID, ""))
			end
		else
			onVehicleDestroyedAllowed = true
		end
	end
end
--================================= ON VEHICLE REMOVED (CLIENT) ===================================



--======================= ON VEHICLE SWITCHED (CLIENT) =======================
local function onVehicleSwitched(oldID, newID)
	--print("Vehicle switched : "..oldID.." - "..newID)
	if GameNetwork.connectionStatus() == 1 then -- If TCP connected
		local newID = getServerVehicleID(newID) -- Get new serverVehicleID of the new vehicle the player is driving
		if newID then -- If it's not null
			GameNetwork.send('Om:'..newID)--Network.buildPacket(1, 2122, newID, ""))
		end
	end
end
--======================= ON VEHICLE SWITCHED (CLIENT) =======================



--======================= ON VEHICLE RESETTED (CLIENT) =======================
local function onVehicleResetted(gameVehicleID)
	--print("Vehicle resetted : "..gameVehicleID)
	if GameNetwork.connectionStatus() == 1 then -- If TCP connected
		local serverVehicleID = getServerVehicleID(gameVehicleID) -- Get new serverVehicleID of the new vehicle the player is driving
		if serverVehicleID and isOwn(gameVehicleID) then -- If serverVehicleID not null and player own vehicle -- If it's not null
			--Network.send(Network.buildPacket(1, 2123, serverVehicleID, ""))
			local veh = be:getObjectByID(gameVehicleID)
			local pos = veh:getPosition()
			local rot = veh:getRotation()

			local tempTable = {}
			tempTable['pos'] = {}
			tempTable['pos'].x = tonumber(pos.x)
			tempTable['pos'].y = tonumber(pos.y)
			tempTable['pos'].z = tonumber(pos.z)
			tempTable['ang'] = {}
			tempTable['ang'].x = tonumber(rot.x)
			tempTable['ang'].y = tonumber(rot.y)
			tempTable['ang'].z = tonumber(rot.z)
			tempTable['ang'].w = tonumber(rot.w)
			GameNetwork.send('Or:'..serverVehicleID..":"..jsonEncode(tempTable).."")
		end
	end
end
--======================= ON VEHICLE RESETTED (CLIENT) =======================



--======================= ON VEHICLE RESETTED (SERVER) =======================
local function onServerVehicleResetted(serverVehicleID, data)
	local gameVehicleID = getGameVehicleID(serverVehicleID) -- Get game ID
	if gameVehicleID then
		local veh = be:getObjectByID(gameVehicleID) -- Get associated vehicle
		if veh and gameVehicleID then
			local pr = jsonDecode(data) -- Decoded data
			veh:reset()
			if pr ~= nil then
				veh:setPositionRotation(pr.pos.x, pr.pos.y, pr.pos.z, pr.ang.x, pr.ang.y, pr.ang.z, pr.ang.w) -- Apply position
			else
				if settings.getValue("showDebugOutput") == true then
			    print('[vehicleGE] pr == nil for onServerVehicleResetted()')
				end
			end
		end
	else
		println("gameVehicleID for serverVehicleID "..serverVehicleID.." not found. (onServerVehicleResetted)")
		--GameNetwork.send('On:'..serverVehicleID) -- Handled by server now.
	end
end
--======================= ON VEHICLE RESETTED (SERVER) =======================

local function handle(rawData)
	-- the data will be the first opt then the data followed
	--print('vehicleGE:'..rawData)
	local code = string.sub(rawData, 1, 1)
	local rawData = string.sub(rawData, 3)
	if code == "s" then
		local playerRole = string.match(rawData,"(%w+)%:")
		print(playerRole)
		rawData = rawData:gsub(playerRole..":", "")
		local playerNickname = string.match(rawData,"^.-:")
		playerNickname = playerNickname:sub(1, #playerNickname - 1)
		print(playerNickname)
		rawData = rawData:gsub(playerNickname..":", "")
		local serverVehicleID = string.match(rawData,"^.-:")
		serverVehicleID = serverVehicleID:sub(1, #serverVehicleID - 1)
		print(serverVehicleID)
		print(rawData)
		local data = string.match(rawData,":(.*)")
		print("Player Name: "..playerNickname..", PlayerRole: "..playerRole..", serverVehicleID: "..serverVehicleID..", Data: "..data)
		onServerVehicleSpawned(playerRole, playerNickname, serverVehicleID, data)
	end

	if code == "c" then -- This is for the customisation of a vehicle event
		local serverVehicleID = string.match(rawData,"^.-:")
		serverVehicleID = serverVehicleID:sub(1, #serverVehicleID - 1)
		print(serverVehicleID)
		print(rawData)
		local data = string.match(rawData,":(.*)")
		UpdateVehicle(serverVehicleID, data)
	end

	if code == "r" then -- This is for vehicle reset event
		local serverVehicleID = string.match(rawData,"^.-:")
		serverVehicleID = serverVehicleID:sub(1, #serverVehicleID - 1)
		local data = string.match(rawData,":(.*)")
		--local data = string.match(rawData,":(.*)")
		--print("serverVehicleID: "..serverVehicleID..", Data: "..data)
		onServerVehicleResetted(serverVehicleID, data)
	end

	if code == "d" then
		local serverVehicleID = rawData -- TODO Finish this code to remove all for player ID if we do not get a -XXX id for the specific car (in the case it was not handled by the server)
		if serverVehicleID:match("-") then
			print("serverVehicleID: "..serverVehicleID.." was removed on owners end.")
			onServerVehicleRemoved(serverVehicleID)
		else
			print("serverVehicleID: "..serverVehicleID.." was removed on owners end.")
			onServerVehicleRemoved(serverVehicleID)
		end
	end
end

local function removeRequest(gameVehicleID)
	if isOwn(gameVehicleID) then
		core_vehicles.removeCurrent(); extensions.hook("trackNewVeh")
		print("[BeamMP] request to remove car id "..gameVehicleID.." DONE")
	else
		print("[BeamMP] request to remove car id "..gameVehicleID.." DENIED")
	end
end

local function setCurrentVehicle(gameVehicleID)
	if activeVehicle ~= gameVehicleID then
		println("Current vehicle: "..gameVehicleID)
	end
	activeVehicle = gameVehicleID
end


function setTires(shouldHaveTires)
	for i = 0, be:getObjectCount() do
		local veh = be:getObject(i)
		if veh then
			local gameVehicleID = veh:getID()
			if not isOwn(gameVehicleID) then
				veh:queueLuaCommand("vehicleVE.setTires("..tostring(shouldHaveTires)..")")
			end
		end
	end
end

local function onUpdate(dt)
	if GameNetwork.connectionStatus() == 1 then -- If TCP connected
		if be:getObjectCount() == 0 then return end -- If no vehicle do nothing
		local shouldSync = false

		local localPos = nil
		for i = 0, be:getObjectCount() do -- Find at least one local player car
			local veh = be:getObject(i)
			if veh and isOwn(veh:getID()) then
				localPos = veh:getPosition()
			end
		end

		if activeVehicle ~= nil then
			--print("currveh:")
			--print(tostring(currentVehicle))
			local veh = be:getObjectByID(tonumber(activeVehicle))
			if veh ~= nil then
				--print("veh:")
				localPos = veh:getPosition()
				--print(tostring(localPos.x).." "..tostring(localPos.y).." "..tostring(localPos.z))
			end
		end

		for i = 0, be:getObjectCount() do -- For each vehicle
			local veh = be:getObject(i) --  Get vehicle
			if veh then -- For loop always return one empty vehicle ?
				local gameVehicleID = veh:getID()
				if not isOwn(gameVehicleID) and nicknameMap[tostring(gameVehicleID)] ~= nil and settings.getValue("showNameTags") == true then
					local pos = veh:getPosition()
					pos.z = pos.z + 2.0
					local forecolor = ColorF(1,1,1,1)
					local backcolor = ColorI(0,0,0,127)
					local tag = ""
					local dist = ""
					local vehIDstr = tostring(gameVehicleID)
					--[[
						USER = Default
						EA = Early Access
						YT = YouTuber
						ET = Events Team
						SUPPORT = Support
						MOD = Moderator
						ADM = Admin
						GDEV = BeamNG Staff
						MDEV = MP Dev
					]]
					--print(dump(nicknameMap[tostring(veh:getID())]))
					if nicknameMap[vehIDstr].role == "USER" then
						forecolor = ColorF(1, 1, 1, 1)
						backcolor = ColorI(0, 0, 0, 127)
						tag = ""
					elseif nicknameMap[vehIDstr].role == "EA" then
						forecolor = ColorF(155/255, 89/255, 182/255, 255/255)
						backcolor = ColorI(69, 0, 150, 127)
						tag = " [Early Access]"
					elseif nicknameMap[vehIDstr].role == "YT" then
						forecolor = ColorF(255/255, 0, 0, 255/255)
						backcolor = ColorI(200, 0, 0, 127)
						tag = " [YouTuber]"
					elseif nicknameMap[vehIDstr].role == "ET" then
						forecolor = ColorF(210/255, 214/255, 109/255, 255/255)
						backcolor = ColorI(210, 214, 109, 127)
						tag = " [Events Team]"
					elseif nicknameMap[vehIDstr].role == "SUPPORT" then
						forecolor = ColorF(68/255, 109/255, 184/255, 255/255)
						backcolor = ColorI(68, 109, 184, 127)
						tag = " [Support]"
					elseif nicknameMap[vehIDstr].role == "MOD" then
						forecolor = ColorF(68/255, 109/255, 184/255, 255/255)
						backcolor = ColorI(68, 109, 184, 127)
						tag = " [Moderator]"
					elseif nicknameMap[vehIDstr].role == "ADM" then
						forecolor = ColorF(218/255, 0, 78/255, 255/255)
						backcolor = ColorI(200, 0, 65, 127)
						tag = " [Admin]"
					elseif nicknameMap[vehIDstr].role == "GDEV" then
						forecolor = ColorF(252/255, 107/255, 3/255, 255/255)
						backcolor = ColorI(252, 107, 3, 127)
						tag = " [BeamNG Staff]"
					elseif nicknameMap[vehIDstr].role == "MDEV" then
						forecolor = ColorF(194/255, 55/255, 55/255, 255/255)
						backcolor = ColorI(194, 55, 55, 127)
						tag = " [MP DEV]"
					end

					--if settings.getValue("nameTagAlternate") == true then  -- Color the background instead of foreground
					--	backcolor = ColorI(0,0,0,127)
					--else
						forecolor = ColorF(1,1,1,1)
					--end


					if settings.getValue("nameTagColorPicker") or false == true then  -- This part was used for debugging and is disabled in the settings HTML page

						forecolor = ColorF(settings.getValue("nameTagColorR")/255,settings.getValue("nameTagColorG")/255,settings.getValue("nameTagColorB")/255,settings.getValue("nameTagColorA")/255)
						backcolor = ColorI(settings.getValue("nameTagBgR"),settings.getValue("nameTagBgG"),settings.getValue("nameTagBgB"),settings.getValue("nameTagBgA"))
					end

					if localPos ~= nil and activeVehicle ~= vehIDstr and settings.getValue("nameTagShowDistance") then
						local distfloat = math.sqrt(math.pow(localPos.x-pos.x, 2) + math.pow(localPos.y-pos.y, 2) + math.pow(localPos.z-pos.z-2.0, 2))
						if distfloat > 20 then
							if settings.getValue("uiUnitLength") == "imperial" then
								distfloat = distfloat * 3.28084
								dist = " "..tostring(math.floor(distfloat)).." ft"
							else
								dist = " "..tostring(math.floor(distfloat)).." m"
							end
						end
					end

					debugDrawer:drawTextAdvanced(
						pos, -- Position in 3D
						String(" "..tostring(nicknameMap[vehIDstr].nickname)..tag..dist.." "), -- Text
						forecolor, true, false, -- Foreground Color / Background / Wtf
						backcolor -- Background Color
					)
					
					
					
					
				end


				if syncVehIDs[gameVehicleID] ~= nil and syncVehIDs[gameVehicleID] ~= 0 then
				
					print("veh id "..gameVehicleID.." has value "..syncVehIDs[gameVehicleID].." in the sync table")

					syncTimer = syncTimer+dt
					if syncTimer > 10 then
						shouldSync = true
						syncTimer = 0
					end
					if shouldSync then
						print("[BeamMP] Autosyncing car ID "..gameVehicleID)
						veh:queueLuaCommand("obj:queueGameEngineLua(\"vehicleGE.sendCustomVehicleData("..gameVehicleID..", '\"..jsonEncode(v.config)..\"')\")")
						syncVehIDs[gameVehicleID] = nil
					end
				end
			end
		end
	end
end

M.setTires				  = setTires
M.setCurrentVehicle		  = setCurrentVehicle
M.removeRequest			  = removeRequest
M.onUpdate                = onUpdate
M.handle                  = handle
M.onVehicleSwitched       = onVehicleSwitched
M.onDisconnect            = onDisconnect
M.isOwn                   = isOwn
M.getOwnMap               = getOwnMap
M.getGameVehicleID        = getGameVehicleID
M.getServerVehicleID      = getServerVehicleID
M.onVehicleDestroyed      = onVehicleDestroyed
M.onVehicleSpawned        = onVehicleSpawned
M.deleteAllVehicles       = deleteAllVehicles
M.sendAllVehicles         = sendAllVehicles
M.sendVehicle             = sendVehicle
M.sendVehicleData         = sendVehicleData
M.sendCustomVehicleData   = sendCustomVehicleData
M.onServerVehicleSpawned  = onServerVehicleSpawned
M.onServerVehicleRemoved  = onServerVehicleRemoved
M.onVehicleResetted       = onVehicleResetted
M.onServerVehicleResetted = onServerVehicleResetted


print("vehicleGE Loaded.")
return M
