--!nonstrict
--[[
    Color - color helpers: hex/rgb/hsl conversion and palette tweaks.
]]

local Color = {}

function Color.fromHex(hex: string): Color3
    hex = string.gsub(hex, "^#", "")
    if #hex == 3 then
        local r = string.sub(hex, 1, 1)
        local g = string.sub(hex, 2, 2)
        local b = string.sub(hex, 3, 3)
        hex = r .. r .. g .. g .. b .. b
    end
    local r = tonumber(string.sub(hex, 1, 2), 16) or 0
    local g = tonumber(string.sub(hex, 3, 4), 16) or 0
    local b = tonumber(string.sub(hex, 5, 6), 16) or 0
    return Color3.fromRGB(r, g, b)
end

function Color.toHex(c: Color3): string
    local r = math.floor(c.R * 255 + 0.5)
    local g = math.floor(c.G * 255 + 0.5)
    local b = math.floor(c.B * 255 + 0.5)
    return string.format("#%02X%02X%02X", r, g, b)
end

function Color.lerp(a: Color3, b: Color3, t: number): Color3
    return Color3.fromRGB(
        math.floor(a.R + (b.R - a.R) * t * 255 + 0.5),
        math.floor(a.G + (b.G - a.G) * t * 255 + 0.5),
        math.floor(a.B + (b.B - a.B) * t * 255 + 0.5)
    )
end

function Color.lighten(c: Color3, amount: number): Color3
    amount = math.clamp(amount, 0, 1)
    local h, s, v = Color3.toHSV(c)
    return Color3.fromHSV(h, s, math.clamp(v + amount, 0, 1))
end

function Color.darken(c: Color3, amount: number): Color3
    amount = math.clamp(amount, 0, 1)
    local h, s, v = Color3.toHSV(c)
    return Color3.fromHSV(h, s, math.clamp(v - amount, 0, 1))
end

function Color.saturate(c: Color3, amount: number): Color3
    amount = math.clamp(amount, -1, 1)
    local h, s, v = Color3.toHSV(c)
    return Color3.fromHSV(h, math.clamp(s + amount, 0, 1), v)
end

function Color.withAlpha(c: Color3, alpha: number): Color3
    -- Color3 has no alpha; consumers requiring alpha should use Color3 + UICorner +
    -- BackgroundTransparency derived from this. This is a no-op helper kept for symmetry.
    return c
end

return Color
