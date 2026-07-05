--!nonstrict
--[[
    TextBox - a labelled text input with focus / commit semantics.

    TextBox.new({
        Text    = "Player name",
        Default = "Sample",
        Placeholder = "...",     -- optional
        Theme   = <optional>,
        Parent  = <Instance>,
    })

    OnChanged fires on FocusLost (Enter or click-away).
]]

local BASE_URL = "https://raw.githubusercontent.com/jakajakamd-glitch/Elysian/main"

local function requireRemote(path: string): any
    local source
    if game and game.GetService then
        source = game:HttpGet(BASE_URL .. "/" .. path, true)
    else
        local res = request({ Url = BASE_URL .. "/" .. path, Method = "GET" })
        source = res.Body
    end
    return loadstring(source, path)()
end

local BaseComponent = requireRemote("src/Components/BaseComponent.luau")
local Drawing       = requireRemote("src/Utilities/Drawing.luau")
local Tween         = requireRemote("src/Utilities/Tween.luau")
local Signal        = requireRemote("src/Utilities/Signal.luau")
local Theme         = requireRemote("src/Theme.luau")

local TextBox = setmetatable({}, BaseComponent)
TextBox.__index = TextBox

export type TextBoxProps = {
    Text: string?,
    Default: string?,
    Placeholder: string?,
    Theme: { [string]: any }?,
    Parent: Instance?,
}

function TextBox.new(props: TextBoxProps?): any
    local self = BaseComponent.new() :: any
    setmetatable(self, TextBox)

    local theme = (props and props.Theme) or Theme.Current
    local text  = (props and props.Text) or "Input"
    local default = (props and props.Default) or ""
    local placeholder = (props and props.Placeholder) or ""

    self.Value = default
    self.Theme = theme
    self.Changed = Signal.new()

    local root = Drawing.frame({
        Name = "ElysianTextBox",
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Parent = props and props.Parent,
    })
    Drawing.rounded(root, theme.CornerRadius - 2)
    Drawing.stroke(root, theme.Border, 1, 0.5)

    local label = Drawing.textLabel({
        Name = "Label",
        Size = UDim2.new(0, 100, 1, 0),
        Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = theme.TextMuted,
        Font = theme.Font,
        TextSize = theme.FontSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = root,
    })

    local input = Drawing.textBox({
        Name = "Input",
        Size = UDim2.new(1, -120, 1, 0),
        Position = UDim2.fromOffset(112, 0),
        BackgroundTransparency = 1,
        Text = default,
        PlaceholderText = placeholder,
        PlaceholderColor3 = theme.TextMuted,
        TextColor3 = theme.Text,
        Font = theme.FontMono,
        TextSize = theme.FontSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = root,
    })

    self.Instance = root
    self.Label = label
    self.Input = input

    input.Focused:Connect(function()
        Tween.quick(root, 0.15, { BackgroundColor3 = theme.SurfaceAlt })
    end)
    input.FocusLost:Connect(function(enterPressed: boolean)
        Tween.quick(root, 0.15, { BackgroundColor3 = theme.Surface })
        self.Value = input.Text
        self.Changed:Fire(input.Text, enterPressed)
    end)

    return self
end

function TextBox:Set(value: string, silent: boolean?)
    self.Value = value
    self.Input.Text = value
    if not silent then
        self.Changed:Fire(value, false)
    end
end

function TextBox:Get(): string
    return self.Value
end

function TextBox:OnChanged(callback: ((string, boolean) -> ()))
    return self.Changed:Connect(callback)
end

function TextBox:RefreshTheme(theme: { [string]: any })
    self.Theme = theme
    self.Label.TextColor3 = theme.TextMuted
    self.Label.Font = theme.Font
    self.Label.TextSize = theme.FontSize
    self.Input.TextColor3 = theme.Text
    self.Input.Font = theme.FontMono
    self.Input.TextSize = theme.FontSize
    self.Instance.BackgroundColor3 = theme.Surface
end

return TextBox
