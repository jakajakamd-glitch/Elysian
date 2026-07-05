--!nonstrict
--[[
    Button - a clickable text button.

    Button.new({
        Text   = "Click me",
        Theme  = <optional theme table>,
        Parent = <Instance>,
    })
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

    local theme = (props and props.Theme) or requireRemote("src/Theme.luau").Current
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

    local function setHover(hover: boolean)
        if hover then
            -- Hover tints the button toward the accent color so it feels alive.
            Tween.quick(root, 0.12, { BackgroundColor3 = theme.AccentAlt })
        else
            Tween.quick(root, 0.12, { BackgroundColor3 = theme.Surface })
        end
    end

    root.MouseEnter:Connect(function() setHover(true) end)
    root.MouseLeave:Connect(function() setHover(false) end)
    root.MouseButton1Down:Connect(function()
        Tween.quick(root, 0.06, { BackgroundColor3 = theme.Accent })
    end)
    root.MouseButton1Up:Connect(function()
        Tween.quick(root, 0.12, { BackgroundColor3 = theme.AccentAlt })
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
    self.Label.TextColor3 = theme.Text
    self.Label.Font = theme.Font
    self.Label.TextSize = theme.FontSize
    self.Instance.BackgroundColor3 = theme.Surface
end

return Button
