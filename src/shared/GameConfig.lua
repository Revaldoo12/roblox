--[[
	GameConfig.lua
	Semua angka tuning, warna, suara, dan ID monetisasi ada di sini.
--]]

local GameConfig = {}

-- ===== DUNIA =====
GameConfig.TrackY = 100 -- tinggi permukaan lintasan (melayang di atas jurang)
GameConfig.TrackWidth = 14
GameConfig.KillY = GameConfig.TrackY - 25 -- jatuh di bawah ini = crash
GameConfig.Gravity = 130
GameConfig.ViewDistance = 520 -- seberapa jauh lintasan dibangun di depan pemain
GameConfig.CleanupBehind = 80 -- bagian lintasan di belakang pemain yang dihapus

-- ===== KECEPATAN (dihitung dari jarak, jadi pola rintangan selalu adil) =====
GameConfig.StartSpeed = 26
GameConfig.MaxSpeed = 80
GameConfig.SpeedRamp = 0.8

-- ===== AKSI SATU TOMBOL =====
GameConfig.JumpPower = 48
GameConfig.DashSpeedBonus = 40
GameConfig.DashDuration = 0.35
GameConfig.CoyoteTime = 0.1 -- masih bisa lompat sesaat setelah lewat tepi
GameConfig.JumpBuffer = 0.12 -- tekan sesaat sebelum mendarat = langsung lompat
GameConfig.ActionCooldown = 0.06

-- ===== RINTANGAN =====
GameConfig.SafeStartDistance = 70
GameConfig.DifficultyFullDistance = 5000
GameConfig.TutorialUntil = 900 -- label petunjuk muncul sampai jarak ini

-- ===== SKOR =====
GameConfig.MilestoneEvery = 1000

-- ===== VISUAL =====
GameConfig.ZoneLength = 800
GameConfig.HazardColor = Color3.fromRGB(255, 40, 90)
GameConfig.GapColor = Color3.fromRGB(255, 214, 10)
GameConfig.CrusherColor = Color3.fromRGB(255, 150, 0)

GameConfig.Palettes = {
	{
		Name = "NEON CITY",
		Primary = Color3.fromRGB(0, 229, 255),
		Secondary = Color3.fromRGB(255, 0, 200),
		Floor = Color3.fromRGB(14, 16, 34),
		Fog = Color3.fromRGB(70, 30, 130),
	},
	{
		Name = "SUNSET DRIVE",
		Primary = Color3.fromRGB(255, 140, 0),
		Secondary = Color3.fromRGB(255, 40, 140),
		Floor = Color3.fromRGB(30, 14, 28),
		Fog = Color3.fromRGB(140, 50, 80),
	},
	{
		Name = "TOXIC GRID",
		Primary = Color3.fromRGB(120, 255, 40),
		Secondary = Color3.fromRGB(0, 255, 190),
		Floor = Color3.fromRGB(10, 26, 20),
		Fog = Color3.fromRGB(20, 90, 60),
	},
	{
		Name = "VOID PALACE",
		Primary = Color3.fromRGB(180, 90, 255),
		Secondary = Color3.fromRGB(255, 210, 60),
		Floor = Color3.fromRGB(20, 10, 36),
		Fog = Color3.fromRGB(60, 20, 110),
	},
	{
		Name = "OVERDRIVE",
		Primary = Color3.fromRGB(255, 255, 255),
		Secondary = Color3.fromRGB(255, 80, 40),
		Floor = Color3.fromRGB(30, 8, 12),
		Fog = Color3.fromRGB(120, 20, 30),
	},
}

function GameConfig.GetPalette(distance: number)
	local zone = math.max(0, math.floor(distance / GameConfig.ZoneLength))
	return GameConfig.Palettes[(zone % #GameConfig.Palettes) + 1], zone
end

-- ===== SUARA =====
-- Pakai suara bawaan Roblox (rbxasset://) supaya langsung bunyi.
-- Mau ganti? Cari di Creator Store, lalu isi dengan "rbxassetid://<ID>".
GameConfig.Sounds = {
	Jump = { Id = "rbxasset://sounds/action_jump.mp3", Volume = 0.5 },
	Land = { Id = "rbxasset://sounds/action_jump_land.mp3", Volume = 0.3 },
	Dash = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.8 },
	Crash = { Id = "rbxasset://sounds/collide.wav", Volume = 1 },
	Tick = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5 },
	Go = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.8 },
	Milestone = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6 },
	Click = { Id = "rbxasset://sounds/button.wav", Volume = 0.5 },
}
GameConfig.MusicId = "" -- contoh: "rbxassetid://1234567890" (musik berlisensi dari Creator Store)
GameConfig.MusicVolume = 0.35

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
