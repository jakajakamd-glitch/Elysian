--!nonstrict
--[[
    Theme - default Elysian theme and helpers for creating custom themes.
    A "Theme" is just a table of Color3 values, font, and metric numbers
    consumed by Components when constructing instances.
]]

local Theme = {}

-- Default theme (a soft dark UI, inspired by modern editor palettes).
local defaultTheme = {
    Background    = Color3.fromRGB(18, 19, 24),
    BackgroundAlt = Color3.fromRGB(24, 26, 33),
    Surface       = Color3.fromRGB(30, 33, 42),
    SurfaceAlt    = Color3.fromRGB(48, 52, 66),
    Border        = Color3.fromRGB(56, 60, 76),
    Accent        = Color3.fromRGB(86, 156, 255),
    AccentAlt     = Color3.fromRGB(64, 120, 200),
    Text          = Color3.fromRGB(232, 234, 240),
    TextMuted     = Color3.fromRGB(150, 155, 170),
    Success       = Color3.fromRGB(95, 200, 130),
    Warning       = Color3.fromRGB(255, 195, 90),
    Danger        = Color3.fromRGB(230, 95, 95),

    -- Font stack: GothamSSm is the cleanest modern Roblox font. Fall back
    -- to GothamMedium/Bold on engines that don't expose GothamSSm.
    Font         = Enum.Font.GothamMedium,
    FontBold     = Enum.Font.GothamBold,
    FontMono     = Enum.Font.RobotoMono,
    FontSize     = 15,
    CornerRadius = 8,
    Padding      = 8,
    ItemHeight   = 38,
}

Theme.Default = defaultTheme
Theme.Current = defaultTheme

-- Override the active theme with a new table (merges with default).
function Theme:Set(theme: { [string]: any })
    local merged = {}
    for k, v in pairs(defaultTheme) do merged[k] = v end
    for k, v in pairs(theme or {}) do merged[k] = v end
    self.Current = merged
    return merged
end

-- Returns a new merged theme without changing the active one.
function Theme:Merge(theme: { [string]: any }): { [string]: any }
    local merged = {}
    for k, v in pairs(self.Current) do merged[k] = v end
    for k, v in pairs(theme or {}) do merged[k] = v end
    return merged
end

-- Reset back to the default theme.
function Theme:Reset()
    self.Current = defaultTheme
end

-- Convenience accessor: Theme:Get("Background")
function Theme:Get(key: string): any
    return self.Current[key]
end

return Theme
