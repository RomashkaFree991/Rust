SWEP.Base = "rust_throwable_melee_base"
SWEP.Category = "TFA Rust Weapons"
SWEP.Spawnable = true
SWEP.AdminSpawnable = false

SWEP.Author = "Darky"
SWEP.PrintName = "Longsword"

SWEP.ViewModel = "models/weapons/darky_m/rust/c_Longsword.mdl"
SWEP.UseHands = true
SWEP.WorldModel = "models/weapons/darky_m/rust/w_Longsword.mdl"
SWEP.HoldType = "knife"
SWEP.IronSightHoldTypeOverride = "melee" 

SWEP.ViewModelFOV = 60
SWEP.Weight = 100

SWEP.Type = "Throwable Melee Weapon"

SWEP.SwingHitAnimation = ACT_VM_SWINGHIT

SWEP.Idle_Mode = TFA.Enum.IDLE_LUA

-- SWEP.IronInSound = Sound("darky_rust.combat-deploy") --Sound to play when ironsighting in?  nil for default
-- SWEP.IronOutSound = Sound("TFA_INS2.IronOut") --Sound to play when ironsighting out?  nil for default

SWEP.Primary.Damage		= 75
SWEP.DamageType = DMG_CLUB 
SWEP.Primary.NumShots	= 1
SWEP.Primary.Automatic			= true
SWEP.Primary.RPM				= 30
SWEP.FiresUnderwater = true
SWEP.Primary.PenetrationMultiplier = 1
SWEP.Primary.Force = 10
SWEP.AllowSprintAttack = true

SWEP.EventTable = {}

SWEP.Primary.ProjectileModel = "models/weapons/darky_m/rust/w_Longsword.mdl"
SWEP.Primary.ProjectileVelocity = 1900
SWEP.Primary.ProjectileSpin = 900
SWEP.Primary.ProjectileStartAng = -45
-- 90, -90 for spears
-- 900, -45 for spinny things
SWEP.Primary.ProjectileStickType = 1 -- 0: never stuck in objects; 1: stucks in objects, sometimes rebounds; 2: always stuck in objects

SWEP.IronAnimation = {
	["in"] = {
		["type"] = TFA.Enum.ANIMATION_SEQ, --Sequence or act
		["value"] = "throw",
		["value_empty"] = "throw",
		["delay_to_shoot"] = 0.2
	},	
	["loop"] = {
		["type"] = TFA.Enum.ANIMATION_SEQ, --Sequence or act
		["value"] = "throw_hold",
		["value_empty"] = "throw_hold",
		["is_idle"] = true
	},
	["out"] = {
		["type"] = TFA.Enum.ANIMATION_SEQ, --Sequence or act
		["value"] = "throw_cancel",
		["value_empty"] = "throw_cancel",
	},	
	["shoot"] = {
		["type"] = TFA.Enum.ANIMATION_SEQ, --Sequence or act
		["value"] = "throw_out",
		["delay_to_shoot"] = 0.5,
		["delay_after_shoot"] = 0
	}
}

SWEP.Primary.Attacks = {
	{
		["act"] = ACT_VM_MISSLEFT, -- Animation; ACT_VM_THINGY, ideally something unique per-sequence
		["len"] = 16 * 4, -- Trace distance
		["dir"] = Vector(0, 0, 0), -- Trace arc cast
		["dmg"] = SWEP.Primary.Damage, --Damage
		["dmgtype"] = DMG_CLUB, --DMG_SLASH,DMG_CRUSH, etc.
		["delay"] = 0.5, --Delay
		["spr"] = true, --Allow attack while sprinting?
		["snd"] = Sound("darky_rust.2handed-sword-attack"),
		["snd_delay"] = 0.5,
		["viewpunch"] = Angle(-1, 1.5, 0), --viewpunch angle
		["end"] = 60/SWEP.Primary.RPM, --time before next attack
		["hull"] = 16, --Hullsize
		["direction"] = "F", --Swing dir,
		["hitflesh"] = "",
		["hitworld"] = "",
		["combotime"] = 0,
		["callback"] = function(tbl, wep, tr)
			if tr.Hit then
				wep:SendViewModelAnim(ACT_VM_HITLEFT)
			end
		end,
	},
	
	{
		["act"] = ACT_VM_MISSCENTER, -- Animation; ACT_VM_THINGY, ideally something unique per-sequence
		["len"] = 16 * 4, -- Trace distance
		["dir"] = Vector(0, 0, 0), -- Trace arc cast
		["dmg"] = SWEP.Primary.Damage, --Damage
		["dmgtype"] = DMG_CLUB, --DMG_SLASH,DMG_CRUSH, etc.
		["delay"] = 0.5, --Delay
		["spr"] = true, --Allow attack while sprinting?
		["snd"] = Sound("darky_rust.2handed-sword-attack"),
		["snd_delay"] = 0.5,
		["viewpunch"] = Angle(-1, 1.5, 0), --viewpunch angle
		["end"] = 60/SWEP.Primary.RPM, --time before next attack
		["hull"] = 16, --Hullsize
		["direction"] = "F", --Swing dir,
		["hitflesh"] = "",
		["hitworld"] = "",
		["combotime"] = 0,
		["callback"] = function(tbl, wep, tr)
			if tr.Hit then
				wep:SendViewModelAnim(ACT_VM_HITCENTER)
			end
		end,
	},

	{
		["act"] = ACT_VM_MISSRIGHT, -- Animation; ACT_VM_THINGY, ideally something unique per-sequence
		["len"] = 16 * 4, -- Trace distance
		["dir"] = Vector(0, 0, 0), -- Trace arc cast
		["dmg"] = SWEP.Primary.Damage, --Damage
		["dmgtype"] = DMG_CLUB, --DMG_SLASH,DMG_CRUSH, etc.
		["delay"] = 0.5, --Delay
		["spr"] = true, --Allow attack while sprinting?
		["snd"] = Sound("darky_rust.2handed-sword-attack"),
		["snd_delay"] = 0.5,
		["viewpunch"] = Angle(-1, 1.5, 0), --viewpunch angle
		["end"] = 60/SWEP.Primary.RPM, --time before next attack
		["hull"] = 16, --Hullsize
		["direction"] = "F", --Swing dir,
		["hitflesh"] = "",
		["hitworld"] = "",
		["combotime"] = 0,
		["callback"] = function(tbl, wep, tr)
			if tr.Hit then
				wep:SendViewModelAnim(ACT_VM_HITRIGHT)
			end
		end,
	},
	
}

SWEP.AllowSprintAttack = false
SWEP.RunSightsPos = Vector(0, 0, 0)
SWEP.RunSightsAng = Vector(-20, 0, 0)


SWEP.SoundMats = {
	[MAT_DEFAULT]		= Sound("darky_rust.2handed-sword-strike-1"),
	[MAT_WOOD]			= Sound("darky_rust.2handed-sword-strike-soft-1"),
	[MAT_ALIENFLESH]	= Sound("darky_rust.2handed-sword-strike-soft-2"),
	[MAT_BLOODYFLESH]	= Sound("darky_rust.2handed-sword-strike-soft-1"),
	[MAT_FLESH]			= Sound("darky_rust.2handed-sword-strike-soft-2"),
}


