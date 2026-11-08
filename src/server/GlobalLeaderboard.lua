--!strict
--[[
	GlobalLeaderboard.lua
	------------------------------------------------------------
	Papan skor GLOBAL top-N antar semua pemain menggunakan OrderedDataStore.
	Mengirim daftar top ke client lewat RemoteEvent "LeaderboardUpdated".

	Catatan: OrderedDataStore butuh API Services aktif (Game Settings → Security).
--]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local GlobalLeaderboard = {}

local TOP_COUNT = 10 -- jumlah yang ditampilkan di panel
local REFRESH_INTERVAL = 60 -- detik

local orderedStore: OrderedDataStore? = nil
do
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore("OBC_GlobalScores_v1")
	end)
	if ok then
		orderedStore = store
	else
		warn("[OBC] OrderedDataStore tidak tersedia untuk leaderboard global.")
	end
end

local cachedTop: { { name: string, score: number } } = {}

-- Catat skor pemain ke leaderboard global (hanya jika lebih tinggi)
function GlobalLeaderboard.Submit(player: Player, score: number)
	if not orderedStore or score <= 0 then
		return
	end
	local store = orderedStore
	pcall(function()
		store:UpdateAsync(tostring(player.UserId), function(old)
			return math.max(tonumber(old) or 0, math.floor(score))
		end)
	end)
end

local nameCache: { [number]: string } = {}

local function usernameFromUserId(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok and typeof(name) == "string" then
		nameCache[userId] = name
		return name
	end
	return "Player" .. tostring(userId)
end

function GlobalLeaderboard.Refresh()
	if not orderedStore then
		return
	end
	local ok, pages = pcall(function()
		return orderedStore:GetSortedAsync(false, TOP_COUNT)
	end)
	if not ok or not pages then
		return
	end

	local top = {}
	local ok2, data = pcall(function()
		return pages:GetCurrentPage()
	end)
	if not ok2 or not data then
		return
	end

	for _, entry in ipairs(data) do
		local userId = tonumber(entry.key)
		if userId then
			table.insert(top, {
				name = usernameFromUserId(userId),
				score = entry.value,
			})
		end
	end

	cachedTop = top
	local event = Remotes.Get("LeaderboardUpdated")
	event:FireAllClients(cachedTop)
end

function GlobalLeaderboard.GetCached()
	return cachedTop
end

function GlobalLeaderboard.Init()
	-- refresh berkala di background
	task.spawn(function()
		while true do
			GlobalLeaderboard.Refresh()
			task.wait(REFRESH_INTERVAL)
		end
	end)

	-- kirim snapshot ke pemain yang baru join
	Players.PlayerAdded:Connect(function(player)
		task.wait(2)
		local event = Remotes.Get("LeaderboardUpdated")
		event:FireClient(player, cachedTop)
	end)

	print("[OBC] Leaderboard global siap.")
end

return GlobalLeaderboard
