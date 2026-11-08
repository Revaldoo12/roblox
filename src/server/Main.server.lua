--[[
	Main.server.lua
	  1. Membuat RemoteEvent & menyiapkan dunia, monetisasi, leaderboard.
	  2. Memvalidasi skor dari client (anti-cheat dasar).
	  3. Menyimpan high score ke DataStore + leaderstats.

	Anti-cheat: durasi run diukur di SERVER (dari RunStarted ke RunEnded).
	Skor di atas (kecepatan maks + dash) x durasi mustahil secara fisika -> ditolak.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local serverFolder = script.Parent
local Environment = require(serverFolder:WaitForChild("Environment"))
local Monetization = require(serverFolder:WaitForChild("Monetization"))
local GlobalLeaderboard = require(serverFolder:WaitForChild("GlobalLeaderboard"))

Remotes.Init()
Environment.Setup()
Monetization.Init()
GlobalLeaderboard.Init()

local RunStarted = Remotes.Get("RunStarted")
local RunEnded = Remotes.Get("RunEnded")
local ScoreValidated = Remotes.Get("ScoreValidated")

local highScoreStore = nil
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

-- state run per pemain
local runState: { [Player]: { startTime: number, ended: boolean, revivePending: boolean } } = {}

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
	task.spawn(function()
		pcall(function()
			highScoreStore:UpdateAsync("hs_" .. player.UserId, function(old)
				return math.max(tonumber(old) or 0, score)
			end)
		end)
	end)
end

Monetization.OnReviveGranted = function(player: Player)
	local s = runState[player]
	if s then
		s.revivePending = true
	end
end

RunStarted.OnServerEvent:Connect(function(player)
	runState[player] = { startTime = os.clock(), ended = false, revivePending = false }
end)

RunEnded.OnServerEvent:Connect(function(player, reportedScore: any)
	local stats = player:FindFirstChild("leaderstats")
	local bestValue = stats and stats:FindFirstChild("Best")
	local currentBest = if bestValue then bestValue.Value else 0

	local s = runState[player]
	local valid = typeof(reportedScore) == "number"
		and reportedScore == reportedScore -- bukan NaN
		and reportedScore >= 0
		and s ~= nil
		and (not s.ended or s.revivePending)

	if not valid then
		ScoreValidated:FireClient(player, 0, false, currentBest)
		return
	end

	local duration = os.clock() - s.startTime
	local maxPossible = (GameConfig.MaxSpeed + GameConfig.DashSpeedBonus) * duration * 1.1 + 20
	s.ended = true
	s.revivePending = false

	if reportedScore > maxPossible then
		warn(("[OBC] Skor ditolak dari %s: %d (maks wajar ~%d)"):format(
			player.Name,
			math.floor(reportedScore),
			math.floor(maxPossible)
		))
		ScoreValidated:FireClient(player, 0, false, currentBest)
		return
	end

	local official = math.floor(reportedScore)
	if Monetization.OwnsDoubleScore(player) then
		official *= 2
	end

	if official > currentBest then
		if bestValue then
			bestValue.Value = official
		end
		currentBest = official
		saveHighScore(player, official)
	end
	if official > 0 then
		task.spawn(GlobalLeaderboard.Submit, player, official)
	end

	ScoreValidated:FireClient(player, official, true, currentBest)
end)

local function onPlayerAdded(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local best = Instance.new("IntValue")
	best.Name = "Best"
	best.Value = 0
	best.Parent = stats
	stats.Parent = player
	best.Value = loadHighScore(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
	runState[player] = nil
end)

print("[OneButtonChaos] Server siap ✔")
