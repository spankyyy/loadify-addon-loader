AddCSLuaFile()

return function(Container)
        local ENV = {}
        ENV.builtin = {}

        ENV.PrintTable = PrintTable
        ENV.print = print

        function ENV.AddCSLuaFile(path)
                if path == nil then
                        AddCSLuaFile(Container.CurrentFile)
                        return
                end
                AddCSLuaFile(Container.BasePath .. "/" .. path)
        end

        function ENV.include(path)
                local AbsoluteParent = Container.AbsoluteParent

                local OldCurrentFile = AbsoluteParent.CurrentFile
                AbsoluteParent.CurrentFile = Container.BasePath .. "/" .. path

                local SourceCode = file.Read(AbsoluteParent.CurrentFile, "LUA")

                local Child = Container:CreateChild(path, SourceCode)

                local Return = { Child:Process():Compile():Run() }

                AbsoluteParent.CurrentFile = OldCurrentFile

                return unpack(Return)
        end

        function ENV.builtin.CurrentContainer()
                return Container
        end

        return ENV
end
