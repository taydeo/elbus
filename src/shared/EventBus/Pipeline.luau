--!strict

--- Ordered transformation pipeline for intra-process events.
---
--- A Pipeline<T> passes a payload through a sequence of registered handlers.
--- Each handler either passes the payload through (optionally transforming it)
--- or rejects the pipeline entirely.
---
--- Use this when multiple systems each need a veto or a chance to modify
--- a value before it is considered accepted. The caller gets back a
--- PipelineResult describing success or the reason for cancellation.
---
--- Use Signal for one-way notifications where no transformation or rejection
--- is needed.

local Signal = require(script.Parent.Signal)

type Connection = Signal.Connection

--- A handler receives the current payload and returns either:
---   (true, payload, nil)     -- accepted, pipeline continues with this payload
---   (false, nil, reason)     -- rejected, pipeline aborts immediately
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

local Pipeline = {}

function Pipeline.new<T>(): Pipeline<T>
	type Entry = { handler: Handler<T>, priority: number }
	local entries: { Entry } = {}
	local completed = Signal.new() :: Signal.Signal<T>

	local function register(handler: Handler<T>, priority: number?): Connection
		local p = priority or 0
		local entry: Entry = { handler = handler, priority = p }

		-- Insert in descending priority order.
		-- Equal-priority handlers run in registration order (stable).
		local idx = #entries + 1
		for i, e in entries do
			if p > e.priority then
				idx = i
				break
			end
		end
		table.insert(entries, idx, entry)

		local conn: Connection
		conn = {
			Connected = true,
			Disconnect = function(self: Connection)
				if not self.Connected then return end
				self.Connected = false
				local i = table.find(entries, entry)
				if i then
					table.remove(entries, i)
				end
			end,
			Destroy = function(self: Connection)
				self:Disconnect()
			end,
		}
		return conn
	end

	local pipeline: Pipeline<T> = {
		Completed = completed,

		Register = function(_self: Pipeline<T>, handler: Handler<T>, priority: number?): Connection
			return register(handler, priority)
		end,

		Fire = function(_self: Pipeline<T>, payload: T): PipelineResult<T>
			if #entries == 0 then
				warn("[Pipeline] Fire called with no handlers registered")
			end
			local current: T = payload
			for _, entry in entries do
				local ok, result, reason = entry.handler(current)
				if not ok then
					if not reason then
						warn("[Pipeline] Handler rejected without providing a reason string")
					end
					return { ok = false, cancelled = true, reason = reason, payload = nil }
				end
				current = result :: T
			end
			completed:Fire(current)
			return { ok = true, cancelled = false, reason = nil, payload = current }
		end,
	}

	return pipeline
end

return Pipeline
