local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local TechConfig = require(ReplicatedStorage:WaitForChild("TechConfig"))
local ShipParts = require(ReplicatedStorage:WaitForChild("ShipParts"))
local Blueprints = require(ReplicatedStorage:WaitForChild("Blueprints"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Audio = { UI = function() end, Play3D = function() end } -- silent until ClientAudio loads
task.spawn(function()
	local mod = script.Parent:WaitForChild("ClientAudio", 10)
	if not mod then
		warn("[GameUI] 'ClientAudio' was not found next to GameUI - sound is off")
		return
	end
	local ok, result = pcall(require, mod)
	if ok and type(result) == "table" then
		Audio = result
	else
		warn("[GameUI] ClientAudio failed to load - sound is off: " .. tostring(result))
	end
end)

local S = ShipParts.CELL
local GRID = ShipParts.GRID
local XMAX = (GRID.W - 1) // 2
local ZMAX = (GRID.L - 1) // 2
local BAY = Vector3.new(0, 500, 0) -- the drydock floats high above the map (only you can see it)

local state = { Money = 0, XP = 0, Unlocked = {} }
local drydockOpen, researchOpen, firing = false, false, false

local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end

local DARK = Color3.fromRGB(15, 20, 30)
local PANEL = Color3.fromRGB(22, 28, 40)
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 200, 90)
local GREEN = Color3.fromRGB(40, 150, 80)
local RED = Color3.fromRGB(200, 60, 60)

local gui = make("ScreenGui", { Name = "DepthsUI", ResetOnSpawn = false, IgnoreGuiInset = true }, player:WaitForChild("PlayerGui"))

-- HUD -----------------------------------------------------------------------------
local hud = make("TextLabel", {
	Size = UDim2.fromOffset(360, 48), Position = UDim2.fromOffset(12, 52),
	BackgroundColor3 = DARK, BackgroundTransparency = 0.25, TextColor3 = WHITE,
	Font = Enum.Font.GothamBold, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top, Text = "",
}, gui)
make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingTop = UDim.new(0, 5) }, hud)

local hpBack = make("Frame", {
	Size = UDim2.fromOffset(360, 22), Position = UDim2.fromOffset(12, 104),
	BackgroundColor3 = Color3.fromRGB(60, 20, 20), Visible = false,
}, gui)
local hpFill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(70, 200, 90), BorderSizePixel = 0 }, hpBack)
local hpText = make("TextLabel", {
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, TextColor3 = WHITE,
	Font = Enum.Font.GothamBold, TextSize = 12, Text = "",
}, hpBack)

make("TextLabel", {
	Size = UDim2.fromOffset(640, 24), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8),
	BackgroundTransparency = 1, TextColor3 = WHITE, TextStrokeTransparency = 0.5, Font = Enum.Font.Gotham, TextSize = 14,
	Text = "WASD: drive   |   Hold left click: fire   |   B: Drydock (build ship)   |   T: Research",
}, gui)

local toastLabel = make("TextLabel", {
	Size = UDim2.fromOffset(480, 36), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 56),
	BackgroundColor3 = DARK, BackgroundTransparency = 0.2, TextColor3 = Color3.fromRGB(255, 220, 120),
	Font = Enum.Font.GothamBold, TextSize = 16, Visible = false, Text = "", ZIndex = 20,
}, gui)
local toastId = 0
local function toast(text)
	toastId += 1
	local mine = toastId
	toastLabel.Text = text
	toastLabel.Visible = true
	task.delay(3.5, function()
		if toastId == mine then toastLabel.Visible = false end
	end)
end

-- RESEARCH PANEL --------------------------------------------------------------------
local research = make("Frame", {
	Size = UDim2.fromOffset(790, 480), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	BackgroundColor3 = PANEL, Visible = false, ZIndex = 5,
}, gui)
make("TextLabel", {
	Text = "RESEARCH  (XP unlocks new ship parts)", Size = UDim2.fromOffset(500, 32), Position = UDim2.fromOffset(10, 6),
	BackgroundTransparency = 1, TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextSize = 20,
	TextXAlignment = Enum.TextXAlignment.Left,
}, research)
local researchClose = make("TextButton", {
	Text = "X", Size = UDim2.fromOffset(32, 28), Position = UDim2.new(1, -42, 0, 8),
	BackgroundColor3 = RED, TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextSize = 16,
}, research)

local unlockText = {}
for _, def in ipairs(ShipParts.List) do
	local cur = unlockText[def.Tech]
	unlockText[def.Tech] = cur and (cur .. ", " .. def.Short) or def.Short
end

local techButtons = {}
local researchTitles = { Core = "CORES", Armor = "ARMOR", Weapon = "WEAPONS", Engine = "ENGINES" }
for i, cat in ipairs(TechConfig.Categories) do
	local x = 10 + (i - 1) * 193
	make("TextLabel", {
		Text = researchTitles[cat], Size = UDim2.fromOffset(185, 26), Position = UDim2.fromOffset(x, 46),
		BackgroundTransparency = 1, TextColor3 = GOLD, Font = Enum.Font.GothamBold, TextSize = 16,
	}, research)
	local list = make("ScrollingFrame", {
		Size = UDim2.fromOffset(185, 400), Position = UDim2.fromOffset(x, 74), BackgroundTransparency = 1,
		BorderSizePixel = 0, ScrollBarThickness = 4, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
	}, research)
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	for order, t in ipairs(TechConfig.Techs) do
		if t.Category == cat then
			local btn = make("TextButton", {
				Size = UDim2.new(1, -8, 0, 92), LayoutOrder = order, TextWrapped = true, TextColor3 = WHITE,
				Font = Enum.Font.Gotham, TextSize = 12, Text = "", ZIndex = 6,
			}, list)
			techButtons[t.Id] = btn
			btn.MouseButton1Click:Connect(function()
				if state.Unlocked[t.Id] then return end
				if t.Requires and not state.Unlocked[t.Requires] then
					toast("Research " .. TechConfig.ById[t.Requires].Name .. " first")
				else
					Remotes.RequestResearch:FireServer(t.Id)
				end
			end)
		end
	end
end

local function refreshResearch()
	for id, btn in pairs(techButtons) do
		local t = TechConfig.ById[id]
		local line, color
		if state.Unlocked[id] then
			line, color = "RESEARCHED", Color3.fromRGB(40, 120, 70)
		elseif t.Requires and not state.Unlocked[t.Requires] then
			line, color = "Locked: needs " .. TechConfig.ById[t.Requires].Name, Color3.fromRGB(50, 50, 55)
		else
			line = ("Click to research: %d XP"):format(t.XPCost)
			color = state.XP >= t.XPCost and Color3.fromRGB(200, 130, 30) or Color3.fromRGB(120, 60, 50)
		end
		btn.BackgroundColor3 = color
		btn.Text = ("%s\n%s\nUnlocks: %s"):format(t.Name, line, unlockText[id] or "-")
	end
end

-- DRYDOCK BAY (client-only parts) ----------------------------------------------------
local bayFolder = Instance.new("Folder")
bayFolder.Name = "DrydockLocal"
bayFolder.Parent = workspace
local placedFolder = Instance.new("Folder")
placedFolder.Name = "Placed"
placedFolder.Parent = bayFolder
local ghostFolder = Instance.new("Folder")
ghostFolder.Name = "Ghosts"
ghostFolder.Parent = bayFolder

local floorPart = make("Part", {
	Name = "Floor", Size = Vector3.new(GRID.W * S + 10, 1, GRID.L * S + 10), CFrame = CFrame.new(BAY - Vector3.new(0, 0.5, 0)),
	Color = Color3.fromRGB(28, 36, 50), Material = Enum.Material.SmoothPlastic, Anchored = true,
}, bayFolder)
local function gridLine(size, offset)
	make("Part", {
		Size = size, CFrame = CFrame.new(BAY + offset), Color = Color3.fromRGB(70, 140, 200), Material = Enum.Material.Neon,
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
	}, bayFolder)
end
for i = 0, GRID.W do
	gridLine(Vector3.new(0.4, 0.05, GRID.L * S), Vector3.new((-XMAX - 0.5 + i) * S, 0.03, 0))
end
for j = 0, GRID.L do
	gridLine(Vector3.new(GRID.W * S, 0.05, 0.4), Vector3.new(0, 0.03, (-ZMAX - 0.5 + j) * S))
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { placedFolder, floorPart }

local placed, occ, modelEntry = {}, {}, {}
local userEdited = false

local function canPlace(def, x, y, z, r)
	if #placed >= ShipParts.MaxBlocks then return false end
	for _, c in ipairs(ShipParts.Footprint(def, x, y, z, r)) do
		if not ShipParts.InBounds(c[1], c[2], c[3]) or occ[ShipParts.Key(c[1], c[2], c[3])] then
			return false
		end
	end
	return true
end

local function addEntry(id, x, y, z, r)
	local def = ShipParts.ById[id]
	if not def or not canPlace(def, x, y, z, r) then return nil end
	local cf, cells = ShipParts.BlockCFrame(def, x, y, z, r)
	local model = ShipParts.CreateVisual(def, true)
	model:PivotTo(CFrame.new(BAY) * cf)
	model.Parent = placedFolder
	local e = { Id = id, X = x, Y = y, Z = z, R = r, Model = model, Cells = cells }
	table.insert(placed, e)
	for _, c in ipairs(cells) do occ[ShipParts.Key(c[1], c[2], c[3])] = e end
	modelEntry[model] = e
	return e
end

local function removeEntry(e)
	local i = table.find(placed, e)
	if i then table.remove(placed, i) end
	for _, c in ipairs(e.Cells) do occ[ShipParts.Key(c[1], c[2], c[3])] = nil end
	modelEntry[e.Model] = nil
	e.Model:Destroy()
end

local function buildList()
	local list = {}
	for _, e in ipairs(placed) do
		table.insert(list, { Id = e.Id, X = e.X, Y = e.Y, Z = e.Z, R = e.R })
	end
	return list
end

local function clearAll()
	for i = #placed, 1, -1 do removeEntry(placed[i]) end
end

local function loadDesign(list)
	clearAll()
	for _, e in ipairs(list) do addEntry(e.Id, e.X, e.Y, e.Z, e.R) end
end

-- mirror helper: finds where the left/right twin of a part goes
local function mirrorPlacement(def, x, y, z, r)
	local cells = ShipParts.Footprint(def, x, y, z, r)
	local orig, target = {}, {}
	for _, c in ipairs(cells) do
		orig[ShipParts.Key(c[1], c[2], c[3])] = true
		target[ShipParts.Key(-c[1], c[2], c[3])] = true
	end
	local overlap = false
	for k in pairs(target) do
		if orig[k] then overlap = true end
	end
	if overlap then return nil end -- centred part: it is its own twin
	local rr = def.Shape == "Corner" and (3 - r) % 4 or (-r) % 4
	for _, c in ipairs(cells) do
		local ax, az = -c[1], c[3]
		local fp = ShipParts.Footprint(def, ax, y, az, rr)
		local ok = #fp == #cells
		if ok then
			for _, f in ipairs(fp) do
				if not target[ShipParts.Key(f[1], f[2], f[3])] then ok = false break end
			end
		end
		if ok then return ax, y, az, rr end
	end
	return nil
end

-- DRYDOCK UI ---------------------------------------------------------------------------
local selectedId, rotation, mirrorOn, removeMode = "Wood_Block", 0, true, false
local lastAnalysis = nil

local dock = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, gui)

local palette = make("Frame", {
	Size = UDim2.new(0, 300, 1, -150), Position = UDim2.fromOffset(10, 52), BackgroundColor3 = PANEL, BackgroundTransparency = 0.08,
}, dock)
make("TextLabel", {
	Text = "DRYDOCK - parts", Size = UDim2.new(1, -10, 0, 28), Position = UDim2.fromOffset(8, 4),
	BackgroundTransparency = 1, TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left,
}, palette)
local paletteList = make("ScrollingFrame", {
	Size = UDim2.new(1, -10, 1, -38), Position = UDim2.fromOffset(5, 34), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 5, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
}, palette)
make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, paletteList)

local statsPanel = make("Frame", {
	Size = UDim2.fromOffset(330, 360), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 52),
	BackgroundColor3 = PANEL, BackgroundTransparency = 0.08,
}, dock)
make("TextLabel", {
	Text = "SHIP STATUS", Size = UDim2.new(1, -10, 0, 26), Position = UDim2.fromOffset(8, 4),
	BackgroundTransparency = 1, TextColor3 = GOLD, Font = Enum.Font.GothamBold, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left,
}, statsPanel)
local statsLabel = make("TextLabel", {
	Size = UDim2.new(1, -16, 0, 160), Position = UDim2.fromOffset(8, 32), BackgroundTransparency = 1, TextColor3 = WHITE,
	Font = Enum.Font.Gotham, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = "",
}, statsPanel)
local problemsLabel = make("TextLabel", {
	Size = UDim2.new(1, -16, 1, -200), Position = UDim2.fromOffset(8, 196), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(255, 120, 110),
	Font = Enum.Font.GothamMedium, TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top, Text = "",
}, statsPanel)

make("TextLabel", {
	Size = UDim2.fromOffset(820, 20), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -76),
	BackgroundTransparency = 1, TextColor3 = WHITE, TextStrokeTransparency = 0.5, Font = Enum.Font.Gotham, TextSize = 13,
	Text = "Click: place   |   R: rotate   |   X: remove mode   |   M: mirror   |   Right-drag: orbit   |   Wheel: zoom   |   Build on top of blocks to go up",
}, dock)

local toolbar = make("Frame", {
	Size = UDim2.fromOffset(790, 56), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12),
	BackgroundColor3 = PANEL, BackgroundTransparency = 0.08,
}, dock)

local function toolButton(x, w, text, color, onClick)
	local b = make("TextButton", {
		Size = UDim2.fromOffset(w, 40), Position = UDim2.fromOffset(x, 8), BackgroundColor3 = color, TextColor3 = WHITE,
		Font = Enum.Font.GothamBold, TextSize = 14, Text = text,
	}, toolbar)
	b.MouseButton1Click:Connect(onClick)
	return b
end

-- forward declarations
local refreshStats, refreshPalette, refreshToolbar, closeDrydock

local launchBtn = toolButton(10, 190, "LAUNCH SHIP", GREEN, function()
	if not lastAnalysis or not lastAnalysis.Ok then
		toast((lastAnalysis and lastAnalysis.Problems[1]) or "Invalid ship design")
		return
	end
	Remotes.LaunchShip:FireServer(buildList())
	closeDrydock()
end)
local rotateBtn = toolButton(210, 110, "ROTATE (R)", Color3.fromRGB(45, 70, 110), function()
	rotation = (rotation + 1) % 4
	refreshToolbar()
end)
local mirrorBtn = toolButton(330, 130, "MIRROR (M)", Color3.fromRGB(45, 70, 110), function()
	mirrorOn = not mirrorOn
	refreshToolbar()
end)
local removeBtn = toolButton(470, 130, "REMOVE (X)", Color3.fromRGB(45, 70, 110), function()
	removeMode = not removeMode
	refreshToolbar()
	refreshPalette()
end)
toolButton(610, 80, "CLEAR", Color3.fromRGB(110, 60, 40), function()
	clearAll()
	userEdited = true
	refreshStats()
end)
toolButton(700, 80, "CLOSE (B)", RED, function() closeDrydock() end)

function refreshToolbar()
	rotateBtn.Text = ("ROTATE (R) %d"):format(rotation * 90) .. "\u{00B0}"
	mirrorBtn.Text = mirrorOn and "MIRROR: ON (M)" or "MIRROR: OFF (M)"
	mirrorBtn.BackgroundColor3 = mirrorOn and GREEN or Color3.fromRGB(70, 70, 80)
	removeBtn.Text = removeMode and "REMOVE: ON (X)" or "REMOVE (X)"
	removeBtn.BackgroundColor3 = removeMode and RED or Color3.fromRGB(45, 70, 110)
end

-- palette buttons
local palButtons = {}
local order = 0
local catTitles = { Core = "CORE (heart of the ship)", Armor = "ARMOR", Weapon = "WEAPONS", Engine = "ENGINES", Misc = "HELM" }

local function describePart(def)
	local s = ("HP %d  |  Mass %.1f  |  $%d"):format(def.HP, def.Mass, def.Cost)
	if def.Category == "Weapon" then
		s ..= ("\nDMG %d every %.2fs  |  range %d"):format(def.Damage, def.Cooldown, def.Range)
	elseif def.Category == "Engine" then
		s ..= ("\nThrust %d"):format(def.Thrust)
	end
	return s
end

for _, cat in ipairs({ "Core", "Armor", "Weapon", "Engine", "Misc" }) do
	order += 1
	make("TextLabel", {
		LayoutOrder = order, Size = UDim2.new(1, -8, 0, 24), BackgroundTransparency = 1, Text = catTitles[cat],
		TextColor3 = GOLD, Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
	}, paletteList)
	for _, def in ipairs(ShipParts.List) do
		if def.Category == cat then
			order += 1
			local btn = make("TextButton", {
				LayoutOrder = order, Size = UDim2.new(1, -8, 0, 56), TextWrapped = true, TextColor3 = WHITE,
				Font = Enum.Font.Gotham, TextSize = 12, Text = "",
			}, paletteList)
			palButtons[def.Id] = btn
			btn.MouseButton1Click:Connect(function()
				if not state.Unlocked[def.Tech] then
					toast("Locked - research " .. TechConfig.ById[def.Tech].Name .. " first (press T)")
					return
				end
				selectedId = def.Id
				Audio.UI("Click")
				removeMode = false
				refreshToolbar()
				refreshPalette()
			end)
		end
	end
end

function refreshPalette()
	for id, btn in pairs(palButtons) do
		local def = ShipParts.ById[id]
		local unlocked = state.Unlocked[def.Tech]
		if unlocked then
			btn.Text = def.Name .. "\n" .. describePart(def)
			btn.TextTransparency = 0
			if selectedId == id and not removeMode then
				btn.BackgroundColor3 = GREEN
			else
				btn.BackgroundColor3 = Color3.fromRGB(45, 60, 90)
			end
		else
			btn.Text = def.Name .. "\n[LOCKED - research " .. TechConfig.ById[def.Tech].Name .. "]"
			btn.TextTransparency = 0.4
			btn.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
		end
	end
end

function refreshStats()
	local res = ShipParts.Analyze(buildList(), state.Unlocked)
	lastAnalysis = res
	local drive = ShipParts.DriveStats(res.Mass, res.Thrust)
	local armorHP, coreHP, dps = 0, 0, 0
	for _, b in ipairs(res.Blocks) do
		local d = b.Def
		if d.Category == "Armor" then
			armorHP += d.HP
		elseif d.Category == "Core" then
			coreHP = d.HP
		elseif d.Category == "Weapon" then
			dps += d.Damage / d.Cooldown
		end
	end
	local free = res.Cost <= TechConfig.FreeBuildBudget
	statsLabel.Text = table.concat({
		("Blocks: %d / %d"):format(#res.Blocks, ShipParts.MaxBlocks),
		("Cost: $%d%s"):format(res.Cost, free and "  (FREE - under budget)" or ""),
		("Mass: %.1f"):format(res.Mass),
		("Thrust: %d   ->   top speed %d"):format(res.Thrust, drive.MaxSpeed),
		("Armor HP: %d    Core HP: %d"):format(armorHP, coreHP),
		("Firepower: %d damage / sec"):format(dps),
		("Weapons: %d    Engines: %d"):format(res.Weapons, res.Engines),
		("Your money: $%d"):format(math.floor(state.Money)),
	}, "\n")

	if #res.Problems == 0 then
		problemsLabel.TextColor3 = Color3.fromRGB(110, 230, 130)
		problemsLabel.Text = "READY TO LAUNCH!"
	else
		problemsLabel.TextColor3 = Color3.fromRGB(255, 120, 110)
		local lines = {}
		for i = 1, math.min(#res.Problems, 6) do
			table.insert(lines, "- " .. res.Problems[i])
		end
		problemsLabel.Text = table.concat(lines, "\n")
	end
	launchBtn.BackgroundColor3 = res.Ok and GREEN or Color3.fromRGB(80, 80, 85)
end

-- placing / removing -------------------------------------------------------------------
local ghosts = {}
local hoverHL = Instance.new("Highlight")
hoverHL.FillTransparency = 0.45
hoverHL.OutlineTransparency = 0
hoverHL.Parent = ghostFolder
local hoverEntry, hoverPlace = nil, nil

local function hideGhosts()
	for i = 1, 2 do
		if ghosts[i] then ghosts[i].Model.Parent = nil end
	end
end

local function ensureGhosts(def)
	if ghosts.DefId == def.Id and ghosts[1] then return end
	for i = 1, 2 do
		if ghosts[i] then ghosts[i].Model:Destroy() end
	end
	table.clear(ghosts)
	for i = 1, 2 do
		local m = ShipParts.CreateVisual(def, true)
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then
				p.CanQuery = false
				p.Transparency = math.clamp(p.Transparency + 0.5, 0, 0.9)
			elseif p:IsA("PointLight") then
				p.Enabled = false
			end
		end
		local h = Instance.new("Highlight")
		h.FillTransparency = 0.5
		h.OutlineTransparency = 0.1
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Adornee = m
		h.Parent = m
		ghosts[i] = { Model = m, Highlight = h }
	end
	ghosts.DefId = def.Id
end

local function showGhost(g, def, x, y, z, r, valid)
	local cf = ShipParts.BlockCFrame(def, x, y, z, r)
	g.Model:PivotTo(CFrame.new(BAY) * cf)
	g.Model.Parent = ghostFolder
	local c = valid and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(255, 80, 80)
	g.Highlight.FillColor = c
	g.Highlight.OutlineColor = c
end

local function overUI(loc)
	for _, f in ipairs({ palette, statsPanel, toolbar }) do
		local p, s = f.AbsolutePosition, f.AbsoluteSize
		if loc.X >= p.X and loc.X <= p.X + s.X and loc.Y >= p.Y and loc.Y <= p.Y + s.Y then
			return true
		end
	end
	return false
end

local function targetFromHit(res)
	local lp = res.Position - BAY
	if res.Instance == floorPart then
		return math.floor(lp.X / S + 0.5), 0, math.floor(lp.Z / S + 0.5)
	end
	local inside = lp - res.Normal * 0.1
	local cx = math.floor(inside.X / S + 0.5)
	local cy = math.floor(inside.Y / S)
	local cz = math.floor(inside.Z / S + 0.5)
	local n = res.Normal
	local ax, ay, az = math.abs(n.X), math.abs(n.Y), math.abs(n.Z)
	local dx, dy, dz = 0, 0, 0
	if ax >= ay and ax >= az then
		dx = n.X > 0 and 1 or -1
	elseif ay >= az then
		dy = n.Y > 0 and 1 or -1
	else
		dz = n.Z > 0 and 1 or -1
	end
	return cx + dx, cy + dy, cz + dz
end

local function updateHover()
	hideGhosts()
	hoverHL.Adornee = nil
	hoverEntry, hoverPlace = nil, nil

	local loc = UserInputService:GetMouseLocation()
	if overUI(loc) then return end
	local ray = workspace.CurrentCamera:ViewportPointToRay(loc.X, loc.Y)
	local res = workspace:Raycast(ray.Origin, ray.Direction * 2000, rayParams)
	if not res then return end

	if removeMode then
		local m = res.Instance:FindFirstAncestorOfClass("Model")
		local entry = m and modelEntry[m]
		if entry then
			hoverEntry = entry
			hoverHL.FillColor = Color3.fromRGB(255, 80, 80)
			hoverHL.OutlineColor = Color3.fromRGB(255, 80, 80)
			hoverHL.Adornee = entry.Model
		end
		return
	end

	local def = ShipParts.ById[selectedId]
	if not def or not state.Unlocked[def.Tech] then return end
	local x, y, z = targetFromHit(res)
	local valid = canPlace(def, x, y, z, rotation)
	hoverPlace = { Def = def, X = x, Y = y, Z = z, R = rotation, Valid = valid }

	ensureGhosts(def)
	showGhost(ghosts[1], def, x, y, z, rotation, valid)
	if mirrorOn then
		local mx, my, mz, mr = mirrorPlacement(def, x, y, z, rotation)
		if mx then
			showGhost(ghosts[2], def, mx, my, mz, mr, canPlace(def, mx, my, mz, mr))
		end
	end
end

local function clickDrydock()
	if removeMode then
		local e = hoverEntry
		if e then
			local c = e.Cells[1]
			local twin = mirrorOn and occ[ShipParts.Key(-c[1], c[2], c[3])] or nil
			removeEntry(e)
			if twin and twin ~= e and twin.Id == e.Id then removeEntry(twin) end
			userEdited = true
			refreshStats()
			Audio.UI("Remove")
		end
	elseif hoverPlace and hoverPlace.Valid then
		local h = hoverPlace
		if addEntry(h.Def.Id, h.X, h.Y, h.Z, h.R) then
			if mirrorOn then
				local mx, my, mz, mr = mirrorPlacement(h.Def, h.X, h.Y, h.Z, h.R)
				if mx then addEntry(h.Def.Id, mx, my, mz, mr) end
			end
			userEdited = true
			refreshStats()
			Audio.UI("Place")
		end
	end
end

-- camera + open/close ---------------------------------------------------------------------
local cam = { Yaw = math.rad(35), Pitch = math.rad(30), Dist = 230, Focus = BAY + Vector3.new(0, 18, 0) }
local rmbDown = false

local function setControls(enabled)
	pcall(function()
		local pm = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
		local controls = pm:GetControls()
		if enabled then controls:Enable() else controls:Disable() end
	end)
end

local function openDrydock()
	if drydockOpen then return end
	drydockOpen = true
	researchOpen = false
	research.Visible = false
	firing = false
	dock.Visible = true
	setControls(false)
	refreshPalette()
	refreshStats()
	refreshToolbar()
end

function closeDrydock()
	if not drydockOpen then return end
	drydockOpen = false
	dock.Visible = false
	hideGhosts()
	hoverHL.Adornee = nil
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then camera.CameraSubject = hum end
	setControls(true)
	if #placed > 0 then Remotes.SaveDesign:FireServer(buildList()) end
end

local function toggleResearch()
	researchOpen = not researchOpen
	research.Visible = researchOpen
	if researchOpen then refreshResearch() end
end
researchClose.MouseButton1Click:Connect(function()
	researchOpen = false
	research.Visible = false
end)

RunService.RenderStepped:Connect(function(dt)
	if not drydockOpen then return end
	local UIS = UserInputService
	if UIS:IsKeyDown(Enum.KeyCode.Q) or UIS:IsKeyDown(Enum.KeyCode.Left) then cam.Yaw += dt * 1.6 end
	if UIS:IsKeyDown(Enum.KeyCode.E) or UIS:IsKeyDown(Enum.KeyCode.Right) then cam.Yaw -= dt * 1.6 end
	if UIS:IsKeyDown(Enum.KeyCode.Up) then cam.Pitch = math.clamp(cam.Pitch + dt, 0.05, 1.45) end
	if UIS:IsKeyDown(Enum.KeyCode.Down) then cam.Pitch = math.clamp(cam.Pitch - dt, 0.05, 1.45) end
	local camera = workspace.CurrentCamera
	local rot = CFrame.Angles(0, cam.Yaw, 0) * CFrame.Angles(-cam.Pitch, 0, 0)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.new(cam.Focus) * rot * CFrame.new(0, 0, cam.Dist)
	updateHover()
end)

-- INPUT -------------------------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if player.PlayerGui:FindFirstChild("LoadingScreen") then return end -- ignore keys while the loading screen is up
	local t = input.UserInputType
	if t == Enum.UserInputType.MouseButton1 then
		if drydockOpen then
			clickDrydock()
		elseif not researchOpen then
			firing = true
		end
	elseif t == Enum.UserInputType.MouseButton2 then
		rmbDown = true
	elseif input.KeyCode == Enum.KeyCode.B then
		if drydockOpen then closeDrydock() else openDrydock() end
	elseif input.KeyCode == Enum.KeyCode.T then
		toggleResearch()
	elseif drydockOpen and input.KeyCode == Enum.KeyCode.R then
		rotation = (rotation + 1) % 4
		refreshToolbar()
	elseif drydockOpen and input.KeyCode == Enum.KeyCode.X then
		removeMode = not removeMode
		refreshToolbar()
		refreshPalette()
	elseif drydockOpen and input.KeyCode == Enum.KeyCode.M then
		mirrorOn = not mirrorOn
		refreshToolbar()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		firing = false
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		rmbDown = false
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not drydockOpen then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
			cam.Yaw -= input.Delta.X * 0.006
			cam.Pitch = math.clamp(cam.Pitch + input.Delta.Y * 0.006, 0.05, 1.45)
		end
	elseif input.UserInputType == Enum.UserInputType.MouseWheel then
		cam.Dist = math.clamp(cam.Dist - input.Position.Z * 15, 60, 520)
	end
end)

-- SERVER EVENTS ----------------------------------------------------------------------------
Remotes.DataUpdate.OnClientEvent:Connect(function(d)
	state = d
	refreshResearch()
	refreshPalette()
	refreshStats()
end)
Remotes.DesignUpdate.OnClientEvent:Connect(function(list)
	if not userEdited then
		loadDesign(list)
		refreshStats()
	end
end)
Remotes.Notify.OnClientEvent:Connect(function(text)
	toast(text)
	local lower = text:lower()
	if lower:find("ship destroyed") then
		Audio.UI("XP")
	elseif lower:find("^researched") then
		Audio.UI("Research")
	elseif lower:find("conquered") then
		Audio.UI("Capture")
	elseif lower:find("ship launched") then
		Audio.UI("Launch")
	elseif lower:find("you lost") or lower:find("was destroyed") then
		Audio.UI("Lost")
	else
		Audio.UI("Error")
	end
end)

-- HUD LOOP + AIMING ----------------------------------------------------------------------------
local function getShip()
	local boats = workspace:FindFirstChild("Boats")
	return boats and boats:FindFirstChild("Ship_" .. player.UserId)
end

task.spawn(function()
	while true do
		local owned, income = 0, 0
		local terr = workspace:FindFirstChild("Territories")
		if terr then
			for _, t in ipairs(terr:GetChildren()) do
				if t:GetAttribute("OwnerId") == player.UserId then
					owned += 1
					for _, d in ipairs(t:GetChildren()) do
						if d.Name == "OilDeposit" then income += d:GetAttribute("Income") or 0 end
					end
				end
			end
		end
		hud.Text = ("Money: $%d     XP: %d\nTerritories: %d     Oil income: $%d / %ds"):format(
			math.floor(state.Money), math.floor(state.XP), owned, income, TechConfig.Territory.OilTickSeconds)

		local ship = getShip()
		if ship then
			local hp, maxHp = ship:GetAttribute("CoreHP") or 0, ship:GetAttribute("CoreMaxHP") or 1
			local blocks, total = ship:GetAttribute("Blocks") or 0, ship:GetAttribute("TotalBlocks") or 0
			local speed = 0
			if ship.PrimaryPart then
				local v = ship.PrimaryPart.AssemblyLinearVelocity
				speed = Vector3.new(v.X, 0, v.Z).Magnitude
			end
			hpBack.Visible = true
			hpFill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
			hpText.Text = ("CORE %d / %d   |   Blocks %d / %d   |   %d studs/s"):format(hp, maxHp, blocks, total, speed)
		else
			hpBack.Visible = false
		end
		task.wait(0.25)
	end
end)

task.spawn(function()
	while true do
		task.wait(0.1)
		local ship = getShip()
		mouse.TargetFilter = ship
		if ship and not drydockOpen then
			Remotes.Aim:FireServer(mouse.Hit.Position, firing)
		end
	end
end)

-- BIG-SHIP CAMERA + LOW-CORE ALARM
local lastSeated, lastAlarm = nil, 0
task.spawn(function()
	while true do
		task.wait(0.25)
		local ship = getShip()
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local seated = ship ~= nil and hum ~= nil and hum.SeatPart ~= nil
		if seated ~= lastSeated then
			lastSeated = seated
			player.CameraMinZoomDistance = seated and 60 or 0.5
			player.CameraMaxZoomDistance = seated and 900 or 128
		end
		if ship then
			local hp, maxHp = ship:GetAttribute("CoreHP") or 0, ship:GetAttribute("CoreMaxHP") or 1
			if hp > 0 and hp / maxHp < 0.35 and os.clock() - lastAlarm > 1.6 then
				lastAlarm = os.clock()
				Audio.UI("Alarm")
			end
		end
	end
end)

-- START --------------------------------------------------------------------------------------
task.spawn(function()
	-- the Drydock opens once the loading screen has been closed
	local pg = player:WaitForChild("PlayerGui")
	while pg:FindFirstChild("LoadingScreen") do task.wait(0.2) end
	task.wait(0.5)
	openDrydock()
end)
loadDesign(Blueprints.AI(1)) -- default starter ship until your saved design arrives
refreshToolbar()
refreshResearch()
refreshPalette()
refreshStats()
Remotes.RequestData:FireServer()


