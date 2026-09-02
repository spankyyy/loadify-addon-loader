AddCSLuaFile()

local Class, Meta = {}, {}
setmetatable(Class, Meta)

function Meta.__call(self, Args)
        local Instance = table.Copy(self)

        setmetatable(Instance, {
                __tostring = function(self)
                        return self:ToString()
                end
        })

        Instance:Initialize(Args)

        Instance.Initialize = nil
        Instance.Extend = nil

        return Instance
end

function Class:Initialize(_) end

function Class:ToString()
        return string.format("%s: %p",
                self.__CLASSNAME,
                self
        )
end

function Class:Extend(ClassName)
        local NewClass = table.Copy(self)

        NewClass.__CLASSNAME = ClassName
        return NewClass
end

function Class:Is(OtherClass)
        return self.__CLASSNAME == OtherClass.__CLASSNAME
end

return Class
