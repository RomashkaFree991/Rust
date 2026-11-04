if not ATTACHMENT then
	ATTACHMENT = {}
end

ATTACHMENT.Name = "Bone Arrow"
--ATTACHMENT.ID = "base" -- normally this is just your filename
ATTACHMENT.Description = {
	TFA.AttachmentColors["="], "An Arrow equipped with a large bone arrowhead making it very easy to hit targets at the expense of damage",
	TFA.AttachmentColors["+"], "Bigger hitbox",
	TFA.AttachmentColors["-"], "10% less velocity",
	TFA.AttachmentColors["-"], "20% less damage",
}
ATTACHMENT.Icon = "entities/arrow.bone.png" --Revers to label, please give it an icon though!  This should be the path to a png, like "entities/tfa_ammo_match.png"
ATTACHMENT.ShortName = "BONE"

ATTACHMENT.WeaponTable = {
	["VElements"] = {
		["bone_arrow"] = {
			["active"] = true
		}
	},
	["WElements"] = {
		["bone_arrow"] = {
			["active"] = true
		}
	},
	["Primary"] = {
		["Damage"] = function(wep,stat) return stat * 0.8 end,
		["ProjectileModel"] = function(wep,stat) return "models/weapons/darky_m/rust/bone_arrow.mdl" end,
		["ProjectileVelocity"] = function(wep,stat) return stat * 0.9 end,
	},
	["Bodygroups_V"] = {
		[2] = 1,
	},	
	
}


function ATTACHMENT:Attach(wep)
	wep:Unload()
	wep.Pull = false
	wep.Keydown = false
end

function ATTACHMENT:Detach(wep)
	wep:Unload()
	wep.Pull = false
	wep.Keydown = false
end



if not TFA_ATTACHMENT_ISUPDATING then
	TFAUpdateAttachments()
end
