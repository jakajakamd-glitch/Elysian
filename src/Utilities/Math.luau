--!nonstrict
--[[
    Math - small math helpers used across the UI library.
]]

local Math = {}

function Math.clamp(value: number, min: number, max: number): number
    if value < min then return min end
    if value > max then return max end
    return value
end

-- A more compact clamp used internally by hot paths (relies on math.min/max).
function Math.clampRaw(value: number, min: number, max: number): number
    return math.min(math.max(value, min), max)
end

function Math.lerp(a: number, b: number, t: number): number
    return a + (b - a) * t
end

function Math.lerpClamped(a: number, b: number, t: number): number
    return Math.lerp(a, b, Math.clamp(t, 0, 1))
end

function Math.invLerp(a: number, b: number, v: number): number
    if a == b then return 0 end
    return (v - a) / (b - a)
end

function Math.invLerpClamped(a: number, b: number, v: number): number
    return Math.clamp(Math.invLerp(a, b, v), 0, 1)
end

function Math.remap(v: number, inMin: number, inMax: number, outMin: number, outMax: number): number
    return outMin + (outMax - outMin) * Math.invLerpClamped(inMin, inMax, v)
end

function Math.round(value: number, precision: number?): number
    local p = precision or 1
    local mult = 1 / p
    return math.floor(value * mult + 0.5) / mult
end

function Math.mapRange(value: number, a1: number, a2: number, b1: number, b2: number): number
    return b1 + (value - a1) * (b2 - b1) / (a2 - a1)
end

function Math.approxEq(a: number, b: number, eps: number?): boolean
    return math.abs(a - b) <= (eps or 1e-6)
end

-- Catmull-Rom-ish smoothing helper, used for slider easing.
function Math.smooth(current: number, target: number, smoothing: number?, dt: number?): number
    local s = Math.clamp(smoothing or 0.15, 0, 0.999)
    local d = dt or 0.016
    local factor = 1 - math.pow(s, d * 60)
    return current + (target - current) * factor
end

return Math
