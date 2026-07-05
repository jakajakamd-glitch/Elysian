--!nonstrict
--[[
    Viewport - helpers for responsive layout. Detects screen size, mobile
    vs desktop, and provides clamping helpers for window sizing.
]]

local Viewport = {}

local function getCamera(): Camera?
    local ok, workspace = pcall(function() return game:GetService("Workspace") end)
    if ok and workspace then
        return workspace.CurrentCamera
    end
    return nil
end

-- Returns the current viewport size as a Vector2.
function Viewport:GetSize(): Vector2
    local cam = getCamera()
    if cam and cam.ViewportSize then
        return cam.ViewportSize
    end
    -- Fallback guess
    return Vector2.new(1024, 768)
end

-- Returns true if the current device is likely a mobile/touch device.
-- Heuristics: small viewport OR touch input is primary.
function Viewport:IsMobile(): boolean
    local size = self:GetSize()
    if size.X < 700 or size.Y < 500 then
        return true
    end
    local ok,UIS = pcall(function() return game:GetService("UserInputService") end)
    if ok and UIS then
        return UIS.TouchEnabled and not UIS.MouseEnabled
    end
    return false
end

function Viewport:IsTouch(): boolean
    local ok,UIS = pcall(function() return game:GetService("UserInputService") end)
    if ok and UIS then
        return UIS.TouchEnabled
    end
    return false
end

-- Clamp a desired window size so it fits within the viewport with margins.
-- `margin` is the minimum gap from the screen edge (default 16px).
function Viewport:ClampSize(desired: Vector2, margin: number?): Vector2
    local m = margin or 16
    local vp = self:GetSize()
    local maxW = vp.X - m * 2
    local maxH = vp.Y - m * 2
    local w = math.min(desired.X, maxW)
    local h = math.min(desired.Y, maxH)
    -- On mobile, fill most of the screen.
    if self:IsMobile() then
        w = math.min(w, vp.X - m * 2)
        h = math.min(h, vp.Y - m * 2)
    end
    return Vector2.new(w, h)
end

-- Center a window of `size` within the viewport.
function Viewport:CenterPosition(size: Vector2): Vector2
    local vp = self:GetSize()
    return Vector2.new(
        math.max(8, (vp.X - size.X) / 2),
        math.max(8, (vp.Y - size.Y) / 2)
    )
end

-- Recommend a layout based on viewport: "desktop" (sidebar tabs) or
-- "mobile" (top bar tabs).
function Viewport:LayoutMode(): string
    if self:IsMobile() then return "mobile" end
    return "desktop"
end

-- Re-compute and notify on viewport changes. Returns a connection to
-- disconnect. `callback(newSize, isMobile)` is called on viewport resize.
function Viewport:OnResize(callback: (Vector2, boolean) -> ()): RBXScriptConnection?
    local cam = getCamera()
    if not cam then return nil end
    return cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        callback(self:GetSize(), self:IsMobile())
    end)
end

return Viewport
