--!strict
--[[
	ObstacleGenerator.lua
	------------------------------------------------------------
	Logika deterministik untuk menentukan posisi & tipe rintangan.
	Memakai seed supaya server & client bisa menghasilkan pola yang SAMA
	(penting untuk validasi anti-cheat di masa depan).
--]]

local GameConfig = require(script.Parent.GameConfig)

local ObstacleGenerator = {}
ObstacleGenerator.__index = ObstacleGenerator

export type Obstacle = {
	index: number,
	distance: number, -- jarak dari start (studs)
	kind: string, -- "Low" (harus lompat) | "High" (harus dash/menunduk)
	lane: number, -- -1, 0, 1
}

function ObstacleGenerator.new(seed: number)
	local self = setmetatable({}, ObstacleGenerator)
	self._rng = Random.new(seed)
	self._nextDistance = GameConfig.ObstacleSpawnGap
	self._index = 0
	return self
end

-- Mengembalikan rintangan berikutnya berdasarkan kecepatan saat ini.
-- Semakin cepat, jarak antar rintangan semakin kecil (sampai batas minimum).
function ObstacleGenerator:Next(currentSpeed: number): Obstacle
	self._index += 1

	-- gap mengecil seiring kecepatan
	local speedRatio = math.clamp(
		(currentSpeed - GameConfig.StartSpeed) / (GameConfig.MaxSpeed - GameConfig.StartSpeed),
		0,
		1
	)
	local gap = GameConfig.ObstacleSpawnGap
		- (GameConfig.ObstacleSpawnGap - GameConfig.MinObstacleGap) * speedRatio

	-- sedikit variasi random supaya tidak monoton
	gap += self._rng:NextNumber(-1.5, 1.5)
	gap = math.max(GameConfig.MinObstacleGap, gap)

	self._nextDistance += gap

	local kindRoll = self._rng:NextNumber(0, 1)
	local kind = kindRoll < 0.6 and "Low" or "High"

	local laneRoll = self._rng:NextInteger(-1, 1)

	local obstacle: Obstacle = {
		index = self._index,
		distance = self._nextDistance,
		kind = kind,
		lane = laneRoll,
	}
	return obstacle
end

return ObstacleGenerator
