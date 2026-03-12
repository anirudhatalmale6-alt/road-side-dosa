-- NightData Module: All 5 nights' rules, events, and phone dialogues
local NightData = {}

NightData.Nights = {
	[1] = {
		phoneDialogue = {
			"*ring ring*... *ring ring*...",
			"Hello? Ah, you must be the new guy.",
			"Welcome to Road Side Dosa. First night, easy shift.",
			"We just added Soda to the menu. Customers love it.",
			"Now listen carefully...",
			"If a man wearing a Chinese hat comes in...",
			"Serve him ONLY Soda. Do NOT give him Dosa.",
			"Trust me on this. Just Soda. Nothing else.",
			"Good luck. I'll call again tomorrow."
		},
		menuItems = {"Dosa", "Soda"},
		rules = {
			{
				npcType = "ChineseGuy",
				description = "Serve ONLY Soda to Chinese Guy. Do NOT serve Dosa.",
				correctItem = "Soda",
				wrongItem = "Dosa",
				consequence = "jumpscare" -- wrong order triggers scare
			}
		},
		events = {},
		anomalies = {},
		difficulty = 1
	},

	[2] = {
		phoneDialogue = {
			"*ring ring*...",
			"Hey, it's me again. You survived night one, good.",
			"We've got a new dosa flavor tonight. Business is picking up.",
			"But I need to warn you about something...",
			"There's a truck that parks outside sometimes.",
			"The Terrifier Truck. It looks like an ice cream van but... wrong.",
			"Whatever you do, DO NOT look at it for more than 5 seconds.",
			"Use the CCTV if you need to check outside, but don't stare.",
			"Oh, and one more thing...",
			"Sometimes a... strange man runs through. Naked. Throws things.",
			"Just clean up after him. Don't engage.",
			"Stay safe tonight."
		},
		menuItems = {"Dosa", "Soda"},
		rules = {},
		events = {
			{
				type = "terrifier_truck",
				description = "Terrifier Truck appears outside. Don't gaze >5 seconds.",
				triggerTime = 0.3, -- 30% through the night
				gazeKill = true
			},
			{
				type = "naked_guy",
				description = "Naked guy runs in, throws something, runs away. Clean it up.",
				triggerTime = 0.6,
				probability = 0.7, -- might happen
				requiresCleanup = true
			}
		},
		anomalies = {"TerrifierTruck"},
		difficulty = 2
	},

	[3] = {
		phoneDialogue = {
			"*ring ring*...",
			"Night three. You're tougher than I thought.",
			"We're adding Ayran to the menu tonight. Yogurt drink.",
			"Customers are going to love it.",
			"But there's a woman who comes in sometimes...",
			"She wears a saree. Very polite. Will order normally.",
			"Serve her whatever she asks for...",
			"But do NOT look at her face. Do NOT look at her eyes.",
			"Keep your gaze down when she's at the counter.",
			"I can't explain why. Just... don't look.",
			"You'll know when she's there. The lights flicker.",
			"Good luck."
		},
		menuItems = {"Dosa", "Soda", "Ayran"},
		rules = {
			{
				npcType = "SareeWoman",
				description = "Serve her, but do NOT look at her face/eyes.",
				correctAction = "serve_no_look",
				consequence = "jumpscare_death" -- looking triggers fatal scare
			}
		},
		events = {
			{
				type = "lights_flicker",
				description = "Lights flicker when Saree Woman arrives",
				linkedNPC = "SareeWoman"
			}
		},
		anomalies = {"SareeWoman", "TerrifierTruck"},
		difficulty = 3
	},

	[4] = {
		phoneDialogue = {
			"*ring ring*...",
			"Night four. Almost there.",
			"New flavor again tonight. The regulars are excited.",
			"Listen... there's a man who comes in dancing.",
			"He'll dance and ask you to serve him. DO NOT serve him.",
			"I don't care how much he begs. Ignore him completely.",
			"And the Terrifier Truck is back tonight...",
			"This time it's more aggressive. When you see it...",
			"CLOSE ALL THE WINDOWS. Use the shutters. Immediately.",
			"If the windows are open when it arrives... well...",
			"Just close them. You have the mechanical shutters.",
			"This is getting serious. Stay sharp."
		},
		menuItems = {"Dosa", "Soda", "Ayran"},
		rules = {
			{
				npcType = "DancingGuy",
				description = "A guy dances while asking for food. Do NOT serve him.",
				correctAction = "ignore",
				consequence = "jumpscare"
			}
		},
		events = {
			{
				type = "terrifier_truck_aggressive",
				description = "Terrifier Truck returns. CLOSE ALL WINDOWS or die.",
				triggerTime = 0.5,
				requiresShutters = true,
				killIfOpen = true
			}
		},
		anomalies = {"DancingGuy", "TerrifierTruck"},
		difficulty = 4
	},

	[5] = {
		phoneDialogue = {
			"*ring ring*...",
			"Last night. Final shift.",
			"We've added something special to the menu... Soothu Dosai.",
			"Don't ask what it is. Just know how to make it.",
			"A man will come in. His shirt says 'Suthan'.",
			"He will ask for Soothu Dosai.",
			"Here's what you do...",
			"Make the dosa batter... but don't cook it.",
			"When he sits down... SPILL THE BATTER ON HIS HEAD.",
			"Then immediately TURN OFF ALL THE LIGHTS.",
			"And RUN. Run to the back room. Hide.",
			"If you do this correctly... you win. You survive all five nights.",
			"If you don't... well, this is your last call either way.",
			"It's been an honor. Good luck."
		},
		menuItems = {"Dosa", "Soda", "Ayran", "SoothuDosai"},
		rules = {
			{
				npcType = "Suthan",
				description = "Spill batter on his head, turn off lights, run to back room.",
				correctAction = "spill_batter_run",
				consequence = "game_over_death" -- failing = permanent death
			}
		},
		events = {
			{
				type = "final_sequence",
				description = "Suthan arrival triggers the endgame sequence",
				triggerTime = 0.7
			}
		},
		anomalies = {"Suthan", "TerrifierTruck", "SareeWoman"},
		difficulty = 5,
		isFinalNight = true
	}
}

-- Phone ring sound config
NightData.PhoneConfig = {
	ringInterval = 2, -- seconds between rings
	dialogueSpeed = 0.05, -- seconds per character (typewriter effect)
	dialoguePause = 1.5, -- pause between lines
	skipEnabled = true -- player can click to skip
}

return NightData
