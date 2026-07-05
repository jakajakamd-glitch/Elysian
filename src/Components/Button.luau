--!nonstrict
--[[
    Button - a clickable text button with smooth hover/press animations.

    Button.new({
        Text   = "Click me",
        Theme  = <optional theme table>,
        Parent = <Instance>,
    })
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
local Signal        = requireRemote("src/Utilities/Signal.luau")
local Theme         = requireRemote("src/Theme.luau")

local Button = setmetatable({}, BaseComponent)
Button.__index = Button

export type ButtonProps = {
    Text: string?,
    Theme: { [string]: any }?,
    Parent: Instance?,
    Size: UDim2?,
    Tooltip: string?,
}

function Button.new(props: ButtonProps?): any
    local self = BaseComponent.new() :: any
    setmetatable(self, Button)

    local theme = (props and props.Theme) or Theme.Current
    local text  = (props and props.Text) or "Button"

    local root = Drawing.textButton({
        Name = "ElysianButton",
        Size = props and props.Size or UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = 0,
        Text = "",
        Parent = props and props.Parent,
    })
    Drawing.rounded(root, theme.CornerRadius - 2)
    Drawing.stroke(root, theme.Border, 1, 0.5)

    local label = Drawing.textLabel({
        Name = "Label",
        Size = UDim2.new(1, -16, 1, 0),
        Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = theme.Text,
        Font = theme.Font,
        TextSize = theme.FontSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = root,
    })

    self.Instance = root
    self.Theme = theme
    self.Label = label
    self.Pressed = Signal.new()
    self._hovering = false
    self._pressing = false

    -- All hover/press reads from self.Theme (live) so RefreshTheme works.
    local function applyState()
        local t = self.Theme
        local targetColor
        if self._pressing then
            targetColor = t.Accent
        elseif self._hovering then
            targetColor = t.AccentAlt
        else
            targetColor = t.Surface
        end
        Tween.quick(root, 0.18, { BackgroundColor3 = targetColor },
            Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    end

    self._applyState = applyState

    root.MouseEnter:Connect(function()
        self._hovering = true
        applyState()
    end)
    root.MouseLeave:Connect(function()
        self._hovering = false
        self._pressing = false
        applyState()
    end)
    root.MouseButton1Down:Connect(function()
        self._pressing = true
        applyState()
    end)
    root.MouseButton1Up:Connect(function()
        self._pressing = false
        applyState()
    end)
    root.MouseButton1Click:Connect(function()
        self.Pressed:Fire()
    end)

    return self
end

function Button:SetText(text: string)
    self.Label.Text = text
end

function Button:OnPressed(callback: (() -> ()))
    return self.Pressed:Connect(callback)
end

function Button:RefreshTheme(theme: { [string]: any })
    self.Theme = theme
    Tween.quick(self.Label, 0.2, { TextColor3 = theme.Text })
    self.Label.Font = theme.Font
    self.Label.TextSize = theme.FontSize
    self._applyState()
end

return Button
