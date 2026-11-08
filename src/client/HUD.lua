--[[
	HUD.lua
	Seluruh UI dibuat lewat kode:
	  - Menu (judul, cara main, tombol toko)
	  - HUD saat lari (skor, best, bar kecepatan, badge 2x)
	  - Hitung mundur, popup zona/milestone, flash saat crash
	  - Kartu Game Over (skor, NEW BEST, Main Lagi, Revive)
	  - Papan peringkat global
	Didesain untuk 1280x720 lalu diskalakan otomatis (PC & HP).
--]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local HUD = {}
HUD.__index = HUD

local FONT_TITLE = Enum.Font.FredokaOne
local FONT_NUM = Enum.Font.GothamBlack
local FONT_BODY = Enum.Font.GothamBold
local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(20, 0, 40)
local GOLD = Color3.fromRGB(255, 205, 60)

-- ===== helper =====
local function new(className: string, props, children)
	local inst = Instance.new(className)
	local parent = nil
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		else
			(inst :: any)[k] = v
		end
	end
	for _, c in ipairs(children or {}) do
		c.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function corner(r: number)
	return new("UICorner", { CornerRadius = UDim.new(0, r) })
end

local function textStroke(color: Color3, thickness: number)
	return new("UIStroke", { Color = color, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
end

local function borderStroke(color: Color3, thickness: number, transparency: number?)
	return new("UIStroke", {
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function gradient(colors, rotation: number?)
	local kps = {}
	for i, c in ipairs(colors) do
		table.insert(kps, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c))
	end
	return new("UIGradient", { Color = ColorSequence.new(kps), Rotation = rotation or 0 })
end

local function tween(inst: Instance, time: number, props, style, dir)
	local t = TweenService:Create(
		inst,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

local function label(props)
	local base = {
		BackgroundTransparency = 1,
		TextColor3 = WHITE,
		Font = FONT_BODY,
		TextSize = 24,
		Size = UDim2.new(1, 0, 0, 30),
	}
	for k, v in pairs(props) do
		base[k] = v
	end
	return new("TextLabel", base)
end

local function button(text: string, colors, size: UDim2, textSize: number)
	local scale = new("UIScale")
	local b = new("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = WHITE,
		Size = size,
		Text = text,
		Font = FONT_TITLE,
		TextSize = textSize,
		TextColor3 = WHITE,
		TextStrokeTransparency = 0.6,
	}, { corner(14), gradient(colors, 0), borderStroke(WHITE, 2, 0.55), scale })
	b.MouseEnter:Connect(function()
		tween(scale, 0.12, { Scale = 1.05 })
	end)
	b.MouseLeave:Connect(function()
		tween(scale, 0.12, { Scale = 1 })
	end)
	b.MouseButton1Down:Connect(function()
		tween(scale, 0.08, { Scale = 0.94 })
	end)
	b.MouseButton1Up:Connect(function()
		tween(scale, 0.12, { Scale = 1.05 })
	end)
	return b
end

-- ===== konstruksi =====
function HUD.new()
	local self = setmetatable({}, HUD)
	self._scales = {}
	self._t = 0
	self.OnPlay = nil
	self.OnRevive = nil
	self.OnBuyDouble = nil
	self.OnBuyRainbow = nil
	self.OnClick = nil

	local gui = new("ScreenGui", {
		Name = "OBC_HUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	self.gui = gui

	self:_buildRunHud()
	self:_buildMenu()
	self:_buildGameOver()
	self:_buildLeaderboard()

	self.flash = new("Frame", {
		Name = "Flash",
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
		Parent = gui,
	})

	local cam = Workspace.CurrentCamera
	local function rescale()
		local vp = Workspace.CurrentCamera.ViewportSize
		local s = math.clamp(math.min(vp.X / 1280, vp.Y / 720), 0.5, 1.5)
		for _, sc in ipairs(self._scales) do
			sc.Scale = s
		end
	end
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()

	self:HideAll()
	return self
end

function HUD:_scaled(frame: Instance)
	local sc = new("UIScale", { Parent = frame })
	table.insert(self._scales, sc)
	return frame
end

function HUD:_click(fn)
	if self.OnClick then
		self.OnClick()
	end
	if fn then
		fn()
	end
end

function HUD:_buildRunHud()
	local run = new("Frame", { Name = "Run", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = self.gui })
	self.run = run

	local box = self:_scaled(new("Frame", {
		Name = "ScoreBox",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(420, 150),
		Parent = run,
	}))

	self.scoreGradient = gradient({ WHITE, GameConfig.Palettes[1].Primary }, 90)
	self.scoreScale = new("UIScale")
	self.score = label({
		Name = "Score",
		Text = "0",
		Font = FONT_NUM,
		TextSize = 80,
		Size = UDim2.new(1, 0, 0, 84),
		Parent = box,
	})
	textStroke(INK, 4).Parent = self.score
	self.scoreGradient.Parent = self.score
	self.scoreScale.Parent = self.score

	self.bestRun = label({
		Name = "Best",
		Text = "BEST 0",
		TextSize = 20,
		TextColor3 = Color3.fromRGB(210, 210, 255),
		Position = UDim2.new(0, 0, 0, 84),
		Size = UDim2.new(1, 0, 0, 24),
		Parent = box,
	})
	textStroke(INK, 2).Parent = self.bestRun

	self.multBadge = new("TextLabel", {
		Name = "Mult",
		BackgroundColor3 = GOLD,
		Position = UDim2.new(1, -70, 0, 22),
		Size = UDim2.fromOffset(62, 34),
		Text = "2x",
		Font = FONT_NUM,
		TextSize = 24,
		TextColor3 = INK,
		Visible = false,
		Parent = box,
	}, { corner(10) })

	local bar = new("Frame", {
		Name = "SpeedBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 118),
		Size = UDim2.fromOffset(240, 10),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.8,
		Parent = box,
	}, { corner(5) })
	self.speedGradient = gradient({ GameConfig.Palettes[1].Primary, GameConfig.Palettes[1].Secondary }, 0)
	self.speedFill = new("Frame", {
		Name = "Fill",
		BackgroundColor3 = WHITE,
		Size = UDim2.fromScale(0, 1),
		Parent = bar,
	}, { corner(5), self.speedGradient })
	label({
		Text = "SPEED",
		TextSize = 12,
		TextColor3 = Color3.fromRGB(190, 190, 230),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(0, -8, 0.5, 0),
		Size = UDim2.fromOffset(60, 14),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = bar,
	})

	-- popup (zona / milestone)
	local popBox = self:_scaled(new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.32),
		Size = UDim2.fromOffset(900, 80),
		Parent = self.gui,
	}))
	self.popupScale = new("UIScale")
	self.popup = label({
		Name = "Popup",
		Font = FONT_TITLE,
		TextSize = 54,
		Size = UDim2.fromScale(1, 1),
		TextTransparency = 1,
		Parent = popBox,
	})
	self.popupStroke = textStroke(INK, 4)
	self.popupStroke.Transparency = 1
	self.popupStroke.Parent = self.popup
	self.popupScale.Parent = self.popup

	-- countdown
	local cdBox = self:_scaled(new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(500, 200),
		Parent = self.gui,
	}))
	self.cdScale = new("UIScale")
	self.countdown = label({
		Name = "Countdown",
		Font = FONT_NUM,
		TextSize = 150,
		Size = UDim2.fromScale(1, 1),
		TextTransparency = 1,
		Parent = cdBox,
	})
	self.cdStroke = textStroke(INK, 6)
	self.cdStroke.Transparency = 1
	self.cdStroke.Parent = self.countdown
	self.cdScale.Parent = self.countdown
end

local function dimBackground(parent: Instance, name: string)
	return new("Frame", {
		Name = name,
		BackgroundColor3 = Color3.fromRGB(8, 4, 24),
		BackgroundTransparency = 0.2,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	}, {
		new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.15),
				NumberSequenceKeypoint.new(0.5, 0.75),
				NumberSequenceKeypoint.new(1, 0.15),
			}),
		}),
	})
end

local function howToCard(icon: string, caption: string, action: string, color: Color3)
	return new("Frame", {
		BackgroundColor3 = Color3.fromRGB(18, 14, 40),
		BackgroundTransparency = 0.15,
		Size = UDim2.fromOffset(270, 96),
	}, {
		corner(14),
		borderStroke(color, 2, 0.2),
		label({ Text = icon, TextSize = 46, Size = UDim2.new(0, 76, 1, 0), TextColor3 = color }),
		label({
			Text = caption,
			TextSize = 16,
			TextColor3 = Color3.fromRGB(170, 170, 210),
			Position = UDim2.fromOffset(76, 16),
			Size = UDim2.new(1, -86, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		label({
			Text = action,
			Font = FONT_TITLE,
			TextSize = 36,
			Position = UDim2.fromOffset(76, 38),
			Size = UDim2.new(1, -86, 0, 42),
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	})
end

function HUD:_buildMenu()
	local menu = dimBackground(self.gui, "Menu")
	self.menu = menu

	local content = self:_scaled(new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.45, 0.5),
		Size = UDim2.fromOffset(760, 540),
		Parent = menu,
	}))

	local top = label({
		Text = "ONE BUTTON",
		Font = FONT_TITLE,
		TextSize = 58,
		Size = UDim2.new(1, 0, 0, 64),
		Parent = content,
	})
	textStroke(INK, 4).Parent = top

	self.titleScale = new("UIScale")
	self.title = label({
		Text = "CHAOS",
		Font = FONT_NUM,
		TextSize = 140,
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 0, 140),
		Parent = content,
	})
	textStroke(INK, 6).Parent = self.title
	gradient({ Color3.fromRGB(0, 229, 255), Color3.fromRGB(255, 0, 200), Color3.fromRGB(255, 160, 0) }, 0).Parent =
		self.title
	self.titleScale.Parent = self.title

	label({
		Text = "Satu tombol. Nol ampun.",
		TextSize = 24,
		TextColor3 = Color3.fromRGB(200, 190, 255),
		Position = UDim2.fromOffset(0, 198),
		Parent = content,
	})

	local row = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 248),
		Size = UDim2.fromOffset(580, 96),
		Parent = content,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 20),
		}),
	})
	howToCard("⬆", "DI TANAH", "LOMPAT", Color3.fromRGB(120, 255, 140)).Parent = row
	howToCard("⚡", "DI UDARA", "DASH", Color3.fromRGB(0, 229, 255)).Parent = row

	self.prompt = label({
		Text = "TAP / SPACE UNTUK MULAI",
		Font = FONT_TITLE,
		TextSize = 34,
		TextColor3 = Color3.fromRGB(255, 230, 120),
		Position = UDim2.fromOffset(0, 368),
		Size = UDim2.new(1, 0, 0, 44),
		Parent = content,
	})
	self.promptStroke = textStroke(INK, 3)
	self.promptStroke.Parent = self.prompt

	self.bestMenu = label({
		Text = "BEST 0",
		TextSize = 22,
		TextColor3 = Color3.fromRGB(210, 210, 255),
		Position = UDim2.fromOffset(0, 418),
		Parent = content,
	})

	local shop = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 466),
		Size = UDim2.fromOffset(600, 50),
		Parent = content,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 14),
		}),
	})
	self.buyDouble = button(
		"⚡ 2x SKOR",
		{ Color3.fromRGB(255, 190, 40), Color3.fromRGB(255, 110, 30) },
		UDim2.fromOffset(240, 48),
		24
	)
	self.buyDouble.Visible = GameConfig.GamePassIds.DoubleScore ~= 0
	self.buyDouble.Parent = shop
	self.buyDouble.Activated:Connect(function()
		self:_click(self.OnBuyDouble)
	end)

	self.buyRainbow = button(
		"🌈 RAINBOW TRAIL",
		{ Color3.fromRGB(170, 80, 255), Color3.fromRGB(255, 60, 170) },
		UDim2.fromOffset(260, 48),
		24
	)
	self.buyRainbow.Visible = GameConfig.GamePassIds.RainbowTrail ~= 0
	self.buyRainbow.Parent = shop
	self.buyRainbow.Activated:Connect(function()
		self:_click(self.OnBuyRainbow)
	end)
end

function HUD:_buildGameOver()
	local over = dimBackground(self.gui, "GameOver")
	self.over = over

	local holder = self:_scaled(new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.45, 0.5),
		Size = UDim2.fromOffset(480, 450),
		Parent = over,
	}))
	self.cardScale = new("UIScale")
	local card = new("Frame", {
		Name = "Card",
		BackgroundColor3 = Color3.fromRGB(16, 12, 36),
		BackgroundTransparency = 0.05,
		Size = UDim2.fromScale(1, 1),
		Parent = holder,
	}, { corner(22), borderStroke(GameConfig.HazardColor, 3, 0.1), self.cardScale })

	local crash = label({
		Text = "CRASH!",
		Font = FONT_NUM,
		TextSize = 64,
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.new(1, 0, 0, 70),
		Parent = card,
	})
	textStroke(INK, 4).Parent = crash
	gradient({ GameConfig.HazardColor, Color3.fromRGB(255, 170, 40) }, 0).Parent = crash

	self.reason = label({
		Text = "",
		TextSize = 18,
		TextColor3 = Color3.fromRGB(190, 180, 230),
		Position = UDim2.fromOffset(0, 84),
		Size = UDim2.new(1, 0, 0, 22),
		Parent = card,
	})
	label({
		Text = "SKOR",
		TextSize = 16,
		TextColor3 = Color3.fromRGB(150, 150, 200),
		Position = UDim2.fromOffset(0, 116),
		Size = UDim2.new(1, 0, 0, 20),
		Parent = card,
	})
	self.overScore = label({
		Text = "0",
		Font = FONT_NUM,
		TextSize = 76,
		Position = UDim2.fromOffset(0, 134),
		Size = UDim2.new(1, 0, 0, 80),
		Parent = card,
	})
	textStroke(INK, 4).Parent = self.overScore

	self.official = label({
		Text = "",
		TextSize = 18,
		TextColor3 = GOLD,
		Position = UDim2.fromOffset(0, 212),
		Size = UDim2.new(1, 0, 0, 22),
		Parent = card,
	})
	self.overBest = label({
		Text = "BEST 0",
		TextSize = 22,
		TextColor3 = Color3.fromRGB(210, 210, 255),
		Position = UDim2.fromOffset(0, 238),
		Size = UDim2.new(1, 0, 0, 28),
		Parent = card,
	})

	self.newBest = new("TextLabel", {
		Name = "NewBest",
		BackgroundColor3 = GOLD,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -60, 0, 128),
		Size = UDim2.fromOffset(150, 40),
		Rotation = 12,
		Text = "NEW BEST!",
		Font = FONT_TITLE,
		TextSize = 24,
		TextColor3 = INK,
		Visible = false,
		Parent = card,
	}, { corner(10) })

	local stack = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 280),
		Size = UDim2.fromOffset(400, 120),
		Parent = card,
	}, {
		new("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 10),
		}),
	})
	local play = button(
		"▶  MAIN LAGI",
		{ Color3.fromRGB(60, 230, 120), Color3.fromRGB(0, 200, 255) },
		UDim2.new(1, 0, 0, 58),
		30
	)
	play.Parent = stack
	play.Activated:Connect(function()
		self:_click(self.OnPlay)
	end)

	self.revive = button(
		"❤  REVIVE (lanjut dari sini)",
		{ Color3.fromRGB(255, 70, 140), Color3.fromRGB(255, 120, 80) },
		UDim2.new(1, 0, 0, 48),
		22
	)
	self.revive.Parent = stack
	self.revive.Activated:Connect(function()
		self:_click(self.OnRevive)
	end)

	label({
		Text = "atau tekan SPACE / TAP layar",
		TextSize = 16,
		TextColor3 = Color3.fromRGB(150, 150, 190),
		Position = UDim2.new(0, 0, 1, -34),
		Size = UDim2.new(1, 0, 0, 22),
		Parent = card,
	})
end

function HUD:_buildLeaderboard()
	local board = self:_scaled(new("Frame", {
		Name = "Leaderboard",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -20, 0.5, 0),
		Size = UDim2.fromOffset(290, 400),
		BackgroundColor3 = Color3.fromRGB(14, 10, 32),
		BackgroundTransparency = 0.15,
		Parent = self.gui,
	}, { corner(18), borderStroke(GameConfig.Palettes[1].Primary, 2, 0.4) }))
	self.board = board

	label({
		Text = "🏆 TOP PEMAIN",
		Font = FONT_TITLE,
		TextSize = 26,
		TextColor3 = GOLD,
		Size = UDim2.new(1, 0, 0, 48),
		Parent = board,
	})
	self.boardList = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 52),
		Size = UDim2.new(1, -28, 1, -62),
		Parent = board,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	self:SetLeaderboard({})
end

-- ===== API =====

function HUD:HideAll()
	self.run.Visible = false
	self.menu.Visible = false
	self.over.Visible = false
	self.board.Visible = false
end

function HUD:ShowMenu(best: number)
	self:HideAll()
	self.menu.Visible = true
	self.board.Visible = true
	self:SetBest(best)
end

function HUD:ShowRun()
	self:HideAll()
	self.run.Visible = true
	self:SetScore(0)
	self:SetSpeedRatio(0)
end

function HUD:ShowGameOver(data)
	self:HideAll()
	self.run.Visible = false
	self.over.Visible = true
	self.board.Visible = true

	self.reason.Text = if data.reason == "fall" then "Jatuh ke jurang 🕳" else "Nabrak rintangan 💥"
	self.official.Text = ""
	self.overBest.Text = ("BEST %d"):format(data.best)
	self.revive.Visible = data.canRevive
	self.newBest.Visible = data.newBest

	-- kartu muncul dengan efek pop
	self.cardScale.Scale = 0.6
	tween(self.cardScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)

	-- skor menghitung naik
	local nv = Instance.new("NumberValue")
	nv.Changed:Connect(function(v)
		self.overScore.Text = tostring(math.floor(v))
	end)
	self.overScore.Text = "0"
	local t = tween(nv, 0.8, { Value = data.score }, Enum.EasingStyle.Cubic)
	t.Completed:Connect(function()
		self.overScore.Text = tostring(data.score)
		nv:Destroy()
	end)
end

function HUD:SetOfficialScore(official: number, doubled: boolean)
	if doubled and self.over.Visible then
		self.official.Text = ("⚡ 2x SKOR → %d"):format(official)
	end
end

function HUD:SetScore(n: number)
	self.score.Text = tostring(n)
end

function HUD:SetBest(n: number)
	local text = ("BEST %d"):format(n)
	self.bestRun.Text = text
	self.bestMenu.Text = text
	self.overBest.Text = text
end

function HUD:SetSpeedRatio(r: number)
	self.speedFill.Size = UDim2.fromScale(math.clamp(r, 0.02, 1), 1)
end

function HUD:SetPalette(pal)
	self.scoreGradient.Color = ColorSequence.new(WHITE, pal.Primary)
	self.speedGradient.Color = ColorSequence.new(pal.Primary, pal.Secondary)
end

function HUD:SetPerks(perks)
	self.multBadge.Visible = perks.doubleScore == true
	self.buyDouble.Visible = GameConfig.GamePassIds.DoubleScore ~= 0 and not perks.doubleScore
	self.buyRainbow.Visible = GameConfig.GamePassIds.RainbowTrail ~= 0 and not perks.rainbowTrail
end

function HUD:SetReviveAvailable(on: boolean)
	self.revive.Visible = on
end

function HUD:PulseScore()
	self.scoreScale.Scale = 1.35
	tween(self.scoreScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

function HUD:Popup(text: string, color: Color3)
	local p = self.popup
	p.Text = text
	p.TextColor3 = color
	p.TextTransparency = 0
	self.popupStroke.Transparency = 0
	self.popupScale.Scale = 0.5
	tween(self.popupScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	local myText = text
	task.delay(1.3, function()
		if p.Text == myText then
			tween(p, 0.4, { TextTransparency = 1 })
			tween(self.popupStroke, 0.4, { Transparency = 1 })
		end
	end)
end

function HUD:Countdown(text: string)
	local c = self.countdown
	c.Text = text
	c.TextColor3 = if text == "GO!" then Color3.fromRGB(120, 255, 140) else WHITE
	c.TextTransparency = 0
	self.cdStroke.Transparency = 0
	self.cdScale.Scale = 1.8
	tween(self.cdScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(0.42, function()
		if c.Text == text then
			tween(c, 0.15, { TextTransparency = 1 })
			tween(self.cdStroke, 0.15, { Transparency = 1 })
		end
	end)
end

function HUD:Flash()
	self.flash.BackgroundTransparency = 0.2
	tween(self.flash, 0.45, { BackgroundTransparency = 1 })
end

local RANK_COLORS = { GOLD, Color3.fromRGB(220, 225, 240), Color3.fromRGB(230, 150, 90) }

function HUD:SetLeaderboard(entries)
	for _, c in ipairs(self.boardList:GetChildren()) do
		if c:IsA("Frame") or c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	if #entries == 0 then
		label({
			Text = "Belum ada skor.\nJadilah yang pertama!",
			TextSize = 18,
			TextColor3 = Color3.fromRGB(170, 170, 210),
			Size = UDim2.new(1, 0, 0, 60),
			TextWrapped = true,
			Parent = self.boardList,
		})
		return
	end
	for i = 1, math.min(#entries, 10) do
		local e = entries[i]
		local color = RANK_COLORS[i] or WHITE
		new("Frame", {
			LayoutOrder = i,
			BackgroundColor3 = WHITE,
			BackgroundTransparency = if i % 2 == 0 then 0.95 else 0.9,
			Size = UDim2.new(1, 0, 0, 30),
			Parent = self.boardList,
		}, {
			corner(8),
			label({
				Text = tostring(i),
				Font = FONT_NUM,
				TextSize = 18,
				TextColor3 = color,
				Size = UDim2.new(0, 30, 1, 0),
			}),
			label({
				Text = tostring(e.name),
				TextSize = 16,
				TextColor3 = color,
				Position = UDim2.fromOffset(32, 0),
				Size = UDim2.new(1, -110, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			label({
				Text = tostring(e.score),
				Font = FONT_NUM,
				TextSize = 16,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -8, 0, 0),
				Size = UDim2.new(0, 76, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
		})
	end
end

-- animasi idle (judul goyang, prompt berkedip)
function HUD:Update(dt: number)
	self._t += dt
	if self.menu.Visible then
		self.title.Rotation = math.sin(self._t * 2) * 3
		self.titleScale.Scale = 1 + math.sin(self._t * 3) * 0.03
		local a = 0.5 + 0.5 * math.sin(self._t * 4)
		self.prompt.TextTransparency = a * 0.6
		self.promptStroke.Transparency = a * 0.6
	end
end

return HUD
