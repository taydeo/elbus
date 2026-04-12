--!strict

--- Wrapper around RunService:BindToSimulation().
---
--- Runs on both client and server. On the client, during a misprediction,
--- Roblox will re-run all bound functions from the last confirmed server
--- state forward. This is what makes client prediction work.
---
--- Usage:
---   Simulation.bind(function(dt)
---       for _, player in Players:GetPlayers() do
---           local dir = MoveInputs.Direction:ReadFrom(player)
---           if dir then
---               -- deterministic movement logic here
---           end
---       end
---   end)
---
--- Rules for code inside bind():
---   - Must be deterministic (same inputs = same outputs, always)
---   - Do not read os.clock(), tick(), or random() without a seeded generator
---   - Update state via Attributes on predicted instances, not via events
---   - Fire into the event bus AFTER the simulation step, not inside it

local RunService = game:GetService("RunService")

export type SimCallback = (dt: number) -> ()

local Simulation = {}

--- Bind a function to the simulation loop.
--- The callback runs every simulation frame on both client and server.
--- On misprediction, the engine re-runs it from the rollback point.
function Simulation.bind(callback: SimCallback)
	RunService:BindToSimulation(callback)
end

return Simulation
