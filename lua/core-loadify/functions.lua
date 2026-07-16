local AddCSLuaFile = AddCSLuaFile
local debug_getinfo = debug.getinfo
local string_Split = string.Split
local include = include
local ErrorNoHalt = ErrorNoHalt
local file_Find = file.Find

AddCSLuaFile()

local MSG = Loadify.MSG

local BASE = "loadify"
local function Normalize(Path)
        Path = Path:gsub("^@", "")

        -- strip "addons/<name>/lua/"
        Path = Path:gsub("^addons/[^/]+/lua/", "")

        -- strip "lua/"
        Path = Path:gsub("^lua/", "")

        return Path
end

local function GetName(Path)
        local Dir = Path:gsub("^loadify/", ""):gsub("/.*$", "")
        return Loadify.LoadedAddonsDirNames[Dir]
end

-- replaced the hardcoded stack level with a stack walker
function Loadify.GetBasePath()
        local Level = 3 -- skip this function's own frame + the Loadify entry point that called us

        while true do
                local Info = debug_getinfo(Level, "S")
                if not Info or not Info.source then return false end

                local Src = Normalize(Info.source)

                -- keep climbing past Loadify's own internal frames
                if not Src:match("^core%-loadify/") then
                        local Split = string_Split(Src, "/")

                        if Split[1] == BASE then
                                return true, Split[1] .. "/" .. Split[2] .. "/"
                        end

                        return false
                end

                Level = Level + 1
        end
end

function Loadify.IsLoadify()
        local IsLoadify = Loadify.GetBasePath()
        return IsLoadify
end

function Loadify.Include(Path)
        local IsLoadify, BasePath = Loadify.GetBasePath()

        if IsLoadify then
                return include(BasePath .. Path)
        end

        ErrorNoHalt("LOADIFY - cannot include file outside of a loadify addon!")

        return nil
end

function Loadify.FindFiles(Path)
        local IsLoadify, BasePath = Loadify.GetBasePath()

        if IsLoadify then
                return file_Find(BasePath .. Path, "LUA")
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
