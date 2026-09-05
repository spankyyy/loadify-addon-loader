AddCSLuaFile()

local RequireCache = {}
local ResolvePath = include("ecosystem/util/path_resolver.lua")

local function ReadFile(Path, Caller)
        local SourceCode = file.Read(Path, "LUA")
        if SourceCode == nil then
                error(string.format("%s could not read '%s'", Caller, Path), 2)
        end

        return SourceCode
end

local function RunFile(Container, Path, SourceCode)
        local Child = Container:CreateChild(Path, SourceCode)
        local Return = { Child:Process():Compile():Run() }
        return unpack(Return)
end

local function SendFile(Path, CheckExists)
        if not CheckExists then
                AddCSLuaFile(Path)
                return
        end

        if not file.Exists(Path, "LUA") then
                error(string.format("AddCSLuaFile could not find '%s'", Path), 2)
        end

        AddCSLuaFile(Path)
end

return function(Container)
        local ENV = {}
        ENV.builtin = {}

        ENV.PrintTable = PrintTable
        ENV.print = print

        function ENV.AddCSLuaFile(path)
                if path == nil then
                        SendFile(Container.CurrentFile, false)
                        return
                end

                if type(path) ~= "string" or path == "" then
                        error("AddCSLuaFile expected a non-empty path", 2)
                end

                SendFile(ResolvePath(path, Container.CurrentFile, Container.BasePath), true)
        end

        function ENV.include(path)
                if type(path) ~= "string" or path == "" then
                        error("include expected a non-empty path", 2)
                end

                local CurrentFile = ResolvePath(path, Container.CurrentFile, Container.BasePath)

                local SourceCode = ReadFile(CurrentFile, "include")

                return RunFile(Container, CurrentFile, SourceCode)
        end

        function ENV.include_static(path)
                error("include_static requires a static string path, for example include_static(\"$RELATIVE/example.lua\")", 2)
        end

        function ENV.require(path)
                if type(path) ~= "string" or path == "" then
                        error("include expected a non-empty path", 2)
                end

                local CurrentFile = ResolvePath(path, Container.CurrentFile, Container.BasePath)

                if not RequireCache[CurrentFile] then
                        local SourceCode = ReadFile(CurrentFile, "include")

                        local Return = { RunFile(Container, CurrentFile, SourceCode) }

                        RequireCache[CurrentFile] = Return

                        return unpack(Return)
                else
                        return unpack(RequireCache[CurrentFile])
                end
        end

        function ENV.builtin.CurrentContainer()
                return Container
        end

        return ENV
end
