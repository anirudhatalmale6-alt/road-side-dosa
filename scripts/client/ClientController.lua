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

-- UI References
local playerGui = player:WaitForChild("PlayerGui")
local mainUI = playerGui:WaitForChild("MainUI")
local hudFrame = mainUI:WaitForChild("HUD")
local phoneFrame = mainUI:WaitForChild("PhoneUI")
local cctvFrame = mainUI:WaitForChild("CCTVUI")
local deathFrame = mainUI:WaitForChild("DeathUI")
local menuFrame = mainUI:WaitForChild("MenuUI")
local jumpscareFrame = mainUI:WaitForChild("JumpscareUI")
local nightStartFrame = mainUI:WaitForChild("NightStartUI")
local dialogueFrame = mainUI:WaitForChild("DialogueUI")

-- State
local currentNight = 0
local isPhoneActive = false
local isCCTVActive = false
local isAlive = true
local stamina = Config.MAX_STAMINA
local isSprinting = false
local menuItems = {}
local selectedItem = nil

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
		-- Flash the serve button
		local serveBtn = hudFrame:FindFirstChild("ServeButton")
		if serveBtn then
			TweenService:Create(serveBtn, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true), {BackgroundColor3 = Color3.fromRGB(255, 200, 0)}):Play()
		end
	end
	if data.serveSuccess then
		-- Show success feedback
		showFloatingText("+$" .. Config.CURRENCY_PER_SALE, Color3.fromRGB(0, 255, 0))
	end
	if data.messCleared then
		showFloatingText("Mess Cleaned!", Color3.fromRGB(100, 200, 255))
	end
	if data.batterSpilled then
		showFloatingText("BATTER SPILLED! RUN!", Color3.fromRGB(255, 0, 0))
	end
end

-- === FLOATING TEXT ===
local function showFloatingText(text, color)
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
function updateMenuButtons()
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

-- === PHONE SYSTEM ===
local function showPhone(active)
	isPhoneActive = active
	phoneFrame.Visible = active
	if active then
		-- Phone ring animation
		local phoneModel = workspace:FindFirstChild("Phone")
		if phoneModel then
			-- Vibrate effect
			task.spawn(function()
				for i = 1, 6 do
					if not isPhoneActive then break end
					-- Play ring sound
					local ringSound = phoneModel:FindFirstChild("RingSound")
					if ringSound then ringSound:Play() end
					task.wait(2)
				end
			end)
		end
	end
end

local function showDialogue(text, lineNum, totalLines)
	dialogueFrame.Visible = true
	local textLabel = dialogueFrame:FindFirstChild("DialogueText")
	local progressLabel = dialogueFrame:FindFirstChild("ProgressLabel")

	if textLabel then
		-- Typewriter effect
		textLabel.Text = ""
		task.spawn(function()
			for i = 1, #text do
				if not isPhoneActive then break end
				textLabel.Text = string.sub(text, 1, i)
				task.wait(NightData.PhoneConfig.dialogueSpeed)
			end
		end)
	end

	if progressLabel then
		progressLabel.Text = lineNum .. "/" .. totalLines
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
	cctvFrame.Visible = isCCTVActive

	if isCCTVActive and #cctvCameras > 0 then
		-- Switch camera to CCTV view
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = cctvCameras[currentCamIndex].CFrame
		-- Apply CCTV filter
		local colorCorrection = Lighting:FindFirstChild("CCTVFilter")
		if colorCorrection then
			colorCorrection.Enabled = true
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

	camera.CFrame = cctvCameras[currentCamIndex].CFrame

	local camLabel = cctvFrame:FindFirstChild("CameraLabel")
	if camLabel then
		camLabel.Text = "CAM " .. currentCamIndex
	end
end

-- === JUMP SCARE SYSTEM ===
local function playJumpScare(scareType)
	jumpscareFrame.Visible = true

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
	local scareSound = SoundService:FindFirstChild("JumpScareSound")
	if scareSound then
		scareSound:Play()
	end

	-- Flash red
	local scareImage = jumpscareFrame:FindFirstChild("ScareImage")
	if scareImage then
		scareImage.Visible = true
		scareImage.ImageTransparency = 0
		TweenService:Create(scareImage, TweenInfo.new(Config.JUMPSCARE_DURATION), {ImageTransparency = 1}):Play()
	end

	task.wait(Config.JUMPSCARE_DURATION)
	jumpscareFrame.Visible = false
end

-- === DEATH SCREEN ===
local function showDeathScreen(data)
	isAlive = false
	deathFrame.Visible = true

	local causeLabel = deathFrame:FindFirstChild("CauseLabel")
	if causeLabel then
		local causeText = "You died."
		if data.cause then
			if string.find(data.cause, "gaze") then
				causeText = "You stared too long..."
			elseif string.find(data.cause, "truck") then
				causeText = "The shutters were open... it got in."
			elseif string.find(data.cause, "saree") then
				causeText = "You looked at her face..."
			elseif string.find(data.cause, "wrong_order") then
				causeText = "You served the wrong item..."
			elseif string.find(data.cause, "should_not_serve") then
				causeText = "You shouldn't have served him..."
			elseif string.find(data.cause, "suthan") then
				causeText = "Suthan caught you..."
			elseif string.find(data.cause, "friend_prank") then
				causeText = "A friend pranked you! (Not a real death)"
				-- This is just a prank from gamepass
				task.wait(2)
				deathFrame.Visible = false
				isAlive = true
				return
			end
		end
		causeLabel.Text = causeText
	end

	local nightLabel = deathFrame:FindFirstChild("NightLabel")
	if nightLabel then
		nightLabel.Text = "Night " .. (data.night or currentNight)
	end
end

-- === NIGHT START SCREEN ===
local function showNightStart(nightNum)
	nightStartFrame.Visible = true
	local titleLabel = nightStartFrame:FindFirstChild("TitleLabel")
	if titleLabel then
		titleLabel.Text = "NIGHT " .. nightNum
		titleLabel.TextTransparency = 1

		-- Fade in
		TweenService:Create(titleLabel, TweenInfo.new(1, Enum.EasingStyle.Sine), {TextTransparency = 0}):Play()
		task.wait(2)
		TweenService:Create(titleLabel, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
		task.wait(0.5)
		nightStartFrame.Visible = false
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
local gazeTargets = {} -- objects that kill if stared at
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
		local model = result.Instance:FindFirstAncestorOfClass("Model") or result.Instance

		if model:GetAttribute("CursedObject") then
			gazeTimers[model] = (gazeTimers[model] or 0) + dt

			-- Show warning UI
			local gazeWarning = hudFrame:FindFirstChild("GazeWarning")
			if gazeWarning then
				gazeWarning.Visible = true
				gazeWarning.Text = string.format("DON'T LOOK! (%.1fs)", Config.GAZE_DEATH_TIME - gazeTimers[model])
				gazeWarning.TextColor3 = Color3.fromRGB(255, math.max(0, 255 - gazeTimers[model] * 50), 0)
			end

			if gazeTimers[model] >= Config.GAZE_DEATH_TIME then
				Remotes:WaitForChild("GazeDeath"):FireServer(model.Name)
				gazeTimers[model] = 0
			end
		else
			-- Reset all gaze timers
			for obj, _ in pairs(gazeTimers) do
				gazeTimers[obj] = math.max(0, (gazeTimers[obj] or 0) - dt * 2)
			end
			local gazeWarning = hudFrame:FindFirstChild("GazeWarning")
			if gazeWarning then
				gazeWarning.Visible = false
			end
		end

		-- Check if looking at Saree Woman's face
		if model:GetAttribute("NPCType") == "SareeWoman" then
			local npcHead = model:FindFirstChild("Head")
			if npcHead and result.Instance == npcHead then
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
		end
		local gazeWarning = hudFrame:FindFirstChild("GazeWarning")
		if gazeWarning then
			gazeWarning.Visible = false
		end
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
			-- Interact with nearest interactable
		end
	elseif input.KeyCode == Enum.KeyCode.F then
		-- Grab batter from fridge (when near fridge)
		local character = player.Character
		if character then
			local fridge = workspace:FindFirstChild("Fridge")
			if fridge then
				local dist = (character.HumanoidRootPart.Position - fridge.Position).Magnitude
				if dist < 8 then
					Remotes:WaitForChild("GrabBatter"):FireServer()
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
				end
			end
		end
	elseif input.KeyCode == Enum.KeyCode.L then
		Remotes:WaitForChild("ToggleLights"):FireServer()
	elseif input.KeyCode == Enum.KeyCode.One then
		Remotes:WaitForChild("ToggleShutter"):FireServer("front")
	elseif input.KeyCode == Enum.KeyCode.Two then
		Remotes:WaitForChild("ToggleShutter"):FireServer("left")
	elseif input.KeyCode == Enum.KeyCode.Three then
		Remotes:WaitForChild("ToggleShutter"):FireServer("right")
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
	else
		-- Show menu selection UI
		menuFrame.Visible = true
	end
end

-- Connect to all proximity prompts
workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("ProximityPrompt") then
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
	deathFrame.Visible = false
	showNightStart(nightNum)
end)

Remotes:WaitForChild("EndNight").OnClientEvent:Connect(function(data)
	if data.survived then
		showFloatingText("NIGHT " .. data.night .. " SURVIVED!", Color3.fromRGB(0, 255, 0))
		task.wait(3)
		if data.nextNight and data.nextNight <= 5 then
			showFloatingText("Preparing Night " .. data.nextNight .. "...", Color3.fromRGB(255, 200, 0))
		end
	end
end)

Remotes:WaitForChild("PhoneRing").OnClientEvent:Connect(function()
	showPhone(true)
	local ringSound = SoundService:FindFirstChild("PhoneRing")
	if ringSound then ringSound:Play() end
end)

Remotes:WaitForChild("PhoneDialogue").OnClientEvent:Connect(function(text, lineNum, totalLines)
	showDialogue(text, lineNum, totalLines)
end)

Remotes:WaitForChild("PlayerDeath").OnClientEvent:Connect(function(data)
	showDeathScreen(data)
	Remotes:WaitForChild("RecordDeath"):FireServer()
end)

Remotes:WaitForChild("JumpScare").OnClientEvent:Connect(function(scareType)
	playJumpScare(scareType)
end)

Remotes:WaitForChild("NightComplete").OnClientEvent:Connect(function(result)
	if result == "victory" then
		-- Victory screen
		deathFrame.Visible = false
		nightStartFrame.Visible = true
		local titleLabel = nightStartFrame:FindFirstChild("TitleLabel")
		if titleLabel then
			titleLabel.Text = "YOU SURVIVED ALL 5 NIGHTS!"
			titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
			titleLabel.TextTransparency = 0
		end
		Remotes:WaitForChild("GameCompleted"):FireServer()
	end
end)

Remotes:WaitForChild("UpdateHUD").OnClientEvent:Connect(function(data)
	updateHUD(data)
end)

Remotes:WaitForChild("TriggerEvent").OnClientEvent:Connect(function(eventType, eventData)
	if eventType == "lights_flicker" then
		flickerLights(3)
	elseif eventType == "terrifier_truck" or eventType == "terrifier_truck_aggressive" then
		-- Truck appears outside
		showFloatingText("Something is outside...", Color3.fromRGB(255, 0, 0))
		if eventData.requiresShutters then
			showFloatingText("CLOSE THE SHUTTERS!", Color3.fromRGB(255, 0, 0))
		end
		-- Trigger truck arrival on server
		task.wait(2)
		if eventData.killIfOpen then
			Remotes:WaitForChild("TruckArrival"):FireServer()
		end
	elseif eventType == "naked_guy_throw" then
		showFloatingText("What the--?! Clean that up!", Color3.fromRGB(255, 150, 0))
	elseif eventType == "final_sequence" then
		showFloatingText("He's here... Suthan...", Color3.fromRGB(200, 0, 0))
	end
end)

Remotes:WaitForChild("SpawnNPC").OnClientEvent:Connect(function(npcType, npcModel, dialogue)
	-- Show NPC dialogue
	if dialogue then
		showFloatingText(dialogue, Color3.fromRGB(255, 255, 200))
	end
end)

Remotes:WaitForChild("NPCDialogue").OnClientEvent:Connect(function(npcType, dialogue)
	showFloatingText(dialogue, Color3.fromRGB(255, 255, 200))
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
		deathFrame.Visible = false
		Remotes:WaitForChild("RequestRetry"):FireServer()
	end)
end

-- Night start button (lobby)
local startBtn = mainUI:FindFirstChild("StartButton")
if startBtn then
	startBtn.MouseButton1Click:Connect(function()
		startBtn.Visible = false
		Remotes:WaitForChild("RequestStartNight"):FireServer()
	end)
end

-- Initialize CCTV
initCCTV()

print("[ClientController] Client initialized for " .. player.Name)
