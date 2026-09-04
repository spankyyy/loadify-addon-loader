AddCSLuaFile()

local ResolvePath = include("ecosystem/util/path_resolver.lua")

local function InlineFile(Container, Path, Variable, Indent)
	if type(Path) ~= "string" or Path == "" then
		error("dofile expected a non-empty path", 2)
	end

	local ResolvedPath = ResolvePath(Path, Container.CurrentFile, Container.BasePath)
	local SourceCode = file.Read(ResolvedPath, "LUA")
	if not SourceCode then error("dofile could not read '" .. ResolvedPath .. "'") end
	local Child = Container:CreateChild(ResolvedPath, SourceCode)
	SourceCode = Child:Process():GetCode()

	local Lines = {}
	for Line in (SourceCode .. "\n"):gmatch("(.-)\n") do
		local ReturnValue = Line:match("^%s*return%s+(.+)%s*$")
		if ReturnValue and Variable then
			table.insert(Lines, Indent .. Variable .. " = " .. ReturnValue)
		elseif not ReturnValue then
			table.insert(Lines, Indent .. Line)
		end
	end

	local Block = { Indent .. "do", table.concat(Lines, "\n"), Indent .. "end" }
	if Variable then table.insert(Block, 1, Indent .. "local " .. Variable) end
	return table.concat(Block, "\n")
end

return function(SourceCode, Container)
	local Output = {}
	for Line in (SourceCode .. "\n"):gmatch("(.-)\n") do
		local Indent = Line:match("^(%s*)") or ""
		local Variable, Path = Line:match("^%s*local%s+([%w_]+)%s*=%s*dofile%s*%(%s*[\"']([^\"']+)[\"']%s*%)%s*$")
		local AssignmentVariable, AssignmentPath = Line:match("^%s*([%w_]+)%s*=%s*dofile%s*%(%s*[\"']([^\"']+)[\"']%s*%)%s*$")
		local StandalonePath = Line:match("^%s*dofile%s*%(%s*[\"']([^\"']+)[\"']%s*%)%s*$")

		if Variable then
			table.insert(Output, InlineFile(Container, Path, Variable, Indent))
		elseif AssignmentVariable then
			table.insert(Output, InlineFile(Container, AssignmentPath, AssignmentVariable, Indent))
		elseif StandalonePath then
			table.insert(Output, InlineFile(Container, StandalonePath, nil, Indent))
		else
			table.insert(Output, Line)
		end
	end
	return table.concat(Output, "\n")
end
