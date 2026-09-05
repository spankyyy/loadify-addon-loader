AddCSLuaFile()

-- Long strings can contain include_static text without triggering the lexer.
local SourceText = [=[include_static("missing-long-string.lua")]=]

return 2, "nested values loaded"
