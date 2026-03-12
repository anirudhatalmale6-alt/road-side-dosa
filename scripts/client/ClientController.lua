-- ClientController: Main client script handling UI, input, and game interaction
-- Location: StarterPlayerScripts

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local NightData = require(ReplicatedStorage:WaitForChild("NightData"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- UI References (each overlay is in its own ScreenGui for clean visibility control)
local playerGui = player:WaitForChild("PlayerGui")

-- Main HUD (always visible)
local mainUI = playerGui:WaitForChild("MainUI")
local hudFrame = mainUI:WaitForChild("HUD")

-- Overlay ScreenGuis (start disabled, enabled by scripts when needed)
local phoneScreenGui = playerGui:WaitForChild("PhoneScreenGui")
local phoneFrame = phoneScreenGui:WaitForChild("PhoneUI")
local dialogueFrame = phoneScreenGui:WaitForChild("DialogueUI")

local cctvScreenGui = playerGui:WaitForChild("CCTVScreenGui")
local cctvFrame = cctvScreenGui:WaitForChild("CCTVUI")

local deathScreenGui = playerGui:WaitForChild("DeathScreenGui")
local deathFrame = deathScreenGui:WaitForChild("DeathUI")

local menuScreenGui = playerGui:WaitForChild("MenuScreenGui")
local menuFrame = menuScreenGui:WaitForChild("MenuUI")

local jumpscareScreenGui = playerGui:WaitForChild("JumpscareScreenGui")
local jumpscareFrame = jumpscareScreenGui:WaitForChild("JumpscareUI")

local nightStartScreenGui = playerGui:WaitForChild("NightStartScreenGui")
local nightStartFrame = nightStartScreenGui:WaitForChild("NightStartUI")

-- State
local currentNight = 0
local isPhoneActive = false
local isCCTVActive = false
local isAlive = true
local stamina = Config.MAX_STAMINA
local isSprinting = false
local menuItems = {}
local selectedItem = nil
local dialogueSkipRequested = false
local phoneDialogueComplete = false

-- Sound helper
local function playSound(soundName)
	local sound = SoundService:FindFirstChild(soundName)
	if sound then sound:Play() end
end

local function stopSound(soundName)
	local sound = SoundService:FindFirstChild(soundName)
	if sound then sound:Stop() end
end

-- Forward declarations
local showFloatingText
local updateMenuButtons

-- === HUD UPDATES ===
local function updateHUD(data)
	if data.night then
		hudFrame:FindFirstChild("NightLabel").Text = "Night " .. data.night
		currentNight = data.night
	end
	if data.currency then
		hudFrame:FindFirstChild("CurrencyLabel").Text = "$" .. data.currency
	end
	if data.batter ~= nil then
		hudFrame:FindFirstChild("BatterLabel").Text = "Batter: " .. data.batter
	end
	if data.menuItems then
		menuItems = data.menuItems
		updateMenuButtons()
	end
	if data.lightsOn ~= nil then
		hudFrame:FindFirstChild("LightsIndicator").Text = data.lightsOn and "LIGHTS: ON" or "LIGHTS: OFF"
		hudFrame:FindFirstChild("LightsIndicator").TextColor3 = data.lightsOn and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0)
	end
	if data.shutters then
		for name, isOpen in pairs(data.shutters) do
			local btn = hudFrame:FindFirstChild("Shutter_" .. name)
			if btn then
				btn.Text = name .. ": " .. (isOpen and "OPEN" or "CLOSED")
				btn.BackgroundColor3 = isOpen and Color3.fromRGB(200,50,50) or Color3.fromRGB(50,200,50)
			end
		end
	end
	if data.dosaReady then
		-- Flash the serve button and play cooking done sound
		playSound("CookingSound")
		local serveBtn = hudFrame:FindFirstChild("ServeButton")
		if serveBtn then
			TweenService:Create(serveBtn, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true), {BackgroundColor3 = Color3.fromRGB(255, 200, 0)}):Play()
		end
		showFloatingText("Dosa Ready!", Color3.fromRGB(255, 200, 0))
	end
	if data.cookingStarted then
		-- Show cooking in progress
		showFloatingText("Cooking...", Color3.fromRGB(200, 150, 50))
	end
	if data.serveSuccess then
		-- Show success feedback
		playSound("CookingSound")
		showFloatingText("+$" .. Config.CURRENCY_PER_SALE, Color3.fromRGB(0, 255, 0))
		updateOrderScreen("ORDER SERVED!\n+$" .. Config.CURRENCY_PER_SALE)
		task.delay(3, function()
			updateOrderScreen("Waiting for customers...")
		end)
	end
	if data.messCleared then
		showFloatingText("Mess Cleaned!", Color3.fromRGB(100, 200, 255))
	end
	if data.batterSpilled then
		showFloatingText("BATTER SPILLED! TURN OFF LIGHTS & RUN!", Color3.fromRGB(255, 0, 0))
		playSound("HeartbeatSound")
	end
end

-- === FLOATING TEXT ===
showFloatingText = function(text, color)
	local label = Instance.new("TextLabel")
	label.Text = text
	label.Size = UDim2.new(0, 200, 0, 50)
	label.Position = UDim2.new(0.5, -100, 0.4, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextStrokeTransparency = 0.5
	label.Parent = mainUI

	local tween = TweenService:Create(label, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -100, 0.2, 0),
		TextTransparency = 1,
		TextStrokeTransparency = 1
	})
	tween:Play()
	tween.Completed:Connect(function()
		label:Destroy()
	end)
end

-- === MENU BUTTONS ===
updateMenuButtons = function()
	local menuContainer = hudFrame:FindFirstChild("MenuContainer")
	if not menuContainer then return end

	-- Clear old buttons
	for _, child in ipairs(menuContainer:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	-- Create buttons for available items
	for i, item in ipairs(menuItems) do
		local btn = Instance.new("TextButton")
		btn.Name = "MenuItem_" .. item
		btn.Text = item
		btn.Size = UDim2.new(0, 100, 0, 40)
		btn.Position = UDim2.new(0, (i-1) * 110, 0, 0)
		btn.BackgroundColor3 = Color3.fromRGB(80, 60, 40)
		btn.TextColor3 = Color3.fromRGB(255, 220, 150)
		btn.Font = Enum.Font.GothamBold
		btn.TextScaled = true
		btn.Parent = menuContainer

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = btn

		btn.MouseButton1Click:Connect(function()
			selectedItem = item
			-- Highlight selected
			for _, sibling in ipairs(menuContainer:GetChildren()) do
				if sibling:IsA("TextButton") then
					sibling.BackgroundColor3 = Color3.fromRGB(80, 60, 40)
				end
			end
			btn.BackgroundColor3 = Color3.fromRGB(200, 150, 50)
		end)
	end
end

-- === PROXIMITY PROMPTS SETUP ===
-- Add ProximityPrompts to key objects on load
task.spawn(function()
	-- Fridge prompt (on door for better interaction feel)
	local fridgeDoor = workspace:WaitForChild("FridgeDoor", 10)
	local fridge = workspace:WaitForChild("Fridge", 10)
	local fridgeTarget = fridgeDoor or fridge
	if fridgeTarget and not fridgeTarget:FindFirstChild("FridgePrompt") then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "FridgePrompt"
		prompt.ActionText = "Grab Batter"
		prompt.ObjectText = "Fridge"
		prompt.MaxActivationDistance = 8
		prompt.HoldDuration = 0
		prompt.KeyboardKeyCode = Enum.KeyCode.F
		prompt.Parent = fridgeTarget
		prompt.Triggered:Connect(function()
			Remotes:WaitForChild("GrabBatter"):FireServer()
			playSound("DoorCreak")
			animateFridgeOpen()
		end)
	end

	-- Tawa prompt
	local tawa = workspace:WaitForChild("Tawa", 10)
	if tawa and not tawa:FindFirstChild("TawaPrompt") then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "TawaPrompt"
		prompt.ActionText = "Cook Dosa"
		prompt.ObjectText = "Tawa (Griddle)"
		prompt.MaxActivationDistance = 8
		prompt.HoldDuration = 0
		prompt.KeyboardKeyCode = Enum.KeyCode.T
		prompt.Parent = tawa
		prompt.Triggered:Connect(function()
			Remotes:WaitForChild("CookDosa"):FireServer()
			playSound("CookingSound")
		end)
	end

	-- Phone prompt
	local phone = workspace:WaitForChild("Phone", 10)
	if phone and not phone:FindFirstChild("PhonePrompt") then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "PhonePrompt"
		prompt.ActionText = "Answer Phone"
		prompt.ObjectText = "Phone"
		prompt.MaxActivationDistance = 8
		prompt.HoldDuration = 0
		prompt.KeyboardKeyCode = Enum.KeyCode.P
		prompt.Parent = phone
		prompt.Triggered:Connect(function()
			showPhone(true)
		end)
	end

	-- Mop prompt (for cleanup)
	local mop = workspace:WaitForChild("Mop", 10)
	if mop and not mop:FindFirstChild("MopPrompt") then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "MopPrompt"
		prompt.ActionText = "Pick Up Mop"
		prompt.ObjectText = "Mop"
		prompt.MaxActivationDistance = 6
		prompt.HoldDuration = 0
		prompt.Parent = mop
		prompt.Triggered:Connect(function()
			showFloatingText("Mop equipped!", Color3.fromRGB(150, 200, 255))
		end)
	end
end)

-- === FRIDGE DOOR ANIMATION ===
local function animateFridgeOpen()
	local fridgeDoor = workspace:FindFirstChild("FridgeDoor")
	local fridgeBatter = workspace:FindFirstChild("FridgeBatter")
	if not fridgeDoor then return end

	-- Show batter inside
	if fridgeBatter then fridgeBatter.Transparency = 0 end

	-- Slide door to the side (open effect)
	local originalPos = fridgeDoor.CFrame
	local openPos = fridgeDoor.CFrame * CFrame.new(2.5, 0, 0)
	TweenService:Create(fridgeDoor, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = openPos}):Play()

	-- Close after delay
	task.delay(1.5, function()
		TweenService:Create(fridgeDoor, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {CFrame = originalPos}):Play()
		task.delay(0.4, function()
			if fridgeBatter then fridgeBatter.Transparency = 1 end
		end)
	end)
end

-- === NPC SPEECH BUBBLE ===
local function showNPCSpeechBubble(npcModel, text)
	if not npcModel or not npcModel.Parent then return end
	local head = npcModel:FindFirstChild("Head")
	if not head then return end

	-- Remove any existing speech bubble
	local existing = head:FindFirstChild("SpeechBubble")
	if existing then existing:Destroy() end

	-- Create BillboardGui above NPC head
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "SpeechBubble"
	billboard.Size = UDim2.new(0, 250, 0, 80)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = head
	billboard.Parent = head

	-- Background frame
	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	bg.BackgroundTransparency = 0.15
	bg.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = bg

	-- Text label
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -10, 1, -6)
	label.Position = UDim2.new(0, 5, 0, 3)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 255, 220)
	label.TextScaled = true
	label.Font = Enum.Font.GothamMedium
	label.TextWrapped = true
	label.Text = text
	label.Parent = bg

	-- Auto-remove after 5 seconds
	task.delay(5, function()
		if billboard and billboard.Parent then
			billboard:Destroy()
		end
	end)
end

-- === LED ORDER SCREEN UPDATE ===
local function updateOrderScreen(text)
	local screen = workspace:FindFirstChild("OrderScreen")
	if not screen then return end
	local gui = screen:FindFirstChild("OrderDisplay")
	if not gui then return end
	local ordersText = gui:FindFirstChild("OrdersText")
	if ordersText then
		ordersText.Text = text
	end
end

-- === PHONE SYSTEM ===
local function showPhone(active)
	isPhoneActive = active
	phoneScreenGui.Enabled = active
	-- Also ensure the child frames are visible
	phoneFrame.Visible = active
	dialogueFrame.Visible = active
	dialogueSkipRequested = false
	phoneDialogueComplete = false
	if active then
		-- Phone ring sound
		playSound("PhoneRing")
	else
		stopSound("PhoneRing")
	end
end

local function showDialogue(text, lineNum, totalLines)
	-- Ensure phone screen is enabled and all frames visible
	phoneScreenGui.Enabled = true
	phoneFrame.Visible = true
	dialogueFrame.Visible = true
	dialogueSkipRequested = false

	-- Play manager voice sound for each line
	playSound("ManagerVoice")

	local textLabel = dialogueFrame:FindFirstChild("DialogueText")
	local progressLabel = dialogueFrame:FindFirstChild("ProgressLabel")
	local skipHint = dialogueFrame:FindFirstChild("SkipHint")

	if textLabel then
		-- Typewriter effect
		textLabel.Text = ""
		task.spawn(function()
			for i = 1, #text do
				if not isPhoneActive then break end
				if dialogueSkipRequested then
					-- Skip to full text
					textLabel.Text = text
					dialogueSkipRequested = false
					break
				end
				textLabel.Text = string.sub(text, 1, i)
				-- Play tick sound every few characters for voice effect
				if i % 3 == 0 then
					playSound("DialogueTick")
				end
				task.wait(NightData.PhoneConfig.dialogueSpeed)
			end
		end)
	end

	if progressLabel then
		progressLabel.Text = lineNum .. "/" .. totalLines
	end

	-- Show skip hint
	if skipHint then
		skipHint.Visible = true
	end
end

-- === CCTV SYSTEM ===
local cctvCameras = {}
local currentCamIndex = 1

local function initCCTV()
	local cctvFolder = workspace:FindFirstChild("CCTVCameras")
	if cctvFolder then
		cctvCameras = cctvFolder:GetChildren()
	end
end

local function toggleCCTV()
	isCCTVActive = not isCCTVActive
	cctvScreenGui.Enabled = isCCTVActive

	if isCCTVActive and #cctvCameras > 0 then
		-- Switch camera to CCTV view
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = cctvCameras[currentCamIndex].CFrame
		-- Apply CCTV filter
		local colorCorrection = Lighting:FindFirstChild("CCTVFilter")
		if colorCorrection then
			colorCorrection.Enabled = true
		end
		-- Camera label
		local camLabel = cctvFrame:FindFirstChild("CameraLabel")
		if camLabel then
			camLabel.Text = "CAM " .. currentCamIndex
		end
	else
		-- Return to normal camera
		camera.CameraType = Enum.CameraType.Custom
		local colorCorrection = Lighting:FindFirstChild("CCTVFilter")
		if colorCorrection then
			colorCorrection.Enabled = false
		end
	end
end

local function switchCCTVCamera(direction)
	if not isCCTVActive or #cctvCameras == 0 then return end

	currentCamIndex = currentCamIndex + direction
	if currentCamIndex < 1 then currentCamIndex = #cctvCameras end
	if currentCamIndex > #cctvCameras then currentCamIndex = 1 end

	-- Smooth transition
	local targetCFrame = cctvCameras[currentCamIndex].CFrame
	TweenService:Create(camera, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {CFrame = targetCFrame}):Play()

	local camLabel = cctvFrame:FindFirstChild("CameraLabel")
	if camLabel then
		camLabel.Text = "CAM " .. currentCamIndex
	end
end

-- === JUMP SCARE SYSTEM ===
local function playJumpScare(scareType)
	jumpscareScreenGui.Enabled = true

	-- Screen shake
	task.spawn(function()
		local originalCF = camera.CFrame
		for i = 1, 15 do
			local shakeX = (math.random() - 0.5) * Config.SCREEN_SHAKE_INTENSITY
			local shakeY = (math.random() - 0.5) * Config.SCREEN_SHAKE_INTENSITY
			camera.CFrame = camera.CFrame * CFrame.new(shakeX, shakeY, 0)
			task.wait(0.03)
		end
		camera.CFrame = originalCF
	end)

	-- Play scare sound
	playSound("JumpScareSound")

	-- Flash red
	local scareImage = jumpscareFrame:FindFirstChild("ScareImage")
	if scareImage then
		scareImage.Visible = true
		scareImage.ImageTransparency = 0
		TweenService:Create(scareImage, TweenInfo.new(Config.JUMPSCARE_DURATION), {ImageTransparency = 1}):Play()
	end

	-- Red flash
	local redFlash = jumpscareFrame:FindFirstChild("RedFlash")
	if redFlash then
		redFlash.BackgroundTransparency = 0
		TweenService:Create(redFlash, TweenInfo.new(Config.JUMPSCARE_DURATION), {BackgroundTransparency = 1}):Play()
	end

	task.wait(Config.JUMPSCARE_DURATION)
	jumpscareScreenGui.Enabled = false
end

-- === DEATH SCREEN ===
local function showDeathScreen(data)
	isAlive = false
	stopSound("HeartbeatSound")
	stopSound("AmbientHorror")

	-- Fade-in death screen
	deathScreenGui.Enabled = true
	local deathBg = deathFrame
	if deathBg then
		deathBg.BackgroundTransparency = 1
		TweenService:Create(deathBg, TweenInfo.new(1, Enum.EasingStyle.Sine), {BackgroundTransparency = 0.2}):Play()
	end

	local causeLabel = deathFrame:FindFirstChild("CauseLabel")
	if causeLabel then
		local causeText = "You died."
		local tipText = ""
		if data.cause then
			if string.find(data.cause, "gaze") then
				causeText = "You stared too long into the abyss..."
				tipText = "TIP: Don't look at cursed objects for more than 5 seconds"
			elseif string.find(data.cause, "truck_open") then
				causeText = "The shutters were open... It crawled in."
				tipText = "TIP: Press [1] [2] [3] to close all shutters when the truck arrives"
			elseif string.find(data.cause, "saree") then
				causeText = "You looked at her face... She was waiting for that."
				tipText = "TIP: Serve her but NEVER look at her face. Keep your gaze down."
			elseif string.find(data.cause, "wrong_order") then
				causeText = "Wrong order. He didn't appreciate that."
				tipText = "TIP: Listen to the manager's rules about what to serve each customer"
			elseif string.find(data.cause, "should_not_serve") then
				causeText = "You shouldn't have served him... He wasn't human."
				tipText = "TIP: Some customers should be IGNORED completely"
			elseif string.find(data.cause, "suthan_lights") then
				causeText = "Suthan found you with the lights on..."
				tipText = "TIP: Spill batter, turn OFF lights, then RUN to the back room"
			elseif string.find(data.cause, "suthan") then
				causeText = "Suthan caught you... There was no escape."
				tipText = "TIP: Press [G] to spill batter, [L] for lights, then run to the back!"
			elseif string.find(data.cause, "fatal") then
				causeText = "A fatal mistake. The rules exist for a reason."
				tipText = "TIP: Follow the manager's phone instructions carefully"
			elseif string.find(data.cause, "friend_prank") then
				causeText = "A friend pranked you! (Not a real death)"
				task.wait(2)
				deathScreenGui.Enabled = false
				isAlive = true
				return
			end
		end
		causeLabel.Text = causeText

		-- Show gameplay tip
		local tipLabel = deathFrame:FindFirstChild("TipLabel")
		if tipLabel and tipText ~= "" then
			tipLabel.Text = tipText
			tipLabel.Visible = true
		elseif tipLabel then
			tipLabel.Visible = false
		end
	end

	local nightLabel = deathFrame:FindFirstChild("NightLabel")
	if nightLabel then
		nightLabel.Text = "Night " .. (data.night or currentNight)
	end
end

-- === NIGHT START SCREEN ===
local function showNightStart(nightNum)
	nightStartScreenGui.Enabled = true
	local titleLabel = nightStartFrame:FindFirstChild("TitleLabel")
	if titleLabel then
		titleLabel.Text = "NIGHT " .. nightNum
		titleLabel.TextColor3 = Color3.fromRGB(200, 50, 25)
		titleLabel.TextTransparency = 1

		-- Fade in
		TweenService:Create(titleLabel, TweenInfo.new(1, Enum.EasingStyle.Sine), {TextTransparency = 0}):Play()
		task.wait(2)
		TweenService:Create(titleLabel, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
		task.wait(0.5)
		nightStartScreenGui.Enabled = false
	end
end

-- === STAMINA SYSTEM ===
RunService.Heartbeat:Connect(function(dt)
	if not isAlive then return end

	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	if isSprinting and stamina > 0 then
		stamina = math.max(0, stamina - Config.SPRINT_DRAIN * dt)
		humanoid.WalkSpeed = 16 * Config.SPRINT_SPEED_MULT
	else
		stamina = math.min(Config.MAX_STAMINA, stamina + Config.STAMINA_REGEN * dt)
		humanoid.WalkSpeed = 16
		if stamina <= 0 then
			isSprinting = false
		end
	end

	-- Update stamina bar
	local staminaBar = hudFrame:FindFirstChild("StaminaBar")
	if staminaBar then
		local fill = staminaBar:FindFirstChild("Fill")
		if fill then
			fill.Size = UDim2.new(stamina / Config.MAX_STAMINA, 0, 1, 0)
			fill.BackgroundColor3 = stamina > 30 and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(200, 0, 0)
		end
	end
end)

-- === GAZE SYSTEM ===
local gazeTimers = {} -- [object] = time spent gazing

RunService.Heartbeat:Connect(function(dt)
	if not isAlive or isCCTVActive then return end

	local character = player.Character
	if not character then return end
	local head = character:FindFirstChild("Head")
	if not head then return end

	-- Cast ray from camera forward
	local ray = camera:ViewportPointToRay(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {character}

	local result = workspace:Raycast(ray.Origin, ray.Direction * 200, raycastParams)

	if result and result.Instance then
		local hitPart = result.Instance
		local model = hitPart:FindFirstAncestorOfClass("Model") or hitPart

		-- Check for CursedObject using BoolValue child
		local cursedVal = hitPart:FindFirstChild("CursedObject") or model:FindFirstChild("CursedObject")
		local isCursed = false
		if cursedVal and cursedVal:IsA("BoolValue") then
			isCursed = cursedVal.Value
		elseif model:GetAttribute("CursedObject") then
			isCursed = true
		end

		if isCursed then
			gazeTimers[model] = (gazeTimers[model] or 0) + dt

			-- Show warning UI
			local gazeWarning = hudFrame:FindFirstChild("GazeWarning")
			if gazeWarning then
				gazeWarning.Visible = true
				gazeWarning.Text = string.format("DON'T LOOK! (%.1fs)", Config.GAZE_DEATH_TIME - gazeTimers[model])
				gazeWarning.TextColor3 = Color3.fromRGB(255, math.max(0, 255 - gazeTimers[model] * 50), 0)
			end

			-- Play heartbeat when getting close to death
			if gazeTimers[model] > Config.GAZE_DEATH_TIME * 0.5 then
				local heartbeat = SoundService:FindFirstChild("HeartbeatSound")
				if heartbeat and not heartbeat.IsPlaying then
					heartbeat:Play()
				end
			end

			if gazeTimers[model] >= Config.GAZE_DEATH_TIME then
				Remotes:WaitForChild("GazeDeath"):FireServer(model.Name)
				gazeTimers[model] = 0
			end
		else
			-- Decay gaze timers
			for obj, _ in pairs(gazeTimers) do
				gazeTimers[obj] = math.max(0, (gazeTimers[obj] or 0) - dt * 2)
				if gazeTimers[obj] <= 0 then
					gazeTimers[obj] = nil
				end
			end
			local gazeWarning = hudFrame:FindFirstChild("GazeWarning")
			if gazeWarning then
				gazeWarning.Visible = false
			end
			stopSound("HeartbeatSound")
		end

		-- Check if looking at Saree Woman's face
		local npcType = model:GetAttribute("NPCType")
		if npcType == "SareeWoman" then
			local npcHead = model:FindFirstChild("Head")
			if npcHead and hitPart == npcHead then
				gazeTimers["SareeWomanFace"] = (gazeTimers["SareeWomanFace"] or 0) + dt
				if gazeTimers["SareeWomanFace"] >= 1 then
					Remotes:WaitForChild("LookedAtFace"):FireServer("SareeWoman")
					gazeTimers["SareeWomanFace"] = 0
				end
			end
		end
	else
		for obj, _ in pairs(gazeTimers) do
			gazeTimers[obj] = math.max(0, (gazeTimers[obj] or 0) - dt * 2)
			if gazeTimers[obj] <= 0 then
				gazeTimers[obj] = nil
			end
		end
		local gazeWarning = hudFrame:FindFirstChild("GazeWarning")
		if gazeWarning then
			gazeWarning.Visible = false
		end
		stopSound("HeartbeatSound")
	end
end)

-- === INPUT HANDLING ===
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end

	if input.KeyCode == Enum.KeyCode.LeftShift then
		isSprinting = true
	elseif input.KeyCode == Enum.KeyCode.C then
		toggleCCTV()
	elseif input.KeyCode == Enum.KeyCode.Q then
		if isCCTVActive then
			switchCCTVCamera(-1)
		end
	elseif input.KeyCode == Enum.KeyCode.E then
		if isCCTVActive then
			switchCCTVCamera(1)
		else
			-- E key cleanup when near mess
			if messVisible then
				local character = player.Character
				if character and messZone then
					local hrp = character:FindFirstChild("HumanoidRootPart")
					if hrp and (hrp.Position - messZone.Position).Magnitude < 8 then
						messVisible = false
						messZone.Transparency = 1
						Remotes:WaitForChild("CleanMess"):FireServer()
						showFloatingText("Mess Cleaned!", Color3.fromRGB(100, 200, 255))
					end
				end
			end
		end
	elseif input.KeyCode == Enum.KeyCode.F then
		-- Grab batter from fridge (when near fridge)
		local character = player.Character
		if character then
			local fridgePart = workspace:FindFirstChild("FridgeDoor") or workspace:FindFirstChild("Fridge")
			if fridgePart then
				local dist = (character.HumanoidRootPart.Position - fridgePart.Position).Magnitude
				if dist < 8 then
					Remotes:WaitForChild("GrabBatter"):FireServer()
					playSound("DoorCreak")
					animateFridgeOpen()
				end
			end
		end
	elseif input.KeyCode == Enum.KeyCode.T then
		-- Cook dosa on tawa (when near tawa)
		local character = player.Character
		if character then
			local tawa = workspace:FindFirstChild("Tawa")
			if tawa then
				local dist = (character.HumanoidRootPart.Position - tawa.Position).Magnitude
				if dist < 8 then
					Remotes:WaitForChild("CookDosa"):FireServer()
					playSound("CookingSound")
				end
			end
		end
	elseif input.KeyCode == Enum.KeyCode.L then
		Remotes:WaitForChild("ToggleLights"):FireServer()
	elseif input.KeyCode == Enum.KeyCode.One then
		Remotes:WaitForChild("ToggleShutter"):FireServer("front")
		playSound("ShutterSound")
	elseif input.KeyCode == Enum.KeyCode.Two then
		Remotes:WaitForChild("ToggleShutter"):FireServer("left")
		playSound("ShutterSound")
	elseif input.KeyCode == Enum.KeyCode.Three then
		Remotes:WaitForChild("ToggleShutter"):FireServer("right")
		playSound("ShutterSound")
	elseif input.KeyCode == Enum.KeyCode.P then
		-- Pick up phone
		showPhone(true)
	elseif input.KeyCode == Enum.KeyCode.G then
		-- Night 5: Spill batter
		if currentNight == 5 then
			Remotes:WaitForChild("SpillBatter"):FireServer()
		end
	end
end)

-- Click to skip dialogue
UserInputService.InputBegan:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 and isPhoneActive then
		dialogueSkipRequested = true
	end
end)

UserInputService.InputEnded:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		isSprinting = false
	end
end)

-- === PROXIMITY PROMPT HANDLING ===
-- NPC serving
local function onProximityPromptTriggered(prompt)
	if not isAlive then return end

	local npcModel = prompt.Parent and prompt.Parent.Parent
	if not npcModel then return end

	local npcType = npcModel:GetAttribute("NPCType")
	if not npcType then return end

	if selectedItem then
		Remotes:WaitForChild("ServeCustomer"):FireServer(npcType, selectedItem)
		selectedItem = nil
		-- Reset menu button highlights
		local menuContainer = hudFrame:FindFirstChild("MenuContainer")
		if menuContainer then
			for _, sibling in ipairs(menuContainer:GetChildren()) do
				if sibling:IsA("TextButton") then
					sibling.BackgroundColor3 = Color3.fromRGB(80, 60, 40)
				end
			end
		end
	else
		-- Show menu selection UI
		menuScreenGui.Enabled = true
	end
end

-- Connect to all proximity prompts (current and future)
workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("ProximityPrompt") and descendant.Name == "ServePrompt" then
		descendant.Triggered:Connect(function()
			onProximityPromptTriggered(descendant)
		end)
	end
end)

-- === LIGHT FLICKER EFFECT ===
local function flickerLights(duration)
	task.spawn(function()
		local elapsed = 0
		while elapsed < duration do
			Lighting.Brightness = math.random() * (Config.FLICKER_MAX - Config.FLICKER_MIN) + Config.FLICKER_MIN
			local waitTime = math.random() * Config.FLICKER_SPEED + 0.05
			task.wait(waitTime)
			elapsed = elapsed + waitTime
		end
		Lighting.Brightness = Config.AMBIENT_BRIGHTNESS
	end)
end

-- === REMOTE EVENT LISTENERS ===
Remotes:WaitForChild("StartNight").OnClientEvent:Connect(function(nightNum, nightInfo)
	currentNight = nightNum
	isAlive = true
	deathScreenGui.Enabled = false
	phoneScreenGui.Enabled = false
	menuScreenGui.Enabled = false
	showNightStart(nightNum)
end)

Remotes:WaitForChild("EndNight").OnClientEvent:Connect(function(data)
	stopSound("AmbientHorror")
	stopSound("HeartbeatSound")
	if data.survived then
		playSound("VictorySound")
		showFloatingText("NIGHT " .. data.night .. " SURVIVED!", Color3.fromRGB(0, 255, 0))
		task.wait(3)
		if data.nextNight and data.nextNight <= 5 then
			showFloatingText("Preparing Night " .. data.nextNight .. "...", Color3.fromRGB(255, 200, 0))
		end
	end
end)

Remotes:WaitForChild("PhoneRing").OnClientEvent:Connect(function()
	showPhone(true)
end)

Remotes:WaitForChild("PhoneDialogue").OnClientEvent:Connect(function(text, lineNum, totalLines)
	showDialogue(text, lineNum, totalLines)
end)

-- Phone dialogue end: close phone UI
local phoneDialogueEnd = Remotes:FindFirstChild("PhoneDialogueEnd")
if phoneDialogueEnd then
	phoneDialogueEnd.OnClientEvent:Connect(function()
		phoneDialogueComplete = true
		task.wait(1)
		showPhone(false)
	end)
end

Remotes:WaitForChild("PlayerDeath").OnClientEvent:Connect(function(data)
	showDeathScreen(data)
	Remotes:WaitForChild("RecordDeath"):FireServer()
end)

Remotes:WaitForChild("JumpScare").OnClientEvent:Connect(function(scareType)
	playJumpScare(scareType)
end)

Remotes:WaitForChild("NightComplete").OnClientEvent:Connect(function(result)
	if result == "victory" then
		-- Victory screen with stats
		stopSound("AmbientHorror")
		stopSound("HeartbeatSound")
		playSound("VictorySound")
		deathScreenGui.Enabled = false

		-- Show the victory screen
		local victoryScreenGui = playerGui:FindFirstChild("VictoryScreenGui")
		if victoryScreenGui then
			victoryScreenGui.Enabled = true
			-- Animate title
			local victoryFrame = victoryScreenGui:FindFirstChild("VictoryUI")
			if victoryFrame then
				local titleLbl = victoryFrame:FindFirstChild("VictoryTitle")
				if titleLbl then
					titleLbl.TextTransparency = 1
					TweenService:Create(titleLbl, TweenInfo.new(1.5, Enum.EasingStyle.Sine), {TextTransparency = 0}):Play()
				end
				-- Display stats
				local statsLbl = victoryFrame:FindFirstChild("StatsLabel")
				if statsLbl then
					local currencyLbl = hudFrame:FindFirstChild("CurrencyLabel")
					local earnings = currencyLbl and currencyLbl.Text or "$0"
					statsLbl.Text = "FINAL STATS\n\nNights Survived: 5/5\nTotal Earnings: " .. earnings .. "\nRating: MASTER CHEF\n\nYou conquered Road Side Dosa!\nThe horrors of the Dhaba are behind you...\n\n...or are they?"
				end
			end
		else
			-- Fallback: use night start screen
			nightStartScreenGui.Enabled = true
			local titleLabel = nightStartFrame:FindFirstChild("TitleLabel")
			if titleLabel then
				titleLabel.Text = "YOU SURVIVED ALL 5 NIGHTS!"
				titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
				titleLabel.TextTransparency = 0
			end
		end
		Remotes:WaitForChild("GameCompleted"):FireServer()
	end
end)

Remotes:WaitForChild("SpawnNPC").OnClientEvent:Connect(function(npcType, npcModel, dialogue, orderedItem)
	-- Show NPC dialogue as floating text
	if dialogue then
		showFloatingText(dialogue, Color3.fromRGB(255, 255, 200))
	end

	-- Show speech bubble above NPC head
	if npcModel and dialogue then
		showNPCSpeechBubble(npcModel, dialogue)
	end

	-- Play customer voice sound
	playSound("CustomerVoice")

	-- Whisper sound when anomaly spawns
	if npcType ~= "NormalCustomer" then
		playSound("WhisperSound")
	end

	-- Update LED order screen with specific order
	local orderText = "NEW ORDER\n"
	if npcType == "DancingGuy" then
		orderText = orderText .. "Dancing Man\n⚠ DO NOT SERVE ⚠"
	elseif npcType == "Suthan" then
		orderText = orderText .. "SUTHAN\n⚠ DANGER ⚠"
	elseif npcType == "NakedGuy" then
		orderText = orderText .. "???\nRUN THROUGH!"
	elseif orderedItem then
		orderText = orderText .. "1 " .. orderedItem
	else
		orderText = orderText .. "Waiting for order..."
	end
	updateOrderScreen(orderText)
end)

Remotes:WaitForChild("NPCDialogue").OnClientEvent:Connect(function(npcType, dialogue)
	showFloatingText(dialogue, Color3.fromRGB(255, 255, 200))
	playSound("CustomerVoice")
	-- Find the NPC model and show speech bubble
	local npcsFolder = workspace:FindFirstChild("NPCs")
	if npcsFolder then
		for _, npc in ipairs(npcsFolder:GetChildren()) do
			if npc:GetAttribute("NPCType") == npcType then
				showNPCSpeechBubble(npc, dialogue)
				break
			end
		end
	end
end)

Remotes:WaitForChild("NPCLeave").OnClientEvent:Connect(function(npcType, reason)
	if reason == "timeout" then
		showFloatingText("Customer left angry!", Color3.fromRGB(255, 100, 0))
	end
end)

-- Death screen retry button
local retryBtn = deathFrame:FindFirstChild("RetryButton")
if retryBtn then
	retryBtn.MouseButton1Click:Connect(function()
		deathScreenGui.Enabled = false
		Remotes:WaitForChild("RequestRetry"):FireServer()
	end)
end

-- Lobby screen
local lobbyScreenGui = playerGui:WaitForChild("LobbyScreenGui")
local lobbyUI = lobbyScreenGui:WaitForChild("LobbyUI")
local startBtn = lobbyUI:FindFirstChild("StartButton")
if startBtn then
	startBtn.MouseButton1Click:Connect(function()
		lobbyScreenGui.Enabled = false
		Remotes:WaitForChild("RequestStartNight"):FireServer()
	end)
end

-- === COOKING VISUAL FEEDBACK ===
local dosaVisual = workspace:FindFirstChild("DosaOnTawa")

Remotes:WaitForChild("UpdateHUD").OnClientEvent:Connect(function(data)
	updateHUD(data)

	-- Show dosa cooking on tawa
	if data.cookingStarted and dosaVisual then
		dosaVisual.Transparency = 0.3
		-- Gradually make it more visible (cooking animation)
		task.spawn(function()
			for i = 1, 10 do
				task.wait(Config.COOKING_TIME / 10)
				if dosaVisual then
					dosaVisual.Transparency = 0.3 - (i * 0.03)
				end
			end
		end)
	end

	if data.dosaReady and dosaVisual then
		dosaVisual.Transparency = 0
		task.delay(3, function()
			if dosaVisual then dosaVisual.Transparency = 1 end
		end)
	end
end)

-- === CLEANUP MECHANIC (Night 2) ===
messVisible = false
messZone = workspace:FindFirstChild("MessZone")

Remotes:WaitForChild("TriggerEvent").OnClientEvent:Connect(function(eventType, eventData)
	if eventType == "naked_guy_throw" then
		-- Make mess visible
		messVisible = true
		if messZone then
			messZone.Transparency = 0
			messZone.BrickColor = BrickColor.new("Dirt brown")
		end
		showFloatingText("What the--?! Clean that up! [E near mess]", Color3.fromRGB(255, 150, 0))
	elseif eventType == "lights_flicker" then
		flickerLights(3)
		playSound("WhisperSound")
	elseif eventType == "terrifier_truck" then
		showFloatingText("Something is outside... DON'T LOOK!", Color3.fromRGB(255, 0, 0))
		playSound("TruckEngine")
	elseif eventType == "terrifier_truck_aggressive" then
		showFloatingText("THE TRUCK IS BACK!", Color3.fromRGB(255, 0, 0))
		playSound("TruckEngine")
		task.wait(1)
		showFloatingText("CLOSE ALL SHUTTERS! [1] [2] [3]", Color3.fromRGB(255, 0, 0))
		if eventData and eventData.killIfOpen then
			task.wait(2)
			Remotes:WaitForChild("TruckArrival"):FireServer()
		end
	elseif eventType == "final_sequence" then
		showFloatingText("He's here... Suthan...", Color3.fromRGB(200, 0, 0))
		playSound("HeartbeatSound")
		flickerLights(2)
	end
end)

-- === SAFE ROOM DETECTION (Night 5) ===
RunService.Heartbeat:Connect(function()
	if not isAlive or currentNight ~= 5 then return end

	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local safeTrigger = workspace:FindFirstChild("SafeRoomTrigger")
	if safeTrigger then
		local dist = (hrp.Position - safeTrigger.Position).Magnitude
		if dist < 6 then
			Remotes:WaitForChild("ReachedSafeRoom"):FireServer()
		end
	end
end)

-- === AMBIENT HORROR EFFECTS ===
-- Random creepy events during night gameplay
task.spawn(function()
	while true do
		task.wait(math.random(15, 40)) -- Random interval
		if not isAlive or currentNight == 0 then continue end

		local roll = math.random(1, 6)
		if roll == 1 then
			-- Random whisper sound
			playSound("WhisperSound")
		elseif roll == 2 then
			-- Brief screen flicker
			local colorCorrection = Lighting:FindFirstChild("HorrorColor")
			if colorCorrection then
				local origBrightness = colorCorrection.Brightness
				colorCorrection.Brightness = -0.3
				task.wait(0.1)
				colorCorrection.Brightness = origBrightness
			end
		elseif roll == 3 then
			-- Subtle heartbeat for 2 seconds
			playSound("HeartbeatSound")
			task.wait(2)
			stopSound("HeartbeatSound")
		elseif roll == 4 then
			-- Creepy floating text
			local messages = {
				"Did you hear that?",
				"Something moved...",
				"Don't look behind you...",
				"Is someone watching?",
				"The walls are breathing...",
				"Trust no one.",
			}
			showFloatingText(messages[math.random(1, #messages)], Color3.fromRGB(100, 50, 50))
		elseif roll == 5 then
			-- Ceiling fan creak sound
			playSound("DoorCreak")
		elseif roll == 6 then
			-- Brief fog change
			local origFog = Lighting.FogEnd
			Lighting.FogEnd = origFog * 0.5
			task.wait(0.5)
			Lighting.FogEnd = origFog
		end
	end
end)

-- === GAMEPASS SYSTEM (Client Side) ===
local ownedPasses = {} -- {passName = true}
local gamePassScreenGui = playerGui:WaitForChild("GamePassScreenGui")
local gamePassFrame = gamePassScreenGui:WaitForChild("GamePassUI")

-- Toggle game pass shop with B key
local gamePassShopOpen = false
local function toggleGamePassShop()
	gamePassShopOpen = not gamePassShopOpen
	gamePassScreenGui.Enabled = gamePassShopOpen
end

-- Handle owned pass notification from server
Remotes:WaitForChild("GamePassOwned").OnClientEvent:Connect(function(passName)
	ownedPasses[passName] = true
	showFloatingText("GamePass: " .. passName .. " Active!", Color3.fromRGB(255, 215, 0))

	-- Update shop button if visible
	local btn = gamePassFrame:FindFirstChild("Pass_" .. passName)
	if btn then
		btn.Text = passName .. " [OWNED]"
		btn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
	end
end)

-- Anomaly Identifier: Show red glow on CCTV when anomaly present
local anomalyWarningActive = false
Remotes:WaitForChild("SpawnNPC").OnClientEvent:Connect(function(npcType, npcModel, dialogue, orderedItem)
	-- If player owns Anomaly Identifier and NPC is anomaly, show warning
	if ownedPasses["AnomalyIdentifier"] and npcType ~= "NormalCustomer" then
		anomalyWarningActive = true
		local warningLabel = cctvFrame:FindFirstChild("AnomalyWarning")
		if warningLabel then
			warningLabel.Visible = true
			warningLabel.Text = "⚠ ANOMALY DETECTED: " .. npcType .. " ⚠"
		end
		-- Also add red glow to NPC model
		if npcModel then
			local highlight = Instance.new("Highlight")
			highlight.Name = "AnomalyHighlight"
			highlight.FillColor = Color3.fromRGB(255, 0, 0)
			highlight.FillTransparency = 0.7
			highlight.OutlineColor = Color3.fromRGB(255, 0, 0)
			highlight.OutlineTransparency = 0.3
			highlight.Parent = npcModel
		end
	end
end)

-- Clear anomaly warning when NPC leaves
Remotes:WaitForChild("NPCLeave").OnClientEvent:Connect(function(npcType, reason)
	anomalyWarningActive = false
	local warningLabel = cctvFrame:FindFirstChild("AnomalyWarning")
	if warningLabel then
		warningLabel.Visible = false
	end
end)

-- GamePass check result
Remotes:WaitForChild("GamePassCheckResult").OnClientEvent:Connect(function(passName, owns)
	if owns then
		ownedPasses[passName] = true
	end
end)

-- NPC Transformed (Humanity Serum)
Remotes:WaitForChild("NPCTransformed").OnClientEvent:Connect(function(npcModel)
	showFloatingText("Anomaly transformed to human!", Color3.fromRGB(0, 255, 100))
	playSound("VictorySound")
	-- Remove highlight if exists
	if npcModel then
		local highlight = npcModel:FindFirstChild("AnomalyHighlight")
		if highlight then highlight:Destroy() end
	end
end)

-- === LEADERBOARD UI ===
local leaderboardScreenGui = playerGui:WaitForChild("LeaderboardScreenGui")
local leaderboardFrame = leaderboardScreenGui:WaitForChild("LeaderboardUI")
local leaderboardOpen = false

local function toggleLeaderboard()
	leaderboardOpen = not leaderboardOpen
	leaderboardScreenGui.Enabled = leaderboardOpen
end

-- Receive leaderboard data from server
Remotes:WaitForChild("UpdateLeaderboard").OnClientEvent:Connect(function(leaderboardData)
	local listFrame = leaderboardFrame:FindFirstChild("LeaderboardList")
	if not listFrame then return end

	-- Clear old entries
	for _, child in ipairs(listFrame:GetChildren()) do
		if child:IsA("TextLabel") and child.Name ~= "HeaderLabel" then
			child:Destroy()
		end
	end

	-- Populate new entries
	for i, entry in ipairs(leaderboardData) do
		if i > 10 then break end -- Show top 10

		local label = Instance.new("TextLabel")
		label.Name = "Entry_" .. i
		label.Size = UDim2.new(1, -10, 0, 25)
		label.Position = UDim2.new(0, 5, 0, 30 + (i * 28))
		label.BackgroundTransparency = 0.5
		label.BackgroundColor3 = i <= 3 and Color3.fromRGB(60, 40, 10) or Color3.fromRGB(30, 30, 30)
		label.TextColor3 = i == 1 and Color3.fromRGB(255, 215, 0) or
						   i == 2 and Color3.fromRGB(200, 200, 200) or
						   i == 3 and Color3.fromRGB(180, 120, 60) or
						   Color3.fromRGB(180, 180, 180)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.Text = "#" .. entry.rank .. "  " .. tostring(entry.key):gsub("Player_", "") .. "  $" .. entry.value
		label.Parent = listFrame
	end
end)

-- === GUN TOOL (GamePass) ===
local hasGun = false
local gunCooldown = false

local function useGun()
	if not ownedPasses["TheGun"] or gunCooldown then return end
	if not isAlive then return end

	gunCooldown = true
	playSound("JumpScareSound") -- Bang sound

	-- Show muzzle flash effect
	showFloatingText("BANG!", Color3.fromRGB(255, 200, 0))

	-- Raycast from camera to find NPC target
	local ray = camera:ViewportPointToRay(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	local character = player.Character
	if character then
		raycastParams.FilterDescendantsInstances = {character}
	end

	local result = workspace:Raycast(ray.Origin, ray.Direction * 100, raycastParams)
	if result and result.Instance then
		local model = result.Instance:FindFirstAncestorOfClass("Model") or result.Instance
		local npcType = model:GetAttribute("NPCType")
		if npcType then
			-- Gun can stun anomaly NPCs (they leave faster)
			showFloatingText("Hit " .. npcType .. "!", Color3.fromRGB(255, 100, 0))
			-- Visual: make NPC flash red
			for _, part in ipairs(model:GetDescendants()) do
				if part:IsA("BasePart") then
					local original = part.BrickColor
					part.BrickColor = BrickColor.new("Really red")
					task.delay(0.3, function()
						if part and part.Parent then
							part.BrickColor = original
						end
					end)
				end
			end
		end
	end

	-- Cooldown 2 seconds
	task.delay(2, function()
		gunCooldown = false
	end)
end

-- === HUMANITY SERUM (GamePass) ===
local function useHumanitySerum()
	if not ownedPasses["HumanitySerum"] then return end
	if not isAlive then return end

	-- Find closest anomaly NPC
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local npcsFolder = workspace:FindFirstChild("NPCs")
	if not npcsFolder then return end

	local closest = nil
	local closestDist = 15

	for _, npc in ipairs(npcsFolder:GetChildren()) do
		if npc:GetAttribute("IsAnomaly") then
			local npcHRP = npc:FindFirstChild("HumanoidRootPart")
			if npcHRP then
				local dist = (hrp.Position - npcHRP.Position).Magnitude
				if dist < closestDist then
					closest = npc
					closestDist = dist
				end
			end
		end
	end

	if closest then
		Remotes:WaitForChild("UseHumanitySerum"):FireServer(closest)
	else
		showFloatingText("No anomaly nearby!", Color3.fromRGB(255, 100, 0))
	end
end

-- === EXTRA INPUT HANDLING (GamePasses + Leaderboard) ===
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end

	if input.KeyCode == Enum.KeyCode.B then
		toggleGamePassShop()
	elseif input.KeyCode == Enum.KeyCode.Tab then
		toggleLeaderboard()
	elseif input.KeyCode == Enum.KeyCode.R then
		-- Gun shoot
		if ownedPasses["TheGun"] then
			useGun()
		end
	elseif input.KeyCode == Enum.KeyCode.H then
		-- Humanity Serum
		if ownedPasses["HumanitySerum"] then
			useHumanitySerum()
		end
	elseif input.KeyCode == Enum.KeyCode.J then
		-- Jumpscare Friend - target nearest other player
		if ownedPasses["JumpscareFriend"] then
			local character = player.Character
			if character then
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if hrp then
					local closestPlayer = nil
					local closestDist = 50
					for _, otherPlayer in ipairs(Players:GetPlayers()) do
						if otherPlayer ~= player and otherPlayer.Character then
							local otherHRP = otherPlayer.Character:FindFirstChild("HumanoidRootPart")
							if otherHRP then
								local dist = (hrp.Position - otherHRP.Position).Magnitude
								if dist < closestDist then
									closestPlayer = otherPlayer
									closestDist = dist
								end
							end
						end
					end
					if closestPlayer then
						Remotes:WaitForChild("UseJumpscareFriend"):FireServer(closestPlayer)
						showFloatingText("Pranked " .. closestPlayer.Name .. "!", Color3.fromRGB(255, 100, 255))
					else
						showFloatingText("No players nearby to prank!", Color3.fromRGB(255, 100, 0))
					end
				end
			end
		end
	end
end)

-- Check owned passes on load
task.spawn(function()
	task.wait(2)
	for _, passName in ipairs({"AnomalyIdentifier", "JumpscareFriend", "TheGun", "HumanitySerum"}) do
		Remotes:WaitForChild("CheckGamePass"):FireServer(passName)
	end
end)

-- Initialize CCTV
initCCTV()

print("[ClientController] Client initialized for " .. player.Name)
