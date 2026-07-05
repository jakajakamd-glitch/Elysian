--!nonstrict
--[[
    Elysian GUI Library
    -------------------
    A modular Roblox GUI library composed of many small Luau modules that
    are loaded directly from this GitHub repository via `loadstring` and
    `game:HttpGet` against raw.githubusercontent.com.

    Entry point: this file. Loadstring this file from your script:

        local Elysian = loadstring(game:HttpGet(
            "https://raw.githubusercontent.com/jakajakamd-glitch/Elysian/main/Elysian.luau"
        ))()

        local service = Elysian.Service
        local rs = service.RenderStepped()
        rs:Bind("MyUpdate", function(dt) print("dt:", dt) end)

        local window = Elysian.Window.new({ Title = "Elysian" })
        local tab = window:CreateTab("Main")
        tab:CreateButton("Click me", function() print("clicked") end)

    Author: Dev
    License: MIT
]]

local REPO_OWNER = "jakajakamd-glitch"
local REPO_NAME  = "Elysian"
local REPO_BRANCH = "main"
local BASE_URL = ("https://raw.githubusercontent.com/%s/%s/%s"):format(
    REPO_OWNER, REPO_NAME, REPO_BRANCH
)

-- HttpGet wrapper, with a fall-back to `request` if `game:HttpGet` is unavailable.
-- Appends a cache-busting query param so executors that ignore the `nocache`
-- flag still fetch fresh code on every loadstring.
local function fetch(url: string): string
    local bustedUrl = url .. (string.find(url, "?") and "&" or "?") .. "_t=" .. tostring(os.time())
    if game and game.GetService then
        local ok, result = pcall(function()
            return game:HttpGet(bustedUrl, true)
        end)
        if ok and type(result) == "string" and #result > 0 then
            return result
        end
    end
    -- Executor `request` fallback
    if typeof(request) == "function" then
        local ok, result = pcall(function()
            return request({
                Url = bustedUrl,
                Method = "GET",
                Headers = { ["Cache-Control"] = "no-cache" },
            })
        end)
        if ok and result and type(result.Body) == "string" then
            return result.Body
        end
    end
    error("[Elysian] Failed to fetch module: " .. url, 2)
end

-- Load a Luau module from the repository, returning its exports.
local loadedCache: {[string]: any} = {}
local function requireRemote(relativePath: string): any
    if loadedCache[relativePath] then
        return loadedCache[relativePath]
    end
    local url = BASE_URL .. "/" .. relativePath
    local source = fetch(url)
    local fn, err = loadstring(source, relativePath)
    if not fn or err then
        error("[Elysian] Failed to compile '" .. relativePath .. "': " .. tostring(err), 2)
    end
    local exports = fn()
    loadedCache[relativePath] = exports
    return exports
end

-- Bootstrap: pull in every subsystem the library exposes.
local Types         = requireRemote("src/Types.luau")
local Signal        = requireRemote("src/Utilities/Signal.luau")
local Task          = requireRemote("src/Utilities/Task.luau")
local Logger        = requireRemote("src/Utilities/Logger.luau")
local Math          = requireRemote("src/Utilities/Math.luau")
local Color         = requireRemote("src/Utilities/Color.luau")
local Tween         = requireRemote("src/Utilities/Tween.luau")
local Drawing       = requireRemote("src/Utilities/Drawing.luau")
local Connections   = requireRemote("src/Utilities/Connections.luau")
local Viewport      = requireRemote("src/Utilities/Viewport.luau")

local Theme         = requireRemote("src/Theme.luau")

local ServiceManager = requireRemote("src/Services/ServiceManager.luau")

local BaseComponent = requireRemote("src/Components/BaseComponent.luau")
local Window        = requireRemote("src/Components/Window.luau")
local OpenButton    = requireRemote("src/Components/OpenButton.luau")
local Tab           = requireRemote("src/Components/Tab.luau")
local Button        = requireRemote("src/Components/Button.luau")
local Toggle        = requireRemote("src/Components/Toggle.luau")
local Slider        = requireRemote("src/Components/Slider.luau")
local TextBox       = requireRemote("src/Components/TextBox.luau")
local Label         = requireRemote("src/Components/Label.luau")
local Dropdown      = requireRemote("src/Components/Dropdown.luau")
local KeyPicker     = requireRemote("src/Components/KeyPicker.luau")
local Notification  = requireRemote("src/Components/Notification.luau")

-- Public exports
local Elysian = {
    Version = "1.3.0",
    Codename = "Elysian",
    _url = BASE_URL,

    -- Subsystems
    Types       = Types,
    Signal      = Signal,
    Task        = Task,
    Logger      = Logger,
    Math        = Math,
    Color       = Color,
    Tween       = Tween,
    Drawing     = Drawing,
    Connections = Connections,
    Viewport    = Viewport,

    -- Service facade (e.g. `local rs = Elysian.Service.RenderStepped()`)
    Service     = ServiceManager,

    -- Theme
    Theme       = Theme,

    -- Component factories (Window.new, etc.)
    BaseComponent = BaseComponent,
    Window      = Window,
    OpenButton  = OpenButton,
    Tab         = Tab,
    Button      = Button,
    Toggle      = Toggle,
    Slider      = Slider,
    TextBox     = TextBox,
    Label       = Label,
    Dropdown    = Dropdown,
    KeyPicker   = KeyPicker,
    Notification = Notification,

    -- Internals exposed for advanced use
    _requireRemote = requireRemote,
    _fetch = fetch,
}

Logger:Info("Elysian v" .. Elysian.Version .. " initialized.")

return Elysian
