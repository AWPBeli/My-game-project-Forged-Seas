local SoundConfig = {}

SoundConfig.MasterVolume = 1

-- Built-in Roblox clips. Swap any of these for your own rbxassetid://... if one fails to load.
local EXPLO = "rbxasset://sounds/impact_explosion_03.mp3"
local WATER = "rbxasset://sounds/impact_water.mp3"
local PING = "rbxasset://sounds/electronicpingshort.wav"
local CLICK = "rbxasset://sounds/clickfast.wav"
local SNAP = "rbxasset://sounds/snap.mp3"
local GLASS = "rbxasset://sounds/glassbreak.wav"
local ROCKET = "rbxasset://sounds/Rocket shot.wav"
local VICTORY = "rbxasset://sounds/victory.wav"

-- Id, Volume, Speed (pitch), Var (random pitch spread), Min/Max (full volume distance / audible distance), Dur (seconds), UI (flat, not positional)
local function snd(id, volume, speed, var, min, max, dur, ui)
	return { Id = id, Volume = volume, Speed = speed, Var = var, Min = min, Max = max, Dur = dur, UI = ui }
end

SoundConfig.Sounds = {
	-- weapons (the keys match the part ids)
	Cannon1 = snd(EXPLO, 0.55, 1.5, 0.10, 40, 900, 1.0),
	Auto = snd(CLICK, 0.7, 1.9, 0.15, 30, 600, 0.3),
	Cannon2 = snd(EXPLO, 0.95, 0.85, 0.08, 60, 1300, 1.8),
	Missile = snd(ROCKET, 0.8, 1.0, 0.10, 50, 1100, 2.2),
	Rail = snd(PING, 0.9, 0.55, 0.05, 50, 1400, 1.4),

	-- combat
	Hit = snd(SNAP, 0.7, 0.7, 0.20, 25, 500, 0.6),
	HitRock = snd(EXPLO, 0.4, 1.8, 0.15, 25, 450, 0.5),
	Splash = snd(WATER, 0.8, 1.0, 0.15, 30, 700, 1.6),
	Explosion = snd(EXPLO, 0.9, 1.0, 0.08, 60, 1400, 2.0),
	BlockBreak = snd(GLASS, 0.55, 0.8, 0.20, 30, 650, 1.3),
	ShipExplode = snd(EXPLO, 1.0, 0.5, 0.05, 120, 2500, 3.5),

	-- ambience
	Thump = snd(EXPLO, 0.2, 0.45, 0.08, 30, 450, 0.6),      -- engine chug
	SeaSwell = snd(WATER, 0.3, 0.6, 0.12, 20, 250, 2.8),    -- waves around you

	-- interface (flat sounds)
	Click = snd(CLICK, 0.4, 1.0, 0.0, nil, nil, 0.4, true),
	Place = snd(SNAP, 0.5, 1.2, 0.1, nil, nil, 0.5, true),
	Remove = snd(SNAP, 0.5, 0.6, 0.1, nil, nil, 0.5, true),
	Launch = snd(ROCKET, 0.6, 0.9, 0.0, nil, nil, 2.0, true),
	Research = snd(VICTORY, 0.6, 1.0, 0.0, nil, nil, 3.0, true),
	Capture = snd(VICTORY, 0.8, 0.85, 0.0, nil, nil, 3.0, true),
	XP = snd(PING, 0.5, 1.6, 0.05, nil, nil, 1.0, true),
	Lost = snd(EXPLO, 0.5, 0.6, 0.0, nil, nil, 2.0, true),
	Alarm = snd(PING, 0.7, 0.7, 0.0, nil, nil, 1.0, true),
	Error = snd(SNAP, 0.5, 0.5, 0.0, nil, nil, 0.5, true),
}

return SoundConfig