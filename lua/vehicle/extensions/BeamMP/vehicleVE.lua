--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}

local function applyPartConfig(data)
	local decodedData = jsonDecode(data) -- Decode received data
	tableMerge(v.config, decodedData)
	obj:respawn(serialize(v.config))
end

local function updateGFX(dt)
	if playerInfo.firstPlayerSeated then
		obj:queueGameEngineLua("vehicleGE.setCurrentVehicle(\'"..obj:getID().."\')")
		--print("current car: "..obj:getID())
	end
end

obj:queueGameEngineLua("electricsGE.setReady(\'"..obj:getID().."\')")

M.applyPartConfig	= applyPartConfig
M.updateGFX			= updateGFX

return M
