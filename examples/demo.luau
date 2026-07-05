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

-- Prefer executor `request()` (returns Response with .Body), fall back to
-- `game:HttpGet`. Always cache-bust so we get fresh code.
local function elysianFetch(url: string): string
    local busted = url .. (string.find(url, "?") and "&" or "?") .. "_t=" .. tostring(os.time())
    if typeof(request) == "function" then
        local res = request({ Url = busted, Method = "GET", Headers = { ["Cache-Control"] = "no-cache" } })
        return res.Body
    end
    return game:HttpGet(busted, true)
end

local Elysian = loadstring(elysianFetch(
    "https://raw.githubusercontent.com/jakajakamd-glitch/Elysian/main/Elysian.luau"
))()

-- For debugging: uncomment to see verbose prints from every subsystem.
-- Elysian.Logger:SetLevel("Debug")
Elysian.Logger:Info("[demo] booting Elysian v" .. Elysian.Version)

-- Diagnostic: verify theme is loaded correctly
Elysian.Logger:Info("[demo] Theme.Background = " .. tostring(Elysian.Theme.Current.Background))
Elysian.Logger:Info("[demo] Theme.Accent = " .. tostring(Elysian.Theme.Current.Accent))
Elysian.Logger:Info("[demo] Theme.Text = " .. tostring(Elysian.Theme.Current.Text))

-- Theme override
Elysian.Theme:Set({
    Accent = Color3.fromRGB(120, 200, 255),
})
Elysian.Logger:Info("[demo] after Set, Theme.Background = " .. tostring(Elysian.Theme.Current.Background))

-- Build window. The OpenButton is created automatically and floats on
-- the left edge of the screen; tap it to toggle the window.
-- OpenButtonProps lets you fully customize the floating button.
--
-- Image loading options:
--   Image     = "rbxassetid://12345678"  -- direct Roblox asset id
--   ImagePath = "C:/path/to/logo.png"    -- local file via getcustomasset()
local window = Elysian.Window.new({
    Title      = "Elysian Demo",
    Size       = Vector2.new(560, 440),
    OpenHotkey = Enum.KeyCode.RightShift, -- press RightShift to toggle on desktop
    OpenButtonProps = {
        Text = "ELYS",
        Size = 52,
        Shape = "Circle",
        Color = Color3.fromRGB(120, 200, 255),      -- custom accent for the FAB
        TextColor = Color3.fromRGB(20, 20, 30),
        StrokeColor = Color3.fromRGB(255, 255, 255),
        StrokeThickness = 2,
        StrokeTransparency = 0.2,
        Side = "Left",
        Draggable = true,
        -- To use a custom image instead of text, uncomment ONE of these:
        -- Image = "rbxassetid://0",           -- direct asset id
        -- ImagePath = "ElysianLogo.png",       -- local file via getcustomasset()
        -- ImageColor = Color3.fromRGB(255, 255, 255),
    },
})

-- A Connections bag makes cleanup trivial; we'll tear everything down
-- on close. (Not strictly required for a demo, but it showcases the API.)
local conns = Elysian.Connections.new()
local Players = game:GetService("Players")

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
    if state then
        -- Simple ESP: add a Highlight to every player's character
        local function highlight(player)
            if player == Players.LocalPlayer then return end
            local char = player.Character
            if char then
                local existing = char:FindFirstChild("ElysianESP")
                if not existing then
                    local hl = Instance.new("Highlight")
                    hl.Name = "ElysianESP"
                    hl.FillColor = Elysian.Theme.Current.Accent
                    hl.FillTransparency = 0.5
                    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                    hl.Parent = char
                end
            end
        end
        for _, p in ipairs(Players:GetPlayers()) do highlight(p) end
        conns:Add(Players.PlayerAdded:Connect(highlight))
        conns:Add(Players.PlayerRemoving:Connect(function(p)
            if p.Character then
                local hl = p.Character:FindFirstChild("ElysianESP")
                if hl then hl:Destroy() end
            end
        end))
        Elysian.Notification:Notify({
            Title = "ESP",
            Body  = "Enabled - players highlighted",
            Type  = "Success",
        })
    else
        -- Remove all ESP highlights
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then
                local hl = p.Character:FindFirstChild("ElysianESP")
                if hl then hl:Destroy() end
            end
        end
        Elysian.Notification:Notify({
            Title = "ESP",
            Body  = "Disabled",
            Type  = "Warning",
        })
    end
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
-- (Players is already defined above for the ESP toggle.)
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
    pcall(function() rs:DisconnectAll() end)
    pcall(function() hb:DisconnectAll() end)
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
    -- Live-apply the new theme to the already-built window and all its
    -- tabs / components. Without this, components keep using the theme
    -- snapshot from when they were created.
    window:RefreshTheme()
end)

themeTab:CreateButton("Reset theme", function()
    Elysian.Theme:Reset()
    window:RefreshTheme()
end)

-- Tab 4: Viewport demo (shows the local player's character)
local previewTab = window:CreateTab("Preview")
previewTab:CreateLabel("Character preview")
local charViewport
local vpOk, vpErr = pcall(function()
    charViewport = previewTab:CreateViewport({
        Size = Vector2.new(0, 200),   -- 0 = fill width, 200px tall
        Title = "Local Character",
        AutoRotate = true,
        CameraDistance = 6,
        CameraHeight = 3,
    })
end)
if not vpOk or not charViewport then
    warn("[demo] Viewport creation failed:", vpErr)
    previewTab:CreateLabel("(ViewportFrame not available in this environment)")
else
    pcall(function() charViewport:SetLocalCharacter() end)
    previewTab:CreateButton("Re-snapshot character", function()
        pcall(function() charViewport:SetLocalCharacter() end)
    end)
    previewTab:CreateToggle("Auto-rotate", true, function(state)
        pcall(function() charViewport:SetAutoRotate(state) end)
    end)
end

-- Tab 5: Debug
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
