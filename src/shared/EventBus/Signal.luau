--!strict

--- Typed signal built with closures instead of metatables.
---
--- Closures let Luau resolve the generic T without any `:: any` casts on
--- the returned object, which is what causes payload to show as `any` in
--- the language server.
---
--- Construction in event modules:
---   local OnDied = Signal.new() :: Signal<DiedPayload>
---
--- The cast must be on the expression, not the variable declaration.
--- Luau does not propagate variable annotations backwards into generic calls.

export type Connection = {
	Disconnect: (self: Connection) -> (),
	Destroy: (self: Connection) -> (), -- alias so any Maid that checks for :Destroy() works
	Connected: boolean,
}

export type Signal<T> = {
	Connect: (self: Signal<T>, callback: (payload: T) -> ()) -> Connection,
	Once: (self: Signal<T>, callback: (payload: T) -> ()) -> Connection,
	Fire: (self: Signal<T>, payload: T) -> (),
	DisconnectAll: (self: Signal<T>) -> (),
	Wait: (self: Signal<T>) -> T,
}

local function new<T>(): Signal<T>
	local callbacks: { (T) -> () } = {}

	local function removeCallback(target: (T) -> ())
		for i, cb in callbacks do
			if cb == target then
				table.remove(callbacks, i)
				return
			end
		end
	end

	local function connect(callback: (T) -> ()): Connection
		table.insert(callbacks, callback)
		-- The self-referential Connection type requires one cast here,
		-- isolated to connection creation and not the signal itself.
		local conn: Connection
		conn = {
			Connected = true,
			Disconnect = function(self: Connection)
				if not self.Connected then
					return
				end
				self.Connected = false
				removeCallback(callback)
			end,
			Destroy = function(self: Connection)
				self:Disconnect()
			end,
		}
		return conn
	end

	local signal: Signal<T> = {
		Connect = function(_self: Signal<T>, callback: (T) -> ()): Connection
			return connect(callback)
		end,

		Once = function(_self: Signal<T>, callback: (T) -> ()): Connection
			local conn: Connection
			conn = connect(function(payload: T)
				conn:Disconnect()
				callback(payload)
			end)
			return conn
		end,

		Fire = function(_self: Signal<T>, payload: T)
			-- Snapshot before iterating so Disconnect inside a callback is safe.
			local snapshot = table.clone(callbacks)
			for _, cb in snapshot do
				cb(payload)
			end
		end,

		DisconnectAll = function(_self: Signal<T>)
			table.clear(callbacks)
		end,

		Wait = function(_self: Signal<T>): T
			local co = coroutine.running()
			assert(co, "Signal:Wait() must be called from inside a coroutine")
			connect(function(payload: T)
				coroutine.resume(co, payload)
			end)
			return coroutine.yield() :: T
		end,
	}

	return signal
end

return { new = new }
