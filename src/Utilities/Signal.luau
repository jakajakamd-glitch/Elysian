--!nonstrict
--[[
    Signal - a lightweight Lua-side event implementation modelled after
    Roblox's BindableEvent but without the overhead of an Instance.

    For RBXScriptSignal instances, prefer using the executor's `firesignal`
    and `replicatesignal` functions (when available) — see
    `Elysian.Signal.FireRBX` / `Elysian.Signal.ReplicateRBX` below.
]]

local Signal = {}
Signal.__index = Signal

export type Connection = {
    Disconnect: (Connection) -> (),
    _alive: boolean,
}

export type Signal = typeof(setmetatable({} :: {
    _handlers: { (...any) -> (...any) },
    _once: { (...any) -> (...any) },
}, Signal))

function Signal.new(): Signal
    return setmetatable({
        _handlers = {},
        _once = {},
    }, Signal) :: any
end

function Signal:Connect(callback: (...any) -> (...any)): Connection
    assert(typeof(callback) == "function", "Signal:Connect expects a function")
    table.insert(self._handlers, callback)
    local conn = { _alive = true }
    function conn:Disconnect()
        if not conn._alive then return end
        conn._alive = false
        local idx = table.find(self._handlers, callback)
        if idx then table.remove(self._handlers, idx) end
    end
    return conn
end

function Signal:Once(callback: (...any) -> (...any))
    table.insert(self._once, callback)
end

-- Fire the signal. (For RBXScriptSignal instances use Signal.FireRBX which
-- delegates to the executor's `firesignal`.)
function Signal:Fire(...: any)
    local n = #self._handlers
    if n == 0 and #self._once == 0 then return end
    -- Snapshot to allow safe disconnect-during-fire.
    local snapshot = {}
    for i = 1, n do
        snapshot[i] = self._handlers[i]
    end
    for i = 1, #snapshot do
        local cb = snapshot[i]
        local ok, err = pcall(cb, ...)
        if not ok then
            warn("[Elysian.Signal] handler error:", err)
        end
    end
    if #self._once > 0 then
        local once = self._once
        self._once = {}
        for _, cb in ipairs(once) do
            local ok, err = pcall(cb, ...)
            if not ok then
                warn("[Elysian.Signal] once-handler error:", err)
            end
        end
    end
end

function Signal:Wait(): ...any
    local thread = coroutine.running()
    local conn
    conn = self:Connect(function(...)
        if conn then conn:Disconnect() end
        task.spawn(thread, ...)
    end)
    return coroutine.yield()
end

function Signal:DisconnectAll()
    self._handlers = {}
    self._once = {}
end

function Signal:Destroy()
    self:DisconnectAll()
end

-- Count active handlers (useful for debugging).
function Signal:Count(): number
    return #self._handlers + #self._once
end

-- ===========================================================================
-- Executor helpers for RBXScriptSignal
-- ===========================================================================

-- Fire all Luau connections of a Roblox signal immediately, ignoring the
-- Workspace.SignalBehaviour property. Uses the executor's `firesignal`
-- when available; otherwise falls back to a no-op with a warning.
function Signal.FireRBX(rbxSignal: any, ...: any): ()
    if typeof(firesignal) == "function" then
        firesignal(rbxSignal, ...)
        return
    end
    warn("[Elysian.Signal] firesignal not available in this environment")
    return
end

-- Replicate a signal to the server with the provided arguments. Uses the
-- executor's `replicatesignal` when available; otherwise falls back to a
-- no-op with a warning. NOTE: signal arguments must match the signal's
-- expected structure or the executor will throw.
function Signal.ReplicateRBX(rbxSignal: any, ...: any): ()
    if typeof(replicatesignal) == "function" then
        replicatesignal(rbxSignal, ...)
        return
    end
    warn("[Elysian.Signal] replicatesignal not available in this environment")
    return
end

-- Returns true if the current environment exposes executor signal helpers.
function Signal.HasExecutorSignalHelpers(): boolean
    return typeof(firesignal) == "function" or typeof(replicatesignal) == "function"
end

return Signal
