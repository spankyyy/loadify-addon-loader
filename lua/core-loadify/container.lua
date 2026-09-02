AddCSLuaFile()

local Class = include("lua/core-loadify/class.lua")
local LuaContainer = Class:Extend("LuaContainer")

function LuaContainer:Initialize(_)
        self.Name = string.format("LuaContainer: %p", self)
        self.CompiledFunction = function() end
        self.SourceCode = " "
        self.Code = nil
        self.ENV = {}
        self.Processors = {}
end

function LuaContainer:SetName(Name)
        self.Name = Name

        return self
end

function LuaContainer:GetName()
        return self.Name
end

function LuaContainer:SetEnvironment(ENV)
        self.ENV = ENV

        return self
end

function LuaContainer:AddToEnvironment(Value)
        table.insert(self.ENV, Value)

        return self
end

function LuaContainer:GetEnvironment()
        return self.ENV
end

function LuaContainer:AddProcessor(Processor)
        table.insert(self.Processors, Processor)

        return self
end

function LuaContainer:SetProcessors(Processors)
        self.Processors = Processors

        return self
end

function LuaContainer:GetProcessors()
        return self.Processors
end

function LuaContainer:Process()
        local Code = self.SourceCode

        for i = 1, #self.Processors do
                Code = self.Processors[i](Code, self)
        end

        self.Code = Code

        return self
end

function LuaContainer:Compile()
        self.ENV._G = self.ENV._G or self.ENV

        local Compiled = CompileString(self.Code or self.SourceCode, self.Name, true) or function() end
        self.CompiledFunction = Compiled

        setfenv(self.CompiledFunction, self.ENV)

        return self
end

function LuaContainer:SetSourceCode(Code)
        self.SourceCode = Code
        self.Code = nil

        return self
end

function LuaContainer:GetSourceCode()
        return self.SourceCode
end

function LuaContainer:GetCode()
        return self.Code
end

function LuaContainer:Run()
        local ok, error = pcall(self.CompiledFunction)
end

function LuaContainer:CreateChild(Name, Code)
        local Child = LuaContainer {}

        Child:SetName(Name)
        Child:SetEnvironment(self:GetEnvironment())
        Child:SetProcessors(self:GetProcessors())
        Child:SetSourceCode(Code)

        return Child
end

return LuaContainer
