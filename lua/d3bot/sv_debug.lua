-- #### Debug stuff ####

function GetPlayerByName(name)
	local name = string.lower(name)
	for _, v in ipairs(player.GetHumans()) do
		if(string.find(string.lower(v:Name()),name,1,true) ~= nil)
			then return v
		end
	end
end

ClDebugOverlay = {}
function ClDebugOverlay.Axis(player, origin, ang, size, lifetime, ignoreZ)
	local lifetime = lifetime or 1
	local ignoreZ = ignoreZ or false
	player:SendLua("debugoverlay.Axis(Vector("..origin.x..","..origin.y..","..origin.z.."), Angle("..ang.pitch..","..ang.yaw..","..ang.roll.."), "..size..", "..lifetime..", "..tostring(ignoreZ)..")")
end
function ClDebugOverlay.Box(player, origin, mins, maxs, lifetime, color)
	local lifetime = lifetime or 1
	local color = color or Color(255, 255, 255)
	player:SendLua("debugoverlay.Box(Vector("..origin.x..","..origin.y..","..origin.z.."), Vector("..mins.x..","..mins.y..","..mins.z.."), Vector("..maxs.x..","..maxs.y..","..maxs.z.."), "..lifetime..", Color("..color.r..", "..color.g..", "..color.b..", "..color.a.."))")
end
function ClDebugOverlay.Cross(player, position, size, lifetime, color, ignoreZ)
	local lifetime = lifetime or 1
	local color = color or Color(255, 255, 255)
	local ignoreZ = ignoreZ or false
	player:SendLua("debugoverlay.Cross(Vector("..position.x..","..position.y..","..position.z.."), "..size..", "..lifetime..", Color("..color.r..", "..color.g..", "..color.b..", "..color.a.."), "..tostring(ignoreZ)..")")
end
function ClDebugOverlay.EntityTextAtPosition(player, pos, line, text, lifetime, color)
	local lifetime = lifetime or 1
	local color = color or Color(255, 255, 255)
	player:SendLua("debugoverlay.EntityTextAtPosition(Vector("..pos.x..","..pos.y..","..pos.z.."), "..line..", \""..text.."\", "..lifetime..", Color("..color.r..", "..color.g..", "..color.b..", "..color.a.."))")
end
function ClDebugOverlay.Line(player, pos1, pos2, lifetime, color, ignoreZ)
	local lifetime = lifetime or 1
	local color = color or Color(255, 255, 255)
	local ignoreZ = ignoreZ or false
	player:SendLua("debugoverlay.Line(Vector("..pos1.x..","..pos1.y..","..pos1.z.."), Vector("..pos2.x..","..pos2.y..","..pos2.z.."), "..lifetime..", Color("..color.r..", "..color.g..", "..color.b..", "..color.a.."), "..tostring(ignoreZ)..")")
end
function ClDebugOverlay.Sphere(player, origin, size, lifetime, color, ignoreZ)
	local lifetime = lifetime or 1
	local color = color or Color(255, 255, 255)
	local ignoreZ = ignoreZ or false
	player:SendLua("debugoverlay.Sphere(Vector("..origin.x..","..origin.y..","..origin.z.."), "..size..", "..lifetime..", Color("..color.r..", "..color.g..", "..color.b..", "..color.a.."), "..tostring(ignoreZ)..")")
end

D3bot.Debug = {}
function D3bot.Debug.DrawPath(player, path, lifetime, color, ignoreZ)
	local oldPos
	for _, node in pairs(path) do
		local pos = node.Pos
		if pos and oldPos then
			ClDebugOverlay.Line(player, pos, oldPos, lifetime, color, ignoreZ)
		end
		oldPos = pos
	end
end

function D3bot.Debug.DrawNodeMetadata(player, nodeMetadata, lifetime, color)
	for node, metadata in pairs(nodeMetadata) do
		local pos = node.Pos
		ClDebugOverlay.EntityTextAtPosition(player, pos, 1, "ZDF = "..tostring(metadata.ZombieDeathFactor), lifetime, color)
		ClDebugOverlay.EntityTextAtPosition(player, pos, 2, "Survivors F. = "..tostring(metadata.PlayerFactorByTeam and metadata.PlayerFactorByTeam[TEAM_SURVIVOR]), lifetime, color)
		ClDebugOverlay.EntityTextAtPosition(player, pos, 3, "Undead F. = "..tostring(metadata.PlayerFactorByTeam and metadata.PlayerFactorByTeam[TEAM_UNDEAD]), lifetime, color)
	end
end