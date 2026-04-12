# Schema

`ReplicatedStorage.Network.Schema`

Runtime validator primitives for untrusted client payloads. Used exclusively at network boundaries - anywhere a client can send arbitrary data to the server.

## Validator type

```luau
export type Validator<T> = (value: unknown) -> (boolean, T?)
```

A validator takes an unknown value and returns `(true, value)` typed as `T` if valid, or `(false, nil)` if not.

## Primitives

```luau
S.string()   -- Validator<string>
S.number()   -- Validator<number>
S.boolean()  -- Validator<boolean>
S.integer()  -- Validator<number>, rejects non-integers
S.Vector3()  -- Validator<Vector3>
S.CFrame()   -- Validator<CFrame>
```

## Composites

### record

Validates a table with named keys, each with its own validator. Extra keys are ignored. Missing required keys fail.

```luau
S.record({
    userId = S.number(),
    abilityId = S.string(),
    target = S.optional(S.Vector3()),
})
```

### array

Validates a homogeneous array where every element passes the given validator.

```luau
S.array(S.string())   -- { string }
S.array(S.number())   -- { number }
```

### optional

Wraps any validator to also accept nil.

```luau
S.optional(S.Vector3())  -- Validator<Vector3?>
```

### literal

Accepts a fixed set of values.

```luau
S.literal("Melee", "Projectile", "Explosion")
```

### union

Passes if any one of the given validators succeeds.

```luau
S.union(S.string(), S.number())
```

### range

Numbers only, within [min, max] inclusive.

```luau
S.range(0, 100)  -- clamped percentage
```

### match

Strings only, matching a Lua pattern.

```luau
S.match("^%a+$")  -- letters only
```

### custom

Wraps a plain boolean predicate into a validator. Use when none of the primitives cover your case.

```luau
S.custom(function(v)
    return type(v) == "number" and v > 0 and v == math.floor(v)
end)
```

With an explicit type parameter when T is not inferrable:

```luau
S.custom<UserId>(function(v)
    return type(v) == "number" and v > 0
end)
```

### transform

Runs a validator then maps the result. Useful for clamping or normalising incoming data.

```luau
S.transform(S.number(), function(n)
    return math.clamp(n, 0, 100)
end)
```

## Composing validators

Validators compose naturally:

```luau
S.record({
    position = S.Vector3(),
    health = S.range(0, 100),
    tags = S.array(S.literal("fire", "ice", "poison")),
    name = S.optional(S.match("^%a[%a%d_]+$")),
})
```

## Usage with Net.client

Pass a validator as the second argument to `Net.client`. It runs automatically on every incoming payload before the server handler sees it.

```luau
Net.client("CombatAbility", S.record({
    userId = S.number(),
    abilityId = S.string(),
})) :: Net.ClientSignal<AbilityUsedPayload>
```

Invalid payloads are dropped with a warning. The client is not notified.
