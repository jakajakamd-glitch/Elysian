--!nonstrict
--[[
    Tween - a small wrapper around Roblox's TweenService that also
    exposes a fire-and-forget utility and a chained-tween builder.
]]

local TweenService = game:GetService("TweenService")
local Tween = {}

-- Create and play a tween on `instance`, with `properties` interpolated
-- over `duration` seconds using `easingStyle`/`easingDirection`. Returns
-- the Tween instance so callers can :Wait() or :Cancel() if needed.
function Tween.to(instance: Instance, duration: number, properties: { [string]: any },
        easingStyle: EnumItem,
        easingDirection: EnumItem,
        callback: (() -> ())?): Tween
    local info = TweenInfo.new(
        duration,
        easingStyle or Enum.EasingStyle.Quad,
        easingDirection or Enum.EasingDirection.Out
    )
    local tween = TweenService:Create(instance, info, properties)
    if callback then
        tween.Completed:Once(callback)
    end
    tween:Play()
    return tween
end

-- Play multiple tweens in parallel and call `callback` once when all are done.
function Tween.parallel(tweens: { Tween }, callback: (() -> ())?)
    if #tweens == 0 then
        if callback then callback() end
        return
    end
    local remaining = #tweens
    for _, t in ipairs(tweens) do
        t.Completed:Once(function()
            remaining -= 1
            if remaining == 0 and callback then
                callback()
            end
        end)
        t:Play()
    end
end

function Tween.chain(tweens: { Tween }, callback: (() -> ())?)
    local function play(i: number)
        if i > #tweens then
            if callback then callback() end
            return
        end
        local t = tweens[i]
        t.Completed:Once(function()
            play(i + 1)
        end)
        t:Play()
    end
    play(1)
end

-- Quick helpers for common easing curves
function Tween.quick(instance: Instance, duration: number, props: { [string]: any }): Tween
    return Tween.to(instance, duration, props, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
end

return Tween
