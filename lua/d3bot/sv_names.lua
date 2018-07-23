D3bot.Names = {"Bot"}

-- TODO: Make search path relative
if D3bot.BotNameFile then
	include("names/"..D3bot.BotNameFile..".lua")
end

local function getUsernames()
	local usernames = {}
	for k, v in pairs(player.GetAll()) do
		usernames[v:Nick()] = v
	end
	return usernames
end

local names = {}
function D3bot.GetUsername()
	local usernames = getUsernames()
	
	if #names == 0 then names = table.Copy(D3bot.Names) end
	local name = table.remove(names, math.random(#names))
	
	if usernames[name] then
		local number = 2
		while usernames[name.."("..number..")"] do
			number = number + 1
		end
		return name.."("..number..")"
	end
	return name
end