--!strict

--- Network signal constructors for the Events domain.
---
--- Instead of services touching RemoteEvents directly, each Events file
--- declares its signals with a direction and the transport is handled here.
---
---   Net.server<T>(name)           -- server fires, clients receive (reliable)
---   Net.client<T>(name, validator) -- client fires, server receives (reliable, validated)
---
---   Net.serverUnreliable<T>(name)           -- same as server, but UnreliableRemoteEvent
---   Net.clientUnreliable<T>(name, validator) -- same as client, but UnreliableRemoteEvent
---
--- Use unreliable variants for high-frequency data where dropped packets are
--- acceptable: character position, aim direction, visual effects.
--- Use reliable variants for anything that must arrive: ability use, item pickup.
---
--- Services and controllers only ever see Signal-like objects.
--- RemoteEvents never leave the Events file.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(script.Parent.Parent.EventBus.Signal)

type Connection = Signal.Connection
type Validator<T> = (unknown) -> (boolean, T?)

local IS_SERVER = RunService:IsServer()

local function getRemote(name: string, unreliable: boolean?): RemoteEvent
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		if IS_SERVER then
			folder = Instance.new("Folder")
			folder.Name = "Remotes"
			folder.Parent = ReplicatedStorage
		else
			folder = ReplicatedStorage:WaitForChild("Remotes")
		end
	end
	if IS_SERVER then
		local existing = folder:FindFirstChild(name)
		if existing then return existing :: RemoteEvent end
		local className = if unreliable then "UnreliableRemoteEvent" else "RemoteEvent"
		local remote = Instance.new(className) :: RemoteEvent
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	return (folder :: Instance):WaitForChild(name) :: RemoteEvent
end

-- ServerSignal: server fires, clients receive.
export type ServerSignal<T> = {
	Fire: (self: ServerSignal<T>, payload: T) -> (),
	FireTo: (self: ServerSignal<T>, player: Player, payload: T) -> (),
	Connect: (self: ServerSignal<T>, callback: (payload: T) -> ()) -> Connection,
	Once: (self: ServerSignal<T>, callback: (payload: T) -> ()) -> Connection,
	Wait: (self: ServerSignal<T>) -> T,
}

-- ClientSignal: client fires, server receives. Player is injected into callbacks.
export type ClientSignal<T> = {
	Fire: (self: ClientSignal<T>, payload: T) -> (),
	Connect: (self: ClientSignal<T>, callback: (player: Player, payload: T) -> ()) -> Connection,
	Once: (self: ClientSignal<T>, callback: (player: Player, payload: T) -> ()) -> Connection,
}

local Net = {}

function Net.server<T>(name: string): ServerSignal<T>
	local remote = getRemote(name)
	local relay = Signal.new() :: Signal.Signal<T>

	if not IS_SERVER then
		remote.OnClientEvent:Connect(function(raw)
			relay:Fire(raw :: T)
		end)
	end

	return {
		Fire = function(_self, payload: T)
			if IS_SERVER then
				remote:FireAllClients(payload)
			end
		end,
		FireTo = function(_self, player: Player, payload: T)
			if IS_SERVER then
				remote:FireClient(player, payload)
			end
		end,
		Connect = function(_self, callback)
			return relay:Connect(callback)
		end,
		Once = function(_self, callback)
			return relay:Once(callback)
		end,
		Wait = function(_self): T
			return relay:Wait()
		end,
	}
end

function Net.client<T>(name: string, validate: Validator<T>): ClientSignal<T>
	local remote = getRemote(name)
	type Wrapped = { player: Player, data: T }
	local relay = Signal.new() :: Signal.Signal<Wrapped>

	if IS_SERVER then
		remote.OnServerEvent:Connect(function(player, raw)
			local ok, data = validate(raw)
			if not ok then
				warn(string.format("[Net:%s] Invalid payload from %s (%d) - dropping", name, player.DisplayName, player.UserId))
				return
			end
			relay:Fire({ player = player, data = data :: T })
		end)
	end

	return {
		Fire = function(_self, payload: T)
			if not IS_SERVER then
				remote:FireServer(payload)
			end
		end,
		Connect = function(_self, callback)
			return relay:Connect(function(wrapped)
				callback(wrapped.player, wrapped.data)
			end)
		end,
		Once = function(_self, callback)
			return relay:Once(function(wrapped)
				callback(wrapped.player, wrapped.data)
			end)
		end,
	}
end

function Net.serverUnreliable<T>(name: string): ServerSignal<T>
	local remote = getRemote(name, true)
	local relay = Signal.new() :: Signal.Signal<T>

	if not IS_SERVER then
		remote.OnClientEvent:Connect(function(raw)
			relay:Fire(raw :: T)
		end)
	end

	return {
		Fire = function(_self, payload: T)
			if IS_SERVER then
				remote:FireAllClients(payload)
			end
		end,
		FireTo = function(_self, player: Player, payload: T)
			if IS_SERVER then
				remote:FireClient(player, payload)
			end
		end,
		Connect = function(_self, callback)
			return relay:Connect(callback)
		end,
		Once = function(_self, callback)
			return relay:Once(callback)
		end,
		Wait = function(_self): T
			return relay:Wait()
		end,
	}
end

function Net.clientUnreliable<T>(name: string, validate: Validator<T>): ClientSignal<T>
	local remote = getRemote(name, true)
	type Wrapped = { player: Player, data: T }
	local relay = Signal.new() :: Signal.Signal<Wrapped>

	if IS_SERVER then
		remote.OnServerEvent:Connect(function(player, raw)
			local ok, data = validate(raw)
			if not ok then
				warn(string.format("[Net:%s] Invalid payload from %s (%d) - dropping", name, player.DisplayName, player.UserId))
				return
			end
			relay:Fire({ player = player, data = data :: T })
		end)
	end

	return {
		Fire = function(_self, payload: T)
			if not IS_SERVER then
				remote:FireServer(payload)
			end
		end,
		Connect = function(_self, callback)
			return relay:Connect(function(wrapped)
				callback(wrapped.player, wrapped.data)
			end)
		end,
		Once = function(_self, callback)
			return relay:Once(function(wrapped)
				callback(wrapped.player, wrapped.data)
			end)
		end,
	}
end

return Net
