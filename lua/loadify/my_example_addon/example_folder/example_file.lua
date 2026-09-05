AddCSLuaFile()

-- This nested include_static uses the directory of this file as its base.
local NestedValue, NestedLabel = include_static("$RELATIVE/nested_values.lua")

local function ReturnFromInsideAFunction()
	return "this return must stay inside the function"
end

return 1 + NestedValue, NestedLabel
