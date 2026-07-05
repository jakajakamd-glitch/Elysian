--!nonstrict
--[[
    Viewport - a ViewportFrame wrapper that can display any 3D model
    (characters, parts, accessories, etc.) inside an Elysian window.

    Viewport.new({
        Size      = Vector2.new(200, 200),  -- pixel size (values <=1 = scale)
        Position  = UDim2.new(...),
        Theme     = <optional>,
        Parent    = <Instance>,
        AutoRotate = true,                   -- slowly spin the model
        CameraDistance = 4,
        CameraHeight = 1.5,
        Title = "Preview",                   -- optional header
    })

    Methods:
        :SetModel(model)         - display a Model instance (clones it)
        :SetCharacter(player)    - clone a player's character into the viewport
        :SetLocalCharacter()     - clone the LocalPlayer's character
        :Clear()                 - remove the current model
        :SetAutoRotate(bool)     - toggle slow rotation
        :RotateTo(degrees)       - set explicit rotation
        :RefreshTheme(theme)     - re-apply theme colors
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
local Theme         = requireRemote("src/Theme.luau")
local Logger        = requireRemote("src/Utilities/Logger.luau")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Viewport = setmetatable({}, BaseComponent)
Viewport.__index = Viewport

export type ViewportProps = {
    Size: Vector2?,
    Position: UDim2?,
    Theme: { [string]: any }?,
    Parent: Instance?,
    AutoRotate: boolean?,
    CameraDistance: number?,
    CameraHeight: number?,
    BackgroundColor: Color3?,
    Title: string?,
}

function Viewport.new(props: ViewportProps?): any
    local self = BaseComponent.new() :: any
    setmetatable(self, Viewport)

    local theme = (props and props.Theme) or Theme.Current
    self.Theme = theme
    self._autoRotate = not (props and props.AutoRotate == false)
    self._cameraDistance = (props and props.CameraDistance) or 5
    self._cameraHeight = (props and props.CameraHeight) or 2
    self._rotation = 0
    self._model = nil
    self._charConn = nil
    self._rotateConn = nil

    -- Size: values <= 1 = scale, > 1 = offset (pixels)
    local rootSize
    if props and props.Size then
        local s = props.Size
        local xs = (s.X <= 1) and s.X or 0
        local xo = (s.X <= 1) and 0 or s.X
        local ys = (s.Y <= 1) and s.Y or 0
        local yo = (s.Y <= 1) and 0 or s.Y
        rootSize = UDim2.new(xs, xo, ys, yo)
    else
        rootSize = UDim2.new(1, 0, 0, 200)
    end

    local root = Drawing.frame({
        Name = "ElysianViewport",
        Size = rootSize,
        Position = props and props.Position or UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = theme.BackgroundAlt,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Parent = props and props.Parent,
    })
    Drawing.rounded(root, theme.CornerRadius - 2)
    Drawing.stroke(root, theme.Border, 1, 0.5)

    -- Optional title
    local titleLabel
    if props and props.Title then
        titleLabel = Drawing.textLabel({
            Name = "Title",
            Size = UDim2.new(1, -12, 0, 20),
            Position = UDim2.fromOffset(8, 4),
            BackgroundTransparency = 1,
            Text = props.Title,
            TextColor3 = theme.TextMuted,
            Font = theme.Font,
            TextSize = theme.FontSize - 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = root,
        })
    end

    -- The ViewportFrame. We create it with Instance.new and configure it
    -- thoroughly so models actually render.
    local vpFrame = Instance.new("ViewportFrame")
    vpFrame.Name = "ViewportFrame"
    vpFrame.Size = titleLabel and UDim2.new(1, -8, 1, -28) or UDim2.new(1, -8, 1, -8)
    vpFrame.Position = titleLabel and UDim2.fromOffset(4, 24) or UDim2.fromOffset(4, 4)
    vpFrame.BackgroundColor3 = (props and props.BackgroundColor) or theme.Background
    vpFrame.BackgroundTransparency = 0
    vpFrame.BorderSizePixel = 0
    -- Important: these lighting-related props affect whether models are visible
    vpFrame.LightDirection = Vector3.new(-1, -1, -1)
    vpFrame.Ambient = Color3.fromRGB(80, 80, 80)
    vpFrame.OutOfRangeMs = 1000
    vpFrame.Parent = root
    Drawing.rounded(vpFrame, theme.CornerRadius - 4)

    -- Camera
    local camera = Instance.new("Camera")
    camera.FieldOfView = 50
    camera.CFrame = CFrame.new(Vector3.new(0, self._cameraHeight, self._cameraDistance))
    vpFrame.CurrentCamera = camera
    camera.Parent = vpFrame

    self.Instance = root
    self.ViewportFrame = vpFrame
    self.Camera = camera
    self.TitleLabel = titleLabel

    if self._autoRotate then
        self:_startAutoRotate()
    end

    Logger:Debug("[Viewport] created")
    return self
end

-- ===========================================================================
-- Model management
-- ===========================================================================

function Viewport:SetModel(model: Model?)
    self:Clear()
    if not model then return end
    Logger:Debug("[Viewport] SetModel: " .. tostring(model:GetDebugName()))
    local clone
    local ok, err = pcall(function()
        clone = model:Clone()
    end)
    if not ok or not clone then
        Logger:Warn("[Viewport] Clone failed: " .. tostring(err))
        return
    end
    -- Move to origin
    pcall(function()
        if clone:IsA("Model") then
            clone:PivotTo(CFrame.new(0, 0, 0))
        elseif clone:IsA("BasePart") then
            clone.CFrame = CFrame.new(0, 0, 0)
        end
    end)
    clone.Parent = self.ViewportFrame
    self._model = clone
    -- Wait a frame for the model to settle, then frame it
    task.defer(function()
        self:_frameModel()
    end)
end

function Viewport:SetCharacter(player: Player?)
    if not player then
        player = Players.LocalPlayer
    end
    if not player then return end
    self:Clear()
    if self._charConn then self._charConn:Disconnect() end

    if player.Character then
        self:SetModel(player.Character)
    else
        -- Wait for character to spawn
        self._charConn = player.CharacterAdded:Connect(function(char)
            task.wait(0.5)
            self:SetModel(char)
        end)
        return
    end
    -- Refresh on respawn
    self._charConn = player.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        self:SetModel(char)
    end)
end

function Viewport:SetLocalCharacter()
    self:SetCharacter(Players.LocalPlayer)
end

function Viewport:Clear()
    if self._model then
        pcall(function() self._model:Destroy() end)
        self._model = nil
    end
end

-- ===========================================================================
-- Camera / rotation
-- ===========================================================================

function Viewport:_frameModel()
    if not self._model or not self.Camera then return end
    local ok, cf, size = pcall(function()
        return self._model:GetBoundingBox()
    end)
    if not ok or not cf then return end
    if not size or size.Magnitude == 0 then
        size = Vector3.new(4, 5, 2)
    end
    local center = cf.Position
    local maxDim = math.max(size.X, size.Y, size.Z, 1)
    local dist = math.max(self._cameraDistance, maxDim * 2.5)
    local angle = math.rad(self._rotation)
    local camPos = center + Vector3.new(
        math.sin(angle) * dist,
        self._cameraHeight + size.Y * 0.5,
        math.cos(angle) * dist
    )
    self.Camera.CFrame = CFrame.new(camPos, center)
end

function Viewport:RotateTo(degrees: number)
    self._rotation = degrees
    self:_frameModel()
end

function Viewport:SetAutoRotate(enabled: boolean)
    self._autoRotate = enabled
    if enabled then
        self:_startAutoRotate()
    else
        self:_stopAutoRotate()
    end
end

function Viewport:_startAutoRotate()
    if self._rotateConn then return end
    self._rotateConn = RunService.RenderStepped:Connect(function(dt)
        self._rotation = (self._rotation + dt * 40) % 360
        self:_frameModel()
    end)
end

function Viewport:_stopAutoRotate()
    if self._rotateConn then
        self._rotateConn:Disconnect()
        self._rotateConn = nil
    end
end

-- ===========================================================================
-- Sizing / theme / lifecycle
-- ===========================================================================

function Viewport:SetSize(size: Vector2)
    if not self.Instance then return end
    local xs = (size.X <= 1) and size.X or 0
    local xo = (size.X <= 1) and 0 or size.X
    local ys = (size.Y <= 1) and size.Y or 0
    local yo = (size.Y <= 1) and 0 or size.Y
    self.Instance.Size = UDim2.new(xs, xo, ys, yo)
end

function Viewport:RefreshTheme(theme: { [string]: any })
    self.Theme = theme
    Tween.quick(self.Instance, 0.2, { BackgroundColor3 = theme.BackgroundAlt })
    Tween.quick(self.ViewportFrame, 0.2, { BackgroundColor3 = theme.Background })
    if self.TitleLabel then
        self.TitleLabel.Font = theme.Font
        self.TitleLabel.TextSize = theme.FontSize - 1
        Tween.quick(self.TitleLabel, 0.2, { TextColor3 = theme.TextMuted })
    end
end

function Viewport:Destroy()
    self:_stopAutoRotate()
    if self._charConn then
        self._charConn:Disconnect()
        self._charConn = nil
    end
    self:Clear()
    if self.Camera then
        pcall(function() self.Camera:Destroy() end)
        self.Camera = nil
    end
    if self.ViewportFrame then
        pcall(function() self.ViewportFrame:Destroy() end)
        self.ViewportFrame = nil
    end
    BaseComponent.Destroy(self)
end

return Viewport
