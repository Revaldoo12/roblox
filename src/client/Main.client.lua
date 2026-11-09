--[[
	Main.client.lua
	State machine game:
	  Menu -> Countdown -> Running -> GameOver -> (tap) Countdown ...
	Restart instan tanpa respawn karakter supaya loop "sekali lagi" terasa cepat.
	Waktu di langit berganti per zona (fajar -> siang -> sore -> senja -> malam).
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local StarterGui = game:GetService("StarterGui")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Locale = require(Shared:WaitForChild("Locale"))

local folder = script.Parent
local InputController = require(folder:WaitForChild("InputController"))
local PlayerRunner = require(folder:WaitForChild("PlayerRunner"))
local TrackStreamer = require(folder:WaitForChild("TrackStreamer"))
local Effects = require(folder:WaitForChild("Effects"))
local CameraController = require(folder:WaitForChild("CameraController"))
local HUD = require(folder:WaitForChild("HUD"))

local RunStarted = Remotes.Get("RunStarted")
local RunEnded = Remotes.Get("RunEnded")
local ScoreValidated = Remotes.Get("ScoreValidated")
local LeaderboardUpdated = Remotes.Get("LeaderboardUpdated")
local GrantRevive = Remotes.Get("GrantRevive")
local PerksUpdated = Remotes.Get("PerksUpdated")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

Locale.Init()

-- HP & tablet: paksa landscape, sembunyikan tombol sentuh bawaan
playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
pcall(function()
	GuiService.TouchControlsEnabled = false
end)

local lowDetail = InputController.IsLowEndDevice()
local hud = HUD.new()
local effects = Effects.new(lowDetail)
local camera = CameraController.new()
local input = InputController.new()
input:Start()
input:Enable()
hud:SetDevice(input.device)
input:OnDeviceChanged(function(device)
	hud:SetDevice(device)
end)

local state = "Loading"
local runner = nil
local streamer = nil
local token = 0
local best = 0
local perks = { doubleScore = false, rainbowTrail = false }
local usedRevive = false
local crashTime = 0
local currentZone = 0
local nextMilestone = GameConfig.MilestoneEvery
local muted = false

-- ===== matikan kontrol bawaan Roblox (WASD, joystick HP) =====
local function disableDefaultControls()
	task.spawn(function()
		local ok, err = pcall(function()
			local playerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: any)
			playerModule:GetControls():Disable()
		end)
		if not ok then
			warn("[OBC] Gagal mematikan kontrol bawaan:", err)
		end
	end)
end

task.spawn(function()
	for _ = 1, 10 do
		local ok = pcall(function()
			StarterGui:SetCore("ResetButtonCallback", false)
		end)
		if ok then
			break
		end
		task.wait(1)
	end
end)

-- ===== sembunyikan pemain lain (tiap pemain punya jalan sendiri) =====
task.spawn(function()
	while true do
		for _, other in ipairs(Players:GetPlayers()) do
			local char = other ~= player and other.Character
			if char then
				for _, d in ipairs(char:GetDescendants()) do
					if d:IsA("BasePart") then
						d.LocalTransparencyModifier = 1
					elseif d:IsA("Decal") then
						d.Transparency = 1
					elseif d:IsA("Humanoid") then
						d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
					end
				end
			end
		end
		task.wait(1)
	end
end)

-- ===== waktu langit per zona =====
local clockValue = Instance.new("NumberValue")
clockValue.Value = Lighting.ClockTime
clockValue.Changed:Connect(function(v)
	Lighting.ClockTime = v % 24
end)

local function applyZone(zone, index: number, announce: boolean, instant: boolean)
	local duration = if instant then 0 else 3
	local info = TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	-- jam selalu maju (tidak mundur melewati siang)
	local current = clockValue.Value % 24
	local delta = (zone.ClockTime - current) % 24
	clockValue.Value = current
	TweenService:Create(clockValue, info, { Value = current + delta }):Play()

	TweenService:Create(Lighting, info, {
		Brightness = zone.Brightness,
		Ambient = zone.Ambient,
		OutdoorAmbient = zone.Ambient,
	}):Play()
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmo then
		TweenService:Create(atmo, info, { Color = zone.AtmoColor, Decay = zone.AtmoDecay }):Play()
	end
	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	local clouds = terrain and terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		local cloudColor = Color3.fromRGB(255, 255, 255):Lerp(zone.AtmoColor, 0.35)
		TweenService:Create(clouds, info, { Color = cloudColor }):Play()
	end

	effects:SetAccent(zone.Accent)
	hud:SetAccent(zone.Accent)
	if announce then
		hud:Popup(Locale.Get("zone", index + 1) .. "  ·  " .. Locale.Get(zone.Key))
		effects:Play("Milestone", 0.8)
	end
end

local function resetZone(instant: boolean)
	currentZone = 0
	nextMilestone = GameConfig.MilestoneEvery
	applyZone(GameConfig.Zones[1], 0, false, instant)
end

-- ===== alur game =====
local function buildFreshTrack()
	if streamer then
		streamer:Destroy()
	end
	streamer = TrackStreamer.new(Random.new():NextInteger(1, 1000000000), lowDetail)
	streamer:Update(0)
	if runner then
		runner:SetHazardFolder(streamer.hazardFolder)
	end
end

local function prepareNewRun(instantSky: boolean)
	buildFreshTrack()
	runner:ResetToStart()
	usedRevive = false
	resetZone(instantSky)
end

local function enterMenu()
	token += 1
	state = "Menu"
	prepareNewRun(true)
	camera:SetMode("Menu")
	effects:SetRunning(false)
	hud:ShowMenu(best)
end

local function startCountdown(isRevive: boolean, tickTime: number)
	token += 1
	local myToken = token
	state = "Countdown"
	camera:SetMode("Run")
	hud:ShowRun()
	hud:SetBest(best)
	task.spawn(function()
		for i = 3, 1, -1 do
			if token ~= myToken then
				return
			end
			hud:Countdown(tostring(i))
			effects:Play("Tick", 1)
			task.wait(tickTime)
		end
		if token ~= myToken then
			return
		end
		hud:Countdown(Locale.Get("go"))
		effects:Play("Go", 1.5)
		state = "Running"
		runner:Run()
		effects:SetRunning(true)
		if not isRevive then
			RunStarted:FireServer()
		end
	end)
end

local function restart()
	effects:Play("Click")
	prepareNewRun(false)
	startCountdown(false, 0.4)
end

local function onCrash(reason: string, pos: Vector3)
	state = "GameOver"
	crashTime = os.clock()
	effects:SetRunning(false)
	effects:Crash(pos)
	camera:SetMode("Crash", pos)
	camera:Shake(0.6)
	hud:Flash()

	local score = runner:GetScore()
	local isNewBest = score > best and score > 0
	best = math.max(best, score)
	RunEnded:FireServer(score)

	local canRevive = GameConfig.ProductIds.Revive ~= 0 and not usedRevive
	local myToken = token
	task.delay(0.6, function()
		if token == myToken and state == "GameOver" then
			hud:ShowGameOver({
				score = score,
				best = best,
				newBest = isNewBest,
				reason = reason,
				canRevive = canRevive,
			})
			if input.device == "pad" then
				GuiService.SelectedObject = hud.playBtn
			end
		end
	end)
end

-- ===== input satu tombol =====
input:OnAction(function()
	if state == "Menu" then
		effects:Play("Click")
		startCountdown(false, 0.55)
	elseif state == "Running" then
		runner:DoAction()
	elseif state == "GameOver" then
		if os.clock() - crashTime > 0.8 then
			GuiService.SelectedObject = nil
			restart()
		end
	end
end)

hud.OnClick = function()
	effects:Play("Click")
end
hud.OnPlay = function()
	if state == "GameOver" then
		GuiService.SelectedObject = nil
		restart()
	end
end
hud.OnRevive = function()
	local id = GameConfig.ProductIds.Revive
	if state == "GameOver" and not usedRevive and id ~= 0 then
		MarketplaceService:PromptProductPurchase(player, id)
	end
end
hud.OnBuyDouble = function()
	local id = GameConfig.GamePassIds.DoubleScore
	if id ~= 0 then
		MarketplaceService:PromptGamePassPurchase(player, id)
	end
end
hud.OnBuyRainbow = function()
	local id = GameConfig.GamePassIds.RainbowTrail
	if id ~= 0 then
		MarketplaceService:PromptGamePassPurchase(player, id)
	end
end
hud.OnToggleSound = function()
	muted = not muted
	effects:SetMuted(muted)
	hud:SetMuted(muted)
end

-- ===== event dari server =====
ScoreValidated.OnClientEvent:Connect(function(official, accepted, serverBest)
	if typeof(serverBest) == "number" then
		best = math.max(best, serverBest)
		hud:SetBest(best)
	end
	if accepted and perks.doubleScore and typeof(official) == "number" then
		hud:SetOfficialScore(official, true)
	end
end)

LeaderboardUpdated.OnClientEvent:Connect(function(entries)
	if typeof(entries) == "table" then
		hud:SetLeaderboard(entries)
	end
end)

PerksUpdated.OnClientEvent:Connect(function(newPerks)
	if typeof(newPerks) == "table" then
		perks = newPerks
		hud:SetPerks(perks)
		effects:SetRainbow(perks.rainbowTrail == true)
	end
end)

GrantRevive.OnClientEvent:Connect(function()
	if state ~= "GameOver" or not runner or not streamer then
		return
	end
	usedRevive = true
	GuiService.SelectedObject = nil
	local safeD = streamer:PrepareRevive(runner.distance)
	runner:Revive(safeD)
	hud:Popup(Locale.Get("revived"))
	startCountdown(true, 0.5)
end)

-- best awal dari leaderstats
task.spawn(function()
	local stats = player:WaitForChild("leaderstats", 15)
	local bestValue = stats and stats:WaitForChild("Best", 5)
	if bestValue and bestValue:IsA("IntValue") then
		best = math.max(best, bestValue.Value)
		hud:SetBest(best)
		bestValue.Changed:Connect(function(v)
			best = math.max(best, v)
			hud:SetBest(best)
		end)
	end
end)

-- ===== karakter =====
local function onCharacter(character: Model)
	token += 1
	if runner then
		runner:Destroy()
	end
	runner = PlayerRunner.new(character)
	runner.OnJump = function(pos)
		effects:Jump(pos)
	end
	runner.OnLand = function(pos)
		effects:Land(pos)
	end
	runner.OnDash = function(pos)
		effects:Dash(pos)
		camera:Punch(4)
	end
	runner.OnCrash = onCrash

	camera:SetTarget(runner.root)
	effects:AttachCharacter(character)
	effects:SetRainbow(perks.rainbowTrail == true)
	disableDefaultControls()
	enterMenu()
end

player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end

-- ===== loop =====
RunService.Heartbeat:Connect(function(dt)
	if not runner then
		return
	end
	if state == "Running" then
		runner:Update(dt)
	end
	if runner.state ~= "Dead" then
		runner:UpdateAnimation()
	end
	if streamer then
		streamer:Update(math.max(runner.distance, 0))
	end
end)

RunService.RenderStepped:Connect(function(dt)
	if streamer then
		streamer:Animate(os.clock())
	end
	hud:Update(dt)
	if not runner then
		return
	end

	local running = state == "Running"
	local r = if running then runner:GetSpeedRatio() else 0
	camera:SetSpeedRatio(r)
	effects:Update(dt, Workspace.CurrentCamera.CFrame, r)

	if running then
		local score = runner:GetScore()
		hud:SetScore(score)
		hud:SetSpeedRatio(r)

		local zone, index = GameConfig.GetZone(runner.distance)
		if index ~= currentZone then
			currentZone = index
			applyZone(zone, index, true, false)
		end
		if score >= nextMilestone then
			hud:Popup(Locale.Get("milestone", nextMilestone))
			hud:PulseScore()
			effects:Play("Milestone", 1.2)
			nextMilestone += GameConfig.MilestoneEvery
		end
	end
end)
