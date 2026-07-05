--!nonstrict
--[[
    Elysian Demo
    ------------
    A complete example showcasing every part of the library, including
    mobile-friendly components, smooth animations, the OpenButton, and
    the new Connections / firesignal helpers.

    Run it with:
        loadstring(game:HttpGet(
            "https://raw.githubusercontent.com/jakajakamd-glitch/Elysian/main/examples/demo.luau"
        ))()
]]

local Elysian = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/jakajakamd-glitch/Elysian/main/Elysian.luau"
))()

-- For debugging: uncomment to see verbose prints from every subsystem.
-- Elysian.Logger:SetLevel("Debug")
Elysian.Logger:Info("[demo] booting Elysian v" .. Elysian.Version)

-- Theme override
Elysian.Theme:Set({
    Accent = Color3.fromRGB(120, 200, 255),
})

-- Build window. The OpenButton is created automatically and floats on
-- the left edge of the screen; tap it to toggle the window.
local window = Elysian.Window.new({
    Title      = "Elysian Demo",
    Size       = Vector2.new(560, 440),
    OpenHotkey = Enum.KeyCode.RightShift, -- press RightShift to toggle on desktop
})

-- A Connections bag makes cleanup trivial; we'll tear everything down
-- on close. (Not strictly required for a demo, but it showcases the API.)
local conns = Elysian.Connections.new()

-- Tab 1: Components showcase
local showcase = window:CreateTab("Showcase")
showcase:CreateLabel("Components")
showcase:CreateButton("Print hello", function()
    Elysian.Notification:Notify({
        Title = "Hello",
        Body  = "Button was pressed.",
        Type  = "Info",
    })
end)

local _espToggle = showcase:CreateToggle("Enable ESP", false, function(state)
    Elysian.Notification:Notify({
        Title = "ESP",
        Body  = state and "Enabled" or "Disabled",
        Type  = state and "Success" or "Warning",
    })
end)

-- WalkSpeed slider. We apply it both immediately and on every Heartbeat
-- so respawns and server-side resets don't undo it. (Persist via conns.)
local SPEED_DEFAULT = 16
local speedSlider = showcase:CreateSlider("Walk Speed", 16, 100, SPEED_DEFAULT, function(value)
    local player = game:GetService("Players").LocalPlayer
    if player and player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
        player.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = value
    end
end)

-- Re-apply speed whenever the character (re)spawns.
local Players = game:GetService("Players")
conns:Add(Players.LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.2) -- wait for Humanoid
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then
        hum.WalkSpeed = speedSlider:Get()
    end
end))
-- Re-apply on Heartbeat too, so server-side resets can't fight us.
local hb = Elysian.Service.Heartbeat()
conns:Add(hb:Connect(function()
    local char = Players.LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and math.abs(hum.WalkSpeed - speedSlider:Get()) > 0.01 then
        hum.WalkSpeed = speedSlider:Get()
    end
end))

showcase:CreateDropdown("Mode", { "Normal", "Aggressive", "Passive" }, "Normal", function(value)
    print("Mode set to:", value)
end)

showcase:CreateTextBox("Target", "Player1", function(value, enterPressed)
    print("Target set to:", value, "enter?", enterPressed)
end)

showcase:CreateKeyPicker("Activate", Enum.KeyCode.E, function(keyCode)
    print("Activate key bound to:", keyCode.Name)
end)

-- Tab 2: Services demo
local services = window:CreateTab("Services")
services:CreateLabel("Service handles")

local rsLabel = services:CreateLabel("RenderStepped dt: --")
local rs = Elysian.Service.RenderStepped()
conns:Add(rs:Connect(function(dt)
    rsLabel:SetText(string.format("RenderStepped dt: %.4f", dt))
end))

local hbLabel = services:CreateLabel("Heartbeat dt: --")
conns:Add(hb:Connect(function(dt)
    hbLabel:SetText(string.format("Heartbeat dt: %.4f", dt))
end))

services:CreateButton("Fire RenderStepped manually", function()
    -- Uses executor `firesignal` under the hood if available.
    rs:Fire(0.123)
    Elysian.Notification:Notify({
        Title = "firesignal",
        Body  = "Fired RenderStepped with dt=0.123 (if executor supports it).",
        Type  = "Info",
    })
end)

services:CreateButton("Disconnect services", function()
    rs:DisconnectAll()
    hb:DisconnectAll()
    rsLabel:SetText("RenderStepped dt: (disconnected)")
    hbLabel:SetText("Heartbeat dt: (disconnected)")
end)

-- Tab 3: Theme demo
local themeTab = window:CreateTab("Theme")
themeTab:CreateLabel("Accent color picker")

themeTab:CreateDropdown("Accent", {
    "Sky Blue", "Lime", "Coral", "Lavender", "Gold"
}, "Sky Blue", function(value)
    local accents = {
        ["Sky Blue"]  = Color3.fromRGB(120, 200, 255),
        ["Lime"]      = Color3.fromRGB(180, 230, 90),
        ["Coral"]     = Color3.fromRGB(255, 120, 100),
        ["Lavender"]  = Color3.fromRGB(180, 140, 255),
        ["Gold"]      = Color3.fromRGB(255, 200, 60),
    }
    Elysian.Theme:Set({ Accent = accents[value] })
end)

themeTab:CreateButton("Reset theme", function()
    Elysian.Theme:Reset()
end)

-- Tab 4: Debug
local debugTab = window:CreateTab("Debug")
debugTab:CreateLabel("Logger level")
debugTab:CreateDropdown("Level", { "Debug", "Info", "Warn", "Error" }, "Info", function(value)
    Elysian.Logger:SetLevel(value)
    Elysian.Logger:Info("[demo] log level set to " .. value)
end)
debugTab:CreateButton("Print debug message", function()
    Elysian.Logger:Debug("[demo] explicit debug print")
end)
debugTab:CreateButton("Print info message", function()
    Elysian.Logger:Info("[demo] explicit info print")
end)
debugTab:CreateButton("Print warn message", function()
    Elysian.Logger:Warn("[demo] explicit warn print")
end)
debugTab:CreateToggle("Connections count (live)", false, function(state)
    if state then
        debugTab._connLoop = Elysian.Service.Heartbeat():Connect(function()
            print("[demo] active connections in bag:", conns:Count())
        end)
    else
        if debugTab._connLoop then
            debugTab._connLoop:Disconnect()
            debugTab._connLoop = nil
        end
    end
end)

-- Initial notification
Elysian.Notification:Notify({
    Title = "Elysian loaded",
    Body  = "v" .. Elysian.Version .. " ready. Tap the floating button to toggle the window.",
    Type  = "Success",
    Duration = 5,
})

Elysian.Logger:Info("[demo] loaded")
