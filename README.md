# Elysian

A modular Roblox GUI library written entirely in `.luau`, designed to be
loaded directly from this GitHub repository via `loadstring` +
`game:HttpGet` against `raw.githubusercontent.com`.

The library is **99% modules**: Services, Components, Utilities, Theme
and Types are all separate `.luau` files fetched on demand and cached
in-memory. You only ever loadstring the entry point — everything else
is pulled lazily.

## Quick start

```lua
local Elysian = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/jakajakamd-glitch/Elysian/main/Elysian.luau"
))()

-- Build a window with tabs and components
local window = Elysian.Window.new({
    Title = "Elysian Demo",
    Size  = Vector2.new(560, 380),
})

local tab = window:CreateTab("Main")

tab:CreateLabel("Welcome to Elysian.")

tab:CreateButton("Click me", function()
    print("Button pressed!")
end)

tab:CreateToggle("Enable ESP", false, function(state)
    print("ESP:", state)
end)

tab:CreateSlider("Speed", 0, 100, 50, function(value)
    print("Speed:", value)
end)

tab:CreateDropdown("Mode", { "Normal", "Aggressive", "Passive" }, "Normal", function(value)
    print("Mode:", value)
end)

tab:CreateTextBox("Player name", "Player1", function(value, enterPressed)
    print("Player name:", value, "Enter?", enterPressed)
end)

tab:CreateKeyPicker("Activate key", Enum.KeyCode.E, function(keyCode)
    print("Bound key:", keyCode.Name)
end)

-- Notifications
Elysian.Notification:Notify({
    Title = "Hello",
    Body  = "Elysian loaded successfully.",
    Duration = 4,
    Type = "Success",
})

-- Services
local service = Elysian.Service
local rs = service.RenderStepped()
rs:Bind("MyUpdate", function(dt)
    print("Frame dt:", dt)
end)
```

## Architecture

```
Elysian/
├── Elysian.luau                  # entry point — loadstring this
├── src/
│   ├── Types.luau                # shared type definitions
│   ├── Theme.luau                # default theme + theme manager
│   ├── Utilities/
│   │   ├── Signal.luau           # custom signal/Event implementation
│   │   ├── Task.luau             # task.spawn / every / everyFrame helpers
│   │   ├── Logger.luau           # tagged console output
│   │   ├── Math.luau             # lerp/clamp/remap/smooth
│   │   ├── Color.luau            # hex/rgb/hsv helpers
│   │   ├── Tween.luau            # TweenService wrappers
│   │   └── Drawing.luau          # GUI instance factories
│   ├── Services/
│   │   ├── ServiceManager.luau   # public `Elysian.Service` facade
│   │   ├── RenderStepped.luau    # service.RenderStepped()
│   │   ├── Heartbeat.luau        # service.Heartbeat()
│   │   ├── Stepped.luau          # service.Stepped()
│   │   ├── RunService.luau       # context queries (IsStudio, IsClient, ...)
│   │   ├── UserInput.luau        # keyboard/mouse helpers
│   │   ├── Players.luau          # Players service wrapper
│   │   ├── Workspace.luau        # Workspace wrapper + raycast helpers
│   │   ├── CoreGui.luau          # parent-finding + ScreenGui container
│   │   └── Http.luau             # HTTP GET/POST + JSON helpers
│   └── Components/
│       ├── BaseComponent.luau    # shared lifecycle
│       ├── Window.luau           # root draggable window
│       ├── Tab.luau              # labelled tab with content scroll list
│       ├── Button.luau
│       ├── Toggle.luau
│       ├── Slider.luau
│       ├── TextBox.luau
│       ├── Label.luau
│       ├── Dropdown.luau
│       ├── KeyPicker.luau
│       └── Notification.luau     # toast stack
├── examples/
│   └── demo.luau                 # full demo script
└── README.md
```

## Loading convention

Every module is fetched with a tiny `requireRemote(path)` helper that
lives both in `Elysian.luau` (the bootstrap) and in `ServiceManager.luau`
and each Component. The helper:

1. Builds a URL against `https://raw.githubusercontent.com/jakajakamd-glitch/Elysian/main/`
2. Fetches via `game:HttpGet` (or executor `request` as a fallback)
3. `loadstring`s the source with a friendly chunk name
4. Caches the result so subsequent requires are free

This means you can mix-and-match: most users will loadstring the entry
point, but a power user can also loadstring an individual component
(`src/Components/Slider.luau`) and use it standalone.

## Theming

`Elysian.Theme` exposes `Default`, `Current`, `:Set(overrides)`,
`:Reset()`, `:Get(key)`, and `:Merge(partial)`. Pass a partial theme
to `Window.new({ Theme = { Accent = Color3.fromRGB(...) } })` to
override per-window without affecting the global default.

## Services API

```lua
local service = Elysian.Service

service.RenderStepped() -- returns a RenderStepped service object
service.Heartbeat()     -- returns a Heartbeat service object
service.Stepped()       -- returns a Stepped service object
service.UserInput()     -- input event listener
service.Players()       -- Players wrapper
service.Workspace()     -- Workspace wrapper
service.CoreGui()       -- parent/container provider
service.Http()          -- HTTP wrapper
service.RunService()    -- context queries
service:Get("Lighting") -- any Roblox service by name
```

Each service object is a fresh instance with its own callback table,
so multiple scripts can hold independent service handles without
interference. `:Destroy()` cleans up all bindings for that handle.

## Components API

Every component inherits from `BaseComponent` and exposes a fluent
`.new(props)` constructor plus getter/setter/event methods:

| Component    | Constructor                                  | Events                       |
|--------------|----------------------------------------------|------------------------------|
| Window       | `Window.new({ Title, Size, ... })`           | (drag/close handled)         |
| Tab          | `Window:CreateTab(name)`                     | (click handled)              |
| Button       | `Tab:CreateButton(text, callback?)`          | `:OnPressed(cb)`             |
| Toggle       | `Tab:CreateToggle(text, default?, cb?)`      | `:OnChanged(cb)`             |
| Slider       | `Tab:CreateSlider(text, min, max, def?, cb?)`| `:OnChanged(cb)`             |
| TextBox      | `Tab:CreateTextBox(text, default?, cb?)`     | `:OnChanged(cb)`             |
| Label        | `Tab:CreateLabel(text)`                       | —                            |
| Dropdown     | `Tab:CreateDropdown(text, opts, def?, cb?)`  | `:OnChanged(cb)`             |
| KeyPicker    | `Tab:CreateKeyPicker(text, def?, cb?)`        | `:OnChanged(cb)`             |
| Notification | `Elysian.Notification:Notify({...})`         | —                            |

## License

MIT — © Elysian contributors.
