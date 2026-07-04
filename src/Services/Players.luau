--!nonstrict
--[[
    Players Service
    ---------------
    Wraps `Players` service: local player, players list, and connects.
]]

local Players = game:GetService("Players")

local PlayersService = {}
PlayersService.__index = PlayersService

export type PlayersService = typeof(setmetatable({} :: {
    _connections: { RBXScriptConnection },
}, PlayersService))

function PlayersService.new(): PlayersService
    return setmetatable({ _connections = {} }, PlayersService) :: any
end

function PlayersService:GetLocalPlayer(): Player
    return Players.LocalPlayer
end

function PlayersService:GetPlayers(): { Player }
    return Players:GetPlayers()
end

function PlayersService:GetPlayerByUserId(userId: number): Player?
    return Players:GetPlayerByUserId(userId)
end

function PlayersService:GetPlayerByName(name: string): Player?
    return Players:FindFirstChild(name) :: any
end

function PlayersService:OnPlayerAdded(callback: (player: Player) -> ()): RBXScriptConnection
    local c = Players.PlayerAdded:Connect(callback)
    table.insert(self._connections, c)
    return c
end

function PlayersService:OnPlayerRemoving(callback: (player: Player) -> ()): RBXScriptConnection
    local c = Players.PlayerRemoving:Connect(callback)
    table.insert(self._connections, c)
    return c
end

function PlayersService:OnCharacterAdded(player: Player, callback: (character: Model) -> ()): RBXScriptConnection?
    if not player then return nil end
    local c = player.CharacterAdded:Connect(callback)
    table.insert(self._connections, c)
    return c
end

function PlayersService:DisconnectAll()
    for _, c in ipairs(self._connections) do
        pcall(function() c:Disconnect() end)
    end
    self._connections = {}
end

function PlayersService:Destroy()
    self:DisconnectAll()
end

return PlayersService
