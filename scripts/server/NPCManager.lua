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

-- Random face decal IDs (Roblox default faces)
-- These are built-in Roblox face asset IDs
local RandomFaces = {
	"rbxasset://textures/face.png",              -- Default smile
	"rbxassetid://7699174",                       -- Worried
	"rbxassetid://7699174",                       -- Chill
	"rbxassetid://163348489",                     -- Skeptic
	"rbxassetid://31117192",                      -- Friendly
}

-- Random shirt colors for normal NPCs
local RandomShirtColors = {
	BrickColor.new("Bright blue"),
	BrickColor.new("Bright green"),
	BrickColor.new("Bright orange"),
	BrickColor.new("Bright violet"),
	BrickColor.new("Dusty Rose"),
	BrickColor.new("Teal"),
	BrickColor.new("Brick yellow"),
	BrickColor.new("Medium stone grey"),
}

-- Random skin tones
local SkinTones = {
	BrickColor.new("Light orange"),
	BrickColor.new("Nougat"),
	BrickColor.new("Reddish brown"),
	BrickColor.new("Brown"),
	BrickColor.new("Brick yellow"),
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

	-- Apply random face to all NPCs (except special ones handled below)
	local function addFace(headPart, faceId)
		local face = Instance.new("Decal")
		face.Name = "face"
		face.Texture = faceId or RandomFaces[math.random(1, #RandomFaces)]
		face.Face = Enum.NormalId.Front
		face.Parent = headPart
	end

	-- Apply random skin tone
	local function applySkinTone(parts)
		local tone = SkinTones[math.random(1, #SkinTones)]
		for _, p in ipairs(parts) do
			p.BrickColor = tone
		end
	end

	-- Add arms and legs for more realistic look
	local leftArm = Instance.new("Part")
	leftArm.Name = "Left Arm"
	leftArm.Size = Vector3.new(0.6, 2, 0.6)
	leftArm.Anchored = false
	leftArm.CanCollide = false
	leftArm.Parent = model

	local rightArm = Instance.new("Part")
	rightArm.Name = "Right Arm"
	rightArm.Size = Vector3.new(0.6, 2, 0.6)
	rightArm.Anchored = false
	rightArm.CanCollide = false
	rightArm.Parent = model

	local leftLeg = Instance.new("Part")
	leftLeg.Name = "Left Leg"
	leftLeg.Size = Vector3.new(0.6, 2, 0.6)
	leftLeg.Anchored = false
	leftLeg.CanCollide = false
	leftLeg.Parent = model

	local rightLeg = Instance.new("Part")
	rightLeg.Name = "Right Leg"
	rightLeg.Size = Vector3.new(0.6, 2, 0.6)
	rightLeg.Anchored = false
	rightLeg.CanCollide = false
	rightLeg.Parent = model

	-- Color based on type
	if npcType == "ChineseGuy" then
		torso.BrickColor = BrickColor.new("Bright red")
		local skinTone = SkinTones[math.random(1, #SkinTones)]
		head.BrickColor = skinTone
		leftArm.BrickColor = skinTone
		rightArm.BrickColor = skinTone
		leftLeg.BrickColor = BrickColor.new("Dark blue")
		rightLeg.BrickColor = BrickColor.new("Dark blue")
		addFace(head)
		-- Add conical hat
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
		head.BrickColor = BrickColor.new("Nougat")
		leftArm.BrickColor = BrickColor.new("Nougat")
		rightArm.BrickColor = BrickColor.new("Nougat")
		leftLeg.BrickColor = BrickColor.new("Magenta")
		rightLeg.BrickColor = BrickColor.new("Magenta")
		-- Dark horrifying face (don't look!)
		local face = Instance.new("Decal")
		face.Name = "face"
		face.Color3 = Color3.fromRGB(0, 0, 0)
		face.Transparency = 0.5
		face.Face = Enum.NormalId.Front
		face.Parent = head
		-- Saree drape over head
		local drape = Instance.new("Part")
		drape.Name = "SareeDrape"
		drape.Size = Vector3.new(1.4, 0.8, 1.4)
		drape.BrickColor = BrickColor.new("Magenta")
		drape.Transparency = 0.3
		drape.CanCollide = false
		drape.Anchored = false
		drape.Parent = model
		local drapeWeld = Instance.new("WeldConstraint")
		drapeWeld.Part0 = head
		drapeWeld.Part1 = drape
		drapeWeld.Parent = drape

	elseif npcType == "DancingGuy" then
		torso.BrickColor = BrickColor.new("Lime green")
		local skinTone = SkinTones[math.random(1, #SkinTones)]
		head.BrickColor = skinTone
		leftArm.BrickColor = skinTone
		rightArm.BrickColor = skinTone
		leftLeg.BrickColor = BrickColor.new("Earth green")
		rightLeg.BrickColor = BrickColor.new("Earth green")
		addFace(head)

	elseif npcType == "Suthan" then
		-- Based on reference photo: dark hair, Indian skin tone, white striped shirt
		local suthanSkin = BrickColor.new("Nougat")
		head.BrickColor = suthanSkin
		leftArm.BrickColor = suthanSkin
		rightArm.BrickColor = suthanSkin
		-- White striped shirt
		torso.BrickColor = BrickColor.new("Institutional white")
		leftLeg.BrickColor = BrickColor.new("Dark stone grey") -- dark pants
		rightLeg.BrickColor = BrickColor.new("Dark stone grey")

		-- Styled dark hair (swept up)
		local hair = Instance.new("Part")
		hair.Name = "Hair"
		hair.Size = Vector3.new(1.3, 0.5, 1.3)
		hair.BrickColor = BrickColor.new("Really black")
		hair.CanCollide = false
		hair.Anchored = false
		hair.Parent = model
		local hairWeld = Instance.new("WeldConstraint")
		hairWeld.Part0 = head
		hairWeld.Part1 = hair
		hairWeld.Parent = hair
		-- Hair front sweep
		local hairFront = Instance.new("Part")
		hairFront.Name = "HairFront"
		hairFront.Size = Vector3.new(0.8, 0.4, 0.3)
		hairFront.BrickColor = BrickColor.new("Really black")
		hairFront.CanCollide = false
		hairFront.Anchored = false
		hairFront.Parent = model
		local hairFrontWeld = Instance.new("WeldConstraint")
		hairFrontWeld.Part0 = head
		hairFrontWeld.Part1 = hairFront
		hairFrontWeld.Parent = hairFront

		-- Menacing face for Suthan
		addFace(head, "rbxasset://textures/face.png")

		-- Shirt stripe details (billboard)
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "ShirtLabel"
		billboard.Size = UDim2.new(3, 0, 1.5, 0)
		billboard.StudsOffset = Vector3.new(0, 0, -0.6)
		billboard.Adornee = torso
		billboard.AlwaysOnTop = false
		billboard.Parent = torso
		local label = Instance.new("TextLabel")
		label.Text = "SUTHAN"
		label.Size = UDim2.new(1, 0, 0.5, 0)
		label.Position = UDim2.new(0, 0, 0.25, 0)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.fromRGB(200, 0, 0)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.TextStrokeTransparency = 0.5
		label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		label.Parent = billboard

		-- NOTE: To use the actual reference photo as Suthan's face:
		-- 1. Upload the photo to Roblox as a Decal (Create > Decals on roblox.com)
		-- 2. Copy the asset ID
		-- 3. Replace the face Decal's Texture with "rbxassetid://YOUR_ID_HERE"

	elseif npcType == "NakedGuy" then
		local skinTone = BrickColor.new("Light orange")
		head.BrickColor = skinTone
		torso.BrickColor = skinTone
		leftArm.BrickColor = skinTone
		rightArm.BrickColor = skinTone
		leftLeg.BrickColor = skinTone
		rightLeg.BrickColor = skinTone
		addFace(head)

	else
		-- Normal customer - random appearance
		local skinTone = SkinTones[math.random(1, #SkinTones)]
		head.BrickColor = skinTone
		leftArm.BrickColor = skinTone
		rightArm.BrickColor = skinTone
		torso.BrickColor = RandomShirtColors[math.random(1, #RandomShirtColors)]
		local pantColor = ({BrickColor.new("Dark blue"), BrickColor.new("Dark stone grey"),
			BrickColor.new("Brown"), BrickColor.new("Black")})[math.random(1, 4)]
		leftLeg.BrickColor = pantColor
		rightLeg.BrickColor = pantColor
		addFace(head)
	end

	-- Weld arms and legs to torso
	for _, limbPart in ipairs({leftArm, rightArm, leftLeg, rightLeg}) do
		local limbWeld = Instance.new("WeldConstraint")
		limbWeld.Part0 = torso
		limbWeld.Part1 = limbPart
		limbWeld.Parent = limbPart
	end

	-- Position limbs relative to torso
	leftArm.Position = torso.Position + Vector3.new(-1.3, 0, 0)
	rightArm.Position = torso.Position + Vector3.new(1.3, 0, 0)
	leftLeg.Position = torso.Position + Vector3.new(-0.5, -2, 0)
	rightLeg.Position = torso.Position + Vector3.new(0.5, -2, 0)

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
