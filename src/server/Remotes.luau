-- Remotes: creates (server) or finds (client) the one folder of
-- RemoteEvents the game talks through. Client -> server requests are
-- intents only ("LockRequest", "RebirthRequest"); every rule is checked
-- again on the server. Server -> client traffic is display state
-- ("HudUpdate") and one-line feedback ("Toast").

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local NAMES = {
	"LockRequest", -- client asks to lock its own base
	"RebirthRequest", -- client asks to rebirth
	"HudUpdate", -- server pushes income / rebirth / lock / event state
	"Toast", -- server pushes a one-line message for one player (or all)
}

function Remotes.Get(): { [string]: RemoteEvent }
	local folder = ReplicatedStorage:FindFirstChild("IslandRemotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "IslandRemotes"
		for _, name in NAMES do
			local event = Instance.new("RemoteEvent")
			event.Name = name
			event.Parent = folder
		end
		folder.Parent = ReplicatedStorage
	end
	local out: { [string]: RemoteEvent } = {}
	for _, name in NAMES do
		out[name] = folder:WaitForChild(name) :: RemoteEvent
	end
	return out
end

return Remotes
