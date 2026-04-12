# Signal

`ReplicatedStorage.EventBus.Signal`

Typed in-process pub/sub primitive. The foundation of all local event communication in the framework. No metatables - closure-based so the Luau LSP resolves `T` correctly.

## Types

```luau
export type Connection = {
    Disconnect: (self: Connection) -> (),
    Destroy: (self: Connection) -> (), -- alias for Maid compatibility
    Connected: boolean,
}

export type Signal<T> = {
    Connect: (self: Signal<T>, callback: (payload: T) -> ()) -> Connection,
    Once: (self: Signal<T>, callback: (payload: T) -> ()) -> Connection,
    Fire: (self: Signal<T>, payload: T) -> (),
    DisconnectAll: (self: Signal<T>) -> (),
    Wait: (self: Signal<T>) -> T,
}
```

## Constructor

```luau
Signal.new<T>(): Signal<T>
```

The type parameter must be cast at the expression level. Luau does not propagate return type annotations backwards into generic calls.

```luau
-- correct
local PlayerDied = Signal.new() :: Signal<PlayerDiedPayload>

-- incorrect - T infers as unknown
local PlayerDied: Signal<PlayerDiedPayload> = Signal.new()
```

## Methods

### Connect

```luau
signal:Connect(function(payload: MyPayload)
    -- runs every time signal is fired
end)
```

Returns a `Connection`. Hold onto it if you need to disconnect later.

### Once

```luau
signal:Once(function(payload: MyPayload)
    -- runs once then disconnects automatically
end)
```

### Fire

```luau
signal:Fire(payload)
```

Calls all connected callbacks synchronously in connection order.

### Wait

```luau
local payload = signal:Wait()
```

Yields the current thread until the signal fires. Returns the payload.

### DisconnectAll

```luau
signal:DisconnectAll()
```

Disconnects every active connection on this signal.

## Connection management

```luau
local conn = signal:Connect(callback)

-- later
conn:Disconnect()
-- or
conn:Destroy() -- same thing, for Maid compatibility

print(conn.Connected) -- false after disconnect
```

## Usage in event domains

Signal instances live in event domain files, not in the modules that use them. See [Event Domains](EventDomains.md).

```luau
-- ServerScriptService/Events/RoundEvents.luau
local Signal = require(game.ReplicatedStorage.EventBus.Signal)
type Signal<T> = Signal.Signal<T>

return table.freeze({
    RoundStarted = Signal.new() :: Signal<RoundStartedPayload>,
    RoundEnded = Signal.new() :: Signal<RoundEndedPayload>,
})
```

The `type Signal<T> = Signal.Signal<T>` alias avoids the double-name `Signal.Signal<T>` when writing type annotations.
