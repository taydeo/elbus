# Pipeline

`ReplicatedStorage.EventBus.Pipeline`

Ordered transformation pipeline for intra-process events. A payload passes through a sequence of registered handlers. Each handler either passes the payload through (optionally transforming it) or rejects the pipeline with a reason.

Use Pipeline when multiple systems each need a veto or a chance to modify a value before it is considered accepted. Use Signal for plain notifications that nothing needs to reject.

## Types

```luau
export type Handler<T> = (payload: T) -> (boolean, T?, string?)

export type PipelineResult<T> = {
    ok: boolean,
    cancelled: boolean,
    reason: string?,
    payload: T?,
}

export type Pipeline<T> = {
    Register: (self: Pipeline<T>, handler: Handler<T>, priority: number?) -> Connection,
    Fire: (self: Pipeline<T>, payload: T) -> PipelineResult<T>,
    Completed: Signal.Signal<T>,
}
```

## Constructor

```luau
Pipeline.new<T>(): Pipeline<T>
```

Same expression-cast rule as Signal:

```luau
EatAttempt = Pipeline.new() :: Pipeline<EatAttemptPayload>
```

## Handler return values

A handler returns three values:

```luau
-- pass through unchanged
return true, payload, nil

-- pass through transformed
return true, { table.unpack(payload), nutrition = payload.nutrition * 1.5 }, nil

-- reject - reason is required
return false, nil, "item is rotten"
```

A warning is emitted at runtime if a handler rejects without providing a reason string.

## Priority

Handlers run highest priority first. Priority is optional and defaults to 0.

```luau
-- runs first - fast rejection before anything else
FoodEvents.EatAttempt:Register(rottenCheck, 900)

-- runs second
FoodEvents.EatAttempt:Register(edibleCheck, 500)

-- runs last - only reached if all checks pass
FoodEvents.EatAttempt:Register(satiateTransform)
```

Handlers with equal priority run in registration order. A warning is emitted if `Fire` is called with no handlers registered.

## PipelineResult

```luau
local result = FoodEvents.EatAttempt:Fire(payload)

if result.cancelled then
    warn("eat rejected:", result.reason)
    return
end

-- result.payload is the final transformed payload
applyEat(result.payload)
```

| Field | Type | Description |
|-------|------|-------------|
| ok | boolean | true if all handlers passed |
| cancelled | boolean | true if any handler rejected |
| reason | string? | rejection reason, nil on success |
| payload | T? | final transformed payload, nil on rejection |

## Completed signal

`pipeline.Completed` fires with the final payload after every successful `Fire`. Use this to wire the pipeline into the Bus or to attach post-success listeners without polling the result.

```luau
Bus.watch("FoodEvents.EatAttempt", FoodEvents.EatAttempt.Completed)
```

Cancelled pipelines do not fire `Completed`.

## Disconnecting a handler

`Register` returns a `Connection`. Disconnect it to remove the handler from the pipeline.

```luau
local conn = FoodEvents.EatAttempt:Register(handler, 500)

-- later
conn:Disconnect()
```
