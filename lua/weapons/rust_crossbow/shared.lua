SWEP.Base = "tfa_gun_base"

SWEP.PrintName = "Crossbow"
SWEP.Author = "Darky"
SWEP.Contact = ""
SWEP.Purpose = ""
SWEP.Instructions = ""

SWEP.Category = "TFA Rust Weapons"

SWEP.Spawnable= true
SWEP.AdminSpawnable= true
SWEP.AdminOnly = false
SWEP.CSMuzzleFlashes = false
SWEP.MuzzleFlashEffect = nil

SWEP.MuzzleAttachment			= "0"						-- "1" CSS models / "muzzle" hl2 models
SWEP.ShellAttachment			= "1"						-- "2" CSS models / "shell" hl2 models
SWEP.MuzzleFlashEnabled 		= true


SWEP.LuaShellEject = false 


SWEP.HoldType = "shotgun"
SWEP.ReloadHoldTypeOverride = "physgun"
SWEP.ViewModelFOV = 65
SWEP.ViewModelFlip = false
SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/darky_m/rust/c_crossbow.mdl"
SWEP.WorldModel = "models/weapons/darky_m/rust/w_crossbow.mdl"
SWEP.ShowViewModel = true
SWEP.ShowWorldModel = true
SWEP.ViewModelBoneMods = {
}

SWEP.Akimbo = false


SWEP.Secondary.BashLength = 54
SWEP.Secondary.BashDelay = 7/60
SWEP.Secondary.BashDamage = 30





SWEP.IronSightsPos = Vector(-6.893, -1.732, 3.26)
SWEP.IronSightsAng = Vector(2.888, -3.25, 3.148)

SWEP.IronSightsPos_msHolosight = Vector(-7.315, -0.1, 6.52)
SWEP.IronSightsAng_msHolosight = Vector(-7.15, -3.75, 2.753)

SWEP.IronSightsPos_Holo = Vector(-7.321, -0.1, 6.639)
SWEP.IronSightsAng_Holo = Vector(-7.4, -3.93, 2.753)

SWEP.IronSightsPos_4xscope = Vector(-7.321, -0.1, 6.639)
SWEP.IronSightsAng_4xscope = Vector(-4.51, -3.89, 2.753)

SWEP.IronSightsPos_8xscope = Vector(-7.333, -0.1, 6.657)
SWEP.IronSightsAng_8xscope = Vector(-7.65, -4.2, 2.753)

SWEP.IronSightsFOV = 40

SWEP.RunSightsPos  = Vector(6.23, -5.226, -0.59)
SWEP.RunSightsAng = Vector(-8.553, 46.076, -5.395)



SWEP.RTOpaque	= true

SWEP.Type = "Crossbow"

SWEP.AutoSwitchTo = true
SWEP.AutoSwitchFrom = true

SWEP.Slot = 1
SWEP.SlotPos = 74
 
SWEP.UseHands = true

SWEP.FiresUnderwater = true

SWEP.DrawCrosshair = true

SWEP.DrawAmmo = true

SWEP.ReloadSound = ""



SWEP.Primary.KickUp = 1.5 
SWEP.Primary.KickDown = 1.5 
SWEP.Primary.KickHorizontal = .5 
SWEP.Primary.StaticRecoilFactor = 0.8 
SWEP.Primary.Spread = .03 
SWEP.Primary.IronAccuracy = .01 

SWEP.Primary.Range = (200 * 16) 
SWEP.Primary.RangeFalloff = 0.7

SWEP.IronRecoilMultiplier = 1 
SWEP.CrouchAccuracyMultiplier = 1 

SWEP.MoveSpeed = 1 
SWEP.IronSightsMoveSpeed = 1 

SWEP.SelectiveFire = false 
SWEP.DisableBurstFire = true
SWEP.OnlyBurstFire = false

SWEP.IronSightTime = 0.2

SWEP.VMPos = Vector(0, 0, 0)
SWEP.VMAng = Vector(0,0,0)

SWEP.VMPos_Additive = false

SWEP.Primary.Ammo = "XBowBolt"
SWEP.Primary.Sound = Sound("weapons/rust_mp3/crossbow-attack-1.mp3")
SWEP.Primary.Damage = 60
SWEP.Primary.TakeAmmo = 1
SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Automatic = false
SWEP.Primary.Recoil = 1.2
SWEP.Primary.RPM = 200

SWEP.SequenceLengthOverride = {
	[ACT_VM_RELOAD] = 5
}

SWEP.Secondary.ClipSize = 0
SWEP.Secondary.DefaultClip = 0
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
SWEP.DisableChambering = true

SWEP.RunSightsPos = Vector(1.222, 0, -1.415)
SWEP.RunSightsAng = Vector(-16.848, -1.236, -3.247)

SWEP.Attachments = {
	[1] = {atts = {"darky_rust_fire_arrows", "darky_rust_bone_arrows", "darky_rust_speed_arrows"}},
	[2] = {atts = {"darky_rust_ms_holosight", "darky_rust_holo", "darky_rust_4x", "darky_rust_8x"}},
	[3] = {atts = {"darky_rust_laser", "darky_rust_flash"}},
}
local rust_holo_material = Material( "models/darky_m/rust_weapons/mods/holosight.reticle.standard.png" )
local rust_ms_material = Material( "models/darky_m/rust_weapons/mods/xhair_highvis.png" )

SWEP.VElements = {
	["ms_holosight"] = { type = "Model", model = "models/weapons/darky_m/rust/mod_ms_holosight.mdl", bone = "main", rel = "", pos = Vector(0, -4.3, 3.5), angle = Angle(180, -90, -90), size = Vector(0.9, 0.9, 0.9), color = Color(255, 255, 255, 255), surpresslightning = false, material = "", skin = 0, bonemerge = false, active = false, bodygroup = {} },
	["ms_holosight_xhair"] = { type = "Quad", bone = "main", rel = "ms_holosight", pos = Vector(0.519, 0, 0), angle = Angle(-90, 0, 90), size = 0.01, active = false, draw_func = function()   surface.SetDrawColor(255,255,255,255) surface.SetMaterial( rust_ms_material ) surface.DrawTexturedRect(-70, -70, 140, 140) end },

	["holosight"] = { type = "Model", model = "models/weapons/darky_m/rust/mod_holo.mdl", bone = "main", rel = "", pos = Vector(-0.08, -4.3, 4.5), angle = Angle(180, -90, 0), size = Vector(0.8, 0.8, 0.8), color = Color(255, 255, 255, 255), surpresslightning = false, material = "", skin = 0, bonemerge = false, active = false, bodygroup = {} },
	["holosight_lens"] = { type = "Quad", bone = "main", rel = "holosight", pos = Vector(0.47, -0.123, 0.3), angle = Angle(0, -90, 0), size = 0.01, active = false, draw_func = function()     surface.SetDrawColor(255,0,0,255) surface.SetMaterial( rust_holo_material ) surface.DrawTexturedRect(-40, -40, 80, 80) end },
	["8xscope"] = { type = "Model", model = "models/weapons/darky_m/rust/mod_8xScope.mdl", bone = "main", rel = "", pos = Vector(0.04, -3.311, 5), angle = Angle(180, 0, -90), size = Vector(0.9, 0.7, 0.9), color = Color(255, 255, 255, 255), surpresslightning = false, materials = {"","","!tfa_rtmaterial"}, skin = 0, bonemerge = false, active = false, bodygroup = {} },
	["4xscope"] = { type = "Model", model = "models/weapons/darky_m/rust/mod_reddot.mdl", bone = "main", rel = "", pos = Vector(0.23, -4.7, 4), angle = Angle(0, 0, -90), size = Vector(0.9, 0.9, 0.9), color = Color(255, 255, 255, 255), surpresslightning = false, materials = {"","","!tfa_rtmaterial"}, skin = 0, bonemerge = false, active = false, bodygroup = {} },
	

	["lasersight"] = { type = "Model", model = "models/weapons/darky_m/rust/mod_laser.mdl", bone = "main", rel = "", pos = Vector(0, -0.2, 7.4+12), angle = Angle(0, -90, 180), size = Vector(0.9, 0.7, 0.9), color = Color(255, 255, 255, 255), surpresslightning = false, material = "", skin = 0, bonemerge = false, active = false, bodygroup = {} },
	["flashlight"] = { type = "Model", model = "models/weapons/darky_m/rust/mod_pistol_flash.mdl", bone = "main", rel = "", pos = Vector(0, 0.2, 7.4+12), angle = Angle(0, 90, 180), size = Vector(0.9, 0.9, 0.9), color = Color(255, 255, 255, 255), surpresslightning = false, material = "", skin = 0, bonemerge = false, active = false, bodygroup = {} },
	["laser_beam"] = { type = "Model", model = "models/tfa/lbeam.mdl", bone = "main", rel = "lasersight", pos = Vector(0.5,0,0), angle = Angle(-90, 0, 0), size = Vector(2, 0.5, 0.5), color = Color(255, 255, 255, 32), surpresslightning = false, material = "", skin = 0, bodygroup = {}, bonemerge = false, active = false },

}
SWEP.WElements = {
	["w_offset"] = { type = "Quad", bone = "main", rel = "", pos = Vector(3.5, 0.7, -1.6), angle = Angle(0, -90, -100), size = 1, active = true, draw_func = nil },

	["ms_holosight"] = { type = "Model", model = "models/weapons/darky_m/rust/w_mod_ms_holosight.mdl", bone = "main", rel = "w_offset", pos = Vector(0, -4.3, 3.5), angle = Angle(180, -90, -90), size = Vector(0.9, 0.9, 0.9), color = Color(255, 255, 255, 255), surpresslightning = false, material = "", skin = 0, bonemerge = false, active = false, bodygroup = {} },

	["holosight"] = { type = "Model", model = "models/weapons/darky_m/rust/w_mod_holo.mdl", bone = "main", rel = "w_offset", pos = Vector(-0.08, -4.3, 4.5), angle = Angle(180, -90, 0), size = Vector(0.8, 0.8, 0.8), color = Color(255, 255, 255, 255), surpresslightning = false, material = "", skin = 0, bonemerge = false, active = false, bodygroup = {} },
	["8xscope"] = { type = "Model", model = "models/weapons/darky_m/rust/w_mod_8xScope.mdl", bone = "main", rel = "w_offset", pos = Vector(0.04, -3.311, 5), angle = Angle(180, 0, -90), size = Vector(0.9, 0.7, 0.9), color = Color(255, 255, 255, 255), surpresslightning = false, material = "", skin = 0, bonemerge = false, active = false, bodygroup = {} },
	["4xscope"] = { type = "Model", model = "models/weapons/darky_m/rust/w_mod_reddot.mdl", bone = "main", rel = "w_offset", pos = Vector(0.23, -4.7, 4), angle = Angle(0, 0, -90), size = Vector(0.9, 0.9, 0.9), color = Color(255, 255, 255, 255), surpresslightning = false, material = "", skin = 0, bonemerge = false, active = false, bodygroup = {} },
	

	["lasersight"] = { type = "Model", model = "models/weapons/darky_m/rust/w_mod_laser.mdl", bone = "main", rel = "w_offset", pos = Vector(0, -0.2, 7.4+12), angle = Angle(0, -90, 180), size = Vector(0.9, 0.7, 0.9), color = Color(255, 255, 255, 255), surpresslightning = false, material = "", skin = 0, bonemerge = false, active = false, bodygroup = {} },
	["flashlight"] = { type = "Model", model = "models/weapons/darky_m/rust/w_mod_pistol_flash.mdl", bone = "main", rel = "w_offset", pos = Vector(0, 0.2, 7.4+12), angle = Angle(0, 90, 180), size = Vector(0.9, 0.9, 0.9), color = Color(255, 255, 255, 255), surpresslightning = false, material = "", skin = 0, bonemerge = false, active = false, bodygroup = {} },
	["laser_dot"] = { type = "Sprite", sprite = "effects/tfalaserdot", bone = "main", rel = "lasersight", pos = Vector(0.4, 0, -2), size = { x = 4, y = 4 }, color = Color(255, 0, 0, 255), nocull = true, additive = true, vertexalpha = true, vertexcolor = true, ignorez = false, active = false},
	["flash_sprite"] = { type = "Sprite", sprite = "effects/blueflare1", bone = "main", rel = "flashlight", pos = Vector(0.3, 0, -4), size = { x = 15, y = 15 }, color = Color(255, 255, 255, 255), nocull = true, additive = true, vertexalpha = true, vertexcolor = true, ignorez = false, active = false}
}
SWEP.data 					= {}
SWEP.data.ironsights = 1
SWEP.Secondary.IronFOV 		= 70
SWEP.IronSightsSensitivity 		= 1




SWEP.Sights_Mode = TFA.Enum.ANI 
SWEP.Sprint_Mode = TFA.Enum.Lua 
SWEP.Idle_Mode = TFA.Enum.IDLE_BOTH 
SWEP.Idle_Blend = 0.25
SWEP.Idle_Smooth = 0.05 

SWEP.ShellAttachment = "1" 
SWEP.MuzzleAttachment = "0" 
SWEP.MuzzleFlashEnabled = false    
SWEP.LaserDistance = 4000
SWEP.LaserDistanceVisual = 4000


SWEP.IronAnimation = {
}

SWEP.EventTable = {
	[ACT_VM_RELOAD] = {															
		{ ["time"] = 0.0, ["type"] = "lua", ["value"] = 
			function( wep, viewmodel, ifp ) 
				if wep.Attachments[1].sel == 1 then
					ParticleEffectAttach( "rust_fire_vm", PATTACH_POINT_FOLLOW, viewmodel, 2 )
				end 
			end,
		["client"] = true, ["server"] = false},
	},	   
	[ACT_VM_PRIMARYATTACK] = {
		{ ["time"] = 0.0, ["type"] = "lua", ["value"] = function( wep, viewmodel, ifp ) viewmodel:StopParticles() end, ["client"] = true, ["server"] = false}, 
	},	  
}


SWEP.Primary.Projectile = "rust_throwable"
SWEP.Primary.ProjectileModel = "models/weapons/darky_m/rust/wood_arrow.mdl"
SWEP.Primary.ProjectileVelocity = 4000
SWEP.Primary.ProjectileSpin = 0
SWEP.Primary.ProjectileStartAng = 90
SWEP.ProjectileMass = 1
SWEP.ProjectileGravityMultiplier = 0.7
-- 90, -90 for spears
-- 900, -45 for spinny things
SWEP.Primary.ProjectileStickType = 2 -- 0: never stuck in objects; 1: stucks in objects, sometimes rebounds; 2: always stuck in objects


function SWEP:ShootBullet()
	self:EmitSound(self:GetStat("Primary.Sound"))

	if SERVER then
		-- timer.Simple(0, function()
		if not self:IsValid() then return end
			

		local ent = ents.Create(self:GetStat("Primary.Projectile"))
		local ang = self:GetOwner():EyeAngles()

		ang:RotateAroundAxis(ang:Right(), math.Rand(0, 0.5) - 0.25)
		ang:RotateAroundAxis(ang:Up(), math.Rand(0, 0.5) - 0.25)

		local dir = ang:Forward()

		if ent:IsValid() then
			ent:SetPos(self:GetOwner():GetShootPos())
			ent:SetAngles(self:GetOwner():EyeAngles()+Angle(self:GetStat("Primary.ProjectileStartAng"),0,0))
			ent:SetModel(self:GetStat("Primary.ProjectileModel"))
			ent:SetPhysicsAttacker(self:GetOwner())
			ent:SetOwner(self:GetOwner())
			ent.damage = self:GetStat("Primary.Damage")
			ent.spinny = 0
			ent.StickType = self:GetStat("Primary.ProjectileStickType")
			ent.ProjMass = self.ProjectileMass
			ent.GravityMultiplier = self.ProjectileGravityMultiplier
			ent:Spawn()


			local phys = ent:GetPhysicsObject()
			local vel = self:GetStat("Primary.ProjectileVelocity")

			if IsValid(phys) then
				phys:SetVelocity(dir * vel)
			end
			
			self:GetOwner():SetAnimation(PLAYER_ATTACK1)
			ent:SetLocalAngularVelocity(Angle(100,200,50))
			self:TakePrimaryAmmo(1)

			ent:SetNW2String("ClassName", self:GetPrimaryAmmoType())
			if self.Primary.Ammo == "rust_fire_arrows" then
				ParticleEffectAttach("rust_fire", PATTACH_POINT_FOLLOW, ent, 1)
			end

			if vel >= 2000 then
				ent.trail = util.SpriteTrail(ent, 0, Color(255, 255, 255), false, 12, 0, 0.15, 1/12 * 0.5, "trails/laser")
			else
				self:EmitSound("darky_rust.throw-item-small")
			end
		end
		-- end)
	end
end