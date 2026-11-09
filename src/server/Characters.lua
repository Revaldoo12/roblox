--[[
	Characters.lua
	Memaksa semua pemain memakai rig R6, apa pun setting avatar mereka.

	Cara kerja: auto-spawn Roblox dimatikan, lalu server membuat karakter
	sendiri dari HumanoidDescription pemain (baju, warna kulit, aksesori
	tetap ikut) dengan HumanoidRigType.R6.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local Characters = {}

local RESPAWN_DELAY = 1.5
-- di atas platform start, jalan dimulai di Z = 0 ke arah -Z
local SPAWN_CFRAME = CFrame.new(0, GameConfig.TrackY + 3.2, 24)

local function getDescription(player: Player): HumanoidDescription
	if player.UserId > 0 then
		local ok, desc = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(player.UserId)
		end)
		if ok and desc then
			return desc
		end
	end
	return Instance.new("HumanoidDescription")
end

local function spawnCharacter(player: Player)
	if not player.Parent then
		return
	end

	local desc = getDescription(player)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
	end)
	if not ok or not model then
		-- jaringan gagal: pakai avatar polos R6 agar pemain tetap bisa main
		model = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6)
	end
	if not player.Parent then
		model:Destroy()
		return
	end

	model.Name = player.Name
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayName = player.DisplayName
	end

	local old = player.Character
	model:PivotTo(SPAWN_CFRAME)
	player.Character = model
	model.Parent = workspace
	if old and old ~= model then
		old:Destroy()
	end

	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		pcall(function()
			root:SetNetworkOwner(player)
		end)
	end

	if humanoid then
		humanoid.Died:Connect(function()
			task.wait(RESPAWN_DELAY)
			if player.Parent and player.Character == model then
				spawnCharacter(player)
			end
		end)
	end
end

function Characters.Init()
	Players.CharacterAutoLoads = false

	local function onPlayer(player: Player)
		task.spawn(spawnCharacter, player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		if not p.Character then
			onPlayer(p)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		if player.Character then
			player.Character:Destroy()
		end
	end)
	print("[OBC] Karakter R6 aktif ✔")
end

return Characters
