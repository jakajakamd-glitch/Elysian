--!nonstrict
--[[
    Window - the root container of an Elysian UI.
    A Window hosts a tab bar and a content area, is draggable by its
    title bar, and can be minimised / closed.

    Window.new({
        Title = "Elysian UI",
        Size  = Vector2.new(560, 380),
        Theme = nil, -- optional override
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
local Theme         = requireRemote("src/Theme.luau")
local Tab           = requireRemote("src/Components/Tab.luau")

local Window = setmetatable({}, BaseComponent)
Window.__index = Window

export type WindowProps = {
    Title: string?,
    Size: Vector2?,
    Position: Vector2?,
    Theme: { [string]: any }?,
    Draggable: boolean?,
}

function Window.new(props: WindowProps?): any
    local self = BaseComponent.new() :: any
    setmetatable(self, Window)

    local theme = props and props.Theme and Theme:Merge(props.Theme) or Theme.Current
    local title = (props and props.Title) or "Elysian"
    local size  = (props and props.Size) or Vector2.new(560, 380)

    local coreGui = requireRemote("src/Services/CoreGui.luau").new()
    local container = coreGui:GetContainer("ElysianRoot")

    local root = Drawing.frame({
        Name = "ElysianWindow",
        Size = UDim2.fromOffset(size.X, size.Y),
        Position = props and props.Position and UDim2.fromOffset(props.Position.X, props.Position.Y)
            or UDim2.fromOffset(
                (workspace.CurrentCamera.ViewportSize.X - size.X) / 2,
                (workspace.CurrentCamera.ViewportSize.Y - size.Y) / 2
            ),
        BackgroundColor3 = theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = false,
        Parent = container,
    })
    Drawing.rounded(root, theme.CornerRadius)
    Drawing.stroke(root, theme.Border, 1, 0.2)
    self.Instance = root
    self.Theme = theme
    self.Tabs = {}
    self.ActiveTab = nil

    -- Title bar
    local titleBar = Drawing.frame({
        Name = "TitleBar",
        Size = UDim2.new(1, 0, 0, 40),
        Position = UDim2.fromScale(0, 0),
        BackgroundColor3 = theme.BackgroundAlt,
        BorderSizePixel = 0,
        Parent = root,
    })
    Drawing.rounded(titleBar, theme.CornerRadius)
    local _titleStrokeFix = Drawing.frame({
        Name = "TitleBarBottomFill",
        Size = UDim2.new(1, 0, 0, theme.CornerRadius),
        Position = UDim2.new(0, 0, 1, -theme.CornerRadius),
        BackgroundColor3 = theme.BackgroundAlt,
        BorderSizePixel = 0,
        Parent = titleBar,
    })
    local titleText = Drawing.textLabel({
        Name = "Title",
        Size = UDim2.new(1, -100, 1, 0),
        Position = UDim2.fromOffset(14, 0),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = theme.Text,
        Font = theme.FontBold,
        TextSize = theme.FontSize + 2,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = titleBar,
    })
    self.TitleText = titleText

    -- Close / minimise buttons
    local closeBtn = Drawing.textButton({
        Name = "Close",
        Size = UDim2.fromOffset(28, 28),
        Position = UDim2.new(1, -34, 0.5, -14),
        BackgroundColor3 = theme.Danger,
        Text = "",
        Parent = titleBar,
    })
    Drawing.rounded(closeBtn, 4)
    local _closeIcon = Drawing.textLabel({
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "X",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = theme.FontBold,
        TextSize = 14,
        Parent = closeBtn,
    })
    closeBtn.MouseButton1Click:Connect(function()
        self:Close()
    end)

    local minimiseBtn = Drawing.textButton({
        Name = "Minimise",
        Size = UDim2.fromOffset(28, 28),
        Position = UDim2.new(1, -66, 0.5, -14),
        BackgroundColor3 = theme.SurfaceAlt,
        Text = "",
        Parent = titleBar,
    })
    Drawing.rounded(minimiseBtn, 4)
    local _minimiseIcon = Drawing.textLabel({
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "_",
        TextColor3 = theme.Text,
        Font = theme.FontBold,
        TextSize = 14,
        Parent = minimiseBtn,
    })
    self._minimised = false
    minimiseBtn.MouseButton1Click:Connect(function()
        self:ToggleMinimise()
    end)

    -- Body container: tab bar (left) + content (right)
    local body = Drawing.frame({
        Name = "Body",
        Size = UDim2.new(1, 0, 1, -40),
        Position = UDim2.fromOffset(0, 40),
        BackgroundTransparency = 1,
        Parent = root,
    })
    self.Body = body

    local tabBar = Drawing.frame({
        Name = "TabBar",
        Size = UDim2.fromOffset(140, 1),
        BackgroundColor3 = theme.BackgroundAlt,
        BorderSizePixel = 0,
        Parent = body,
    })
    Drawing.padding(tabBar, 6)
    Drawing.list(tabBar, Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)
    self.TabBar = tabBar

    local contentArea = Drawing.frame({
        Name = "ContentArea",
        Size = UDim2.new(1, -140, 1, 0),
        Position = UDim2.fromOffset(140, 0),
        BackgroundColor3 = theme.Surface,
        BorderSizePixel = 0,
        Parent = body,
    })
    Drawing.rounded(contentArea, theme.CornerRadius)
    Drawing.padding(contentArea, 8)
    self.ContentArea = contentArea

    -- Dragging logic
    if props == nil or props.Draggable ~= false then
        local dragging = false
        local dragStart: Vector2?
        local startPos: UDim2?
        titleBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragStart = input.Position
                startPos = root.Position
            end
        end)
        titleBar.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)
        local UserInputService = game:GetService("UserInputService")
        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement and dragStart and startPos then
                local delta = input.Position - dragStart
                root.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end)
    end

    return self
end

-- Create a tab in this window. Returns the Tab component.
function Window:CreateTab(name: string, icon: string?): any
    local tab = Tab.new(self, name, self.Theme, icon)
    table.insert(self.Tabs, tab)
    if #self.Tabs == 1 then
        self:SelectTab(tab)
    end
    return tab
end

function Window:SelectTab(tab: any)
    for _, t in ipairs(self.Tabs) do
        t:SetActive(t == tab)
    end
    self.ActiveTab = tab
end

function Window:Close()
    Tween.quick(self.Instance, 0.15, { BackgroundTransparency = 1 })
    for _, child in ipairs(self.Instance:GetChildren()) do
        if child:IsA("GuiObject") then
            Tween.quick(child, 0.15, { BackgroundTransparency = 1 })
        end
    end
    task.wait(0.16)
    self:Destroy()
end

function Window:ToggleMinimise()
    self._minimised = not self._minimised
    if self._minimised then
        self._prevBodySize = self.Body.Size
        self.Body.Size = UDim2.new(1, 0, 0, 0)
        self.Body.Visible = false
    else
        self.Body.Visible = true
        self.Body.Size = self._prevBodySize or UDim2.new(1, 0, 1, -40)
    end
end

return Window
