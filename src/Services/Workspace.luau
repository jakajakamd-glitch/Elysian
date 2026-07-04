--!nonstrict
--[[
    Workspace Service
    -----------------
    Wraps the `Workspace` service and exposes common queries.
]]

local Workspace = game:GetService("Workspace")

local WorkspaceService = {}
WorkspaceService.__index = WorkspaceService

function WorkspaceService.new()
    return setmetatable({}, WorkspaceService)
end

function WorkspaceService:GetCurrentCamera(): Camera
    return Workspace.CurrentCamera
end

function WorkspaceService:FindFirstChild(name: string): Instance?
    return Workspace:FindFirstChild(name)
end

function WorkspaceService:Raycast(origin: Vector3, direction: Vector3, params: RaycastParams?): RaycastResult?
    return Workspace:Raycast(origin, direction, params)
end

function WorkspaceService:FindPartOnRay(ray: Ray, ignoreDescendantsInstance: Instance?): (BasePart?, Vector3?, Vector3?)
    -- Legacy helper that wraps Raycast for older code.
    local result = Workspace:Raycast(ray.Origin, ray.Direction)
    if result then
        return result.Instance, result.Position, result.Normal
    end
    return nil, nil, nil
end

function WorkspaceService:Raw(): Workspace
    return Workspace
end

return WorkspaceService
