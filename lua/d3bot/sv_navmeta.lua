if not D3bot.UsingSourceNav then return end

local CNavLink = CNavLink or {}
CNavLink.__index = CNavLink

function CNavLink:new( areaA, areaB, initData )
	return setmetatable( {
		area_1 = areaA,
		area_2 = areaB,
		metaData = initData or {}
	}, CNavLink )
end

function CNavLink:GetMetaData()
	self.metaData = self.metaData or {}
	return self.metaData
end

function CNavLink:GetLinkedAreas()
	return self.area_1, self.area_2
end

setmetatable( CNavLink, { __call = CNavLink.new } )

D3bot.CNavLink = CNavLink

local CNavArea = FindMetaTable( "CNavArea" )

local NavAreaMetaData = NavAreaMetaData or {}
local NavAreaLinks = NavAreaLinks or {}

function CNavArea:GetMetaData()
	if not self:IsValid() then return { Params = {} } end
	NavAreaMetaData[ self:GetID() ] = NavAreaMetaData[ self:GetID() ] or {}
	return NavAreaMetaData[ self:GetID() ]
end

function CNavArea:CreateLink( area, data ) -- Not going to bother with a remove function, links won't be made unless necessary
	NavAreaLinks[ self:GetID() ] = NavAreaLinks[ self:GetID() ] or {}
	NavAreaLinks[ area:GetID() ] = NavAreaLinks[ area:GetID() ] or {}
	local areaLinksSelf = NavAreaLinks[ self:GetID() ]
	local areaLinksArea = NavAreaLinks[ area:GetID() ]
	local link = D3bot.CNavLink( self, area, data )
	areaLinksSelf[ #areaLinksSelf + 1 ] = link
	areaLinksArea[ #areaLinksArea + 1 ] = link
	NavAreaLinks[ self:GetID() ] = areaLinksSelf
	NavAreaLinks[ area:GetID() ] = areaLinksArea
	return link
end

function CNavArea:SharesLink( area )
	NavAreaLinks[ self:GetID() ] = NavAreaLinks[ self:GetID() ] or {}
	local areaLinks = NavAreaLinks[ self:GetID() ]
	for _, link in ipairs( areaLinks ) do
		local a1, a2 = link:GetLinkedAreas()
		if ( self == a1 or self == a2 ) and ( area == a1 or area == a2 ) then
			return link
		end
	end
	return false
end

hook.Add( "InitPostEntity", "D3bot.SetupNavLinks", function()
	if not D3bot.ValveNav then return end

	timer.Simple( 0.1, function()
		for _, area in pairs( navmesh.GetAllNavAreas() ) do
			for _, neighbor in pairs( area:GetAdjacentAreas() ) do
				if not area:SharesLink( neighbor ) and area:IsConnected( neighbor ) then
					local link = area:CreateLink( neighbor )
					local linkData = link:GetMetaData()
					linkData.Params = linkData.Params or {}

					if area:HasAttributes( NAV_MESH_WALK ) and neighbor:HasAttributes( NAV_MESH_WALK ) then
						linkData.Params.Walking = "Needed"
					end
					
					if area:HasAttributes( NAV_MESH_CLIFF + NAV_MESH_RUN ) then
						linkData.Params.Pouncing = "Needed"
					end
				end
			end

			local areaData = area:GetMetaData()
			areaData.Params = areaData.Params or {}

			if area:HasAttributes( NAV_MESH_CLIFF + NAV_MESH_OBSTACLE_TOP ) then
				areaData.Params.Climbing = "Needed"
			end

			if area:HasAttributes( NAV_MESH_JUMP ) then
				areaData.Params.Jump, areaData.Params.JumpTo = "Always"
			end

			if area:HasAttributes( NAV_MESH_NO_JUMP ) then
				areaData.Params.Jump, areaData.Params.JumpTo = "Disabled"
			end

			if area:HasAttributes( NAV_MESH_CROUCH ) then
				areaData.Params.Duck, areaData.Params.DuckTo = "Always"
			end

			if area:HasAttributes( NAV_MESH_STAND ) then
				areaData.Params.Duck, areaData.Params.DuckTo = "Disabled"
			end

			if area:HasAttributes( NAV_MESH_AVOID ) then
				areaData.Params.See = "Disabled"
			end

			if area:HasAttributes( NAV_MESH_DONT_HIDE ) then
				areaData.Params.Aim, areaData.Params.AimTo = "Straight"
			end

			if area:HasAttributes( NAV_MESH_FUNC_COST ) then
				areaData.Params.Cost = true -- This will just add weight during pathfinding
			end

			if area:HasAttributes( NAV_MESH_TRANSIENT ) then
				areaData.Params.Condition = "Unblocked"
			end

			if area:HasAttributes( NAV_MESH_NAV_BLOCKER ) then
				areaData.Params.Condition = "Blocked"
			end
		end
	end )
end )
