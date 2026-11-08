--[[
	TrackGenerator.lua
	Menghasilkan pola rintangan secara deterministik (seed).
	Semua jarak dihitung dari fisika lompat & dash pada kecepatan saat itu,
	jadi setiap pola SELALU bisa dilewati (susah tapi adil).

	Jenis fitur:
	  Wall     - dinding neon rendah            -> LOMPAT
	  Laser    - pagar laser                    -> LOMPAT
	  Gap      - jurang (long = butuh LOMPAT + DASH)
	  Crusher  - balok penghancur naik-turun    -> timing (lewat bawah / lompati)
--]]

local GameConfig = require(script.Parent.GameConfig)

local TrackGenerator = {}
TrackGenerator.__index = TrackGenerator

function TrackGenerator.SpeedAt(distance: number): number
	local s0 = GameConfig.StartSpeed
	local s = math.sqrt(s0 * s0 + 2 * GameConfig.SpeedRamp * math.max(distance, 0))
	return math.min(s, GameConfig.MaxSpeed)
end

function TrackGenerator.AirTime(): number
	return 2 * GameConfig.JumpPower / GameConfig.Gravity
end

function TrackGenerator.AirDistance(distance: number): number
	return TrackGenerator.SpeedAt(distance) * TrackGenerator.AirTime()
end

function TrackGenerator.DashDistance(distance: number): number
	return (TrackGenerator.SpeedAt(distance) + GameConfig.DashSpeedBonus) * GameConfig.DashDuration
end

local function weightedPick(rng: Random, weights)
	local total = 0
	for _, entry in ipairs(weights) do
		total += entry[2]
	end
	local r = rng:NextNumber() * total
	for _, entry in ipairs(weights) do
		r -= entry[2]
		if r <= 0 then
			return entry[1]
		end
	end
	return weights[#weights][1]
end

local function weightsFor(d: number)
	if d < 250 then
		return { { "Wall", 3 }, { "GapShort", 1.2 } }
	elseif d < 700 then
		return { { "Wall", 3 }, { "Laser", 2 }, { "GapShort", 2 }, { "GapLong", 1.6 } }
	elseif d < 1300 then
		return {
			{ "Wall", 2.5 },
			{ "Laser", 2 },
			{ "GapShort", 1.6 },
			{ "GapLong", 1.6 },
			{ "DoubleWall", 1.4 },
			{ "WallGap", 1.2 },
		}
	end
	return {
		{ "Wall", 2 },
		{ "Laser", 2 },
		{ "GapShort", 1.3 },
		{ "GapLong", 1.6 },
		{ "DoubleWall", 1.4 },
		{ "WallGap", 1.4 },
		{ "Crusher", 1.6 },
	}
end

function TrackGenerator.new(seed: number)
	local self = setmetatable({}, TrackGenerator)
	self._rng = Random.new(seed)
	self.cursor = GameConfig.SafeStartDistance
	self._last = ""
	return self
end

-- Mengembalikan daftar fitur untuk satu pola, lalu memajukan cursor.
function TrackGenerator:Next()
	local rng = self._rng
	local d = self.cursor
	local air = TrackGenerator.AirDistance(d) * 0.95 -- margin keamanan
	local dash = TrackGenerator.DashDistance(d)
	local difficulty = math.clamp(d / GameConfig.DifficultyFullDistance, 0, 1)

	local kind = weightedPick(rng, weightsFor(d))
	if kind == self._last and kind ~= "Wall" and kind ~= "Laser" then
		kind = weightedPick(rng, weightsFor(d))
	end
	self._last = kind

	local features = {}
	local endD = d

	if kind == "Wall" then
		table.insert(features, { kind = "Wall", z = d, length = 2.5 })
		endD = d + 2.5
	elseif kind == "Laser" then
		table.insert(features, { kind = "Laser", z = d, length = 1.5 })
		endD = d + 1.5
	elseif kind == "GapShort" then
		local len = air * rng:NextNumber(0.4, 0.55)
		table.insert(features, { kind = "Gap", z = d, length = len, long = false })
		endD = d + len
	elseif kind == "GapLong" then
		local len = air + dash * rng:NextNumber(0.3, 0.45)
		table.insert(features, { kind = "Gap", z = d, length = len, long = true })
		endD = d + len
	elseif kind == "DoubleWall" then
		local second = d + air * 0.5
		table.insert(features, { kind = "Wall", z = d, length = 2.5 })
		table.insert(features, { kind = "Wall", z = second, length = 2.5 })
		endD = second + 2.5
	elseif kind == "WallGap" then
		local gapStart = d + air * 0.6
		local gapLen = air * 0.5
		table.insert(features, { kind = "Wall", z = d, length = 2.5 })
		table.insert(features, { kind = "Gap", z = gapStart, length = gapLen, long = true })
		endD = gapStart + gapLen
	elseif kind == "Crusher" then
		table.insert(features, { kind = "Crusher", z = d, length = 5, phase = rng:NextNumber() })
		endD = d + 5
	end

	local spacing = air * (2.4 - 1.05 * difficulty) + rng:NextNumber(0, air * 0.6)
	self.cursor = endD + math.max(spacing, 28)
	return features
end

return TrackGenerator
