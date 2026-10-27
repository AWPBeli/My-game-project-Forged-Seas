local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Waves = require(ReplicatedStorage:WaitForChild("Waves"))
local WorldConfig = require(ReplicatedStorage:WaitForChild("WorldConfig"))
workspace:WaitForChild("OceanTiles") -- only draw the moving water once the world has been built

-- SETTINGS ----------------------------------------------------------------------------
local TILE = 30           -- bigger tiles = fewer parts (faster) but slightly more faceted
local COUNT = 50          -- 25 x 25 tiles = about 480 studs around you. Lower it on slow devices
local THICK = 4
local OVERLAP = 0         -- if you ever see hairline cracks between tiles, try 1.5
local UPDATE_RATE = 20    -- water updates per second
local FOAM_STRENGTH = 0.25   -- 0 = one even colour (smoothest and fastest). Try 0.25 for lighter wave crests
local HARBOR_RANGE = 800  -- buoys and floating crates only update when you are this close to the harbor
-----------------------------------------------------------------------------------------

local HALF = (COUNT - 1) / 2
local TILE_COLOR = Color3.fromRGB(20, 90, 160)
local FOAM = Color3.fromRGB(190, 225, 245)

local folder = Instance.new("Folder")
folder.Name = "WaterLocal"
folder.Parent = workspace

local tiles, cfs = {}, {}
for n = 1, COUNT * COUNT do
	local p = Instance.new("Part")
	p.Name = "WaterTile"
	p.Size = Vector3.new(TILE + OVERLAP, THICK, TILE + OVERLAP)
	p.Color = TILE_COLOR
	p.Material = Enum.Material.SmoothPlastic
	p.Reflectance = 0 -- no reflection = no colour glints when the camera moves
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = folder
	tiles[n] = p
	cfs[n] = CFrame.new(0, -50, 0)
end

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- harbor buoys bob on the swell
local buoyParts, buoyBases, buoyMoves = {}, {}, {}
task.spawn(function()
	local terr = workspace:WaitForChild("Territories", 60)
	local harbor = terr and terr:WaitForChild(WorldConfig.Harbor.Name, 60)
	if not harbor then return end
	for _, d in ipairs(harbor:GetChildren()) do
		if d.Name == "Buoy" or d.Name == "BuoyLight" then
			table.insert(buoyParts, d)
			table.insert(buoyBases, d.CFrame)
		end
	end
end)

-- floating crates and barrels drift along with the swell
local flotsam, flotParts, flotMoves = {}, {}, {}
for i = 1, 24 do
	local barrel = i % 2 == 0
	local p = Instance.new("Part")
	p.Name = "Flotsam"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	if barrel then
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(5, 4, 4)
		p.Color = Color3.fromRGB(125, 62, 50)
		p.Material = Enum.Material.Metal
	else
		p.Size = Vector3.new(4.5, 4.5, 4.5)
		p.Color = Color3.fromRGB(150, 110, 65)
		p.Material = Enum.Material.WoodPlanks
	end
	p.Parent = folder
	local a = math.random() * math.pi * 2
	local d = 140 + math.random() * 300
	flotsam[i] = { X = math.cos(a) * d, Z = math.sin(a) * d, Spin = math.random() * 6.28, Barrel = barrel }
	flotParts[i] = p
	flotMoves[i] = p.CFrame
end

local function update(dt)
	local cam = workspace.CurrentCamera
	if cam.CameraType == Enum.CameraType.Scriptable then return end -- Drydock: the sea is not on screen
	local camPos = cam.CFrame.Position
	local gx = math.floor(camPos.X / TILE + 0.5) * TILE
	local gz = math.floor(camPos.Z / TILE + 0.5) * TILE
	local t = Waves.Now()

	local n = 0
	for i = -HALF, HALF do
		for j = -HALF, HALF do
			n += 1
			local x, z = gx + i * TILE, gz + j * TILE
			-- the swell flattens near the edge of the water ring so the edge is invisible
			local edge = math.max(math.abs(i), math.abs(j)) / HALF
			local fade = 1 - smooth((edge - 0.78) / 0.22)
			local h, sx, sz = Waves.Sample(x, z, t)
			h *= fade
			sx *= fade
			sz *= fade
			local vx = Vector3.new(1, sx, 0).Unit
			local normal = Vector3.new(-sx, 1, -sz).Unit
			local lift = (OVERLAP > 0 and (i + j) % 2 == 0) and 0.15 or 0 -- overlapping tiles never fight over the same depth
			cfs[n] = CFrame.fromMatrix(Vector3.new(x, h, z), vx, normal) * CFrame.new(0, -THICK / 2 + 0.1 + lift, 0)
			if FOAM_STRENGTH > 0 then
				tiles[n].Color = TILE_COLOR:Lerp(FOAM, math.clamp((h - 0.8) / 2.2, 0, 1) * FOAM_STRENGTH)
			end
		end
	end
	workspace:BulkMoveTo(tiles, cfs, Enum.BulkMoveMode.FireCFrameChanged)

	-- buoys + flotsam only matter near the harbor
	if camPos.X * camPos.X + camPos.Z * camPos.Z > HARBOR_RANGE * HARBOR_RANGE then return end

	if #buoyParts > 0 then
		for k, base in ipairs(buoyBases) do
			local p = base.Position
			buoyMoves[k] = base + Vector3.new(0, (Waves.Sample(p.X, p.Z, t)), 0)
		end
		workspace:BulkMoveTo(buoyParts, buoyMoves, Enum.BulkMoveMode.FireCFrameChanged)
	end

	local drift = Waves.Direction * Waves.Drift * Waves.Strength * 2
	for k, f in ipairs(flotsam) do
		f.X += drift.X * dt
		f.Z += drift.Z * dt
		local m = math.sqrt(f.X * f.X + f.Z * f.Z)
		if m > 460 then
			f.X, f.Z = -f.X / m * 440, -f.Z / m * 440
		end
		f.Spin += dt * 0.15
		local h, sx, sz = Waves.Sample(f.X, f.Z, t)
		local vx = Vector3.new(1, sx, 0).Unit
		local normal = Vector3.new(-sx, 1, -sz).Unit
		local cf = CFrame.fromMatrix(Vector3.new(f.X, h + 0.3, f.Z), vx, normal) * CFrame.Angles(0, f.Spin, 0)
		if f.Barrel then cf = cf * CFrame.Angles(0, 0, math.rad(90)) end
		flotMoves[k] = cf
	end
	workspace:BulkMoveTo(flotParts, flotMoves, Enum.BulkMoveMode.FireCFrameChanged)
end

local acc = 0
RunService.RenderStepped:Connect(function(dt)
	acc += dt
	if acc < 1 / UPDATE_RATE then return end
	local step = acc
	acc = 0
	update(step)
end)