--!nonstrict
--[[
    Elysian GUI Library
    -------------------
    A modular Roblox GUI library composed of many small Luau modules that
    are loaded directly from this GitHub repository via `loadstring` and
    the executor `request()` function (with a `game:HttpGet` fallback).

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

-- ===========================================================================
-- Bootstrap: load the shared module loader. This is the ONLY inline fetch
-- in the entire library; everything else goes through _G._ELYSIAN_BOOTSTRAP
-- so that every subsystem sees the SAME cached instance of each module.
-- This is critical for Theme: without a shared cache, each module gets its
-- own Theme table and Theme:Set() in one place doesn't propagate to others.
-- ===========================================================================
if _G._ELYSIAN_BOOTSTRAP == nil then
    local bsUrl = BASE_URL .. "/src/Bootstrap.luau?_t=" .. tostring(os.time())
    local bsSource
    -- Prefer executor `request()` (returns Response table with .Body).
    if typeof(request) == "function" then
        local res = request({
            Url = bsUrl,
            Method = "GET",
            Headers = { ["Cache-Control"] = "no-cache" },
        })
        bsSource = res.Body
    elseif game and game.GetService then
        bsSource = game:HttpGet(bsUrl, true)
    else
        error("[Elysian] No HTTP method available (need `request` or `game:HttpGet`)", 0)
    end
    local bsFn = loadstring(bsSource, "src/Bootstrap.luau")
    bsFn()
end
local requireRemote = _G._ELYSIAN_BOOTSTRAP.requireRemote

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
    Version = "1.4.0",
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
