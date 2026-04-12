# Authority

`ServerScriptService.Authority`

Server-side request validation. Composable checks that run before any game logic processes a client request. Only available on the server.

## Check type

```luau
type Check<T> = (player: Player, payload: T) -> (boolean, string?)
```

A check receives the player and payload and returns `(true)` to allow or `(false, "reason")` to deny.

## Composing checks

### all

Runs every check in order. Fails on the first denial.

```luau
local checkAbility = Authority.all({
    Authority.rateLimit(2),
    function(player, payload)
        local character = player.Character
        if not character then
            return false, "no character"
        end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then
            return false, "dead"
        end
        return true
    end,
})
```

## Built-in checks

### rateLimit

```luau
Authority.rateLimit(maxPerSecond: number): Check<any>
```

Tracks request counts per player using a token bucket. Returns `(false, "rate limit exceeded")` when the player exceeds `maxPerSecond` requests in the last second.

### once

```luau
Authority.once(): Check<any>
```

Allows a player through exactly once. Subsequent calls from the same player are denied. Useful for one-time setup requests.

## Usage in a service

Build the check once at the top of the service, then call it inside the event handler.

```luau
-- CombatService.server.luau
local checkAbility = Authority.all({
    Authority.rateLimit(2),
    function(player, payload)
        -- custom game logic check
        return true
    end,
})

CombatEvents.AbilityUsed:Connect(function(player, payload)
    local ok, reason = checkAbility(player, payload)
    if not ok then
        warn(player.DisplayName, "denied:", reason)
        return
    end

    -- safe to process
end)
```

## Notes

- Authority checks run after Schema validation. By the time a check sees a payload, it is already type-safe.
- Checks are pure functions - they should read state but not modify it. Side effects belong in the handler after the check passes.
- Rate limits are per-service-instance, not global. Two services with `rateLimit(2)` each allow 2 requests per second independently.
