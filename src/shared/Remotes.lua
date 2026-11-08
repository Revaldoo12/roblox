--!strict
--[[
	Remotes.lua
	------------------------------------------------------------
	Membuat & mengambil RemoteEvent secara konsisten di client/server.
	Server memanggil :Get() untuk membuat, client memanggil untuk mengambil.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

-- Daftar nama remote yang dipakai game
local REMOTE_NAMES = {
	"RunStarted", -- client -> server : pemain mulai ronde
	"RunEnded", -- client -> server : pemain mati, kirim skor & waktu untuk validasi
	"ScoreValidated", -- server -> client : skor resmi setelah divalidasi
	"LeaderboardUpdated", -- server -> client : update papan skor
	"GrantRevive", -- server -> client : pemain membeli revive
	"PerksUpdated", -- server -> client : status Game Pass (2x skor, rainbow trail)
}

function Remotes.Get(name: string): RemoteEvent
	local existing = remotesFolder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end

	if RunService:IsServer() then
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotesFolder
		return remote
	else
		-- Client menunggu server membuat remote
		return remotesFolder:WaitForChild(name, 10) :: RemoteEvent
	end
end

-- Server membuat semua remote saat start
function Remotes.Init()
	if not RunService:IsServer() then
		return
	end
	for _, name in ipairs(REMOTE_NAMES) do
		Remotes.Get(name)
	end
end

return Remotes
