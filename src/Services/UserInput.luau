--!nonstrict
--[[
    UserInput Service
    -----------------
    Wraps `UserInputService` for input listening and key queries.
    Each instance manages its own set of connections.
]]

local UserInputService = game:GetService("UserInputService")

local UserInput = {}
UserInput.__index = UserInput

export type UserInput = typeof(setmetatable({} :: {
    _connections: { RBXScriptConnection },
}, UserInput))

function UserInput.new(): UserInput
    return setmetatable({ _connections = {} }, UserInput) :: any
end

function UserInput:OnInputBegan(callback: (input: InputObject, processed: boolean) -> ()): RBXScriptConnection
    local c = UserInputService.InputBegan:Connect(callback)
    table.insert(self._connections, c)
    return c
end

function UserInput:OnInputChanged(callback: (input: InputObject, processed: boolean) -> ()): RBXScriptConnection
    local c = UserInputService.InputChanged:Connect(callback)
    table.insert(self._connections, c)
    return c
end

function UserInput:OnInputEnded(callback: (input: InputObject, processed: boolean) -> ()): RBXScriptConnection
    local c = UserInputService.InputEnded:Connect(callback)
    table.insert(self._connections, c)
    return c
end

function UserInput:IsKeyDown(keyCode: EnumItem): boolean
    return UserInputService:IsKeyDown(keyCode)
end

function UserInput:GetMouseLocation(): Vector2
    return UserInputService:GetMouseLocation()
end

function UserInput:GetMouseDelta(): Vector2
    return UserInputService:GetMouseDelta()
end

function UserInput:IsMouseButtonPressed(button: EnumItem): boolean
    return UserInputService:IsMouseButtonPressed(button)
end

-- Manually fire an input signal (uses executor `firesignal` when available).
-- Pass one of: UserInputService.InputBegan, .InputChanged, .InputEnded
function UserInput:Fire(signal: any, inputObject: InputObject, processed: boolean?)
    if typeof(firesignal) == "function" then
        firesignal(signal, inputObject, processed or false)
    end
end

-- Replicate an input signal to the server (uses executor `replicatesignal`).
function UserInput:Replicate(signal: any, inputObject: InputObject, processed: boolean?)
    if typeof(replicatesignal) == "function" then
        replicatesignal(signal, inputObject, processed or false)
    end
end

-- Returns the underlying UserInputService (for direct access).
function UserInput:Raw()
    return UserInputService
end

function UserInput:DisconnectAll()
    for _, c in ipairs(self._connections) do
        pcall(function() c:Disconnect() end)
    end
    self._connections = {}
end

function UserInput:Destroy()
    self:DisconnectAll()
end

return UserInput
