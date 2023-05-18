public void ProjectileSpawnPost(int entity)
{
	int weapon = GetEntPropEnt(entity, Prop_Send, "m_hLauncher");
		
	if (weapon != -1 && TF2Util_IsEntityWeapon(weapon))
	{
		SetCustomProjectileModel(weapon, entity);
		
		char particleName[128]; TF2Attrib_HookValueString("", "projectile_trail_particle", weapon, particleName, sizeof(particleName));
		if (strlen(particleName) > 0)
		{
			float color0[3], color1[3];
			
			// color0 = GetWeaponParticleColor(weapon, 1);
			// color1 = GetWeaponParticleColor(weapon, 2);
			
			//FIXME: this works in RequestFrame but not here?
			//I'm not sure how that makes sense since overload 1 works in SpawnPost
			//Also the original particle is removed even with reset set to false
			if (StrContains(particleName, "~") != -1)
			{
				ReplaceString(particleName, sizeof(particleName), "~", "");
				DispatchParticleEffect3(particleName, PATTACH_ABSORIGIN_FOLLOW, entity, "trail", color0, color1, true, true);
			}
			else
				DispatchParticleEffect3(particleName, PATTACH_ABSORIGIN_FOLLOW, entity, "trail", color0, color1, true, false);
		}
	}
}

//CTFGameRules::ApplyOnDamageModifyRules happens in CTFPlayer::OnTakeDamage
//This callback should happen after its rules have already been applied
public Action PlayerOnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (IsValidClientIndex(attacker))
	{
		if (IsValidEntity(weapon))
		{
			float dmgMult = 1.0;
			
			if (IsMiniBoss(victim))
				dmgMult = TF2Attrib_HookValueFloat(dmgMult, "mult_dmg_vs_giants", weapon);
			
			if (dmgMult != 1.0)
			{
				damage *= dmgMult;
				return Plugin_Changed;
			}
		}
	}
	
	return Plugin_Continue;
}