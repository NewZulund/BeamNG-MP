--====================================================================================
-- All work by Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================

local M = {}

local players = {}

print("UI Initialising...")


-- setLanguage() -- language setting in case its not in the base game list
local function setLanguage()
  local lang = settings.getValue("userLanguageMP")
  if lang ~= "" and lang ~= settings.getValue("userLanguage") then
	print('setting language to: ' .. lang)
	be:executeJS('setLanguage(\''..lang..'\');')
  end
end


local function updateLoading(data)
  --print(data)
  local code = string.sub(data, 1, 1)
  local msg = string.sub(data, 2)

  if code == "l" then
    guihooks.trigger('LoadingInfo', {
      message = msg
    })
  end
end

local function typeof(var)
    local _type = type(var);
    if(_type ~= "table" and _type ~= "userdata") then
        return _type;
    end
    local _meta = getmetatable(var);
    if(_meta ~= nil and _meta._NAME ~= nil) then
        return _meta._NAME;
    else
        return _type;
    end
end

local function split(s, sep)
    local fields = {}

    local sep = sep or " "
    local pattern = string.format("([^%s]+)", sep)
    string.gsub(s, pattern, function(c) fields[#fields + 1] = c end)

    return fields
end

local function updatePlayersList(playersString)
  --print(playersString)
  local players = split(playersString, ",")
  --print(dump(players))
  be:executeJS('playerList(\''..jsonEncode(players)..'\');')
end

local function setPing(ping)
  if tonumber(ping) > -1 then
	be:executeJS('setPing("'..ping..' ms")')
  end
end

local function setNickName(name)
  --print("My Nickname: "..name)
	be:executeJS('setNickname("'..name..'")')
end

local function setStatus(status)
	be:executeJS('setStatus("'..status..'")')
end

local function setPlayerCount(playerCount)
	be:executeJS('setPlayerCount("'..playerCount..'")')
end

local function error(text)
	print("UI Error > "..text)
	ui_message(''..text, 10, 0, 0)
end

local function message(text)
	print("[Message] > "..text)
	ui_message(''..text, 10, 0, 0)
end

local function showNotification(type, text)
  if text == nil then
    message(type)
  else
    if type == "error" then
      error(text)
    else
      message(text)
    end
  end
end

local function chatMessage(rawMessage, sendWhole)
  local message = rawMessage
  if sendWhole == nil then
	message = string.sub(rawMessage, 2)
  end
  be:executeJS('addMessage("'..message..'")')
end

local function chatSend(msg)
  local c = 'C:'..mpConfig.getNickname()..": "..msg
  print(c)
  GameNetwork.send(c)
end

local ready = true

local function ready(src)
  print("UI / Game Has now loaded ("..src..")")
  -- Now start the TCP connection to the launcher to allow the sending and receiving of the vehicle / session data
  if src == "MP-SESSION" or src == "FIRSTVEH" then
	if ready then
	  ready = false
	  GameNetwork.connectToLauncher()
	  
	  if CoreNetwork.Server.NAME ~= nil then
		setStatus("Server: "..CoreNetwork.Server.NAME)
	  end
	end
  end
end

local function readyReset()
  ready = true
end

M.updateLoading = updateLoading
M.updatePlayersList = updatePlayersList
M.ready = ready
M.readyReset = readyReset
M.setPing = setPing
M.setNickName = setNickName
M.setStatus = setStatus
M.chatMessage = chatMessage
M.chatSend = chatSend
M.setPlayerCount = setPlayerCount
M.showNotification = showNotification

print("UI Loaded.")
return M
