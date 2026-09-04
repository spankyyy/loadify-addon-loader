AddCSLuaFile()

local function Normalize(Path)
	local Parts = {}
	Path = Path:gsub("\\", "/"):gsub("/+", "/")

	for Part in Path:gmatch("[^/]+") do
		if Part == ".." then
			if #Parts > 0 then table.remove(Parts) end
		elseif Part ~= "." then
			table.insert(Parts, Part)
		end
	end

	return table.concat(Parts, "/")
end

local function Directory(Path)
	return Path:match("^(.*)/") or ""
end

return function(Path, CurrentFile, BasePath)
	if type(Path) ~= "string" then return nil end

	if Path:sub(1, 10) == "$RELATIVE/" then
		return Normalize(Directory(CurrentFile or "") .. "/" .. Path:sub(11))
	elseif Path:sub(1, 10) == "$ABSOLUTE/" then
		return Normalize((BasePath or "") .. "/" .. Path:sub(11))
	end

	return Normalize((BasePath or "") .. "/" .. Path)
end
