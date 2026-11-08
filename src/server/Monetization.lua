--!strict
--[[
	Monetization.lua
	------------------------------------------------------------
	Mengelola Game Pass & Developer Products.

	CARA PAKAI:
	  1. Buat Game Pass / Developer Product di halaman game Roblox (Creator Hub).
	  2. Salin ID-nya ke tabel di bawah (ganti angka 0).
	  3. Game otomatis menangani pembelian & efeknya.

	Jenis monetisasi yang disiapkan:
	  - Game Pass "DoubleScore"  : skor x2 permanen (one-time buy)
	  - Dev Product "Revive"     : hidupkan lagi 1x setelah mati (consumable)
	  - Dev Product "SkinNeon"   : beli skin trail neon (consumable/unlock)
--]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Monetization = {}

-- ⬇️ GANTI dengan ID asli dari Creator Hub kamu
Monetization.GamePasses = {
	DoubleScore = 0, -- contoh: 123456789
}

Monetization.Products = {
	Revive = 0, -- contoh: 987654321
	SkinNeon = 0,
}

-- state fitur yang dibeli per pemain (per sesi)
local ownsDoubleScore: { [Player]: boolean } = {}

function Monetization.OwnsDoubleScore(player: Player): boolean
	return ownsDoubleScore[player] == true
end

local function checkGamePass(player: Player)
	local id = Monetization.GamePasses.DoubleScore
	if id == 0 then
		return
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
	end)
	if ok and owns then
		ownsDoubleScore[player] = true
	end
end

function Monetization.Init()
	Players.PlayerAdded:Connect(checkGamePass)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(checkGamePass, p)
	end

	Players.PlayerRemoving:Connect(function(player)
		ownsDoubleScore[player] = nil
	end)

	-- Game Pass dibeli saat sesi berjalan
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchased)
		if purchased and gamePassId == Monetization.GamePasses.DoubleScore then
			ownsDoubleScore[player] = true
		end
	end)

	-- Developer Product (consumable) — WAJIB mengembalikan status
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not player then
			-- pemain keluar; minta Roblox coba lagi nanti
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local productId = receiptInfo.ProductId

		if productId == Monetization.Products.Revive then
			local reviveEvent = Remotes.Get("GrantRevive")
			reviveEvent:FireClient(player)
		elseif productId == Monetization.Products.SkinNeon then
			local skinEvent = Remotes.Get("GrantSkin")
			skinEvent:FireClient(player, "Neon")
		end

		-- TODO (penting untuk produksi): simpan receipt ke DataStore agar
		-- pembelian tidak diproses dua kali jika server restart.
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	print("[OBC] Monetisasi siap (isi ID di Monetization.lua untuk mengaktifkan).")
end

return Monetization
