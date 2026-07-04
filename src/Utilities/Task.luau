--!nonstrict
--[[
    Task - thin wrapper around Roblox's task library to centralise
    deferred/spawned execution and provide a simple cancellation token.
]]

local Task = {}

function Task.spawn(fn: (...any) -> (), ...: any)
    return task.spawn(fn, ...)
end

function Task.defer(fn: (...any) -> (), ...: any)
    return task.defer(fn, ...)
end

function Task.delay(seconds: number, fn: (...any) -> (), ...: any)
    return task.delay(seconds, fn, ...)
end

function Task.wait(seconds: number?)
    return task.wait(seconds)
end

function Task.heartbeatWait()
    return task.wait()
end

-- Spawns a loop that runs `fn(dt)` every frame until the returned
-- cancellation function is called.
function Task.everyFrame(fn: (number) -> ()): () -> ()
    local conn
    local alive = true
    local last = os.clock()
    local RunService = game:GetService("RunService")
    conn = RunService.Heartbeat:Connect(function()
        if not alive then return end
        local now = os.clock()
        local dt = now - last
        last = now
        fn(dt)
    end)
    return function()
        alive = false
        if conn then conn:Disconnect() end
    end
end

-- Calls `fn` every `interval` seconds until the returned cancellation
-- function is called.
function Task.every(interval: number, fn: () -> ()): () -> ()
    local alive = true
    task.spawn(function()
        while alive do
            task.wait(interval)
            if not alive then break end
            fn()
        end
    end)
    return function()
        alive = false
    end
end

return Task
