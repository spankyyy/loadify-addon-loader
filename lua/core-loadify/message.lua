AddCSLuaFile()

local Message = {}

--- @alias MsgLevel
--- | 1 # INFO (yellow)
--- | 2 # WARN (orange)
--- | 3 # ERROR (red)

--- @enum MSGLEVEL
local MSGLEVEL = {
        INFO = 1, -- YELLOW
        WARN = 2, -- ORANGE
        ERROR = 3 -- RED
}

local MSGLEVEL_NAMES = {
        [MSGLEVEL.INFO] = "INFO",
        [MSGLEVEL.WARN] = "WARN",
        [MSGLEVEL.ERROR] = "ERROR"
}

local MSGLEVEL_COLORS = {
        [MSGLEVEL.INFO] = Color(255, 255, 0),
        [MSGLEVEL.WARN] = Color(255, 128, 0),
        [MSGLEVEL.ERROR] = Color(255, 0, 0)
}

local NeutralColor = Color(255, 255, 255)
local TitleColor = Color(0, 255, 0)
local RealmColor = SERVER and Color(128, 240, 255) or Color(255, 240, 128)
local Realm = SERVER and "Server" or "Client"

--- Format and print a coloured message to the console.
--- @param MessageLevel MsgLevel
--- @param AddonName string?
--- @param ... any
local function ThrowMessage(MessageLevel, AddonName, ...)
        local TimeStamp = os.date("%H:%M:%S")
        local LevelColor = MSGLEVEL_COLORS[MessageLevel or 1]
        local LevelName = MSGLEVEL_NAMES[MessageLevel or 1]

        MsgC(
                NeutralColor, "[" .. TimeStamp .. "] ",
                TitleColor, "[" .. AddonName .. "] ",
                NeutralColor, "[",
                RealmColor, Realm,
                NeutralColor, "/",
                LevelColor, LevelName,
                NeutralColor, "]: ",
                NeutralColor, ...,
                "\n"
        )
end

--- Log an info-level message.
--- @param ... any
function Message.Info(...)
        local AddonName = "Loadify"
        if Loadify.IsLoadify() then
                local _, Addon = Loadify.GetCurrentAddon()
                AddonName = Addon.title
        end

        ThrowMessage(MSGLEVEL.INFO, AddonName, ...)
end

--- Log a warning-level message.
--- @param ... any
function Message.Warn(...)
        local AddonName = "Loadify"
        if Loadify.IsLoadify() then
                local _, Addon = Loadify.GetCurrentAddon()
                AddonName = Addon.title
        end

        ThrowMessage(MSGLEVEL.WARN, AddonName, ...)
end

--- Log an error-level message.
--- @param ... any
function Message.Error(...)
        local AddonName = "Loadify"
        if Loadify.IsLoadify() then
                local _, Addon = Loadify.GetCurrentAddon()
                AddonName = Addon.title
        end

        ThrowMessage(MSGLEVEL.ERROR, AddonName, ...)
end

return Message
