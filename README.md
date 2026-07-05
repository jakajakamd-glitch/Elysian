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
│   │   ├── Signal.luau           # custom signal + firesignal/replicatesignal helpers
│   │   ├── Connections.luau      # managed RBXScriptConnection bag
│   │   ├── Task.luau             # task.spawn / every / everyFrame helpers
│   │   ├── Logger.luau           # tagged console output
│   │   ├── Math.luau             # lerp/clamp/remap/smooth
│   │   ├── Color.luau            # hex/rgb/hsv helpers
│   │   ├── Tween.luau            # TweenService wrappers
│   │   └── Drawing.luau          # GUI instance factories
│   ├── Services/
│   │   ├── ServiceManager.luau   # public `Elysian.Service` facade
│   │   ├── RenderStepped.luau    # service.RenderStepped() — supports :Fire / :Replicate
│   │   ├── Heartbeat.luau        # service.Heartbeat() — supports :Fire / :Replicate
│   │   ├── Stepped.luau          # service.Stepped() — supports :Fire / :Replicate
│   │   ├── RunService.luau       # context queries (IsStudio, IsClient, ...)
│   │   ├── UserInput.luau        # keyboard/mouse/touch helpers + :Fire / :Replicate
│   │   ├── Players.luau          # Players service wrapper
│   │   ├── Workspace.luau        # Workspace wrapper + raycast helpers
│   │   ├── CoreGui.luau          # parent-finding + ScreenGui container
│   │   └── Http.luau             # HTTP GET/POST + JSON helpers
│   └── Components/
│       ├── BaseComponent.luau    # shared lifecycle (auto-cleans Connections)
│       ├── Window.luau           # root draggable window + OpenButton + animations
│       ├── OpenButton.luau       # floating toggle button (mobile-friendly)
│       ├── Tab.luau              # labelled tab with content scroll list
│       ├── Button.luau
│       ├── Toggle.luau
│       ├── Slider.luau           # touch + mouse support
│       ├── TextBox.luau
│       ├── Label.luau
│       ├── Dropdown.luau         # touch + mouse support
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
service.UserInput()     -- input event listener (mouse + touch + keyboard)
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

### Executor helpers (firesignal / replicatesignal)

When running on an executor that exposes `firesignal` and `replicatesignal`,
you can use them to manually trigger or replicate Roblox signals:

```lua
local rs = Elysian.Service.RenderStepped()
rs:Fire(0.016)              -- firesignal(RunService.RenderStepped, 0.016)
rs:Replicate(0.016)         -- replicatesignal(RunService.RenderStepped, 0.016)

local ui = Elysian.Service.UserInput()
ui:Fire(UserInputService.InputBegan, fakeInputObj, false)
ui:Replicate(UserInputService.InputBegan, fakeInputObj, false)

-- Or call the executor functions directly via the Signal module:
Elysian.Signal.FireRBX(someRBXScriptSignal, args...)
Elysian.Signal.ReplicateRBX(someRBXScriptSignal, args...)
Elysian.Signal.HasExecutorSignalHelpers() -- boolean
```

If the executor doesn't expose these functions, calls log a warning and no-op.

## Connections API

`Elysian.Connections` is a managed bag of RBXScriptConnections (and arbitrary
cleanup functions). Tear everything down in one call:

```lua
local conns = Elysian.Connections.new()

conns:Add(workspace.ChildAdded:Connect(...))
conns:Add(function() print("custom cleanup") end)
conns:Bind {
    RunService.Heartbeat:Connect(...),
    Players.PlayerRemoving:Connect(...),
}

print(conns:Count())     -- number of tracked items
conns:DisconnectAll()    -- tears down everything in LIFO order
```

Every component also exposes `self.Connections` automatically (populated by
`BaseComponent.new`) — subclass code can do `self.Connections:Add(conn)` and
they'll be torn down when the component is destroyed.

## Window visibility & OpenButton

`Window.new` automatically creates a floating, always-visible OpenButton on
the left edge of the screen. Tap it (or press the optional hotkey) to
toggle the window's visibility with a smooth scale/fade animation.

```lua
local window = Elysian.Window.new({
    Title      = "My UI",
    Size       = Vector2.new(560, 380),
    OpenHotkey = Enum.KeyCode.RightShift, -- optional
    OpenButton = true,                    -- default true, set false to disable
})

window:Show()    -- smooth scale-in
window:Hide()    -- smooth scale-out (window stays alive, just hidden)
window:Toggle()  -- flips between Show and Hide
window:Close()   -- animate out + destroy (also destroys the OpenButton)
```

The OpenButton is mobile-friendly: tap to toggle, drag to move.

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
