#include <stocklib_officerspy/tf/tf_obj>
#include <stocklib_officerspy/tf/tf_player>
#include <stocklib_officerspy/mathlib/vector>
#include <stocklib_officerspy/mathlib/mathlib_base>
#include <stocklib_officerspy/shared/util_shared>
#include <stocklib_officerspy/shared/particle_parse>

float CalculateProjectileSpeed(int weapon)
{
	if (!IsValidEntity(weapon))
		return 0.0;
	
	float speed = 0.0;
	
	int weaponid = TF2Util_GetWeaponID(weapon);
	int projid = TF2Attrib_HookValueInt(0, "override_projectile_type", weapon);
	
	if (projid == 0)
	{
		projid = GetWeaponProjectileType(weapon);
	}
	
	if (projid == TF_PROJECTILE_ROCKET)
	{
		speed = 1100.0;
	}
	else if (projid == TF_PROJECTILE_FLARE)
	{
		speed = 2000.0;
	}
	else if (projid == TF_PROJECTILE_SYRINGE)
	{
		speed = 1000.0;
	}
	else if (projid == TF_PROJECTILE_ENERGY_RING)
	{
		int penetrate = TF2Attrib_HookValueInt(0, "energy_weapon_penetration", weapon);
		
		speed = penetrate ? 840.0 : 1200.0;
	}
	else if (projid == TF_PROJECTILE_BALLOFFIRE)
	{
		speed = 3000.0;
	}
	else
	{
		speed = GetProjectileSpeed(weapon);
	}
	
	if (weaponid != TF_WEAPON_GRENADELAUNCHER && weaponid != TF_WEAPON_CANNON && weaponid != TF_WEAPON_CROSSBOW && weaponid != TF_WEAPON_COMPOUND_BOW && weaponid != TF_WEAPON_GRAPPLINGHOOK && weaponid != TF_WEAPON_SHOTGUN_BUILDING_RESCUE)
	{
		float mult_speed = TF2Attrib_HookValueFloat(1.0, "mult_projectile_speed", weapon);
		speed *= mult_speed;
	}
	
	if (projid == TF_PROJECTILE_ROCKET)
	{
		int specialist = TF2Attrib_HookValueInt(0, "rocket_specialist", weapon);
		speed *= RemapVal(float(specialist), 1.0, 4.0, 1.15, 1.6);
	}
	
	return speed;
}