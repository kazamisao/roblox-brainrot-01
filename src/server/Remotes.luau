-- Remotes: the one folder of RemoteEvents the game talks through,
-- created here on the server and found by the client. Client ->
-- server traffic is intents only (the "Action" event carries words
-- like "rebirth" or "lock"); every rule behind an intent is checked
-- again on the server. Server -> client traffic is display state
-- (the "Hud" event) and one-line feedback (the "Toast" event).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local events: { [string]: RemoteEvent } = {}

local function makeEvent(name: string): RemoteEvent
	local ev = Instance.new("RemoteEvent")
	ev.Name = name
	ev.Parent = Remotes.Folder
	events[name] = ev
	return ev
end

function Remotes.Init()
	local folder = ReplicatedStorage:FindFirstChild("BrainrotRemotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "BrainrotRemotes"
		folder.Parent = ReplicatedStorage
	end
	Remotes.Folder = folder
	makeEvent("Hud")
	makeEvent("Toast")
	makeEvent("Action")
	makeEvent("Debug")
	makeEvent("Teleport")
end

function Remotes.Hud(player: Player, payload: { [string]: any })
	local ev = events.Hud
	if ev then
		ev:FireClient(player, payload)
	end
end

function Remotes.Toast(player: Player, text: string)
	local ev = events.Toast
	if ev then
		ev:FireClient(player, text)
	end
end

-- Bind the handler for client intents. The handler receives the
-- player and the action word; anything unrecognized is ignored by
-- the handler, never trusted.
function Remotes.OnAction(handler: (Player, string) -> ())
	local ev = events.Action
	if ev then
		ev.OnServerEvent:Connect(function(player: Player, action: any)
			if type(action) == "string" then
				handler(player, action)
			end
		end)
	end
end

-- The diagnostic report goes to everyone at once: the probe is
-- describing the shared world, not one player's state.
function Remotes.DebugAll(text: string)
	local ev = events.Debug
	if ev then
		ev:FireAllClients(text)
	end
end

-- Bind the handler for the client's "KE BELT" debug teleport. The
-- handler receives only the player; where they land is decided on
-- the server, never by the client.
function Remotes.OnTeleport(handler: (Player) -> ())
	local ev = events.Teleport
	if ev then
		ev.OnServerEvent:Connect(function(player: Player)
			handler(player)
		end)
	end
end

return Remotes
