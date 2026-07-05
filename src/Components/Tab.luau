--!nonstrict
--[[
    Tab - a labelled section within a Window. Holds a list of components
    (buttons, toggles, sliders, etc.) in a vertical scrollable container.

    Created by Window:CreateTab(name). You usually do not construct one
    directly, but it is exposed so that consumers can attach their own
    items to it.
]]

local BASE_URL = "https://raw.githubusercontent.com/jakajakamd-glitch/Elysian/main"

-- Use the shared bootstrap loader so every module gets the SAME cached
-- instance of each dependency (critical for Theme, Signal, etc.).
local _bootstrap = _G._ELYSIAN_BOOTSTRAP
if not _bootstrap then
    -- Bootstrap hasn't been loaded yet. Load it inline.
    local bsSource
    if typeof(request) == "function" then
        local res = request({ Url = BASE_URL .. "/src/Bootstrap.luau", Method = "GET" })
        bsSource = res.Body
    else
        bsSource = game:HttpGet(BASE_URL .. "/src/Bootstrap.luau", true)
    end
    local bsFn = loadstring(bsSource, "src/Bootstrap.luau")
    bsFn()
    _bootstrap = _G._ELYSIAN_BOOTSTRAP
end
local requireRemote = _bootstrap.requireRemote

local BaseComponent = requireRemote("src/Components/BaseComponent.luau")
local Drawing       = requireRemote("src/Utilities/Drawing.luau")
local Tween         = requireRemote("src/Utilities/Tween.luau")

local Button   = requireRemote("src/Components/Button.luau")
local Toggle   = requireRemote("src/Components/Toggle.luau")
local Slider   = requireRemote("src/Components/Slider.luau")
local TextBox  = requireRemote("src/Components/TextBox.luau")
local Label    = requireRemote("src/Components/Label.luau")
local Dropdown = requireRemote("src/Components/Dropdown.luau")
local KeyPicker = requireRemote("src/Components/KeyPicker.luau")
local ViewportFrame = requireRemote("src/Components/ViewportFrame.luau")

local Tab = setmetatable({}, BaseComponent)
Tab.__index = Tab

function Tab.new(window: any, name: string, theme: { [string]: any }, icon: string?, layoutMode: string?): any
    local self = BaseComponent.new() :: any
    setmetatable(self, Tab)

    self.Window = window
    self.Name = name
    self.Theme = theme
    self.Components = {}
    self._layoutMode = "horizontal" -- always horizontal now

    -- Tab button: auto-sized to text, horizontal layout
    local button = Drawing.textButton({
        Name = "TabButton_" .. name,
        Size = UDim2.fromOffset(0, 28),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = theme.SurfaceAlt or Color3.fromRGB(48, 52, 66),
        BackgroundTransparency = 1,
        Text = "",
        Parent = window.TabBar,
    })
    Drawing.rounded(button, 6)
    local label = Drawing.textLabel({
        Size = UDim2.new(1, -16, 1, 0),
        Position = UDim2.fromOffset(8, 0),
        BackgroundTransparency = 1,
        Text = name,
        TextColor3 = theme.TextMuted or Color3.fromRGB(150, 155, 170),
        Font = theme.Font or Enum.Font.GothamMedium,
        TextSize = theme.FontSize or 15,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = button,
    })
    self.Button = button
    self.Label = label
    self._isActive = false

    -- Content panel
    local panel = Drawing.frame({
        Name = "TabContent_" .. name,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Visible = false,
        Parent = window.ContentArea,
    })
    local scroll = Drawing.scrollFrame({
        Name = "ScrollList",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = panel,
    })
    Drawing.list(scroll, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)
    Drawing.padding(scroll, 4)
    self.Panel = panel
    self.Scroll = scroll

    button.MouseButton1Click:Connect(function()
        window:SelectTab(self)
    end)

    -- Hover effect: light up the button unless it's the active tab.
    button.MouseEnter:Connect(function()
        if not self._isActive then
            Tween.quick(button, 0.12, { BackgroundTransparency = 0.6 })
        end
    end)
    button.MouseLeave:Connect(function()
        if not self._isActive then
            Tween.quick(button, 0.12, { BackgroundTransparency = 1 })
        end
    end)

    return self
end

function Tab:SetActive(active: boolean)
    self._isActive = active
    self.Panel.Visible = active
    if active then
        self.Label.TextColor3 = self.Theme.Text
        -- Active tab gets a subtle accent-tinted background so it's
        -- clearly distinguishable from inactive (gray) tabs.
        self.Button.BackgroundColor3 = self.Theme.Accent
        Tween.quick(self.Button, 0.15, { BackgroundTransparency = 0.85 })
        -- Highlight bar (accent colored)
        if not self.Button:FindFirstChild("ActiveHighlight") then
            local highlight = Drawing.frame({
                Name = "ActiveHighlight",
                Size = UDim2.fromOffset(3, 18),
                Position = UDim2.fromOffset(0, 7),
                BackgroundColor3 = self.Theme.Accent,
                BorderSizePixel = 0,
                Parent = self.Button,
            })
            Drawing.rounded(highlight, 2)
        end
    else
        self.Label.TextColor3 = self.Theme.TextMuted
        Tween.quick(self.Button, 0.15, { BackgroundTransparency = 1 })
        local hl = self.Button:FindFirstChild("ActiveHighlight")
        if hl then hl:Destroy() end
    end
end

-- Re-apply the current theme to this tab's visuals. Called by Window:RefreshTheme.
function Tab:RefreshTheme(theme: { [string]: any })
    self.Theme = theme
    self.Label.Font = theme.Font
    self.Label.TextSize = theme.FontSize
    if self._isActive then
        Tween.quick(self.Label, 0.2, { TextColor3 = theme.Text })
        Tween.quick(self.Button, 0.2, { BackgroundColor3 = theme.Accent })
        local hl = self.Button:FindFirstChild("ActiveHighlight")
        if hl then
            Tween.quick(hl, 0.2, { BackgroundColor3 = theme.Accent })
        end
    else
        Tween.quick(self.Label, 0.2, { TextColor3 = theme.TextMuted })
    end
    -- Refresh child components
    for _, comp in ipairs(self.Components) do
        if comp.RefreshTheme then
            comp:RefreshTheme(theme)
        end
    end
end

-- Convenience constructors mirroring Window-style usage.
function Tab:CreateButton(text: string, callback: (() -> ())?): any
    local btn = Button.new({ Text = text, Theme = self.Theme, Parent = self.Scroll })
    if callback then btn:OnPressed(callback) end
    table.insert(self.Components, btn)
    return btn
end

function Tab:CreateToggle(text: string, default: boolean?, callback: ((boolean) -> ())?): any
    local tog = Toggle.new({ Text = text, Default = default, Theme = self.Theme, Parent = self.Scroll })
    if callback then tog:OnChanged(callback) end
    table.insert(self.Components, tog)
    return tog
end

function Tab:CreateSlider(text: string, min: number, max: number, default: number?, callback: ((number) -> ())?): any
    local sld = Slider.new({
        Text = text, Min = min, Max = max, Default = default,
        Theme = self.Theme, Parent = self.Scroll,
    })
    if callback then sld:OnChanged(callback) end
    table.insert(self.Components, sld)
    return sld
end

function Tab:CreateTextBox(text: string, default: string?, callback: ((string) -> ())?): any
    local tb = TextBox.new({ Text = text, Default = default, Theme = self.Theme, Parent = self.Scroll })
    if callback then tb:OnChanged(callback) end
    table.insert(self.Components, tb)
    return tb
end

function Tab:CreateLabel(text: string): any
    local lbl = Label.new({ Text = text, Theme = self.Theme, Parent = self.Scroll })
    table.insert(self.Components, lbl)
    return lbl
end

function Tab:CreateDropdown(text: string, options: { string }, default: string?,
        callback: ((string) -> ())?): any
    local dd = Dropdown.new({
        Text = text, Options = options, Default = default,
        Theme = self.Theme, Parent = self.Scroll,
    })
    if callback then dd:OnChanged(callback) end
    table.insert(self.Components, dd)
    return dd
end

function Tab:CreateKeyPicker(text: string, default: EnumItem?, callback: ((EnumItem) -> ())?): any
    local kp = KeyPicker.new({
        Text = text, Default = default,
        Theme = self.Theme, Parent = self.Scroll,
    })
    if callback then kp:OnChanged(callback) end
    table.insert(self.Components, kp)
    return kp
end

-- Create a Viewport inside this tab. Returns the Viewport component.
--   tab:CreateViewport({
--       Size = Vector2.new(1, 200),  -- 1 = fill width, 200px tall
--       Title = "Character Preview",
--       AutoRotate = true,
--   })
function Tab:CreateViewport(props: any?): any
    local vpProps = props or {}
    local vp = ViewportFrame.new({
        Size = vpProps.Size,
        Position = vpProps.Position,
        Theme = self.Theme,
        Parent = self.Scroll,
        AutoRotate = vpProps.AutoRotate,
        CameraDistance = vpProps.CameraDistance,
        CameraHeight = vpProps.CameraHeight,
        BackgroundColor = vpProps.BackgroundColor,
        Title = vpProps.Title,
    })
    table.insert(self.Components, vp)
    return vp
end

return Tab
