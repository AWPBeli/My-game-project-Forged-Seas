local ShipParts = {}

ShipParts.SCALE = 3                  -- every block, weapon and engine is built this many times bigger
ShipParts.CELL = 2 * ShipParts.SCALE -- one grid cell = 6 studs
ShipParts.GRID = { W = 11, L = 25, H = 9 } -- cells: x -5..5, z -12..12 (bow = -z), y 0..8
ShipParts.MaxBlocks = 300
ShipParts.SpeedFactor = 14   -- top speed = thrust / mass * this
ShipParts.SpeedCap = 95

-- If wedge/corner pieces slope the wrong way in-game, set this to true
local WEDGE_FLIPPED = false
local WEDGE_YAW = WEDGE_FLIPPED and math.pi or 0
local CORNER_YAW = WEDGE_FLIPPED and -math.pi / 2 or 0

local S = ShipParts.CELL
local GRID = ShipParts.GRID
local XMAX = (GRID.W - 1) // 2
local ZMAX = (GRID.L - 1) // 2

function ShipParts.Key(x, y, z) return (x + 16) * 1024 + y * 32 + (z + 16) end
function ShipParts.InBounds(x, y, z)
	return x >= -XMAX and x <= XMAX and z >= -ZMAX and z <= ZMAX and y >= 0 and y < GRID.H
end

ShipParts.DIRS = { { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 } }

-- PART DEFINITIONS ---------------------------------------------------------------
ShipParts.List = {}
ShipParts.ById = {}

local function add(def)
	def.Size = def.Size or { 1, 1, 1 }
	def.Short = def.Short or def.Name
	table.insert(ShipParts.List, def)
	ShipParts.ById[def.Id] = def
end

-- Armor: 4 materials x 4 shapes (Tech = material). Corner = bow-chamfer piece, cuts the front-left corner at rotation 0.
local MATERIALS = {
	{ Key = "Wood",     HP = 60,  Mass = 0.5, Cost = 5,  Color = Color3.fromRGB(150, 100, 60),  Material = Enum.Material.WoodPlanks,     Reflectance = 0 },
	{ Key = "Iron",     HP = 150, Mass = 1.2, Cost = 15,  Color = Color3.fromRGB(105, 100, 98),  Material = Enum.Material.CorrodedMetal, Reflectance = 0 },
	{ Key = "Steel",    HP = 320, Mass = 2.0, Cost = 25, Color = Color3.fromRGB(165, 172, 182), Material = Enum.Material.DiamondPlate,   Reflectance = 0.05 },
	{ Key = "Titanium", HP = 520, Mass = 1.6, Cost = 50, Color = Color3.fromRGB(185, 200, 225), Material = Enum.Material.Metal,          Reflectance = 0.15 },
}
local SHAPES = { { "Block", 1 }, { "Slab", 0.5 }, { "Wedge", 0.6 }, { "Corner", 0.6 } }
for _, m in ipairs(MATERIALS) do
	for _, sh in ipairs(SHAPES) do
		add({
			Id = m.Key .. "_" .. sh[1], Category = "Armor", Tech = m.Key, Shape = sh[1],
			Name = m.Key .. " " .. sh[1], Short = sh[1],
			HP = math.floor(m.HP * sh[2]), Mass = m.Mass * sh[2], Cost = math.max(1, math.floor(m.Cost * sh[2] + 0.5)),
			Color = m.Color, Material = m.Material, Reflectance = m.Reflectance,
		})
	end
end

-- Cores: lose this and the ship is destroyed
add({ Id = "Core1", Category = "Core", Tech = "Core1", Name = "Core Mk1", HP = 300,  Mass = 6,  Cost = 100,  Glow = Color3.fromRGB(80, 200, 255) })
add({ Id = "Core2", Category = "Core", Tech = "Core2", Name = "Core Mk2", HP = 700,  Mass = 9,  Cost = 600, Glow = Color3.fromRGB(120, 255, 140) })
add({ Id = "Core3", Category = "Core", Tech = "Core3", Name = "Core Mk3", HP = 1600, Mass = 12, Cost = 2000, Glow = Color3.fromRGB(255, 90, 200) })

add({ Id = "Helm", Category = "Misc", Tech = "Helm", Name = "Helm (captain's seat)", Short = "Helm", HP = 150, Mass = 1, Cost = 0 })

-- Engines (1 wide, 1 tall, 2 long)
add({ Id = "Paddle",  Category = "Engine", Tech = "Paddle",  Name = "Paddle Wheel",  Size = { 1, 1, 2 }, HP = 50,  Mass = 4,  Cost = 75,   Thrust = 80,  Style = "paddle",  Housing = Color3.fromRGB(150, 100, 60) })
add({ Id = "Diesel",  Category = "Engine", Tech = "Diesel",  Name = "Diesel Engine", Size = { 1, 1, 2 }, HP = 70,  Mass = 6,  Cost = 300,  Thrust = 200, Style = "diesel",  Housing = Color3.fromRGB(70, 72, 78) })
add({ Id = "Turbine", Category = "Engine", Tech = "Turbine", Name = "Gas Turbine",   Size = { 1, 1, 2 }, HP = 90,  Mass = 9,  Cost = 900,  Thrust = 420, Style = "turbine", Housing = Color3.fromRGB(150, 155, 165), Glow = Color3.fromRGB(255, 140, 50) })
add({ Id = "Reactor", Category = "Engine", Tech = "Reactor", Name = "Reactor Drive", Size = { 1, 1, 2 }, HP = 120, Mass = 12, Cost = 2100, Thrust = 800, Style = "reactor", Housing = Color3.fromRGB(35, 40, 45), Glow = Color3.fromRGB(80, 255, 170) })

-- Weapons: Vis describes the turret (housing + barrels). Neon barrels are decoration only.
local function weapon(def)
	def.Category = "Weapon"
	def.Muzzles = {}
	for _, b in ipairs(def.Vis.Barrels) do
		if not b.Neon then
			table.insert(def.Muzzles, Vector3.new(b.X, b.Y or 0, -(def.Vis.Housing.Z / 2 + b.Len - 0.2)))
		end
	end
	add(def)
end

weapon({ Id = "Cannon1", Tech = "Cannon1", Name = "Light Cannon", HP = 40, Mass = 2, Cost = 150,
	Damage = 12, Cooldown = 1.2, Speed = 220, Range = 450, Splash = 2, Color = Color3.fromRGB(80, 84, 92),
	Vis = { Housing = Vector3.new(1.1, 0.9, 1.5), Barrels = { { X = 0, Y = 0.05, Len = 2.2, Thick = 0.4 } } },
	Proj = { Size = Vector3.new(0.5, 0.5, 2.2), Color = Color3.fromRGB(255, 200, 80) } })

weapon({ Id = "Auto", Tech = "Auto", Name = "Autocannon", HP = 40, Mass = 2.5, Cost = 300,
	Damage = 5, Cooldown = 0.35, Speed = 300, Range = 380, Splash = 1, Color = Color3.fromRGB(95, 100, 110),
	Vis = { Housing = Vector3.new(1.0, 0.8, 1.3), Barrels = { { X = -0.28, Len = 1.7, Thick = 0.22 }, { X = 0.28, Len = 1.7, Thick = 0.22 } } },
	Proj = { Size = Vector3.new(0.3, 0.3, 1.6), Color = Color3.fromRGB(255, 235, 140) } })

weapon({ Id = "Cannon2", Tech = "Cannon2", Name = "Heavy Cannon", Size = { 2, 1, 2 }, HP = 90, Mass = 5, Cost = 800,
	Damage = 50, Cooldown = 1.7, Speed = 260, Range = 650, Splash = 3, Color = Color3.fromRGB(60, 62, 72),
	Vis = { Housing = Vector3.new(2.6, 1.1, 2.6), Barrels = { { X = -0.7, Len = 3.4, Thick = 0.65 }, { X = 0.7, Len = 3.4, Thick = 0.65 } } },
	Proj = { Size = Vector3.new(0.9, 0.9, 3.2), Color = Color3.fromRGB(255, 150, 60) } })

weapon({ Id = "Missile", Tech = "Missile", Name = "Missile Launcher", Size = { 2, 1, 1 }, HP = 70, Mass = 4, Cost = 1500,
	Damage = 70, Cooldown = 3, Speed = 170, Range = 800, Splash = 7, Color = Color3.fromRGB(150, 55, 55),
	Vis = { Housing = Vector3.new(3.2, 0.9, 1.5), Barrels = {
		{ X = -1.2, Y = 0.1, Len = 1.6, Thick = 0.55 }, { X = -0.4, Y = 0.1, Len = 1.6, Thick = 0.55 },
		{ X = 0.4, Y = 0.1, Len = 1.6, Thick = 0.55 }, { X = 1.2, Y = 0.1, Len = 1.6, Thick = 0.55 } } },
	Proj = { Size = Vector3.new(0.7, 0.7, 2.4), Color = Color3.fromRGB(255, 90, 60) } })

weapon({ Id = "Rail", Tech = "Rail", Name = "Railgun", Size = { 1, 1, 3 }, HP = 80, Mass = 6, Cost = 2500,
	Damage = 350, Cooldown = 2.2, Speed = 650, Range = 1000, Splash = 0, Color = Color3.fromRGB(40, 45, 55), Accent = Color3.fromRGB(90, 220, 255),
	Vis = { Housing = Vector3.new(1.0, 0.9, 3.2), Barrels = {
		{ X = 0, Y = 0.05, Len = 4, Thick = 0.3 },
		{ X = -0.38, Y = 0.05, Len = 3.6, Thick = 0.12, Neon = true }, { X = 0.38, Y = 0.05, Len = 3.6, Thick = 0.12, Neon = true } } },
	Proj = { Size = Vector3.new(0.2, 0.2, 5), Color = Color3.fromRGB(90, 220, 255) } })

-- GEOMETRY -----------------------------------------------------------------------
local function rotXZ(dx, dz, r)
	for _ = 1, r do dx, dz = dz, -dx end
	return dx, dz
end

function ShipParts.Footprint(def, x, y, z, r)
	local cells = {}
	for dx = 0, def.Size[1] - 1 do
		for dy = 0, def.Size[2] - 1 do
			for dz = 0, def.Size[3] - 1 do
				local rx, rz = rotXZ(dx, dz, r)
				table.insert(cells, { x + rx, y + dy, z + rz })
			end
		end
	end
	return cells
end

-- CFrame of a block's centre in ship space (ship origin = keel centre), plus its cells
function ShipParts.BlockCFrame(def, x, y, z, r)
	local cells = ShipParts.Footprint(def, x, y, z, r)
	local sx, sy, sz = 0, 0, 0
	for _, c in ipairs(cells) do sx += c[1]; sy += c[2]; sz += c[3] end
	local n = #cells
	return CFrame.new(sx / n * S, sy / n * S + S / 2, sz / n * S) * CFrame.Angles(0, r * math.pi / 2, 0), cells
end

function ShipParts.DriveStats(mass, thrust)
	if thrust <= 0 or mass <= 0 then return { MaxSpeed = 0, Accel = 5, Turn = 0.3 } end
	local ratio = thrust / mass
	return {
		MaxSpeed = math.min(ShipParts.SpeedCap, ratio * ShipParts.SpeedFactor),
		Accel = math.clamp(ratio * 6, 5, 40),
		Turn = math.clamp(0.25 + ratio * 0.3, 0.3, 1.3),
	}
end

-- VALIDATION ---------------------------------------------------------------------
local function isInt(n) return type(n) == "number" and n == math.floor(n) and math.abs(n) < 1000 end

-- blueprint = array of { Id, X, Y, Z, R }. unlocked (optional) = set of researched tech ids.
function ShipParts.Analyze(blueprint, unlocked)
	local res = { Blocks = {}, Occ = {}, Problems = {}, Cost = 0, Mass = 0, Thrust = 0,
		Weapons = 0, Engines = 0, Cores = 0, Helms = 0, MinZ = 0, MaxZ = 0, Ok = false }
	local reported = {}
	local function problem(msg)
		if not reported[msg] then
			reported[msg] = true
			table.insert(res.Problems, msg)
		end
	end

	if type(blueprint) ~= "table" or #blueprint == 0 then
		problem("The design is empty")
		return res
	end
	if #blueprint > ShipParts.MaxBlocks then
		problem(("Too many blocks (max %d)"):format(ShipParts.MaxBlocks))
		return res
	end

	local firstCell = true
	for _, e in ipairs(blueprint) do
		local def = type(e) == "table" and type(e.Id) == "string" and ShipParts.ById[e.Id]
		if def and isInt(e.X) and isInt(e.Y) and isInt(e.Z) and isInt(e.R) and e.R >= 0 and e.R <= 3 then
			if unlocked and not unlocked[def.Tech] then
				problem(def.Name .. " is not researched yet")
			else
				local cells = ShipParts.Footprint(def, e.X, e.Y, e.Z, e.R)
				local fits = true
				for _, c in ipairs(cells) do
					if not ShipParts.InBounds(c[1], c[2], c[3]) or res.Occ[ShipParts.Key(c[1], c[2], c[3])] then
						fits = false
						break
					end
				end
				if fits then
					local index = #res.Blocks + 1
					local cf = ShipParts.BlockCFrame(def, e.X, e.Y, e.Z, e.R)
					res.Blocks[index] = { Def = def, X = e.X, Y = e.Y, Z = e.Z, R = e.R, Cells = cells, CFrame = cf }
					for _, c in ipairs(cells) do
						res.Occ[ShipParts.Key(c[1], c[2], c[3])] = index
						if firstCell then
							res.MinZ, res.MaxZ = c[3], c[3]
							firstCell = false
						end
						res.MinZ = math.min(res.MinZ, c[3])
						res.MaxZ = math.max(res.MaxZ, c[3])
					end
					res.Cost += def.Cost
					res.Mass += def.Mass
					if def.Category == "Core" then res.Cores += 1; res.CoreIndex = index
					elseif def.Id == "Helm" then res.Helms += 1
					elseif def.Category == "Weapon" then res.Weapons += 1
					elseif def.Category == "Engine" then res.Engines += 1; res.Thrust += def.Thrust end
				else
					problem("Some parts overlap or are outside the build area")
				end
			end
		else
			problem("Invalid part in the design")
		end
	end

	if res.Cores == 0 then problem("Place a Core: the heart of your ship")
	elseif res.Cores > 1 then problem("Only one Core is allowed") end
	if res.Helms == 0 then problem("Place a Helm (captain's seat)")
	elseif res.Helms > 1 then problem("Only one Helm is allowed") end
	if res.Weapons == 0 then problem("Add at least one weapon") end
	if res.Engines == 0 then problem("Add at least one engine, or the ship can't move") end

	if res.Cores == 1 then
		local core = res.Blocks[res.CoreIndex]

		-- the core must be fully wrapped in armor (water below the keel counts as safe)
		local exposed = 0
		for _, d in ipairs(ShipParts.DIRS) do
			local nx, ny, nz = core.X + d[1], core.Y + d[2], core.Z + d[3]
			if ny >= 0 then
				local idx = ShipParts.InBounds(nx, ny, nz) and res.Occ[ShipParts.Key(nx, ny, nz)]
				if not idx or res.Blocks[idx].Def.Category ~= "Armor" then exposed += 1 end
			end
		end
		if exposed > 0 then
			problem(("The Core must be fully surrounded by armor (%d side(s) exposed)"):format(exposed))
		end

		-- everything must be connected to the core
		local seen, queue, qi = { [res.CoreIndex] = true }, { res.CoreIndex }, 1
		while qi <= #queue do
			local blk = res.Blocks[queue[qi]]
			qi += 1
			for _, c in ipairs(blk.Cells) do
				for _, d in ipairs(ShipParts.DIRS) do
					local nx, ny, nz = c[1] + d[1], c[2] + d[2], c[3] + d[3]
					if ShipParts.InBounds(nx, ny, nz) then
						local idx = res.Occ[ShipParts.Key(nx, ny, nz)]
						if idx and not seen[idx] then
							seen[idx] = true
							table.insert(queue, idx)
						end
					end
				end
			end
		end
		local loose = #res.Blocks - #queue
		if loose > 0 then problem(("%d part(s) are not connected to the core"):format(loose)) end
	end

	res.Ok = #res.Problems == 0
	return res
end

-- VISUALS ------------------------------------------------------------------------
local SMOKE_TEX = "rbxasset://textures/particles/smoke_main.dds"

function ShipParts.SmokeEmitter(parent, name, c0, c1, size0, size1, life, speed)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Rate = 0
	e.Texture = SMOKE_TEX
	e.Lifetime = NumberRange.new(life * 0.7, life)
	e.Speed = NumberRange.new(speed * 0.6, speed)
	e.Color = ColorSequence.new(c0, c1)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size0), NumberSequenceKeypoint.new(1, size1) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	e.RotSpeed = NumberRange.new(-30, 30)
	e.Parent = parent
	return e
end
-- scales a freshly drawn visual (parts, attachments, lights, particles) around the origin
local function scaleModel(model, k)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Size = d.Size * k
			d.CFrame = CFrame.new(d.Position * k) * d.CFrame.Rotation
		elseif d:IsA("Attachment") then
			d.Position = d.Position * k
		elseif d:IsA("Light") then
			d.Range = math.min(d.Range * k, 60)
		elseif d:IsA("ParticleEmitter") then
			local keys = {}
			for _, kp in ipairs(d.Size.Keypoints) do
				table.insert(keys, NumberSequenceKeypoint.new(kp.Time, kp.Value * k, kp.Envelope * k))
			end
			d.Size = NumberSequence.new(keys)
			d.Speed = NumberRange.new(d.Speed.Min * k, d.Speed.Max * k)
		end
	end
end
local function mk(model, name, class, size, cf, color, material)
	local p = Instance.new(class)
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- Builds one block's model centred on the origin of its cell(s). Part named "Main" is the anchor.
-- Parts named "Turret" rotate; parts named "T_*" ride on the turret.

function ShipParts.CreateVisual(def, preview)
	local S = ShipParts.CELL / ShipParts.SCALE -- the parts below are drawn at the base size, then scaled up at the end
	local model = Instance.new("Model")
	model.Name = def.Id
	local cat = def.Category

	if cat == "Armor" then
		local sh = def.Shape
		local main
		if sh == "Block" then
			main = mk(model, "Main", "Part", Vector3.new(S, S, S), CFrame.new(), def.Color, def.Material)
		elseif sh == "Slab" then
			main = mk(model, "Main", "Part", Vector3.new(S, S / 2, S), CFrame.new(0, -S / 4, 0), def.Color, def.Material)
		elseif sh == "Wedge" then
			main = mk(model, "Main", "WedgePart", Vector3.new(S, S, S), CFrame.Angles(0, WEDGE_YAW, 0), def.Color, def.Material)
		else
			main = mk(model, "Main", "WedgePart", Vector3.new(S, S, S),
				CFrame.Angles(0, CORNER_YAW, 0) * CFrame.Angles(0, 0, math.pi / 2), def.Color, def.Material)
		end
		main.Reflectance = def.Reflectance or 0

	elseif cat == "Core" then
		local casing = mk(model, "Main", "Part", Vector3.new(S, S, S), CFrame.new(), Color3.fromRGB(35, 40, 52), Enum.Material.Metal)
		casing.Transparency = 0.3
		local glow = mk(model, "Glow", "Part", Vector3.one * (S * 0.55), CFrame.new(), def.Glow, Enum.Material.Neon)
		glow.Shape = Enum.PartType.Ball
		local light = Instance.new("PointLight")
		light.Color = def.Glow
		light.Range = 14
		light.Brightness = 2
		light.Parent = glow

	elseif cat == "Misc" then -- helm
		mk(model, "Main", "Part", Vector3.new(S, 0.5, S), CFrame.new(0, -S / 2 + 0.25, 0), Color3.fromRGB(120, 85, 55), Enum.Material.WoodPlanks)
		local seat = Instance.new("VehicleSeat")
		seat.Name = "Seat"
		seat.Size = Vector3.new(1.4, 0.4, 1.4)
		seat.CFrame = CFrame.new(0, -S / 2 + 0.7, 0.2)
		seat.Color = Color3.fromRGB(60, 40, 30)
		seat.Anchored = true
		seat.MaxSpeed = 0
		seat.Torque = 0
		seat.TurnSpeed = 0
		seat.HeadsUpDisplay = false
		seat.Disabled = preview == true
		seat.Parent = model
		mk(model, "Back", "Part", Vector3.new(1.4, 0.9, 0.2), CFrame.new(0, -S / 2 + 1.35, 0.8), Color3.fromRGB(60, 40, 30), Enum.Material.Wood)
		mk(model, "Post", "Part", Vector3.new(0.15, 0.7, 0.15), CFrame.new(0, -S / 2 + 0.85, -0.5), Color3.fromRGB(40, 40, 40), Enum.Material.Metal)
		local wheel = mk(model, "Wheel", "Part", Vector3.new(0.12, 0.9, 0.9),
			CFrame.new(0, -S / 2 + 1.3, -0.5) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(150, 105, 60), Enum.Material.Wood)
		wheel.Shape = Enum.PartType.Cylinder

	elseif cat == "Engine" then
		local len = def.Size[3] * S
		local housing = mk(model, "Main", "Part", Vector3.new(S * 0.9, 1.6, len * 0.95), CFrame.new(0, -0.2, 0), def.Housing,
			def.Style == "paddle" and Enum.Material.WoodPlanks or Enum.Material.Metal)
		local stack = mk(model, "Stack", "Part", Vector3.new(1.0, 0.6, 0.6),
			CFrame.new(0, 1.1, len * 0.3) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(45, 45, 48), Enum.Material.Metal)
		stack.Shape = Enum.PartType.Cylinder
		local att = Instance.new("Attachment")
		att.Name = "Exhaust"
		att.Position = Vector3.new(0, 1.9, len * 0.3)
		att.Parent = housing
		if def.Style ~= "reactor" then
			ShipParts.SmokeEmitter(att, "Smoke", Color3.fromRGB(60, 60, 60), Color3.fromRGB(150, 150, 150), 0.8, 3.5, 2, 6)
		end
		if def.Glow then
			mk(model, "Nozzle", "Part", Vector3.new(1.1, 0.9, 0.15), CFrame.new(0, -0.2, len * 0.475 + 0.05), def.Glow, Enum.Material.Neon)
		end
		if def.Style == "paddle" then
			local wheel = mk(model, "PaddleWheel", "Part", Vector3.new(1.7, 2.2, 2.2), CFrame.new(0, -0.3, len / 2 + 0.7), Color3.fromRGB(110, 75, 45), Enum.Material.WoodPlanks)
			wheel.Shape = Enum.PartType.Cylinder
		elseif def.Style == "reactor" then
			for _, sx in ipairs({ -0.55, 0.55 }) do
				mk(model, "Strip", "Part", Vector3.new(0.15, 0.15, len * 0.8), CFrame.new(sx, 0.62, 0), def.Glow, Enum.Material.Neon)
			end
		end

	elseif cat == "Weapon" then
		local v = def.Vis
		local sx, sy, sz = def.Size[1] * S, def.Size[2] * S, def.Size[3] * S
		local baseH = 0.8
		local baseCY = -sy / 2 + baseH / 2
		mk(model, "Main", "Part", Vector3.new(sx * 0.92, baseH, sz * 0.92), CFrame.new(0, baseCY, 0), Color3.fromRGB(48, 50, 56), Enum.Material.Metal)
		local turCY = -sy / 2 + baseH + v.Housing.Y / 2
		mk(model, "Turret", "Part", v.Housing, CFrame.new(0, turCY, 0), def.Color, Enum.Material.Metal)
		for i, b in ipairs(v.Barrels) do
			local z = -(v.Housing.Z / 2 + b.Len / 2 - 0.2)
			mk(model, "T_Barrel" .. i, "Part", Vector3.new(b.Thick, b.Thick, b.Len), CFrame.new(b.X, turCY + (b.Y or 0), z),
				b.Neon and def.Accent or Color3.fromRGB(32, 33, 36), b.Neon and Enum.Material.Neon or Enum.Material.Metal)
		end
	end

	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanQuery = true
			p.CanCollide = (cat == "Armor") and not preview
			p.CanTouch = p:IsA("VehicleSeat")
		end
	end
	scaleModel(model, ShipParts.SCALE)
	model.WorldPivot = CFrame.new()
	return model
end

return ShipParts