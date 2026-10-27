local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local WorldConfig = require(ReplicatedStorage:WaitForChild("WorldConfig"))

local WORLD = WorldConfig.WorldSize
local HARBOR = WorldConfig.Harbor
local TERRITORIES = WorldConfig.GetTerritories()
local terrFolder = workspace:FindFirstChild("Territories")

local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end

local TEAL = Color3.fromRGB(60, 200, 190)
local WHITE = Color3.new(1, 1, 1)

local gui = make("ScreenGui", { Name = "MapUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 5 }, player:WaitForChild("PlayerGui"))

local function getFocus()
	local boats = workspace:FindFirstChild("Boats")
	local ship = boats and boats:FindFirstChild("Ship_" .. player.UserId)
	if ship and ship.PrimaryPart then
		local cf = ship.PrimaryPart.CFrame
		return cf.Position, cf.LookVector
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then return hrp.Position, hrp.CFrame.LookVector end
	return Vector3.zero, Vector3.new(0, 0, -1)
end

local function heading(look)
	return math.deg(math.atan2(look.X, -look.Z)) -- GUI rotation: 0 = up (north = -z), clockwise
end

local function ownerStroke(def)
	terrFolder = terrFolder or workspace:FindFirstChild("Territories")
	local m = terrFolder and terrFolder:FindFirstChild(def.Name)
	local ownerId = m and m:GetAttribute("OwnerId") or 0
	if ownerId == player.UserId then return Color3.fromRGB(80, 255, 120), 3, m end
	if ownerId ~= 0 then return Color3.fromRGB(255, 220, 90), 3, m end
	return WHITE, 0, m
end

local function shipColor(m)
	local f = m:GetAttribute("Faction")
	if f and WorldConfig.Factions[f] then return WorldConfig.Factions[f].Color end
	if f == "Pirates" then return Color3.fromRGB(190, 190, 195) end
	return Color3.fromRGB(90, 220, 255) -- other players
end

-- MINIMAP ----------------------------------------------------------------------------
local MINI, MINI_RANGE = 200, 900
local ms = (MINI / 2) / MINI_RANGE

local mini = make("Frame", {
	Size = UDim2.fromOffset(MINI, MINI), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -14),
	BackgroundColor3 = Color3.fromRGB(12, 40, 72), ClipsDescendants = true,
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 10) }, mini)
make("UIStroke", { Color = Color3.fromRGB(120, 170, 220), Thickness = 2 }, mini)

local miniSafe = make("Frame", {
	Size = UDim2.fromOffset(HARBOR.Radius * 2 * ms, HARBOR.Radius * 2 * ms), AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = TEAL, BackgroundTransparency = 0.8, BorderSizePixel = 0,
}, mini)
make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, miniSafe)
make("UIStroke", { Color = TEAL, Thickness = 1 }, miniSafe)

local miniHome = make("TextLabel", {
	Size = UDim2.fromOffset(16, 16), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = TEAL, Text = "H",
	TextColor3 = Color3.fromRGB(10, 30, 40), Font = Enum.Font.GothamBold, TextSize = 12, BorderSizePixel = 0,
}, mini)
make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, miniHome)

local miniMarkers = {}
for _, def in ipairs(TERRITORIES) do
	local f = WorldConfig.Factions[def.Faction]
	local m = make("Frame", {
		Size = UDim2.fromOffset(11, 11), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = f.Color,
		BorderSizePixel = 0, Rotation = 45,
	}, mini)
	local stroke = make("UIStroke", { Thickness = 0, Color = WHITE }, m)
	table.insert(miniMarkers, { Def = def, Frame = m, Stroke = stroke })
end

local miniArrow = make("TextLabel", {
	Size = UDim2.fromOffset(22, 22), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(MINI / 2, MINI / 2),
	BackgroundTransparency = 1, Text = "\u{25B2}", TextColor3 = WHITE, TextStrokeTransparency = 0, Font = Enum.Font.GothamBold,
	TextSize = 20, ZIndex = 5,
}, mini)

local dots = {}

-- FULL MAP -----------------------------------------------------------------------------
local FM = 720
local fs = FM / WORLD
local mapOpen = false

local full = make("Frame", {
	Size = UDim2.fromOffset(FM, FM), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(10, 30, 52), ClipsDescendants = true, Visible = false,
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 12) }, full)
make("UIStroke", { Color = Color3.fromRGB(140, 190, 240), Thickness = 3 }, full)

local function fpos(x, z)
	return UDim2.fromOffset(FM / 2 + x * fs, FM / 2 + z * fs)
end

-- faction sector dividers + tier rings
for _, rot in ipairs({ 0, 90 }) do
	make("Frame", {
		Size = UDim2.fromOffset(FM, 1), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(FM / 2, FM / 2),
		BackgroundColor3 = Color3.fromRGB(70, 100, 140), BackgroundTransparency = 0.4, BorderSizePixel = 0, Rotation = rot,
	}, full)
end
for i, radius in ipairs(WorldConfig.TierRadius) do
	local d = radius * 2 * fs
	local ring = make("Frame", {
		Size = UDim2.fromOffset(d, d), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(FM / 2, FM / 2),
		BackgroundTransparency = 1,
	}, full)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, ring)
	make("UIStroke", { Color = Color3.fromRGB(80, 115, 160), Thickness = 1, Transparency = 0.5 }, ring)
	make("TextLabel", {
		Size = UDim2.fromOffset(30, 14), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(FM / 2, FM / 2 - radius * fs),
		BackgroundTransparency = 1, Text = "T" .. i, TextColor3 = Color3.fromRGB(130, 170, 215), Font = Enum.Font.GothamBold, TextSize = 11,
	}, full)
end

-- faction names in their sectors
for _, key in ipairs(WorldConfig.FactionOrder) do
	local f = WorldConfig.Factions[key]
	local a = math.rad(f.Sector)
	make("TextLabel", {
		Size = UDim2.fromOffset(170, 20), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = fpos(math.cos(a) * (WorldConfig.TierRadius[7] + 420), math.sin(a) * (WorldConfig.TierRadius[7] + 420)), BackgroundTransparency = 1,
		Text = f.Name:upper(), TextColor3 = f.Color, Font = Enum.Font.GothamBlack, TextSize = 15, TextStrokeTransparency = 0.5,
	}, full)
end

-- home harbor + safe zone
local fullSafe = make("Frame", {
	Size = UDim2.fromOffset(HARBOR.Radius * 2 * fs, HARBOR.Radius * 2 * fs), AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromOffset(FM / 2, FM / 2), BackgroundColor3 = TEAL, BackgroundTransparency = 0.7, BorderSizePixel = 0,
}, full)
make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, fullSafe)
make("UIStroke", { Color = TEAL, Thickness = 1 }, fullSafe)
local homeMark = make("TextLabel", {
	Size = UDim2.fromOffset(24, 24), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(FM / 2, FM / 2),
	BackgroundColor3 = TEAL, Text = "H", TextColor3 = Color3.fromRGB(10, 30, 40), Font = Enum.Font.GothamBold, TextSize = 16, BorderSizePixel = 0,
}, full)
make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, homeMark)
make("TextLabel", {
	Size = UDim2.fromOffset(140, 14), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(FM / 2, FM / 2 + 14),
	BackgroundTransparency = 1, Text = "HOME HARBOR (safe)", TextColor3 = TEAL, Font = Enum.Font.GothamBold, TextSize = 11, TextStrokeTransparency = 0.5,
}, full)

-- territories
local fullMarkers = {}
for _, def in ipairs(TERRITORIES) do
	local f = WorldConfig.Factions[def.Faction]
	local m = make("TextLabel", {
		Size = UDim2.fromOffset(20, 20), AnchorPoint = Vector2.new(0.5, 0.5), Position = fpos(def.Pos.X, def.Pos.Z),
		BackgroundColor3 = f.Color, Text = tostring(def.Tier), TextColor3 = Color3.fromRGB(15, 15, 20),
		Font = Enum.Font.GothamBold, TextSize = 13, BorderSizePixel = 0,
	}, full)
	make("UICorner", { CornerRadius = UDim.new(0, 4) }, m)
	local stroke = make("UIStroke", { Thickness = 0, Color = WHITE }, m)
	local name = make("TextLabel", {
		Size = UDim2.fromOffset(150, 14), Position = UDim2.fromOffset(23, 3), BackgroundTransparency = 1, Text = def.Name,
		TextColor3 = WHITE, Font = Enum.Font.GothamMedium, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextStrokeTransparency = 0.4,
	}, m)
	table.insert(fullMarkers, { Def = def, Frame = m, Stroke = stroke, Name = name })
end

local fullArrow = make("TextLabel", {
	Size = UDim2.fromOffset(26, 26), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Text = "\u{25B2}",
	TextColor3 = WHITE, TextStrokeTransparency = 0, Font = Enum.Font.GothamBold, TextSize = 24, ZIndex = 6,
}, full)

-- title + legend
local title = make("TextLabel", {
	Size = UDim2.fromOffset(400, 26), Position = UDim2.fromOffset(10, 6), BackgroundTransparency = 1, Text = "WORLD MAP",
	TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7,
}, full)
local legendLines = {
	"<b>Number = enemy tier</b> (T1 is closest to your harbor, T7 is farthest)",
	"<font color=\"rgb(80,255,120)\">Green outline</font> = yours    <font color=\"rgb(255,220,90)\">Gold outline</font> = another player's",
}
for _, key in ipairs(WorldConfig.FactionOrder) do
	local f = WorldConfig.Factions[key]
	table.insert(legendLines, ("<font color=\"rgb(%d,%d,%d)\">\u{25A0}</font> %s"):format(
		math.floor(f.Color.R * 255), math.floor(f.Color.G * 255), math.floor(f.Color.B * 255), f.Name))
end
table.insert(legendLines, "Press M to close")
make("TextLabel", {
	Size = UDim2.fromOffset(350, 118), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -8),
	BackgroundColor3 = Color3.fromRGB(8, 20, 36), BackgroundTransparency = 0.25, RichText = true,
	Text = table.concat(legendLines, "\n"), TextColor3 = WHITE, Font = Enum.Font.Gotham, TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 7,
}, full)
local closeBtn = make("TextButton", {
	Size = UDim2.fromOffset(30, 26), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 6),
	BackgroundColor3 = Color3.fromRGB(190, 60, 60), Text = "X", TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextSize = 15, ZIndex = 8,
}, full)

local function setMap(open)
	mapOpen = open
	full.Visible = open
end
closeBtn.MouseButton1Click:Connect(function() setMap(false) end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.M then
		-- inside the Drydock M means "mirror", so the map stays closed there
		if workspace.CurrentCamera.CameraType == Enum.CameraType.Scriptable then return end
		setMap(not mapOpen)
	end
end)

-- UPDATE -----------------------------------------------------------------------------------
local function updateMarkers()
	local owned = 0
	for _, e in ipairs(fullMarkers) do
		local color, thickness, model = ownerStroke(e.Def)
		e.Stroke.Color = color
		e.Stroke.Thickness = thickness
		local ownerId = model and model:GetAttribute("OwnerId") or 0
		if ownerId == player.UserId then owned += 1 end
		local ownerName = model and model:GetAttribute("OwnerName") or ""
		e.Name.Text = ownerId ~= 0 and (e.Def.Name .. "  [" .. ownerName .. "]") or e.Def.Name
	end
	for _, e in ipairs(miniMarkers) do
		local color, thickness = ownerStroke(e.Def)
		e.Stroke.Color = color
		e.Stroke.Thickness = thickness > 0 and 2 or 0
	end
	title.Text = ("WORLD MAP     territories held: %d / %d"):format(owned, #TERRITORIES)
end

local markerTimer = 0
RunService.RenderStepped:Connect(function(dt)
	local scriptable = workspace.CurrentCamera.CameraType == Enum.CameraType.Scriptable
	mini.Visible = not scriptable and not mapOpen

	local pos, look = getFocus()
	local rot = heading(look)

	markerTimer -= dt
	if markerTimer <= 0 then
		markerTimer = 0.5
		updateMarkers()
	end

	if mapOpen then
		fullArrow.Position = fpos(pos.X, pos.Z)
		fullArrow.Rotation = rot
	end
	if not mini.Visible then return end

	local c = MINI / 2
	miniArrow.Rotation = rot
	miniSafe.Position = UDim2.fromOffset(c - pos.X * ms, c - pos.Z * ms)
	miniHome.Position = miniSafe.Position
	for _, e in ipairs(miniMarkers) do
		local ox, oy = (e.Def.Pos.X - pos.X) * ms, (e.Def.Pos.Z - pos.Z) * ms
		e.Frame.Visible = math.abs(ox) < c + 10 and math.abs(oy) < c + 10
		e.Frame.Position = UDim2.fromOffset(c + ox, c + oy)
	end

	-- other ships (red/pirate grey/faction colours, players cyan)
	local seen = {}
	local boats = workspace:FindFirstChild("Boats")
	if boats then
		for _, m in ipairs(boats:GetChildren()) do
			if m:IsA("Model") and m.Name ~= "Ship_" .. player.UserId and m.PrimaryPart then
				local d = m.PrimaryPart.Position - pos
				local ox, oy = d.X * ms, d.Z * ms
				if math.abs(ox) < c - 3 and math.abs(oy) < c - 3 then
					seen[m] = true
					local dot = dots[m]
					if not dot then
						dot = make("Frame", { Size = UDim2.fromOffset(6, 6), AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0 }, mini)
						make("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
						dots[m] = dot
					end
					dot.Position = UDim2.fromOffset(c + ox, c + oy)
					dot.BackgroundColor3 = shipColor(m)
				end
			end
		end
	end
	for m, dot in pairs(dots) do
		if not seen[m] then
			dot:Destroy()
			dots[m] = nil
		end
	end
end)

updateMarkers()