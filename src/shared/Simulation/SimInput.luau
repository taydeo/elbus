--!strict

--- Simulation-bound input annotation.
---
--- SimInput<T> marks an input as belonging to the new server authority API
--- (InputAction + BindToSimulation) rather than the RemoteEvent path.
---
--- InputAction only carries five fixed value types. SimInput constructors
--- map to those exactly:
---
---   SimInput.bool(name)        -> Bool        (boolean)
---   SimInput.axis(name)        -> Direction1D  (number, e.g. throttle)
---   SimInput.axis2D(name)      -> Direction2D  (Vector2, e.g. look delta)
---   SimInput.axis3D(name)      -> Direction3D  (Vector3, e.g. move direction)
---   SimInput.viewportPos(name) -> ViewportPosition (Vector2, screen position)
---
--- For complex inputs (e.g. "fire + aim direction"), declare multiple SimInputs
--- and read them together inside BindToSimulation.
---
--- Client: call input:Fire(value) to send to server
--- Server (inside BindToSimulation): call input:ReadFrom(player) to poll current value
---
--- REQUIRED: the following Workspace properties must be enabled or this module
--- will error at runtime:
---   Workspace.PlayerScriptsUseInputActionSystem = true
---   Workspace.UseFixedSimulation = true
---   Workspace.NextGenerationReplication = true
---   Workspace.SignalBehavior = Deferred

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Fail fast with a clear message if the required beta flags are off.
-- Without these, InputAction does not exist and Enum.InputActionType is nil.
do
	local ok = pcall(function()
		local _ = Enum.InputActionType
	end)
	if not ok then
		error(
			[[[SimInput] Enum.InputActionType not found. Enable these Workspace properties before using SimInput: PlayerScriptsUseInputActionSystem, UseFixedSimulation, NextGenerationReplication, SignalBehavior = Deferred]],
			2
		)
	end
end

export type SimInput<T> = {
	name: string,
	-- Client: fires the InputAction with the given value.
	Fire: (self: SimInput<T>, value: T) -> (),
	-- Server/simulation: polls the current value for a specific player.
	-- Call this inside a BindToSimulation callback.
	ReadFrom: (self: SimInput<T>, player: Player) -> T?,
}

type InputTypeName = "Bool" | "Direction1D" | "Direction2D" | "Direction3D" | "ViewportPosition"

local IS_SERVER = RunService:IsServer()

local function getContext(player: Player): Instance
	local ctx = player:FindFirstChild("SimInputs")
	if not ctx then
		if IS_SERVER then
			local folder = Instance.new("Folder")
			folder.Name = "SimInputs"
			folder.Parent = player
			return folder
		else
			return player:WaitForChild("SimInputs")
		end
	end
	return ctx
end

local function getAction(player: Player, name: string, typeName: InputTypeName): InputAction
	local ctx = getContext(player)
	local action = ctx:FindFirstChild(name)
	if not action then
		if IS_SERVER then
			-- Server creates the InputAction instance under the player.
			local inst = Instance.new("InputAction") :: InputAction
			inst.Name = name
			inst.Type = Enum.InputActionType[typeName]
			inst.Parent = ctx
			return inst
		else
			return ctx:WaitForChild(name) :: InputAction
		end
	end
	return action :: InputAction
end

local function makeInput<T>(name: string, typeName: InputTypeName): SimInput<T>
	-- On the server, create InputActions for all current and future players.
	if IS_SERVER then
		local function setup(player: Player)
			getAction(player, name, typeName)
		end
		for _, player in Players:GetPlayers() do
			setup(player)
		end
		Players.PlayerAdded:Connect(setup)
	end

	return {
		name = name,

		Fire = function(_self: SimInput<T>, value: T)
			if IS_SERVER then return end
			local action = getAction(Players.LocalPlayer, name, typeName)
			action:Fire(value :: any)
		end,

		ReadFrom = function(_self: SimInput<T>, player: Player): T?
			local ctx = player:FindFirstChild("SimInputs")
			if not ctx then return nil end
			local action = ctx:FindFirstChild(name)
			if not action then return nil end
			return (action :: InputAction):GetState() :: T
		end,
	}
end

local SimInput = {}

function SimInput.bool(name: string): SimInput<boolean>
	return makeInput(name, "Bool") :: SimInput<boolean>
end

function SimInput.axis(name: string): SimInput<number>
	return makeInput(name, "Direction1D") :: SimInput<number>
end

function SimInput.axis2D(name: string): SimInput<Vector2>
	return makeInput(name, "Direction2D") :: SimInput<Vector2>
end

function SimInput.axis3D(name: string): SimInput<Vector3>
	return makeInput(name, "Direction3D") :: SimInput<Vector3>
end

function SimInput.viewportPos(name: string): SimInput<Vector2>
	return makeInput(name, "ViewportPosition") :: SimInput<Vector2>
end

return SimInput
