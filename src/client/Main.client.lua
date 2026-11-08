--!strict
--[[
	Main.client.lua
	------------------------------------------------------------
	Titik masuk CLIENT. Merangkai semua modul menjadi satu game loop:
	  InputController -> PlayerRunner -> HUD
	dan berkomunikasi dengan server untuk validasi skor.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local scriptsFolder = script.Parent
local PlayerRunner = require(scriptsFolder:WaitForChild("PlayerRunner"))
local InputController = require(scriptsFolder:WaitForChild("InputController"))
local HUD = require(scriptsFolder:WaitForChild("HUD"))

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RunStarted = Remotes.Get("RunStarted")
local RunEnded = Remotes.Get("RunEnded")
local ScoreValidated = Remotes.Get("ScoreValidated")
local LeaderboardUpdated = Remotes.Get("LeaderboardUpdated")
local GrantRevive = Remotes.Get("GrantRevive")
local GrantSkin = Remotes.Get("GrantSkin")

local player = Players.LocalPlayer

local hud = HUD.new()
local input = InputController.new()
input:Start()

local runner: any = nil
local runStartTime = 0
local bestScore = 0

local function endRun()
	if not runner or not runner:IsAlive() then
		return
	end
	local finalScore = runner:GetScore()
	runner:Stop()
	input:Disable()

	-- kirim ke server untuk validasi (durasi dipakai server untuk cek kewajaran)
	local elapsed = os.clock() - runStartTime
	RunEnded:FireServer(finalScore, elapsed)

	bestScore = math.max(bestScore, finalScore)
	hud:ShowGameOver(finalScore, bestScore)
end

local function startRun(character: Model)
	hud:Reset()
	runner = PlayerRunner.new(character)
	runner:Start()
	input:Enable()
	runStartTime = os.clock()
	RunStarted:FireServer()

	-- update HUD skor tiap frame
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		if runner and runner:IsAlive() then
			hud:SetScore(runner:GetScore())
		else
			conn:Disconnect()
		end
	end)

	-- deteksi mati
	runner.humanoid.Died:Connect(endRun)
end

-- satu tombol memicu aksi; jika game over, tombol memulai ronde baru
input:OnAction(function()
	if runner and runner:IsAlive() then
		runner:DoAction()
	else
		-- respawn untuk main lagi
		player:LoadCharacter()
	end
end)

-- server mengonfirmasi skor resmi (mis. anti-cheat menolak/menyetujui)
ScoreValidated.OnClientEvent:Connect(function(officialScore: number, accepted: boolean)
	if accepted then
		bestScore = math.max(bestScore, officialScore)
	end
end)

-- update panel leaderboard global dari server
LeaderboardUpdated.OnClientEvent:Connect(function(entries)
	if typeof(entries) == "table" then
		hud:SetLeaderboard(entries)
	end
end)

-- pemain membeli revive: hidupkan kembali tanpa reset skor
GrantRevive.OnClientEvent:Connect(function()
	if runner and not runner:IsAlive() then
		player:LoadCharacter()
	end
end)

-- pemain membeli/mengaktifkan skin: beri trail warna pada karakter
GrantSkin.OnClientEvent:Connect(function(skinName)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local att0 = Instance.new("Attachment")
	att0.Position = Vector3.new(0, 1, 0)
	att0.Parent = root
	local att1 = Instance.new("Attachment")
	att1.Position = Vector3.new(0, -1, 0)
	att1.Parent = root
	local trail = Instance.new("Trail")
	trail.Attachment0 = att0
	trail.Attachment1 = att1
	trail.Lifetime = 0.4
	trail.Color = ColorSequence.new(Color3.fromRGB(120, 220, 255), Color3.fromRGB(255, 120, 220))
	trail.Parent = root
end)

player.CharacterAdded:Connect(startRun)
if player.Character then
	startRun(player.Character)
end
