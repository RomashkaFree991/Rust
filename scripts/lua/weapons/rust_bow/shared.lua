SWEP.Base = "rust_throwable_melee_base"
SWEP.Category = "TFA Rust Weapons"
SWEP.Spawnable = true
SWEP.AdminSpawnable = false

SWEP.Author = "Darky"
SWEP.PrintName = "Bow"

SWEP.ViewModel = "models/weapons/darky_m/rust/c_bow.mdl" --Viewmodel path
SWEP.UseHands = true
SWEP.WorldModel = "models/weapons/darky_m/rust/w_bow.mdl"
SWEP.HoldType = "physgun"
SWEP.IronSightHoldTypeOverride = "smg"
SWEP.ViewModelFOV = 60
SWEP.Weight = 100
SWEP.Type = "Bow"


SWEP.Idle_Mode = TFA.Enum.IDLE_LUA

SWEP.IronInSound = Sound("")
SWEP.IronOutSound = Sound("")

SWEP.Primary.Damage		= 50
SWEP.DamageType = DMG_CLUB 
SWEP.Primary.NumShots	= 1
SWEP.Primary.Automatic			= true
SWEP.Primary.RPM				= 68
SWEP.FiresUnderwater = true
SWEP.Primary.PenetrationMultiplier = 1
SWEP.Primary.Force = 10
SWEP.FireModeName = "Bow"

SWEP.AllowSprintAttack = true
SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Ammo = "XBowBolt"
SWEP.Primary.Sound = Sound("darky_rust.bow-attack-1")
SWEP.Primary.AmmoConsumption = 1

SWEP.EventTable = {}

SWEP.Secondary.IronFOV = 70
SWEP.IronViewModelFOV = 70
SWEP.DisableChambering = true

SWEP.EventTable = {
	[ACT_VM_DEPLOY] = {															
		{ ["time"] = 0.0, ["type"] = "lua", ["value"] = 
			function( wep, viewmodel, ifp ) 
				if wep.Attachments[1].sel == 1 then
					ParticleEffectAttach( "rust_fire_vm", PATTACH_POINT_FOLLOW, viewmodel, 1 )
				end 
			end,
		["client"] = true, ["server"] = false},
	},	   
	[ACT_VM_PRIMARYATTACK] = {
		{ ["time"] = 0.0, ["type"] = "lua", ["value"] = function( wep, viewmodel, ifp ) viewmodel:StopParticles() end, ["client"] = true, ["server"] = false}, 
	},	  

	[ACT_VM_UNDEPLOY] = {
		{ ["time"] = 2.0, ["type"] = "lua", ["value"] = function( wep, viewmodel, ifp ) viewmodel:StopParticles() end, ["client"] = true, ["server"] = false},	  
	}
}

SWEP.Primary.ProjectileModel = "models/weapons/darky_m/rust/wood_arrow.mdl"
SWEP.Primary.ProjectileVelocity = 3000
SWEP.Primary.ProjectileSpin = 0
SWEP.Primary.ProjectileStartAng = 90
-- 90, -90 for spears
-- 900, -45 for spinny things
SWEP.Primary.ProjectileStickType = 2 -- 0: never stuck in objects; 1: stucks in objects, sometimes rebounds; 2: always stuck in objects

SWEP.Attachments = {
	[1] = {atts = {"darky_rust_fire_arrows", "darky_rust_bone_arrows", "darky_rust_speed_arrows"}},
}

SWEP.VElements = {}
SWEP.IronAnimation = {
	["idle"] = {
		["type"] = TFA.Enum.ANIMATION_SEQ, --Sequence or act
		["value"] = "loop",
		["enabled"] = true
	},
	["shoot"] = {
		["type"] = TFA.Enum.ANIMATION_SEQ, --Sequence or act
		["value"] = "fire",
		["enabled"] = true,
		["delay_to_shoot"] = 0,
		["delay_after_shoot"] = 0.5
	},
	["out"] = {
		["type"] = TFA.Enum.ANIMATION_SEQ, --Sequence or act
		["value"] = "cancel",
		["enabled"] = true
	},
	["in"] = {
		["type"] = TFA.Enum.ANIMATION_SEQ, --Sequence or act
		["value"] = "charge",
		["enabled"] = true,
		["delay_to_shoot"] = 1.5
	}
}

SWEP.Primary.Attacks = {}
SWEP.ThrowGesture = ACT_HL2MP_GESTURE_RANGE_ATTACK_PISTOL

function SWEP:StrikeThink() return end
function SWEP:Strike() return end
-- removing melee hit functions so they will not error (we don't have any attacks at bow)

function SWEP:CanBePickedUpByNPCs()
	return false
end

SWEP.AllowSprintAttack = false
SWEP.RunSightsPos = Vector(0, 0, 2)
SWEP.RunSightsAng = Vector(-20, 0, 0)




