--!nonstrict
--[[
    Notification - toast-style notification stack.

    Usage:
        local notif = Elysian.Notification
        notif:Notify({
            Title = "Hello",
            Body  = "World",
            Duration = 4,           -- seconds; default 4
            Type = "Info",          -- "Info" | "Success" | "Warning" | "Danger"
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

local Drawing  = requireRemote("src/Utilities/Drawing.luau")
local Tween    = requireRemote("src/Utilities/Tween.luau")
local Theme    = requireRemote("src/Theme.luau")
local CoreGui  = requireRemote("src/Services/CoreGui.luau")

local Notification = {}
Notification.__index = Notification

function Notification.new()
    return setmetatable({
        _container = nil,
        _active = {},
    }, Notification)
end

local function ensureContainer(self: any): Frame
    if self._container and self._container.Parent then
        return self._container
    end
    local coreGui = CoreGui.new()
    local gui = coreGui:GetContainer("ElysianNotifications")
    local container = Drawing.frame({
        Name = "NotificationStack",
        Size = UDim2.fromOffset(320, 1),
        Position = UDim2.new(1, -340, 0, 20),
        BackgroundTransparency = 1,
        Parent = gui,
    })
    Drawing.list(container, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Top)
    self._container = container
    return container
end

function Notification:Notify(props: { [string]: any })
    local theme = props.Theme or Theme.Current
    local title = props.Title or "Notification"
    local body  = props.Body or ""
    local duration = props.Duration or 4
    local kind = props.Type or "Info"

    local color
    if kind == "Success" then color = theme.Success
    elseif kind == "Warning" then color = theme.Warning
    elseif kind == "Danger" then color = theme.Danger
    else color = theme.Accent end

    local container = ensureContainer(self)

    local toast = Drawing.frame({
        Name = "Toast",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = theme.BackgroundAlt,
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        Parent = container,
    })
    Drawing.rounded(toast, theme.CornerRadius)
    Drawing.stroke(toast, theme.Border, 1, 0.5)

    local accent = Drawing.frame({
        Name = "AccentBar",
        Size = UDim2.fromOffset(3, 1),
        Position = UDim2.fromOffset(0, 0),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = toast,
    })
    Drawing.rounded(accent, 2)

    local _pad = Drawing.padding(toast, 12)

    local titleLabel = Drawing.textLabel({
        Size = UDim2.new(1, -12, 0, 18),
        Position = UDim2.fromOffset(12, 8),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = theme.Text,
        Font = theme.FontBold,
        TextSize = theme.FontSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = toast,
    })

    local bodyLabel = Drawing.textLabel({
        Size = UDim2.new(1, -12, 0, 14),
        Position = UDim2.fromOffset(12, 28),
        BackgroundTransparency = 1,
        Text = body,
        TextColor3 = theme.TextMuted,
        Font = theme.Font,
        TextSize = theme.FontSize - 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        Parent = toast,
    })
    -- Force the body label to autosize so multi-line text grows the toast.
    bodyLabel.AutomaticSize = Enum.AutomaticSize.Y

    -- Initial reveal: tiny then grow
    toast.Size = UDim2.new(1, 0, 0, 0)
    toast.BackgroundTransparency = 1
    Tween.quick(toast, 0.2, { BackgroundTransparency = 0.05 })

    task.delay(duration, function()
        if not toast.Parent then return end
        local tw = Tween.quick(toast, 0.25, { BackgroundTransparency = 1 })
        Tween.quick(titleLabel, 0.25, { TextTransparency = 1 })
        Tween.quick(bodyLabel, 0.25, { TextTransparency = 1 })
        Tween.quick(accent, 0.25, { BackgroundTransparency = 1 })
        tw.Completed:Once(function()
            toast:Destroy()
        end)
    end)
end

-- Singleton-style helpers so callers can use Elysian.Notification:Notify(...)
-- without instantiating their own.
local defaultInstance = Notification.new()
Notification.Notify = function(_, props) defaultInstance:Notify(props) end

return Notification
