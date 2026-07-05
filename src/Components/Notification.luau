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

    You can also create your own stack instance if you want a separate
    notification container:

        local stack = Elysian.Notification.new()
        stack:Notify({ Title = "Hi" })
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
local Logger   = requireRemote("src/Utilities/Logger.luau")

local Notification = {}
Notification.__index = Notification

function Notification.new()
    return setmetatable({
        -- Marker so the module-level Notify wrapper can tell whether it
        -- was called on a real instance or on the Notification class itself.
        _isInstance = true,
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

-- The actual notification implementation. `self` must be a real instance
-- (created by Notification.new()). Kept as a local so the module-level
-- Notify wrapper can call it without going back through __index (which
-- would cause infinite recursion).
local function notifyImpl(self: any, props: { [string]: any })
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
        BackgroundTransparency = 1, -- start fully transparent, animate in
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
        BackgroundTransparency = 0,
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

    -- Track active toasts so we can cap the stack and avoid runaway growth.
    table.insert(self._active, toast)
    -- Cap at 6 simultaneous toasts; oldest gets torn down.
    while #self._active > 6 do
        local oldest = table.remove(self._active, 1)
        if oldest and oldest.Parent then
            oldest:Destroy()
        end
    end

    -- Reveal animation
    Tween.quick(toast, 0.2, { BackgroundTransparency = 0.05 })

    -- Auto-dismiss
    task.delay(duration, function()
        if not toast.Parent then return end
        local tw = Tween.quick(toast, 0.25, { BackgroundTransparency = 1 })
        Tween.quick(titleLabel, 0.25, { TextTransparency = 1 })
        Tween.quick(bodyLabel, 0.25, { TextTransparency = 1 })
        Tween.quick(accent, 0.25, { BackgroundTransparency = 1 })
        tw.Completed:Once(function()
            -- Remove from active list and destroy.
            for i, t in ipairs(self._active) do
                if t == toast then
                    table.remove(self._active, i)
                    break
                end
            end
            toast:Destroy()
        end)
    end)

    Logger:Debug(("[Notification] %s: %s"):format(title, body))
end

-- Public Notify method. Handles both call styles:
--   Elysian.Notification:Notify({...})   -> self is the Notification class
--   myInstance:Notify({...})             -> self is a real instance
-- Dispatches to notifyImpl with the appropriate target. This indirection
-- is what prevents the infinite recursion that happened when the wrapper
-- called defaultInstance:Notify(props) (which re-dispatched through
-- __index back to this same wrapper).
function Notification.Notify(self: any, props: { [string]: any })
    local target = (self and self._isInstance) and self or Notification._default
    notifyImpl(target, props)
end

-- Also expose the impl as an instance method for callers who already hold
-- a real instance and want to bypass the dispatcher (negligible overhead,
-- but useful for subclassing).
Notification._notifyImpl = notifyImpl

-- Singleton instance used by module-level :Notify calls.
Notification._default = Notification.new()

return Notification
