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

--------------------------------------------------------------------------------------------------------------------------------

AddCSLuaFile()

Loadify = {}
Loadify.MSG = include("core-loadify/message.lua")
local MSG = Loadify.MSG

--------------------------------------------------------------------------------------------------------------------------------

Loadify.LoadedAddons = {}
Loadify.LoadedAddonsDirNames = {}
Loadify.AddonDirectory = "loadify/"

Loadify.LuaContainer = include("core-loadify/container.lua")
Loadify.Ecosystem = {
        Preprocessors = {
                include_static = "ecosystem/preprocessors/dofile.lua"
        },
        ENV = {
                Default = "ecosystem/default_environment.lua"
        }
}

local loadedAddons = Loadify.LoadedAddons
local loadedAddonsDirNames = Loadify.LoadedAddonsDirNames

local LuaContainer = Loadify.LuaContainer

local queue = {}
local sortedAddonsName = {}
local sortedAddons = {}

local LOAD_ENABLED = true
local STRICT_DEPENDENCY = true


--------------------------------------------------------------------------------------------------------------------------------

local function verifyManifest(info)
        if not info then return false end
        if type(info.name) ~= "string" or #info.name == 0 then return false end
        if type(info.version) ~= "string" or #info.version == 0 then return false end
        return true
end

local function checkDependencies(info)
        for _, dependency in pairs(info.dependencies) do
                if not sortedAddonsName[dependency] then
                        return false
                end
        end

        return true
end

local function getMissingDependencies(blockedInfo)
        local missing = {}

        if blockedInfo == nil or blockedInfo.dependencies == nil or #blockedInfo.dependencies == 0 then
                return missing
        end

        for _, dependency in pairs(blockedInfo.dependencies) do
                if not sortedAddonsName[dependency] then
                        table_insert(missing, dependency)
                end
        end

        return missing
end

local function reportDeadlock(stuckQueue)
        for _, blocked in ipairs(stuckQueue) do
                local missing = getMissingDependencies(blocked.info)

                if #missing > 0 then
                        MSG.Error(string.format(
                                "Addon '%s' has unresolvable dependencies: %s",
                                blocked.info.name or "(unknown)",
                                table.concat(missing, ", ")))
                end
        end
end

local function loadAddon(basePath, path)
        local SourceCode = file.Read(basePath .. path, "LUA")
        if SourceCode == nil then
                MSG.Error(string.format("Cannot load file: '%s' is missing.", basePath .. path))
                return nil
        end

        local AddonContainer = LuaContainer {}
        local DefaultEnv = include(Loadify.Ecosystem.ENV.Default)
        local ENV = table.Copy(DefaultEnv(AddonContainer))

        AddonContainer.BasePath = basePath
        AddonContainer.CurrentFile = basePath .. path
        AddonContainer:SetName(AddonContainer.CurrentFile)

        for _, PreprocessorPath in pairs(Loadify.Ecosystem.Preprocessors) do
                Preprocessor = include(PreprocessorPath)

                AddonContainer:AddProcessor(Preprocessor)
        end

        AddonContainer
            :SetEnvironment(ENV)
            :SetSourceCode(SourceCode)
            :Process()
            :Compile()
            :Run()

        return nil
end

local function Load()
        if not LOAD_ENABLED then return end

        local _, directories = file_Find(Loadify.AddonDirectory .. "*", "LUA")

        for _, dir in ipairs(directories) do
                local path = Loadify.AddonDirectory .. dir

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

        -- sort addons based on depencencies
        while remaining > 0 do
                local addon = queue[1]
                local info = addon.info
                local name = info.name

                local dependenciesLoaded = true

                if STRICT_DEPENDENCY and info.dependencies and #info.dependencies > 0 then
                        dependenciesLoaded = checkDependencies(info)

                        if not dependenciesLoaded then
                                moves = moves + 1
                                table_insert(queue, table_remove(queue, 1))
                        else
                                moves = 0
                        end

                        if moves >= remaining then
                                reportDeadlock(queue)
                                break
                        end
                end

                if dependenciesLoaded then
                        table_remove(queue, 1)
                        remaining = remaining - 1


                        sortedAddonsName[addon.info.name] = addon

                        table.insert(sortedAddons, addon)
                end
        end

        print()
        MSG.Info(string.format("Loading addons (%i)", #sortedAddons))

        local AddonNum, Index = #sortedAddons, 1
        for _, addon in pairs(sortedAddons) do
                MSG.Info(string.format("Loading addon '%s' (%i/%i)", addon.info.name, Index, AddonNum))

                loadAddon(addon.path, "/main.lua")

                Index = Index + 1
        end
end

--------------------------------------------------------------------------------------------------------------------------------

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
