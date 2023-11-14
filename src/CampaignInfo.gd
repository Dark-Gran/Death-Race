extends Reference
class_name CI

const PORTRAITS_RINGED:Array = [
	preload("res://assets/portraits/p50/00.png"),
	preload("res://assets/portraits/p50/01.png"),
	preload("res://assets/portraits/p50/02.png"),
	preload("res://assets/portraits/p50/03.png"),
	preload("res://assets/portraits/p50/04.png"),
	preload("res://assets/portraits/p50/05.png"),
	preload("res://assets/portraits/p50/06.png"),
	preload("res://assets/portraits/p50/07.png"),
	preload("res://assets/portraits/p50/08.png"),
	preload("res://assets/portraits/p50/09.png"),
	preload("res://assets/portraits/p50/10.png"),
	preload("res://assets/portraits/p50/11.png")
]

const ENGINE_UPGRADE_POWER:float = 7.5
const TYRES_UPGRADE_POWER:float = 15.0
const ARMOR_UPGRADE_POWER:float = 20.0 # in-future: distinct between extra health and damage reduction

const UPGRADE_PRICE:int = 250 # per level(tier)
const SELL_PRICE:float = 0.5 # part from the original price

const REPAIR_PRICE:float = 0.25 # How much of original-price does it cost to repair 100%
const REPAIR_POWER:float = 0.1 # Strength of one repair-use

const MINES_PRICE:int = 500 # per level(tier)
const ROCKET_FUEL_PRICE:int = 250
const SABOTAUGE_PRICE:int = 250

const SABOTAUGE_TOP:float = 0.4 # top dmg by sabotauge
const SABOTAUGE_BOT:float = 0.2

const ROCKET_FUEL_CHANCE:float = 0.33 # chance that an enemy will pick rocket fuel
const MINES_CHANCE:float = 0.33 # chance that an enemy will pick mines

const REAPER_REWARDS:Array = [1500, 4500, 9000] # Reward for killing all (possibly placeholder)
const KILL_REWARDS:Array = [1000, 3000, 6000]
const QUEST_CHANCE:float = 0.1
enum QuestType {KILL, MAX}

const RACE_REWARDS_POINTS = [
	[3, 2, 1, 0],
	[6, 4, 2, 0],
	[12, 8, 4, 0]
]

const RACE_REWARDS_CASH = [
	[1000, 500, 250, 0],
	[3000, 1500, 750, 0],
	[6000, 3000, 1500, 0]
]

enum DriverInfo {PORTRAIT, NAME, HUE, CASH, SCORE, LAST_REWARD_POINTS, SCORE_POSITION, BASE_SKILL, GARAGE_SLOTS, CARS, MAX}

enum CarInfo {TIER, PRICE, HITPOINTS, RESOURCE, MAX}
# Most Car stats are set in car-scenes. Only Hitpoints are needed outside of the race.
# However that renders the car-scene condition settings pointless (EXCEPT for the cars that are placed on track for "show"), therefore some rethink should be done in case more stats are needed outside the race.
const CARS:Dictionary = {
	"Companion" : {
		CarInfo.TIER : 0,
		CarInfo.PRICE : 1965,
		CarInfo.HITPOINTS : 140.0,
		CarInfo.RESOURCE : "Companion"
	},
	"Bee" : {
		CarInfo.TIER : 0,
		CarInfo.PRICE : 2000,
		CarInfo.HITPOINTS : 160.0,
		CarInfo.RESOURCE : "Bee"
	},
	"Warden" : {
		CarInfo.TIER : 1,
		CarInfo.PRICE : 5000,
		CarInfo.HITPOINTS : 190.0,
		CarInfo.RESOURCE : "Warden"
	},
	"Warrior" : {
		CarInfo.TIER : 2,
		CarInfo.PRICE : 10000,
		CarInfo.HITPOINTS : 170.0,
		CarInfo.RESOURCE : "Warrior"
	},
	"Hunter" : {
		CarInfo.TIER : 2,
		CarInfo.PRICE : 10000,
		CarInfo.HITPOINTS : 160.0,
		CarInfo.RESOURCE : "Hunter"
	},
	"Needle" : {
		CarInfo.TIER : 3,
		CarInfo.PRICE : 15000,
		CarInfo.HITPOINTS : 130.0,
		CarInfo.RESOURCE : "Needle"
	},
	"Cobra" : {
		CarInfo.TIER : 3,
		CarInfo.PRICE : 20000,
		CarInfo.HITPOINTS : 120.0,
		CarInfo.RESOURCE : "Cobra"
	},
}

enum CarSlot {NAME, CONDITION, ENGINE, TYRES, ARMOR, MAX}

var player_info:Dictionary = {
	DriverInfo.PORTRAIT : 0,
	DriverInfo.NAME : ". . .",
	DriverInfo.HUE : 0.0,
	DriverInfo.CASH : 1100,
	DriverInfo.SCORE : 0,
	DriverInfo.LAST_REWARD_POINTS : 0,
	DriverInfo.SCORE_POSITION : 12,
	DriverInfo.BASE_SKILL : 0.0,
	DriverInfo.GARAGE_SLOTS : 1,
	DriverInfo.CARS: [
		{
			CarSlot.NAME : "Companion",
			CarSlot.CONDITION : 140.0,
			CarSlot.ENGINE : 0,
			CarSlot.TYRES : 0,
			CarSlot.ARMOR : 0
		}
	]
}

var campaign_stats:Array = [ # includes vars for tutorial scripting, needs separation into a campaign manager if it ever were to be upgraded
	0, # 0Tournament Rounds
	false, # 1Saw victory screen
	"", # 2Disabled bot
	11, # 3Quest-Giver portrait
	false, # 4Saw Tutorial
	false, # 5Saw "Medium warning"
	false, #6second track on tier0 ("players second race") forced; see var second_player_race_forced
	false, #7saw shop welcome
	false, #8bought mines
	false, #9bought rocket fuel
	false #10bought sabotauge
]

const BOT_NAMES:Array = [ # used as keys for bot_infos and CHARACTERS; sorted by "Default Score"
	"#GRANNY",
	"Jane Toyota",
	"M.C. $paghetti",
	"John Smith",
	"Helen Killowski",
	"Jean Kolo",
	"Mia Payne",
	"Fred Krieger",
	"Mental Max",
	"Liz Lemon",
	"Pepper Pete",
	"Billy Bob"
]

var bot_infos:Dictionary = { # sorted by Portrait ID
	"John Smith" : {
		DriverInfo.PORTRAIT : 0,
		DriverInfo.NAME : "John Smith",
		DriverInfo.HUE : 0.6,
		DriverInfo.CASH : 0,
		DriverInfo.SCORE : 9,
		DriverInfo.LAST_REWARD_POINTS : 0,
		DriverInfo.SCORE_POSITION : 3,
		DriverInfo.BASE_SKILL : 9.0,
		DriverInfo.GARAGE_SLOTS : 1,
		DriverInfo.CARS: [
		{
			CarSlot.NAME : "Hunter",
			CarSlot.CONDITION : 160.0,
			CarSlot.ENGINE : 2,
			CarSlot.TYRES : 2,
			CarSlot.ARMOR : 0
		}
	]
	},
	"Mia Payne" : {
		DriverInfo.PORTRAIT : 1,
		DriverInfo.NAME : "Mia Payne",
		DriverInfo.HUE : 0.88,
		DriverInfo.CASH : 0,
		DriverInfo.SCORE : 6,
		DriverInfo.LAST_REWARD_POINTS : 0,
		DriverInfo.SCORE_POSITION : 6,
		DriverInfo.BASE_SKILL : 6.0,
		DriverInfo.GARAGE_SLOTS : 1,
		DriverInfo.CARS: [
		{
			CarSlot.NAME : "Warden",
			CarSlot.CONDITION : 210.0,
			CarSlot.ENGINE : 1,
			CarSlot.TYRES : 1,
			CarSlot.ARMOR : 1
		}
	]
	},
	"Pepper Pete" : {
		DriverInfo.PORTRAIT : 2,
		DriverInfo.NAME : "Pepper Pete",
		DriverInfo.HUE : 0.8,
		DriverInfo.CASH : 0,
		DriverInfo.SCORE : 2,
		DriverInfo.LAST_REWARD_POINTS : 0,
		DriverInfo.SCORE_POSITION : 10,
		DriverInfo.BASE_SKILL : 2.0,
		DriverInfo.GARAGE_SLOTS : 1,
		DriverInfo.CARS: [
		{
			CarSlot.NAME : "Bee",
			CarSlot.CONDITION : 160.0,
			CarSlot.ENGINE : 0,
			CarSlot.TYRES : 1,
			CarSlot.ARMOR : 0
		}
	]
	},
	"Billy Bob" : {
		DriverInfo.PORTRAIT : 3,
		DriverInfo.NAME : "Billy Bob",
		DriverInfo.HUE : 0.43,
		DriverInfo.CASH : 0,
		DriverInfo.SCORE : 1,
		DriverInfo.LAST_REWARD_POINTS : 0,
		DriverInfo.SCORE_POSITION : 11,
		DriverInfo.BASE_SKILL : 1.0,
		DriverInfo.GARAGE_SLOTS : 1,
		DriverInfo.CARS: [
		{
			CarSlot.NAME : "Companion",
			CarSlot.CONDITION : 140.0,
			CarSlot.ENGINE : 0,
			CarSlot.TYRES : 1,
			CarSlot.ARMOR : 0
		}
	]
	},
	"Jean Kolo" : {
		DriverInfo.PORTRAIT : 4,
		DriverInfo.NAME : "Jean Kolo",
		DriverInfo.HUE : 0.2,
		DriverInfo.CASH : 0,
		DriverInfo.SCORE : 7,
		DriverInfo.LAST_REWARD_POINTS : 0,
		DriverInfo.SCORE_POSITION : 5,
		DriverInfo.BASE_SKILL : 7.0,
		DriverInfo.GARAGE_SLOTS : 1,
		DriverInfo.CARS: [
		{
			CarSlot.NAME : "Warrior",
			CarSlot.CONDITION : 190.0,
			CarSlot.ENGINE : 0,
			CarSlot.TYRES : 2,
			CarSlot.ARMOR : 1
		}
	]
	},
	"Liz Lemon" : {
		DriverInfo.PORTRAIT : 5,
		DriverInfo.NAME : "Liz Lemon",
		DriverInfo.HUE : 0.14,
		DriverInfo.CASH : 0,
		DriverInfo.SCORE : 3,
		DriverInfo.LAST_REWARD_POINTS : 0,
		DriverInfo.SCORE_POSITION : 9,
		DriverInfo.BASE_SKILL : 3.0,
		DriverInfo.GARAGE_SLOTS : 1,
		DriverInfo.CARS: [
		{
			CarSlot.NAME : "Companion",
			CarSlot.CONDITION : 140.0,
			CarSlot.ENGINE : 0,
			CarSlot.TYRES : 1,
			CarSlot.ARMOR : 0
		}
	]
	},
	"Mental Max" : {
		DriverInfo.PORTRAIT : 6,
		DriverInfo.NAME : "Mental Max",
		DriverInfo.HUE : 0.7,
		DriverInfo.CASH : 0,
		DriverInfo.SCORE : 4,
		DriverInfo.LAST_REWARD_POINTS : 0,
		DriverInfo.SCORE_POSITION : 8,
		DriverInfo.BASE_SKILL : 4.0,
		DriverInfo.GARAGE_SLOTS : 1,
		DriverInfo.CARS: [
		{
			CarSlot.NAME : "Warden",
			CarSlot.CONDITION : 190.0,
			CarSlot.ENGINE : 1,
			CarSlot.TYRES : 1,
			CarSlot.ARMOR : 0
		}
	]
	},
	"Helen Killowski" : {
		DriverInfo.PORTRAIT : 7,
		DriverInfo.NAME : "Helen Killowski",
		DriverInfo.HUE : 0.28,
		DriverInfo.CASH : 0,
		DriverInfo.SCORE : 8,
		DriverInfo.LAST_REWARD_POINTS : 0,
		DriverInfo.SCORE_POSITION : 4,
		DriverInfo.BASE_SKILL : 8.0,
		DriverInfo.GARAGE_SLOTS : 1,
		DriverInfo.CARS: [
		{
			CarSlot.NAME : "Hunter",
			CarSlot.CONDITION : 200.0,
			CarSlot.ENGINE : 1,
			CarSlot.TYRES : 2,
			CarSlot.ARMOR : 2
		}
	]
	},
	"Fred Krieger" : {
		DriverInfo.PORTRAIT : 8,
		DriverInfo.NAME : "Fred Krieger",
		DriverInfo.HUE : 0.1,
		DriverInfo.CASH : 0,
		DriverInfo.SCORE : 5,
		DriverInfo.LAST_REWARD_POINTS : 0,
		DriverInfo.SCORE_POSITION : 7,
		DriverInfo.BASE_SKILL : 5.0,
		DriverInfo.GARAGE_SLOTS : 1,
		DriverInfo.CARS: [
		{
			CarSlot.NAME : "Warden",
			CarSlot.CONDITION : 210.0,
			CarSlot.ENGINE : 1,
			CarSlot.TYRES : 0,
			CarSlot.ARMOR : 1
		}
	]
	},
	"M.C. $paghetti" : {
		DriverInfo.PORTRAIT : 9,
		DriverInfo.NAME : "M.C. $paghetti",
		DriverInfo.HUE : 0.74,
		DriverInfo.CASH : 0,
		DriverInfo.SCORE : 10,
		DriverInfo.LAST_REWARD_POINTS : 0,
		DriverInfo.SCORE_POSITION : 2,
		DriverInfo.BASE_SKILL : 10.0,
		DriverInfo.GARAGE_SLOTS : 1,
		DriverInfo.CARS: [
		{
			CarSlot.NAME : "Needle",
			CarSlot.CONDITION : 180.0,
			CarSlot.ENGINE : 3,
			CarSlot.TYRES : 2,
			CarSlot.ARMOR : 3
		}
	]
	},
	"Jane Toyota" : {
		DriverInfo.PORTRAIT : 10,
		DriverInfo.NAME : "Jane Toyota",
		DriverInfo.HUE : 0.52,
		DriverInfo.CASH : 0,
		DriverInfo.SCORE : 11,
		DriverInfo.LAST_REWARD_POINTS : 0,
		DriverInfo.SCORE_POSITION : 1,
		DriverInfo.BASE_SKILL : 11.0,
		DriverInfo.GARAGE_SLOTS : 1,
		DriverInfo.CARS: [
		{
			CarSlot.NAME : "Cobra",
			CarSlot.CONDITION : 160.0,
			CarSlot.ENGINE : 3,
			CarSlot.TYRES : 3,
			CarSlot.ARMOR : 2
		}
	]
	},
	"#GRANNY" : {
		DriverInfo.PORTRAIT : 11,
		DriverInfo.NAME : "#GRANNY",
		DriverInfo.HUE : 0.0,
		DriverInfo.CASH : 0,
		DriverInfo.SCORE : 12,
		DriverInfo.LAST_REWARD_POINTS : 0,
		DriverInfo.SCORE_POSITION : 0,
		DriverInfo.BASE_SKILL : 12.0,
		DriverInfo.GARAGE_SLOTS : 1,
		DriverInfo.CARS: [
		{
			CarSlot.NAME : "Cobra",
			CarSlot.CONDITION : 180.0,
			CarSlot.ENGINE : 3,
			CarSlot.TYRES : 3,
			CarSlot.ARMOR : 3
		}
	]
	}
}

enum BotTraits {
	RESOURCE_TOPUP, # does not need pickup until the resource amount is below the line
	GREEDY,
	CASUAL_USER,
	ADDICT,
	AGGRESIVITY,
	PLAYER_RELATION,
	ENGINE_DEBUFF,
MAX}
# PATIENCE = affect stuck+recovery times
# RESISTANCE? = toward hallucination etc
# PRECISION = botpoint+pickup
# INDECISIVE = chance to hesitate during race singup

const CHARACTERS:Dictionary = { # sorted by "Default Score"
	"Billy Bob" : {
		BotTraits.RESOURCE_TOPUP : 0.5,
		BotTraits.GREEDY : false,
		BotTraits.CASUAL_USER : true,
		BotTraits.ADDICT : false,
		BotTraits.AGGRESIVITY : 0.0,
		BotTraits.PLAYER_RELATION : 0.0,
		BotTraits.ENGINE_DEBUFF : 0.0
	},
	"Pepper Pete" : {
		BotTraits.RESOURCE_TOPUP : 0.5,
		BotTraits.GREEDY : false,
		BotTraits.CASUAL_USER : true,
		BotTraits.ADDICT : false,
		BotTraits.AGGRESIVITY : 0.0,
		BotTraits.PLAYER_RELATION : 0.0,
		BotTraits.ENGINE_DEBUFF : 0.0
	},
	"Liz Lemon" : {
		BotTraits.RESOURCE_TOPUP : 0.5,
		BotTraits.GREEDY : false,
		BotTraits.CASUAL_USER : false,
		BotTraits.ADDICT : false,
		BotTraits.AGGRESIVITY : 0.0,
		BotTraits.PLAYER_RELATION : 0.0,
		BotTraits.ENGINE_DEBUFF : 0.0
	},
	"Mental Max" : {
		BotTraits.RESOURCE_TOPUP : 0.1,
		BotTraits.GREEDY : false,
		BotTraits.CASUAL_USER : true,
		BotTraits.ADDICT : true,
		BotTraits.AGGRESIVITY : 0.2,
		BotTraits.PLAYER_RELATION : 0.0,
		BotTraits.ENGINE_DEBUFF : 0.0
	},
	"Fred Krieger" : {
		BotTraits.RESOURCE_TOPUP : 0.8,
		BotTraits.GREEDY : true,
		BotTraits.CASUAL_USER : false,
		BotTraits.ADDICT : false,
		BotTraits.AGGRESIVITY : 0.0,
		BotTraits.PLAYER_RELATION : 0.0,
		BotTraits.ENGINE_DEBUFF : 0.0
	},
	"Mia Payne" : {
		BotTraits.RESOURCE_TOPUP : 0.3,
		BotTraits.GREEDY : false,
		BotTraits.CASUAL_USER : false,
		BotTraits.ADDICT : false,
		BotTraits.AGGRESIVITY : 0.0,
		BotTraits.PLAYER_RELATION : 0.0,
		BotTraits.ENGINE_DEBUFF : 0.0
	},
	"Jean Kolo" : {
		BotTraits.RESOURCE_TOPUP : 0.2,
		BotTraits.GREEDY : true,
		BotTraits.CASUAL_USER : true,
		BotTraits.ADDICT : true,
		BotTraits.AGGRESIVITY : 0.0,
		BotTraits.PLAYER_RELATION : 0.0,
		BotTraits.ENGINE_DEBUFF : 0.0
	},
	"Helen Killowski" : {
		BotTraits.RESOURCE_TOPUP : 0.4,
		BotTraits.GREEDY : false,
		BotTraits.CASUAL_USER : false,
		BotTraits.ADDICT : false,
		BotTraits.AGGRESIVITY : 0.2,
		BotTraits.PLAYER_RELATION : 0.0,
		BotTraits.ENGINE_DEBUFF : 0.0
	},
	"John Smith" : {
		BotTraits.RESOURCE_TOPUP : 0.5,
		BotTraits.GREEDY : false,
		BotTraits.CASUAL_USER : false,
		BotTraits.ADDICT : false,
		BotTraits.AGGRESIVITY : 0.0,
		BotTraits.PLAYER_RELATION : 0.0,
		BotTraits.ENGINE_DEBUFF : 0.0
	},
	"M.C. $paghetti" : {
		BotTraits.RESOURCE_TOPUP : 0.4,
		BotTraits.GREEDY : false,
		BotTraits.CASUAL_USER : false,
		BotTraits.ADDICT : false,
		BotTraits.AGGRESIVITY : 0.1,
		BotTraits.PLAYER_RELATION : -1.0,
		BotTraits.ENGINE_DEBUFF : 0.0
	},
	"Jane Toyota" : {
		BotTraits.RESOURCE_TOPUP : 0.5,
		BotTraits.GREEDY : false,
		BotTraits.CASUAL_USER : false,
		BotTraits.ADDICT : false,
		BotTraits.AGGRESIVITY : 0.0,
		BotTraits.PLAYER_RELATION : 0.0,
		BotTraits.ENGINE_DEBUFF : 0.0
	},
	"#GRANNY" : {
		BotTraits.RESOURCE_TOPUP : 0.1,
		BotTraits.GREEDY : false,
		BotTraits.CASUAL_USER : true,
		BotTraits.ADDICT : false,
		BotTraits.AGGRESIVITY : 0.1,
		BotTraits.PLAYER_RELATION : 1.0,
		BotTraits.ENGINE_DEBUFF : 0.0
	}
}
