local Waves = {}

Waves.Strength = 2.85   -- 0 = flat sea, 1 = normal, 2 = stormy
Waves.ShipTilt = 1.75   -- how strongly ships tilt with the swell
Waves.Drift = 1.2      -- studs/second the swell pushes a ship along

-- direction (degrees), wavelength, height, speed (studs/second)
local LAYERS = {
	{ dir = 25,  len = 260, amp = 1.3,  speed = 14 }, -- long, slow swell
	{ dir = 80,  len = 170, amp = 0.55, speed = 11 }, -- cross swell
	{ dir = -40, len = 120, amp = 0.2,  speed = 8 },  -- gentle ripple
}


local PRE = {}
for i, l in ipairs(LAYERS) do
	local a = math.rad(l.dir)
	local k = 2 * math.pi / l.len
	PRE[i] = { dx = math.cos(a), dz = math.sin(a), k = k, w = k * l.speed, amp = l.amp }
end

-- the server and every client read the same clock, so the water matches everywhere
function Waves.Now()
	return workspace:GetServerTimeNow()
end

-- returns height, slope along x, slope along z at a world position
function Waves.Sample(x, z, t)
	local h, sx, sz = 0, 0, 0
	for _, l in ipairs(PRE) do
		local phase = l.k * (x * l.dx + z * l.dz) - l.w * t
		h += l.amp * math.sin(phase)
		local d = l.amp * l.k * math.cos(phase)
		sx += d * l.dx
		sz += d * l.dz
	end
	local s = Waves.Strength
	return h * s, sx * s, sz * s
end

-- the way the main swell travels (flat, unit length)
Waves.Direction = Vector3.new(PRE[1].dx, 0, PRE[1].dz)

return Waves