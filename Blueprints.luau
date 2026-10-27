local ShipParts = require(script.Parent:WaitForChild("ShipParts"))

local Blueprints = {}

-- =====================================================================================
-- 1) ORIGINAL GENERATOR (the player's free starter ship uses AI(1))
-- =====================================================================================
local TIERS = {
	[1] = { HW = 1, Len = 7,  Armor = "Wood",     Core = "Core1", Engine = "Paddle",  EngineX = { 0 },      HelmZ = 1,
		Deck = { { "Cannon1", 0, -2 } } },
	[2] = { HW = 1, Len = 9,  Armor = "Iron",     Core = "Core1", Engine = "Diesel",  EngineX = { 0 },      HelmZ = 1,
		Deck = { { "Cannon1", 0, -3 }, { "Auto", 0, 2 } } },
	[3] = { HW = 2, Len = 11, Armor = "Steel",    Core = "Core2", Engine = "Turbine", EngineX = { -1, 1 }, HelmZ = 2,
		Deck = { { "Cannon2", -2, -3 }, { "Cannon2", 1, -3 }, { "Auto", 0, -3 }, { "Auto", 0, 3 } } },
	[4] = { HW = 2, Len = 15, Armor = "Titanium", Core = "Core3", Engine = "Reactor", EngineX = { -1, 1 }, HelmZ = 3,
		Deck = { { "Missile", -2, -5 }, { "Missile", 1, -5 }, { "Cannon2", -2, -3 }, { "Cannon2", 1, -3 }, { "Auto", 0, -4 }, { "Auto", 0, 4 } } },
}

function Blueprints.Generate(cfg)
	local list, occ = {}, {}
	local function add(id, x, y, z, r)
		r = r or 0
		local cells = ShipParts.Footprint(ShipParts.ById[id], x, y, z, r)
		for _, c in ipairs(cells) do
			if occ[ShipParts.Key(c[1], c[2], c[3])] then return end
		end
		for _, c in ipairs(cells) do occ[ShipParts.Key(c[1], c[2], c[3])] = true end
		table.insert(list, { Id = id, X = x, Y = y, Z = z, R = r })
	end

	local half = (cfg.Len - 1) // 2
	local hw = cfg.HW

	add(cfg.Core, 0, 1, 0)
	for _, ex in ipairs(cfg.EngineX) do add(cfg.Engine, ex, 1, half - 1) end
	add("Helm", 0, 2, cfg.HelmZ)
	for _, w in ipairs(cfg.Deck) do add(w[1], w[2], 2, w[3], w[4]) end
	add(cfg.Armor .. "_Block", 0, 2, 0)

	local wb = math.min(1, hw)
	for x = -wb, wb do add(cfg.Armor .. "_Wedge", x, 2, -half, 0) end

	for y = 0, 1 do
		for k = 0, cfg.Len - 1 do
			local z = -half + k
			local w = math.min(k + 1, hw)
			for x = -w, w do
				if k < hw and math.abs(x) == w then
					add(cfg.Armor .. "_Corner", x, y, z, x < 0 and 0 or 3)
				else
					add(cfg.Armor .. "_Block", x, y, z, 0)
				end
			end
		end
	end
	return list
end

function Blueprints.AI(tier)
	return Blueprints.Generate(TIERS[tier] or TIERS[1])
end

-- =====================================================================================
-- 2) FACTION + PIRATE DESIGNS
-- =====================================================================================
local function K(x, y, z) return ShipParts.Key(x, y, z) end

local function newBuilder(armor)
	return { list = {}, occ = {}, armor = armor }
end

local function canPut(B, id, x, y, z, r)
	local def = ShipParts.ById[id]
	for _, c in ipairs(ShipParts.Footprint(def, x, y, z, r)) do
		if not ShipParts.InBounds(c[1], c[2], c[3]) or B.occ[K(c[1], c[2], c[3])] then return false end
	end
	return true
end

local function put(B, id, x, y, z, r)
	r = r or 0
	if not canPut(B, id, x, y, z, r) then return false end
	local def = ShipParts.ById[id]
	for _, c in ipairs(ShipParts.Footprint(def, x, y, z, r)) do B.occ[K(c[1], c[2], c[3])] = true end
	table.insert(B.list, { Id = id, X = x, Y = y, Z = z, R = r })
	return true
end

local function armorAt(B, shape, x, y, z, r)
	return put(B, B.armor .. "_" .. shape, x, y, z, r or 0)
end

-- every cell under the part must already be occupied (no floating guns)
local function supported(B, id, x, y, z, r)
	local def = ShipParts.ById[id]
	for _, c in ipairs(ShipParts.Footprint(def, x, y, z, r)) do
		if not B.occ[K(c[1], c[2] - 1, c[3])] then return false end
	end
	return true
end

local function engineXs(n)
	if n == 1 then return { 0 } elseif n == 2 then return { -1, 1 } end
	return { -2, 0, 2 }
end

local function widthAt(cfg, k)
	if cfg.Bow == "blunt" then return cfg.HW end
	if cfg.Bow == "needle" then return math.min(k // 2 + 1, cfg.HW) end
	return math.min(k + 1, cfg.HW)
end

-- Solid hulls fill every cell; open hulls are a full floor + armored walls (keeps big ships under the block limit)
local function buildHull(B, cfg)
	local half = (cfg.Len - 1) // 2
	local prev = 0
	for k = 0, cfg.Len - 1 do
		local z = -half + k
		local w = widthAt(cfg, k)
		for y = 0, cfg.Layers - 1 do
			for x = -w, w do
				local edge = math.abs(x) == w
				if cfg.Solid or y == 0 or edge or k == 0 or k == cfg.Len - 1 then
					if edge and w > prev then
						armorAt(B, "Corner", x, y, z, x < 0 and 0 or 3)
					else
						armorAt(B, "Block", x, y, z, 0)
					end
				end
			end
		end
		prev = w
	end
end

local function wrapCore(B, cfg)
	if cfg.Citadel then
		for dx = -1, 1 do
			for dz = -1, 1 do
				for y = cfg.CoreY, cfg.CoreY + 1 do
					if not (dx == 0 and dz == 0 and y == cfg.CoreY) then armorAt(B, "Block", dx, y, dz, 0) end
				end
			end
		end
	end
	for _, d in ipairs(ShipParts.DIRS) do
		local y = cfg.CoreY + d[2]
		if y >= 0 then armorAt(B, "Block", d[1], y, d[3], 0) end
	end
end

-- mode "c" = centre line, "s" = a symmetric pair; k = rows from the bow
local function weaponAt(B, cfg, id, mode, k, e)
	local def = ShipParts.ById[id]
	local half = (cfg.Len - 1) // 2
	local z, y, sx = -half + k, cfg.DeckY, def.Size[1]
	if mode == "c" then
		if sx % 2 ~= 1 then return false end
		local x = -(sx // 2)
		if supported(B, id, x, y, z, 0) and canPut(B, id, x, y, z, 0) then
			return put(B, id, x, y, z, 0)
		end
		return false
	end
	local inset = cfg.Solid and 0 or 1
	local xr = math.max(1, cfg.HW - (sx - 1) - (e or 0) - inset)
	local xl = -(xr + sx - 1)
	if supported(B, id, xr, y, z, 0) and supported(B, id, xl, y, z, 0)
		and canPut(B, id, xr, y, z, 0) and canPut(B, id, xl, y, z, 0) then
		put(B, id, xr, y, z, 0)
		put(B, id, xl, y, z, 0)
		return true
	end
	return false
end

-- places weapons one after another from the bow towards the stern, skipping blocked rows
local function pack(B, cfg, plan)
	local k = 1
	for _, item in ipairs(plan) do
		local def = ShipParts.ById[item[1]]
		local placed = 0
		while placed < item[3] and k <= cfg.Len - 3 do
			if weaponAt(B, cfg, item[1], item[2], k, item[4]) then
				placed += 1
				k += def.Size[3] + 1
			else
				k += 1
			end
		end
	end
end

local function generate(cfg, plan)
	local B = newBuilder(cfg.Armor)
	local half = (cfg.Len - 1) // 2

	put(B, cfg.Core, 0, cfg.CoreY, 0, 0)
	for _, x in ipairs(engineXs(cfg.EngN)) do
		put(B, cfg.Engine, x, cfg.EngY, half - 1, 0)
	end
	buildHull(B, cfg)
	wrapCore(B, cfg)

	if cfg.BowWedge and cfg.Solid then
		for x = -1, 1 do
			if B.occ[K(x, cfg.DeckY - 1, -half)] then armorAt(B, "Wedge", x, cfg.DeckY, -half, 0) end
		end
	end

	local hz = math.max(1, (cfg.Len - 3) // 4)
	put(B, "Helm", 0, cfg.DeckY, hz, 0)
	if cfg.Cabin and cfg.Cabin > 0 then
		for _, c in ipairs({ { -1, 0 }, { 1, 0 }, { 0, 1 } }) do
			for h = 0, cfg.Cabin - 1 do armorAt(B, "Block", c[1], cfg.DeckY + h, hz + c[2], 0) end
		end
	end

	pack(B, cfg, plan)

	local hasWeapon = false
	for _, e in ipairs(B.list) do
		if ShipParts.ById[e.Id].Category == "Weapon" then hasWeapon = true break end
	end
	if not hasWeapon then -- safety: always carry at least one gun
		for k = 1, cfg.Len - 3 do
			if weaponAt(B, cfg, "Cannon1", "c", k, 0) then break end
		end
	end
	return B.list
end

local TIER = {
	{ Armor = "Wood",     Core = "Core1", Engine = "Paddle",  EngN = 1, HW = 1, Len = 7  },
	{ Armor = "Iron",     Core = "Core1", Engine = "Diesel",  EngN = 1, HW = 1, Len = 9  },
	{ Armor = "Steel",    Core = "Core2", Engine = "Turbine", EngN = 2, HW = 2, Len = 11 },
	{ Armor = "Titanium", Core = "Core3", Engine = "Reactor", EngN = 2, HW = 2, Len = 15 },
	{ Armor = "Titanium", Core = "Core3", Engine = "Reactor", EngN = 2, HW = 3, Len = 17 },
	{ Armor = "Titanium", Core = "Core3", Engine = "Reactor", EngN = 3, HW = 3, Len = 21 },
	{ Armor = "Titanium", Core = "Core3", Engine = "Reactor", EngN = 3, HW = 3, Len = 23 },
}

-- what makes each faction's ships look different (hull shape, bow, cabin)
local STYLE = {
	Armada = function(t, c) -- short, fat, blunt bow, tall conning tower
		if t == 3 or t == 4 then c.HW += 1 end
		if t >= 3 then c.Len -= 2 end
		c.Bow = "blunt"
		c.Cabin = t >= 3 and 3 or 0
	end,
	Corsairs = function(t, c) -- long, narrow, sharp needle bow
		if t >= 3 then c.HW = math.max(1, c.HW - 1) end
		if t >= 2 then c.Len = math.min(25, c.Len + 2) end
		c.Bow = "needle"
		c.BowWedge = true
	end,
	Dominion = function(t, c) -- very long, pointed bow, bridge tower
		if t >= 3 then c.Len = math.min(23, c.Len + 4) end
		c.Bow = "pointed"
		c.Cabin = t >= 3 and 2 or 0
		c.BowWedge = true
	end,
	Syndicate = function(t, c) -- sleek, low, needle bow
		if t >= 2 then c.Len = math.min(23, c.Len + 2) end
		c.Bow = "needle"
		c.BowWedge = true
	end,
}

-- weapon loadouts per tier: { id, mode, count, inset }
local PLANS = {
	Armada = {
		{ { "Cannon1", "c", 1 } },
		{ { "Cannon1", "c", 2 } },
		{ { "Cannon2", "s", 2 }, { "Auto", "c", 2 } },
		{ { "Cannon2", "s", 3 }, { "Auto", "c", 2 } },
		{ { "Cannon2", "s", 4 }, { "Missile", "s", 1, 1 }, { "Auto", "c", 2 } },
		{ { "Cannon2", "s", 5 }, { "Missile", "s", 2, 1 }, { "Auto", "c", 2 } },
		{ { "Cannon2", "s", 5 }, { "Missile", "s", 2, 1 }, { "Rail", "c", 1 }, { "Auto", "c", 2 } },
	},
	Corsairs = {
		{ { "Auto", "c", 1 } },
		{ { "Auto", "c", 1 }, { "Cannon1", "c", 1 } },
		{ { "Auto", "s", 3 }, { "Cannon1", "c", 1 } },
		{ { "Auto", "s", 4 }, { "Cannon1", "s", 1 } },
		{ { "Auto", "s", 5 }, { "Cannon1", "s", 2 } },
		{ { "Auto", "s", 6 }, { "Cannon1", "s", 3 }, { "Rail", "c", 1 } },
		{ { "Auto", "s", 8 }, { "Cannon1", "s", 3 }, { "Rail", "c", 2 } },
	},
	Dominion = {
		{ { "Cannon1", "c", 1 } },
		{ { "Cannon1", "c", 1 }, { "Auto", "c", 1 } },
		{ { "Missile", "s", 2 }, { "Auto", "c", 2 } },
		{ { "Missile", "s", 3 }, { "Auto", "c", 2 } },
		{ { "Missile", "s", 4 }, { "Cannon2", "s", 1 }, { "Auto", "c", 2 } },
		{ { "Missile", "s", 4 }, { "Cannon2", "s", 1 }, { "Auto", "c", 2 } },
		{ { "Missile", "s", 5 }, { "Rail", "c", 1 }, { "Cannon2", "s", 1 }, { "Auto", "c", 2 } },
	},
	Syndicate = {
		{ { "Cannon1", "c", 1 } },
		{ { "Cannon1", "c", 1 }, { "Auto", "c", 1 } },
		{ { "Cannon2", "s", 1 }, { "Auto", "c", 2 } },
		{ { "Rail", "c", 1 }, { "Cannon2", "s", 2 }, { "Auto", "c", 1 } },
		{ { "Rail", "c", 2 }, { "Cannon2", "s", 2 }, { "Auto", "c", 2 } },
		{ { "Rail", "c", 3 }, { "Cannon2", "s", 2 }, { "Missile", "s", 1 }, { "Auto", "c", 2 } },
		{ { "Rail", "c", 4 }, { "Cannon2", "s", 3 }, { "Missile", "s", 2 }, { "Auto", "c", 2 } },
	},
}

local function factionConfig(key, t)
	local base = TIER[t]
	local cfg = {
		Armor = base.Armor, Core = base.Core, Engine = base.Engine, EngN = base.EngN,
		HW = base.HW, Len = base.Len, Bow = "pointed", Layers = 2, Cabin = 0, BowWedge = false,
	}
	STYLE[key](t, cfg)
	cfg.Solid = t <= 4
	cfg.Citadel = not cfg.Solid
	cfg.CoreY = 1
	cfg.DeckY = cfg.Solid and 2 or 1
	cfg.EngY = 1
	return cfg
end

function Blueprints.Faction(key, tier)
	tier = math.clamp(tier or 1, 1, 7)
	if not STYLE[key] then return Blueprints.AI(1) end
	local list = generate(factionConfig(key, tier), PLANS[key][tier])
	local res = ShipParts.Analyze(list)
	if not res.Ok then
		warn(("[Blueprints] %s tier %d is invalid (%s) - using a fallback design"):format(key, tier, table.concat(res.Problems, "; ")))
		return Blueprints.AI(math.min(tier, 4))
	end
	return list
end

-- three weak pirate ships: easy early XP
local PIRATE = {
	{ Len = 7, Plan = { { "Cannon1", "c", 1 } } }, -- Raft
	{ Len = 7, Plan = { { "Auto", "c", 1 } } },    -- Skiff
	{ Len = 9, Plan = { { "Cannon1", "c", 2 } } }, -- Gunboat
}
Blueprints.PirateCount = #PIRATE

function Blueprints.Pirate(i)
	local p = PIRATE[i] or PIRATE[1]
	local cfg = {
		Armor = "Wood", Core = "Core1", Engine = "Paddle", EngN = 1, HW = 1, Len = p.Len,
		Bow = "pointed", Layers = 1, Solid = true, Citadel = false, CoreY = 0, DeckY = 1, EngY = 0, Cabin = 0,
	}
	local list = generate(cfg, p.Plan)
	local res = ShipParts.Analyze(list)
	if not res.Ok then
		warn("[Blueprints] Pirate design " .. i .. " is invalid (" .. table.concat(res.Problems, "; ") .. ")")
		return Blueprints.AI(1)
	end
	return list
end

return Blueprints