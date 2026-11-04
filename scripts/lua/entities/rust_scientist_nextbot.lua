AddCSLuaFile()

ENT.Base 			= "base_nextbot"
ENT.Spawnable		= true

function ENT:SetupDataTables()
	self:NetworkVar( "Entity", 0, "ActiveWeapon" )
end

function ENT:Give(wepname)
    if CLIENT then return end
    if self:GetActiveLuaWeapon():IsValid() then self:GetActiveLuaWeapon():Remove() end

	local wep = ents.Create(wepname)
	
	if IsValid(wep) then
		wep:SetPos(self:GetPos())
		wep:SetOwner(self)
		wep:Spawn()
		wep:Activate()
		return self:SetupWeapon(wep)
	end
end

function ENT:GetActiveLuaWeapon()
	return self.m_ActualWeapon or NULL
end

function ENT:SetupWeapon(wep)
	if !IsValid(wep) then return end

	self:SetActiveWeapon(wep)

	self.m_ActualWeapon = wep

	local actwep = self:GetActiveLuaWeapon()
	
	wep:SetVelocity(vector_origin)
	wep:RemoveSolidFlags(FSOLID_TRIGGER)
	wep:SetOwner(self)
	wep:RemoveEffects(EF_ITEM_BLINK)
	wep:PhysicsDestroy()
	
	wep:SetParent(self)
	wep:SetMoveType(MOVETYPE_NONE)
	wep:AddEffects(EF_BONEMERGE)
	wep:AddSolidFlags(FSOLID_NOT_SOLID)
	wep:SetLocalPos(vector_origin)
	wep:SetLocalAngles(angle_zero)
	
	wep:SetTransmitWithParent(true)
	wep.CurAmmo = 15
	wep.Reloading = false
	return actwep
end



function ENT:Initialize()
	self:SetModel("models/player/darky_m/rust/scientist.mdl")
	
	self.LoseTargetDist	= 1200
	self.SearchRadius 	= 100
    self:Give("scientist_geiger")
    self:SetHealth(100)

	self.NextFire = CurTime()
	self.NextSound = CurTime()+1
	self.NextFootstep = CurTime()
	self.NextCrouch = CurTime()

	self.Healing = false
	self.Foot = false
	
	
end

function ENT:SetEnemy(ent)
	self.Enemy = ent
end

function ENT:GetEnemy()
	return self.Enemy
end

local ignore = GetConVar("ai_ignoreplayers")
local disableai = GetConVar("ai_disabled")

function ENT:HaveEnemy()
	if ignore:GetBool() then return end
	if self:GetEnemy() and IsValid(self:GetEnemy()) then
		if self:GetRangeTo(self:GetEnemy():GetPos()) > self.LoseTargetDist then
			return self:FindEnemy()
		elseif self:GetEnemy():IsPlayer() and !self:GetEnemy():Alive() then
			return self:FindEnemy()
		end	
		return true
	else
		return self:FindEnemy()
	end
end



function ENT:FindEnemy(radius)
	if ignore:GetBool() then return end
	local rs = radius or self.SearchRadius
	local _ents = ents.FindInSphere(self:GetPos(), rs)
	for k,v in ipairs(_ents) do
		if v:IsPlayer() and v:Alive() then
			self:SetEnemy(v)
			return true
		end
	end	
	self:SetEnemy(nil)
	return false
end

function ENT:RunBehaviour()
    local wep = self:GetActiveLuaWeapon()
	while true do
		if not disableai:GetBool() then 
			if self:HaveEnemy() then
				self:StartActivity(ACT_HL2MP_WALK_REVOLVER)
				self:Give("scientist_pistol")
				self:SetPoseParameter("aim_pitch",0)
				self.loco:SetDesiredSpeed(50)
				self.NextFire = CurTime()+10 
				self:GoAwayFromEnemy()
			else
				self:StartActivity(ACT_HL2MP_WALK_DUEL)
				self:Give("scientist_geiger")
				self:SetPoseParameter("aim_pitch",40)
				self.loco:SetDesiredSpeed(50)
				self:MoveToPos(self:GetPos() + Vector(math.Rand(-1, 1), math.Rand(-1, 1), 0) * 100)
				self:StartActivity(ACT_HL2MP_IDLE_DUEL)
			end
		else
			self:StartActivity(ACT_HL2MP_WALK_DUEL )
		end
		coroutine.wait(2)
	end
end	

function ENT:BodyUpdate()
	self:BodyMoveXY()
end

function ENT:GoAwayFromEnemy()
	local path = Path("Follow")
	path:SetMinLookAheadDistance(0)
	path:SetGoalTolerance(20)
	path:Compute(self, self:GetEnemy():GetPos()+Vector(0,0,50))
    
	if not path:IsValid() then return "failed" end

	while path:IsValid() and self:HaveEnemy() do
		if path:GetAge() > 0.1 then
			local vec = vec or self:GetPos()
			vec = (self:GetPos() - self:GetEnemy():GetPos()):Angle():Forward()*100
			path:Compute(self, self:GetPos()+vec)
			self:WeaponPrimaryAttack()
			self.loco:FaceTowards(self:GetEnemy():GetPos())
			if self.NextCrouch < CurTime() then
				self.NextCrouch = CurTime() + 5
				if math.random(1,4) == 2 then 
					self:StartActivity(ACT_HL2MP_WALK_CROUCH_REVOLVER)
					self.loco:SetDesiredSpeed(38)
				else
					self:StartActivity(ACT_HL2MP_WALK_REVOLVER)
					self.loco:SetDesiredSpeed(60)
				end
			end
        end
		path:Update(self)
		self.loco:FaceTowards(self:GetEnemy():GetPos())

		if (self.loco:IsStuck()) then
			self:HandleStuck()
			return "stuck"
		end

		coroutine.yield()
	end

	return "ok"
end

function ENT:OnInjured(info)
	self.Enemy = info:GetAttacker()
	self:FindEnemy(1200)
	self.NextFire = CurTime()+0.1
end

function ENT:OnKilled(dmginfo)
	self:EmitSound("rust_scientist/death-1.mp3")
	local rag = self:BecomeRagdoll(dmginfo)
	hook.Call("OnNPCKilled", GAMEMODE, self, dmginfo:GetAttacker(), dmginfo:GetInflictor())
	SafeRemoveEntityDelayed(self, 0.05)
end

function ENT:Reload()
	local wep = self:GetActiveLuaWeapon()
	if wep.Reloading then return end
	self:RestartGesture(ACT_HL2MP_GESTURE_RELOAD_REVOLVER)
	wep.Reloading = true
	timer.Simple(2.5, function()
		if self:IsValid() and wep:IsValid() then
			wep.CurAmmo = 15
			wep.Reloading = false
		end
	end)

	return
end

local syringesInstalled = weapons.Get("darky_syringe") and true or false 
local syringesInstalled_v2 = weapons.Get("rust_syringe") and true or false 

function ENT:WeaponPrimaryAttack()
	if self.NextFire > CurTime() then return end
	if not self:HaveEnemy() then return end
	if self.Healing then return end

	local wep = self:GetActiveLuaWeapon()

	if wep.CurAmmo <= 0 then
		self:Reload()
		return
	end
	if self:Health()<=30 and syringesInstalled or self:Health()<=30 and syringesInstalled_v2 then
		self:Heal()
	end

	self:SetPoseParameter("aim_pitch",0)

	ProtectedCall(function() 
        self.NextFire = CurTime()+0.4
        wep:EmitSound("rust_scientist/m92-attack.mp3", SNDLVL_GUNFIRE, 100, 1, CHAN_STATIC)
        self:RestartGesture(ACT_HL2MP_GESTURE_RANGE_ATTACK_PISTOL)
        local bullet = {}
        bullet.Num		= 1
        bullet.Src		= wep:GetPos()+Vector(0,0,50)
        bullet.Dir		= self:GetEnemy():GetPos()-wep:GetPos()
        bullet.Spread	= Vector(20, 20, 0)
        bullet.Tracer	= 1
        bullet.Force	= 1
        bullet.Damage	= 10
        bullet.AmmoType = "pistol"

        wep:FireBullets(bullet)
		wep.CurAmmo = wep.CurAmmo -1
		wep:MuzzleFlash()
    end)
end

function ENT:Heal()
	if self.Healing or self:GetActiveLuaWeapon().Reloading then return end
	self:RemoveAllGestures()
	self:AddGesture(ACT_HL2MP_GESTURE_RELOAD_PISTOL)

	if syringesInstalled_v2 then 
		self:EmitSound("darky_rust.syringe-inject-friend")
		self:Give("rust_syringe")
	else
		self:EmitSound("syringe.inject")
		self:Give("darky_syringe")
	end

	self.Healing = true

	timer.Simple(2, function()
		if self:IsValid() then
			self.Healing = false
			self:Give("scientist_pistol")
			self:SetHealth(50)
		end
	end)

	return
end

function ENT:Think()
	if CLIENT then return end

	if self.NextSound < CurTime() and not disableai:GetBool() then
		self.NextSound = CurTime()+math.random(9,18)
		self:EmitSound("rust_scientist/chatter-"..math.random(1,3)..".mp3")
	end

	local speed = (self.loco:GetVelocity().x + self.loco:GetVelocity().y)%1

	if self.NextFootstep < CurTime() and speed>0.6 then
		if self.Foot then
			self:EmitSound("NPC_Citizen.FootstepLeft")
		else
			self:EmitSound("NPC_Citizen.FootstepRight")
		end
		self.NextFootstep = CurTime()+0.6
		self.Foot = !self.Foot
	end
end

list.Set("NPC", "rust_scientist_nextbot", {
	Name = "Rust Scientist",
	Class = "rust_scientist_nextbot",
	Category = "Nextbot"
})