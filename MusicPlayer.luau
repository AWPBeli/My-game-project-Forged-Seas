local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("MusicConfig"))
local WorldConfig = require(ReplicatedStorage:WaitForChild("WorldConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local rng = Random.new()
local S = Config.Synth

local musicOn = Config.Enabled
local volume = Config.Volume

-- MIXER: everything musical goes through one group, so volume and effects apply to all of it -------
local group = Instance.new("SoundGroup")
group.Name = "Music"
group.Volume = musicOn and volume or 0
group.Parent = SoundService

local reverb = Instance.new("ReverbSoundEffect")
reverb.DecayTime = 3
reverb.Density = 0.9
reverb.Diffusion = 0.9
reverb.DryLevel = -2
reverb.WetLevel = -7
reverb.Parent = group

local echo = Instance.new("EchoSoundEffect")
echo.Delay = 0.375
echo.Feedback = 0.3
echo.DryLevel = 0
echo.WetLevel = -9
echo.Parent = group

-- INSTRUMENTS: pools of Sounds that are replayed at different pitches --------------------------------
local function makePool(id, count)
	local pool = { List = {}, I = 1 }
	for i = 1, count do
		local s = Instance.new("Sound")
		s.SoundId = id
		s.SoundGroup = group
		s.Parent = SoundService
		pool.List[i] = s
	end
	return pool
end

local pluck = makePool(S.Sample, 20)
local bass = makePool(S.Sample, 6)
local kick = makePool(S.Kick, 4)
local snare = makePool(S.Snare, 3)
local hat = makePool(S.Hat, 6)
local crash = makePool(S.Kick, 2)

local tokens = {}
local function hit(pool, speed, vol, cut)
	local s = pool.List[pool.I]
	pool.I = pool.I % #pool.List + 1
	s.PlaybackSpeed = speed
	s.Volume = vol
	s.TimePosition = 0
	s:Play()
	local token = (tokens[s] or 0) + 1
	tokens[s] = token
	if cut then
		task.delay(cut, function()
			if tokens[s] == token then s:Stop() end
		end)
	end
end

local function semi(n) return 2 ^ (n / 12) end
local function playPluck(n, vol, cut) hit(pluck, S.Pitch * semi(n), vol, cut or 0.9) end
local function playBass(n, vol, cut) hit(bass, S.Pitch * semi(n), vol, cut or 0.7) end

-- melodies wander up and down these scales
local CALM_SCALE = { 0, 2, 4, 7, 9, 12, 14, 16, 19, 21 } -- major pentatonic, two octaves
local SAIL_SCALE = { 0, 3, 5, 7, 10, 12, 15, 17, 19, 22 } -- minor pentatonic, two octaves
local MOVES = { -2, -1, -1, 0, 1, 1, 2 }
local function walk(idx, size)
	return math.clamp(idx + MOVES[rng:NextInteger(1, #MOVES)], 1, size)
end
local calmIdx, sailIdx = 4, 4

-- THE MOODS: tempo, key, chords (in semitones) and what happens on every step of a bar ------------------------
-- Steps = steps per bar (16 = 16th notes, 12 = triplets for a rolling "wave" feel). Step(pos, chord, key, bar)
local MOODS = {
	Calm = {
		Bpm = 78, Key = 0,
		Chords = { { 0, 4, 7 }, { 7, 11, 14 }, { -3, 0, 4 }, { 5, 9, 12 } },
		Step = function(pos, chord, key, bar)
			-- bass: root on the bar, fifth in the middle, a lively pickup now and then
			if pos == 0 then
				playBass(chord[1] + key - 12, 0.5)
			elseif pos == 8 then
				playBass(chord[3] + key - 12, 0.4)
			elseif (pos == 6 or pos == 14) and rng:NextNumber() < 0.3 then
				playBass(chord[1] + key, 0.3)
			end
			-- a gentle heartbeat every other bar
			if pos == 0 and bar % 2 == 0 then hit(kick, S.KickSpeed * 0.8, 0.3, 0.2) end
			-- flowing arpeggio on the 8th notes
			if pos % 2 == 0 and rng:NextNumber() < 0.8 then
				local order = { 1, 2, 3, 2 }
				local up = pos >= 8 and 12 or 0
				playPluck(chord[order[(pos // 2) % 4 + 1]] + up + key, 0.24, 0.6)
			end
			-- a melody that wanders around the scale
			if (pos % 4 == 0 and rng:NextNumber() < 0.55) or ((pos == 3 or pos == 11) and rng:NextNumber() < 0.25) then
				calmIdx = walk(calmIdx, #CALM_SCALE)
				playPluck(CALM_SCALE[calmIdx] + key, 0.34, 1.2)
			end
			-- soft shaker
			if pos % 4 == 2 then hit(hat, S.HatSpeed, 0.1, 0.07) end
		end,
	},

	Sailing = {
		Bpm = 112, Key = -2, Steps = 12, -- 12 steps per bar = a rolling triplet feel, like waves
		Chords = { { 0, 3, 7 }, { -2, 2, 5 }, { -4, 0, 3 }, { -2, 2, 5 } },
		Step = function(pos, chord, key, bar)
			-- driving bass: root, fifth, root, fifth on the four beats, with a pickup into the next bar
			if pos == 0 or pos == 6 then
				playBass(chord[1] + key - 12, 0.55)
			elseif pos == 3 or pos == 9 then
				playBass(chord[3] + key - 12, 0.45)
			elseif pos == 11 then
				playBass(chord[1] + key, 0.3)
			end
			-- wave drum on beats 1 and 3, a snap on 2 and 4
			if pos == 0 or pos == 6 then hit(kick, S.KickSpeed, 0.6, 0.22) end
			if pos == 3 or pos == 9 then hit(snare, S.SnareSpeed, 0.32, 0.25) end
			-- rolling hats on every triplet
			hit(hat, S.HatSpeed, pos % 3 == 0 and 0.2 or 0.11, 0.07)
			-- rolling arpeggio that swells up and down like waves
			local order = { 1, 2, 3, 2, 3, 2 }
			local up = (pos // 3) % 2 == 1 and 12 or 0
			playPluck(chord[order[pos % 6 + 1]] + up + key, pos % 3 == 0 and 0.36 or 0.24, 0.5)
			-- a shanty-like melody on beats 1 and 3
			if (pos == 0 or pos == 6) and rng:NextNumber() < 0.6 then
				sailIdx = walk(sailIdx, #SAIL_SCALE)
				playPluck(SAIL_SCALE[sailIdx] + key + 12, 0.38, 1.0)
			end
		end,
	},

	Combat = {
		Bpm = 156, Key = -5,
		Chords = { { 0, 3, 7 }, { -4, 0, 3 }, { -2, 2, 5 }, { -5, -1, 2 } },
		Step = function(pos, chord, key, bar)
			local phrase = bar % 4 -- every 4th bar is a build-up with a drum fill
			-- crash cymbal + deep sub on the first beat of each phrase
			if phrase == 0 and pos == 0 then
				hit(crash, 1.3, 0.7, 1.0)
				playBass(chord[1] + key - 24, 0.7, 0.9)
			end
			-- kick: four on the floor + syncopation
			if pos % 4 == 0 then
				hit(kick, S.KickSpeed, 1.0, 0.28)
			elseif pos == 6 or pos == 10 then
				hit(kick, S.KickSpeed, 0.8, 0.25)
			end
			-- snare on 2 and 4, plus ghost notes
			if pos == 4 or pos == 12 then
				hit(snare, S.SnareSpeed, 0.75, 0.3)
			elseif (pos == 7 or pos == 15) and rng:NextNumber() < 0.6 then
				hit(snare, S.SnareSpeed * 1.2, 0.28, 0.15)
			end
			-- driving 16th hats with accents
			hit(hat, S.HatSpeed, pos % 2 == 0 and 0.28 or 0.14, 0.06)
			-- pounding 8th note bass with an octave jump
			if pos % 2 == 0 then
				playBass(chord[1] + key - 12 + (pos % 8 == 6 and 12 or 0), 0.55, 0.3)
			end
			-- power chord stabs
			if pos == 0 or pos == 3 or pos == 6 or pos == 10 or pos == 14 then
				for i = 1, 3 do playPluck(chord[i] + key, 0.2, 0.35) end
			end
			-- relentless 16th note lead riff (it climbs through the last bar of every phrase)
			local order = { 1, 3, 2, 3, 1, 2, 3, 2, 1, 3, 2, 3, 3, 2, 1, 2 }
			local building = phrase == 3 and pos >= 8
			local up = (pos % 4 >= 2) and 12 or 0
			playPluck(chord[order[pos + 1]] + up + (building and 12 or 0) + key, 0.22 + (building and (pos - 8) * 0.02 or 0), 0.18)
			-- tom fill at the end of the phrase
			if phrase == 3 and pos >= 12 then
				hit(kick, S.KickSpeed * (1.9 - 0.2 * (pos - 12)), 0.8, 0.22)
			end
		end,
	},
}

local function realTracks(mood)
	local list = Config.Tracks[mood]
	return (list and #list > 0) and list or nil
end

-- the sequencer: one tick per step, moods can change on the bar line -----------------------------------------
local currentMood, pendingMood = "Calm", "Calm"
local stepIndex = 0

task.spawn(function()
	local nextTime = os.clock()
	while true do
		task.wait()
		local now = os.clock()
		if now >= nextTime then
			local mood = MOODS[currentMood]
			local steps = mood.Steps or 16
			if now - nextTime > 0.5 then nextTime = now end
			nextTime += 240 / mood.Bpm / steps -- one bar = 4 beats
			local pos = stepIndex % steps
			if pos == 0 and pendingMood ~= currentMood then -- mood changes happen on the bar line
				currentMood = pendingMood
				mood = MOODS[currentMood]
				steps = mood.Steps or 16
				stepIndex = 0
				pos = 0
			end
			if musicOn and not realTracks(currentMood) then
				local bar = stepIndex // steps
				local chord = mood.Chords[bar % #mood.Chords + 1]
				mood.Step(pos, chord, mood.Key, bar)
			end
			stepIndex += 1
		end
	end
end)
-- REAL TRACKS (only used for moods where you pasted ids into MusicConfig.Tracks) ---------------------------
local wantedMood = "Calm"
local real = { Sound = nil, Mood = nil }

local function fadeOutReal()
	if real.Sound then
		local old = real.Sound
		real.Sound, real.Mood = nil, nil
		TweenService:Create(old, TweenInfo.new(Config.CrossfadeSeconds), { Volume = 0 }):Play()
		Debris:AddItem(old, Config.CrossfadeSeconds + 0.3)
	end
end

local playReal
function playReal(mood)
	local list = realTracks(mood)
	if not list then return end
	local item = list[rng:NextInteger(1, #list)]
	local id = type(item) == "table" and item.Id or item
	local vol = type(item) == "table" and (item.Volume or 0.8) or 0.8
	fadeOutReal()
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = 0
	s.SoundGroup = group
	s.Parent = SoundService
	s:Play()
	TweenService:Create(s, TweenInfo.new(Config.CrossfadeSeconds), { Volume = vol }):Play()
	real.Sound, real.Mood = s, mood
	s.Ended:Connect(function()
		local again = real.Sound == s and wantedMood == mood and musicOn
		s:Destroy()
		if again then
			real.Sound, real.Mood = nil, nil
			playReal(mood) -- next track of the same mood
		end
	end)
end

-- WHICH MOOD FITS RIGHT NOW? --------------------------------------------------------------------------------
local HARBOR_R = WorldConfig.Harbor.Radius
local combatUntil, lastCore = 0, nil

local function decideMood()
	local pg = player:FindFirstChild("PlayerGui")
	if pg and pg:FindFirstChild("LoadingScreen") then return "Calm" end
	if workspace.CurrentCamera.CameraType == Enum.CameraType.Scriptable then return "Calm" end -- Drydock

	local boats = workspace:FindFirstChild("Boats")
	local ship = boats and boats:FindFirstChild("Ship_" .. player.UserId)
	if not ship or not ship.PrimaryPart then
		lastCore = nil
		return "Calm"
	end
	local pos = ship.PrimaryPart.Position
	if pos.X * pos.X + pos.Z * pos.Z <= HARBOR_R * HARBOR_R then
		lastCore = ship:GetAttribute("CoreHP")
		return "Calm" -- the harbor is a safe zone
	end

	local now = os.clock()
	local core = ship:GetAttribute("CoreHP")
	if lastCore and core and core < lastCore then combatUntil = now + 14 end -- we are being hit
	lastCore = core

	for _, m in ipairs(boats:GetChildren()) do
		if m ~= ship and m:IsA("Model") and m.PrimaryPart and (m.PrimaryPart.Position - pos).Magnitude < 320 then
			combatUntil = math.max(combatUntil, now + 10) -- enemies are close
		end
	end
	return now < combatUntil and "Combat" or "Sailing"
end

task.spawn(function()
	if realTracks("Calm") and musicOn then playReal("Calm") end
	while true do
		task.wait(0.5)
		local mood = decideMood()
		if mood ~= wantedMood then
			wantedMood = mood
			if realTracks(mood) then
				pendingMood, currentMood = mood, mood
				if musicOn then playReal(mood) end
			else
				fadeOutReal()
				pendingMood = mood -- the synth switches on the next bar line
			end
		end
	end
end)

-- STINGERS: short flourishes for big moments --------------------------------------------------------------------
local function stinger(notes, spacing, vol)
	if not musicOn then return end
	for i, n in ipairs(notes) do
		task.delay((i - 1) * spacing, function() playPluck(n, vol) end)
	end
end

local notify = Remotes:WaitForChild("Notify", 20)
if notify then
	notify.OnClientEvent:Connect(function(text)
		local t = text:lower()
		if t:find("conquered") then
			stinger({ 0, 4, 7, 12, 16, 19 }, 0.1, 0.6)
		elseif t:find("ship destroyed") then
			stinger({ 0, 7, 12 }, 0.08, 0.5)
		elseif t:find("core was destroyed") then
			stinger({ 12, 7, 3, 0, -5 }, 0.2, 0.55)
		elseif t:find("^researched") then
			stinger({ 0, 7, 12, 16 }, 0.07, 0.45)
		end
	end)
end

-- VOLUME PANEL (under the HUD) + HOTKEYS ---------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "MusicUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 2
gui.Parent = player:WaitForChild("PlayerGui")

local function button(text, x, w)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(w, 24)
	b.Position = UDim2.fromOffset(x, 2)
	b.BackgroundColor3 = Color3.fromRGB(45, 70, 110)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.Text = text
	b.Parent = gui:FindFirstChild("Row")
	return b
end

local row = Instance.new("Frame")
row.Name = "Row"
row.Size = UDim2.fromOffset(184, 28)
row.Position = UDim2.fromOffset(12, 134)
row.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
row.BackgroundTransparency = 0.25
row.Parent = gui

local toggle = button("", 2, 120)
local minus = button("-", 126, 26)
local plus = button("+", 154, 26)

local function refreshUI()
	toggle.Text = musicOn and ("MUSIC  %d%%"):format(math.floor(volume * 100 + 0.5)) or "MUSIC  OFF"
	toggle.BackgroundColor3 = musicOn and Color3.fromRGB(40, 140, 80) or Color3.fromRGB(110, 50, 50)
end

local function applyVolume()
	TweenService:Create(group, TweenInfo.new(0.3), { Volume = musicOn and volume or 0 }):Play()
	refreshUI()
end

local function setMusicOn(on)
	musicOn = on
	if on then
		if realTracks(wantedMood) and not real.Sound then playReal(wantedMood) end
	else
		fadeOutReal()
	end
	applyVolume()
end

local function changeVolume(delta)
	volume = math.clamp(math.floor((volume + delta) * 10 + 0.5) / 10, 0, 1)
	applyVolume()
end

toggle.MouseButton1Click:Connect(function() setMusicOn(not musicOn) end)
minus.MouseButton1Click:Connect(function() changeVolume(-0.1) end)
plus.MouseButton1Click:Connect(function() changeVolume(0.1) end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	local pg = player:FindFirstChild("PlayerGui")
	if pg and pg:FindFirstChild("LoadingScreen") then return end
	if input.KeyCode == Enum.KeyCode.N then
		setMusicOn(not musicOn)
	elseif input.KeyCode == Enum.KeyCode.LeftBracket then
		changeVolume(-0.1)
	elseif input.KeyCode == Enum.KeyCode.RightBracket then
		changeVolume(0.1)
	end
end)

-- hide the panel in the Drydock (the part list sits in the same corner)
task.spawn(function()
	while true do
		task.wait(0.3)
		row.Visible = workspace.CurrentCamera.CameraType ~= Enum.CameraType.Scriptable
	end
end)

refreshUI()

-- warn if the built-in instrument clip can't load
task.spawn(function()
	local test = Instance.new("Sound")
	test.SoundId = S.Sample
	pcall(function() ContentProvider:PreloadAsync({ test }) end)
	if test.TimeLength <= 0 then
		warn("[Music] The built-in instrument sound could not load. Put real tracks into MusicConfig.Tracks instead.")
	end
	test:Destroy()
end)