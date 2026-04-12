--!strict

local Signal = require(script.Parent.Parent.EventBus.Signal)
type Signal<T> = Signal.Signal<T>

-- Payload types

export type PlayerJoinedPayload = {
	userId: number,
	displayName: string,
	accountAge: number,
}

export type PlayerLeftPayload = {
	userId: number,
	displayName: string,
	sessionDuration: number, -- seconds
}

export type PlayerRespawnedPayload = {
	userId: number,
	spawnLocation: Vector3,
}

-- Signals

local PlayerJoined = Signal.new() :: Signal<PlayerJoinedPayload>
local PlayerLeft = Signal.new() :: Signal<PlayerLeftPayload>
local PlayerRespawned = Signal.new() :: Signal<PlayerRespawnedPayload>

local bus = table.freeze({
	PlayerJoined = PlayerJoined,
	PlayerLeft = PlayerLeft,
	PlayerRespawned = PlayerRespawned,
})

return bus
