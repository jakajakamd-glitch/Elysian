--!nonstrict
--[[
    Window - the root container of an Elysian UI.
    A Window hosts a tab bar and a content area, is draggable by its
    title bar (mouse OR touch), can be minimised / closed, and ships
    with an always-visible floating OpenButton to toggle its visibility.

    Window.new({
        Title      = "Elysian UI",
        Size       = Vector2.new(560, 380),
        Position   = Vector2.new(...),        -- optional
        Theme      = nil,                     -- optional override
        Draggable  = true,                    -- default true
        OpenButton = true,                    -- default true (set false to disable)
        OpenHotkey = Enum.KeyCode.RightShift, -- optional keyboard hotkey
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
local OpenButton    = requireRemote("src/Components/OpenButton.luau")
local Logger        = requireRemote("src/Utilities/Logger.luau")

local Window = setmetatable({}, BaseComponent)
Window.__index = Window

export type WindowProps = {
    Title: string?,
    Size: Vector2?,
    Position: Vector2?,
    Theme: { [string]: any }?,
    Draggable: boolean?,
    OpenButton: boolean?,
    OpenHotkey: EnumItem?,
}

function Window.new(props: WindowProps?): any
    local self = BaseComponent.new() :: any
    setmetatable(self, Window)

    local theme = props and props.Theme and Theme:Merge(props.Theme) or Theme.Current
    local title = (props and props.Title) or "Elysian"
    local size  = (props and props.Size) or Vector2.new(560, 380)

    Logger:Debug("[Window] creating '" .. title .. "' (" .. size.X .. "x" .. size.Y .. ")")

    local coreGui = requireRemote("src/Services/CoreGui.luau").new()
    local container = coreGui:GetContainer("ElysianRoot")

    local initialPos = props and props.Position and UDim2.fromOffset(props.Position.X, props.Position.Y)
        or UDim2.fromOffset(
            (workspace.CurrentCamera.ViewportSize.X - size.X) / 2,
            (workspace.CurrentCamera.ViewportSize.Y - size.Y) / 2
        )

    local root = Drawing.frame({
        Name = "ElysianWindow",
        Size = UDim2.fromOffset(size.X, size.Y),
        Position = initialPos,
        BackgroundColor3 = theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = container,
    })
    Drawing.rounded(root, theme.CornerRadius)
    Drawing.stroke(root, theme.Border, 1, 0.2)
    self.Instance = root
    self.Theme = theme
    self.Tabs = {}
    self.ActiveTab = nil
    self._isOpen = true
    self._minimised = false
    self._size = size

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
    self.TitleBar = titleBar

    -- Close / minimise buttons (with hover + press animation)
    local closeBtn = Drawing.textButton({
        Name = "Close",
        Size = UDim2.fromOffset(28, 28),
        Position = UDim2.new(1, -34, 0.5, -14),
        BackgroundColor3 = theme.Danger,
        BackgroundTransparency = 0.2,
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
    closeBtn.MouseEnter:Connect(function()
        Tween.quick(closeBtn, 0.12, { BackgroundTransparency = 0 })
    end)
    closeBtn.MouseLeave:Connect(function()
        Tween.quick(closeBtn, 0.12, { BackgroundTransparency = 0.2 })
    end)
    closeBtn.MouseButton1Click:Connect(function()
        Logger:Debug("[Window] close clicked")
        self:Hide()
    end)

    local minimiseBtn = Drawing.textButton({
        Name = "Minimise",
        Size = UDim2.fromOffset(28, 28),
        Position = UDim2.new(1, -66, 0.5, -14),
        BackgroundColor3 = theme.SurfaceAlt,
        BackgroundTransparency = 0.2,
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
    minimiseBtn.MouseEnter:Connect(function()
        Tween.quick(minimiseBtn, 0.12, { BackgroundTransparency = 0 })
    end)
    minimiseBtn.MouseLeave:Connect(function()
        Tween.quick(minimiseBtn, 0.12, { BackgroundTransparency = 0.2 })
    end)
    minimiseBtn.MouseButton1Click:Connect(function()
        Logger:Debug("[Window] minimise clicked")
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

    -- Dragging logic (mouse + touch)
    if props == nil or props.Draggable ~= false then
        local dragging = false
        local dragStart: Vector2?
        local startPos: UDim2?
        titleBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = root.Position
            end
        end)
        titleBar.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        local UserInputService = game:GetService("UserInputService")
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch)
                and dragStart and startPos then
                local delta = input.Position - dragStart
                root.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end)
    end

    -- Open button (floating, always visible) to toggle this window's visibility
    if props == nil or props.OpenButton ~= false then
        self.OpenButton = OpenButton.new({
            Text = string.sub(title or "E", 1, 1),
            Theme = theme,
            Hotkey = props and props.OpenHotkey,
        })
        self.OpenButton:OnPressed(function()
            self:Toggle()
        end)
    end

    -- Open animation
    root.BackgroundTransparency = 1
    root.Size = UDim2.fromOffset(size.X * 0.92, size.Y * 0.92)
    Tween.quick(root, 0.25, {
        BackgroundTransparency = 0,
        Size = UDim2.fromOffset(size.X, size.Y),
    }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

    Logger:Debug("[Window] created")
    return self
end

-- Create a tab in this window. Returns the Tab component.
function Window:CreateTab(name: string, icon: string?): any
    Logger:Debug("[Window] CreateTab: " .. name)
    local tab = Tab.new(self, name, self.Theme, icon)
    table.insert(self.Tabs, tab)
    if #self.Tabs == 1 then
        self:SelectTab(tab)
    end
    return tab
end

function Window:SelectTab(tab: any)
    Logger:Debug("[Window] SelectTab: " .. tab.Name)
    for _, t in ipairs(self.Tabs) do
        t:SetActive(t == tab)
    end
    self.ActiveTab = tab
end

-- Smoothly hide the window (used by the close button).
function Window:Hide()
    if not self._isOpen then return end
    self._isOpen = false
    Logger:Debug("[Window] Hide")
    Tween.quick(self.Instance, 0.18, {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(self._size.X * 0.92, self._size.Y * 0.92),
    }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    for _, child in ipairs(self.Instance:GetDescendants()) do
        if child:IsA("GuiObject") then
            Tween.quick(child, 0.15, { BackgroundTransparency = 1 })
        end
    end
    task.delay(0.2, function()
        if self.Instance then self.Instance.Visible = false end
    end)
end

-- Smoothly show the window.
function Window:Show()
    if self._isOpen then return end
    self._isOpen = true
    Logger:Debug("[Window] Show")
    self.Instance.Visible = true
    self.Instance.BackgroundTransparency = 1
    Tween.quick(self.Instance, 0.22, {
        BackgroundTransparency = 0,
        Size = UDim2.fromOffset(self._size.X, self._size.Y),
    }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    for _, child in ipairs(self.Instance:GetDescendants()) do
        if child:IsA("GuiObject") then
            Tween.quick(child, 0.18, { BackgroundTransparency = 0 })
        end
    end
end

-- Toggle visibility (called by the OpenButton).
function Window:Toggle()
    if self._isOpen then self:Hide() else self:Show() end
end

-- Hard close: animate out and destroy.
function Window:Close()
    Logger:Debug("[Window] Close (destroy)")
    Tween.quick(self.Instance, 0.15, {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(self._size.X * 0.9, self._size.Y * 0.9),
    }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    task.wait(0.16)
    if self.OpenButton then
        self.OpenButton:Destroy()
    end
    self:Destroy()
end

function Window:ToggleMinimise()
    self._minimised = not self._minimised
    Logger:Debug("[Window] ToggleMinimise -> " .. tostring(self._minimised))
    if self._minimised then
        self._prevBodySize = self.Body.Size
        self.Body.Visible = true
        Tween.quick(self.Body, 0.2, {
            Size = UDim2.new(1, 0, 0, 0),
            Position = UDim2.fromOffset(0, 40),
        }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        task.delay(0.2, function()
            if self._minimised then self.Body.Visible = false end
        end)
    else
        self.Body.Visible = true
        Tween.quick(self.Body, 0.22, {
            Size = self._prevBodySize or UDim2.new(1, 0, 1, -40),
            Position = UDim2.fromOffset(0, 40),
        }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    end
end

return Window
