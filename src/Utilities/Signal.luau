--!nonstrict
--[[
    Signal - a lightweight Lua-side event implementation modelled after
    Roblox's BindableEvent but without the overhead of an Instance.
]]

local Signal = {}
Signal.__index = Signal

export type Connection = {
    Disconnect: (Connection) -> (),
    _alive: boolean,
}

export type Signal = typeof(setmetatable({} :: {
    _handlers: { (any) -> () },
    _once: { (any) -> () },
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

function Signal:Fire(...: any)
    for _, cb in ipairs(self._handlers) do
        task.spawn(cb, ...)
    end
    if #self._once > 0 then
        local once = self._once
        self._once = {}
        for _, cb in ipairs(once) do
            task.spawn(cb, ...)
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

return Signal
