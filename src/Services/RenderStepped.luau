--!nonstrict
--[[
    RenderStepped Service
    ---------------------
    Wraps `RunService.RenderStepped` and `RunService:BindToRenderStep`.
    Each call to `.new()` returns a fresh wrapper that manages its own
    set of named bindings.
]]

local RunService = game:GetService("RunService")

local RenderStepped = {}
RenderStepped.__index = RenderStepped

export type RenderStepped = typeof(setmetatable({} :: {
    _bindings: { [string]: boolean },
}, RenderStepped))

function RenderStepped.new(): RenderStepped
    return setmetatable({ _bindings = {} }, RenderStepped) :: any
end

-- Bind a callback to RenderStepped using RunService:BindToRenderStep.
-- `name` must be unique per binding; calling :Bind with a name that is
-- already bound will replace that binding.
function RenderStepped:Bind(name: string, callback: (dt: number) -> (), priority: number?)
    if self._bindings[name] then
        self:Unbind(name)
    end
    RunService:BindToRenderStep(name, priority or 1, callback)
    self._bindings[name] = true
end

function RenderStepped:Unbind(name: string)
    if self._bindings[name] then
        pcall(function() RunService:UnbindFromRenderStep(name) end)
        self._bindings[name] = nil
    end
end

function RenderStepped:UnbindAll()
    for name in pairs(self._bindings) do
        self:Unbind(name)
    end
end

-- Like :Bind, but the callback fires once and is removed.
function RenderStepped:BindOnce(name: string, callback: (dt: number) -> (), priority: number?)
    local fired = false
    self:Bind(name, function(dt: number)
        if fired then return end
        fired = true
        callback(dt)
        self:Unbind(name)
    end, priority)
end

-- Connect to RenderStepped signal directly (returns RBXScriptConnection).
function RenderStepped:Connect(callback: (dt: number) -> ()): RBXScriptConnection
    return RunService.RenderStepped:Connect(callback)
end

-- Wait for the next render frame (yields).
function RenderStepped:Wait(): number
    return RunService.RenderStepped:Wait()
end

function RenderStepped:Destroy()
    self:UnbindAll()
end

return RenderStepped
