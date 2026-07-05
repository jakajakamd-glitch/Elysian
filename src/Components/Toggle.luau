--!nonstrict
--[[
    Toggle - a checkbox-style binary switch with a label.

    Toggle.new({
        Text    = "Enable ESP",
        Default = false,
        Theme   = <optional>,
        Parent  = <Instance>,
    })
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
local Signal        = requireRemote("src/Utilities/Signal.luau")
local Theme         = requireRemote("src/Theme.luau")

local Toggle = setmetatable({}, BaseComponent)
Toggle.__index = Toggle

export type ToggleProps = {
    Text: string?,
    Default: boolean?,
    Theme: { [string]: any }?,
    Parent: Instance?,
}

function Toggle.new(props: ToggleProps?): any
    local self = BaseComponent.new() :: any
    setmetatable(self, Toggle)

    local theme = (props and props.Theme) or Theme.Current
    local text  = (props and props.Text) or "Toggle"
    self.Value  = not not (props and props.Default)
    self.Theme  = theme
    self.Changed = Signal.new()

    local root = Drawing.textButton({
        Name = "ElysianToggle",
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = 0,
        Text = "",
        Parent = props and props.Parent,
    })
    Drawing.rounded(root, theme.CornerRadius - 2)
    Drawing.stroke(root, theme.Border, 1, 0.5)

    local label = Drawing.textLabel({
        Name = "Label",
        Size = UDim2.new(1, -64, 1, 0),
        Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = theme.Text,
        Font = theme.Font,
        TextSize = theme.FontSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = root,
    })

    -- Switch container (40 wide, 20 tall)
    local switch = Drawing.frame({
        Name = "Switch",
        Size = UDim2.fromOffset(40, 20),
        Position = UDim2.new(1, -52, 0.5, -10),
        BackgroundColor3 = self.Value and theme.Accent or theme.SurfaceAlt,
        BorderSizePixel = 0,
        Parent = root,
    })
    Drawing.rounded(switch, 10)
    Drawing.stroke(switch, theme.Border, 1, 0.4)

    local knob = Drawing.frame({
        Name = "Knob",
        Size = UDim2.fromOffset(16, 16),
        Position = self.Value and UDim2.new(1, -18, 0.5, -8) or UDim2.fromOffset(2, 2),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        Parent = switch,
    })
    Drawing.rounded(knob, 8)

    self.Instance = root
    self.Label = label
    self.Switch = switch
    self.Knob = knob

    local function applyVisual(animated: boolean)
        -- Read from self.Theme (live) instead of the captured `theme` local,
        -- so RefreshTheme actually takes effect.
        local t = self.Theme
        local targetColor = self.Value and t.Accent or t.SurfaceAlt
        local targetKnobPos = self.Value and UDim2.new(1, -18, 0.5, -8) or UDim2.fromOffset(2, 2)
        if animated then
            Tween.quick(switch, 0.15, { BackgroundColor3 = targetColor })
            Tween.quick(knob, 0.15, { Position = targetKnobPos })
        else
            switch.BackgroundColor3 = targetColor
            knob.Position = targetKnobPos
        end
    end
    self._applyVisual = applyVisual

    root.MouseButton1Click:Connect(function()
        self:Set(not self.Value)
    end)

    applyVisual(false)
    return self
end

function Toggle:Set(value: boolean, silent: boolean?)
    value = not not value
    if value == self.Value then return end
    self.Value = value
    self._applyVisual(true)
    if not silent then
        self.Changed:Fire(value)
    end
end

function Toggle:Get(): boolean
    return self.Value
end

function Toggle:OnChanged(callback: ((boolean) -> ()))
    return self.Changed:Connect(callback)
end

function Toggle:RefreshTheme(theme: { [string]: any })
    self.Theme = theme
    self.Label.TextColor3 = theme.Text
    self.Label.Font = theme.Font
    self.Label.TextSize = theme.FontSize
    self.Instance.BackgroundColor3 = theme.Surface
    self.Switch.BackgroundColor3 = self.Value and theme.Accent or theme.SurfaceAlt
    self._applyVisual(false)
end

return Toggle
