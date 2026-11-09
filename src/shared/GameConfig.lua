--[[
	GameConfig.lua
	Semua angka tuning, warna, suara, dan ID monetisasi ada di sini.
	Tema: jalan setapak di atas awan. Warna hangat & lembut, tanpa neon.
--]]

local GameConfig = {}

GameConfig.GameTitle = "ONE BUTTON CHAOS"

-- ===== DUNIA =====
GameConfig.TrackY = 100 -- tinggi permukaan jalan
GameConfig.TrackWidth = 14
GameConfig.KillY = GameConfig.TrackY - 25 -- jatuh di bawah ini = gagal
GameConfig.Gravity = 130
GameConfig.ViewDistance = 520 -- jarak jalan dibangun di depan pemain (PC/konsol)
GameConfig.ViewDistanceLow = 380 -- untuk perangkat ringan (HP)
GameConfig.CleanupBehind = 80

-- ===== KECEPATAN (dihitung dari jarak agar pola rintangan selalu adil) =====
GameConfig.StartSpeed = 26
GameConfig.MaxSpeed = 80
GameConfig.SpeedRamp = 0.8

-- ===== AKSI SATU TOMBOL =====
GameConfig.JumpPower = 48
GameConfig.DashSpeedBonus = 40
GameConfig.DashDuration = 0.35
GameConfig.CoyoteTime = 0.1
GameConfig.JumpBuffer = 0.12
GameConfig.ActionCooldown = 0.06

-- ===== RINTANGAN =====
GameConfig.SafeStartDistance = 70
GameConfig.DifficultyFullDistance = 5000
GameConfig.TutorialUntil = 900

-- ===== SKOR =====
GameConfig.MilestoneEvery = 1000

-- ===== MATERIAL & WARNA (lembut, hangat) =====
GameConfig.Colors = {
	PathA = Color3.fromRGB(226, 206, 176), -- batu pasir hangat
	PathB = Color3.fromRGB(212, 190, 160),
	PathEdge = Color3.fromRGB(170, 146, 118),
	Wood = Color3.fromRGB(168, 124, 92),
	WoodDark = Color3.fromRGB(128, 92, 70),
	Rope = Color3.fromRGB(214, 196, 160),
	Cloud = Color3.fromRGB(250, 250, 252),
	CloudShade = Color3.fromRGB(228, 234, 244),
	Grass = Color3.fromRGB(132, 190, 112),
	GrassDark = Color3.fromRGB(106, 160, 96),
	Rock = Color3.fromRGB(176, 164, 152),
	RockDark = Color3.fromRGB(142, 132, 124),
	Leaf = Color3.fromRGB(132, 184, 120),
	LeafLight = Color3.fromRGB(170, 210, 140),

	-- rintangan: cukup kontras dengan jalan, tapi tetap kalem
	Obstacle = Color3.fromRGB(206, 122, 98), -- terakota
	ObstacleTrim = Color3.fromRGB(244, 226, 196),
	Stone = Color3.fromRGB(124, 128, 140),
	StoneTrim = Color3.fromRGB(210, 150, 110),
	Warning = Color3.fromRGB(232, 170, 96), -- bendera/tanda di tepi jurang
	Flags = {
		Color3.fromRGB(232, 140, 120),
		Color3.fromRGB(240, 206, 120),
		Color3.fromRGB(140, 196, 170),
		Color3.fromRGB(140, 170, 220),
	},
	Balloon = {
		Color3.fromRGB(236, 150, 130),
		Color3.fromRGB(240, 210, 130),
		Color3.fromRGB(150, 190, 225),
		Color3.fromRGB(170, 205, 160),
	},
}

-- ===== ZONA (waktu di langit berganti) =====
GameConfig.ZoneLength = 800

-- Key = kunci nama di Locale.lua
GameConfig.Zones = {
	{
		Key = "zone_dawn",
		ClockTime = 6.6,
		Accent = Color3.fromRGB(236, 160, 140),
		AtmoColor = Color3.fromRGB(240, 200, 190),
		AtmoDecay = Color3.fromRGB(200, 150, 160),
		Ambient = Color3.fromRGB(150, 130, 140),
		Brightness = 2,
	},
	{
		Key = "zone_day",
		ClockTime = 12.5,
		Accent = Color3.fromRGB(110, 165, 225),
		AtmoColor = Color3.fromRGB(200, 222, 245),
		AtmoDecay = Color3.fromRGB(150, 185, 225),
		Ambient = Color3.fromRGB(140, 150, 165),
		Brightness = 2.4,
	},
	{
		Key = "zone_golden",
		ClockTime = 16.4,
		Accent = Color3.fromRGB(232, 178, 98),
		AtmoColor = Color3.fromRGB(245, 215, 170),
		AtmoDecay = Color3.fromRGB(215, 165, 120),
		Ambient = Color3.fromRGB(160, 140, 120),
		Brightness = 2.2,
	},
	{
		Key = "zone_sunset",
		ClockTime = 17.7,
		Accent = Color3.fromRGB(220, 130, 140),
		AtmoColor = Color3.fromRGB(230, 170, 165),
		AtmoDecay = Color3.fromRGB(150, 110, 150),
		Ambient = Color3.fromRGB(150, 120, 135),
		Brightness = 1.8,
	},
	{
		Key = "zone_night",
		ClockTime = 0.5,
		Accent = Color3.fromRGB(160, 170, 230),
		AtmoColor = Color3.fromRGB(90, 100, 140),
		AtmoDecay = Color3.fromRGB(50, 56, 90),
		Ambient = Color3.fromRGB(110, 115, 145),
		Brightness = 1.2,
	},
}

function GameConfig.GetZone(distance: number)
	local index = math.max(0, math.floor(distance / GameConfig.ZoneLength))
	return GameConfig.Zones[(index % #GameConfig.Zones) + 1], index
end

-- ===== SUARA =====
-- Suara bawaan Roblox (rbxasset://) supaya langsung bunyi.
-- Ganti dengan "rbxassetid://<ID>" dari Creator Store kalau mau suara sendiri.
GameConfig.Sounds = {
	Jump = { Id = "rbxasset://sounds/action_jump.mp3", Volume = 0.45 },
	Land = { Id = "rbxasset://sounds/action_jump_land.mp3", Volume = 0.25 },
	Dash = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.6 },
	Crash = { Id = "rbxasset://sounds/collide.wav", Volume = 0.7 },
	Tick = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.35 },
	Go = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5 },
	Milestone = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.4 },
	Click = { Id = "rbxasset://sounds/button.wav", Volume = 0.4 },
}
GameConfig.MusicId = "rbxassetid://1840684529" -- "Cool Vibes" oleh APM Music (berlisensi di Roblox Creator Store)
GameConfig.MusicVolume = 0.3

-- ===== MONETISASI =====
-- Buat item di Creator Hub, lalu ganti 0 dengan ID-nya. 0 = tombol disembunyikan.
GameConfig.GamePassIds = {
	DoubleScore = 0,
	RainbowTrail = 0,
}
GameConfig.ProductIds = {
	Revive = 0,
}

return GameConfig
