--!nonstrict
--[[
    CoreGui Service
    ---------------
    Provides a parent for library GUI instances. Tries CoreGui first
    (executor context), and falls back to PlayerGui / workspace root.
]]

local CoreGuiService = {}
CoreGuiService.__index = CoreGuiService

local cachedParent: Instance?

function CoreGuiService.new()
    return setmetatable({}, CoreGuiService)
end

-- Returns a suitable parent Instance for UI created by the library.
function CoreGuiService:GetParent(): Instance
    if cachedParent then return cachedParent end

    local ok, coreGui = pcall(function()
        return game:GetService("CoreGui")
    end)
    if ok and coreGui then
        cachedParent = coreGui
        return coreGui
    end

    local Players = game:GetService("Players")
    local localPlayer = Players.LocalPlayer
    if localPlayer and localPlayer:FindFirstChildOfClass("PlayerGui") then
        cachedParent = localPlayer:FindFirstChildOfClass("PlayerGui")
        return cachedParent
    end

    cachedParent = game
    return game
end

-- Returns (or creates) a single ScreenGui container under which all
-- library UI is parented. Subsequent calls return the same instance.
function CoreGuiService:GetContainer(name: string?): ScreenGui
    local parent = self:GetParent()
    local containerName = name or "ElysianRoot"
    local existing = parent:FindFirstChild(containerName)
    if existing and existing:IsA("ScreenGui") then
        return existing :: any
    end
    local gui = Instance.new("ScreenGui")
    gui.Name = containerName
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 9999
    gui.IgnoreGuiInset = true
    gui.Parent = parent
    return gui
end

return CoreGuiService
