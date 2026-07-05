--!nonstrict
--[[
    Tab - a labelled section within a Window. Holds a list of components
    (buttons, toggles, sliders, etc.) in a vertical scrollable container.

    Created by Window:CreateTab(name).
]]

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
local List = requireRemote("src/Components/List.luau")

local Tab = setmetatable({}, BaseComponent)
Tab.__index = Tab

function Tab.new(window: any, name: string, theme: { [string]: any }, icon: string?, layoutMode: string?): any
    local self = BaseComponent.new() :: any
    setmetatable(self, Tab)

    self.Window = window
    self.Name = name
    self.Theme = theme
    self.Components = {}

    -- Tab button: text directly on the button, fixed width based on text length.
    -- No AutomaticSize (causes circular sizing with child labels).
    local textLen = string.len(name)
    local btnWidth = math.max(60, textLen * 10 + 24) -- rough char width estimate

    local button = Drawing.textButton({
        Name = "TabButton_" .. name,
        Size = UDim2.fromOffset(btnWidth, 28),
        BackgroundColor3 = theme.SurfaceAlt or Color3.fromRGB(48, 52, 66),
        BackgroundTransparency = 1,
        Text = name,
        TextColor3 = theme.TextMuted or Color3.fromRGB(150, 155, 170),
        Font = theme.Font or Enum.Font.GothamMedium,
        TextSize = theme.FontSize or 15,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = window.TabBar,
    })
    Drawing.rounded(button, 6)
    self.Button = button
    self.Label = button -- text is on the button itself
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

    -- Hover effect
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
        self.Label.TextColor3 = self.Theme.Text or Color3.fromRGB(232, 234, 240)
        self.Button.BackgroundColor3 = self.Theme.Accent or Color3.fromRGB(86, 156, 255)
        Tween.quick(self.Button, 0.15, { BackgroundTransparency = 0.85 })
        -- Highlight bar
        if not self.Button:FindFirstChild("ActiveHighlight") then
            local highlight = Drawing.frame({
                Name = "ActiveHighlight",
                Size = UDim2.fromOffset(self.Button.Size.X.Offset, 3),
                Position = UDim2.fromOffset(0, 25),
                BackgroundColor3 = self.Theme.Accent or Color3.fromRGB(86, 156, 255),
                BorderSizePixel = 0,
                Parent = self.Button,
            })
            Drawing.rounded(highlight, 2)
        end
    else
        self.Label.TextColor3 = self.Theme.TextMuted or Color3.fromRGB(150, 155, 170)
        Tween.quick(self.Button, 0.15, { BackgroundTransparency = 1 })
        local hl = self.Button:FindFirstChild("ActiveHighlight")
        if hl then hl:Destroy() end
    end
end

-- Re-apply the current theme to this tab's visuals.
function Tab:RefreshTheme(theme: { [string]: any })
    self.Theme = theme
    self.Label.Font = theme.Font or Enum.Font.GothamMedium
    self.Label.TextSize = theme.FontSize or 15
    if self._isActive then
        self.Label.TextColor3 = theme.Text or Color3.fromRGB(232, 234, 240)
        self.Button.BackgroundColor3 = theme.Accent or Color3.fromRGB(86, 156, 255)
        local hl = self.Button:FindFirstChild("ActiveHighlight")
        if hl then
            hl.BackgroundColor3 = theme.Accent or Color3.fromRGB(86, 156, 255)
        end
    else
        self.Label.TextColor3 = theme.TextMuted or Color3.fromRGB(150, 155, 170)
    end
    for _, comp in ipairs(self.Components) do
        if comp.RefreshTheme then
            comp:RefreshTheme(theme)
        end
    end
end

-- Convenience constructors
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

-- Create a List inside this tab. Returns the List component.
--   tab:CreateList({
--       Items = { "Apple", "Banana", "Cherry" },
--       MultiSelect = false,
--       Height = 200,
--       OnSelect = function(item, index) print("Selected:", item) end,
--   })
function Tab:CreateList(props: any?): any
    local listProps = props or {}
    local list = List.new({
        Items = listProps.Items,
        MultiSelect = listProps.MultiSelect,
        DefaultIndex = listProps.DefaultIndex,
        OnSelect = listProps.OnSelect,
        Height = listProps.Height,
        Theme = self.Theme,
        Parent = self.Scroll,
        Title = listProps.Title,
    })
    table.insert(self.Components, list)
    return list
end

return Tab
