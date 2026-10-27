local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

print("[LoadingScreen] script started")

-- SETTINGS ------------------------------------------------------------------------------
local GAME_NAME = "FORGED SEAS"
local SUBTITLE = "BUILD YOUR SHIP DESTROY THE PIRATS AND CONQUER THE WORLD"
local SLOW_AFTER = 45 -- seconds before it suggests pressing SKIP

local TIPS = {
	"Surround your Core with armor. If the Core is destroyed, your whole ship is lost.",
	"Press B at the harbor to open the Drydock and design your ship.",
	"Press T to spend XP on research and unlock new ship parts.",
	"Hunt the weak pirates near the harbor for easy early XP.",
	"Oil derricks on islands you conquer pay you money every few seconds.",
	"Home Harbor is a safe zone: nobody can shoot or be shot inside it.",
	"Press M to open the world map.",
	"Heavy armor slows your ship. Balance it with stronger engines.",
	"If a part is cut off from your Core, it breaks away from the ship.",
	"Sit alone inside an island's zone to capture it. Enemy ships in the zone will try to block you.",
}
-------------------------------------------------------------------------------------------

-- the player can be missing for a moment when this runs from ReplicatedFirst
local player = Players.LocalPlayer
while not player do
	task.wait()
	player = Players.LocalPlayer
end
local playerGui = player:WaitForChild("PlayerGui")

local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end

local WHITE = Color3.new(1, 1, 1)

-- BUILD THE SCREEN (off-screen first, so a failure never leaves half a screen) ---------------
local function buildUI(fancy)
	local ui = {}
	local gui = make("ScreenGui", {
		Name = "LoadingScreen", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 1000,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, nil)
	ui.gui = gui

	local root = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0 }, gui)
	local bg = make("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(10, 28, 52), BorderSizePixel = 0, Active = true,
	}, root)
	if fancy then
		make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(18, 52, 94), Color3.fromRGB(4, 10, 20)), Rotation = 90 }, bg)
	end

	-- moving sea at the bottom
	ui.waves = {}
	if fancy then
		for i = 1, 3 do
			local f = make("Frame", {
				Size = UDim2.new(1.2, 0, 0, 170), Position = UDim2.new(-0.1, 0, 1, -60 - i * 22),
				BackgroundColor3 = Color3.fromRGB(30 + i * 10, 90 + i * 14, 150 + i * 14),
				BackgroundTransparency = 0.5 + i * 0.1, BorderSizePixel = 0,
			}, root)
			make("UICorner", { CornerRadius = UDim.new(0, 70) }, f)
			ui.waves[i] = f
		end
	end

	make("TextLabel", {
		Size = UDim2.fromOffset(1000, 74), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.3, 0),
		BackgroundTransparency = 1, Text = GAME_NAME, TextColor3 = WHITE, Font = Enum.Font.GothamBlack,
		TextSize = 60, TextStrokeTransparency = 0.6,
	}, root)
	make("TextLabel", {
		Size = UDim2.fromOffset(900, 28), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.3, 58),
		BackgroundTransparency = 1, Text = SUBTITLE, TextColor3 = Color3.fromRGB(170, 205, 240),
		Font = Enum.Font.GothamMedium, TextSize = 20,
	}, root)

	ui.status = make("TextLabel", {
		Size = UDim2.fromOffset(900, 26), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
		BackgroundTransparency = 1, Text = "Connecting to the game", TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextSize = 18,
	}, root)

	local barBack = make("Frame", {
		Size = UDim2.fromOffset(520, 16), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.545, 0),
		BackgroundColor3 = Color3.fromRGB(8, 18, 32), BorderSizePixel = 0,
	}, root)
	ui.barFill = make("Frame", {
		Size = UDim2.fromScale(0, 1), BackgroundColor3 = fancy and WHITE or Color3.fromRGB(70, 160, 240), BorderSizePixel = 0,
	}, barBack)
	if fancy then
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, barBack)
		make("UIStroke", { Color = Color3.fromRGB(110, 160, 215), Thickness = 2 }, barBack)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, ui.barFill)
		ui.barGradient = make("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(70, 190, 255), Color3.fromRGB(60, 120, 230)),
		}, ui.barFill)
	end

	ui.percent = make("TextLabel", {
		Size = UDim2.fromOffset(200, 22), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.585, 0),
		BackgroundTransparency = 1, Text = "0%", TextColor3 = Color3.fromRGB(170, 205, 240), Font = Enum.Font.GothamBold, TextSize = 16,
	}, root)

	ui.playBtn = make("TextButton", {
		Size = UDim2.fromOffset(260, 64), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.67, 0),
		BackgroundColor3 = Color3.fromRGB(50, 190, 100), Text = "PLAY", TextColor3 = WHITE, Font = Enum.Font.GothamBlack,
		TextSize = 32, AutoButtonColor = false, Visible = false, BackgroundTransparency = 1, TextTransparency = 1,
	}, root)
	if fancy then make("UICorner", { CornerRadius = UDim.new(0, 14) }, ui.playBtn) end
	ui.playScale = make("UIScale", { Scale = 1 }, ui.playBtn)

	ui.skipBtn = make("TextButton", {
		Size = UDim2.fromOffset(140, 42), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -24),
		BackgroundColor3 = Color3.fromRGB(20, 40, 70), BackgroundTransparency = 0.15, Text = "SKIP  >>",
		TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextSize = 18,
	}, root)
	if fancy then
		make("UICorner", { CornerRadius = UDim.new(0, 10) }, ui.skipBtn)
		make("UIStroke", { Color = Color3.fromRGB(110, 160, 215), Thickness = 1 }, ui.skipBtn)
	end

	ui.tip = make("TextLabel", {
		Size = UDim2.fromOffset(900, 24), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.78, 0),
		BackgroundTransparency = 1, Text = "", TextColor3 = Color3.fromRGB(200, 225, 250), Font = Enum.Font.Gotham,
		TextSize = 17, TextTransparency = 1,
	}, root)

	return ui
end

local ok, ui = xpcall(buildUI, debug.traceback, true)
if not ok then
	warn("[LoadingScreen] the fancy screen failed, using a simple one:\n" .. tostring(ui))
	ok, ui = xpcall(buildUI, debug.traceback, false)
end
if not ok then
	warn("[LoadingScreen] could not build any loading screen, starting the game directly:\n" .. tostring(ui))
	player:SetAttribute("GameStarted", true)
	return
end

ui.gui.Parent = playerGui
print("[LoadingScreen] screen is up")
pcall(function() ReplicatedFirst:RemoveDefaultLoadingScreen() end)

-- LOADING STEPS ------------------------------------------------------------------------------
local weights = { Game = 0.10, World = 0.60, Data = 0.10, Sounds = 0.20 }
local prog = { Game = 0, World = 0, Data = 0, Sounds = 0 }
local startTime = os.clock()
local closed, ready = false, false

-- 1) the game itself
task.spawn(function()
	if not game:IsLoaded() then game.Loaded:Wait() end
	prog.Game = 1
end)

-- 2) the world: the server says how many objects it built, we wait until we have them all
local WORLD_FOLDERS = { "OceanTiles", "WorldEdge", "Territories", "AISpawns", "Decor" }
local function countWorld()
	local n = 0
	for _, name in ipairs(WORLD_FOLDERS) do
		local f = workspace:FindFirstChild(name)
		if f then n += #f:GetDescendants() + 1 end
	end
	return n
end

task.spawn(function()
	local readySince
	while not closed do
		local total = workspace:GetAttribute("WorldTotal")
		if workspace:GetAttribute("ServerReady") and total then
			readySince = readySince or os.clock()
			if workspace.StreamingEnabled then
				prog.World = 1
				break
			end
			local n = countWorld()
			prog.World = math.clamp(n / math.max(total, 1), 0, 0.99)
			if n >= total - 8 or os.clock() - readySince > 20 then
				prog.World = 1
				break
			end
		else
			-- the server is still building: creep so the bar stays alive
			prog.World = math.min(0.3, (os.clock() - startTime) / 120)
		end
		task.wait(0.25)
	end
end)

-- 3) your save data
task.spawn(function()
	local t0 = os.clock()
	while not closed do
		if player:FindFirstChild("leaderstats") or os.clock() - t0 > 25 then
			prog.Data = 1
			break
		end
		prog.Data = math.min(0.8, (os.clock() - t0) / 20)
		task.wait(0.2)
	end
end)

-- 4) sounds
task.spawn(function()
	local module = ReplicatedStorage:WaitForChild("SoundConfig", 15)
	if not module then
		prog.Sounds = 1
		return
	end
	local loaded, Config = pcall(require, module)
	if not loaded then
		prog.Sounds = 1
		return
	end
	local seen, list = {}, {}
	for _, cfg in pairs(Config.Sounds) do
		if not seen[cfg.Id] then
			seen[cfg.Id] = true
			local s = Instance.new("Sound")
			s.SoundId = cfg.Id
			table.insert(list, s)
		end
	end
	local total, done = #list, 0
	if total == 0 then
		prog.Sounds = 1
		return
	end
	task.delay(15, function() prog.Sounds = 1 end) -- never wait forever for sounds
	pcall(function()
		ContentProvider:PreloadAsync(list, function()
			done += 1
			prog.Sounds = math.max(prog.Sounds, math.min(done / total, 0.99))
		end)
	end)
	prog.Sounds = 1
	for _, s in ipairs(list) do s:Destroy() end
end)

-- progress report in Output (first minute only)
task.spawn(function()
	local pct = function(x) return math.floor(x * 100 + 0.5) end
	for _ = 1, 20 do
		task.wait(3)
		if closed then return end
		print(("[LoadingScreen] game %d%% | world %d%% | data %d%% | sounds %d%%"):format(
			pct(prog.Game), pct(prog.World), pct(prog.Data), pct(prog.Sounds)))
	end
end)

-- BUTTONS --------------------------------------------------------------------------------------
local connections = {}

local function click()
	local s = Instance.new("Sound")
	s.SoundId = "rbxasset://sounds/clickfast.wav"
	s.Volume = 0.5
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, 1)
end

local function fadeOut(gui)
	local info = TweenInfo.new(0.6)
	for _, d in ipairs(gui:GetDescendants()) do
		if d:IsA("GuiObject") then
			local goals = { BackgroundTransparency = 1 }
			if d:IsA("TextLabel") or d:IsA("TextButton") then
				goals.TextTransparency = 1
				goals.TextStrokeTransparency = 1
			end
			TweenService:Create(d, info, goals):Play()
		elseif d:IsA("UIStroke") then
			TweenService:Create(d, info, { Transparency = 1 }):Play()
		end
	end
end

local function close()
	if closed then return end
	closed = true
	click()
	player:SetAttribute("GameStarted", true)
	fadeOut(ui.gui)
	task.delay(0.8, function()
		for _, c in ipairs(connections) do c:Disconnect() end
		ui.gui:Destroy()
		print("[LoadingScreen] closed")
	end)
end

local function setReady()
	ready = true
	ui.status.Text = "Everything is ready!"
	ui.barFill.Size = UDim2.fromScale(1, 1)
	ui.percent.Text = "100%"
	if ui.barGradient then
		ui.barGradient.Color = ColorSequence.new(Color3.fromRGB(90, 230, 140), Color3.fromRGB(50, 180, 100))
	else
		ui.barFill.BackgroundColor3 = Color3.fromRGB(70, 200, 120)
	end
	ui.skipBtn.Visible = false
	ui.playBtn.Visible = true
	TweenService:Create(ui.playBtn, TweenInfo.new(0.5), { BackgroundTransparency = 0, TextTransparency = 0 }):Play()
end

table.insert(connections, ui.skipBtn.MouseButton1Click:Connect(close))
table.insert(connections, ui.playBtn.MouseButton1Click:Connect(close))
table.insert(connections, ui.playBtn.MouseEnter:Connect(function()
	TweenService:Create(ui.playScale, TweenInfo.new(0.15), { Scale = 1.07 }):Play()
end))
table.insert(connections, ui.playBtn.MouseLeave:Connect(function()
	TweenService:Create(ui.playScale, TweenInfo.new(0.15), { Scale = 1 }):Play()
end))
table.insert(connections, UserInputService.InputBegan:Connect(function(input)
	if ready and (input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.Space) then
		close()
	end
end))

-- ANIMATION + PROGRESS BAR ----------------------------------------------------------------------
local function statusText(t)
	local dots = string.rep(".", math.floor(t * 2) % 4)
	local msg
	if prog.Game < 1 then
		msg = "Connecting to the game"
	elseif prog.World < 1 then
		msg = "Building the ocean world"
	elseif prog.Data < 1 then
		msg = "Loading your captain's data"
	else
		msg = "Tuning the cannons and the sea sounds"
	end
	if t > SLOW_AFTER then
		return msg .. dots .. "   (taking longer than usual - you can press SKIP)"
	end
	return msg .. dots
end

local displayed = 0
table.insert(connections, RunService.RenderStepped:Connect(function(dt)
	local t = os.clock() - startTime

	for i, f in ipairs(ui.waves) do
		f.Position = UDim2.new(-0.1 + math.sin(t * 0.4 + i) * 0.03, 0, 1, -60 - i * 22 + math.sin(t * 1.1 + i * 1.7) * 10)
	end

	if closed or ready then return end
	local overall = 0
	for k, w in pairs(weights) do overall += w * prog[k] end
	displayed += (overall - displayed) * math.min(1, dt * 4)
	ui.barFill.Size = UDim2.fromScale(math.clamp(displayed, 0, 1), 1)
	ui.percent.Text = ("%d%%"):format(math.floor(displayed * 100 + 0.5))

	if overall >= 0.999 and displayed >= 0.985 then
		setReady()
	else
		ui.status.Text = statusText(t)
	end
end))

-- rotating tips
task.spawn(function()
	local i = math.random(#TIPS)
	while not closed do
		ui.tip.Text = "TIP:  " .. TIPS[i]
		TweenService:Create(ui.tip, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
		task.wait(4.5)
		if closed then return end
		TweenService:Create(ui.tip, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		task.wait(0.55)
		i = i % #TIPS + 1
	end
end)