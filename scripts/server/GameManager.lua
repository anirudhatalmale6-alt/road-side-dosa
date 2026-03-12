-- GameManager: Main server script controlling game flow and night progression
-- Location: ServerScriptService

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local NightData = require(ReplicatedStorage:WaitForChild("NightData"))

-- Remote Events
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local StartNightEvent = Remotes:WaitForChild("StartNight")
local EndNightEvent = Remotes:WaitForChild("EndNight")
local PhoneRingEvent = Remotes:WaitForChild("PhoneRing")
local PhoneDialogueEvent = Remotes:WaitForChild("PhoneDialogue")
local PlayerDeathEvent = Remotes:WaitForChild("PlayerDeath")
local NightCompleteEvent = Remotes:WaitForChild("NightComplete")
local TriggerEventRemote = Remotes:WaitForChild("TriggerEvent")
local UpdateHUDEvent = Remotes:WaitForChild("UpdateHUD")
local JumpScareEvent = Remotes:WaitForChild("JumpScare")

-- BindableEvent to notify NPCManager when a night starts
local NightStartBindable = ServerStorage:WaitForChild("NightStartBindable")

-- Game State
local GameState = {
	players = {}, -- [player] = {night, currency, alive, inventory}
	activeNight = {},  -- [player] = nightNumber
	nightTimers = {}, -- [player] = elapsed time
	nightActive = {} -- [player] = bool
}

-- Initialize player data
local function initPlayer(player)
	GameState.players[player] = {
		night = 1,
		currency = Config.STARTING_CURRENCY,
		alive = true,
		inventory = {},
		batter = 0,
		currentOrder = nil,
		shuttersOpen = {front = true, left = true, right = true},
		lightsOn = true,
		isCooking = false
	}
	GameState.activeNight[player] = 0
	GameState.nightActive[player] = false
end

-- Clean up player data
local function cleanupPlayer(player)
	GameState.players[player] = nil
	GameState.activeNight[player] = nil
	GameState.nightTimers[player] = nil
	GameState.nightActive[player] = nil
end

-- Set night atmosphere (progressively darker and more oppressive)
local function setNightAtmosphere(nightNum)
	local brightness = Config.AMBIENT_BRIGHTNESS - (nightNum * 0.04)
	Lighting.Brightness = math.max(brightness, 0.02)
	Lighting.ClockTime = 22 + (nightNum * 0.5) -- Gets later each night (22:00 → 00:30)
	Lighting.FogEnd = 200 - (nightNum * 30)
	Lighting.FogColor = Color3.fromRGB(10 - nightNum, 5 - nightNum, 15 - nightNum * 2)

	local atmosphere = Lighting:FindFirstChild("NightAtmosphere")
	if atmosphere then
		atmosphere.Density = 0.3 + (nightNum * 0.08)
		atmosphere.Glare = 0.05 + (nightNum * 0.03)
		atmosphere.Haze = 2 + (nightNum * 1.5)
	end

	-- Color correction gets more intense each night
	local colorEffect = Lighting:FindFirstChild("HorrorColor")
	if colorEffect then
		colorEffect.Contrast = 0.15 + (nightNum * 0.05)
		colorEffect.Saturation = -0.3 - (nightNum * 0.1)
		colorEffect.Brightness = -0.05 - (nightNum * 0.02)
	end

	-- Bloom intensifies
	local bloom = Lighting:FindFirstChild("HorrorBloom")
	if bloom then
		bloom.Intensity = 0.4 + (nightNum * 0.1)
	end
end

-- Start phone call sequence
local function startPhoneCall(player, nightNum)
	local nightInfo = NightData.Nights[nightNum]
	if not nightInfo then return end

	-- Ring the phone
	PhoneRingEvent:FireClient(player)
	task.wait(Config.PHONE_RING_DELAY)

	-- Deliver dialogue lines
	for i, line in ipairs(nightInfo.phoneDialogue) do
		if not GameState.nightActive[player] then break end
		PhoneDialogueEvent:FireClient(player, line, i, #nightInfo.phoneDialogue)
		-- Calculate wait time based on line length
		local waitTime = math.max(#line * NightData.PhoneConfig.dialogueSpeed, 1)
		waitTime = waitTime + NightData.PhoneConfig.dialoguePause
		task.wait(waitTime)
	end

	-- Close phone after all dialogue
	if GameState.nightActive[player] then
		Remotes:WaitForChild("PhoneDialogueEnd"):FireClient(player)
	end
end

-- Start a night for a player
local function startNight(player)
	local pData = GameState.players[player]
	if not pData then return end

	local nightNum = pData.night
	if nightNum > 5 then
		-- Player has completed all nights!
		NightCompleteEvent:FireClient(player, "victory")
		return
	end

	GameState.activeNight[player] = nightNum
	GameState.nightActive[player] = true
	GameState.nightTimers[player] = 0
	pData.alive = true
	pData.batter = 0
	pData.isCooking = false
	pData.shuttersOpen = {front = true, left = true, right = true}
	pData.lightsOn = true

	-- Set atmosphere
	setNightAtmosphere(nightNum)

	-- Reset shutters visually (all open = transparent)
	for _, shutterName in ipairs({"Shutter_front", "Shutter_left", "Shutter_right"}) do
		local shutterPart = workspace:FindFirstChild(shutterName)
		if shutterPart then
			shutterPart.Transparency = 0.8
		end
	end

	-- Reset lights
	for _, light in ipairs(workspace:GetDescendants()) do
		if (light:IsA("PointLight") or light:IsA("SpotLight")) then
			local ctrl = light:FindFirstChild("Controllable")
			if ctrl and ctrl:IsA("BoolValue") and ctrl.Value then
				light.Enabled = true
			end
		end
	end

	-- Notify client
	StartNightEvent:FireClient(player, nightNum, NightData.Nights[nightNum])
	UpdateHUDEvent:FireClient(player, {
		night = nightNum,
		currency = pData.currency,
		alive = true,
		menuItems = Config.MENU_UNLOCK[nightNum],
		lightsOn = true,
		shutters = pData.shuttersOpen
	})

	-- CRITICAL: Fire NightStartBindable to tell NPCManager to begin spawning NPCs
	NightStartBindable:Fire(player, nightNum)

	-- Start phone call in separate thread
	task.spawn(function()
		task.wait(2)
		startPhoneCall(player, nightNum)
	end)

	-- Play ambient horror sound
	local ambientSound = SoundService:FindFirstChild("AmbientHorror")
	if ambientSound then ambientSound:Play() end

	-- Night loop
	local eventsFired = {}
	while GameState.nightActive[player] and pData.alive do
		task.wait(1)

		if not GameState.nightActive[player] then break end

		GameState.nightTimers[player] = (GameState.nightTimers[player] or 0) + 1
		local elapsed = GameState.nightTimers[player]
		local progress = elapsed / Config.NIGHT_DURATION

		-- Process events
		local nightInfo = NightData.Nights[nightNum]
		if nightInfo and nightInfo.events then
			for idx, event in ipairs(nightInfo.events) do
				if event.triggerTime and progress >= event.triggerTime and not eventsFired[idx] then
					eventsFired[idx] = true
					if not event.probability or math.random() <= event.probability then
						TriggerEventRemote:FireClient(player, event.type, event)
					end
				end
			end
		end

		-- Check if night is over
		if elapsed >= Config.NIGHT_DURATION then
			GameState.nightActive[player] = false
			pData.night = nightNum + 1

			-- Stop ambient sound
			if ambientSound then ambientSound:Stop() end

			-- Night survived!
			EndNightEvent:FireClient(player, {
				survived = true,
				night = nightNum,
				currency = pData.currency,
				nextNight = pData.night
			})

			-- Sync to DataManager
			Remotes:WaitForChild("UpdateCurrency"):FireServer(pData.currency)
			Remotes:WaitForChild("UpdateNightProgress"):FireServer(pData.night)

			-- Play victory sound for surviving
			local victorySound = SoundService:FindFirstChild("VictorySound")
			if victorySound then victorySound:Play() end

			if pData.night > 5 then
				task.wait(3)
				NightCompleteEvent:FireClient(player, "victory")
			end
		end
	end

	-- Stop ambient on death/exit too
	if ambientSound then ambientSound:Stop() end
end

-- Handle player death
local function killPlayer(player, cause)
	local pData = GameState.players[player]
	if not pData or not pData.alive then return end

	pData.alive = false
	GameState.nightActive[player] = false

	-- Stop ambient sound
	local ambientSound = SoundService:FindFirstChild("AmbientHorror")
	if ambientSound then ambientSound:Stop() end

	-- Trigger death effects
	JumpScareEvent:FireClient(player, cause or "generic")
	task.wait(Config.JUMPSCARE_DURATION)

	PlayerDeathEvent:FireClient(player, {
		cause = cause,
		night = GameState.activeNight[player],
		currency = pData.currency
	})
end

-- Remote event handlers
Remotes:WaitForChild("RequestStartNight").OnServerEvent:Connect(function(player)
	task.spawn(function()
		startNight(player)
	end)
end)

Remotes:WaitForChild("RequestRetry").OnServerEvent:Connect(function(player)
	local pData = GameState.players[player]
	if pData then
		pData.alive = true
		task.spawn(function()
			startNight(player)
		end)
	end
end)

-- Continue from saved night progress
Remotes:WaitForChild("RequestContinueNight").OnServerEvent:Connect(function(player, savedNight)
	local pData = GameState.players[player]
	if pData and savedNight and savedNight > 1 and savedNight <= 5 then
		pData.night = savedNight
		pData.alive = true
		task.spawn(function()
			startNight(player)
		end)
	end
end)

-- Cooking events
Remotes:WaitForChild("GrabBatter").OnServerEvent:Connect(function(player)
	local pData = GameState.players[player]
	if not pData or not pData.alive then return end

	if pData.batter < Config.MAX_BATTER_CARRY then
		pData.batter = pData.batter + 1
		UpdateHUDEvent:FireClient(player, {batter = pData.batter})
	end
end)

Remotes:WaitForChild("CookDosa").OnServerEvent:Connect(function(player)
	local pData = GameState.players[player]
	if not pData or not pData.alive then return end
	if pData.isCooking then return end -- Prevent double-cooking

	if pData.batter > 0 then
		pData.isCooking = true
		pData.batter = pData.batter - 1
		UpdateHUDEvent:FireClient(player, {batter = pData.batter, cookingStarted = true})
		-- Cooking takes time
		task.wait(Config.COOKING_TIME)
		pData.isCooking = false
		if pData.alive then
			UpdateHUDEvent:FireClient(player, {
				batter = pData.batter,
				dosaReady = true
			})
		end
	end
end)

Remotes:WaitForChild("ServeCustomer").OnServerEvent:Connect(function(player, npcId, itemName)
	local pData = GameState.players[player]
	if not pData or not pData.alive then return end

	local nightNum = GameState.activeNight[player]
	local nightInfo = NightData.Nights[nightNum]
	if not nightInfo then return end

	-- Check rules for this NPC
	local ruleViolated = false
	for _, rule in ipairs(nightInfo.rules or {}) do
		if rule.npcType == npcId then
			if rule.wrongItem and itemName == rule.wrongItem then
				ruleViolated = true
				if rule.consequence == "jumpscare" then
					killPlayer(player, "wrong_order_" .. npcId)
				elseif rule.consequence == "jumpscare_death" then
					killPlayer(player, "fatal_" .. npcId)
				end
				break
			elseif rule.correctAction == "ignore" then
				-- Should not have served at all
				ruleViolated = true
				killPlayer(player, "should_not_serve_" .. npcId)
				break
			end
		end
	end

	if not ruleViolated then
		-- Successful serve
		pData.currency = pData.currency + Config.CURRENCY_PER_SALE
		UpdateHUDEvent:FireClient(player, {
			currency = pData.currency,
			serveSuccess = true,
			npcId = npcId
		})
		-- Sync to DataManager
		Remotes:WaitForChild("RecordServe"):FireServer(itemName)
	end
end)

-- Defense events
Remotes:WaitForChild("ToggleShutter").OnServerEvent:Connect(function(player, shutterName)
	local pData = GameState.players[player]
	if not pData or not pData.alive then return end

	if pData.shuttersOpen[shutterName] ~= nil then
		pData.shuttersOpen[shutterName] = not pData.shuttersOpen[shutterName]
		UpdateHUDEvent:FireClient(player, {shutters = pData.shuttersOpen})

		-- Replicate shutter state to workspace
		-- Shutters are direct children of workspace: Shutter_front, Shutter_left, Shutter_right
		local shutterPart = workspace:FindFirstChild("Shutter_" .. shutterName)
		if shutterPart then
			shutterPart.Transparency = pData.shuttersOpen[shutterName] and 0.8 or 0
		end
	end
end)

Remotes:WaitForChild("ToggleLights").OnServerEvent:Connect(function(player)
	local pData = GameState.players[player]
	if not pData or not pData.alive then return end

	pData.lightsOn = not pData.lightsOn
	UpdateHUDEvent:FireClient(player, {lightsOn = pData.lightsOn})

	-- Update actual lights in workspace (using BoolValue children instead of attributes)
	for _, light in ipairs(workspace:GetDescendants()) do
		if light:IsA("PointLight") or light:IsA("SpotLight") then
			local ctrl = light:FindFirstChild("Controllable")
			if ctrl and ctrl:IsA("BoolValue") and ctrl.Value then
				light.Enabled = pData.lightsOn
			end
		end
	end
end)

-- Gaze death (client reports looking at cursed object too long)
Remotes:WaitForChild("GazeDeath").OnServerEvent:Connect(function(player, objectName)
	killPlayer(player, "gaze_" .. (objectName or "unknown"))
end)

-- Shutter check for truck event
Remotes:WaitForChild("TruckArrival").OnServerEvent:Connect(function(player)
	local pData = GameState.players[player]
	if not pData or not pData.alive then return end

	-- Check if any shutters are open
	local anyOpen = false
	for name, isOpen in pairs(pData.shuttersOpen) do
		if isOpen then
			anyOpen = true
			break
		end
	end

	if anyOpen then
		task.wait(3) -- Give player a moment
		-- Re-check all shutters
		for name, isOpen in pairs(pData.shuttersOpen) do
			if isOpen then
				killPlayer(player, "truck_open_shutter")
				return
			end
		end
	end
end)

-- Night 5 special: Spill batter on Suthan
Remotes:WaitForChild("SpillBatter").OnServerEvent:Connect(function(player)
	local pData = GameState.players[player]
	if not pData or not pData.alive then return end

	if GameState.activeNight[player] == 5 and pData.batter > 0 then
		pData.batter = 0
		UpdateHUDEvent:FireClient(player, {batterSpilled = true})

		-- Player must now turn off lights and run
		-- Start a timer - they have 5 seconds
		task.spawn(function()
			task.wait(5)
			if pData.alive and pData.lightsOn then
				killPlayer(player, "suthan_lights_on")
			end
		end)
	end
end)

-- Night 5: Check if player reached safe room
Remotes:WaitForChild("ReachedSafeRoom").OnServerEvent:Connect(function(player)
	local pData = GameState.players[player]
	if not pData or not pData.alive then return end

	if GameState.activeNight[player] == 5 then
		-- Victory!
		GameState.nightActive[player] = false
		pData.night = 6
		NightCompleteEvent:FireClient(player, "victory")

		-- Play victory sound
		local victorySound = SoundService:FindFirstChild("VictorySound")
		if victorySound then victorySound:Play() end
	end
end)

-- Naked guy cleanup (Night 2)
Remotes:WaitForChild("CleanMess").OnServerEvent:Connect(function(player)
	local pData = GameState.players[player]
	if not pData or not pData.alive then return end

	UpdateHUDEvent:FireClient(player, {messCleared = true})
end)

-- Saree Woman gaze check
Remotes:WaitForChild("LookedAtFace").OnServerEvent:Connect(function(player, npcType)
	if npcType == "SareeWoman" then
		killPlayer(player, "saree_woman_gaze")
	end
end)

-- Player connections
Players.PlayerAdded:Connect(function(player)
	initPlayer(player)

	player.CharacterAdded:Connect(function(character)
		local pData = GameState.players[player]
		if pData then
			pData.alive = true
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	GameState.nightActive[player] = false -- Stop any running night loop
	cleanupPlayer(player)
end)

print("[GameManager] Road Side Dosa - Game Manager initialized")
