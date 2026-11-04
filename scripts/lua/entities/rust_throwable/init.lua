AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
	local mdl = self:GetModel()

	if not mdl or mdl == "" or string.find(mdl, "error") then
		self:SetModel("models/weapons/darky_m/rust/w_hammer.mdl")
	end

	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)

	local phys = self:GetPhysicsObject()
	self:NextThink(CurTime() + 0.1)

	if phys:IsValid() then
		phys:SetMass(self.ProjMass)
		phys:EnableGravity(false)
		phys:AddAngleVelocity(Vector(0, self.spinny, 0))

		phys:Wake()

		self.spinny = self.spinny or 1800
	end
	self.GravityMultiplier = 0.7
	if self.spinny> 100 then
		self.snd = self:StartLoopingSound("darky_rust.hatchet-stone-thrown-flight")
	else
		self.snd = self:StartLoopingSound("darky_rust.bow-arrow-flight")
	end

	local bounds = self:OBBMaxs() - self:OBBMins()
	
	if bounds.z > bounds.x and bounds.z > bounds.y then
		self.up = true
	elseif bounds.y > bounds.x and bounds.y > bounds.z then
		self.right = true
	end

	self:SetUseType(SIMPLE_USE)

	self.damage = self.damage or 15

	-- self.DestroyTime = CurTime() + GetConVar("tfa_rust_throwable_flytime"):GetInt()
	self.DestroyTime = CurTime() + 20
	self:SetNW2Bool("CanStick", true)
end

hook.Add("EntityRemoved", "clear parent rust throwable", function(ent)
	table.foreach(ent:GetChildren(), function(k, v)
		if v:GetClass() == "rust_throwable" then 
			v:SetParent(nil)
			v:SetMoveType(MOVETYPE_VPHYSICS)
			v:SetNW2Bool("CanStick", true)
			v:SetPos(v:GetPos()+Vector(0,0,8))
			v:GetPhysicsObject():EnableMotion(true)
		end
	end)
end)


function ENT:Think()
	self:NextThink(CurTime() + 0.3)
	if CurTime() > self.DestroyTime then
		self:Remove()
	end
	local parent = self:GetParent()
	if parent:IsValid() then
		if parent:IsPlayer() and not parent:Alive() then
			self:SetParent(nil)
			self:SetMoveType(MOVETYPE_VPHYSICS)
			self:SetPos(self:GetPos()+Vector(0,0,10))
			self:GetPhysicsObject():EnableMotion(true)
			self:SetNW2Bool("CanStick", true)
		end
	end
	-- debugoverlay.Cross(self:GetPos(), 3, 0.3, Color(255, 255, 255), true)
end

function ENT:PhysicsUpdate( phys )
    phys:ApplyForceCenter( Vector( 0, 0, (phys:GetMass() * -9.80665)*self.GravityMultiplier) )
end

function ENT:Stick()
	self.DestroyTime = CurTime() + 180
	-- self.DestroyTime = CurTime() + GetConVar("tfa_rust_throwable_sticktime"):GetInt()
	if IsValid(self) and self:GetNW2Bool("CanStick") then
		self:SetNW2Bool("CanStick", false)
		self:GetPhysicsObject():EnableMotion(false)
	end
end

function ENT:Parent(ent)
	self.DestroyTime = CurTime() + 180
	-- self.DestroyTime = CurTime() + GetConVar("tfa_rust_throwable_sticktime"):GetInt()
	if IsValid(self) and self:GetNW2Bool("CanStick") then
		self:SetParent(ent)
		self:SetNW2Bool("CanStick", false)
	end
end


function ENT:PhysicsCollide(data, phys)
	timer.Simple(0, function()  -- to prevent "Changing collision rules within a callback is likely to cause crashes!" errors
		if not self:IsValid() then return end

		self:StopLoopingSound(self.snd)

		if self.trail and self.trail:IsValid() then
			self.trail:Remove()
		end

		if self:GetNW2Bool("CanStick") then
			if not IsValid(self) then return end
			local owner = self:GetOwner()
			self:SetOwner(nil)
			local fwdang = self:GetAngles()
			local fwdvec

			if self.up then
				fwdvec = fwdang:Up()
			elseif self.right then
				fwdvec = fwdang:Right()
			else
				fwdvec = fwdang:Forward()
			end

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
			-- debugoverlay.Cross(traceres.HitPos, 1, 15.3, Color(255, 0, 255), true)
			-- debugoverlay.Cross(data.HitPos, 1, 15.3, Color(0, 255, 255), true)


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

			local canstick

			if self.StickType then
				if self.StickType == 0 then
					canstick = false
				elseif self.StickType == 1 then
					canstick = self:GetNW2Bool("CanStick") and data.Speed > 100 and traceres.HitNormal:Dot(fwdvec) < (-1 + data.Speed / 1000 * 1.0)
				elseif self.StickType == 2 then
					canstick = self:GetNW2Bool("CanStick") or true
				end
			end
			
			-- if ent:IsWorld() and canstick and GetConVar("tfa_rust_throwable_stick_in_world"):GetBool() then
			if ent:IsWorld() and canstick and true then
				util.Decal("ManhackCut", traceres.HitPos + traceres.HitNormal, traceres.HitPos - traceres.HitNormal)
				self:EmitSound(self.ImpactSound)
				self:SetPos(data.HitPos)
				local tmpang = data.HitNormal:Angle()
				tmpang:RotateAroundAxis(tmpang:Right(), 180)
				self:Stick()
			elseif ent:IsValid() then
				if canstick then
					if ent:GetClass() == "prop_ragdoll" and GetConVar("tfa_rust_throwable_stick_in_ragdolls"):GetBool() then
						local fx = EffectData()
						fx:SetOrigin(data.HitPos)
						util.Effect("BloodImpact", fx)
						self:Parent(ent)
					elseif ent:GetClass() == "prop_physics" and true then
					-- elseif ent:GetClass() == "prop_physics" and GetConVar("tfa_rust_throwable_stick_in_props"):GetBool() then
						util.Decal("ManhackCut", data.HitPos + data.HitNormal, data.HitPos - data.HitNormal)
						self:Parent(ent)
					-- elseif ent:IsNPC() and GetConVar("tfa_rust_throwable_stick_in_npc"):GetBool() and canstick then
					elseif ent:IsNPC() and true and canstick then
						local fx = EffectData()
						fx:SetOrigin(data.HitPos)
						util.Effect("BloodImpact", fx)
						self:Parent(ent)
					elseif ent:IsPlayer() then
						local fx = EffectData()
						fx:SetOrigin(data.HitPos)
						util.Effect("BloodImpact", fx)
						local bone = traceres.PhysicsBone
						if bone == 0 then
							bone = 1
						end
						if true then
						-- if GetConVar("tfa_rust_throwable_stick_in_player"):GetBool() then
							self:SetParent(nil)
							self:SetPos(data.HitPos)
							self:SetParent(ent, bone)
						end

					end
				end
				

				if data.HitEntity:IsPlayer() then
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
		end
		if self:IsValid() then
			self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
		end		
	end)
end

function ENT:Use(ply, caller)
	local classname = self:GetNW2String("ClassName")
	if not classname or classname == "" then return end

	if ply:IsPlayer() then
		if tonumber(classname) then
			ply:GiveAmmo(1, tonumber(classname))
			self:Remove()
		elseif ply:GetWeapon(classname) == NULL then
			ply:Give(classname)
			self:Remove()
		end
	end
end