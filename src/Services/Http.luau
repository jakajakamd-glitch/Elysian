--!nonstrict
--[[
    Http Service
    ------------
    Thin wrapper around Roblox HttpService plus executor `request` fallback.
]]

local HttpService = game:GetService("HttpService")

local Http = {}
Http.__index = Http

function Http.new()
    return setmetatable({}, Http)
end

function Http:Get(url: string, headers: { [string]: string }?): string
    if typeof(request) == "function" then
        local res = request({
            Url = url,
            Method = "GET",
            Headers = headers or {},
        })
        return res.Body
    end
    return HttpService:GetAsync(url, false)
end

function Http:Post(url: string, body: string, contentType: string?, headers: { [string]: string }?): string
    if typeof(request) == "function" then
        local res = request({
            Url = url,
            Method = "POST",
            Body = body,
            Headers = headers or {},
        })
        return res.Body
    end
    return HttpService:PostAsync(url, body, Enum.HttpContentType.ApplicationUrlEncoded)
end

function Http:JSONEncode(value: any): string
    return HttpService:JSONEncode(value)
end

function Http:JSONDecode(value: string): any
    return HttpService:JSONDecode(value)
end

function Http:UrlEncode(value: string): string
    return HttpService:UrlEncode(value)
end

function Http:GenerateGUID(wrapInCurlyBraces: boolean?): string
    return HttpService:GenerateGUID(wrapInCurlyBraces)
end

return Http
