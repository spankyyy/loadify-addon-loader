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

function Loadify.GetBasePath()
        local info = debug_getinfo(3, "S")
        if not info or not info.source then return false end

        local src = Normalize(info.source)

        local split = string_Split(src, "/")

        if split[1] == BASE then
                return true, split[1] .. "/" .. split[2] .. "/"
        end

        return false
end

function Loadify.Test()
        local info = debug_getinfo(3, "S")
        if not info or not info.source then return false end

        return info.source
end

function Loadify.IsLoadify()
        local info = debug_getinfo(3, "S")
        if not info or not info.source then return false end

        local src = Normalize(info.source)

        local split = string_Split(src, "/")

        if split[1] == BASE then
                return true
        end

        return false
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
        local IsLoadify = false
        local BasePath = ""

        local info = debug_getinfo(3, "S")

        if info ~= nil and info.source ~= nil then
                local src = Normalize(info.source)

                local split = string_Split(src, "/")

                if split[1] == BASE then
                        IsLoadify = true
                        BasePath = split[1] .. "/" .. split[2] .. "/"
                end
        end

        if IsLoadify then
                local AddonName = GetName(BasePath)
                return AddonName, Loadify.LoadedAddons[AddonName]
        end

        ErrorNoHalt("LOADIFY - cannot get current addon outside of a loadify addon!")
end

--- todo
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

--- todo
function Loadify.RegisterEntitiesFromDir(Path)

end
