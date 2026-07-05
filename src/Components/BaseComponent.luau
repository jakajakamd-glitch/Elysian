--!nonstrict
--[[
    BaseComponent - shared lifecycle and parent-management for all
    Elysian UI components. Components inherit this to get a common
    Destroy / SetParent / SetVisible API.

    Subclasses can store connections in `self.Connections` (an
    Elysian.Connections instance) and they'll be torn down automatically
    on :Destroy().
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

local Connections = requireRemote("src/Utilities/Connections.luau")

local BaseComponent = {}
BaseComponent.__index = BaseComponent

export type BaseComponent = typeof(setmetatable({} :: {
    Instance: Instance?,
    Parent: Instance?,
    Visible: boolean,
    Destroyed: boolean,
    Children: { BaseComponent },
    Connections: any,
}, BaseComponent))

function BaseComponent.new(): BaseComponent
    return setmetatable({
        Instance = nil,
        Parent = nil,
        Visible = true,
        Destroyed = false,
        Children = {},
        Connections = Connections.new(),
    }, BaseComponent) :: any
end

function BaseComponent:SetParent(parent: Instance?)
    self.Parent = parent
    if self.Instance then
        self.Instance.Parent = parent
    end
end

function BaseComponent:SetVisible(visible: boolean)
    self.Visible = visible
    if self.Instance and self.Instance:IsA("GuiObject") then
        self.Instance.Visible = visible
    end
end

function BaseComponent:GetInstance(): Instance?
    return self.Instance
end

function BaseComponent:AddChild(child: BaseComponent)
    table.insert(self.Children, child)
end

function BaseComponent:RemoveChild(child: BaseComponent)
    local idx = table.find(self.Children, child)
    if idx then table.remove(self.Children, idx) end
end

function BaseComponent:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    for _, c in ipairs(self.Children) do
        pcall(function() c:Destroy() end)
    end
    self.Children = {}
    if self.Connections then
        pcall(function() self.Connections:DisconnectAll() end)
    end
    if self.Instance then
        pcall(function() self.Instance:Destroy() end)
        self.Instance = nil
    end
end

return BaseComponent
