--[[
	Monetization.lua
	  - Game Pass DoubleScore  : skor resmi x2 (dihitung di server)
	  - Game Pass RainbowTrail : trail pelangi permanen
	  - Dev Product Revive     : lanjut dari titik crash (1x per run)
	ID diatur di src/shared/GameConfig.lua. ID 0 = fitur nonaktif.

	ProcessReceipt dibuat idempotent: setiap PurchaseId dicatat di DataStore,
	jadi pembelian tidak diproses dua kali walau server restart.
--]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Monetization = {}
Monetization.OnReviveGranted = nil -- diisi Main.server (untuk izinkan run berlanjut)

local perks: { [Player]: { doubleScore: boolean, rainbowTrail: boolean } } = {}

local receiptStore = nil
do
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore("OBC_Receipts_v1")
	end)
	if ok then
		receiptStore = store
	end
end

local function getPerks(player: Player)
	local p = perks[player]
	if not p then
		p = { doubleScore = false, rainbowTrail = false }
		perks[player] = p
	end
	return p
end

local function push(player: Player)
	Remotes.Get("PerksUpdated"):FireClient(player, getPerks(player))
end

local function owns(player: Player, passId: number): boolean
	if passId == 0 then
		return false
	end
	local ok, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	return ok and result == true
end

function Monetization.OwnsDoubleScore(player: Player): boolean
	return getPerks(player).doubleScore
end

local function onPlayerAdded(player: Player)
	local p = getPerks(player)
	p.doubleScore = owns(player, GameConfig.GamePassIds.DoubleScore)
	p.rainbowTrail = owns(player, GameConfig.GamePassIds.RainbowTrail)
	push(player)
end

local function grantProduct(player: Player, productId: number): boolean
	if productId == GameConfig.ProductIds.Revive and productId ~= 0 then
		if Monetization.OnReviveGranted then
			Monetization.OnReviveGranted(player)
		end
		Remotes.Get("GrantRevive"):FireClient(player)
		return true
	end
	return false
end

local function processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- tanpa DataStore (mis. Studio tanpa API) tetap berikan, tapi tanpa jaminan anti-duplikat
	if not receiptStore then
		grantProduct(player, receiptInfo.ProductId)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local key = tostring(receiptInfo.PurchaseId)
	local alreadyGranted = false
	local ok = pcall(function()
		receiptStore:UpdateAsync(key, function(old)
			if old then
				alreadyGranted = true
				return nil -- jangan ubah
			end
			return true
		end)
	end)
	if not ok then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not alreadyGranted then
		grantProduct(player, receiptInfo.ProductId)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function Monetization.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, p)
	end
	Players.PlayerRemoving:Connect(function(player)
		perks[player] = nil
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local p = getPerks(player)
		if passId == GameConfig.GamePassIds.DoubleScore then
			p.doubleScore = true
		elseif passId == GameConfig.GamePassIds.RainbowTrail then
			p.rainbowTrail = true
		end
		push(player)
	end)

	MarketplaceService.ProcessReceipt = processReceipt
	print("[OBC] Monetisasi siap (atur ID di GameConfig.lua).")
end

return Monetization
