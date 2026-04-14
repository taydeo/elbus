# SimInput

`ReplicatedStorage.Simulation.SimInput`

Typed wrapper around Roblox's `InputAction` API for server authority inputs. Used when a client needs to send continuous input state (movement, aim) to the server under the new server authority model, rather than firing RemoteEvents.

## Required workspace properties

SimInput will error at startup if these are not enabled:

```
Workspace.PlayerScriptsUseInputActionSystem = true
Workspace.UseFixedSimulation = true
Workspace.NextGenerationReplication = true
Workspace.SignalBehavior = Deferred
```

## SimInput type

```luau
export type SimInput<T> = {
    name: string,
    Fire: (self: SimInput<T>, value: T) -> (),           -- client only
    ReadFrom: (self: SimInput<T>, player: Player) -> T?,     -- server only, inside BindToSimulation
}
```

## Constructors

```luau
SimInput.bool(name) :: SimInput<boolean>  -- Bool
SimInput.axis(name) :: SimInput<number>   -- Direction1D (e.g. throttle -1 to 1)
SimInput.axis2D(name) :: SimInput<Vector2>  -- Direction2D (e.g. look delta)
SimInput.axis3D(name) :: SimInput<Vector3>  -- Direction3D (e.g. move direction)
SimInput.viewportPos(name) :: SimInput<Vector2>  -- ViewportPosition (screen coords)
```

## Usage

Declare inputs in a shared inputs file:

```luau
-- ReplicatedStorage/Inputs/MovementInputs.luau
local SimInput = require(game.ReplicatedStorage.Simulation.SimInput)
type SimInput<T> = SimInput.SimInput<T>

return table.freeze({
    MoveDirection = SimInput.axis3D("MoveDirection") :: SimInput<Vector3>,
    Sprinting = SimInput.bool("Sprinting") :: SimInput<boolean>,
})
```

Client fires the input each frame:

```luau
-- inside a client script
MovementInputs.MoveDirection:Fire(moveVector)
MovementInputs.Sprinting:Fire(isSprintHeld)
```

Server reads inside `BindToSimulation`:

```luau
-- inside a server script
local Simulation = require(game.ReplicatedStorage.Simulation.Simulation)

Simulation.bind(function(dt)
    for _, player in Players:GetPlayers() do
        local move = MovementInputs.MoveDirection:ReadFrom(player)
        local sprint = MovementInputs.Sprinting:ReadFrom(player)
        if move then
            applyMovement(player, move, sprint, dt)
        end
    end
end)
```

## Notes

- `InputAction` instances are created under a `SimInputs` folder on each player. The server creates them; the client waits for them.
- For complex inputs that combine multiple values (fire direction + trigger), declare multiple SimInputs and read them together inside `BindToSimulation`.
- SimInput is not a replacement for RemoteEvents. Use it only for continuous per-frame input under the server authority model. For discrete actions (ability use, item pickup), use `Net.client`.

## See also

- [Simulation](https://create.roblox.com/docs/projects/server-authority) - Roblox server authority docs
