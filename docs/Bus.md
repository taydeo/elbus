# Bus

`ReplicatedStorage.Common.EventBus.Signal`

Global broadcast bus for cross-cutting observers. Logging, analytics, and debugging systems subscribe once to `Signal.Fired` and receive every event registered with `Signal.watch`.

Payloads arrive as `unknown`. Observers are not expected to care about types.

Bus is per-context. A server bus and a client bus are separate instances.

## API

```luau
Signal.Fired: Signal<BusEvent>

Signal.watch(name: string, signal: Signal<any>)
```

```luau
export type BusEvent = {
    name: string,
    payload: unknown,
}
```

## Watching a Signal

```luau
local Signal = require(game.ReplicatedStorage.Common.EventBus.Signal)

Signal.watch("FoodEvents.ItemConsumed", ItemConsumed)
```

## Watching a Pipeline

```luau
Signal.watch("FoodEvents.EatAttempt", EatAttempt.Completed)
```

## Registering in a domain file

Wire up `Signal.watch` at the bottom of the domain file so observers get everything from one place.

```luau
-- ServerScriptService/Events/FoodEvents.luau
local Signal = require(game.ReplicatedStorage.Common.EventBus.Signal)
local Pipeline = require(game.ReplicatedStorage.Common.EventBus.Pipeline)
type Signal<T> = Signal.Signal<T>
type Pipeline<T> = Pipeline.Pipeline<T>

local EatAttempt = Pipeline.new() :: Pipeline<EatAttemptPayload>
local ItemConsumed = Signal.new() :: Signal<ItemConsumedPayload>

Signal.watch("FoodEvents.EatAttempt",   EatAttempt.Completed)
Signal.watch("FoodEvents.ItemConsumed", ItemConsumed)

return table.freeze({ EatAttempt = EatAttempt, ItemConsumed = ItemConsumed })
```

## Subscribing as an observer

```luau
local Signal = require(game.ReplicatedStorage.Common.EventBus.Signal)

Signal.Fired:Connect(function(event: Signal.BusEvent) -- or use a local type alias
    print(event.name, game:GetService("HttpService"):JSONEncode(event.payload))
end)
```

## Notes

- Only events explicitly registered with `Signal.watch` are broadcast. Internal signals you do not want observed simply stay unwatched.
