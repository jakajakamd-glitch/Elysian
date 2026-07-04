--!nonstrict
--[[
    ServiceManager - the public `Elysian.Service` facade.
    Each method returns a small wrapper object around a Roblox service so
    that consumers can bind/unbind callbacks, query state, and so on,
    without ever touching `game:GetService` directly.

    Example:
        local service = Elysian.Service
        local rs = service.RenderStepped()
        rs:Bind("MyUpdate", function(dt) print("dt:", dt) end)
]]

-- These modules are loaded lazily to keep the bootstrap order simple.
-- In practice, since this file is itself loaded via loadstring from the
-- repo, we use the same loadstring-require pattern.

local BASE_URL = "https://raw.githubusercontent.com/jakajakamd-glitch/Elysian/main"

local cache: {[string]: any} = {}
local function requireRemote(path: string): any
    if cache[path] then return cache[path] end
    local source
    if game and game.GetService then
        source = game:HttpGet(BASE_URL .. "/" .. path, true)
    else
        local res = request({ Url = BASE_URL .. "/" .. path, Method = "GET" })
        source = res.Body
    end
    local fn = loadstring(source, path)
    local exports = fn()
    cache[path] = exports
    return exports
end

local ServiceManager = {}

-- RunService-backed services
function ServiceManager.RenderStepped()
    return requireRemote("src/Services/RenderStepped.luau").new()
end

function ServiceManager.Heartbeat()
    return requireRemote("src/Services/Heartbeat.luau").new()
end

function ServiceManager.Stepped()
    return requireRemote("src/Services/Stepped.luau").new()
end

-- Higher-level wrappers
function ServiceManager.UserInput()
    return requireRemote("src/Services/UserInput.luau").new()
end

function ServiceManager.Players()
    return requireRemote("src/Services/Players.luau").new()
end

function ServiceManager.Workspace()
    return requireRemote("src/Services/Workspace.luau").new()
end

function ServiceManager.CoreGui()
    return requireRemote("src/Services/CoreGui.luau").new()
end

function ServiceManager.Http()
    return requireRemote("src/Services/Http.luau").new()
end

function ServiceManager.RunService()
    return requireRemote("src/Services/RunService.luau").new()
end

-- A catch-all accessor for any Roblox service:
--     local Lighting = ServiceManager:Get("Lighting")
function ServiceManager:Get(name: string): Instance
    return game:GetService(name)
end

return ServiceManager
