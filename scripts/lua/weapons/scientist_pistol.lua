SWEP.PrintName = "pistol"
SWEP.Spawnable = false
SWEP.AdminSpawnable = false

if DARKY_RUST and DARKY_RUST.firearms == true then
    SWEP.WorldModel = "models/weapons/darky_m/rust/w_m92.mdl"
else
    SWEP.WorldModel = "models/weapons/w_pist_elite_single.mdl"
end