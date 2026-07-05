--!nonstrict
--[[
    Label - simple, non-interactive text line.

    Label.new({
        Text = "Section title",
        Theme = <optional>,
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
local Theme         = requireRemote("src/Theme.luau")

local Label = setmetatable({}, BaseComponent)
Label.__index = Label

export type LabelProps = {
    Text: string?,
    Color: Color3?,
    Font: EnumItem?,
    TextSize: number?,
    Theme: { [string]: any }?,
    Parent: Instance?,
}

function Label.new(props: LabelProps?): any
    local self = BaseComponent.new() :: any
    setmetatable(self, Label)

    local theme = (props and props.Theme) or Theme.Current
    local text  = (props and props.Text) or ""

    local root = Drawing.frame({
        Name = "ElysianLabel",
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        Parent = props and props.Parent,
    })

    local label = Drawing.textLabel({
        Name = "Label",
        Size = UDim2.new(1, -8, 1, 0),
        Position = UDim2.fromOffset(4, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = (props and props.Color) or theme.TextMuted,
        Font = (props and props.Font) or theme.Font,
        TextSize = (props and props.TextSize) or (theme.FontSize - 1),
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = root,
    })

    self.Instance = root
    self.Label = label
    self.Theme = theme

    return self
end

function Label:SetText(text: string)
    self.Label.Text = text
end

function Label:SetColor(color: Color3)
    self.Label.TextColor3 = color
end

function Label:RefreshTheme(theme: { [string]: any })
    self.Theme = theme
    self.Label.Font = theme.Font
    self.Label.TextSize = theme.FontSize - 1
    self.Label.TextColor3 = theme.TextMuted
end

return Label
