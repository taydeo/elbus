--!strict

--- Ordered transformation pipeline for intra-process events.
---
--- A Pipeline<T> passes a payload through a sequence of registered handlers.
--- Each handler either passes the payload through (optionally transforming it)
--- or rejects the pipeline entirely.
---
--- Use this when multiple systems each need a veto or a chance to modify
--- a value before it is considered accepted. The caller gets back the final
--- transformed payload, or false if any handler rejected.
---
--- Use Signal for one-way notifications where no transformation or rejection
--- is needed.

local Signal = require(script.Parent.Signal)

type Connection = Signal.Connection

--- A handler receives the current payload and returns either:
---   (true, payload)  -- accepted, pipeline continues with this payload
---   (false, nil)     -- rejected, pipeline aborts immediately
export type Handler<T> = (payload: T) -> (boolean, T?)

export type Pipeline<T> = {
	Register: (self: Pipeline<T>, handler: Handler<T>) -> Connection,
	Fire: (self: Pipeline<T>, payload: T) -> (boolean, T?),
}

local Pipeline = {}

function Pipeline.new<T>(): Pipeline<T>
	local handlers: { Handler<T> } = {}

	return {
		Register = function(_self: Pipeline<T>, handler: Handler<T>): Connection
			table.insert(handlers, handler)
			return {
				Connected = true,
				Disconnect = function(self: Connection)
					if not self.Connected then return end
					self.Connected = false
					local idx = table.find(handlers, handler)
					if idx then
						table.remove(handlers, idx)
					end
				end,
				Destroy = function(self: Connection)
					self:Disconnect()
				end,
			}
		end,

		Fire = function(_self: Pipeline<T>, payload: T): (boolean, T?)
			local current: T = payload
			for _, handler in handlers do
				local ok, result = handler(current)
				if not ok then
					return false, nil
				end
				current = result :: T
			end
			return true, current
		end,
	} :: Pipeline<T>
end

return Pipeline
