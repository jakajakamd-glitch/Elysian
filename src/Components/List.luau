--!nonstrict
--[[
    List - a scrollable list of selectable items.

    List.new({
        Items = { "Apple", "Banana", "Cherry" },  -- array of strings or {Text=, Icon=, Data=} tables
        MultiSelect = false,                        -- allow multiple selections
        DefaultIndex = 1,                           -- index to select initially (1-based)
        OnSelect = function(item, index) end,       -- callback when an item is selected
        Height = 200,                               -- pixel height of the list
        Theme = <optional>,
        Parent = <Instance>,
    })

    Methods:
        :SetItems(items)        - replace all items
        :AddItem(item)          - append an item
        :RemoveItem(index)      - remove item at index
        :Clear()                - remove all items
        :Select(index)          - select item at index
        :GetSelected()          - returns selected index (or array if MultiSelect)
        :RefreshTheme(theme)    - re-apply theme
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

local List = setmetatable({}, BaseComponent)
List.__index = List

export type ListProps = {
    Items: { any }?,
    MultiSelect: boolean?,
    DefaultIndex: number?,
    OnSelect: ((any, number) -> ())?,
    Height: number?,
    Theme: { [string]: any }?,
    Parent: Instance?,
    Title: string?,
}

local function getItemText(item: any): string
    if type(item) == "string" then return item end
    if type(item) == "table" then
        return item.Text or item.text or tostring(item)
    end
    return tostring(item)
end

local function getItemData(item: any): any
    if type(item) == "table" then
        return item.Data or item.data or item
    end
    return item
end

function List.new(props: ListProps?): any
    local self = BaseComponent.new() :: any
    setmetatable(self, List)

    local theme = (props and props.Theme) or Theme.Current
    self.Theme = theme
    self._items = {}
    self._itemButtons = {}
    self._selected = {}  -- map of index -> true (for multi-select)
    self._multiSelect = not not (props and props.MultiSelect)
    self._height = (props and props.Height) or 200
    self.Changed = Signal.new()

    if props and props.OnSelect then
        self.Changed:Connect(function(item, index)
            props.OnSelect(item, index)
        end)
    end

    -- Root container
    local root = Drawing.frame({
        Name = "ElysianList",
        Size = UDim2.new(1, 0, 0, self._height),
        BackgroundColor3 = theme.BackgroundAlt or Color3.fromRGB(24, 26, 33),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Parent = props and props.Parent,
    })
    Drawing.rounded(root, (theme.CornerRadius or 8) - 2)
    Drawing.stroke(root, theme.Border or Color3.fromRGB(56, 60, 76), 1, 0.5)

    -- Optional title
    local titleLabel
    local scrollOffset = 4
    if props and props.Title then
        titleLabel = Drawing.textLabel({
            Name = "Title",
            Size = UDim2.new(1, -12, 0, 20),
            Position = UDim2.fromOffset(8, 4),
            BackgroundTransparency = 1,
            Text = props.Title,
            TextColor3 = theme.TextMuted or Color3.fromRGB(150, 155, 170),
            Font = theme.Font or Enum.Font.GothamMedium,
            TextSize = (theme.FontSize or 15) - 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = root,
        })
        scrollOffset = 26
    end

    -- Scroll frame for items
    local scroll = Drawing.scrollFrame({
        Name = "ScrollList",
        Size = UDim2.new(1, -4, 1, -scrollOffset - 4),
        Position = UDim2.fromOffset(2, scrollOffset),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = root,
    })
    Drawing.list(scroll, Enum.FillDirection.Vertical, 2,
        Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)
    Drawing.padding(scroll, 2)

    self.Instance = root
    self.TitleLabel = titleLabel
    self.Scroll = scroll

    -- Populate initial items
    if props and props.Items then
        self:SetItems(props.Items)
    end

    -- Select default
    if props and props.DefaultIndex then
        self:Select(props.DefaultIndex)
    end

    return self
end

function List:_rebuildItems()
    -- Clear existing buttons
    for _, btn in ipairs(self._itemButtons) do
        pcall(function() btn:Destroy() end)
    end
    self._itemButtons = {}

    -- Create buttons for each item
    for i, item in ipairs(self._items) do
        local text = getItemText(item)
        local isSelected = self._selected[i] == true
        local theme = self.Theme

        local btn = Drawing.textButton({
            Name = "Item_" .. i,
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundColor3 = isSelected and (theme.Accent or Color3.fromRGB(86, 156, 255))
                                       or (theme.Surface or Color3.fromRGB(30, 33, 42)),
            BackgroundTransparency = isSelected and 0 or 0.3,
            Text = text,
            TextColor3 = isSelected and Color3.fromRGB(255, 255, 255)
                                   or (theme.Text or Color3.fromRGB(232, 234, 240)),
            Font = theme.Font or Enum.Font.GothamMedium,
            TextSize = theme.FontSize or 15,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            LayoutOrder = i,
            Parent = self.Scroll,
        })
        Drawing.rounded(btn, 4)

        -- Hover effect
        btn.MouseEnter:Connect(function()
            if not self._selected[i] then
                Tween.quick(btn, 0.12, { BackgroundTransparency = 0 })
            end
        end)
        btn.MouseLeave:Connect(function()
            if not self._selected[i] then
                Tween.quick(btn, 0.12, { BackgroundTransparency = 0.3 })
            end
        end)

        -- Click to select
        btn.MouseButton1Click:Connect(function()
            self:Select(i)
        end)

        table.insert(self._itemButtons, btn)
    end
end

function List:SetItems(items: { any })
    self._items = items or {}
    self._selected = {}
    self:_rebuildItems()
end

function List:AddItem(item: any)
    table.insert(self._items, item)
    self:_rebuildItems()
end

function List:RemoveItem(index: number)
    if index < 1 or index > #self._items then return end
    table.remove(self._items, index)
    -- Rebuild selected map with shifted indices
    local newSelected = {}
    for i in pairs(self._selected) do
        if i < index then
            newSelected[i] = true
        elseif i > index then
            newSelected[i - 1] = true
        end
    end
    self._selected = newSelected
    self:_rebuildItems()
end

function List:Clear()
    self._items = {}
    self._selected = {}
    self:_rebuildItems()
end

function List:Select(index: number)
    if index < 1 or index > #self._items then return end

    if not self._multiSelect then
        self._selected = {}
    end

    -- Toggle selection if already selected (in multi-select mode)
    if self._multiSelect and self._selected[index] then
        self._selected[index] = nil
    else
        self._selected[index] = true
    end

    self:_rebuildItems()

    local item = self._items[index]
    local data = getItemData(item)
    self.Changed:Fire(data, index)
end

function List:GetSelected(): any
    if self._multiSelect then
        local result = {}
        for i in pairs(self._selected) do
            table.insert(result, getItemData(self._items[i]))
        end
        return result
    else
        for i in pairs(self._selected) do
            return getItemData(self._items[i]), i
        end
    end
    return nil
end

function List:GetSelectedIndex(): number?
    for i in pairs(self._selected) do
        return i
    end
    return nil
end

function List:OnChanged(callback: ((any, number) -> ()))
    return self.Changed:Connect(callback)
end

function List:SetHeight(height: number)
    self._height = height
    if self.Instance then
        self.Instance.Size = UDim2.new(1, 0, 0, height)
    end
end

function List:RefreshTheme(theme: { [string]: any })
    self.Theme = theme
    if self.Instance then
        self.Instance.BackgroundColor3 = theme.BackgroundAlt or Color3.fromRGB(24, 26, 33)
    end
    if self.TitleLabel then
        self.TitleLabel.Font = theme.Font or Enum.Font.GothamMedium
        self.TitleLabel.TextSize = (theme.FontSize or 15) - 1
        self.TitleLabel.TextColor3 = theme.TextMuted or Color3.fromRGB(150, 155, 170)
    end
    -- Rebuild items with new theme colors
    self:_rebuildItems()
end

return List
