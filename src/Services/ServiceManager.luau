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

-- Use the shared bootstrap loader so every module gets the SAME cached
-- instance of each dependency.
local BASE_URL = "https://raw.githubusercontent.com/jakajakamd-glitch/Elysian/main"
local _bootstrap = _G._ELYSIAN_BOOTSTRAP
if not _bootstrap then
    local bsSource
    if typeof(request) == "function" then
        local res = request({ Url = BASE_URL .. "/src/Bootstrap.luau", Method = "GET" })
        bsSource = res.Body
    else
        bsSource = game:HttpGet(BASE_URL .. "/src/Bootstrap.luau", true)
    end
    loadstring(bsSource, "src/Bootstrap.luau")()
    _bootstrap = _G._ELYSIAN_BOOTSTRAP
end
local requireRemote = _bootstrap.requireRemote

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
