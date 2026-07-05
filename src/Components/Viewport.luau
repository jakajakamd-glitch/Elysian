--!nonstrict
--[[
    Viewport - a ViewportFrame wrapper that can display any 3D model
    (characters, parts, accessories, etc.) inside an Elysian window.

    Viewport.new({
        Size      = Vector2.new(200, 200),  -- pixel size
        Position  = UDim2.new(...),          -- optional explicit position
        Theme     = <optional>,
        Parent    = <Instance>,
        AutoRotate = true,                   -- slowly spin the model
        CameraDistance = 4,                  -- how far the camera sits
        CameraHeight = 1.5,                  -- vertical offset
    })

    Convenience: Tab:CreateViewport({ Size = Vector2.new(1, 200) })

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
    self._cameraDistance = (props and props.CameraDistance) or 4
    self._cameraHeight = (props and props.CameraHeight) or 1.5
    self._rotation = 0
    self._model = nil
    self._charConn = nil  -- RBXScriptConnection for CharacterAdded

    -- Root container (a Frame so it fits the Elysian layout system)
    local rootSize
    if props and props.Size then
        rootSize = UDim2.fromOffset(props.Size.X, props.Size.Y)
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

    -- Optional title label
    local titleLabel
    if props and props.Title then
        titleLabel = Drawing.textLabel({
            Name = "Title",
            Size = UDim2.new(1, -12, 0, 18),
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

    -- The actual ViewportFrame
    local vpFrame = Instance.new("ViewportFrame")
    vpFrame.Name = "ViewportFrame"
    vpFrame.Size = titleLabel and UDim2.new(1, -8, 1, -26) or UDim2.new(1, -8, 1, -8)
    vpFrame.Position = titleLabel and UDim2.fromOffset(4, 22) or UDim2.fromOffset(4, 4)
    vpFrame.BackgroundColor3 = (props and props.BackgroundColor) or theme.Background
    vpFrame.BackgroundTransparency = 0
    vpFrame.BorderSizePixel = 0
    vpFrame.Parent = root
    Drawing.rounded(vpFrame, theme.CornerRadius - 4)

    -- Camera for the viewport
    local camera = Instance.new("Camera")
    camera.CFrame = CFrame.new(Vector3.new(0, self._cameraHeight, self._cameraDistance))
    vpFrame.CurrentCamera = camera
    camera.Parent = vpFrame

    self.Instance = root
    self.ViewportFrame = vpFrame
    self.Camera = camera
    self.TitleLabel = titleLabel

    -- Auto-rotate loop
    self._rotateConn = nil
    if self._autoRotate then
        self:_startAutoRotate()
    end

    return self
end

-- ===========================================================================
-- Model management
-- ===========================================================================

-- Display a Model instance. The model is CLONED so the original is untouched.
-- Any existing model is removed first.
function Viewport:SetModel(model: Model?)
    self:Clear()
    if not model then return end
    local clone = model:Clone()
    -- Move the model to origin so the camera can see it
    pcall(function()
        if clone:IsA("Model") then
            clone:PivotTo(CFrame.new(0, 0, 0))
        end
    end)
    clone.Parent = self.ViewportFrame
    self._model = clone
    self:_frameModel()
end

-- Clone a player's character into the viewport.
function Viewport:SetCharacter(player: Player?)
    if not player then
        -- default to LocalPlayer
        player = Players.LocalPlayer
    end
    if not player then return end
    self:Clear()
    if not player.Character then
        -- Wait for character to spawn, then display it
        if self._charConn then self._charConn:Disconnect() end
        self._charConn = player.CharacterAdded:Connect(function(char)
            task.wait(0.3) -- let the character finish building
            self:SetModel(char)
        end)
        return
    end
    self:SetModel(player.Character)
    -- Also refresh when the character respawns
    if self._charConn then self._charConn:Disconnect() end
    self._charConn = player.CharacterAdded:Connect(function(char)
        task.wait(0.3)
        self:SetModel(char)
    end)
end

-- Convenience: show the LocalPlayer's character.
function Viewport:SetLocalCharacter()
    self:SetCharacter(Players.LocalPlayer)
end

-- Remove the current model.
function Viewport:Clear()
    if self._model then
        pcall(function() self._model:Destroy() end)
        self._model = nil
    end
end

-- ===========================================================================
-- Camera / rotation
-- ===========================================================================

-- Frame the current model: position the camera to look at the model's center.
function Viewport:_frameModel()
    if not self._model then return end
    local ok, cf, size = pcall(function()
        return self._model:GetBoundingBox()
    end)
    if not ok or not cf then return end
    local center = cf.Position
    local dist = self._cameraDistance
    if size then
        -- Scale distance by model size so it always fits
        local maxDim = math.max(size.X, size.Y, size.Z)
        dist = math.max(self._cameraDistance, maxDim * 1.8)
    end
    local angle = math.rad(self._rotation)
    local camPos = center + Vector3.new(
        math.sin(angle) * dist,
        self._cameraHeight + size.Y * 0.3,
        math.cos(angle) * dist
    )
    self.Camera.CFrame = CFrame.new(camPos, center)
end

-- Set explicit rotation (degrees) and re-frame.
function Viewport:RotateTo(degrees: number)
    self._rotation = degrees
    self:_frameModel()
end

-- Toggle auto-rotation.
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
    self._rotateConn = RunService.Heartbeat:Connect(function(dt)
        self._rotation = (self._rotation + dt * 30) % 360  -- 30 deg/sec
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
    if self.Instance then
        self.Instance.Size = UDim2.fromOffset(size.X, size.Y)
    end
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
        self.Camera:Destroy()
        self.Camera = nil
    end
    if self.ViewportFrame then
        self.ViewportFrame:Destroy()
        self.ViewportFrame = nil
    end
    -- BaseComponent:Destroy handles the root instance
    getmetatable(self).__index.Destroy(self)
end

return Viewport
