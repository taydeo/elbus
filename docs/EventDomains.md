# Event Domains

An event domain is a single ModuleScript that owns everything related to a logical area of the game: payload types, signals, pipelines, and network transport. Nothing is spread across multiple files. Adding a new event means adding to (or creating) a domain file.

## Three scopes

### Shared - server and client both see it

Lives in `ReplicatedStorage/Events/`. Used for events that cross the network or need to be referenced on both sides.

```luau
-- ReplicatedStorage/Events/CombatEvents.luau
return table.freeze({
    PlayerDied = Signal.new() :: Signal<PlayerDiedPayload>,             -- local only, server internal
    DamageDealt = Net.server("CombatDamage") :: Net.ServerSignal<...>,  -- server -> clients
    AbilityUsed = Net.client("CombatAbility", validator) :: Net.ClientSignal<...>, -- client -> server
})
```

### Server-only

Lives in `ServerScriptService/Events/`. Clients cannot access this location. Used for signals and pipelines that are purely internal to the server.

```luau
-- ServerScriptService/Events/FoodEvents.luau
return table.freeze({
    EatAttempt   = Pipeline.new() :: Pipeline<EatAttemptPayload>,
    ItemConsumed = Signal.new() :: Signal<ItemConsumedPayload>,
})
```

### Client-only

Lives in `StarterPlayerScripts/Events/` (or `StarterCharacterScripts/Events/`). Used for signals internal to the client - UI state, local effects, input handling.

```luau
-- StarterPlayerScripts/Events/HUDEvents.luau
return table.freeze({
    HealthChanged = Signal.new() :: Signal<{ current: number, max: number }>,
    AbilityReady  = Signal.new() :: Signal<{ abilityId: string }>,
})
```

## Anatomy of a domain file

```luau
--!strict

local Signal = require(game.ReplicatedStorage.EventBus.Signal)
local Pipeline = require(game.ReplicatedStorage.EventBus.Pipeline)
local Bus = require(game.ReplicatedStorage.EventBus.Bus)

-- local type aliases to avoid Signal.Signal<T> double-name
type Signal<T> = Signal.Signal<T>
type Pipeline<T> = Pipeline.Pipeline<T>

-- 1. Payload types
export type MyPayload = { ... }

-- 2. Signal and Pipeline instances
local MySignal = Signal.new() :: Signal<MyPayload>
local MyPipeline = Pipeline.new() :: Pipeline<MyPayload>

-- 3. Register with Bus (optional, for observability)
Bus.watch("MyDomain.MySignal",   MySignal)
Bus.watch("MyDomain.MyPipeline", MyPipeline.Completed)

-- 4. Freeze and return
return table.freeze({
    MySignal = MySignal,
    MyPipeline = MyPipeline,
})
```

## Rules

- **Payload types are exported** (`export type`) so consuming modules can reference them without re-declaring.
- **RemoteEvents never leave the domain file.** `Net.server` and `Net.client` handle transport internally. Services and controllers never call `:FireServer` or `:FireClient` directly.
- **One require, shared instance.** Roblox caches module results, so every script that requires the same domain file gets the same Signal/Pipeline instances. Connections made in one script are visible to all others.
- **Bus registration is optional.** Only register events you want observed globally. Private internal signals can stay unwatched.

## Choosing Signal vs Pipeline

| Situation | Use |
|-----------|-----|
| Something happened, notify listeners | Signal |
| Something was requested, systems need to validate or transform it | Pipeline |
| A client sent data to the server | Net.client (ClientSignal) |
| The server needs to push state to clients | Net.server (ServerSignal) |
| Continuous per-frame client input | SimInput |

## Example: adding a new server event

1. Open or create the relevant domain file in `ServerScriptService/Events/`.
2. Add the payload type and a `Signal.new()` or `Pipeline.new()`.
3. Optionally register with `Bus.watch`.
4. The service that owns the event fires it. Other services listen.
