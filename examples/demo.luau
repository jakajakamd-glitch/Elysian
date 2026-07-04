--!nonstrict
--[[
    Elysian Demo
    ------------
    A complete example showcasing every part of the library.

    Run it with:
        loadstring(game:HttpGet(
            "https://raw.githubusercontent.com/jakajakamd-glitch/Elysian/main/examples/demo.luau"
        ))()
]]

local Elysian = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/jakajakamd-glitch/Elysian/main/Elysian.luau"
))()

-- Theme override
Elysian.Theme:Set({
    Accent = Color3.fromRGB(120, 200, 255),
})

-- Build window
local window = Elysian.Window.new({
    Title = "Elysian Demo",
    Size  = Vector2.new(560, 420),
})

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

local _espEnabled = false
showcase:CreateToggle("Enable ESP", false, function(state)
    _espEnabled = state
    Elysian.Notification:Notify({
        Title = "ESP",
        Body  = state and "Enabled" or "Disabled",
        Type  = state and "Success" or "Warning",
    })
end)

showcase:CreateSlider("Walk Speed", 16, 100, 16, function(value)
    local player = game:GetService("Players").LocalPlayer
    if player and player.Character and player.Character:FindFirstChild("Humanoid") then
        player.Character.Humanoid.WalkSpeed = value
    end
end)

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
rs:Bind("DemoRSDisplay", function(dt)
    rsLabel:SetText(string.format("RenderStepped dt: %.4f", dt))
end)

local hbLabel = services:CreateLabel("Heartbeat dt: --")
local hb = Elysian.Service.Heartbeat()
hb:Connect(function(dt)
    hbLabel:SetText(string.format("Heartbeat dt: %.4f", dt))
end)

services:CreateButton("Unbind RenderStepped", function()
    rs:Unbind("DemoRSDisplay")
    rsLabel:SetText("RenderStepped dt: (unbound)")
end)

services:CreateButton("Re-bind RenderStepped", function()
    rs:Bind("DemoRSDisplay", function(dt)
        rsLabel:SetText(string.format("RenderStepped dt: %.4f", dt))
    end)
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

-- Initial notification
Elysian.Notification:Notify({
    Title = "Elysian loaded",
    Body  = "v" .. Elysian.Version .. " ready to roll.",
    Type  = "Success",
    Duration = 5,
})

print("[Elysian] Demo loaded.")
