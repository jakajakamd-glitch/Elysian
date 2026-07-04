--!nonstrict
--[[
    Drawing - factory helpers for building common GUI instances (Frame,
    TextLabel, ImageLabel, etc.) with a fluent-builder API.
]]

local Drawing = {}

-- Returns a Frame instance configured with the provided properties.
-- Defaults to a VISIBLE background (BackgroundTransparency = 0). Callers
-- that want a transparent layout-only container should pass
-- `BackgroundTransparency = 1` explicitly.
function Drawing.frame(props: { [string]: any }): Frame
    local f = Instance.new("Frame")
    f.BackgroundTransparency = 0
    f.BorderSizePixel = 0
    for k, v in pairs(props or {}) do
        f[k] = v
    end
    return f
end

function Drawing.textLabel(props: { [string]: any }): TextLabel
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.BorderSizePixel = 0
    l.Text = ""
    l.Font = Enum.Font.GothamMedium
    l.TextColor3 = Color3.fromRGB(255, 255, 255)
    l.TextSize = 14
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextYAlignment = Enum.TextYAlignment.Center
    l.RichText = false
    for k, v in pairs(props or {}) do
        l[k] = v
    end
    return l
end

function Drawing.textButton(props: { [string]: any }): TextButton
    local b = Instance.new("TextButton")
    b.BackgroundTransparency = 0
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Text = ""
    b.Font = Enum.Font.GothamMedium
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.TextSize = 14
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.TextYAlignment = Enum.TextYAlignment.Center
    for k, v in pairs(props or {}) do
        b[k] = v
    end
    return b
end

function Drawing.textBox(props: { [string]: any }): TextBox
    local t = Instance.new("TextBox")
    t.BackgroundTransparency = 1
    t.BorderSizePixel = 0
    t.Text = ""
    t.Font = Enum.Font.GothamMedium
    t.TextColor3 = Color3.fromRGB(255, 255, 255)
    t.TextSize = 14
    t.ClearTextOnFocus = false
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.TextYAlignment = Enum.TextYAlignment.Center
    for k, v in pairs(props or {}) do
        t[k] = v
    end
    return t
end

function Drawing.image(props: { [string]: any }): ImageLabel
    local i = Instance.new("ImageLabel")
    i.BackgroundTransparency = 1
    i.BorderSizePixel = 0
    for k, v in pairs(props or {}) do
        i[k] = v
    end
    return i
end

function Drawing.scrollFrame(props: { [string]: any }): ScrollingFrame
    local s = Instance.new("ScrollingFrame")
    s.BackgroundTransparency = 1
    s.BorderSizePixel = 0
    s.ScrollBarThickness = 4
    s.ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255)
    s.ScrollBarImageTransparency = 0.6
    s.CanvasSize = UDim2.new()
    s.AutomaticCanvasSize = Enum.AutomaticSize.Y
    s.ScrollingDirection = Enum.ScrollingDirection.Y
    s.ElasticBehavior = Enum.ElasticBehavior.Never
    s.VerticalScrollBarInset = Enum.ScrollBarInset.None
    for k, v in pairs(props or {}) do
        s[k] = v
    end
    return s
end

-- Apply a rounded-corner look using a UICorner child (if radius > 0).
function Drawing.rounded(parent: Instance, radius: number?): UICorner
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 6)
    c.Parent = parent
    return c
end

-- Apply a stroke to `parent` with optional color, thickness, transparency.
function Drawing.stroke(parent: Instance, color: Color3, thickness: number?, transparency: number?): UIStroke
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

-- Apply a UIListLayout to `parent`.
function Drawing.list(parent: Instance, direction: EnumItem?, padding: number?,
        horizontal: EnumItem?, vertical: EnumItem?): UIListLayout
    local l = Instance.new("UIListLayout")
    l.FillDirection = direction or Enum.FillDirection.Vertical
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Padding = UDim.new(0, padding or 4)
    l.HorizontalAlignment = horizontal or Enum.HorizontalAlignment.Center
    l.VerticalAlignment = vertical or Enum.VerticalAlignment.Top
    l.Parent = parent
    return l
end

-- Apply a UIPadding to `parent`.
function Drawing.padding(parent: Instance, padding: number?): UIPadding
    local p = Instance.new("UIPadding")
    p.PaddingTop = UDim.new(0, padding or 8)
    p.PaddingBottom = UDim.new(0, padding or 8)
    p.PaddingLeft = UDim.new(0, padding or 8)
    p.PaddingRight = UDim.new(0, padding or 8)
    p.Parent = parent
    return p
end

return Drawing
