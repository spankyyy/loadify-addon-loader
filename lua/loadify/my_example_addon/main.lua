AddCSLuaFile()

-- The lexer must ignore this comment: include_static("missing-comment.lua")
local TextThatMentionsIncludeStatic = "include_static(\\\"missing-string.lua\\\")"
print("string", TextThatMentionsIncludeStatic)

-- Absolute paths start at this addon's root.
local AbsoluteFirst, AbsoluteSecond = include_static("$ABSOLUTE/example_folder/example_file.lua")
print("absolute", AbsoluteFirst, AbsoluteSecond)

-- Relative paths start at the current source file.
local RelativeFirst, RelativeSecond = include_static(
	"$RELATIVE/example_folder/example_file.lua"
)
print("relative", RelativeFirst, RelativeSecond)

-- A single return value remains a normal local assignment.
local SingleValue = include_static("$RELATIVE/example_folder/single_value.lua")
print("single", SingleValue)

-- Imported files can import another file relative to themselves.
local NestedFirst, NestedSecond = include_static("$RELATIVE/example_folder/example_file.lua")
print("nested", NestedFirst, NestedSecond)

-- A standalone call is allowed when the return value is not needed.
include_static("$RELATIVE/example_folder/side_effect.lua")
