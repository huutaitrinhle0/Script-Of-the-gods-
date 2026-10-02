-- OwnerKeyGuard.server.lua
-- Put this Script in ServerScriptService.
-- IMPORTANT: enable Game Settings -> Security -> Allow HTTP Requests.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VERIFY_URL = "https://YOUR-VERCEL-DOMAIN.vercel.app/api/verify"
local SUBMIT_EVENT_NAME = "OwnerKey_Submit"
local OWNER_COMMAND_EVENT_NAME = "OwnerKey_Command"

-- Optional second lock for owner commands. Replace with the owner's Roblox UserId.
local OWNER_USER_ID = 123456789

local REQUEST_COOLDOWN = 3
local PENDING_TIMEOUT = 45
local MAX_COMMAND_LENGTH = 180

local state = {}
local lastRequest = {}
local commandCooldown = {}

local remotes = ReplicatedStorage:FindFirstChild("OwnerKeyRemotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "OwnerKeyRemotes"
	remotes.Parent = ReplicatedStorage
end

local submitEvent = remotes:FindFirstChild(SUBMIT_EVENT_NAME)
if not submitEvent then
	submitEvent = Instance.new("RemoteEvent")
	submitEvent.Name = SUBMIT_EVENT_NAME
	submitEvent.Parent = remotes
end

local commandEvent = remotes:FindFirstChild(OWNER_COMMAND_EVENT_NAME)
if not commandEvent then
	commandEvent = Instance.new("RemoteEvent")
	commandEvent.Name = OWNER_COMMAND_EVENT_NAME
	commandEvent.Parent = remotes
end

local function kick(player, reason)
	if player and player.Parent == Players then
		player:Kick(reason or "Key verification failed.")
	end
end

local function isOwner(player)
	return player.UserId == OWNER_USER_ID and state[player] and state[player].owner == true
end

local function verifyKey(player, suppliedKey)
	if type(suppliedKey) ~= "string" then
		kick(player, "Invalid key format.")
		return false
	end

	local key = string.upper(suppliedKey:match("^%s*(.-)%s*$") or "")
	if not key:match("^KEY%-[A-Z0-9]+%-[A-Z0-9]+%-[A-Z0-9]+$") then
		kick(player, "Fake/invalid key detected.")
		return false
	end

	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < REQUEST_COOLDOWN then
		kick(player, "Too many key verification requests.")
		return false
	end
	lastRequest[player] = now

	local payload = HttpService:JSONEncode({
		key = key,
		ownerId = tostring(player.UserId), -- NEVER trust ownerId from the client.
	})

	local ok, response = pcall(function()
		return HttpService:RequestAsync({
			Url = VERIFY_URL,
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
			},
			Body = payload,
		})
	end)

	if not ok or not response or not response.Success then
		kick(player, "Key verification service unavailable.")
		return false
	end

	local decodedOk, data = pcall(function()
		return HttpService:JSONDecode(response.Body)
	end)

	if not decodedOk or type(data) ~= "table" or data.valid ~= true then
		kick(player, "Fake/expired/revoked key detected.")
		return false
	end

	state[player] = {
		verified = true,
		owner = data.ownerOnly == true and player.UserId == OWNER_USER_ID,
		key = key,
		verifiedAt = os.time(),
		expiresAt = data.expiresAt,
	}

	player:SetAttribute("KeyVerified", true)
	player:SetAttribute("KeyOwner", state[player].owner)
	player:SetAttribute("KeyExpiresAt", data.expiresAt or "N/A")

	return true
end

submitEvent.OnServerEvent:Connect(function(player, key)
	verifyKey(player, key)
end)

local function findPlayer(token)
	local textToken = string.lower(tostring(token or ""))
	for _, player in ipairs(Players:GetPlayers()) do
		if tostring(player.UserId) == textToken or string.lower(player.Name) == textToken or string.lower(player.DisplayName) == textToken then
			return player
		end
	end
end

local function kickFakePlayers(exceptPlayer)
	local count = 0
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= exceptPlayer then
			local s = state[player]
			if not s or s.verified ~= true then
				count += 1
				kick(player, "You were removed because your key was not verified.")
			end
		end
	end
	return count
end

local function handleOwnerCommand(ownerPlayer, raw)
	if not isOwner(ownerPlayer) then
		kick(ownerPlayer, "Owner command rejected.")
		return
	end

	if type(raw) ~= "string" then return end
	raw = raw:sub(1, MAX_COMMAND_LENGTH)
	if raw:sub(1, 1) ~= "!" then return end

	local parts = {}
	for part in raw:gmatch("%S+") do
		table.insert(parts, part)
	end

	local command = string.lower(parts[1] or "")

	if command == "!kickfake" or command == "!kickunverified" then
		local count = kickFakePlayers(ownerPlayer)
		ownerPlayer:SetAttribute("LastOwnerCommand", "Kicked " .. tostring(count) .. " unverified player(s)")
		return
	end

	if command == "!kick" then
		local target = findPlayer(parts[2])
		if not target then return end
		local reason = table.concat(parts, " ", 3)
		kick(target, reason ~= "" and reason or "Kicked by Owner")
		return
	end

	if command == "!verify" then
		local target = findPlayer(parts[2])
		if target then
			local s = state[target]
			ownerPlayer:SetAttribute("LastOwnerCommand", target.Name .. " verified=" .. tostring(s and s.verified == true))
		end
		return
	end
end

commandEvent.OnServerEvent:Connect(function(player, command)
	local now = os.clock()
	if commandCooldown[player] and now - commandCooldown[player] < 0.5 then
		return
	end
	commandCooldown[player] = now
	handleOwnerCommand(player, command)
end)

Players.PlayerAdded:Connect(function(player)
	state[player] = { verified = false, owner = false }
	player:SetAttribute("KeyVerified", false)
	player:SetAttribute("KeyOwner", false)
	player:SetAttribute("KeyExpiresAt", "N/A")

	task.delay(PENDING_TIMEOUT, function()
		if player.Parent == Players then
			local s = state[player]
			if not s or s.verified ~= true then
				kick(player, "No valid key was submitted.")
			end
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	state[player] = nil
	lastRequest[player] = nil
	commandCooldown[player] = nil
end)
