--!nonstrict
--[[
    OpenButton - a customizable floating button that toggles the visibility
    of a Window. Self-contained, always-visible, draggable (mouse + touch),
    and supports an optional keyboard hotkey.

    Created automatically by Window.new unless `OpenButton = false` is
    passed. You can also pass an `OpenButtonProps` table via Window's
    `OpenButtonProps` field to customize it:

        local window = Elysian.Window.new({
            Title = "My UI",
            OpenButtonProps = {
                Text = "MENU",
                Size = 56,
                Color = Color3.fromRGB(255, 80, 120),   -- custom bg color
                TextColor = Color3.fromRGB(255, 255, 0),
                Position = Vector2.new(40, 200),
                Shape = "Circle",                       -- "Circle" | "Rounded" | "Square"
                StrokeColor = Color3.fromRGB(255, 255, 255),
                StrokeThickness = 2,
                Image = "rbxassetid://12345678",        -- optional image instead of text
                Hotkey = Enum.KeyCode.RightShift,
                Side = "Left",                          -- "Left" | "Right" | "Top" | "Bottom" (default pos)
            },
        })

    Or construct standalone:

        local btn = Elysian.OpenButton.new({ Text = "X", Size = 40 })
        btn:OnPressed(function() print("toggled") end)
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

local Drawing       = requireRemote("src/Utilities/Drawing.luau")
local Tween         = requireRemote("src/Utilities/Tween.luau")
local Theme         = requireRemote("src/Theme.luau")
local CoreGui       = requireRemote("src/Services/CoreGui.luau")
local Signal        = requireRemote("src/Utilities/Signal.luau")

local OpenButton = {}
OpenButton.__index = OpenButton

export type OpenButtonProps = {
    Text: string?,
    Size: number?,
    Position: Vector2?,
    Theme: { [string]: any }?,
    Hotkey: EnumItem?,
    Color: Color3?,             -- background color override
    TextColor: Color3?,         -- text color override
    Shape: string?,             -- "Circle" | "Rounded" | "Square"
    CornerRadius: number?,      -- override (used when Shape = "Rounded")
    StrokeColor: Color3?,
    StrokeThickness: number?,
    StrokeTransparency: number?,
    Image: string?,             -- asset id for image icon (overrides Text)
    ImageColor: Color3?,
    Side: string?,              -- "Left" | "Right" | "Top" | "Bottom" (default anchor)
    Font: EnumItem?,
    Draggable: boolean?,
}

local function defaultPosition(side: string, size: number): UDim2
    if side == "Right" then
        return UDim2.new(1, -size - 20, 0.5, -size / 2)
    elseif side == "Top" then
        return UDim2.new(0.5, -size / 2, 0, 20)
    elseif side == "Bottom" then
        return UDim2.new(0.5, -size / 2, 1, -size - 20)
    else -- "Left" (default)
        return UDim2.new(0, 20, 0.5, -size / 2)
    end
end

function OpenButton.new(props: OpenButtonProps?): any
    local self = setmetatable({
        Theme = (props and props.Theme) or Theme.Current,
        Visible = true,
        Destroyed = false,
        _props = props or {},
    }, OpenButton)

    local theme = self.Theme
    local size = (props and props.Size) or 48
    local shape = (props and props.Shape) or "Circle"
    local side = (props and props.Side) or "Left"

    local bgColor = (props and props.Color) or theme.Accent
    local textColor = (props and props.TextColor) or Color3.fromRGB(255, 255, 255)
    local strokeColor = (props and props.StrokeColor) or Color3.fromRGB(255, 255, 255)
    local strokeThickness = (props and props.StrokeThickness) or 1
    local strokeTransparency = (props and props.StrokeTransparency) or 0.4

    local coreGui = CoreGui.new()
    local gui = coreGui:GetContainer("ElysianOpenButton")

    -- If an image is provided, use an ImageLabel-based button; otherwise TextButton.
    local button
    local icon
    if props and props.Image then
        button = Drawing.textButton({
            Name = "ElysianOpenButton",
            Size = UDim2.fromOffset(size, size),
            Position = props and props.Position
                and UDim2.fromOffset(props.Position.X, props.Position.Y)
                or defaultPosition(side, size),
            BackgroundColor3 = bgColor,
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            Active = true,
            Parent = gui,
        })
        icon = Drawing.image({
            Name = "Icon",
            Size = UDim2.fromScale(0.6, 0.6),
            Position = UDim2.fromScale(0.2, 0.2),
            BackgroundTransparency = 1,
            Image = props.Image,
            ImageColor3 = (props and props.ImageColor) or Color3.fromRGB(255, 255, 255),
            Parent = button,
        })
    else
        local text = (props and props.Text) or "E"
        button = Drawing.textButton({
            Name = "ElysianOpenButton",
            Size = UDim2.fromOffset(size, size),
            Position = props and props.Position
                and UDim2.fromOffset(props.Position.X, props.Position.Y)
                or defaultPosition(side, size),
            BackgroundColor3 = bgColor,
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            Text = text,
            TextColor3 = textColor,
            Font = (props and props.Font) or theme.FontBold,
            TextSize = math.floor(size * 0.45),
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            AutoButtonColor = false,
            Active = true,
            Parent = gui,
        })
    end

    -- Shape: apply corner radius
    local cornerRadius
    if shape == "Circle" then
        cornerRadius = size / 2
    elseif shape == "Square" then
        cornerRadius = 0
    elseif shape == "Rounded" then
        cornerRadius = (props and props.CornerRadius) or math.floor(size * 0.25)
    else
        cornerRadius = size / 2
    end
    if cornerRadius > 0 then
        Drawing.rounded(button, cornerRadius)
    end
    -- Stroke
    if strokeThickness > 0 then
        Drawing.stroke(button, strokeColor, strokeThickness, strokeTransparency)
    end

    self.Instance = button
    self.Icon = icon
    self.Gui = gui
    self.Pressed = Signal.new()
    self._size = size

    -- Hover/tap feedback
    button.MouseEnter:Connect(function()
        Tween.quick(button, 0.15, {
            Size = UDim2.fromOffset(size + 6, size + 6),
            BackgroundTransparency = 0.05,
        })
    end)
    button.MouseLeave:Connect(function()
        Tween.quick(button, 0.15, {
            Size = UDim2.fromOffset(size, size),
            BackgroundTransparency = 0,
        })
    end)

    -- Click to toggle
    button.MouseButton1Click:Connect(function()
        self.Pressed:Fire()
        -- tiny press-bounce
        Tween.quick(button, 0.08, { Size = UDim2.fromOffset(size - 4, size - 4) })
        task.delay(0.08, function()
            Tween.quick(button, 0.15, { Size = UDim2.fromOffset(size, size) })
        end)
    end)

    -- Drag support (mouse + touch), enabled by default
    if props == nil or props.Draggable ~= false then
        local dragging = false
        local dragStart: Vector2?
        local startPos: UDim2?
        local dragMoved = false

        local function beginDrag(input: InputObject)
            dragging = true
            dragMoved = false
            dragStart = input.Position
            startPos = button.Position
        end
        local function updateDrag(input: InputObject)
            if not dragging or not dragStart or not startPos then return end
            local delta = input.Position - dragStart
            if delta.Magnitude > 4 then dragMoved = true end
            button.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
        local function endDrag()
            dragging = false
            dragStart = nil
            startPos = nil
            -- If the user dragged, suppress the click that follows.
            if dragMoved then
                task.wait(0.05)
                dragMoved = false
            end
        end

        button.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                beginDrag(input)
            end
        end)
        button.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                endDrag()
            end
        end)
        local UserInputService = game:GetService("UserInputService")
        UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch then
                updateDrag(input)
            end
        end)
    end

    -- Optional hotkey (keyboard) to toggle
    if props and props.Hotkey then
        local hotkey = props.Hotkey
        local UserInputService = game:GetService("UserInputService")
        UserInputService.InputBegan:Connect(function(input, processed)
            if processed then return end
            if input.UserInputType == Enum.UserInputType.Keyboard
                and input.KeyCode == hotkey then
                self.Pressed:Fire()
            end
        end)
    end

    return self
end

-- ===========================================================================
-- Customization setters (live-update the button)
-- ===========================================================================

function OpenButton:SetText(text: string)
    if self.Instance then
        self.Instance.Text = text
    end
end

function OpenButton:SetImage(imageId: string)
    if not self.Instance then return end
    if not self.Icon then
        -- Convert from text button to image button
        self.Instance.Text = ""
        self.Icon = Drawing.image({
            Name = "Icon",
            Size = UDim2.fromScale(0.6, 0.6),
            Position = UDim2.fromScale(0.2, 0.2),
            BackgroundTransparency = 1,
            Image = imageId,
            ImageColor3 = Color3.fromRGB(255, 255, 255),
            Parent = self.Instance,
        })
    else
        self.Icon.Image = imageId
    end
end

function OpenButton:SetColor(color: Color3)
    if self.Instance then
        self.Instance.BackgroundColor3 = color
    end
end

function OpenButton:SetTextColor(color: Color3)
    if self.Instance then
        self.Instance.TextColor3 = color
    end
    if self.Icon then
        self.Icon.ImageColor3 = color
    end
end

function OpenButton:SetSize(size: number)
    if not self.Instance then return end
    self._size = size
    self.Instance.Size = UDim2.fromOffset(size, size)
    if not self._props.Image then
        self.Instance.TextSize = math.floor(size * 0.45)
    end
    -- Re-apply corner radius for circle shape
    local existing = self.Instance:FindFirstChildOfClass("UICorner")
    if existing then
        existing.CornerRadius = UDim.new(0, size / 2)
    end
end

function OpenButton:SetPosition(position: Vector2)
    if self.Instance then
        self.Instance.Position = UDim2.fromOffset(position.X, position.Y)
    end
end

function OpenButton:SetVisible(visible: boolean)
    self.Visible = visible
    if self.Instance then
        self.Instance.Visible = visible
    end
end

function OpenButton:OnPressed(callback: (() -> ()))
    return self.Pressed:Connect(callback)
end

-- Re-apply theme colors. Called by Window:RefreshTheme().
function OpenButton:RefreshTheme(theme: { [string]: any })
    self.Theme = theme
    if not self.Instance then return end
    -- Only update color if the user hasn't overridden it
    if not (self._props and self._props.Color) then
        self.Instance.BackgroundColor3 = theme.Accent
    end
    if not (self._props and self._props.Font) and not self._props.Image then
        self.Instance.Font = theme.FontBold
    end
end

function OpenButton:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    if self.Instance then
        self.Instance:Destroy()
        self.Instance = nil
    end
end

return OpenButton
