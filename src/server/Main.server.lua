--!strict
--[[
	Main.server.lua
	------------------------------------------------------------
	Titik masuk SERVER.
	  1. Membuat semua RemoteEvent.
	  2. Memvalidasi skor yang dikirim client (anti-cheat dasar).
	  3. Menyimpan high score pemain ke DataStore (persisten).

	CATATAN ANTI-CHEAT:
	Karena game ini client-authoritative untuk gerakan (demi responsivitas),
	server tidak bisa 100% memverifikasi. Tapi kita menolak skor yang MUSTAHIL
	secara fisika: skor maksimum = kecepatan_maks * durasi. Skor di atas itu
	pasti hasil cheat dan ditolak. Ini garis pertahanan pertama yang murah.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

-- modul server tambahan
local serverFolder = script.Parent
local TrackBuilder = require(serverFolder:WaitForChild("TrackBuilder"))
local Monetization = require(serverFolder:WaitForChild("Monetization"))
local GlobalLeaderboard = require(serverFolder:WaitForChild("GlobalLeaderboard"))

Remotes.Init()

-- bangun map + inisialisasi sistem
TrackBuilder.Build()
Monetization.Init()
GlobalLeaderboard.Init()

local RunStarted = Remotes.Get("RunStarted")
local RunEnded = Remotes.Get("RunEnded")
local ScoreValidated = Remotes.Get("ScoreValidated")

-- DataStore untuk high score (dibungkus pcall supaya aman di Studio tanpa API akses)
local highScoreStore: DataStore? = nil
do
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore("OBC_HighScores_v1")
	end)
	if ok then
		highScoreStore = store
	else
		warn("[OBC] DataStore tidak tersedia (aktifkan API Services untuk simpan skor).")
	end
end

-- state ronde per pemain: kapan mulai, untuk validasi durasi
local runState: { [Player]: { startTime: number } } = {}

local function loadHighScore(player: Player): number
	if not highScoreStore then
		return 0
	end
	local ok, value = pcall(function()
		return highScoreStore:GetAsync("hs_" .. player.UserId)
	end)
	if ok and typeof(value) == "number" then
		return value
	end
	return 0
end

local function saveHighScore(player: Player, score: number)
	if not highScoreStore then
		return
	end
	pcall(function()
		highScoreStore:UpdateAsync("hs_" .. player.UserId, function(old)
			old = old or 0
			return math.max(old, score)
		end)
	end)
end

RunStarted.OnServerEvent:Connect(function(player)
	runState[player] = { startTime = os.clock() }
end)

RunEnded.OnServerEvent:Connect(function(player, reportedScore: any, reportedDuration: any)
	-- validasi tipe (client bisa mengirim apa saja — jangan percaya)
	if typeof(reportedScore) ~= "number" or typeof(reportedDuration) ~= "number" then
		ScoreValidated:FireClient(player, 0, false)
		return
	end
	if reportedScore < 0 or reportedDuration < 0 then
		ScoreValidated:FireClient(player, 0, false)
		return
	end

	-- batas fisika: jarak maksimum = kecepatan maksimum * durasi (+ sedikit toleransi)
	local maxPossible = GameConfig.MaxSpeed * reportedDuration * 1.1 + 10
	local accepted = reportedScore <= maxPossible

	-- cek durasi server-side (mencegah fire RunEnded tanpa RunStarted)
	local state = runState[player]
	if not state then
		accepted = false
	end
	runState[player] = nil

	local officialScore = accepted and math.floor(reportedScore) or 0

	-- Game Pass "Double Score": gandakan skor resmi (dihitung di server = aman)
	if accepted and Monetization.OwnsDoubleScore(player) then
		officialScore *= 2
	end

	if accepted and officialScore > 0 then
		saveHighScore(player, officialScore)
		GlobalLeaderboard.Submit(player, officialScore)
	end

	ScoreValidated:FireClient(player, officialScore, accepted)
	if not accepted then
		warn(("[OBC] Skor ditolak dari %s: %s (maks wajar ~%d)"):format(player.Name, tostring(reportedScore), math.floor(maxPossible)))
	end
end)

-- leaderstats agar high score tampil di menu pemain Roblox
Players.PlayerAdded:Connect(function(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	stats.Parent = player

	local best = Instance.new("IntValue")
	best.Name = "Best"
	best.Value = loadHighScore(player)
	best.Parent = stats
end)

Players.PlayerRemoving:Connect(function(player)
	runState[player] = nil
end)

print("[OneButtonChaos] Server siap ✔")
