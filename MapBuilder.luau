local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorldConfig = require(ReplicatedStorage:WaitForChild("WorldConfig"))

local MapBuilder = {}
local rng = Random.new(20261021)
local TOP = 5.4 -- ground level of every island

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

local function part(name, size, cf, color, material, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- upright cylinder, centre = middle of the cylinder
local function cyl(name, diameter, height, center, color, material, parent)
	local p = part(name, Vector3.new(height, diameter, diameter), CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), color, material, parent)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function ball(name, diameter, center, color, material, parent)
	local p = part(name, Vector3.one * diameter, CFrame.new(center), color, material, parent)
	p.Shape = Enum.PartType.Ball
	return p
end

local function label3d(adornee, text, offsetY, color, width)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(width or 140, 26)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 380
	gui.Adornee = adornee
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.Font = Enum.Font.GothamBold
	l.TextSize = 14
	l.TextStrokeTransparency = 0.4
	l.Parent = gui
	gui.Parent = adornee
end

local THEMES = {
	Home      = { Sand = rgb(236, 216, 156), Top = rgb(86, 162, 76),  TopMat = Enum.Material.Grass,     Rock = rgb(125, 115, 100) },
	Armada    = { Sand = rgb(120, 118, 114), Top = rgb(92, 96, 102),  TopMat = Enum.Material.Slate,     Rock = rgb(62, 64, 70) },
	Corsairs  = { Sand = rgb(236, 216, 156), Top = rgb(60, 150, 70),  TopMat = Enum.Material.Grass,     Rock = rgb(110, 100, 85) },
	Dominion  = { Sand = rgb(240, 212, 140), Top = rgb(214, 180, 98), TopMat = Enum.Material.Sandstone, Rock = rgb(190, 150, 82) },
	Syndicate = { Sand = rgb(58, 52, 74),    Top = rgb(40, 34, 60),   TopMat = Enum.Material.Basalt,    Rock = rgb(28, 26, 38) },
}

-- PROPS --------------------------------------------------------------------------------
local function palm(parent, x, z, scale)
	scale = scale or 1
	local h = 8 * scale
	local base = Vector3.new(x, TOP, z)
	cyl("PalmTrunk", 0.9 * scale, h, base + Vector3.new(0, h / 2, 0), rgb(120, 85, 50), Enum.Material.Wood, parent)
	local crown = base + Vector3.new(0, h, 0)
	local spin = rng:NextNumber(0, math.pi * 2)
	for i = 1, 6 do
		local leaf = part("PalmLeaf", Vector3.new(7 * scale, 0.25, 1.9 * scale),
			CFrame.new(crown) * CFrame.Angles(0, spin + i * math.pi / 3, 0) * CFrame.Angles(0, 0, math.rad(-24)) * CFrame.new(3.3 * scale, 0, 0),
			rgb(50, 130, 55), Enum.Material.Grass, parent)
		leaf.CanCollide = false
	end
end

local function rock(parent, pos, s, color)
	return part("Rock", Vector3.new(s * rng:NextNumber(0.8, 1.4), s * rng:NextNumber(0.6, 1.1), s * rng:NextNumber(0.8, 1.4)),
		CFrame.new(pos) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.28), rng:NextNumber(-0.3, 0.3)),
		color, Enum.Material.Slate, parent)
end

-- box building with a gable roof; the door is on the -z side
local function building(parent, pos, yaw, w, h, d, wall, roof, mat)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	local body = part("BuildingWall", Vector3.new(w, h, d), cf * CFrame.new(0, h / 2, 0), wall, mat or Enum.Material.Concrete, parent)
	local rise = d * 0.22
	local ang = math.atan(rise / (d / 2))
	local len = math.sqrt((d / 2) ^ 2 + rise ^ 2) + 0.8
	for _, s in ipairs({ -1, 1 }) do
		part("BuildingRoof", Vector3.new(w + 1.2, 0.6, len), cf * CFrame.new(0, h + rise / 2 + 0.2, s * d / 4) * CFrame.Angles(s * ang, 0, 0), roof, Enum.Material.Metal, parent)
	end
	part("BuildingDoor", Vector3.new(math.min(w * 0.3, 8), h * 0.65, 0.3), cf * CFrame.new(0, h * 0.325, -d / 2 - 0.1), rgb(40, 32, 28), Enum.Material.Wood, parent)
	return body
end

-- dock starts at `start` (y = 0) and runs forward (-z of yaw) for `length`
local function dock(parent, start, yaw, length)
	local cf = CFrame.new(start) * CFrame.Angles(0, yaw, 0)
	part("DockDeck", Vector3.new(6, 0.6, length), cf * CFrame.new(0, 3, -length / 2), rgb(130, 95, 60), Enum.Material.WoodPlanks, parent)
	for i = 0, math.floor(length / 8) do
		for _, sx in ipairs({ -2.6, 2.6 }) do
			cyl("DockPost", 0.7, 7, (cf * CFrame.new(sx, 0.5, -i * 8)).Position, rgb(80, 60, 40), Enum.Material.Wood, parent)
		end
	end
end

local function lighthouse(parent, pos)
	local cols = { rgb(235, 235, 235), rgb(190, 50, 45) }
	cyl("LighthouseBase", 11, 3, pos + Vector3.new(0, 1.5, 0), rgb(110, 105, 100), Enum.Material.Concrete, parent)
	for i = 0, 3 do
		cyl("LighthouseBand", 8 - i * 0.7, 5, pos + Vector3.new(0, 3 + i * 5 + 2.5, 0), cols[i % 2 + 1], Enum.Material.Concrete, parent)
	end
	cyl("LighthouseGallery", 8.4, 1, pos + Vector3.new(0, 24, 0), rgb(40, 40, 45), Enum.Material.Metal, parent)
	local lamp = cyl("LighthouseLamp", 5, 4, pos + Vector3.new(0, 26.5, 0), rgb(255, 235, 150), Enum.Material.Neon, parent)
	lamp.Transparency = 0.2
	local light = Instance.new("PointLight")
	light.Range = 60
	light.Brightness = 3
	light.Color = rgb(255, 235, 170)
	light.Parent = lamp
	cyl("LighthouseRoof", 6.5, 1.4, pos + Vector3.new(0, 29.2, 0), rgb(190, 50, 45), Enum.Material.Metal, parent)
end

local function derrick(parent, pos, income)
	cyl("DerrickPlatform", 15, 1.2, pos + Vector3.new(0, 0.6, 0), rgb(70, 72, 78), Enum.Material.DiamondPlate, parent)
	for _, sx in ipairs({ -4, 4 }) do
		for _, sz in ipairs({ -4, 4 }) do
			local lean = CFrame.Angles(sz > 0 and -math.rad(8) or math.rad(8), 0, sx > 0 and math.rad(8) or -math.rad(8))
			part("DerrickLeg", Vector3.new(0.8, 19, 0.8), CFrame.new(pos + Vector3.new(sx, 10.7, sz)) * lean, rgb(200, 150, 40), Enum.Material.Metal, parent)
		end
	end
	part("DerrickTop", Vector3.new(5, 2, 5), CFrame.new(pos + Vector3.new(0, 20.5, 0)), rgb(60, 62, 68), Enum.Material.Metal, parent)
	ball("DerrickBeacon", 1.6, pos + Vector3.new(0, 22.5, 0), rgb(255, 60, 40), Enum.Material.Neon, parent)
	local oil = cyl("OilDeposit", 6, 3, pos + Vector3.new(0, 2.7, 0), rgb(18, 18, 20), Enum.Material.Metal, parent)
	oil:SetAttribute("Income", income)
	label3d(oil, "OIL  $" .. income, 12, rgb(255, 220, 100), 110)
	return oil
end

local function flag(parent, pos, color, height)
	cyl("FlagPole", 0.5, height, pos + Vector3.new(0, height / 2, 0), rgb(60, 60, 65), Enum.Material.Metal, parent)
	local cloth = part("Flag", Vector3.new(0.12, 3.2, 5.4), CFrame.new(pos + Vector3.new(0, height - 2, 3)), color, Enum.Material.Neon, parent)
	cloth.CanCollide = false
end

local function crane(parent, pos, yaw)
	local yellow = rgb(235, 190, 40)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	part("CraneBase", Vector3.new(8, 3, 8), cf * CFrame.new(0, 1.5, 0), rgb(70, 70, 75), Enum.Material.Metal, parent)
	cyl("CraneTower", 3, 24, (cf * CFrame.new(0, 15, 0)).Position, yellow, Enum.Material.Metal, parent)
	part("CraneJib", Vector3.new(3, 2, 30), cf * CFrame.new(0, 27, -8), yellow, Enum.Material.Metal, parent)
	part("CraneWeight", Vector3.new(4, 4, 5), cf * CFrame.new(0, 26, 9), rgb(80, 80, 85), Enum.Material.Concrete, parent)
	part("CraneCable", Vector3.new(0.2, 12, 0.2), cf * CFrame.new(0, 20, -20), rgb(30, 30, 30), Enum.Material.Metal, parent)
	part("CraneHook", Vector3.new(1.6, 1.6, 1.6), cf * CFrame.new(0, 13.5, -20), rgb(200, 60, 40), Enum.Material.Metal, parent)
end

-- FACTION LANDMARKS --------------------------------------------------------------------
local function armadaFeature(model, c, r)
	local steel = rgb(98, 102, 110)
	local n, R = 14, r * 0.8
	for i = 1, n do
		local a = i / n * math.pi * 2
		local pos = c + Vector3.new(math.cos(a) * R, TOP + 3, math.sin(a) * R)
		part("FortWall", Vector3.new(2 * R * math.sin(math.pi / n) + 0.6, 6, 3), CFrame.lookAt(pos, c + Vector3.new(0, TOP + 3, 0)), steel, Enum.Material.Concrete, model)
	end
	for q = 0, 3 do
		local a = q * math.pi / 2 + math.pi / 4
		local p = c + Vector3.new(math.cos(a) * R, 0, math.sin(a) * R)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		cyl("FortTower", 9, 17, p + Vector3.new(0, TOP + 8.5, 0), steel, Enum.Material.Concrete, model)
		cyl("FortTowerRoof", 10.5, 1.5, p + Vector3.new(0, TOP + 17.8, 0), rgb(70, 72, 78), Enum.Material.Metal, model)
		cyl("FortRing", 9.4, 0.6, p + Vector3.new(0, TOP + 15, 0), rgb(255, 60, 50), Enum.Material.Neon, model)
		for _, s in ipairs({ -1.2, 1.2 }) do
			local origin = p + Vector3.new(0, TOP + 19.5, 0) + dir:Cross(Vector3.yAxis) * s
			part("FortGun", Vector3.new(0.9, 0.9, 7), CFrame.lookAt(origin + dir * 3, origin + dir * 10), rgb(40, 42, 46), Enum.Material.Metal, model)
		end
	end
	part("Keep", Vector3.new(16, 22, 16), CFrame.new(c + Vector3.new(0, TOP + 11, 0)), steel, Enum.Material.Concrete, model)
	part("KeepRoof", Vector3.new(18, 2, 18), CFrame.new(c + Vector3.new(0, TOP + 23, 0)), rgb(70, 72, 78), Enum.Material.Metal, model)
	flag(model, c + Vector3.new(0, TOP + 24, 0), rgb(205, 65, 55), 14)
end

local function corsairFeature(model, c, r)
	for i = 1, 3 do
		local a = i * 2.1 + 0.4
		building(model, c + Vector3.new(math.cos(a) * r * 0.55, TOP, math.sin(a) * r * 0.55), a, 7, 4.5, 7, rgb(160, 110, 70), rgb(55, 125, 60), Enum.Material.WoodPlanks)
	end
	for i = 0, 4 do
		part("Totem", Vector3.new(3, 3, 3), CFrame.new(c + Vector3.new(0, TOP + 1.5 + i * 3, 0)) * CFrame.Angles(0, i * 0.7, 0),
			i % 2 == 0 and rgb(60, 165, 95) or rgb(190, 60, 50), Enum.Material.Wood, model)
	end
	ball("TotemEye", 1.6, c + Vector3.new(0, TOP + 16.5, 0), rgb(120, 255, 170), Enum.Material.Neon, model)
	flag(model, c + Vector3.new(4, TOP, 4), rgb(60, 190, 100), 16)
	local tp = c + Vector3.new(r * 0.3, TOP, -r * 0.3)
	cyl("BigTrunk", 3, 14, tp + Vector3.new(0, 7, 0), rgb(100, 70, 45), Enum.Material.Wood, model)
	for i = 1, 4 do
		local ang = i * 1.57
		local canopy = ball("Canopy", 11, tp + Vector3.new(math.cos(ang) * 4, 15 + (i % 2) * 2, math.sin(ang) * 4), rgb(50, 140, 60), Enum.Material.Grass, model)
		canopy.CanCollide = false
	end
end

local function dominionFeature(model, c, r)
	local sand, gold = rgb(228, 196, 120), rgb(245, 195, 60)
	for i = 0, 2 do
		local s = 28 - i * 8
		part("Ziggurat", Vector3.new(s, 3, s), CFrame.new(c + Vector3.new(0, TOP + 1.5 + i * 3, 0)), sand, Enum.Material.Sandstone, model)
	end
	part("Obelisk", Vector3.new(3.4, 20, 3.4), CFrame.new(c + Vector3.new(0, TOP + 19, 0)), gold, Enum.Material.Metal, model)
	part("ObeliskTip", Vector3.new(3.4, 4, 3.4), CFrame.new(c + Vector3.new(0, TOP + 31, 0)), gold, Enum.Material.Neon, model)
	local orb = ball("SunOrb", 6, c + Vector3.new(0, TOP + 36, 0), rgb(255, 235, 140), Enum.Material.Neon, model)
	local light = Instance.new("PointLight")
	light.Range = 70
	light.Brightness = 3
	light.Color = rgb(255, 225, 130)
	light.Parent = orb
	for _, off in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
		cyl("Column", 3, 12, c + Vector3.new(off[1] * 11, TOP + 6, off[2] * 11), gold, Enum.Material.Marble, model)
	end
end

local function syndicateFeature(model, c, r)
	local purple = rgb(150, 90, 230)
	for _ = 1, 10 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(8, r * 0.7)
		local h = rng:NextNumber(8, 22)
		local p = part("Crystal", Vector3.new(rng:NextNumber(2, 3.5), h, rng:NextNumber(2, 3.5)),
			CFrame.new(c + Vector3.new(math.cos(a) * d, TOP + h / 2 - 1, math.sin(a) * d))
				* CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, 3), rng:NextNumber(-0.25, 0.25)),
			purple, Enum.Material.Neon, model)
		p.Transparency = 0.15
	end
	cyl("VoidSpire", 6, 32, c + Vector3.new(0, TOP + 16, 0), rgb(30, 26, 42), Enum.Material.Basalt, model)
	for i = 1, 3 do
		cyl("SpireRing", 6.6, 0.8, c + Vector3.new(0, TOP + 8 * i, 0), purple, Enum.Material.Neon, model)
	end
	local tip = ball("SpireTip", 3, c + Vector3.new(0, TOP + 33, 0), purple, Enum.Material.Neon, model)
	local light = Instance.new("PointLight")
	light.Range = 60
	light.Brightness = 3
	light.Color = purple
	light.Parent = tip
end

local FEATURES = { Armada = armadaFeature, Corsairs = corsairFeature, Dominion = dominionFeature, Syndicate = syndicateFeature }

-- ISLANDS ----------------------------------------------------------------------------------
local function island(model, c, r, th)
	cyl("Seabed", r * 2 + 30, 6, c + Vector3.new(0, -8, 0), th.Rock, Enum.Material.Slate, model)
	cyl("Beach", r * 2, 10, c, th.Sand, Enum.Material.Sand, model)
	cyl("Top", r * 1.55, 10.4, c + Vector3.new(0, 0.2, 0), th.Top, th.TopMat, model)
	for _ = 1, 8 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = r * rng:NextNumber(0.92, 1.04)
		rock(model, c + Vector3.new(math.cos(a) * d, 3.5, math.sin(a) * d), rng:NextNumber(4, 8), th.Rock)
	end
end

local function scatterPalms(model, c, r, count)
	for _ = 1, count do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(r * 0.3, r * 0.72)
		palm(model, c.X + math.cos(a) * d, c.Z + math.sin(a) * d, rng:NextNumber(0.8, 1.2))
	end
end

local function makeTerritory(def, folder, spawnFolder)
	local f = WorldConfig.Factions[def.Faction]
	local c = def.Pos
	local r = 38 + def.Tier * 3

	local model = Instance.new("Model")
	model.Name = def.Name
	model:SetAttribute("DisplayName", def.Name)
	model:SetAttribute("Faction", def.Faction)
	model:SetAttribute("Tier", def.Tier)	
	model.Parent = folder

	island(model, c, r, THEMES[def.Faction])
	FEATURES[def.Faction](model, c, r)
	scatterPalms(model, c, r, 4 + def.Tier)

	for i = 1, def.Deposits do
		local a = (i / def.Deposits) * math.pi * 2 + 0.5
		derrick(model, c + Vector3.new(math.cos(a) * r * 0.62, TOP, math.sin(a) * r * 0.62), def.Income)
	end

	-- dock on the side facing the harbor
	local toHome = (Vector3.zero - c)
	toHome = Vector3.new(toHome.X, 0, toHome.Z).Unit
	local yaw = math.atan2(-toHome.X, -toHome.Z)
	local dockStart = c + toHome * (r - 4)
	dock(model, Vector3.new(dockStart.X, 0, dockStart.Z), yaw, 28)
	local tip = c + toHome * (r + 22)
	flag(model, Vector3.new(tip.X, 3.3, tip.Z), f.Color, 12)

	if def.Tier >= 3 then
		local la = rng:NextNumber(0, math.pi * 2)
		lighthouse(model, c + Vector3.new(math.cos(la) * r * 0.85, TOP, math.sin(la) * r * 0.85))
	end

	local zone = part("Zone", Vector3.new(260, 1, 340), CFrame.new(c + Vector3.new(0, 6, 0)), f.Color, Enum.Material.Neon, model)
	zone.Transparency = 0.85
	zone.CanCollide = false
	zone.CanQuery = false

	local guards = def.Tier >= 4 and 3 or 2
	for i = 1, guards do
		local a = (i / guards) * math.pi * 2 + rng:NextNumber(0, 1)
		local sp = part("Guard_" .. def.Name .. "_" .. i, Vector3.new(4, 1, 4),
			CFrame.new(c + Vector3.new(math.cos(a) * 150, 1, math.sin(a) * 150)), Color3.new(1, 0, 0), nil, spawnFolder)
		sp.Transparency = 1
		sp.CanCollide = false
		sp.CanQuery = false
		sp:SetAttribute("Tier", def.Tier)
		sp:SetAttribute("Faction", def.Faction)
		sp:SetAttribute("Territory", def.Name)
	end
end

-- HOME HARBOR ---------------------------------------------------------------------------------
local function buildHarbor(folder)
	local H = WorldConfig.Harbor
	local model = Instance.new("Model")
	model.Name = H.Name
	model:SetAttribute("Home", true)
	model:SetAttribute("DisplayName", H.Name)
	model.Parent = folder

	local r = H.IslandRadius
	island(model, Vector3.zero, r, THEMES.Home)
	cyl("Plaza", 44, 0.5, Vector3.new(0, TOP + 0.25, 0), rgb(150, 150, 155), Enum.Material.Concrete, model)

	local sp = Instance.new("SpawnLocation")
	sp.Size = Vector3.new(12, 1, 12)
	sp.Position = Vector3.new(0, TOP + 1, 0)
	sp.Anchored = true
	sp.Neutral = true
	sp.Duration = 0
	sp.Color = rgb(60, 200, 190)
	sp.Material = Enum.Material.Neon
	sp.Transparency = 0.3
	sp.Parent = model

	-- safe zone: glowing disc on the water + a ring of buoys
	local disc = cyl("SafeZoneDisc", H.Radius * 2, 0.3, Vector3.new(0, 3.4, 0), rgb(60, 200, 190), Enum.Material.Neon, model)
	disc.Transparency = 0.88
	disc.CanCollide = false
	disc.CanQuery = false
	for i = 0, 27 do
		local a = i / 28 * math.pi * 2
		local p = Vector3.new(math.cos(a) * H.Radius, 0, math.sin(a) * H.Radius)
		local b = cyl("Buoy", 3, 4, p + Vector3.new(0, 1, 0), i % 2 == 0 and rgb(220, 60, 50) or rgb(240, 240, 240), Enum.Material.SmoothPlastic, model)
		b.CanCollide = false
		local lamp = ball("BuoyLight", 1.4, p + Vector3.new(0, 3.4, 0), rgb(255, 230, 120), Enum.Material.Neon, model)
		lamp.CanCollide = false
	end

	-- buildings (they all keep inside the green top of the island)
	local blocked = { { 0, 0, 24 } } -- x, z, radius: keeps palms off buildings
	local function reserve(x, z, rad) table.insert(blocked, { x, z, rad }) end

	local hall = building(model, Vector3.new(24, TOP, -40), 0, 30, 15, 22, rgb(150, 160, 175), rgb(60, 90, 140), Enum.Material.Concrete)
	label3d(hall, "DRYDOCK - press B to build ships", 20, rgb(120, 230, 255), 240)
	reserve(24, -40, 24)

	for _, w in ipairs({ { -20, 52, 0 }, { 10, 56, 0 }, { 40, 38, 0 } }) do
		local pos = Vector3.new(w[1], TOP, w[2])
		building(model, pos, math.atan2(pos.X, pos.Z), 18, 8, 14, rgb(140, 125, 105), rgb(110, 60, 50), Enum.Material.Brick)
		reserve(w[1], w[2], 14)
	end

	crane(model, Vector3.new(-48, TOP, -42), math.rad(20))
	reserve(-48, -42, 12)
	crane(model, Vector3.new(58, TOP, -10), math.rad(-70))
	reserve(58, -10, 12)
	lighthouse(model, Vector3.new(-55, TOP, 30))
	reserve(-55, 30, 10)

	for i, z in ipairs({ -8, 14 }) do
		derrick(model, Vector3.new(-46, TOP, z), H.OilIncome)
		reserve(-46, z, 12)
	end

	-- crates and barrels around the hall
	for _ = 1, 12 do
		local p = Vector3.new(rng:NextNumber(-8, 16), TOP + 1.2, rng:NextNumber(-30, -14))
		part("Crate", Vector3.new(2.4, 2.4, 2.4), CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rgb(150, 110, 65), Enum.Material.WoodPlanks, model)
	end
	for _ = 1, 6 do
		cyl("Barrel", 2.2, 3, Vector3.new(rng:NextNumber(-6, 14), TOP + 1.5, rng:NextNumber(-12, -4)), rgb(120, 60, 50), Enum.Material.Metal, model)
	end

	-- two piers into the sea; your ship appears next to them
	local function pier(x, z0, length)
		part("PierDeck", Vector3.new(8, 0.6, length), CFrame.new(x, 4.9, z0 - length / 2), rgb(130, 95, 60), Enum.Material.WoodPlanks, model)
		for i = 0, math.floor(length / 8) do
			for _, sx in ipairs({ -3.4, 3.4 }) do
				cyl("PierPost", 0.8, 9, Vector3.new(x + sx, 0.5, z0 - i * 8), rgb(80, 60, 40), Enum.Material.Wood, model)
			end
		end
		local lamp = ball("PierLamp", 1.6, Vector3.new(x, 9, z0 - length), rgb(255, 230, 140), Enum.Material.Neon, model)
		cyl("PierLampPost", 0.4, 8, Vector3.new(x, 5.2 + 2, z0 - length), rgb(50, 50, 55), Enum.Material.Metal, model)
		local light = Instance.new("PointLight")
		light.Range = 30
		light.Brightness = 2
		light.Color = rgb(255, 225, 150)
		light.Parent = lamp
	end
	pier(0, -74, 60)
	pier(-30, -70, 54)

	flag(model, Vector3.new(0, TOP + 0.5, 12), rgb(60, 200, 190), 18)

	local sign = part("HarborLabel", Vector3.one, CFrame.new(0, TOP + 26, 0), Color3.new(1, 1, 1), nil, model)
	sign.Transparency = 1
	sign.CanCollide = false
	sign.CanQuery = false
	label3d(sign, "HOME HARBOR - SAFE ZONE", 0, rgb(120, 240, 230), 280)

	-- palms on any free spot
	local placedPalms, tries = 0, 0
	while placedPalms < 22 and tries < 300 do
		tries += 1
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(30, 62)
		local x, z = math.cos(a) * d, math.sin(a) * d
		local free = true
		for _, b in ipairs(blocked) do
			if math.sqrt((x - b[1]) ^ 2 + (z - b[2]) ^ 2) < b[3] then free = false break end
		end
		if free then
			palm(model, x, z, rng:NextNumber(0.9, 1.3))
			placedPalms += 1
		end
	end
end

-- DECORATIVE ISLETS ---------------------------------------------------------------------------
local function isletBase(model, pos, r)
	cyl("Seabed", r * 2 + 10, 4, pos + Vector3.new(0, -6, 0), rgb(110, 100, 85), Enum.Material.Slate, model)
	cyl("Sand", r * 2, 10, pos, rgb(236, 216, 156), Enum.Material.Sand, model)
end

local ISLETS = {}

ISLETS.Palm = function(model, pos)
	local r = rng:NextNumber(16, 22)
	isletBase(model, pos, r)
	cyl("Grass", r * 1.5, 10.3, pos + Vector3.new(0, 0.2, 0), rgb(70, 150, 70), Enum.Material.Grass, model)
	for _ = 1, rng:NextInteger(3, 5) do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(0, r * 0.6)
		palm(model, pos.X + math.cos(a) * d, pos.Z + math.sin(a) * d, rng:NextNumber(0.8, 1.1))
	end
	for _ = 1, 3 do
		local a = rng:NextNumber(0, math.pi * 2)
		rock(model, pos + Vector3.new(math.cos(a) * r * 0.95, 3.5, math.sin(a) * r * 0.95), rng:NextNumber(3, 6), rgb(120, 112, 98))
	end
end

ISLETS.Spire = function(model, pos)
	cyl("RockBase", 24, 10, pos, rgb(95, 90, 88), Enum.Material.Slate, model)
	local y, size = 5, 15
	for i = 1, 5 do
		local r = rock(model, pos + Vector3.new(rng:NextNumber(-1.5, 1.5), y + size * 0.4, rng:NextNumber(-1.5, 1.5)), size, rgb(100 - i * 4, 95 - i * 4, 92 - i * 4))
		y += size * 0.65
		size *= 0.78
	end
	for _ = 1, 4 do
		local a = rng:NextNumber(0, math.pi * 2)
		rock(model, pos + Vector3.new(math.cos(a) * 14, 3, math.sin(a) * 14), rng:NextNumber(4, 8), rgb(88, 84, 82))
	end
end

ISLETS.Reef = function(model, pos)
	for _ = 1, rng:NextInteger(9, 13) do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(0, 24)
		local r = rock(model, pos + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d), rng:NextNumber(4, 8), rgb(105, 120, 110))
		r.Material = Enum.Material.Slate
	end
end

ISLETS.Wreck = function(model, pos)
	local bar = cyl("Sandbar", 40, 3, pos + Vector3.new(0, 0.2, 0), rgb(236, 216, 156), Enum.Material.Sand, model)
	local yaw = rng:NextNumber(0, math.pi * 2)
	local base = CFrame.new(pos + Vector3.new(0, 4, 0)) * CFrame.Angles(math.rad(-6), yaw, math.rad(18))
	local function piece(name, size, offset, color, mat)
		local p = part(name, size, base * offset, color, mat, model)
		p.CanCollide = false
		return p
	end
	piece("WreckHull", Vector3.new(10, 5, 30), CFrame.new(0, 0, 0), rgb(88, 62, 42), Enum.Material.WoodPlanks)
	piece("WreckBow", Vector3.new(7, 4, 9), CFrame.new(0, 0.5, -17) * CFrame.Angles(math.rad(-10), 0, 0), rgb(80, 56, 38), Enum.Material.WoodPlanks)
	for i = -2, 2 do
		piece("WreckRib", Vector3.new(0.6, 6.5, 0.6), CFrame.new(4.4, 3, i * 5) * CFrame.Angles(0, 0, math.rad(-12)), rgb(70, 50, 34), Enum.Material.Wood)
		piece("WreckRib", Vector3.new(0.6, 6.5, 0.6), CFrame.new(-4.4, 3, i * 5) * CFrame.Angles(0, 0, math.rad(12)), rgb(70, 50, 34), Enum.Material.Wood)
	end
	piece("BrokenMast", Vector3.new(1, 24, 1), CFrame.new(0, 12, -3) * CFrame.Angles(math.rad(12), 0, math.rad(-22)), rgb(95, 68, 46), Enum.Material.Wood)
	piece("TornSail", Vector3.new(0.2, 10, 8), CFrame.new(1.5, 15, -3) * CFrame.Angles(math.rad(12), 0, math.rad(-22)), rgb(210, 195, 160), Enum.Material.Fabric)
end

local function buildIslets(parent)
	local avoid = {}
	for _, t in ipairs(WorldConfig.GetTerritories()) do table.insert(avoid, t.Pos) end
	local mine = {}
	local kinds = { "Palm", "Spire", "Reef", "Wreck" }
	local count, tries = 0, 0
	local limit = WorldConfig.WorldSize / 2 - 150
	while count < 90 and tries < 4000 do
		tries += 1
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(500, limit)
		local pos = Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		local ok = math.abs(pos.X) < limit and math.abs(pos.Z) < limit
		if ok then
			for _, p in ipairs(avoid) do
				if (p - pos).Magnitude < 270 then ok = false break end
			end
		end
		if ok then
			for _, p in ipairs(mine) do
				if (p - pos).Magnitude < 170 then ok = false break end
			end
		end
		if ok then
			count += 1
			table.insert(mine, pos)
			local model = Instance.new("Model")
			model.Name = "Islet_" .. kinds[count % 4 + 1]
			ISLETS[kinds[count % 4 + 1]](model, pos)
			model.Parent = parent
		end
	end
end

-- BUILD THE WORLD ----------------------------------------------------------------------------
local function step(name, fn)
	local ok, err = xpcall(fn, debug.traceback)
	if ok then
		print("[MapBuilder] " .. name .. " - ok")
	else
		warn("[MapBuilder] FAILED at '" .. name .. "':\n" .. tostring(err))
	end
	return ok
end

local function buildOcean()
	local W = WorldConfig.WorldSize
	local N = math.ceil(W / 2000) -- a Part can't be bigger than 2048 studs, so the sea is a grid of tiles
	local tile = W / N
	local folder = Instance.new("Folder")
	folder.Name = "OceanTiles"
	for i = 0, N - 1 do
		for j = 0, N - 1 do
			local cx = (i - (N - 1) / 2) * tile
			local cz = (j - (N - 1) / 2) * tile
			local t = part("Ocean", Vector3.new(tile, 6, tile), CFrame.new(cx, -6, cz), rgb(20, 90, 160), Enum.Material.SmoothPlastic, folder)
			t.Transparency = 0
			t.CanCollide = false
			t.Touched:Connect(function(hit)
				local hum = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
				if hum and not hum.SeatPart and hum.Health > 0 and not hit.Parent:GetAttribute("Launching") then
					hum.Health = 0 -- falling into the sea without a ship
				end
			end)
		end
	end
	folder.Parent = workspace
end

local function buildEdges()
	local W = WorldConfig.WorldSize
	local N = math.ceil(W / 2000)
	local tile = W / N
	local folder = Instance.new("Folder")
	folder.Name = "WorldEdge"
	local E, T, HH = W / 2, 10, 300
	for k = 0, N - 1 do
		local c = (k - (N - 1) / 2) * tile
		for _, spec in ipairs({
			{ Vector3.new(T, HH, tile + 2 * T), Vector3.new(E + T / 2, 100, c) },
			{ Vector3.new(T, HH, tile + 2 * T), Vector3.new(-E - T / 2, 100, c) },
			{ Vector3.new(tile + 2 * T, HH, T), Vector3.new(c, 100, E + T / 2) },
			{ Vector3.new(tile + 2 * T, HH, T), Vector3.new(c, 100, -E - T / 2) },
			}) do
			local wall = part("EdgeWall", spec[1], CFrame.new(spec[2]), Color3.new(1, 1, 1), nil, folder)
			wall.Transparency = 1
			wall.CanQuery = false
		end
	end
	folder.Parent = workspace
end

-- emergency ground, only used if the harbor fails to build
local function fallbackSpawn()
	part("FallbackIsland", Vector3.new(120, 6, 120), CFrame.new(0, 2.4, 0), rgb(236, 216, 156), Enum.Material.Sand, workspace)
	local sp = Instance.new("SpawnLocation")
	sp.Size = Vector3.new(12, 1, 12)
	sp.Position = Vector3.new(0, 6.4, 0)
	sp.Anchored = true
	sp.Neutral = true
	sp.Duration = 0
	sp.Parent = workspace
end

function MapBuilder.Build()
	if workspace:FindFirstChild("Territories") then return end -- you made your own map

	local base = workspace:FindFirstChild("Baseplate")
	if base then base:Destroy() end
	for _, inst in ipairs(workspace:GetChildren()) do
		if inst:IsA("SpawnLocation") then inst:Destroy() end
	end

	local terrFolder = Instance.new("Folder")
	terrFolder.Name = "Territories"
	terrFolder.Parent = workspace
	local spawnFolder = Instance.new("Folder")
	spawnFolder.Name = "AISpawns"
	spawnFolder.Parent = workspace
	local decorFolder = Instance.new("Folder")
	decorFolder.Name = "Decor"
	decorFolder.Parent = workspace

	-- 1) harbor + spawn + launch point FIRST, so you always have ground and a place to launch from
	step("Home Harbor", function() buildHarbor(terrFolder) end)
	if not terrFolder:FindFirstChildWhichIsA("SpawnLocation", true) then
		warn("[MapBuilder] No spawn point was built - creating an emergency island")
		fallbackSpawn()
	end
	local bs = part("BoatSpawn", Vector3.new(12, 1, 26), CFrame.new(70, 1, -190), Color3.new(1, 1, 1), nil, workspace)
	bs.Transparency = 1
	bs.CanCollide = false
	bs.CanQuery = false

	step("Ocean", buildOcean)
	step("World edge", buildEdges)

	step("Pirate spawn points", function()
		for i = 1, 6 do
			local a = math.rad(i * 60 + 15)
			local sp = part("Pirate_" .. i, Vector3.new(4, 1, 4), CFrame.new(math.cos(a) * 560, 1, math.sin(a) * 560), Color3.new(1, 0, 0), nil, spawnFolder)
			sp.Transparency = 1
			sp.CanCollide = false
			sp.CanQuery = false
			sp:SetAttribute("Pirate", true)
			sp:SetAttribute("Faction", "Pirates")
		end
	end)
	task.wait()

	-- 2) enemy territories one at a time (a short pause now and then so a big build can't time out)
	for i, def in ipairs(WorldConfig.GetTerritories()) do
		step("Territory " .. def.Name, function() makeTerritory(def, terrFolder, spawnFolder) end)
		if i % 3 == 0 then task.wait() end
	end

	step("Decorative islets", function() buildIslets(decorFolder) end)
	-- performance pass: small props and hidden pieces don't need to cast shadows
	step("Performance pass", function()
		for _, root in ipairs({ terrFolder, decorFolder }) do
			for _, d in ipairs(root:GetDescendants()) do
				if d:IsA("BasePart") then
					local s = d.Size
					if math.max(s.X, s.Y, s.Z) < 12 or d.Name == "Seabed" or d.Name == "Zone" or d.Name == "SafeZoneDisc" then
						d.CastShadow = false
					end
				end
			end
		end
	end)
	print("[MapBuilder] World ready")
end

return MapBuilder