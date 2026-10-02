-- OwnerKeyClient.local.lua
-- Optional LocalScript helper for the Owner Key system.
-- Put this LocalScript in StarterPlayerScripts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("OwnerKeyRemotes")
local submitEvent = remotes:WaitForChild("OwnerKey_Submit")
local commandEvent = remotes:WaitForChild("OwnerKey_Command")

_G.OwnerKeySubmit = function(key)
	submitEvent:FireServer(key)
end

_G.OwnerKeyCommand = function(command)
	commandEvent:FireServer(command)
end
