local AddCSLuaFile = AddCSLuaFile
local include = include
local file_Find = file.Find
local file_Exists = file.Exists
local ipairs = ipairs
local pairs = pairs
local table_insert = table.insert
local table_remove = table.remove

local concommand_Add = concommand.Add
local net_Start = net.Start
local net_Broadcast = net.Broadcast
local hook_Add = hook.Add
local net_Receive = net.Receive

AddCSLuaFile()

Loadify = {}

local MSG = include("core-loadify/message.lua")
Loadify.MSG = MSG

include("core-loadify/functions.lua")

Loadify.LoadedAddons = {}
local loadedAddons = Loadify.LoadedAddons
Loadify.LoadedAddonsDirNames = {}
local loadedAddonsDirNames = Loadify.LoadedAddonsDirNames

local queue = {}

local STRICT_DEPENDENCY = true
local STRICT_VERSION = true

local LOAD_ENABLED = true

-- Parses "myaddon>=1.0" into { name = "myaddon", op = ">=", version = "1.0" }
-- If no operator/version, returns { name = "myaddon", op = nil, version = nil }
local function parseDependency(dep)
        local name, op, version = dep:match("^([%w_%-%.]+)([><=!]+)(.+)$")
        if name and op and version then
                return { name = name, op = op, version = version }
        end
        return { name = dep, op = nil, version = nil }
end

-- Converts "1.2.3" into a table of numbers { 1, 2, 3 } for comparison
local function parseVersion(v)
        local parts = {}
        for part in v:gmatch("[^%.]+") do
                table_insert(parts, tonumber(part) or 0)
        end
        return parts
end

-- Returns -1, 0, or 1 (a < b, a == b, a > b)
local function compareVersions(a, b)
        local pa = parseVersion(a)
        local pb = parseVersion(b)
        local len = math.max(#pa, #pb)
        for i = 1, len do
                local va = pa[i] or 0
                local vb = pb[i] or 0
                if va < vb then return -1 end
                if va > vb then return 1 end
        end
        return 0
end

-- Returns true if `actual` satisfies `op` `required`
-- e.g. satisfiesVersion("1.2.0", ">=", "1.0.0") -> true
local function satisfiesVersion(actual, op, required)
        local cmp = compareVersions(actual, required)
        if op == ">" then return cmp > 0 end
        if op == "<" then return cmp < 0 end
        if op == ">=" then return cmp >= 0 end
        if op == "<=" then return cmp <= 0 end
        if op == "==" then return cmp == 0 end
        return false
end

local function verifyManifest(info)
        if not info then return false end
        if type(info.name) ~= "string" or #info.name == 0 then return false end
        if type(info.version) ~= "string" or #info.version == 0 then return false end
        return true
end

local function Load()
        if not LOAD_ENABLED then return end

        local _, directories = file_Find("loadify/*", "LUA")

        for _, dir in ipairs(directories) do
                local path = "loadify/" .. dir

                if not file_Exists(path .. "/manifest.lua", "LUA") then
                        MSG.Warn(string.format("Addon '%s' is missing manifest.lua", dir))
                elseif not file_Exists(path .. "/main.lua", "LUA") then
                        MSG.Warn(string.format("Addon '%s' is missing main.lua", dir))
                else
                        local info = include(path .. "/manifest.lua")

                        AddCSLuaFile(path .. "/manifest.lua")
                        AddCSLuaFile(path .. "/main.lua")

                        if verifyManifest(info) then
                                table_insert(queue, { info = info, path = path })
                        else
                                MSG.Error(string.format("Couldn't verify manifest for '%s'", dir))
                        end

                        loadedAddonsDirNames[dir] = info.name
                end
        end



        local moves = 0
        local remaining = #queue


        while remaining > 0 do
                local addon = queue[1]
                local info, path = addon.info, addon.path
                local name = info.name

                local dependenciesLoaded = true

                if STRICT_DEPENDENCY and info.dependencies and #info.dependencies > 0 then
                        for _, depString in pairs(info.dependencies) do
                                local dep = parseDependency(depString)

                                if not loadedAddons[dep.name] then
                                        dependenciesLoaded = false
                                        break
                                end

                                -- Dependency is loaded; now check version constraint if present
                                if STRICT_VERSION and dep.op and dep.version then
                                        local loadedVersion = loadedAddons[dep.name].version
                                        if not satisfiesVersion(loadedVersion, dep.op, dep.version) then
                                                MSG.Error(string.format(
                                                        "Addon '%s' requires '%s%s%s' but loaded version is '%s'",
                                                        name, dep.name, dep.op, dep.version, loadedVersion))
                                                dependenciesLoaded = false
                                                break
                                        end
                                end
                        end

                        if not dependenciesLoaded then
                                moves = moves + 1
                                table_insert(queue, table_remove(queue, 1))
                        else
                                moves = 0
                        end

                        if moves >= remaining then
                                for _, blocked in ipairs(queue) do
                                        local blockedInfo = blocked.info
                                        if blockedInfo == nil or blockedInfo.dependencies == nil or #blockedInfo.dependencies == 0 then
                                                continue
                                        end

                                        local missing = {}
                                        for _, depString in pairs(blockedInfo.dependencies) do
                                                local dep = parseDependency(depString)

                                                if not loadedAddons[dep.name] then
                                                        table_insert(missing, depString) -- include the full string for clarity
                                                elseif STRICT_VERSION and dep.op and dep.version then
                                                        local loadedVersion = loadedAddons[dep.name].version
                                                        if not satisfiesVersion(loadedVersion, dep.op, dep.version) then
                                                                table_insert(missing, string.format(
                                                                        "%s%s%s (got %s)", dep.name, dep.op, dep.version, loadedVersion))
                                                        end
                                                end
                                        end

                                        if #missing > 0 then
                                                MSG.Error(string.format(
                                                        "Addon '%s' has unresolvable dependencies: %s",
                                                        blockedInfo.name or "(unknown)",
                                                        table.concat(missing, ", ")))
                                        end
                                end

                                break
                        end
                end

                if dependenciesLoaded then
                        MSG.Info(string.format("Loading addon '%s'", name))

                        table_remove(queue, 1)
                        remaining = remaining - 1

                        -- Store the addon's version alongside its loaded state so
                        -- dependents can check version constraints against it
                        loadedAddons[name] = info

                        include(path .. "/main.lua")

                        print()
                end
        end
end

if SERVER then
        util.AddNetworkString("loadify_lua_reload")

        concommand_Add("loadify_reload", function(player)
                if player ~= nil and player ~= NULL and not player:IsSuperAdmin() then
                        return
                end

                Load()

                net_Start("loadify_lua_reload")
                net_Broadcast()
        end)

        Load()
end

if CLIENT then
        hook_Add("InitPostEntity", "Loadify.Init", function()
                Load()
                LOADIFY_ClientFirstLoaded = true
        end)

        if LOADIFY_ClientFirstLoaded then
                Load()
        end

        net_Receive("loadify_lua_reload", function()
                Load()
        end)
end
