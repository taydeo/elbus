# Net

`ReplicatedStorage.Network.Net`

Network transport layer. Wraps RemoteEvents so that services and controllers never touch them directly. RemoteEvents are created and managed internally - they never leave the event domain file.

## Constructors

```luau
Net.server<T>(name: string): ServerSignal<T>
Net.client<T>(name: string, validate: Validator<T>): ClientSignal<T>

Net.serverUnreliable<T>(name: string): ServerSignal<T>
Net.clientUnreliable<T>(name: string, validate: Validator<T>): ClientSignal<T>
```

All four are called inside event domain files, not in services or controllers.

`serverUnreliable` and `clientUnreliable` use `UnreliableRemoteEvent` under the hood. The API is identical to the reliable variants. Use unreliable for high-frequency data where dropped packets are acceptable (position, aim direction, visual effects). Use reliable for anything that must arrive (ability use, item pickup, state changes).

## ServerSignal

Server fires, all clients (or a specific client) receive.

```luau
export type ServerSignal<T> = {
    Fire: (self: ServerSignal<T>, payload: T) -> (), -- fires to all clients
    FireTo: (self: ServerSignal<T>, player: Player, payload: T) -> (), -- fires to one client
    Connect: (self: ServerSignal<T>, callback: (payload: T) -> ()) -> Connection,
    Once: (self: ServerSignal<T>, callback: (payload: T) -> ()) -> Connection,
    Wait: (self: ServerSignal<T>) -> T,
}
```

`Fire` and `FireTo` only execute on the server. `Connect`, `Once`, and `Wait` only fire on the client.

## ClientSignal

Client fires, server receives. A Schema validator is required - it runs on every incoming payload and drops invalid ones before any game logic runs.

```luau
export type ClientSignal<T> = {
    Fire: (self: ClientSignal<T>, payload: T) -> (),
    Connect: (self: ClientSignal<T>, callback: (player: Player, payload: T) -> ()) -> Connection,
    Once: (self: ClientSignal<T>, callback: (player: Player, payload: T) -> ()) -> Connection,
}
```

`Fire` only executes on the client. `Connect` and `Once` only fire on the server, with `player` injected automatically.

Invalid payloads are silently dropped with a warning. The sending client is never informed.

## Usage in a domain file

```luau
-- ReplicatedStorage/Events/CombatEvents.luau
local Net = require(game.ReplicatedStorage.Network.Net)
local S = require(game.ReplicatedStorage.Network.Schema)

return table.freeze({
    -- server -> all clients
    DamageDealt = Net.server("CombatDamage") :: Net.ServerSignal<DamageDealtPayload>,

    -- client -> server, validated
    AbilityUsed = Net.client("CombatAbility", S.record({
        userId = S.number(),
        abilityId = S.string(),
        target = S.optional(S.Vector3()),
    })) :: Net.ClientSignal<AbilityUsedPayload>,
})
```

Note: do not pass explicit type arguments to `S.record` or `Net.client`. Luau parses `f<T>()` as a comparison at runtime. Use expression casts (`:: Type`) instead.

## RemoteEvent naming

The string name passed to `Net.server` or `Net.client` is the RemoteEvent name under `ReplicatedStorage.Remotes`. Keep names unique across the entire project.

## See also

- [Schema](Schema.md) - validator primitives for client payloads
- [Authority](Authority.md) - server-side checks to run after a ClientSignal fires
