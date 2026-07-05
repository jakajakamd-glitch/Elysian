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
    Tween.quick(self.Label, 0.2, { TextColor3 = theme.TextMuted })
end

return Label
