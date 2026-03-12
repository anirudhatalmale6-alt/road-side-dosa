-- GamePassManager: Handles gamepass purchases and effects
-- Location: ServerScriptService

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- Track owned gamepasses per player
local OwnedPasses = {} -- [player] = {passName = true}

-- Gamepass definitions
local GamePasses = {
	AnomalyIdentifier = {
		id = Config.GAMEPASS_ANOMALY_IDENTIFIER,
		name = "Anomaly Identifier",
		description = "Highlights ghosts on the CCTV camera",
		price = Config.PRICE_ANOMALY_IDENTIFIER
	},
	JumpscareFriend = {
		id = Config.GAMEPASS_JUMPSCARE_FRIEND,
		name = "Jumpscare Friend",
		description = "Remote trigger to prank another player",
		price = Config.PRICE_JUMPSCARE_FRIEND
	},
	TheGun = {
		id = Config.GAMEPASS_GUN,
		name = "The Gun",
		description = "Defensive weapon for Night 4 and 5",
		price = Config.PRICE_GUN
	},
	HumanitySerum = {
		id = Config.GAMEPASS_HUMANITY_SERUM,
		name = "Humanity Serum",
		description = "Turns an anomaly back into a human NPC",
		price = Config.PRICE_HUMANITY_SERUM
	}
}

-- Check if player owns a gamepass
local function playerOwnsPass(player, passId)
	if passId == 0 then return false end -- Placeholder ID

	local success, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)

	return success and owns
end

-- Grant gamepass effects
local function grantPassEffects(player, passName)
	if not OwnedPasses[player] then
		OwnedPasses[player] = {}
	end
	OwnedPasses[player][passName] = true

	-- Notify client of owned pass
	Remotes:WaitForChild("GamePassOwned"):FireClient(player, passName)
end

-- Initialize player gamepasses
local function initPlayerPasses(player)
	OwnedPasses[player] = {}

	for passName, passData in pairs(GamePasses) do
		if passData.id > 0 and playerOwnsPass(player, passData.id) then
			grantPassEffects(player, passName)
		end
	end
end

-- Handle gamepass purchase
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased then return end

	for passName, passData in pairs(GamePasses) do
		if passData.id == passId then
			grantPassEffects(player, passName)
			break
		end
	end
end)

-- Player connections
Players.PlayerAdded:Connect(function(player)
	task.spawn(function()
		initPlayerPasses(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	OwnedPasses[player] = nil
end)

-- Remote: Use Jumpscare Friend on another player
Remotes:WaitForChild("UseJumpscareFriend").OnServerEvent:Connect(function(player, targetPlayer)
	if not OwnedPasses[player] or not OwnedPasses[player]["JumpscareFriend"] then return end
	if not targetPlayer or not targetPlayer.Parent then return end

	Remotes:WaitForChild("JumpScare"):FireClient(targetPlayer, "friend_prank")
end)

-- Remote: Use Humanity Serum on an NPC
Remotes:WaitForChild("UseHumanitySerum").OnServerEvent:Connect(function(player, npcModel)
	if not OwnedPasses[player] or not OwnedPasses[player]["HumanitySerum"] then return end
	if not npcModel or not npcModel.Parent then return end

	-- Transform anomaly NPC to normal
	if npcModel:GetAttribute("IsAnomaly") then
		npcModel:SetAttribute("IsAnomaly", false)
		npcModel:SetAttribute("NPCType", "NormalCustomer")

		-- Visual change - make them look normal
		for _, part in ipairs(npcModel:GetDescendants()) do
			if part:IsA("BasePart") then
				part.BrickColor = BrickColor.new("Bright yellow")
			end
		end

		Remotes:WaitForChild("NPCTransformed"):FireClient(player, npcModel)
	end
end)

-- Remote: Check if player owns specific pass (client query)
Remotes:WaitForChild("CheckGamePass").OnServerEvent:Connect(function(player, passName)
	local owns = OwnedPasses[player] and OwnedPasses[player][passName] or false
	Remotes:WaitForChild("GamePassCheckResult"):FireClient(player, passName, owns)
end)

print("[GamePassManager] GamePass system initialized")
