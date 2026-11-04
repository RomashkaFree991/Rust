AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
	local mdl = self:GetModel()

	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)

	local phys = self:GetPhysicsObject()
	self:NextThink(CurTime() + 0.1)

	if (phys:IsValid()) then
		phys:Wake()
		phys:SetMass(1)
		self.spinny = self.spinny or 1800
		phys:AddAngleVelocity(Vector(0,self.spinny,0))
	end

	self.snd = self:StartLoopingSound("darky_rust.bow-arrow-flight")

	local bounds = self:OBBMaxs() - self:OBBMins()
	
	if bounds.z > bounds.x and bounds.z > bounds.y then
		self.up = true
	elseif bounds.y > bounds.x and bounds.y > bounds.z then
		self.right = true
	end

	self.damage = self.damage or 15
			
	self.DestroyTime = CurTime() + 10
	-- self.DestroyTime = CurTime() + GetConVar("tfa_rust_throwable_flytime"):GetInt()
end


function ENT:Think()
	self:NextThink(CurTime() + 0.3)
	if CurTime() > self.DestroyTime then
		self:Remove()
	end
end



function ENT:PhysicsCollide(data, phys)
	if not IsFirstTimePredicted() then return end

	timer.Simple(0, function()  -- to prevent "Changing collision rules within a callback is likely to cause crashes!" errors
		self:StopLoopingSound(self.snd)

		if not IsValid(self) then return end
		local owner = self:GetOwner()
		self:SetOwner(nil)
		local fwdang = self:GetAngles()
		local fwdvec
		if self.up then
			fwdvec = fwdang:Up()

			local ent = data.HitEntity
			if not IsValid(ent) and not (ent and ent:IsWorld()) then return end
			local dmg = self.damage * math.sqrt(data.Speed / 4000)

			if data.Speed > 200 and ent and not ent:IsWorld() and not ent:IsPlayer() then
				local dmginfo = DamageInfo()
				dmginfo:SetDamage(dmg)
				dmginfo:SetDamagePosition(data.HitPos)
				dmginfo:SetDamageForce(data.OurOldVelocity)
				dmginfo:SetInflictor(self)
				dmginfo:SetDamageType(DMG_SLASH)
				local att = self:GetPhysicsAttacker()

				if not IsValid(att) then
					att = owner
				end

				if not IsValid(att) then
					att = self
				end

				dmginfo:SetAttacker(att)
				ent:TakeDamageInfo(dmginfo)
			end

			local traceres = util.QuickTrace(self:GetPos(), data.OurOldVelocity, self)
			if not traceres.HitPos then return end


			if data.Speed > 50 then
				local soundtbl

				if self.HitSounds[traceres.MatType] then
					soundtbl = self.HitSounds[traceres.MatType]
				else
					soundtbl = self.HitSounds[MAT_DIRT]
				end

				local snd = soundtbl[math.random(1, #soundtbl)]
				self:EmitSound(snd)
			end

			ParticleEffect( "rust_explode", traceres.HitPos, Angle( 0, 0, 0 ) )

			if ent:IsWorld() then
				util.Decal("FadingScorch", traceres.HitPos + traceres.HitNormal, traceres.HitPos - traceres.HitNormal)
				self:EmitSound(self.ImpactSound)
			elseif ent:IsValid() then
				if ent:IsPlayer() then
					-- local fx = EffectData()
					-- fx:SetOrigin(data.HitPos)
					-- util.Effect("Sparks", fx)

					local bone = traceres.PhysicsBone
					if bone == 0 then
						bone = 1
					end
					local headpos = ent:GetBonePosition(ent:LookupBone("ValveBiped.Bip01_Head1"))
					if headpos == ent:GetPos() then
						headpos = ent:GetBoneMatrix(ent:LookupBone("ValveBiped.Bip01_Head1")):GetTranslation()
					end

					local dmginfo = DamageInfo()
					dmginfo:SetDamage(dmg)
					dmginfo:SetDamagePosition(data.HitPos)
					dmginfo:SetDamageForce(data.OurOldVelocity)
					dmginfo:SetInflictor(self)
					dmginfo:SetDamageType(DMG_SLASH)
					if traceres.HitPos:DistToSqr(headpos) < 150 then
						dmginfo:ScaleDamage(2)
						data.HitEntity:SetLastHitGroup(1)
					else
						dmginfo:ScaleDamage(1)
						data.HitEntity:SetLastHitGroup(0)
					end
					local att = self:GetPhysicsAttacker()
		
					if not IsValid(att) then
						att = owner
					end
	
					if not IsValid(att) then
						att = self
					end
	
					dmginfo:SetAttacker(att)
					ent:TakeDamageInfo(dmginfo)
				end
			end
			for i=1, math.random(1,3) do
				local i = ents.Create("rust_fire_ent")
				if i:IsValid() then
					i:SetPos(data.HitPos)
					i:Spawn()
					i:GetPhysicsObject():SetVelocity(Vector(traceres.HitNormal*(data.Speed/15)))
					ParticleEffectAttach("rust_fire_ent", PATTACH_ABSORIGIN_FOLLOW, i, 0)
				end
			end
			self:Remove()
		end
	end)
end
