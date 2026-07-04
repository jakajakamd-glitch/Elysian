--!nonstrict
-- Elysian shared type definitions.

export type Instance = any
export type GuiObject = any

export type Vector2 = { X: number, Y: number }
export type UDim2 = any
export type UDim = any
export type Color3 = any

export type Theme = {
    Background:    Color3,
    BackgroundAlt: Color3,
    Surface:       Color3,
    SurfaceAlt:    Color3,
    Border:        Color3,
    Accent:        Color3,
    AccentAlt:     Color3,
    Text:          Color3,
    TextMuted:     Color3,
    Success:       Color3,
    Warning:       Color3,
    Danger:        Color3,
    Font:          any,
    FontSize:      number,
    CornerRadius:  number,
    Padding:       number,
}

export type Signal<T...> = {
    Connect: (self: Signal<T...>, callback: (T...) -> ()) -> { Disconnect: () -> () },
    Fire: (self: Signal<T...>, T...) -> (),
    Wait: (self: Signal<T...>) -> T...,
    Destroy: (self: Signal<T...>) -> (),
}

export type ComponentProps = {
    Name: string?,
    Tooltip: string?,
    Visible: boolean?,
}

return {}
