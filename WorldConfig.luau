local WorldConfig = {}

WorldConfig.WorldSize = 9000 -- the sea is built from a grid of tiles (see MapBuilder)

-- enemy territory of tier N sits this far from the harbor (tier 1 closest, tier 7 farthest)
WorldConfig.TierRadius = { 1000, 1500, 2000, 2500, 3000, 3500, 4000 }
WorldConfig.TierAngle  = { -20, 18, -14, 20, -16, 14, 0 } -- degrees, spreads territories inside each sector

WorldConfig.Harbor = {
	Name = "Home Harbor",
	Radius = 230,       -- safe zone: nobody can be damaged, enemies ignore you
	IslandRadius = 85,
	Deposits = 2,
	OilIncome = 8,      -- per deposit per tick, paid to EVERY player
}

WorldConfig.Pirates = { Key = "Pirates", Name = "Pirates", Color = Color3.fromRGB(70, 70, 75) }

WorldConfig.FactionOrder = { "Armada", "Corsairs", "Dominion", "Syndicate" }

WorldConfig.Factions = {
	Armada = {
		Key = "Armada", Name = "Iron Armada", Color = Color3.fromRGB(205, 65, 55), Sector = 45,
		Names = { "Forge Point", "Anvil Reef", "Ironclad Bay", "Bulwark Isle", "Cannonade Cay", "Dreadnought Rock", "Armada Citadel" },
	},
	Corsairs = {
		Key = "Corsairs", Name = "Jade Corsairs", Color = Color3.fromRGB(60, 190, 100), Sector = 135,
		Names = { "Jade Cove", "Marauder's Rest", "Tradewind Isle", "Reaver Bay", "Siren's Landing", "Typhoon Keep", "Corsair Crown" },
	},
	Dominion = {
		Key = "Dominion", Name = "Solar Dominion", Color = Color3.fromRGB(245, 195, 60), Sector = 225,
		Names = { "Sunspire", "Dawn Beacon", "Gilded Shoal", "Helios Reach", "Aurora Bastion", "Zenith Isle", "Solar Throne" },
	},
	Syndicate = {
		Key = "Syndicate", Name = "Void Syndicate", Color = Color3.fromRGB(150, 90, 230), Sector = 315,
		Names = { "Shadow Cay", "Veil Rock", "Nightfall Atoll", "Obsidian Reef", "Phantom Isle", "Eclipse Hold", "Void Citadel" },
	},
}

function WorldConfig.GetTerritories()
	local list = {}
	for _, fk in ipairs(WorldConfig.FactionOrder) do
		local f = WorldConfig.Factions[fk]
		for t = 1, 7 do
			local ang = math.rad(f.Sector + WorldConfig.TierAngle[t])
			local r = WorldConfig.TierRadius[t]
			table.insert(list, {
				Name = f.Names[t], Faction = fk, Tier = t,
				Pos = Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r),
				Deposits = 1 + (t >= 3 and 1 or 0) + (t >= 5 and 1 or 0),
				Income = 12 + t * 6,
			})
		end
	end
	return list
end

return WorldConfig