--!nonstrict
--[[
    KeyPicker - lets the user bind an Enum.KeyCode to an action.

    KeyPicker.new({
        Text    = "Activate",
        Default = Enum.KeyCode.E,
        Theme   = <optional>,
        Parent  = <Instance>,
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
local Theme         = requireRemote("src/Theme.luau")

local KeyPicker = setmetatable({}, BaseComponent)
KeyPicker.__index = KeyPicker

export type KeyPickerProps = {
    Text: string?,
    Default: EnumItem?,
    Theme: { [string]: any }?,
    Parent: Instance?,
}

local function keyName(keyCode: EnumItem?): string
    if not keyCode then return "None" end
    local name = keyCode.Name
    return name
end

function KeyPicker.new(props: KeyPickerProps?): any
    local self = BaseComponent.new() :: any
    setmetatable(self, KeyPicker)

    local theme = (props and props.Theme) or Theme.Current
    local text  = (props and props.Text) or "Key"
    local default = props and props.Default

    self.Value = default
    self.Theme = theme
    self.Changed = Signal.new()
    self._listening = false

    local root = Drawing.frame({
        Name = "ElysianKeyPicker",
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
        Size = UDim2.new(1, -100, 1, 0),
        Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = theme.Text,
        Font = theme.Font,
        TextSize = theme.FontSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = root,
    })

    local display = Drawing.textButton({
        Name = "Display",
        Size = UDim2.fromOffset(72, 24),
        Position = UDim2.new(1, -84, 0.5, -12),
        BackgroundColor3 = theme.SurfaceAlt,
        BackgroundTransparency = 0,
        Text = keyName(default),
        TextColor3 = theme.Text,
        Font = theme.FontMono,
        TextSize = theme.FontSize - 1,
        AutoButtonColor = false,
        Parent = root,
    })
    Drawing.rounded(display, 4)

    self.Instance = root
    self.Label = label
    self.Display = display

    local UserInputService = game:GetService("UserInputService")

    local function startListening()
        self._listening = true
        display.Text = "..."
        Tween.quick(display, 0.15, { BackgroundColor3 = theme.Accent, TextColor3 = Color3.fromRGB(255, 255, 255) })
    end

    local function stopListening()
        self._listening = false
        display.Text = keyName(self.Value)
        Tween.quick(display, 0.15, { BackgroundColor3 = theme.SurfaceAlt, TextColor3 = theme.Text })
    end

    display.MouseButton1Click:Connect(function()
        if self._listening then
            stopListening()
        else
            startListening()
        end
    end)

    UserInputService.InputBegan:Connect(function(input, processed)
        if not self._listening then return end
        if processed then return end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode == Enum.KeyCode.Escape then
                stopListening()
                return
            end
            self.Value = input.KeyCode
            self.Changed:Fire(input.KeyCode)
            stopListening()
        elseif input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.MouseButton2
            or input.UserInputType == Enum.UserInputType.MouseButton3 then
            self.Value = input.UserInputType
            self.Changed:Fire(input.UserInputType)
            stopListening()
        end
    end)

    return self
end

function KeyPicker:Set(keyCode: EnumItem?, silent: boolean?)
    self.Value = keyCode
    self.Display.Text = keyName(keyCode)
    if not silent then
        self.Changed:Fire(keyCode)
    end
end

function KeyPicker:Get(): EnumItem?
    return self.Value
end

function KeyPicker:OnChanged(callback: ((EnumItem?) -> ()))
    return self.Changed:Connect(callback)
end

return KeyPicker
