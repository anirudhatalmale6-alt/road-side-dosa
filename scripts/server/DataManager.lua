-- DataManager: Server script for DataStore saving/loading, leaderboard, and trading
-- Location: ServerScriptService

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- DataStores
local PlayerDataStore = DataStoreService:GetDataStore(Config.DATASTORE_NAME)
local LeaderboardStore = DataStoreService:GetOrderedDataStore(Config.LEADERBOARD_NAME)

-- Cached player data
local PlayerCache = {}

-- Default data template
local function getDefaultData()
	return {
		currency = Config.STARTING_CURRENCY,
		nightProgress = 1,
		totalEarnings = 0,
		gamesCompleted = 0,
		deaths = 0,
		inventory = {},
		gamePasses = {},
		stats = {
			dosasServed = 0,
			sodasServed = 0,
			ayransServed = 0,
			jumpscaresReceived = 0,
			nightsSurvived = 0
		}
	}
end

-- Load player data
local function loadPlayerData(player)
	local key = "Player_" .. player.UserId
	local success, data = pcall(function()
		return PlayerDataStore:GetAsync(key)
	end)

	if success and data then
		-- Merge with defaults in case of new fields
		local defaults = getDefaultData()
		for k, v in pairs(defaults) do
			if data[k] == nil then
				data[k] = v
			end
		end
		PlayerCache[player] = data
	else
		PlayerCache[player] = getDefaultData()
	end

	return PlayerCache[player]
end

-- Save player data
local function savePlayerData(player)
	local data = PlayerCache[player]
	if not data then return end

	local key = "Player_" .. player.UserId
	local success, err = pcall(function()
		PlayerDataStore:SetAsync(key, data)
	end)

	if not success then
		warn("[DataManager] Failed to save data for " .. player.Name .. ": " .. tostring(err))
	end
end

-- Update leaderboard
local function updateLeaderboard(player)
	local data = PlayerCache[player]
	if not data then return end

	local success, err = pcall(function()
		LeaderboardStore:SetAsync("Player_" .. player.UserId, data.totalEarnings)
	end)

	if not success then
		warn("[DataManager] Failed to update leaderboard: " .. tostring(err))
	end
end

-- Create leaderboard display
local function refreshLeaderboardDisplay()
	local success, pages = pcall(function()
		return LeaderboardStore:GetSortedAsync(false, Config.MAX_LEADERBOARD)
	end)

	if success then
		local topPage = pages:GetCurrentPage()
		-- Fire to all clients
		local leaderboardData = {}
		for rank, entry in ipairs(topPage) do
			table.insert(leaderboardData, {
				rank = rank,
				key = entry.key,
				value = entry.value
			})
		end
		Remotes:WaitForChild("UpdateLeaderboard"):FireAllClients(leaderboardData)
	end
end

-- Player connections
Players.PlayerAdded:Connect(function(player)
	local data = loadPlayerData(player)

	-- Create leaderstats
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local currency = Instance.new("IntValue")
	currency.Name = "Cash"
	currency.Value = data.currency
	currency.Parent = leaderstats

	local night = Instance.new("IntValue")
	night.Name = "Night"
	night.Value = data.nightProgress
	night.Parent = leaderstats

	-- Send saved data to client (including night progress for continue button)
	Remotes:WaitForChild("LoadPlayerData"):FireClient(player, data)

	-- Notify client of saved progress so they can show Continue button
	if data.nightProgress and data.nightProgress > 1 then
		Remotes:WaitForChild("SavedProgressLoaded"):FireClient(player, data.nightProgress)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	savePlayerData(player)
	updateLeaderboard(player)
	PlayerCache[player] = nil
end)

-- Auto-save every 60 seconds
task.spawn(function()
	while true do
		task.wait(60)
		for player, _ in pairs(PlayerCache) do
			if player.Parent then -- Still in game
				savePlayerData(player)
			end
		end
	end
end)

-- Refresh leaderboard every 30 seconds
task.spawn(function()
	while true do
		task.wait(30)
		refreshLeaderboardDisplay()
	end
end)

-- Remote handlers for data updates
Remotes:WaitForChild("UpdateCurrency").OnServerEvent:Connect(function(player, amount)
	local data = PlayerCache[player]
	if not data then return end

	data.currency = data.currency + amount
	data.totalEarnings = data.totalEarnings + math.max(0, amount)

	-- Update leaderstats
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local cash = leaderstats:FindFirstChild("Cash")
		if cash then cash.Value = data.currency end
	end
end)

Remotes:WaitForChild("UpdateNightProgress").OnServerEvent:Connect(function(player, nightNum)
	local data = PlayerCache[player]
	if not data then return end

	if nightNum > data.nightProgress then
		data.nightProgress = nightNum
		data.stats.nightsSurvived = data.stats.nightsSurvived + 1

		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			local night = leaderstats:FindFirstChild("Night")
			if night then night.Value = nightNum end
		end
	end
end)

Remotes:WaitForChild("RecordDeath").OnServerEvent:Connect(function(player)
	local data = PlayerCache[player]
	if data then
		data.deaths = data.deaths + 1
	end
end)

Remotes:WaitForChild("RecordServe").OnServerEvent:Connect(function(player, itemType)
	local data = PlayerCache[player]
	if not data then return end

	if itemType == "Dosa" then
		data.stats.dosasServed = data.stats.dosasServed + 1
	elseif itemType == "Soda" then
		data.stats.sodasServed = data.stats.sodasServed + 1
	elseif itemType == "Ayran" then
		data.stats.ayransServed = data.stats.ayransServed + 1
	end
end)

-- Trading system
Remotes:WaitForChild("TradeRequest").OnServerEvent:Connect(function(sender, targetPlayer, offerItem, requestItem)
	if not targetPlayer or not targetPlayer.Parent then return end

	local senderData = PlayerCache[sender]
	local targetData = PlayerCache[targetPlayer]
	if not senderData or not targetData then return end

	-- Check sender has the item
	local hasItem = false
	for i, item in ipairs(senderData.inventory) do
		if item == offerItem then
			hasItem = true
			break
		end
	end

	if not hasItem then return end

	-- Send trade request to target
	Remotes:WaitForChild("TradeRequestReceived"):FireClient(targetPlayer, sender, offerItem, requestItem)
end)

Remotes:WaitForChild("TradeAccept").OnServerEvent:Connect(function(accepter, sender, offerItem, requestItem)
	local senderData = PlayerCache[sender]
	local accepterData = PlayerCache[accepter]
	if not senderData or not accepterData then return end

	-- Verify both have items
	local senderHas, accepterHas = false, false
	local senderIdx, accepterIdx

	for i, item in ipairs(senderData.inventory) do
		if item == offerItem then
			senderHas = true
			senderIdx = i
			break
		end
	end

	for i, item in ipairs(accepterData.inventory) do
		if item == requestItem then
			accepterHas = true
			accepterIdx = i
			break
		end
	end

	if senderHas and accepterHas then
		-- Swap items
		senderData.inventory[senderIdx] = requestItem
		accepterData.inventory[accepterIdx] = offerItem

		Remotes:WaitForChild("TradeComplete"):FireClient(sender, true, requestItem)
		Remotes:WaitForChild("TradeComplete"):FireClient(accepter, true, offerItem)
	end
end)

-- Game completion
Remotes:WaitForChild("GameCompleted").OnServerEvent:Connect(function(player)
	local data = PlayerCache[player]
	if data then
		data.gamesCompleted = data.gamesCompleted + 1
		savePlayerData(player)
		updateLeaderboard(player)
	end
end)

print("[DataManager] Data system initialized")
