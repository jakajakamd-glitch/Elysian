--!nonstrict
--[[
    Window - the root container of an Elysian UI.

    Features:
    - Responsive: auto-clamps to viewport, switches to mobile layout
      (top tab bar) on small/touch screens.
    - Draggable by title bar (mouse + touch).
    - Smooth open/close/minimise animations (root-only, preserves
      descendant transparency/colors).
    - Customizable floating OpenButton.
    - Live theme refresh via :RefreshTheme().

    Window.new({
        Title      = "Elysian UI",
        Size       = Vector2.new(560, 380),  -- desired size (auto-clamped)
        MinSize    = Vector2.new(320, 240),  -- minimum size (optional)
        Position   = Vector2.new(...),        -- optional explicit position
        Theme      = nil,                     -- optional override
        Draggable  = true,                    -- default true
        Resizable  = true,                    -- auto-resize on viewport change
        OpenButton = true,                    -- default true
        OpenButtonProps = {...},              -- customize the FAB
        OpenHotkey = Enum.KeyCode.RightShift, -- optional keyboard hotkey
        MobileLayout = nil,                   -- force "mobile" | "desktop" | nil (auto)
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
local Theme         = requireRemote("src/Theme.luau")
local Tab           = requireRemote("src/Components/Tab.luau")
local OpenButton    = requireRemote("src/Components/OpenButton.luau")
local Logger        = requireRemote("src/Utilities/Logger.luau")
local Viewport      = requireRemote("src/Utilities/Viewport.luau")

local Window = setmetatable({}, BaseComponent)
Window.__index = Window

export type WindowProps = {
    Title: string?,
    Size: Vector2?,
    MinSize: Vector2?,
    Position: Vector2?,
    Theme: { [string]: any }?,
    Draggable: boolean?,
    Resizable: boolean?,
    OpenButton: boolean?,
    OpenButtonProps: any?,
    OpenHotkey: EnumItem?,
    MobileLayout: string?,
}

-- Layout constants
local DESKTOP_TABBAR_WIDTH = 140
local MOBILE_TABBAR_HEIGHT = 36
local TITLEBAR_HEIGHT = 40
local SCREEN_MARGIN = 12

function Window.new(props: WindowProps?): any
    local self = BaseComponent.new() :: any
    setmetatable(self, Window)

    local theme = props and props.Theme and Theme:Merge(props.Theme) or Theme.Current
    local title = (props and props.Title) or "Elysian"
    local desiredSize = (props and props.Size) or Vector2.new(560, 380)
    local minSize = (props and props.MinSize) or Vector2.new(320, 240)

    -- Determine layout mode
    local layoutMode
    if props and props.MobileLayout == "mobile" then
        layoutMode = "mobile"
    elseif props and props.MobileLayout == "desktop" then
        layoutMode = "desktop"
    else
        layoutMode = Viewport:LayoutMode()
    end
    self._layoutMode = layoutMode

    -- Clamp size to viewport
    local vp = Viewport:GetSize()
    local size = Viewport:ClampSize(desiredSize, SCREEN_MARGIN)
    -- On mobile, fill most of the screen
    if layoutMode == "mobile" then
        size = Vector2.new(vp.X - SCREEN_MARGIN * 2, vp.Y - SCREEN_MARGIN * 2)
    end
    -- Respect min size
    size = Vector2.new(math.max(size.X, math.min(minSize.X, vp.X)), math.max(size.Y, math.min(minSize.Y, vp.Y)))

    Logger:Debug(string.format("[Window] creating '%s' %dx%d (layout: %s, viewport: %dx%d)",
        title, size.X, size.Y, layoutMode, vp.X, vp.Y))

    local coreGui = requireRemote("src/Services/CoreGui.luau").new()
    local container = coreGui:GetContainer("ElysianRoot")

    local initialPos
    if props and props.Position then
        initialPos = UDim2.fromOffset(props.Position.X, props.Position.Y)
    else
        local center = Viewport:CenterPosition(size)
        initialPos = UDim2.fromOffset(center.X, center.Y)
    end

    local root = Drawing.frame({
        Name = "ElysianWindow",
        Size = UDim2.fromOffset(size.X, size.Y),
        Position = initialPos,
        BackgroundColor3 = theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = false,  -- dropdowns need to overflow
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
    self._desiredSize = desiredSize

    -- Title bar
    local titleBar = Drawing.frame({
        Name = "TitleBar",
        Size = UDim2.new(1, 0, 0, TITLEBAR_HEIGHT),
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

    -- Close / minimise buttons
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

    -- Body container
    local body = Drawing.frame({
        Name = "Body",
        Size = UDim2.new(1, 0, 1, -TITLEBAR_HEIGHT),
        Position = UDim2.fromOffset(0, TITLEBAR_HEIGHT),
        BackgroundTransparency = 1,
        Parent = root,
    })
    self.Body = body

    -- Layout: desktop = left sidebar, mobile = top bar
    local tabBar, contentArea
    if layoutMode == "mobile" then
        -- Mobile: horizontal tab bar at top, content below
        tabBar = Drawing.frame({
            Name = "TabBar",
            Size = UDim2.new(1, 0, 0, MOBILE_TABBAR_HEIGHT),
            BackgroundColor3 = theme.BackgroundAlt,
            BorderSizePixel = 0,
            Parent = body,
        })
        Drawing.padding(tabBar, 4)
        local _tll = Drawing.list(tabBar, Enum.FillDirection.Horizontal, 4,
            Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
        contentArea = Drawing.frame({
            Name = "ContentArea",
            Size = UDim2.new(1, 0, 1, -MOBILE_TABBAR_HEIGHT),
            Position = UDim2.fromOffset(0, MOBILE_TABBAR_HEIGHT),
            BackgroundColor3 = theme.Surface,
            BorderSizePixel = 0,
            Parent = body,
        })
        Drawing.rounded(contentArea, theme.CornerRadius)
        Drawing.padding(contentArea, 6)
    else
        -- Desktop: left sidebar, content on right
        tabBar = Drawing.frame({
            Name = "TabBar",
            Size = UDim2.fromOffset(DESKTOP_TABBAR_WIDTH, 1),
            BackgroundColor3 = theme.BackgroundAlt,
            BorderSizePixel = 0,
            Parent = body,
        })
        Drawing.padding(tabBar, 6)
        Drawing.list(tabBar, Enum.FillDirection.Vertical, 4,
            Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)
        contentArea = Drawing.frame({
            Name = "ContentArea",
            Size = UDim2.new(1, -DESKTOP_TABBAR_WIDTH, 1, 0),
            Position = UDim2.fromOffset(DESKTOP_TABBAR_WIDTH, 0),
            BackgroundColor3 = theme.Surface,
            BorderSizePixel = 0,
            Parent = body,
        })
        Drawing.rounded(contentArea, theme.CornerRadius)
        Drawing.padding(contentArea, 8)
    end
    self.TabBar = tabBar
    self.ContentArea = contentArea

    -- Dragging logic (mouse + touch). On mobile, allow dragging but keep
    -- the window within viewport bounds.
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
                local newPosX = startPos.X.Offset + delta.X
                local newPosY = startPos.Y.Offset + delta.Y
                -- Clamp to viewport so the window can't be dragged off-screen
                local vpNow = Viewport:GetSize()
                newPosX = math.max(-size.X + 80, math.min(newPosX, vpNow.X - 80))
                newPosY = math.max(0, math.min(newPosY, vpNow.Y - 40))
                root.Position = UDim2.fromOffset(newPosX, newPosY)
            end
        end)
    end

    -- Open button
    if props == nil or props.OpenButton ~= false then
        local obProps = props and props.OpenButtonProps or {}
        local mergedProps = {
            Text = obProps.Text or string.sub(title or "E", 1, 1),
            Theme = obProps.Theme or theme,
            Hotkey = obProps.Hotkey or (props and props.OpenHotkey),
            Size = obProps.Size,
            Position = obProps.Position,
            Color = obProps.Color,
            TextColor = obProps.TextColor,
            Shape = obProps.Shape,
            CornerRadius = obProps.CornerRadius,
            StrokeColor = obProps.StrokeColor,
            StrokeThickness = obProps.StrokeThickness,
            StrokeTransparency = obProps.StrokeTransparency,
            Image = obProps.Image,
            ImageColor = obProps.ImageColor,
            Side = obProps.Side,
            Font = obProps.Font,
            Draggable = obProps.Draggable,
        }
        self.OpenButton = OpenButton.new(mergedProps)
        self.OpenButton:OnPressed(function()
            self:Toggle()
        end)
    end

    -- Responsive: re-layout on viewport resize
    if props == nil or props.Resizable ~= false then
        self._resizeConn = Viewport:OnResize(function(newVp, isMobile)
            self:HandleResize(newVp, isMobile)
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

-- Handle viewport resize: re-clamp window size and position.
function Window:HandleResize(newVp: Vector2, isMobile: boolean)
    if not self.Instance then return end
    -- Re-clamp size
    local newSize = Viewport:ClampSize(self._desiredSize, SCREEN_MARGIN)
    if isMobile then
        newSize = Vector2.new(newVp.X - SCREEN_MARGIN * 2, newVp.Y - SCREEN_MARGIN * 2)
    end
    self._size = newSize
    Tween.quick(self.Instance, 0.2, {
        Size = UDim2.fromOffset(newSize.X, newSize.Y),
    }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    -- Re-clamp position
    local pos = self.Instance.Position
    local newX = math.max(0, math.min(pos.X.Offset, newVp.X - newSize.X))
    local newY = math.max(0, math.min(pos.Y.Offset, newVp.Y - newSize.Y))
    self.Instance.Position = UDim2.fromOffset(newX, newY)
    Logger:Debug(string.format("[Window] resized to %dx%d", newSize.X, newSize.Y))
end

-- Create a tab in this window. Returns the Tab component.
function Window:CreateTab(name: string, icon: string?): any
    Logger:Debug("[Window] CreateTab: " .. name)
    local tab = Tab.new(self, name, self.Theme, icon, self._layoutMode)
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

-- Smoothly hide the window.
function Window:Hide()
    if not self._isOpen then return end
    self._isOpen = false
    Logger:Debug("[Window] Hide")
    self.Instance.BackgroundTransparency = 0
    Tween.quick(self.Instance, 0.18, {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(self._size.X * 0.92, self._size.Y * 0.92),
    }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    task.delay(0.2, function()
        if self.Instance and not self._isOpen then
            self.Instance.Visible = false
            self.Instance.BackgroundTransparency = 0
        end
    end)
end

-- Smoothly show the window.
function Window:Show()
    if self._isOpen then return end
    self._isOpen = true
    Logger:Debug("[Window] Show")
    self.Instance.Visible = true
    self.Instance.BackgroundTransparency = 1
    self.Instance.Size = UDim2.fromOffset(self._size.X * 0.92, self._size.Y * 0.92)
    Tween.quick(self.Instance, 0.22, {
        BackgroundTransparency = 0,
        Size = UDim2.fromOffset(self._size.X, self._size.Y),
    }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    self:RefreshTheme()
end

function Window:Toggle()
    if self._isOpen then self:Hide() else self:Show() end
end

-- Hard close: animate out and destroy.
function Window:Close()
    Logger:Debug("[Window] Close (destroy)")
    if self._resizeConn then
        self._resizeConn:Disconnect()
        self._resizeConn = nil
    end
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
            Position = UDim2.fromOffset(0, TITLEBAR_HEIGHT),
        }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        task.delay(0.2, function()
            if self._minimised then self.Body.Visible = false end
        end)
    else
        self.Body.Visible = true
        Tween.quick(self.Body, 0.22, {
            Size = self._prevBodySize or UDim2.new(1, 0, 1, -TITLEBAR_HEIGHT),
            Position = UDim2.fromOffset(0, TITLEBAR_HEIGHT),
        }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    end
end

-- Re-apply the current Theme.Current to this window and all its tabs.
function Window:RefreshTheme()
    local theme = Theme.Current
    self.Theme = theme
    self.Instance.BackgroundColor3 = theme.Background
    self.TitleBar.BackgroundColor3 = theme.BackgroundAlt
    self.TitleText.TextColor3 = theme.Text
    self.TitleText.Font = theme.FontBold
    self.TitleText.TextSize = theme.FontSize + 2
    self.TabBar.BackgroundColor3 = theme.BackgroundAlt
    self.ContentArea.BackgroundColor3 = theme.Surface
    local closeBtn = self.TitleBar:FindFirstChild("Close")
    if closeBtn then closeBtn.BackgroundColor3 = theme.Danger end
    local minBtn = self.TitleBar:FindFirstChild("Minimise")
    if minBtn then minBtn.BackgroundColor3 = theme.SurfaceAlt end
    if self.OpenButton and self.OpenButton.Instance then
        self.OpenButton:RefreshTheme(theme)
    end
    for _, tab in ipairs(self.Tabs) do
        tab:RefreshTheme(theme)
    end
    Logger:Debug("[Window] RefreshTheme applied")
end

return Window
