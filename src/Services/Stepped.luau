--!nonstrict
--[[
    Stepped Service
    ---------------
    Wraps `RunService.Stepped` - fires before physics each frame.
]]

local RunService = game:GetService("RunService")

local Stepped = {}
Stepped.__index = Stepped

export type Stepped = typeof(setmetatable({} :: {
    _connections: { RBXScriptConnection },
}, Stepped))

function Stepped.new(): Stepped
    return setmetatable({ _connections = {} }, Stepped) :: any
end

function Stepped:Connect(callback: (time: number, dt: number) -> ()): RBXScriptConnection
    local conn = RunService.Stepped:Connect(callback)
    table.insert(self._connections, conn)
    return conn
end

function Stepped:Wait(): (number, number)
    return RunService.Stepped:Wait()
end

function Stepped:DisconnectAll()
    for _, c in ipairs(self._connections) do
        pcall(function() c:Disconnect() end)
    end
    self._connections = {}
end

function Stepped:Destroy()
    self:DisconnectAll()
end

return Stepped
