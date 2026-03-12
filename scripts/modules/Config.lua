-- Config Module: All game configuration values
local Config = {}

-- Currency
Config.CURRENCY_PER_SALE = 150
Config.STARTING_CURRENCY = 0

-- Night timing (seconds)
Config.NIGHT_DURATION = 300 -- 5 minutes per night
Config.PHONE_RING_DELAY = 5 -- seconds before phone rings at night start
Config.NPC_SPAWN_INTERVAL = 20 -- seconds between NPC spawns
Config.SERVING_TIMEOUT = 30 -- seconds to serve before NPC leaves angry

-- Cooking
Config.COOKING_TIME = 4 -- seconds on tawa
Config.BATTER_PER_DOSA = 1
Config.MAX_BATTER_CARRY = 5

-- Defense
Config.GAZE_DEATH_TIME = 5 -- seconds looking at cursed object = death
Config.SHUTTER_CLOSE_TIME = 1.5 -- seconds to close shutter
Config.CCTV_SWITCH_TIME = 0.5

-- Lighting
Config.AMBIENT_BRIGHTNESS = 0.3
Config.FLICKER_MIN = 0.1
Config.FLICKER_MAX = 0.4
Config.FLICKER_SPEED = 0.3

-- Jump Scare
Config.JUMPSCARE_DURATION = 1.5
Config.SCREEN_SHAKE_INTENSITY = 10
Config.DEATH_FADE_TIME = 2

-- Stamina
Config.MAX_STAMINA = 100
Config.SPRINT_DRAIN = 20 -- per second
Config.STAMINA_REGEN = 10 -- per second when not sprinting
Config.SPRINT_SPEED_MULT = 1.6

-- DataStore
Config.DATASTORE_NAME = "RoadSideDosaData"
Config.LEADERBOARD_NAME = "TopChefs"
Config.MAX_LEADERBOARD = 100

-- GamePass IDs (placeholder - client sets real ones)
Config.GAMEPASS_ANOMALY_IDENTIFIER = 0
Config.GAMEPASS_JUMPSCARE_FRIEND = 0
Config.GAMEPASS_GUN = 0
Config.GAMEPASS_HUMANITY_SERUM = 0

-- GamePass Prices (for reference)
Config.PRICE_ANOMALY_IDENTIFIER = 250
Config.PRICE_JUMPSCARE_FRIEND = 100
Config.PRICE_GUN = 350
Config.PRICE_HUMANITY_SERUM = 500

-- NPC Types
Config.NPC_TYPES = {
	CHINESE_GUY = "ChineseGuy",
	SAREE_WOMAN = "SareeWoman",
	DANCING_GUY = "DancingGuy",
	SUTHAN = "Suthan",
	NORMAL = "NormalCustomer",
	NAKED_GUY = "NakedGuy"
}

-- Menu Items
Config.MENU_ITEMS = {
	DOSA = "Dosa",
	SODA = "Soda",
	AYRAN = "Ayran",
	SOOTHU_DOSAI = "SoothuDosai"
}

-- Night unlock schedule for menu items
Config.MENU_UNLOCK = {
	[1] = {"Dosa", "Soda"},
	[2] = {"Dosa", "Soda"},
	[3] = {"Dosa", "Soda", "Ayran"},
	[4] = {"Dosa", "Soda", "Ayran"},
	[5] = {"Dosa", "Soda", "Ayran", "SoothuDosai"}
}

return Config
