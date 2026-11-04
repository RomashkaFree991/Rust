SWEP.Base = "rust_throwable_melee_base"
SWEP.Category = "TFA Rust Weapons"
SWEP.Spawnable = true
SWEP.AdminSpawnable = false

SWEP.Author = "Darky"
SWEP.PrintName = "Wooden Spear"

SWEP.ViewModel = "models/weapons/darky_m/rust/c_wooden_spear.mdl"
SWEP.UseHands = true
SWEP.WorldModel = "models/weapons/darky_m/rust/w_wooden_spear.mdl"
SWEP.HoldType = "crossbow"
SWEP.IronSightHoldTypeOverride = "melee" 

SWEP.ViewModelFOV = 60
SWEP.Weight = 100

SWEP.Type = "Throwable Melee Weapon"

SWEP.SwingHitAnimation = ACT_VM_SWINGHIT

SWEP.Idle_Mode = TFA.Enum.IDLE_LUA

-- SWEP.IronInSound = Sound("darky_rust.combat-deploy") --Sound to play when ironsighting in?  nil for default
-- SWEP.IronOutSound = Sound("TFA_INS2.IronOut") --Sound to play when ironsighting out?  nil for default

SWEP.Primary.Damage = 39
SWEP.DamageType = DMG_CRUSH 
SWEP.Primary.NumShots	= 1
SWEP.Primary.Automatic			= true
SWEP.Primary.RPM				= 40
SWEP.FiresUnderwater = true
SWEP.Primary.PenetrationMultiplier = 1
SWEP.Primary.Force = 1
SWEP.AllowSprintAttack = true
SWEP.ImpactDecal = "Impact.Concrete"

SWEP.EventTable = {}

SWEP.Primary.ProjectileModel = "models/weapons/darky_m/rust/w_wooden_spear.mdl"
SWEP.Primary.ProjectileVelocity = 1500
SWEP.Primary.ProjectileSpin = 0
SWEP.Primary.ProjectileStartAng = 13
-- 90, -90 for spears
-- 900, -45 for spinny things
SWEP.Primary.ProjectileStickType = 2 -- 0: never stuck in objects; 1: stucks in objects, sometimes rebounds; 2: always stuck in objects

SWEP.SoundMats = {
	[MAT_DEFAULT]		= Sound("darky_rust.spear-strike-muted"),
	[MAT_WOOD]			= Sound("darky_rust.spear-strike-muted"),
	[MAT_ALIENFLESH]	= Sound("darky_rust.spear-strike-soft"),
	[MAT_BLOODYFLESH]	= Sound("darky_rust.spear-strike-soft"),
	[MAT_FLESH]			= Sound("darky_rust.spear-strike-soft"),
}


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
		["act"] = ACT_VM_SWINGMISS, -- Animation; ACT_VM_THINGY, ideally something unique per-sequence
		["len"] = 24 * 3.8, -- Trace distance
		["dir"] = Vector(0, 0, 0), -- Trace arc cast
		["dmg"] = SWEP.Primary.Damage, --Damage
		["dmgtype"] = DMG_CRUSH, --DMG_SLASH,DMG_CRUSH, etc.
		["delay"] = 0.45, --Delay
		["spr"] = true, --Allow attack while sprinting?
		["snd"] = Sound("darky_rust.spear-attack"),
		["snd_delay"] = 0.15,
		["viewpunch"] = Angle(-1, 0.5, 0), --viewpunch angle
		["end"] = 60/SWEP.Primary.RPM, --time before next attack
		["hull"] = 16, --Hullsize
		["direction"] = "F", --Swing dir,
		["hitflesh"] = "",
		["hitworld"] = "",
		["combotime"] = 0
	}
}

SWEP.AllowSprintAttack = false
SWEP.RunSightsPos = Vector(0, 0, 0)
SWEP.RunSightsAng = Vector(-20, 0, 0)




