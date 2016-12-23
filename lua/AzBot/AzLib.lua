
local lib = {}

local consoleErrorColor = Color(255, 75, 0)
function lib.LogError(msg) MsgC(consoleErrorColor, "Error: " .. msg .. "\n") end

function lib.TryCatch(func, error)
	local didNotError, errorMsg = xpcall(func, debug.traceback)
	if not didNotError then error(errorMsg) end
end

function lib.TwoWay(a, b, func)
	func(a, b)
	func(b, a)
end

function lib.WriteOrAdd(tbl, k, v) if k == nil then table.insert(tbl, v) else tbl[k] = v end end

lib.SortedQueueMeta = { __index = {} }
local sortedQueueFallback = lib.SortedQueueMeta.__index
function lib.NewSortedQueue(func)
	return setmetatable({
		Set = {},
		Func = func }, lib.SortedQueueMeta)
end
function sortedQueueFallback:Enqueue(item)
	if self.Set[item] then return end
	self.Set[item] = true
	for idx, v in ipairs(self) do if self.Func(item, v) then return table.insert(self, idx, item) end end
	return table.insert(self, item)
end
function sortedQueueFallback:Dequeue()
	local item = table.remove(self)
	self.Set[item] = nil
	return item
end

function lib.SplitStr(str, separator) return str == "" and {} or str:Split(separator) end

function lib.Send(...) (SERVER and net.Send or net.SendToServer)(...) end

lib.QueryMeta = { __index = {} }
local queryFallback = lib.QueryMeta.__index
function lib.From(v) return setmetatable({ R = v }, lib.QueryMeta) end
local from = lib.From
function queryFallback:ShallowCopy()
	local r = {}
	for k, v in pairs(self.R) do r[k] = v end
	self.R = r
	return self
end
function queryFallback:Len()
	local len = 0
	for k, v in ipairs(self.R) do len = len + 1 end
	self.R = len
	return self
end
function queryFallback:Ks()
	local r = {}
	for k, v in pairs(self.R) do table.insert(r, k) end
	self.R = r
	return self
end
function queryFallback:Select(func)
	local r = {}
	for k, v in pairs(self.R) do lib.WriteOrAdd(r, func(k, v)) end
	self.R = r
	return self
end
function queryFallback:SelectV(func)
	local r = {}
	for k, v in pairs(self.R) do r[k] = func(v) end
	self.R = r
	return self
end
function queryFallback:Where(func)
	local r = {}
	for k, v in pairs(self.R) do if func(k, v) then r[k] = v end end
	self.R = r
	return self
end
function queryFallback:Sort(funcOrNil)
	self:ShallowCopy()
	table.sort(self.R, funcOrNil or function(a, b) return a < b end)
	return self
end
function queryFallback:Reverse(func)
	local r = {}
	for k, v in ipairs(self.R) do table.insert(r, 1, v) end
	self.R = r
	return self
end
function queryFallback:ValuesSet()
	local r = {}
	for k, v in ipairs(self.R) do r[v] = true end
	self.R = r
	return self
end
function queryFallback:Join(separator)
	self.R = string.Implode(separator, self.R)
	return self
end

lib.Color = {}
lib.Color.Black = Color(0, 0, 0)
lib.Color.White = Color(255, 255, 255)
lib.Color.Red = Color(255, 0, 0)
lib.Color.Orange = Color(255, 128, 0)
lib.Color.Yellow = Color(255, 255, 0)
lib.Color.Green = Color(0, 150, 0)
for name, color in pairs(lib.Color) do
	color.HalfAlpha = ColorAlpha(color, 128)
	color.EightAlpha = ColorAlpha(color, 32)
end

function lib.GetViewCenter(pl) return pl:GetPos() + (pl:Crouching() and pl:GetViewOffsetDucked() or pl:GetViewOffset()) end

local filePath = debug.getinfo(1, "S").short_src
for idx, relFilePath in ipairs(from(file.Find(filePath:GetPathFromFilename() .. "*.lua", "GAME")):Sort().R) do
	if relFilePath:lower() ~= filePath:GetFileFromFilename() then
		local extensionlessRelFilePath = relFilePath:StripExtension()
		local isServerFile = extensionlessRelFilePath:EndsWith("_sv")
		local isClientFile = extensionlessRelFilePath:EndsWith("_cl")
		if not (isServerFile or isClientFile) then
			isServerFile = true
			isClientFile = true
		end
		if SERVER and isClientFile then AddCSLuaFile(relFilePath) end
		if (SERVER and isServerFile) or (CLIENT and isClientFile) then
			local func = include(relFilePath)
			if func then func(lib) end
		end
	end
end

return function(globalK)
	if lib.IsInitialized then error("Do not initialize twice.", 2) end
	_G[globalK] = lib
	lib.GlobalK = globalK
	lib.IsInitialized = true
end
