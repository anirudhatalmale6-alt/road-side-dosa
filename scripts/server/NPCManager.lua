-- NPCManager: Server script for NPC spawning, AI, and behavior
-- Location: ServerScriptService

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local NightData = require(ReplicatedStorage:WaitForChild("NightData"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SpawnNPCEvent = Remotes:WaitForChild("SpawnNPC")
local NPCDialogueEvent = Remotes:WaitForChild("NPCDialogue")
local NPCLeaveEvent = Remotes:WaitForChild("NPCLeave")
local TriggerEventRemote = Remotes:WaitForChild("TriggerEvent")

-- NPC Templates
local NPCTemplates = {
	NormalCustomer = {
		name = "Customer",
		walkSpeed = 8,
		dialogue = {
			enter = {"Hello! I'd like to order please.", "Hi there! What's on the menu?", "Evening! One dosa please."},
			served = {"Thank you! Delicious!", "Great, thanks!", "Mmm, perfect!"},
			angry = {"I've been waiting too long!", "Forget it, I'm leaving!", "Terrible service!"}
		},
		orderItems = {"Dosa"},
		isAnomaly = false
	},
	ChineseGuy = {
		name = "Chinese Hat Man",
		walkSpeed = 6,
		dialogue = {
			enter = {"*adjusts hat* I'll have something to eat.", "Good evening. What do you recommend?"},
			served_correct = {"*nods approvingly* Good. Very good.", "Perfect choice. Thank you."},
			served_wrong = {"*eyes go wide* You... shouldn't have done that..."},
			angry = {"*slowly backs away*"}
		},
		orderItems = {"Dosa", "Soda"}, -- Will ask for either, but rule says serve ONLY soda
		isAnomaly = true,
		anomalyType = "rule_based"
	},
	SareeWoman = {
		name = "Saree Woman",
		walkSpeed = 4,
		dialogue = {
			enter = {"*speaks softly* Hello, dear. I'll have whatever you recommend."},
			served = {"*whispers* Thank you... don't look up..."},
			looked = {"*SCREAMING* YOU LOOKED AT ME!"}
		},
		orderItems = {"Dosa", "Ayran"},
		isAnomaly = true,
		anomalyType = "gaze_based",
		triggersFlicker = true
	},
	DancingGuy = {
		name = "Dancing Man",
		walkSpeed = 10,
		dialogue = {
			enter = {"*dancing* Hey hey hey! Give me some food, brother!",
					 "*twirling* Come on, serve me! I'm hungry!",
					 "*moonwalking* Don't be shy, just give me a dosa!"},
			ignored = {"*dances more aggressively* COME ON! SERVE ME!",
					   "*gets closer* Why won't you serve me?!"},
			leaves = {"*stops dancing* ...fine. *walks away normally*"}
		},
		orderItems = {"Dosa"},
		isAnomaly = true,
		anomalyType = "ignore_required",
		danceAnimation = true
	},
	Suthan = {
		name = "Suthan",
		walkSpeed = 5,
		dialogue = {
			enter = {"*sits down* I want Soothu Dosai.", "*stares* Make me Soothu Dosai. Now."},
			waiting = {"*tapping table impatiently*", "*eyes narrowing*"},
			batter_spilled = {"*ROARING* WHAT HAVE YOU DONE?!"},
			lights_off = {"*stumbling in darkness* WHERE ARE YOU?!"}
		},
		orderItems = {"SoothuDosai"},
		isAnomaly = true,
		anomalyType = "final_boss",
		shirtText = "Suthan"
	},
	NakedGuy = {
		name = "???",
		walkSpeed = 20,
		dialogue = {
			enter = {"*runs through screaming*"},
		},
		orderItems = {},
		isAnomaly = true,
		anomalyType = "random_event",
		throwsObject = true
	}
}

-- Active NPCs tracking
local activeNPCs = {} -- [npcModel] = {type, player, spawnTime}

-- NPC Spawn points
local function getSpawnPoint()
	local spawns = workspace:FindFirstChild("NPCSpawns")
	if spawns then
		local children = spawns:GetChildren()
		if #children > 0 then
			return children[math.random(1, #children)]
		end
	end
	-- Fallback spawn position (outside door)
	return CFrame.new(0, 3, -30)
end

-- Get counter position (where NPCs go to order)
local function getCounterPoint()
	local counter = workspace:FindFirstChild("CounterTarget")
	if counter then
		return counter.Position
	end
	return Vector3.new(0, 3, 0)
end

-- Create NPC model
local function createNPCModel(npcType, template)
	local model = Instance.new("Model")
	model.Name = "NPC_" .. npcType

	-- Create humanoid rig (simplified)
	local humanoidRootPart = Instance.new("Part")
	humanoidRootPart.Name = "HumanoidRootPart"
	humanoidRootPart.Size = Vector3.new(2, 2, 1)
	humanoidRootPart.Transparency = 1
	humanoidRootPart.CanCollide = false
	humanoidRootPart.Anchored = false
	humanoidRootPart.Parent = model

	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, 2, 1)
	torso.BrickColor = BrickColor.new("Bright yellow")
	torso.Anchored = false
	torso.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.2, 1.2, 1.2)
	head.Shape = Enum.PartType.Ball
	head.BrickColor = BrickColor.new("Bright yellow")
	head.Anchored = false
	head.Parent = model

	-- Color based on type
	if npcType == "ChineseGuy" then
		torso.BrickColor = BrickColor.new("Bright red")
		-- Add hat
		local hat = Instance.new("Part")
		hat.Name = "Hat"
		hat.Size = Vector3.new(1.5, 0.3, 1.5)
		hat.Shape = Enum.PartType.Cylinder
		hat.BrickColor = BrickColor.new("Brown")
		hat.Anchored = false
		hat.Parent = model
		local hatWeld = Instance.new("WeldConstraint")
		hatWeld.Part0 = head
		hatWeld.Part1 = hat
		hatWeld.Parent = hat
	elseif npcType == "SareeWoman" then
		torso.BrickColor = BrickColor.new("Magenta")
		head.BrickColor = BrickColor.new("Light orange")
		-- Dark face (don't look!)
		local face = Instance.new("Decal")
		face.Name = "Face"
		face.Color3 = Color3.fromRGB(0, 0, 0)
		face.Transparency = 0.5
		face.Face = Enum.NormalId.Front
		face.Parent = head
	elseif npcType == "DancingGuy" then
		torso.BrickColor = BrickColor.new("Lime green")
	elseif npcType == "Suthan" then
		torso.BrickColor = BrickColor.new("Dark stone grey")
		-- Billboard for shirt text
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "ShirtLabel"
		billboard.Size = UDim2.new(3, 0, 1, 0)
		billboard.StudsOffset = Vector3.new(0, 0, -1)
		billboard.Adornee = torso
		billboard.Parent = torso
		local label = Instance.new("TextLabel")
		label.Text = "SUTHAN"
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.fromRGB(255, 0, 0)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Parent = billboard
	elseif npcType == "NakedGuy" then
		torso.BrickColor = BrickColor.new("Light orange")
		head.BrickColor = BrickColor.new("Light orange")
	end

	-- Humanoid
	local humanoid = Instance.new("Humanoid")
	humanoid.WalkSpeed = template.walkSpeed
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.Parent = model

	-- Welds
	local rootWeld = Instance.new("WeldConstraint")
	rootWeld.Part0 = humanoidRootPart
	rootWeld.Part1 = torso
	rootWeld.Parent = humanoidRootPart

	local headWeld = Instance.new("WeldConstraint")
	headWeld.Part0 = torso
	headWeld.Part1 = head
	headWeld.Parent = torso

	head.Position = torso.Position + Vector3.new(0, 1.5, 0)
	humanoidRootPart.Position = torso.Position

	model.PrimaryPart = humanoidRootPart

	-- Proximity prompt for interaction
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ServePrompt"
	prompt.ActionText = "Serve"
	prompt.ObjectText = template.name
	prompt.MaxActivationDistance = 8
	prompt.HoldDuration = 0
	prompt.Parent = humanoidRootPart

	-- NPC type attribute
	model:SetAttribute("NPCType", npcType)
	model:SetAttribute("IsAnomaly", template.isAnomaly)

	return model
end

-- Spawn an NPC
local function spawnNPC(npcType, targetPlayer)
	local template = NPCTemplates[npcType]
	if not template then return end

	local model = createNPCModel(npcType, template)
	local spawnPoint = getSpawnPoint()

	if typeof(spawnPoint) == "CFrame" then
		model:SetPrimaryPartCFrame(spawnPoint)
	else
		model:SetPrimaryPartCFrame(spawnPoint.CFrame)
	end

	model.Parent = workspace:FindFirstChild("NPCs") or workspace

	activeNPCs[model] = {
		type = npcType,
		player = targetPlayer,
		spawnTime = tick(),
		template = template,
		state = "entering"
	}

	-- Notify client
	SpawnNPCEvent:FireClient(targetPlayer, npcType, model, template.dialogue.enter[math.random(1, #template.dialogue.enter)])

	-- NPC walks to counter
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:MoveTo(getCounterPoint())
	end

	-- Special behaviors
	if npcType == "SareeWoman" and template.triggersFlicker then
		TriggerEventRemote:FireClient(targetPlayer, "lights_flicker", {linkedNPC = "SareeWoman"})
	end

	if npcType == "NakedGuy" then
		-- Run through and throw something
		task.spawn(function()
			task.wait(2)
			TriggerEventRemote:FireClient(targetPlayer, "naked_guy_throw", {})
			task.wait(1)
			-- Leave
			if model and model.Parent then
				model:Destroy()
				activeNPCs[model] = nil
			end
		end)
	end

	-- Timeout - NPC leaves if not served
	if npcType ~= "NakedGuy" and npcType ~= "DancingGuy" then
		task.spawn(function()
			task.wait(Config.SERVING_TIMEOUT)
			if activeNPCs[model] then
				NPCLeaveEvent:FireClient(targetPlayer, npcType, "timeout")
				task.wait(3)
				if model and model.Parent then
					model:Destroy()
					activeNPCs[model] = nil
				end
			end
		end)
	end

	-- Dancing Guy special: leaves after ignoring for 20 seconds
	if npcType == "DancingGuy" then
		task.spawn(function()
			task.wait(20)
			if activeNPCs[model] then
				NPCDialogueEvent:FireClient(targetPlayer, npcType,
					template.dialogue.leaves[1])
				task.wait(3)
				if model and model.Parent then
					model:Destroy()
					activeNPCs[model] = nil
				end
			end
		end)
	end

	return model
end

-- NPC Spawning loop per player per night
local function nightNPCLoop(player, nightNum)
	local nightInfo = NightData.Nights[nightNum]
	if not nightInfo then return end

	local spawnCount = 0
	local maxSpawns = 3 + nightNum -- More NPCs on harder nights

	-- Spawn anomaly NPCs based on night rules
	local anomalySpawned = {}

	while GameState and GameState.nightActive and GameState.nightActive[player] do
		task.wait(Config.NPC_SPAWN_INTERVAL + math.random(-3, 5))

		if not GameState.nightActive[player] then break end
		if spawnCount >= maxSpawns then break end

		-- Decide what to spawn
		local npcType = "NormalCustomer"

		-- Check if we should spawn an anomaly
		for _, rule in ipairs(nightInfo.rules or {}) do
			if not anomalySpawned[rule.npcType] then
				-- Spawn anomaly NPC with higher chance as night progresses
				local elapsed = GameState.nightTimers[player] or 0
				local progress = elapsed / Config.NIGHT_DURATION
				if progress > 0.2 and math.random() < 0.5 then
					npcType = rule.npcType
					anomalySpawned[rule.npcType] = true
				end
			end
		end

		spawnNPC(npcType, player)
		spawnCount = spawnCount + 1
	end
end

-- Listen for night start to begin NPC spawning
Remotes:WaitForChild("StartNight").OnClientEvent = nil -- Server doesn't listen to OnClientEvent
-- Instead, we hook into the StartNight fire from GameManager by attribute

-- We use a BindableEvent to communicate between server scripts
local nightStartBindable = ServerStorage:FindFirstChild("NightStartBindable")
if not nightStartBindable then
	nightStartBindable = Instance.new("BindableEvent")
	nightStartBindable.Name = "NightStartBindable"
	nightStartBindable.Parent = ServerStorage
end

-- GameManager will fire this when a night starts
nightStartBindable.Event:Connect(function(player, nightNum)
	task.spawn(function()
		nightNPCLoop(player, nightNum)
	end)
end)

-- Also handle NPC interaction via proximity prompt
-- This is handled by client sending ServeCustomer remote

-- Clean up NPCs when night ends
Remotes:WaitForChild("EndNight").OnServerEvent:Connect(function(player)
	-- Remove all NPCs
	local npcsFolder = workspace:FindFirstChild("NPCs")
	if npcsFolder then
		for _, npc in ipairs(npcsFolder:GetChildren()) do
			if activeNPCs[npc] and activeNPCs[npc].player == player then
				npc:Destroy()
				activeNPCs[npc] = nil
			end
		end
	end
end)

print("[NPCManager] NPC system initialized")
