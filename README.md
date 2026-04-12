# elbus

A strongly-typed event framework for Roblox. Allows you to create different types of checks for specific cases, run your logic through event buses and validates remote data automagically.

## Three transport modes

| Mode | Module | Direction | Use case |
|------|--------|-----------|----------|
| Local | Signal | in-process | module-to-module on server or client |
| Network | Net | server <-> client | game state replication, client requests |
| Simulation | SimInput | client -> server | character input under server authority |

## Studio structure

```
ReplicatedStorage/
  EventBus/
    Signal -- typed in-process signal primitive
    Pipeline -- ordered transformation pipeline primitive
    Bus -- global broadcast bus for observers
  Network/
    Net -- network transport (RemoteEvent abstraction)
    Schema -- runtime payload validators
  Simulation/
    SimInput -- InputAction wrapper for server authority inputs
    Simulation -- BindToSimulation wrapper
  Events/ -- shared event domains (server <-> client)
  Inputs/ -- SimInput declarations

ServerScriptService/
  Events/ -- server-only event domains
  Authority -- server-side request validation

StarterPlayer/StarterPlayerScripts/
  Events/ -- client-only event domains (add as needed)
```

## Quick examples

### In-process signal (server to server)

```luau
-- ServerScriptService/Events/RoundEvents.luau
return table.freeze({
    RoundStarted = Signal.new() :: Signal<RoundStartedPayload>,
})

-- RoundService: fire
RoundEvents.RoundStarted:Fire({ roundNumber = 1, mapName = "Highlands" })

-- SpawnSystem: listen
RoundEvents.RoundStarted:Connect(function(payload)
    spawnPlayers(payload.mapName)
end)
```

### Networked signal (server -> clients)

```luau
-- ReplicatedStorage/Events/CombatEvents.luau
DamageDealt = Net.server("CombatDamage") :: Net.ServerSignal<DamageDealtPayload>

-- Server fires, all clients receive automatically
CombatEvents.DamageDealt:Fire({ attackerId = 1, victimId = 2, amount = 10 })
```

### Validated client request (client -> server)

```luau
-- ReplicatedStorage/Events/CombatEvents.luau
AbilityUsed = Net.client("CombatAbility", S.record({
    userId = S.number(),
    abilityId = S.string(),
    target = S.optional(S.Vector3()),
})) :: Net.ClientSignal<AbilityUsedPayload>

-- Client fires
CombatEvents.AbilityUsed:Fire({ userId = Players.LocalPlayer.UserId, abilityId = "dash" })

-- Server receives with player injected, payload already validated
CombatEvents.AbilityUsed:Connect(function(player, payload)
    -- payload is guaranteed valid here
end)
```

### Transformation pipeline (server-only)

```luau
-- FoodEvents.EatAttempt passes through each system in priority order.
-- Any system can reject with a reason.

FoodEvents.EatAttempt:Register(function(payload)
    if payload.isRotten then
        return false, nil, "item is rotten"
    end
    return true, payload, nil
end, 900)

local result = FoodEvents.EatAttempt:Fire(payload)
if result.cancelled then
    print("rejected:", result.reason)
end
```

## Docs

- [Signal](docs/Signal.md)
- [Pipeline](docs/Pipeline.md)
- [Bus](docs/Bus.md)
- [Net](docs/Net.md)
- [Schema](docs/Schema.md)
- [Authority](docs/Authority.md)
- [SimInput](docs/SimInput.md)
- [Event Domains](docs/EventDomains.md)
