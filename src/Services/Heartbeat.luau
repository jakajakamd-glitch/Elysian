--!nonstrict
--[[
    Heartbeat Service
    -----------------
    Wraps `RunService.Heartbeat` for per-frame simulation timing (post-physics).
]]

local RunService = game:GetService("RunService")

local Heartbeat = {}
Heartbeat.__index = Heartbeat

export type Heartbeat = typeof(setmetatable({} :: {
    _connections: { RBXScriptConnection },
}, Heartbeat))

function Heartbeat.new(): Heartbeat
    return setmetatable({ _connections = {} }, Heartbeat) :: any
end

-- Connect a callback to Heartbeat. Returns a connection handle.
function Heartbeat:Connect(callback: (dt: number) -> ()): RBXScriptConnection
    local conn = RunService.Heartbeat:Connect(callback)
    table.insert(self._connections, conn)
    return conn
end

function Heartbeat:Wait(): number
    return RunService.Heartbeat:Wait()
end

-- Manually fire all Heartbeat connections (uses executor `firesignal`).
function Heartbeat:Fire(dt: number?)
    if typeof(firesignal) == "function" then
        firesignal(RunService.Heartbeat, dt or 0)
    end
end

-- Replicate Heartbeat to the server (uses executor `replicatesignal`).
function Heartbeat:Replicate(dt: number?)
    if typeof(replicatesignal) == "function" then
        replicatesignal(RunService.Heartbeat, dt or 0)
    end
end

function Heartbeat:DisconnectAll()
    for _, c in ipairs(self._connections) do
        pcall(function() c:Disconnect() end)
    end
    self._connections = {}
end

function Heartbeat:Destroy()
    self:DisconnectAll()
end

return Heartbeat
