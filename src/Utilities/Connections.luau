--!nonstrict
--[[
    Connections - a managed collection of RBXScriptConnections (and
    arbitrary cleanup functions) that can be torn down in one call.

    Usage:
        local Connections = Elysian.Connections.new()

        Connections:Add(workspace.ChildAdded:Connect(function(c) ... end))
        Connections:Add(function()
            -- custom cleanup
            print("tearing down")
        end)

        Connections:DisconnectAll()  -- tears everything down in LIFO order

    Also exposes a small helper for binding many connections at once:
        Connections:Bind {
            workspace.ChildAdded:Connect(...),
            RunService.Heartbeat:Connect(...),
        }
]]

local Connections = {}
Connections.__index = Connections

function Connections.new()
    return setmetatable({
        _items = {},
        _alive = true,
    }, Connections)
end

-- Add a connection (or any object with a :Disconnect() method) OR a plain
-- cleanup function. Returns the connection so the caller can also store
-- a reference if needed.
function Connections:Add(connection)
    if not self._alive then
        -- Already torn down; disconnect immediately if possible.
        if typeof(connection) == "function" then
            pcall(connection)
        elseif connection and typeof(connection.Disconnect) == "function" then
            pcall(function() connection:Disconnect() end)
        end
        return connection
    end
    table.insert(self._items, connection)
    return connection
end

-- Bind a list of connections / cleanup functions at once.
function Connections:Bind(list)
    for _, c in ipairs(list) do
        self:Add(c)
    end
end

-- Disconnect a specific connection (and remove it from the bag).
function Connections:Remove(connection)
    for i, c in ipairs(self._items) do
        if c == connection then
            table.remove(self._items, i)
            if typeof(c) == "function" then
                pcall(c)
            elseif c and typeof(c.Disconnect) == "function" then
                pcall(function() c:Disconnect() end)
            end
            return true
        end
    end
    return false
end

-- Tear down everything in reverse order (LIFO), so dependents are cleaned
-- up before the things they depend on.
function Connections:DisconnectAll()
    self._alive = false
    local items = self._items
    self._items = {}
    for i = #items, 1, -1 do
        local c = items[i]
        local ok, err = pcall(function()
            if typeof(c) == "function" then
                c()
            elseif c and typeof(c.Disconnect) == "function" then
                c:Disconnect()
            end
        end)
        if not ok then
            warn("[Elysian.Connections] cleanup error:", err)
        end
    end
end

-- Alias
Connections.Destroy = Connections.DisconnectAll
Connections.Cleanup  = Connections.DisconnectAll

function Connections:IsAlive()
    return self._alive
end

function Connections:Count()
    return #self._items
end

return Connections
