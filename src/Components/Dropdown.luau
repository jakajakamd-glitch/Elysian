--!nonstrict
--[[
    Dropdown - a labelled selection control.

    Dropdown.new({
        Text    = "Mode",
        Options = { "Normal", "Aggressive", "Passive" },
        Default = "Normal",
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

local Dropdown = setmetatable({}, BaseComponent)
Dropdown.__index = Dropdown

export type DropdownProps = {
    Text: string?,
    Options: { string }?,
    Default: string?,
    Theme: { [string]: any }?,
    Parent: Instance?,
}

function Dropdown.new(props: DropdownProps?): any
    local self = BaseComponent.new() :: any
    setmetatable(self, Dropdown)

    local theme = (props and props.Theme) or Theme.Current
    local text  = (props and props.Text) or "Dropdown"
    local options = (props and props.Options) or {}
    local default = (props and props.Default) or (options[1] or "")

    self.Options = options
    self.Value = default
    self.Theme = theme
    self.Changed = Signal.new()
    self._open = false

    local root = Drawing.textButton({
        Name = "ElysianDropdown",
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

    local valueLabel = Drawing.textLabel({
        Name = "Value",
        Size = UDim2.new(1, -130, 1, 0),
        Position = UDim2.fromOffset(112, 0),
        BackgroundTransparency = 1,
        Text = default,
        TextColor3 = theme.Text,
        Font = theme.Font,
        TextSize = theme.FontSize,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = root,
    })

    local chevron = Drawing.textLabel({
        Name = "Chevron",
        Size = UDim2.fromOffset(20, 20),
        Position = UDim2.new(1, -28, 0.5, -10),
        BackgroundTransparency = 1,
        Text = "v",
        TextColor3 = theme.TextMuted,
        Font = theme.FontBold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = root,
    })

    -- The dropdown list (hidden by default). We parent it to the root so it
    -- pops above subsequent siblings; for full overflow we'd parent to the
    -- ScreenGui root, but this approach keeps things simple.
    local list = Drawing.frame({
        Name = "List",
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.fromOffset(0, 36),
        BackgroundColor3 = theme.BackgroundAlt,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 100,
        ClipsDescendants = true,
        Parent = root,
    })
    Drawing.rounded(list, theme.CornerRadius - 2)
    Drawing.stroke(list, theme.Border, 1, 0.6)
    Drawing.list(list, Enum.FillDirection.Vertical, 2, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)
    Drawing.padding(list, 4)
    self.List = list
    self._listItems = {}

    self.Instance = root
    self.Label = label
    self.ValueLabel = valueLabel
    self.Chevron = chevron

    local function rebuildList()
        for _, item in ipairs(self._listItems) do
            item:Destroy()
        end
        self._listItems = {}
        for _, opt in ipairs(self.Options) do
            local item = Drawing.textButton({
                Name = "Item_" .. opt,
                Size = UDim2.new(1, 0, 0, 28),
                BackgroundColor3 = theme.Surface,
                BackgroundTransparency = opt == self.Value and 0 or 1,
                Text = "",
                LayoutOrder = #self._listItems + 1,
                Parent = list,
            })
            Drawing.rounded(item, 4)
            local _itemLabel = Drawing.textLabel({
                Size = UDim2.new(1, -12, 1, 0),
                Position = UDim2.fromOffset(8, 0),
                BackgroundTransparency = 1,
                Text = opt,
                TextColor3 = opt == self.Value and theme.Accent or theme.Text,
                Font = theme.Font,
                TextSize = theme.FontSize,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = item,
            })
            item.MouseButton1Click:Connect(function()
                self:Set(opt)
                self:_closeList()
            end)
            table.insert(self._listItems, item)
        end
    end

    function self:_openList()
        if self._open then return end
        self._open = true
        list.Visible = true
        rebuildList()
        Tween.quick(list, 0.15, { Size = UDim2.new(1, 0, 0, math.min(#self.Options, 6) * 32 + 8) })
        Tween.quick(chevron, 0.15, { TextColor3 = theme.Accent })
    end

    function self:_closeList()
        if not self._open then return end
        self._open = false
        local tw = Tween.quick(list, 0.12, { Size = UDim2.new(1, 0, 0, 0) })
        tw.Completed:Once(function()
            if not self._open then list.Visible = false end
        end)
        Tween.quick(chevron, 0.12, { TextColor3 = theme.TextMuted })
    end

    function self:_toggleList()
        if self._open then self:_closeList() else self:_openList() end
    end

    root.MouseButton1Click:Connect(function()
        self:_toggleList()
    end)

    -- Close when clicking elsewhere
    local UserInputService = game:GetService("UserInputService")
    UserInputService.InputBegan:Connect(function(input, processed)
        if self._open and input.UserInputType == Enum.UserInputType.MouseButton1 and processed == false then
            local mousePos = UserInputService:GetMouseLocation()
            local rootPos = root.AbsolutePosition
            local rootSize = root.AbsoluteSize
            if mousePos.X < rootPos.X or mousePos.X > rootPos.X + rootSize.X
                or mousePos.Y < rootPos.Y or mousePos.Y > rootPos.Y + rootSize.Y + 200 then
                self:_closeList()
            end
        end
    end)

    return self
end

function Dropdown:Set(value: string, silent: boolean?)
    if table.find(self.Options, value) == nil then return end
    if value == self.Value then return end
    self.Value = value
    self.ValueLabel.Text = value
    if not silent then
        self.Changed:Fire(value)
    end
end

function Dropdown:Get(): string
    return self.Value
end

function Dropdown:SetOptions(options: { string })
    self.Options = options
    if table.find(options, self.Value) == nil then
        self.Value = options[1] or ""
        self.ValueLabel.Text = self.Value
    end
end

function Dropdown:OnChanged(callback: ((string) -> ()))
    return self.Changed:Connect(callback)
end

return Dropdown
