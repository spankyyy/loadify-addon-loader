AddCSLuaFile()

local ResolvePath = include("ecosystem/util/path_resolver.lua")

local function ReadFile(Path, Caller)
        local SourceCode = file.Read(Path, "LUA")
        if SourceCode == nil then
                error(string.format("%s could not read '%s'", Caller, Path), 2)
        end

        return SourceCode
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

                local Child = Container:CreateChild(CurrentFile, SourceCode)

                local Return = { Child:Process():Compile():Run() }

                return unpack(Return)
        end

        function ENV.builtin.CurrentContainer()
                return Container
        end

        return ENV
end
