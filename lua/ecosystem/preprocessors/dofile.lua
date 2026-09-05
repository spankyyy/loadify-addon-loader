AddCSLuaFile()

local ResolvePath = include("ecosystem/util/path_resolver.lua")
local IncludeStaticDepth = 0
local MaxIncludeStaticDepth = 32

local function IsIdentifierStart(Character)
	return Character and Character:match("[%a_]") ~= nil
end

local function IsIdentifierPart(Character)
	return Character and Character:match("[%w_]") ~= nil
end

local function ReadLongString(SourceCode, Position)
	local Equals = SourceCode:match("^%[(=*)%[", Position)
	if Equals == nil then return nil end

	local Closing = "]" .. Equals .. "]"
	local End = SourceCode:find(Closing, Position + #Equals + 2, true)
	return End and End + #Closing - 1 or #SourceCode
end

local function Lex(SourceCode)
	local Tokens = {}
	local Position = 1
	local Length = #SourceCode

	while Position <= Length do
		local Character = SourceCode:sub(Position, Position)
		local NextCharacter = SourceCode:sub(Position + 1, Position + 1)

		if Character:match("%s") then
			Position = Position + 1
		elseif Character == "-" and NextCharacter == "-" then
			local LongEnd = ReadLongString(SourceCode, Position + 2)
			if LongEnd then
				Position = LongEnd + 1
			else
				local Newline = SourceCode:find("\n", Position + 2, true)
				Position = Newline or Length + 1
			end
		elseif Character == "[" then
			local LongEnd = ReadLongString(SourceCode, Position)
			if LongEnd then
				table.insert(Tokens, { type = "string", value = SourceCode:sub(Position, LongEnd), start = Position, finish = LongEnd })
				Position = LongEnd + 1
			else
				table.insert(Tokens, { type = "symbol", value = Character, start = Position, finish = Position })
				Position = Position + 1
			end
		elseif Character == "\"" or Character == "'" then
			local Quote = Character
			local End = Position + 1
			while End <= Length do
				if SourceCode:sub(End, End) == "\\" then
					End = End + 2
				elseif SourceCode:sub(End, End) == Quote then
					break
				else
					End = End + 1
				end
			end
			table.insert(Tokens, { type = "string", value = SourceCode:sub(Position, End), start = Position, finish = End })
			Position = End + 1
		elseif IsIdentifierStart(Character) then
			local End = Position + 1
			while IsIdentifierPart(SourceCode:sub(End, End)) do End = End + 1 end
			table.insert(Tokens, { type = "identifier", value = SourceCode:sub(Position, End - 1), start = Position, finish = End - 1 })
			Position = End
		else
			table.insert(Tokens, { type = "symbol", value = Character, start = Position, finish = Position })
			Position = Position + 1
		end
	end

	return Tokens
end

local function GetIncludeStaticAssignment(SourceCode, Tokens, Index)
	local Open = Tokens[Index + 1]
	local Path = Tokens[Index + 2]
	local Close = Tokens[Index + 3]
	local Equals = Tokens[Index - 1]

	if not Open or Open.value ~= "(" or not Path or Path.type ~= "string" or not Close or Close.value ~= ")" then
		return nil
	end

	local PathValue = Path.value
	local LongEquals = PathValue:match("^%[(=*)%[")
	if LongEquals then
		PathValue = PathValue:sub(3 + #LongEquals, -(2 + #LongEquals))
	else
		PathValue = PathValue:sub(2, -2)
	end

	if not Equals or Equals.value ~= "=" then
		local Previous = Tokens[Index - 1]
		local Next = Tokens[Index + 4]
		local Before = Previous and SourceCode:sub(Previous.finish + 1, Tokens[Index].start - 1) or SourceCode:sub(1, Tokens[Index].start - 1)
		local After = Next and SourceCode:sub(Close.finish + 1, Next.start - 1) or SourceCode:sub(Close.finish + 1)
		if Previous and not Before:find("[\r\n]") then return nil end
		if Next and not After:find("[\r\n;]") then return nil end

		return {
			start = Tokens[Index].start,
			finish = Close.finish,
			path = PathValue,
			variables = nil,
			localDeclaration = false
		}
	end

	local Variables = {}
	local VariableIndex = Index - 2
	while VariableIndex >= 1 do
		local Variable = Tokens[VariableIndex]
		if not Variable or Variable.type ~= "identifier" then break end
		table.insert(Variables, 1, Variable.value)
		VariableIndex = VariableIndex - 1
		if not Tokens[VariableIndex] or Tokens[VariableIndex].value ~= "," then break end
		VariableIndex = VariableIndex - 1
	end

	if #Variables == 0 then return nil end

	local IsLocal = Tokens[VariableIndex] and Tokens[VariableIndex].value == "local"
	local Start = Tokens[IsLocal and VariableIndex or VariableIndex + 1]
	if not Start then return nil end

	return {
		start = Start.start,
		finish = Close.finish,
		path = PathValue,
		variables = table.concat(Variables, ", "),
		localDeclaration = IsLocal
	}
end

local function ReplaceTopLevelReturn(SourceCode, Variables)
	local Tokens = Lex(SourceCode)
	local Blocks = {}

	for _, Token in ipairs(Tokens) do
		if Token.value == "function" or Token.value == "do" or Token.value == "repeat" then
			table.insert(Blocks, Token.value)
		elseif Token.value == "then" and Blocks[#Blocks] == "pending-if" then
			Blocks[#Blocks] = "if"
		elseif Token.value == "if" then
			table.insert(Blocks, "pending-if")
		elseif Token.value == "end" then
			table.remove(Blocks)
		elseif Token.value == "until" and Blocks[#Blocks] == "repeat" then
			table.remove(Blocks)
		elseif Token.value == "return" and #Blocks == 0 then
			local Expression = SourceCode:sub(Token.finish + 1)
			Expression = Expression:gsub("^%s+", ""):gsub("%s+$", ""):gsub(";%s*$", "")
			local Prefix = SourceCode:sub(1, Token.start - 1)
			if Variables and Expression ~= "" then
				return Prefix .. Variables .. " = " .. Expression
			end
			return Prefix
		end
	end

	return SourceCode
end

local function InlineFile(Container, Assignment)
	local ResolvedPath = ResolvePath(Assignment.path, Container.CurrentFile, Container.BasePath)
	if IncludeStaticDepth >= MaxIncludeStaticDepth then
		error(string.format(
			"include_static preprocessing limit (%d) reached while loading '%s'",
			MaxIncludeStaticDepth,
			ResolvedPath
		), 2)
	end

	local SourceCode = file.Read(ResolvedPath, "LUA")
	if not SourceCode then error("include_static could not read '" .. ResolvedPath .. "'") end

	IncludeStaticDepth = IncludeStaticDepth + 1
	local Success, ProcessedSource = pcall(function()
		local Child = Container:CreateChild(ResolvedPath, SourceCode)
		return Child:Process():GetCode()
	end)
	IncludeStaticDepth = IncludeStaticDepth - 1

	if not Success then error(ProcessedSource, 2) end
	SourceCode = ProcessedSource
	SourceCode = ReplaceTopLevelReturn(SourceCode, Assignment.variables)

	local Block = { "do", SourceCode, "end" }
	if Assignment.localDeclaration then table.insert(Block, 1, "local " .. Assignment.variables) end
	return table.concat(Block, "\n")
end

return function(SourceCode, Container)
	local Tokens = Lex(SourceCode)
	local Replacements = {}

	for Index, Token in ipairs(Tokens) do
		if Token.value == "include_static" then
			local Assignment = GetIncludeStaticAssignment(SourceCode, Tokens, Index)
			if Assignment then
				table.insert(Replacements, {
					start = Assignment.start,
					finish = Assignment.finish,
					replacement = InlineFile(Container, Assignment)
				})
			end
		end
	end

	for Index = #Replacements, 1, -1 do
		local Replacement = Replacements[Index]
		SourceCode = SourceCode:sub(1, Replacement.start - 1) .. Replacement.replacement .. SourceCode:sub(Replacement.finish + 1)
	end

	return SourceCode
end
