SWEP.Base = "rust_throwable_melee_base"
SWEP.Category = "TFA Rust Weapons"
SWEP.Spawnable = true
SWEP.AdminSpawnable = false

SWEP.Author = "Darky"
SWEP.PrintName = "Compound Bow"

SWEP.ViewModel = "models/weapons/darky_m/rust/c_compoundbow.mdl" --Viewmodel path
SWEP.UseHands = true
SWEP.WorldModel = "models/weapons/darky_m/rust/w_compoundbow.mdl"
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
SWEP.Primary.RPM				= 60
SWEP.FiresUnderwater = true
SWEP.Primary.PenetrationMultiplier = 1
SWEP.Primary.Force = 20
SWEP.FireModeName = "Bow"

SWEP.AllowSprintAttack = true
SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Ammo = "XBowBolt"
SWEP.Primary.Sound = "TFA_RUST_CBOW"
SWEP.Primary.AmmoConsumption = 1

SWEP.EventTable = {}

SWEP.Secondary.IronFOV = 70
SWEP.IronViewModelFOV = 70
SWEP.DisableChambering = true

SWEP.EventTable = {
	[ACT_VM_DEPLOY] = {															
		{ ["time"] = 0.0, ["type"] = "lua", ["value"] = 
			function(wep, viewmodel, ifp) 
				if wep.Attachments[1].sel == 1 then
					ParticleEffectAttach("rust_fire_vm", PATTACH_POINT_FOLLOW, viewmodel, 1)
				end 
			end,
		["client"] = true, ["server"] = false},
	},	   
	[ACT_VM_PRIMARYATTACK] = {
		{ ["time"] = 0.0, ["type"] = "lua", ["value"] = function(wep, viewmodel, ifp) viewmodel:StopParticles() end, ["client"] = true, ["server"] = false}, 
	},	  

	[ACT_VM_UNDEPLOY] = {
		{ ["time"] = 2.0, ["type"] = "lua", ["value"] = function(wep, viewmodel, ifp) viewmodel:StopParticles() end, ["client"] = true, ["server"] = false},	  
	}
}
	
SWEP.Primary.ProjectileModel = "models/weapons/darky_m/rust/wood_arrow.mdl"
SWEP.Primary.ProjectileVelocity = 50000
SWEP.Primary.ProjectileSpin = 0
SWEP.Primary.ProjectileStartAng = 90
SWEP.ProjectileMass = 1
SWEP.ProjectileGravityMultiplier = 0.7
-- 90, -90 for spears
-- 900, -45 for spinny things
SWEP.Primary.ProjectileStickType = 2 -- 0: never stuck in objects; 1: stucks in objects, sometimes rebounds; 2: always stuck in objects

SWEP.Attachments = {
	[1] = {atts = {"darky_rust_fire_arrows", "darky_rust_bone_arrows", "darky_rust_speed_arrows"}},
}

SWEP.VElements = {}
SWEP.IronAnimation = {
	["idle"] = {
		["value"] = "pull_idle",
	},
	["shoot"] = {
		["value"] = "fire",
		["delay_to_shoot"] = 0,
		["delay_after_shoot"] = 0.5
	},
	["out"] = {
		["type"] = TFA.Enum.ANIMATION_SEQ, --Sequence or act
		["value"] = "cancel",
		["enabled"] = true
	},
	["in"] = {
		["value"] = "pull",
		["delay_to_shoot"] = 2,
		["idle_in"] = 3.5
	},
	["reset"] = {
		["value"] = "reset_pull",
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
SWEP.RunSightsPos = Vector(0, 0, 5)
SWEP.RunSightsAng = Vector(-20, 0, 0)

SWEP.PullProgress = 0

DEFINE_BASECLASS(SWEP.Base)

function SWEP:Think()
	BaseClass.Think(self)

	local owner = self.Owner
	local CT = CurTime()
	
	if self:GetPull() then
		if owner:KeyDown(IN_JUMP) or owner:KeyDown(IN_FORWARD) or owner:KeyDown(IN_BACK) or owner:KeyDown(IN_MOVELEFT) or owner:KeyDown(IN_MOVERIGHT) then
			self:SetPullTime(self:GetPullTime()+0.6)

			self:SendViewModelSeq(self.IronAnimation["reset"].value, nil, nil, -CT)
		end

		self:SetPullTime(math.Clamp(self:GetPullTime(), CT - 3.5, CT))

		self.PullProgress = math.Clamp(-(self:GetPullTime() - CT)/3.5, 0, 1)
		self.DMGMultiplier = 1 + self.PullProgress
	end
end


if CLIENT then -- shaky code and hud thing
	local ShakeLerp = 0.035
	local ShakeAng = Angle(0, 0, 0)

	local sH, sW = ScrH(), ScrW()
	local SmoothPullProgress = 0
	local nextScrenShake = CurTime()

	function SWEP:ShakeUpdate() -- RecoilUpdate fork from firearms pack
		local ply = self:GetOwner()
	
		if ply:IsPlayer() then
			if not ShakeAng:IsZero() then 
				local eyeang = ply:EyeAngles()
				local withShake = eyeang + (ShakeAng * 100 * FrameTime())
				local withShakeLimited = Angle(math.max(withShake.p, -89), withShake.y, 0) -- math max to prevent spinning while looking stright up
					
				eyeang = LerpAngle(ShakeLerp, eyeang, withShakeLimited)
				eyeang.r = 0
	
				ply:SetEyeAngles(eyeang)
			end
		end
	end

	function SWEP:DrawHUD()
		local ply = self:GetOwner()

		if ply:IsPlayer() then
			local FPS = math.min(1 / FrameTime() / 100, 0.5)/2

            if UnPredictedCurTime() >= nextScrenShake then
                ShakeAng = Angle(math.Rand(-FPS, FPS), math.Rand(-FPS, FPS), 0)
                nextScrenShake = UnPredictedCurTime()+0.1
            end
			
			if self:GetPull() then
				self:ShakeUpdate()

				SmoothPullProgress = Lerp(0.1, SmoothPullProgress, self.PullProgress)

				surface.SetDrawColor(255, 255, 255, 50)
				surface.DrawRect(sW/2-37.5, sH/2+93, 75, 6)

				surface.SetDrawColor(255, 255, 255, 255)
				surface.DrawRect(sW/2-37.5, sH/2+93, 75*SmoothPullProgress, 6)
			else
				SmoothPullProgress = 0
			end
		end

		BaseClass.DrawHUD(self)
	end
end

