--!nonstrict
--[[
    Logger - tagged, level-aware console output.

    Used as a singleton: `Logger:Info("...")`, `Logger:SetLevel("Debug")`, etc.
]]

local Logger = {}

local LEVEL_ORDER = { ["Debug"] = 1, ["Info"] = 2, ["Warn"] = 3, ["Error"] = 4 }
Logger._level = "Info"

local function format(level: string, message: string): string
    return string.format("[%s] [Elysian] %s", string.upper(level), message)
end

function Logger:Debug(message: string)
    if LEVEL_ORDER[self._level] <= 1 then
        print(format("Debug", message))
    end
end

function Logger:Info(message: string)
    if LEVEL_ORDER[self._level] <= 2 then
        print(format("Info", message))
    end
end

function Logger:Warn(message: string)
    if LEVEL_ORDER[self._level] <= 3 then
        warn(format("Warn", message))
    end
end

function Logger:Error(message: string)
    error(format("Error", message), 2)
end

function Logger:SetLevel(level: string)
    assert(LEVEL_ORDER[level], "Invalid log level: " .. tostring(level))
    self._level = level
end

return Logger
