-- Just some test. TODO: Make it work

D3bot.Names = {}

-- TODO: Make search path relative
for i, filename in pairs(file.Find("d3bot/names/*.lua", "LUA")) do
	include("names/"..filename)
end

local names = D3bot.Names.FNG_UserNames

local meta = FindMetaTable("Player")
D3bot.OldNick = OldNick or meta.Nick
local oldNick = D3bot.OldNick
function meta:Nick()
	if self:IsBot() then
		self.D3bot_FakeName = self.D3bot_FakeName or table.Random(names)
		return self.D3bot_FakeName
	end
	return oldNick(self)
end

meta.Name = meta.Nick
meta.GetName = meta.Nick