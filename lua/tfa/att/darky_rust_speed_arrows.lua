if not ATTACHMENT then
	ATTACHMENT = {}
end

ATTACHMENT.Name = "High Velocity Arrow"
--ATTACHMENT.ID = "base" -- normally this is just your filename
ATTACHMENT.Description = {
	TFA.AttachmentColors["="], "Lighter, faster arrow that deals less damage.",
	TFA.AttachmentColors["+"], "60% more velocity",
	TFA.AttachmentColors["-"], "20% less damage",
}
ATTACHMENT.Icon = "entities/arrow.hv.png" --Revers to label, please give it an icon though!  This should be the path to a png, like "entities/tfa_ammo_match.png"
ATTACHMENT.ShortName = "HV"

ATTACHMENT.WeaponTable = {
	["VElements"] = {
		["hv_arrow"] = {
			["active"] = true
		}
	},
	["WElements"] = {
		["hv_arrow"] = {
			["active"] = true
		}
	},
	["Primary"] = {
		["Damage"] = function(wep,stat) return stat * 0.8 end,
		["ProjectileModel"] = function(wep,stat) return "models/weapons/darky_m/rust/metal_arrow.mdl" end,
		["ProjectileVelocity"] = function(wep,stat) return stat * 1.6 end,
	},
	["Bodygroups_V"] = {
		[2] = 2,
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
