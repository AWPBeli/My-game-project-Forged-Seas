local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local TechConfig = require(ReplicatedStorage:WaitForChild("TechConfig"))
local ShipParts = require(ReplicatedStorage:WaitForChild("ShipParts"))
local WorldConfig = require(ReplicatedStorage:WaitForChild("WorldConfig"))
-- loads a helper script safely: if it is missing or broken the game still starts (and says why in Output)
local function safeRequire(parent, name, standIn)
	local mod = parent:WaitForChild(name, 5)
	if mod then
		local ok, result = pcall(require, mod)
		if ok then return result end
		warn("[BoatService] '" .. name .. "' failed to load: " .. tostring(result))
	else
		warn("[BoatService] '" .. name .. "' was not found in " .. parent.Name .. " (check the name and that it is a ModuleScript)")
	end
	return standIn
end

local Waves = safeRequire(ReplicatedStorage, "Waves", {
	Strength = 0, ShipTilt = 0, Drift = 0, Direction = Vector3.zero,
	Now = function() return 0 end,
	Sample = function() return 0, 0, 0 end,
})
local PlayerData = require(ServerScriptService:WaitForChild("PlayerData"))
local Sfx = safeRequire(ServerScriptService, "Sfx", { Play = function() end })
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local BoatService = {}
BoatService.Boats = {}        -- [Model] = ship
BoatService.PlayerBoats = {}  -- [Player] = ship

local S = ShipParts.CELL
local U = ShipParts.SCALE or 1
local SHIP_Y = -0.8 * U -- keel sits this far below the mean water level (y = 0)
local SAFE_RADIUS = WorldConfig.Harbor.Radius

local boatsFolder = Instance.new("Folder")
boatsFolder.Name = "Boats"
boatsFolder.Parent = workspace
local projFolder = Instance.new("Folder")
projFolder.Name = "Projectiles"
projFolder.Parent = workspace

local projectiles = {}
local buildCooldown = {}

local function notify(player, text)
	Remotes.Notify:FireClient(player, text)
end

-- a glowing ball that grows and fades (sizes are given at the old scale and multiplied by U here)
local function effect(pos, size, color)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = Vector3.one
	p.Position = pos
	p.Parent = workspace
	TweenService:Create(p, TweenInfo.new(0.4), { Size = Vector3.one * size * U, Transparency = 1 }):Play()
	Debris:AddItem(p, 0.6)
end

function BoatService.ToList(analysis)
	local list = {}
	for _, blk in ipairs(analysis.Blocks) do
		table.insert(list, { Id = blk.Def.Id, X = blk.X, Y = blk.Y, Z = blk.Z, R = blk.R })
	end
	return list
end

-- SHIP STATE -----------------------------------------------------------------

local function aliveCount(ship)
	local n = 0
	for _, b in ipairs(ship.Blocks) do
		if b.Alive then n += 1 end
	end
	return n
end

-- speed / turning / range depend on what is still attached
local function recompute(ship)
	local mass, thrust, range = 0, 0, 0
	for _, b in ipairs(ship.Blocks) do
		if b.Alive then
			mass += b.Def.Mass
			if b.Def.Category == "Engine" then
				thrust += b.Def.Thrust
			elseif b.Def.Category == "Weapon" then
				range = math.max(range, b.Def.Range)
			end
		end
	end
	ship.Stats = ShipParts.DriveStats(mass, thrust)
	ship.Range = range
	if ship.LV.Parent then
		ship.LV.MaxForce = ship.PhysMass * ship.Stats.Accel
	end
	ship.Model:SetAttribute("Blocks", aliveCount(ship))
	ship.Model:SetAttribute("TopSpeed", math.floor(ship.Stats.MaxSpeed))
end

-- detach a block from the ship and let it fly off / fall into the sea
local function release(blk, center, power)
	blk.Alive = false
	for _, p in ipairs(blk.Model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
		end
	end
	if blk.RootWeld then blk.RootWeld:Destroy() end
	local main = blk.Main
	if main and main.Parent then
		local away = main.Position - center
		away = away.Magnitude > 0.1 and away.Unit or Vector3.yAxis
		main.AssemblyLinearVelocity = away * power + Vector3.new(math.random(-6, 6), math.random(10, 26), math.random(-6, 6))
		main.AssemblyAngularVelocity = Vector3.new(math.random(-6, 6), math.random(-6, 6), math.random(-6, 6))
	end
	Debris:AddItem(blk.Model, 5)
end

local function removeBlock(ship, blk, power)
	if not blk.Alive then return end
	for _, c in ipairs(blk.Cells) do
		ship.Occ[ShipParts.Key(c[1], c[2], c[3])] = nil
	end
	release(blk, ship.Hull.Position, power)
	if blk == ship.HelmBlock then
		local occupant = ship.Seat and ship.Seat.Occupant
		if occupant then occupant.Health = 0 end -- the captain is lost with the helm
	end
end

-- anything no longer connected to the core breaks off
local function cutLoose(ship)
	local seen = { [ship.CoreBlock] = true }
	local queue, qi = { ship.CoreBlock }, 1
	while qi <= #queue do
		local blk = queue[qi]
		qi += 1
		for _, c in ipairs(blk.Cells) do
			for _, d in ipairs(ShipParts.DIRS) do
				local idx = ship.Occ[ShipParts.Key(c[1] + d[1], c[2] + d[2], c[3] + d[3])]
				local other = idx and ship.Blocks[idx]
				if other and other.Alive and not seen[other] then
					seen[other] = true
					table.insert(queue, other)
				end
			end
		end
	end
	for _, blk in ipairs(ship.Blocks) do
		if blk.Alive and not seen[blk] then
			removeBlock(ship, blk, 8)
		end
	end
end

local function markDamaged(blk)
	if blk.Marked then return end
	blk.Marked = true
	local main = blk.Main
	main.Color = main.Color:Lerp(Color3.fromRGB(20, 20, 20), 0.4)
	local att = Instance.new("Attachment")
	att.Position = Vector3.new(0, 1.2 * U, 0)
	att.Parent = main
	local smoke = ShipParts.SmokeEmitter(att, "DamageSmoke", Color3.fromRGB(35, 35, 35), Color3.fromRGB(120, 120, 120), 0.8 * U, 3 * U, 2, 4 * U)
	smoke.Rate = 8
	if blk.Def.Category == "Core" then
		local fire = Instance.new("Fire")
		fire.Size = 6 * U
		fire.Heat = 8
		fire.Parent = main
	end
end

local function killBlock(ship, blk)
	if blk == ship.CoreBlock then
		BoatService.Destroy(ship, true) -- the heart of the ship is gone
		return
	end
	Sfx.Play("BlockBreak", blk.Main.Position)
	effect(blk.Main.Position, 6, Color3.fromRGB(255, 160, 60))
	removeBlock(ship, blk, 18)
	cutLoose(ship)
	recompute(ship)
end

function BoatService.DamageBlock(ship, blk, amount, attacker)
	if not ship.Alive or not blk or not blk.Alive then return end
	if ship.InSafe then return end -- nobody can be hurt inside the Home Harbor
	blk.HP -= amount
	ship.LastAttacker = attacker
	if blk == ship.CoreBlock then
		ship.Model:SetAttribute("CoreHP", math.max(0, math.floor(blk.HP)))
	end
	if blk.HP <= 0 then
		killBlock(ship, blk)
	elseif blk.HP < blk.MaxHP * 0.5 then
		markDamaged(blk)
	end
end

function BoatService.Destroy(ship, killed)
	if not ship.Alive then return end
	ship.Alive = false
	BoatService.Boats[ship.Model] = nil
	if ship.Owner and BoatService.PlayerBoats[ship.Owner] == ship then
		BoatService.PlayerBoats[ship.Owner] = nil
	end

	if not killed then
		ship.Model:Destroy()
		return
	end

	local center = ship.Hull.Position
	Sfx.Play("ShipExplode", center)
	effect(center + Vector3.new(0, 4, 0), 36, Color3.fromRGB(255, 130, 40))
	effect(center + Vector3.new(0, 4, 0), 20, Color3.fromRGB(255, 240, 160))

	local killer = ship.LastAttacker
	if killer and killer.Owner and killer ~= ship then
		local cfg = TechConfig.XPReward
		local reward = cfg.Base + ship.Cost * cfg.PerCost
		if not ship.IsAI then reward *= cfg.PlayerMultiplier end
		reward = math.floor(reward)
		PlayerData.AddXP(killer.Owner, reward)
		notify(killer.Owner, ("Ship destroyed! +%d XP"):format(reward))
	end

	local occupant = ship.Seat and ship.Seat.Occupant
	if occupant then occupant.Health = 0 end
	if ship.Owner then notify(ship.Owner, "Your ship's core was destroyed!") end

	ship.Wake.Rate = 0
	ship.Spray.Rate = 0
	for _, blk in ipairs(ship.Blocks) do
		if blk.Alive then release(blk, center, 30) end
	end
	ship.LV:Destroy()
	ship.AO:Destroy()
	ship.AP:Destroy()
	Debris:AddItem(ship.Model, 6)
end

function BoatService.RemovePlayerBoat(player)
	local ship = BoatService.PlayerBoats[player]
	if ship then BoatService.Destroy(ship, false) end
end

-- BUILDING ---------------------------------------------------------------------

function BoatService.Build(spawnCFrame, analysis, owner, faction)
	local _, yaw = spawnCFrame:ToOrientation()
	local shipCF = CFrame.new(spawnCFrame.Position.X, SHIP_Y, spawnCFrame.Position.Z) * CFrame.Angles(0, yaw, 0)

	-- centre of mass: the ship turns around this point
	local sx, sy, sz, tm = 0, 0, 0, 0
	for _, blk in ipairs(analysis.Blocks) do
		local p, m = blk.CFrame.Position, blk.Def.Mass
		sx += p.X * m
		sy += p.Y * m
		sz += p.Z * m
		tm += m
	end
	local com = Vector3.new(sx / tm, sy / tm, sz / tm)

	local model = Instance.new("Model")
	model.Name = owner and ("Ship_" .. owner.UserId) or "AIShip"

	-- invisible root: carries the mass and all the physics constraints
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(4, 1, 6)
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Anchored = true
	root.CFrame = shipCF * CFrame.new(com)
	local physMass = math.max(analysis.Mass * 4, 150)
	root.CustomPhysicalProperties = PhysicalProperties.new(math.clamp(physMass / 24, 0.1, 100), 0.3, 0, 1, 1)
	root.Parent = model
	model.PrimaryPart = root

	-- one visual model per block
	local blocks, weapons = {}, {}
	local coreBlock, helmBlock
	for i, blk in ipairs(analysis.Blocks) do
		local def = blk.Def
		local vis = ShipParts.CreateVisual(def, false)
		vis:SetAttribute("Idx", i)
		vis:PivotTo(shipCF * blk.CFrame)
		vis.Parent = model
		local e = {
			Index = i, Def = def, Model = vis, Main = vis:FindFirstChild("Main"),
			HP = def.HP, MaxHP = def.HP, Alive = true, Cells = blk.Cells,
			Turret = {}, Yaw = 0, LastFire = 0,
			TurnSpeed = math.clamp(3.2 - def.Mass * 0.2, 1.2, 3),
		}
		blocks[i] = e
		if def.Category == "Core" then
			coreBlock = e
		elseif def.Id == "Helm" then
			helmBlock = e
		elseif def.Category == "Weapon" then
			table.insert(weapons, e)
		end
	end

	-- faction paint + flag at the helm
	local fdata = faction and (WorldConfig.Factions[faction] or (faction == "Pirates" and WorldConfig.Pirates))
	if fdata then
		for _, e in ipairs(blocks) do
			if e.Def.Category == "Armor" then
				e.Main.Color = e.Main.Color:Lerp(fdata.Color, 0.35)
			end
		end
		local hcf = shipCF * analysis.Blocks[helmBlock.Index].CFrame
		local function flagPart(name, size, offset, color, material)
			local p = Instance.new("Part")
			p.Name = name
			p.Size = size
			p.CFrame = hcf * offset
			p.Color = color
			p.Material = material
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Parent = helmBlock.Model
		end
		flagPart("FlagPole", Vector3.new(0.2, 4, 0.2) * U, CFrame.new(0.85 * U, 2 * U, 0.85 * U), Color3.fromRGB(60, 60, 65), Enum.Material.Metal)
		flagPart("FactionFlag", Vector3.new(0.1, 1.5, 2.4) * U, CFrame.new(0.85 * U, 3.4 * U, 2.1 * U), fdata.Color, Enum.Material.Neon)
	end

	model.Parent = boatsFolder

	-- weld everything (still anchored), turret parts get a rotatable Weld
	for _, e in ipairs(blocks) do
		local main = e.Main
		local isWeapon = e.Def.Category == "Weapon"
		for _, p in ipairs(e.Model:GetDescendants()) do
			if p:IsA("BasePart") and p ~= main then
				p.Massless = true
				if isWeapon and (p.Name == "Turret" or p.Name:sub(1, 2) == "T_") then
					local rel = main.CFrame:ToObjectSpace(p.CFrame)
					local w = Instance.new("Weld")
					w.Part0 = main
					w.Part1 = p
					w.C0 = rel
					w.C1 = CFrame.new()
					w.Parent = p
					table.insert(e.Turret, { Weld = w, Rel = rel })
				else
					local w = Instance.new("WeldConstraint")
					w.Part0 = main
					w.Part1 = p
					w.Parent = p
				end
			end
		end
		main.Massless = true
		local rw = Instance.new("WeldConstraint")
		rw.Part0 = root
		rw.Part1 = main
		rw.Parent = main
		e.RootWeld = rw
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = false end
	end

	-- physics: ride the swell (height + tilt are driven every frame), slide toward a target velocity
	local mass = root.AssemblyMass
	local holdY = SHIP_Y + com.Y
	local att = Instance.new("Attachment")
	att.Name = "DriveAttachment"
	att.Parent = root

	local ap = Instance.new("AlignPosition")
	ap.Mode = Enum.PositionAlignmentMode.OneAttachment
	ap.Attachment0 = att
	ap.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	ap.MaxAxesForce = Vector3.new(0, mass * workspace.Gravity * 10, 0)
	ap.Position = Vector3.new(0, holdY, 0)
	ap.Responsiveness = 16
	ap.RigidityEnabled = false
	ap.ApplyAtCenterOfMass = true
	ap.Parent = root

	local ao = Instance.new("AlignOrientation")
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.RigidityEnabled = false
	ao.MaxTorque = 1e9
	ao.Responsiveness = 12
	ao.CFrame = CFrame.Angles(0, yaw, 0)
	ao.Parent = root

	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.xAxis
	lv.SecondaryTangentAxis = Vector3.zAxis
	lv.PlaneVelocity = Vector2.zero
	lv.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	lv.MaxForce = mass * 10
	lv.Parent = root

	-- wake + bow spray (waterline is local y = -(hover height))
	local waterLocalY = -holdY
	local sternAtt = Instance.new("Attachment")
	sternAtt.Position = Vector3.new(0, waterLocalY, analysis.MaxZ * S + S / 2 - com.Z)
	sternAtt.Parent = root
	local bowAtt = Instance.new("Attachment")
	bowAtt.Position = Vector3.new(0, waterLocalY + 0.3 * U, analysis.MinZ * S - S / 2 - com.Z)
	bowAtt.Parent = root
	local wake = ShipParts.SmokeEmitter(sternAtt, "Wake", Color3.new(1, 1, 1), Color3.fromRGB(190, 225, 255), 2 * U, 7 * U, 1.8, 3 * U)
	wake.SpreadAngle = Vector2.new(85, 85)
	local spray = ShipParts.SmokeEmitter(bowAtt, "Spray", Color3.new(1, 1, 1), Color3.new(1, 1, 1), 0.6 * U, 2.4 * U, 0.8, 8 * U)
	spray.SpreadAngle = Vector2.new(30, 30)

	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = { model }

	local occ = {}
	for k, v in pairs(analysis.Occ) do occ[k] = v end

	local ship = {
		Model = model, Hull = root, Seat = helmBlock.Model:FindFirstChild("Seat"),
		Owner = owner, IsAI = owner == nil,
		Blocks = blocks, Weapons = weapons, Occ = occ, CoreBlock = coreBlock, HelmBlock = helmBlock,
		Alive = true, Cost = analysis.Cost, Yaw = yaw, PhysMass = mass, HoldY = holdY, WaveTimer = 0,
		LV = lv, AO = ao, AP = ap, Wake = wake, Spray = spray, FxTimer = 0,
		RayParams = rp, AimPos = nil, Firing = false, Range = 0,
		Stats = { MaxSpeed = 0, Accel = 5, Turn = 0.3 },
		AIInput = owner == nil and { Throttle = 0, Steer = 0 } or nil,
	}
	model:SetAttribute("CoreHP", coreBlock.HP)
	model:SetAttribute("CoreMaxHP", coreBlock.MaxHP)
	model:SetAttribute("TotalBlocks", #blocks)
	model:SetAttribute("OwnerName", owner and owner.Name or "Pirate")
	model:SetAttribute("Faction", faction or "")
	recompute(ship)

	BoatService.Boats[model] = ship
	if owner then BoatService.PlayerBoats[owner] = ship end
	return ship
end

-- WEAPONS -----------------------------------------------------------------------

local function applyYaw(blk)
	local rot = CFrame.Angles(0, blk.Yaw, 0)
	for _, t in ipairs(blk.Turret) do
		t.Weld.C0 = rot * t.Rel
	end
end

local function fireWeapon(ship, blk)
	local def = blk.Def
	local base = blk.Main.CFrame * CFrame.new(0, (0.4 + def.Vis.Housing.Y / 2) * U, 0) * CFrame.Angles(0, blk.Yaw, 0)
	Sfx.Play(def.Id, base.Position, 1)
	for _, m in ipairs(def.Muzzles) do
		local muzzle = base:PointToWorldSpace(m * U)
		local aim = ship.AimPos - muzzle
		if aim.Magnitude >= 1 then
			local dir = aim.Unit
			local pr = def.Proj
			local size = pr.Size * U

			local part = Instance.new("Part")
			part.Size = size
			part.Color = pr.Color
			part.Material = Enum.Material.Neon
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CFrame = CFrame.lookAt(muzzle, muzzle + dir)

			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(0, size.Y / 2, 0)
			a0.Parent = part
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(0, -size.Y / 2, 0)
			a1.Parent = part
			local trail = Instance.new("Trail")
			trail.Attachment0 = a0
			trail.Attachment1 = a1
			trail.Lifetime = 0.25
			trail.Color = ColorSequence.new(pr.Color)
			trail.LightEmission = 1
			trail.Transparency = NumberSequence.new(0.2, 1)
			trail.Parent = part
			if def.Splash > 0 then
				local smoke = ShipParts.SmokeEmitter(a1, "Smoke", Color3.fromRGB(210, 210, 210), Color3.fromRGB(120, 120, 120), 0.9 * U, 2.4 * U, 1.2, 1)
				smoke.Rate = 45
			end
			part.Parent = projFolder

			table.insert(projectiles, {
				Part = part, Pos = muzzle, Dir = dir, Speed = def.Speed, Damage = def.Damage,
				Range = def.Range, Splash = def.Splash, Traveled = 0, Owner = ship,
			})
			effect(muzzle, math.clamp(def.Damage / 15, 1.5, 5), Color3.fromRGB(255, 225, 150))
		end
	end
end

local function stepWeapons(ship, dt, now)
	for _, blk in ipairs(ship.Weapons) do
		if blk.Alive then
			local desired = blk.Yaw
			if ship.AimPos then
				local cf = blk.Main.CFrame
				local ld = cf:VectorToObjectSpace(ship.AimPos - cf.Position)
				desired = math.atan2(-ld.X, -ld.Z)
			end
			local diff = (desired - blk.Yaw + math.pi) % (2 * math.pi) - math.pi
			local maxStep = blk.TurnSpeed * dt
			local step = math.clamp(diff, -maxStep, maxStep)
			if math.abs(step) > 0.0005 then
				blk.Yaw += step
				applyYaw(blk)
			end
			-- fire once the turret points at the target (never inside the harbor)
			if ship.Firing and not ship.InSafe and ship.AimPos and math.abs(diff - step) < 0.1 and now - blk.LastFire >= blk.Def.Cooldown then
				blk.LastFire = now
				fireWeapon(ship, blk)
			end
		end
	end
end

local function lookup(inst)
	local m = inst:FindFirstAncestorOfClass("Model")
	if not m then return nil end
	local ship = BoatService.Boats[m.Parent]
	if ship then
		local idx = m:GetAttribute("Idx")
		return ship, idx and ship.Blocks[idx]
	end
	-- hit a captain sitting at the helm? count it as hitting the helm
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum and hum.SeatPart then
		local sm = hum.SeatPart:FindFirstAncestorOfClass("Model")
		local s = sm and BoatService.Boats[sm.Parent]
		if s then return s, s.HelmBlock end
	end
	return nil
end

-- inst = what was hit (nil means the shell hit the water)
local function onProjectileHit(p, inst, pos)
	local attacker = p.Owner
	local ship, blk
	if inst then ship, blk = lookup(inst) end
	if ship and ship ~= attacker and not (ship.IsAI and attacker.IsAI) then
		BoatService.DamageBlock(ship, blk, p.Damage, attacker)
	end

	if not inst then
		Sfx.Play("Splash", pos, math.clamp(p.Damage / 40, 0.6, 1.4))
		effect(pos, math.max(p.Splash * 0.6, 3), Color3.fromRGB(190, 225, 255))
	else
		Sfx.Play(ship and "Hit" or "HitRock", pos, math.clamp(p.Damage / 40, 0.6, 1.5))
		effect(pos, p.Splash > 0 and p.Splash * 0.6 or 4, Color3.fromRGB(255, 170, 60))
	end

	if p.Splash > 0 then
		Sfx.Play("Explosion", pos, 1)
		local radius = p.Splash * U -- the blast covers the same number of blocks as before
		for _, other in pairs(BoatService.Boats) do
			if other.Alive and other ~= attacker and not (other.IsAI and attacker.IsAI)
				and (other.Hull.Position - pos).Magnitude <= radius + 30 * U then
				for _, b in ipairs(other.Blocks) do
					if b.Alive and b ~= blk then
						local d = (b.Main.Position - pos).Magnitude
						if d <= radius then
							BoatService.DamageBlock(other, b, p.Damage * 0.35 * (1 - d / radius), attacker)
						end
					end
				end
			end
		end
	end
end

local function stepProjectiles(dt)
	local t = Waves.Now()
	for i = #projectiles, 1, -1 do
		local p = projectiles[i]
		local step = p.Dir * p.Speed * dt
		local result = workspace:Raycast(p.Pos, step, p.Owner.RayParams)

		local hitInst, hitPos
		if result and result.Instance.Name ~= "Ocean" then
			hitInst, hitPos = result.Instance, result.Position
		else
			-- the sea is the moving swell, not the flat floor underneath it
			local np = p.Pos + step
			local wh = Waves.Sample(np.X, np.Z, t)
			if np.Y <= wh then hitPos = Vector3.new(np.X, wh, np.Z) end
		end

		if hitPos then
			onProjectileHit(p, hitInst, hitPos)
			p.Part:Destroy()
			table.remove(projectiles, i)
		else
			p.Pos += step
			p.Traveled += step.Magnitude
			if p.Traveled >= p.Range then
				p.Part:Destroy()
				table.remove(projectiles, i)
			else
				p.Part.CFrame = CFrame.lookAt(p.Pos, p.Pos + p.Dir)
			end
		end
	end
end

-- DRIVING + WATER ------------------------------------------------------------------

local function stepBoats(dt)
	local now = os.clock()
	local t = Waves.Now()
	for _, ship in pairs(BoatService.Boats) do
		if ship.Alive then
			local pos = ship.Hull.Position
			ship.InSafe = (pos.X * pos.X + pos.Z * pos.Z) <= SAFE_RADIUS * SAFE_RADIUS

			local throttle, steer
			if ship.AIInput then
				throttle, steer = ship.AIInput.Throttle, ship.AIInput.Steer
			elseif ship.Seat and ship.Seat.Occupant then
				throttle, steer = ship.Seat.ThrottleFloat, ship.Seat.SteerFloat
			else
				throttle, steer = 0, 0
				ship.Firing = false
			end
			if throttle < 0 then throttle *= 0.4 end

			local maxSpeed = math.max(ship.Stats.MaxSpeed, 1)
			local vel = ship.Hull.AssemblyLinearVelocity
			local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
			local ratio = math.clamp(speed / maxSpeed, 0, 1)
			local turnFactor = math.clamp(ratio + 0.3, 0.3, 1)

			ship.Yaw -= steer * ship.Stats.Turn * dt * turnFactor -- steer +1 = right = yaw decreases
			local rot = CFrame.Angles(0, ship.Yaw, 0)
			local fwd, rgt = rot.LookVector, rot.RightVector

			-- the swell: tilt with the wave slope, heel outward in turns, lift the bow when accelerating
			local h, sx, sz = Waves.Sample(pos.X, pos.Z, t)
			local pitch = math.atan((sx * fwd.X + sz * fwd.Z) * Waves.ShipTilt) + throttle * ratio * 0.03
			local roll = math.atan((sx * rgt.X + sz * rgt.Z) * Waves.ShipTilt) + steer * ratio * 0.1
			ship.AO.CFrame = rot * CFrame.Angles(pitch, 0, roll)

			ship.WaveTimer -= dt
			if ship.WaveTimer <= 0 then
				ship.WaveTimer = 1 / 20
				ship.AP.Position = Vector3.new(0, ship.HoldY + h, 0) -- heave: rise and fall with the water
			end

			local current = Waves.Direction * Waves.Drift * Waves.Strength -- the swell pushes you along
			local v = fwd * (throttle * ship.Stats.MaxSpeed) + current
			ship.LV.PlaneVelocity = Vector2.new(v.X, v.Z)

			stepWeapons(ship, dt, now)

			ship.FxTimer -= dt
			if ship.FxTimer <= 0 then
				ship.FxTimer = 0.25
				ship.Wake.Rate = speed > 2 and math.min(speed * 1.5, 60) or 0
				ship.Spray.Rate = speed > 14 and math.min((speed - 14) * 2, 40) or 0
			end
		end
	end
end

-- PLAYER REQUESTS --------------------------------------------------------------------

function BoatService.PlayerAim(player, pos, firing)
	local ship = BoatService.PlayerBoats[player]
	if not ship or not ship.Alive then return end
	local occ = ship.Seat and ship.Seat.Occupant
	if not occ or occ.Parent ~= player.Character then
		ship.Firing = false
		return
	end
	ship.AimPos = pos
	ship.Firing = firing
	ship.RayParams.FilterDescendantsInstances = { ship.Model, player.Character }
end

function BoatService.PlayerBuild(player, blueprint)
	if buildCooldown[player] and os.clock() - buildCooldown[player] < 2 then return end

	local d = PlayerData.Get(player)
	if not d then
		notify(player, "Your data is still loading, try again in a moment")
		return
	end

	local analysis = ShipParts.Analyze(blueprint, d.Unlocked)
	if not analysis.Ok then
		notify(player, analysis.Problems[1] or "Invalid ship design")
		return
	end

	local cost = analysis.Cost <= TechConfig.FreeBuildBudget and 0 or analysis.Cost
	if d.Money < cost then
		notify(player, ("Not enough money! This ship costs $%d"):format(cost))
		return
	end

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		notify(player, "You need to be alive to launch a ship")
		return
	end
	local spawnPart = workspace:FindFirstChild("BoatSpawn")
	if not spawnPart then
		notify(player, "No 'BoatSpawn' part found in Workspace (did the map generate?)")
		return
	end

	buildCooldown[player] = os.clock()
	BoatService.RemovePlayerBoat(player) -- scrap the old ship (no refund)

	local built, ship = xpcall(BoatService.Build, debug.traceback, spawnPart.CFrame, analysis, player)
	if not built then
		warn("[BoatService] Build failed:\n" .. tostring(ship))
		notify(player, "Ship build error - check the Output window")
		return
	end

	PlayerData.SpendMoney(player, cost)
	PlayerData.SetDesign(player, BoatService.ToList(analysis))

	char:SetAttribute("Launching", true) -- the sea can't hurt you while you get seated
	char:PivotTo(ship.Seat.CFrame * CFrame.new(0, 2 * U, 0))
	for _ = 1, 25 do
		if not ship.Alive or not hum.Parent or hum.SeatPart == ship.Seat then break end
		pcall(function() ship.Seat:Sit(hum) end)
		task.wait(0.1)
	end
	if ship.Alive and hum.Parent and hum.SeatPart ~= ship.Seat then
		warn("[BoatService] The captain could not sit at the helm")
		notify(player, "Could not seat you at the helm - check the Output window")
	end
	task.delay(3, function()
		if char.Parent then char:SetAttribute("Launching", nil) end
	end)
	notify(player, "Ship launched! WASD to drive, hold click to fire.")
end

function BoatService.Init()
	RunService.Heartbeat:Connect(function(dt)
		stepBoats(dt)
		stepProjectiles(dt)
	end)

	local function hook(player)
		player.CharacterRemoving:Connect(function()
			BoatService.RemovePlayerBoat(player)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in ipairs(Players:GetPlayers()) do hook(p) end
	Players.PlayerRemoving:Connect(function(p)
		BoatService.RemovePlayerBoat(p)
		buildCooldown[p] = nil
	end)
end

return BoatService