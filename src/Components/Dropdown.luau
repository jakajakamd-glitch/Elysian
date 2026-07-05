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
local CoreGui       = requireRemote("src/Services/CoreGui.luau")

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

    -- The dropdown list. We parent it to a top-level ScreenGui container
    -- (NOT to `root`) so it can overflow past the scroll frame and window
    -- bounds. Position is computed from `root.AbsolutePosition` when opened.
    local overlayGui = CoreGui.new():GetContainer("ElysianDropdownOverlay")
    local list = Drawing.frame({
        Name = "List",
        Size = UDim2.fromOffset(200, 0),
        Position = UDim2.fromOffset(0, 0),
        BackgroundColor3 = theme.BackgroundAlt,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 9999,
        ClipsDescendants = true,
        Parent = overlayGui,
    })
    Drawing.rounded(list, theme.CornerRadius - 2)
    Drawing.stroke(list, theme.Border, 1, 0.6)
    Drawing.list(list, Enum.FillDirection.Vertical, 2, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)
    Drawing.padding(list, 4)
    self.List = list
    self._listItems = {}
    self._overlayGui = overlayGui

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
        -- Position the list at the dropdown root's absolute position,
        -- sized to match the root's width.
        local rootPos = root.AbsolutePosition
        local rootSize = root.AbsoluteSize
        local listWidth = math.max(rootSize.X, 160)
        local listHeight = math.min(#self.Options, 6) * 32 + 8
        list.Size = UDim2.fromOffset(listWidth, 0)
        list.Position = UDim2.fromOffset(rootPos.X, rootPos.Y + rootSize.Y)
        list.Visible = true
        rebuildList()
        Tween.quick(list, 0.15, { Size = UDim2.fromOffset(listWidth, listHeight) })
        Tween.quick(chevron, 0.15, { TextColor3 = theme.Accent })
    end

    function self:_closeList()
        if not self._open then return end
        self._open = false
        local currentWidth = list.Size.X.Offset
        local tw = Tween.quick(list, 0.12, { Size = UDim2.fromOffset(currentWidth, 0) })
        tw.Completed:Once(function()
            if not self._open then list.Visible = false end
        end)
        Tween.quick(chevron, 0.12, { TextColor3 = theme.TextMuted })
    end

    function self:_toggleList()
        if self._open then self:_closeList() else self:_openList() end
    end

    -- Use InputBegan on the root (not global UIS) so the click that opens
    -- the list doesn't immediately close it. The global "close on
    -- outside click" handler below uses a flag + task.defer to avoid
    -- racing with item clicks.
    root.MouseButton1Click:Connect(function()
        self:_toggleList()
    end)

    -- Close when tapping/clicking elsewhere (mouse or touch).
    -- We defer the check by one frame so item clicks (which fire on the
    -- same InputBegan) can register first.
    local UserInputService = game:GetService("UserInputService")
    UserInputService.InputBegan:Connect(function(input, processed)
        if not self._open then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local pos = input.Position
        local rootPos = root.AbsolutePosition
        local rootSize = root.AbsoluteSize
        local listPos = list.AbsolutePosition
        local listSize = list.AbsoluteSize
        -- If the tap is inside the dropdown root OR inside the list,
        -- let the normal handlers deal with it.
        local inRoot = pos.X >= rootPos.X and pos.X <= rootPos.X + rootSize.X
                    and pos.Y >= rootPos.Y and pos.Y <= rootPos.Y + rootSize.Y
        local inList = pos.X >= listPos.X and pos.X <= listPos.X + listSize.X
                    and pos.Y >= listPos.Y and pos.Y <= listPos.Y + listSize.Y
        if not inRoot and not inList then
            task.defer(function()
                self:_closeList()
            end)
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

function Dropdown:RefreshTheme(theme: { [string]: any })
    self.Theme = theme
    self.Label.TextColor3 = theme.TextMuted
    self.Label.Font = theme.Font
    self.Label.TextSize = theme.FontSize
    self.ValueLabel.TextColor3 = theme.Text
    self.ValueLabel.Font = theme.Font
    self.Chevron.TextColor3 = theme.TextMuted
    self.Instance.BackgroundColor3 = theme.Surface
end

return Dropdown
