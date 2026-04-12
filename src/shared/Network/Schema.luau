--!strict

--- Runtime validator primitives.
---
--- A Validator<T> is a function that takes an unknown value and returns
--- (ok, value) where value is typed as T if ok is true.
---
--- Validators are used at network boundaries where Luau's type system
--- cannot make guarantees (RemoteEvent payloads from clients).

export type Validator<T> = (value: unknown) -> (boolean, T?)

local Schema = {}

function Schema.string(): Validator<string>
	return function(value: unknown): (boolean, string?)
		if type(value) == "string" then
			return true, value
		end
		return false, nil
	end
end

function Schema.number(): Validator<number>
	return function(value: unknown): (boolean, number?)
		if type(value) == "number" then
			return true, value
		end
		return false, nil
	end
end

function Schema.boolean(): Validator<boolean>
	return function(value: unknown): (boolean, boolean?)
		if type(value) == "boolean" then
			return true, value
		end
		return false, nil
	end
end

function Schema.integer(): Validator<number>
	return function(value: unknown): (boolean, number?)
		if type(value) == "number" and value == math.floor(value) then
			return true, value
		end
		return false, nil
	end
end

function Schema.Vector3(): Validator<Vector3>
	return function(value: unknown): (boolean, Vector3?)
		if typeof(value) == "Vector3" then
			return true, value
		end
		return false, nil
	end
end

function Schema.CFrame(): Validator<CFrame>
	return function(value: unknown): (boolean, CFrame?)
		if typeof(value) == "CFrame" then
			return true, value
		end
		return false, nil
	end
end

--- Accepts a fixed set of string values.
function Schema.literal<T>(...)
	local allowed: { unknown } = { ... }
	return function(value: unknown): (boolean, T?)
		for _, v in allowed do
			if value == v then
				return true, value :: T
			end
		end
		return false, nil
	end
end

--- Makes any validator accept nil as a valid value.
function Schema.optional<T>(validator: Validator<T>): Validator<T?>
	return function(value: unknown): (boolean, T?)
		if value == nil then
			return true, nil
		end
		return validator(value)
	end
end

--- Validates a plain table where each key has its own validator.
--- Extra keys in the incoming table are silently ignored.
--- Missing required keys cause validation to fail.
function Schema.record<T>(shape: { [string]: Validator<any> }): Validator<T>
	return function(value: unknown): (boolean, T?)
		if type(value) ~= "table" then
			return false, nil
		end
		local result: { [string]: any } = {}
		for key, validator in shape do
			local ok, validated = validator((value :: any)[key])
			if not ok then
				return false, nil
			end
			result[key] = validated
		end
		return true, result :: T
	end
end

--- Validates a homogeneous array where every element passes the given validator.
function Schema.array<T>(validator: Validator<T>): Validator<{ T }>
	return function(value: unknown): (boolean, { T }?)
		if type(value) ~= "table" then
			return false, nil
		end
		local result: { T } = {}
		for i, item in value :: { unknown } do
			if type(i) ~= "number" then
				return false, nil
			end
			local ok, validated = validator(item)
			if not ok then
				return false, nil
			end
			result[i] = validated :: T
		end
		return true, result
	end
end

--- Wraps a plain predicate into a Validator.
--- Use this to write custom validators without manually handling the return tuple.
---
---   local validUserId = S.custom(function(v)
---       return type(v) == "number" and v > 0 and v == math.floor(v)
---   end)
function Schema.custom<T>(check: (value: unknown) -> boolean): Validator<T>
	return function(value: unknown): (boolean, T?)
		if check(value) then
			return true, value :: T
		end
		return false, nil
	end
end

--- Passes only numbers within [min, max] inclusive.
function Schema.range(min: number, max: number): Validator<number>
	return function(value: unknown): (boolean, number?)
		if type(value) == "number" and value >= min and value <= max then
			return true, value
		end
		return false, nil
	end
end

--- Passes only strings that match the given Lua pattern.
function Schema.match(pattern: string): Validator<string>
	return function(value: unknown): (boolean, string?)
		if type(value) == "string" and string.match(value, pattern) ~= nil then
			return true, value
		end
		return false, nil
	end
end

--- Passes if the value satisfies any one of the given validators.
--- Returns the result of the first validator that succeeds.
function Schema.union<T>(...: Validator<T>): Validator<T>
	local validators: { Validator<T> } = { ... }
	return function(value: unknown): (boolean, T?)
		for _, validator in validators do
			local ok, result = validator(value)
			if ok then
				return true, result
			end
		end
		return false, nil
	end
end

--- Runs a validator then transforms the value if it passes.
--- Useful for normalising incoming data (e.g. clamping a number, trimming a string).
function Schema.transform<TIn, TOut>(validator: Validator<TIn>, fn: (TIn) -> TOut): Validator<TOut>
	return function(value: unknown): (boolean, TOut?)
		local ok, result = validator(value)
		if not ok then
			return false, nil
		end
		return true, fn(result :: TIn)
	end
end

return Schema
