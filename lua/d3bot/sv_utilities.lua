function D3bot.D3botNavAvailableAndActive()
	-- D3bot navmesh is loaded by default at start, so there will always be a navmesh.
	-- Check if there are any navmesh entities.
	return table.Count(D3bot.MapNavMesh.ItemById) > 0
end

function D3bot.SourceNavAvailableAndActive()
	-- Check if it is enabled by config.
	if not D3bot.ValveNav then return false end

	-- Check if there is a source nav file.
	if not file.Exists("maps/" .. game.GetMap() .. ".nav", "GAME") then return false end

	-- Check if the newer bots are used.
	if D3bot.UseConsoleBots then return false end

	return true
end

-- DesiredNavmeshType returns a string that defines the desired type of navmesh.
function D3bot.DesiredNavmeshType()
	-- D3bot navmesh is available and enabled for the current map.
	local d3botNav = D3bot.D3botNavAvailableAndActive()

	-- Source navmesh is available and enabled for the current map.
	local sourceNav = D3bot.SourceNavAvailableAndActive()

	-- By default, D3bot navmeshes have higher priority.
	local type = (d3botNav and "D3botNav") or (sourceNav and "SourceNav") or ""

	-- If override is set, always use source navmesh if available.
	if D3bot.ValveNavOverride and sourceNav then
		--print(string.format("D3bot: Overriding navmesh type %q with %q, as requested in sv_config.lua.", type, "SourceNav"))
		type = "SourceNav"
	end

	return type
end

-- IsEnabled returns whether the whole bot logic will be active or not.
function D3bot.IsEnabled()
	if engine.ActiveGamemode() ~= "zombiesurvival" then return false end

	-- Check if there is a desired navmesh type.
	local navmeshType = D3bot.DesiredNavmeshType()
	if navmeshType == "" then return false end

	return true
end

-- Evaluate states once, and cache them.
D3bot.IsEnabledCached = D3bot.IsEnabled()
D3bot.DesiredNavmeshTypeCached = D3bot.DesiredNavmeshType()

-- Outputting what navmesh we will use.
if D3bot.DesiredNavmeshTypeCached ~= "" then
	print(string.format("D3bot: Using navmesh type %q.", D3bot.DesiredNavmeshTypeCached))
else
	print(string.format("D3bot: No navmesh available."))
end

-- Also enabling and loading source navmeshes if desired.
if D3bot.DesiredNavmeshTypeCached == "SourceNav" then
	D3bot.UsingSourceNav = true -- Enable source navmeshes globally. When enabled, this will override a lot of stuff.

	hook.Add("InitPostEntity", "D3bot.LoadValveNavMesh", function()
		navmesh.Load()
	end)
end
