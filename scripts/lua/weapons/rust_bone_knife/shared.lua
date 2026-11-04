SWEP.Base = "rust_throwable_melee_base"
SWEP.Category = "TFA Rust Weapons"
SWEP.Spawnable = true
SWEP.AdminSpawnable = false

SWEP.Author = "Darky"
SWEP.PrintName = "Bone Knife"

SWEP.ViewModel = "models/weapons/darky_m/rust/c_boneknife.mdl"
SWEP.UseHands = true
SWEP.WorldModel = "models/weapons/darky_m/rust/w_boneknife.mdl"
SWEP.HoldType = "knife"
SWEP.IronSightHoldTypeOverride = "melee" 

SWEP.SoundMats = {
	[MAT_DEFAULT]		= Sound("darky_rust.bone-club-strike-1"),
	[MAT_WOOD]			= Sound("darky_rust.hammer_impact_wood"),
	[MAT_ALIENFLESH]	= Sound("darky_rust.bone-knife-strike-soft"),
	[MAT_BLOODYFLESH]	= Sound("darky_rust.bone-knife-strike-soft"),
	[MAT_FLESH]			= Sound("darky_rust.bone-knife-strike-soft"),
}

SWEP.ViewModelFOV = 70
SWEP.Weight = 100

SWEP.Type = "Throwable Melee Weapon"

SWEP.SwingHitAnimation = ACT_VM_SWINGHIT

SWEP.Idle_Mode = TFA.Enum.IDLE_LUA

SWEP.IronInSound = nil --Sound to play when ironsighting in?  nil for default
-- SWEP.IronOutSound = Sound("TFA_INS2.IronOut") --Sound to play when ironsighting out?  nil for default

SWEP.Primary.Damage		= 35
SWEP.DamageType = DMG_CLUB 
SWEP.Primary.NumShots	= 1
SWEP.Primary.Automatic			= true
SWEP.Primary.RPM				= 68
SWEP.FiresUnderwater = true
SWEP.Primary.PenetrationMultiplier = 1
SWEP.Primary.Force = 10
SWEP.AllowSprintAttack = true

SWEP.EventTable = {}

SWEP.Primary.ProjectileModel = "models/weapons/darky_m/rust/w_boneknife.mdl"
SWEP.Primary.ProjectileVelocity = 1000
SWEP.Primary.ProjectileSpin = 900
SWEP.Primary.ProjectileStartAng = -45
-- 90, -90 for spears
-- 900, -45 for spinny things
SWEP.Primary.ProjectileStickType = 0 -- 0: never stuck in objects; 1: stucks in objects, sometimes rebounds; 2: always stuck in objects

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
		["len"] = 16 * 5, -- Trace distance
		["dir"] = Vector(0, 0, 0), -- Trace arc cast
		["dmg"] = SWEP.Primary.Damage, --Damage
		["dmgtype"] = DMG_CLUB, --DMG_SLASH,DMG_CRUSH, etc.
		["delay"] = 0.15, --Delay
		["spr"] = false, --Allow attack while sprinting?
		["snd"] = Sound("darky_rust.bone-knife-attack"),
		["snd_delay"] = 0.15,
		["viewpunch"] = Angle(0, 0, 0), --viewpunch angle
		["end"] = 0.6, --time before next attack
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




