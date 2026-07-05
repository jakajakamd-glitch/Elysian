--!nonstrict
--[[
    Slider - a horizontal numeric slider with a label and value display.

    Slider.new({
        Text    = "Speed",
        Min     = 0,
        Max     = 100,
        Default = 50,
        Step    = 1,            -- optional, defaults to continuous
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
local Math          = requireRemote("src/Utilities/Math.luau")
local Theme         = requireRemote("src/Theme.luau")

local Slider = setmetatable({}, BaseComponent)
Slider.__index = Slider

export type SliderProps = {
    Text: string?,
    Min: number?,
    Max: number?,
    Default: number?,
    Step: number?,
    Theme: { [string]: any }?,
    Parent: Instance?,
}

function Slider.new(props: SliderProps?): any
    local self = BaseComponent.new() :: any
    setmetatable(self, Slider)

    local theme = (props and props.Theme) or Theme.Current
    local text  = (props and props.Text) or "Slider"
    local minV  = (props and props.Min) or 0
    local maxV  = (props and props.Max) or 100
    local step  = props and props.Step
    local value = (props and props.Default) or ((minV + maxV) / 2)
    value = Math.clamp(value, minV, maxV)
    if step then
        value = math.round((value - minV) / step) * step + minV
    end

    self.Min = minV
    self.Max = maxV
    self.Step = step
    self.Value = value
    self.Theme = theme
    self.Changed = Signal.new()

    -- Use a TextButton as the root so it captures input on both desktop
    -- and mobile (Frames don't fire InputBegan for taps/clicks on themselves
    -- unless Active = true, and even then behaviour is inconsistent).
    local root = Drawing.textButton({
        Name = "ElysianSlider",
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Parent = props and props.Parent,
    })
    Drawing.rounded(root, theme.CornerRadius - 2)
    Drawing.stroke(root, theme.Border, 1, 0.5)

    local label = Drawing.textLabel({
        Name = "Label",
        Size = UDim2.new(1, -64, 0, 18),
        Position = UDim2.fromOffset(12, 4),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = theme.Text,
        Font = theme.Font,
        TextSize = theme.FontSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = root,
    })

    local valueLabel = Drawing.textLabel({
        Name = "Value",
        Size = UDim2.fromOffset(48, 18),
        Position = UDim2.new(1, -60, 0, 4),
        BackgroundTransparency = 1,
        Text = string.format("%.0f", value),
        TextColor3 = theme.TextMuted,
        Font = theme.FontMono,
        TextSize = theme.FontSize,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = root,
    })

    local track = Drawing.frame({
        Name = "Track",
        Size = UDim2.new(1, -24, 0, 6),
        Position = UDim2.fromOffset(12, 28),
        BackgroundColor3 = theme.SurfaceAlt,
        BorderSizePixel = 0,
        Parent = root,
    })
    Drawing.rounded(track, 3)

    local fill = Drawing.frame({
        Name = "Fill",
        Size = UDim2.fromScale(Math.invLerpClamped(minV, maxV, value), 1),
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
        Parent = track,
    })
    Drawing.rounded(fill, 3)

    local knob = Drawing.frame({
        Name = "Knob",
        Size = UDim2.fromOffset(14, 14),
        Position = UDim2.new(Math.invLerpClamped(minV, maxV, value), -7, 0.5, -7),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        Parent = track,
    })
    Drawing.rounded(knob, 7)

    self.Instance = root
    self.Label = label
    self.ValueLabel = valueLabel
    self.Track = track
    self.Fill = fill
    self.Knob = knob

    local dragging = false
    local _lastInput: InputObject? = nil

    -- Update the value from any input position (mouse OR touch).
    local function updateFromInput(input: InputObject)
        local trackPos = track.AbsolutePosition
        local trackSize = track.AbsoluteSize
        if trackSize.X <= 0 then return end
        local rel = (input.Position.X - trackPos.X) / trackSize.X
        rel = Math.clamp(rel, 0, 1)
        local v = minV + (maxV - minV) * rel
        if step and step > 0 then
            v = math.round((v - minV) / step) * step + minV
        end
        v = Math.clamp(v, minV, maxV)
        self._applyValue(v, true)
    end

    -- Make the whole slider row tappable (not just the thin track).
    -- This is critical for mobile usability.
    root.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            _lastInput = input
            updateFromInput(input)
            Tween.quick(knob, 0.1, { Size = UDim2.fromOffset(18, 18) })
        end
    end)
    root.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            _lastInput = nil
            Tween.quick(knob, 0.12, { Size = UDim2.fromOffset(14, 14) })
        end
    end)

    -- Listen for global input changes so dragging keeps working even when
    -- the finger/cursor leaves the slider's bounds.
    local UserInputService = game:GetService("UserInputService")
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromInput(input)
        end
    end)
    -- Also handle the case where input ends outside the slider.
    UserInputService.InputEnded:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            Tween.quick(knob, 0.12, { Size = UDim2.fromOffset(14, 14) })
        end
    end)

    function self._applyValue(v: number, fire: boolean?)
        self.Value = v
        local t = Math.invLerpClamped(minV, maxV, v)
        -- Animate fill width and knob position for fluid feel when not dragging.
        if not dragging then
            Tween.quick(self.Fill, 0.12, { Size = UDim2.fromScale(t, 1) },
                Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
            Tween.quick(self.Knob, 0.12, { Position = UDim2.new(t, -7, 0.5, -7) },
                Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        else
            self.Fill.Size = UDim2.fromScale(t, 1)
            self.Knob.Position = UDim2.new(t, -7, 0.5, -7)
        end
        local display: string
        if step and step >= 1 then
            display = string.format("%d", math.floor(v + 0.5))
        else
            display = string.format("%.2f", v)
        end
        self.ValueLabel.Text = display
        if fire then
            self.Changed:Fire(v)
        end
    end

    return self
end

function Slider:Set(value: number, silent: boolean?)
    value = Math.clamp(value, self.Min, self.Max)
    if self.Step and self.Step > 0 then
        value = math.round((value - self.Min) / self.Step) * self.Step + self.Min
    end
    self:_applyValue(value, not silent)
end

function Slider:Get(): number
    return self.Value
end

function Slider:OnChanged(callback: ((number) -> ()))
    return self.Changed:Connect(callback)
end

function Slider:RefreshTheme(theme: { [string]: any })
    self.Theme = theme
    Tween.quick(self.Label, 0.2, { TextColor3 = theme.Text })
    self.Label.Font = theme.Font
    self.Label.TextSize = theme.FontSize
    Tween.quick(self.ValueLabel, 0.2, { TextColor3 = theme.TextMuted })
    self.ValueLabel.Font = theme.FontMono
    Tween.quick(self.Instance, 0.2, { BackgroundColor3 = theme.Surface })
    Tween.quick(self.Track, 0.2, { BackgroundColor3 = theme.SurfaceAlt })
    Tween.quick(self.Fill, 0.2, { BackgroundColor3 = theme.Accent })
end

return Slider
