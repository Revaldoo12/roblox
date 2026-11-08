--!strict
--[[
	GameConfig.lua
	------------------------------------------------------------
	Satu tempat untuk semua angka/tuning game.
	Ubah di sini untuk balancing tanpa menyentuh logika.
--]]

local GameConfig = {}

-- ===== KECEPATAN & DIFFICULTY =====
GameConfig.StartSpeed = 24 -- kecepatan lari awal (studs/detik)
GameConfig.MaxSpeed = 90 -- batas kecepatan maksimum
GameConfig.SpeedRampPerSecond = 0.9 -- seberapa cepat makin ngebut tiap detik

-- ===== AKSI TOMBOL =====
GameConfig.JumpPower = 50 -- kekuatan lompat
GameConfig.DashSpeed = 60 -- dorongan saat dash
GameConfig.DashDuration = 0.25 -- berapa lama dash aktif (detik)
GameConfig.ActionCooldown = 0.08 -- jeda minimum antar input (anti-spam)

-- ===== SKOR =====
GameConfig.ScorePerSecond = 10 -- skor otomatis tiap detik hidup
GameConfig.ScorePerObstacle = 25 -- bonus tiap lewatin rintangan

-- ===== RINTANGAN =====
GameConfig.ObstacleSpawnGap = 18 -- jarak antar rintangan (studs) saat awal
GameConfig.MinObstacleGap = 9 -- jarak minimum saat sudah ngebut
GameConfig.LaneWidth = 16 -- lebar lintasan

-- ===== TIPE AKSI (context-sensitive) =====
-- Tombol yang sama melakukan aksi berbeda tergantung situasi karakter.
GameConfig.ActionType = {
	Jump = "Jump", -- saat di tanah
	Dash = "Dash", -- saat di udara / melayang
}

return GameConfig
