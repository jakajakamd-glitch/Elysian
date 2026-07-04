--!nonstrict
--[[
    BaseComponent - shared lifecycle and parent-management for all
    Elysian UI components. Components inherit this to get a common
    Destroy / SetParent / SetVisible API.
]]

local BaseComponent = {}
BaseComponent.__index = BaseComponent

export type BaseComponent = typeof(setmetatable({} :: {
    Instance: Instance?,
    Parent: Instance?,
    Visible: boolean,
    Destroyed: boolean,
    Children: { BaseComponent },
}, BaseComponent))

function BaseComponent.new(): BaseComponent
    return setmetatable({
        Instance = nil,
        Parent = nil,
        Visible = true,
        Destroyed = false,
        Children = {},
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
    if self.Instance then
        pcall(function() self.Instance:Destroy() end)
        self.Instance = nil
    end
end

return BaseComponent
