--!strict

local Players = game:GetService("Players")

--- Server-side authority checks.
---
--- Authority is separate from schema validation:
---   Schema  = is the data the right shape?
---   Authority = is this player allowed to do this right now?
---
--- Usage:
---
---   local checkAbility = Authority.all({
---       Authority.rateLimit(2),
---       function(player, payload)
---           if not hasAbility(player, payload.abilityId) then
---               return false, "not unlocked"
---           end
---           return true
---       end,
---   })
---
---   local ok, reason = checkAbility(player, payload)
---   if not ok then return end

--- A check returns true to allow, or false + reason to deny.
export type Check<T> = (player: Player, payload: T) -> (boolean, string?)

--- Run a list of checks in order. Returns on the first failure.
local function all<T>(checks: { Check<T> }): Check<T>
	return function(player: Player, payload: T): (boolean, string?)
		for _, check in checks do
			local ok, reason = check(player, payload)
			if not ok then
				return false, reason or "denied"
			end
		end
		return true, nil
	end
end

--- Allow at most `max` calls per player per second.
--- State is captured in the closure so each rateLimit() call is independent.
local function rateLimit<T>(max: number): Check<T>
	type Bucket = { count: number, resetAt: number }
	local buckets: { [number]: Bucket } = {}

	Players.PlayerRemoving:Connect(function(player)
		buckets[player.UserId] = nil
	end)

	return function(player: Player, _payload: T): (boolean, string?)
		local now = os.clock()
		local bucket = buckets[player.UserId]

		if not bucket or now >= bucket.resetAt then
			buckets[player.UserId] = { count = 1, resetAt = now + 1 }
			return true, nil
		end

		if bucket.count >= max then
			return false, "rate limit exceeded"
		end

		bucket.count += 1
		return true, nil
	end
end

--- Allow each player to pass at most once. Useful for one-time setup requests.
local function once<T>(): Check<T>
	local seen: { [number]: boolean } = {}

	return function(player: Player, _payload: T): (boolean, string?)
		if seen[player.UserId] then
			return false, "already called"
		end
		seen[player.UserId] = true
		return true, nil
	end
end

return {
	all = all,
	rateLimit = rateLimit,
	once = once,
}
