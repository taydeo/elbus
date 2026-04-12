# Bus

`ReplicatedStorage.EventBus.Bus`

Global broadcast bus for cross-cutting observers. Logging, analytics, and debugging systems subscribe once to `Bus.Fired` and receive every event that has been registered with `Bus.watch`.

Payloads arrive as `unknown`. Observers are not expected to care about types - only event names and raw data for serialization or logging.

## API

```luau
Bus.Fired: Signal.Signal<BusEvent>

Bus.watch(name: string, signal: Signal.Signal<any>)
```

```luau
export type BusEvent = {
    name: string,
    payload: unknown,
}
```

## Watching a Signal

```luau
local Bus = require(game.ReplicatedStorage.EventBus.Bus)

Bus.watch("FoodEvents.ItemConsumed", ItemConsumed)
```

## Watching a Pipeline

Point at `pipeline.Completed` - Bus never needs to know about Pipeline directly. Cancelled pipelines are not broadcast.

```luau
Bus.watch("FoodEvents.EatAttempt", EatAttempt.Completed)
```

## Registering in a domain file

Wire up Bus.watch at the bottom of the domain file so observers get everything from one place.

```luau
-- ServerScriptService/Events/FoodEvents.luau
local Bus = require(game.ReplicatedStorage.EventBus.Bus)

local EatAttempt = Pipeline.new() :: Pipeline<EatAttemptPayload>
local ItemConsumed = Signal.new() :: Signal<ItemConsumedPayload>

Bus.watch("FoodEvents.EatAttempt",   EatAttempt.Completed)
Bus.watch("FoodEvents.ItemConsumed", ItemConsumed)

return table.freeze({ EatAttempt = EatAttempt, ItemConsumed = ItemConsumed })
```

## Subscribing as an observer

```luau
local Bus = require(game.ReplicatedStorage.EventBus.Bus)

Bus.Fired:Connect(function(event: Bus.BusEvent)
    print(event.name, game:GetService("HttpService"):JSONEncode(event.payload))
end)
```

## Notes

- Bus is per-context. A server Bus and a client Bus are separate instances - they do not communicate across the network.
- Only events explicitly registered with `Bus.watch` are broadcast. Internal signals you do not want observed simply stay unwatched.
