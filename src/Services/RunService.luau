--!nonstrict
--[[
    RunService - thin access wrapper around game:GetService("RunService").
    Exposes booleans describing the current execution context and a few
    convenience methods.
]]

local RunService = game:GetService("RunService")

local RS = {}
RS.__index = RS

function RS.new()
    return setmetatable({}, RS)
end

function RS:IsStudio(): boolean
    return RunService:IsStudio()
end

function RS:IsRunning(): boolean
    return RunService:IsRunning()
end

function RS:IsClient(): boolean
    return RunService:IsClient()
end

function RS:IsServer(): boolean
    return RunService:IsServer()
end

function RS:IsEdit(): boolean
    return RunService:IsEdit()
end

-- Pass-through access to underlying service.
function RS:Raw(): RunService
    return RunService
end

return RS
