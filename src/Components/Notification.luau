--!nonstrict
--[[
    Notification - toast-style notification stack.

    Usage:
        Elysian.Notification:Notify({
            Title = "Hello",
            Body  = "World",
            Duration = 4,           -- seconds; default 4
            Type = "Info",          -- "Info" | "Success" | "Warning" | "Danger"
        })

    Elysian.Notification is itself a singleton instance - you call :Notify
    directly on it. If you need a separate stack, call Notification.new().
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

local Drawing  = requireRemote("src/Utilities/Drawing.luau")
local Tween    = requireRemote("src/Utilities/Tween.luau")
local Theme    = requireRemote("src/Theme.luau")
local CoreGui  = requireRemote("src/Services/CoreGui.luau")

-- The Notification "class" is just a plain table holding methods. We DON'T
-- use it as a metatable - each instance gets its own methods bound to its
-- own state via closures. This eliminates any __index recursion risk.
local Notification = {}

function Notification.new()
    local self = {
        _container = nil,
        _active = {},
    }

    function self:Notify(props: { [string]: any })
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

        -- Ensure container exists
        if not (self._container and self._container.Parent) then
            local coreGui = CoreGui.new()
            local gui = coreGui:GetContainer("ElysianNotifications")
            local container = Drawing.frame({
                Name = "NotificationStack",
                Size = UDim2.fromOffset(320, 1),
                Position = UDim2.new(1, -340, 0, 20),
                BackgroundTransparency = 1,
                Parent = gui,
            })
            Drawing.list(container, Enum.FillDirection.Vertical, 8,
                Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Top)
            self._container = container
        end
        local container = self._container

        local toast = Drawing.frame({
            Name = "Toast",
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = theme.BackgroundAlt,
            BackgroundTransparency = 1,
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
        bodyLabel.AutomaticSize = Enum.AutomaticSize.Y

        -- Track active toasts (cap at 6).
        table.insert(self._active, toast)
        while #self._active > 6 do
            local oldest = table.remove(self._active, 1)
            if oldest then
                pcall(function() oldest:Destroy() end)
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
                for i, t in ipairs(self._active) do
                    if t == toast then
                        table.remove(self._active, i)
                        break
                    end
                end
                pcall(function() toast:Destroy() end)
            end)
        end)
    end

    function self:Clear()
        for i = #self._active, 1, -1 do
            local t = self._active[i]
            pcall(function() t:Destroy() end)
        end
        self._active = {}
    end

    return self
end

-- The default singleton. Elysian.Notification IS this instance, so
-- `Elysian.Notification:Notify({...})` calls the bound :Notify method
-- directly - no dispatch, no __index lookup, no recursion possible.
local defaultInstance = Notification.new()
Notification.Notify  = function(_, props) defaultInstance:Notify(props) end
Notification.Clear   = function() defaultInstance:Clear() end
Notification.new     = Notification.new  -- keep constructor accessible

-- Make Notification behave like an instance for :Notify calls.
-- Since Notification.Notify is a direct field on the Notification table,
-- `Notification:Notify(props)` resolves to `Notification.Notify(Notification, props)`
-- which dispatches to defaultInstance:Notify(props). No __index involved.
return Notification
