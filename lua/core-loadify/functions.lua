local AddCSLuaFile = AddCSLuaFile
local debug_getinfo = debug.getinfo
local string_Split = string.Split
local include = include
local ErrorNoHalt = ErrorNoHalt
local file_Find = file.Find

AddCSLuaFile()

local MSG = Loadify.MSG

local BASE = "loadify"
local function Normalize(path)
        path = path:gsub("^@", "")

        -- strip "addons/<name>/lua/"
        path = path:gsub("^addons/[^/]+/lua/", "")

        -- strip "lua/"
        path = path:gsub("^lua/", "")

        return path
end

local function GetName(path)
        local dir = path:gsub("^loadify/", ""):gsub("/.*$", "")
        return Loadify.LoadedAddonsDirNames[dir]
end

-- replaced the hardcoded stack level with a stack walker
function Loadify.GetBasePath()
        local level = 3 -- skip this function's own frame + the Loadify entry point that called us

        while true do
                local info = debug_getinfo(level, "S")
                if not info or not info.source then return false end

                local src = Normalize(info.source)

                -- keep climbing past Loadify's own internal frames
                if not src:match("^core%-loadify/") then
                        local split = string_Split(src, "/")

                        if split[1] == BASE then
                                return true, split[1] .. "/" .. split[2] .. "/"
                        end

                        return false
                end

                level = level + 1
        end
end

function Loadify.IsLoadify()
        local IsLoadify = Loadify.GetBasePath()
        return IsLoadify
end

function Loadify.Include(path)
        local IsLoadify, BasePath = Loadify.GetBasePath()

        if IsLoadify then
                return include(BasePath .. path)
        end

        ErrorNoHalt("LOADIFY - cannot include file outside of a loadify addon!")

        return nil
end

function Loadify.FindFiles(path)
        local IsLoadify, BasePath = Loadify.GetBasePath()

        if IsLoadify then
                return file_Find(BasePath .. path, "LUA")
        end

        ErrorNoHalt("LOADIFY - cannot find files outside of a loadify addon!")

        return nil
end

function Loadify.GetCurrentAddon()
        local IsLoadify, BasePath = Loadify.GetBasePath()

        if IsLoadify then
                local AddonName = GetName(BasePath)
                return AddonName, Loadify.LoadedAddons[AddonName]
        end

        ErrorNoHalt("LOADIFY - cannot get current addon outside of a loadify addon!")
end

function Loadify.RegisterEntityFromFile(Path)
        local IsLoadify, BasePath = Loadify.GetBasePath()

        MSG.Info(BasePath .. Path)

        if IsLoadify then
                MSG.Info("Loading entity [" .. Path .. "]...")

                do
                        ENT, CLASSNAME = {}, nil

                        include(BasePath .. Path)

                        scripted_ents.Register(ENT, CLASSNAME)

                        if CLASSNAME ~= nil then

                        elseif CLASSNAME ~= "base_entity" then
                                MSG.Error("Entity [" .. Path .. "] tried to override base_entity")
                        else
                                MSG.Error("Entity [" .. Path .. "] does not have a ClassName defined.")
                        end
                        _G.ENT, _G.CLASSNAME = nil, nil
                end
        end
end

function Loadify.RegisterWeaponFromFile(Path)
        local IsLoadify, BasePath = Loadify.GetBasePath()

        MSG.Info(BasePath .. Path)

        if IsLoadify then
                MSG.Info("Loading weapon [" .. Path .. "]...")

                do
                        ENT, CLASSNAME = {}, nil

                        include(BasePath .. Path)

                        weapons.Register(ENT, CLASSNAME)

                        if CLASSNAME ~= nil then

                        elseif CLASSNAME ~= "base_entity" then
                                MSG.Error("Weapon [" .. Path .. "] tried to override base_entity")
                        else
                                MSG.Error("Weapon [" .. Path .. "] does not have a ClassName defined.")
                        end
                        _G.ENT, _G.CLASSNAME = nil, nil
                end
        end
end

--- todo
function Loadify.RegisterEntitiesFromDir(Path)

end

--- todo
function Loadify.RegisterWeaponsFromDir(Path)

end
