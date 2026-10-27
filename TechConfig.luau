local TechConfig = {}

TechConfig.StartMoney = 600
TechConfig.FreeBuildBudget = 550   -- ships costing this much or less are free (so you can never get stuck)
TechConfig.XPReward = { Base = 30, PerCost = 0.15, PlayerMultiplier = 1.5 } -- XP = Base + shipCost * PerCost

TechConfig.Territory = {
	CaptureSeconds = 12,
	OilTickSeconds = 5,
	OilIncomePerDeposit = 15,
}

TechConfig.Categories = { "Core", "Armor", "Weapon", "Engine" }

-- Researching a tech unlocks every ship part that uses it (see ShipParts)
TechConfig.Techs = {
	{ Id = "Core1", Category = "Core", Name = "Core Mk1", XPCost = 0 },
	{ Id = "Core2", Category = "Core", Name = "Core Mk2", XPCost = 2000,  Requires = "Core1" },
	{ Id = "Core3", Category = "Core", Name = "Core Mk3", XPCost = 500000, Requires = "Core2" },

	{ Id = "Wood",     Category = "Armor", Name = "Wooden Plating",  XPCost = 0 },
	{ Id = "Iron",     Category = "Armor", Name = "Iron Plating",    XPCost = 250, Requires = "Wood" },
	{ Id = "Steel",    Category = "Armor", Name = "Steel Plating",   XPCost = 1000, Requires = "Iron" },
	{ Id = "Titanium", Category = "Armor", Name = "Titanium Armor",  XPCost = 2500, Requires = "Steel" },

	{ Id = "Cannon1", Category = "Weapon", Name = "Light Cannon",    XPCost = 0 },
	{ Id = "Auto",    Category = "Weapon", Name = "Autocannon",      XPCost = 500,  Requires = "Cannon1" },
	{ Id = "Cannon2", Category = "Weapon", Name = "Heavy Cannon",    XPCost = 1000,  Requires = "Cannon1" },
	{ Id = "Missile", Category = "Weapon", Name = "Missile Launcher", XPCost = 3000,  Requires = "Cannon2" },
	{ Id = "Rail",    Category = "Weapon", Name = "Railgun",         XPCost = 7500, Requires = "Missile" },

	{ Id = "Paddle",  Category = "Engine", Name = "Paddle Wheel",    XPCost = 0 },
	{ Id = "Diesel",  Category = "Engine", Name = "Diesel Engine",   XPCost = 750,  Requires = "Paddle" },
	{ Id = "Turbine", Category = "Engine", Name = "Gas Turbine",     XPCost = 1500,  Requires = "Diesel" },
	{ Id = "Reactor", Category = "Engine", Name = "Reactor Drive",   XPCost = 3000, Requires = "Turbine" },

	{ Id = "Helm", Category = "Misc", Name = "Helm", XPCost = 0 },
}

TechConfig.ById = {}
for _, t in ipairs(TechConfig.Techs) do
	TechConfig.ById[t.Id] = t
end

return TechConfig