--!nonstrict
--[[
    Bootstrap - the shared module loader. This is the ONLY place that
    fetches Luau source from the repo. Every other module calls into
    here via the global _ELYSIAN_BOOTSTRAP symbol.

    Uses the executor `request()` function (preferred) with a fallback
    to `game:HttpGet`. All fetched modules are cached in a shared
    global table so every subsystem sees the SAME instance of each
    module (critical for Theme, Signal, etc. - otherwise each module
    gets its own copy and Theme:Set in one place doesn't propagate).
]]

local REPO_OWNER  = "jakajakamd-glitch"
local REPO_NAME   = "Elysian"
local REPO_BRANCH = "main"
local BASE_URL    = ("https://raw.githubusercontent.com/%s/%s/%s"):format(
    REPO_OWNER, REPO_NAME, REPO_BRANCH
)

-- Shared global cache. Keyed by relative path. ALL modules read from
-- and write to this same table.
if _G._ELYSIAN_CACHE == nil then
    _G._ELYSIAN_CACHE = {}
end
local cache = _G._ELYSIAN_CACHE

-- Fetch a URL's contents. Uses executor `request()` first (returns a
-- Response table with .Body), then falls back to `game:HttpGet`.
local function fetch(url: string): string
    -- Cache-bust so executors that cache HTTP responses still pull fresh code.
    local busted = url .. (string.find(url, "?") and "&" or "?") .. "_t=" .. tostring(os.time())

    if typeof(request) == "function" then
        local ok, res = pcall(function()
            return request({
                Url = busted,
                Method = "GET",
                Headers = { ["Cache-Control"] = "no-cache" },
            })
        end)
        if ok and res and type(res.Body) == "string" and #res.Body > 0 then
            return res.Body
        end
    end

    if game and game.GetService then
        local ok, result = pcall(function()
            return game:HttpGet(busted, true)
        end)
        if ok and type(result) == "string" and #result > 0 then
            return result
        end
    end

    error("[Elysian.Bootstrap] Failed to fetch: " .. url, 2)
end

-- Load (and cache) a Luau module from the repo by relative path.
-- Returns the module's exports table. Subsequent calls for the same
-- path return the cached instance.
local function requireRemote(relativePath: string): any
    if cache[relativePath] then
        return cache[relativePath]
    end
    local url = BASE_URL .. "/" .. relativePath
    local source = fetch(url)
    local fn, err = loadstring(source, relativePath)
    if not fn then
        error("[Elysian.Bootstrap] Failed to compile '" .. relativePath .. "': " .. tostring(err), 2)
    end
    local exports = fn()
    cache[relativePath] = exports
    return exports
end

-- Pre-load a module without returning it (useful for warming the cache).
local function preload(relativePath: string)
    requireRemote(relativePath)
end

-- Expose the bootstrap API on the global so other modules can use it
-- without each having their own copy of the fetch logic.
_G._ELYSIAN_BOOTSTRAP = {
    fetch         = fetch,
    requireRemote = requireRemote,
    preload       = preload,
    BASE_URL      = BASE_URL,
    cache         = cache,
}

return _G._ELYSIAN_BOOTSTRAP
