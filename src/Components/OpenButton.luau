--!nonstrict
--[[
    OpenButton - a small floating button that toggles the visibility of
    a Window. Solves the "button to open it is invisible" complaint by
    being a self-contained, always-visible, draggable FAB.

    Created automatically by Window.new unless `props.OpenButton = false`.
    You usually don't construct this directly.
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
}

function OpenButton.new(props: OpenButtonProps?): any
    local self = setmetatable({
        Theme = (props and props.Theme) or Theme.Current,
        Visible = true,
        Destroyed = false,
    }, OpenButton)

    local theme = self.Theme
    local size = (props and props.Size) or 48
    local text = (props and props.Text) or "E"

    local coreGui = CoreGui.new()
    local gui = coreGui:GetContainer("ElysianOpenButton")

    local button = Drawing.textButton({
        Name = "ElysianOpenButton",
        Size = UDim2.fromOffset(size, size),
        Position = props and props.Position
            and UDim2.fromOffset(props.Position.X, props.Position.Y)
            or UDim2.new(0, 20, 0.5, -size / 2),
        BackgroundColor3 = theme.Accent,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Text = text,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = theme.FontBold,
        TextSize = math.floor(size * 0.45),
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        AutoButtonColor = false,
        Active = true,
        Draggable = false,
        Parent = gui,
    })
    Drawing.rounded(button, size / 2)
    Drawing.stroke(button, Color3.fromRGB(255, 255, 255), 1, 0.4)

    self.Instance = button
    self.Gui = gui
    self.Pressed = Signal.new()

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

    -- Drag support (mouse + touch)
    local dragging = false
    local dragStart: Vector2?
    local startPos: UDim2?

    local function beginDrag(input: InputObject)
        dragging = true
        dragStart = input.Position
        startPos = button.Position
    end
    local function updateDrag(input: InputObject)
        if not dragging or not dragStart or not startPos then return end
        local delta = input.Position - dragStart
        button.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
    local function endDrag()
        dragging = false
        dragStart = nil
        startPos = nil
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

    -- Optional hotkey (keyboard) to toggle
    if props and props.Hotkey then
        local hotkey = props.Hotkey
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

function OpenButton:SetText(text: string)
    self.Instance.Text = text
end

function OpenButton:SetVisible(visible: boolean)
    self.Visible = visible
    self.Instance.Visible = visible
end

function OpenButton:OnPressed(callback: (() -> ()))
    return self.Pressed:Connect(callback)
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
