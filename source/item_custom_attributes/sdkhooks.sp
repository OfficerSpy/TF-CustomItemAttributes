//CTFGameRules::ApplyOnDamageModifyRules happens in CTFPlayer::OnTakeDamage
//This callback should happen after its rules have already been applied
public Action PlayerOnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	bool bChanged = false;
	
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
				bChanged = true;
			}
			
			ApplyOnHitAttributes(weapon, victim, attacker, damage);
		}
	}
	
	return bChanged ? Plugin_Changed : Plugin_Continue;
}

//TODO: ApplyOnHitAttributes in base object take damage

public void ProjectileSpawnPost(int entity)
{
	int weapon = GetProjectileOriginalLauncher(entity);
	
	// PrintToChatAll("WEAPON %d", weapon);
	
	int launcher;
	
	if (weapon > 0)
		launcher = TF2_GetEntityOwner(weapon);
	
	if (launcher > 0)
	{
		// int weapon = TF2_GetClientActiveWeapon(launcher);
		if (weapon > 0)
		{
			float turnPower = TF2Attrib_HookValueFloat(0.0, "mod_projectile_heat_seek_power", weapon);
			float acceleration = TF2Attrib_HookValueFloat(0.0, "projectile_acceleration", weapon);
			float gravity = TF2Attrib_HookValueFloat(0.0, "projectile_gravity", weapon);
			if (turnPower != 0.0 || acceleration != 0.0 || gravity != 0.0)
			{
				HR_turnPower[entity] = turnPower;
				HR_acceleration[entity] = acceleration;
				HR_gravity[entity] = gravity;
				
				PrintToChatAll("turnPower %.2f", turnPower);
				PrintToChatAll("acceleration %.2f", acceleration);
				PrintToChatAll("gravity %.2f", gravity);
				
				SetEntityMoveType(entity, MOVETYPE_CUSTOM);
				
				VPhysicsDestroyObject(entity);
				
				HR_enabled[entity] = true;
				
				float min_dot_product = TF2Attrib_HookValueFloat(0.0, "mod_projectile_heat_aim_error", weapon);
				HR_minDotProduct[entity] = min_dot_product != 0.0 ? Cosine(DegToRad(UTIL_Clamp(min_dot_product, 0.0, 180.0))) : -0.25; //Shouldn't this be FastCos?
				
				float aim_time = TF2Attrib_HookValueFloat(0.0, "mod_projectile_heat_aim_time", weapon);
				HR_aimTIme[entity] = aim_time != 0.0 ? aim_time : 9999.0;
				
				float aim_start_time = TF2Attrib_HookValueFloat(0.0, "mod_projectile_heat_aim_start_time", weapon);
				HR_aimStartTime[entity] = aim_start_time != 0.0 ? aim_start_time : 0.0;
				
				float acceleration_time = TF2Attrib_HookValueFloat(0.0, "projectile_acceleration_time", weapon);
				HR_accelerationTime[entity] = acceleration_time != 0.0 ? acceleration_time : 9999.0;
				
				float acceleration_start = TF2Attrib_HookValueFloat(0.0, "projectile_acceleration_start_time", weapon);
				HR_accelerationStart[entity] = acceleration_start != 0.0 ? acceleration_start : 0.0;
				
				int follow_crosshair = TF2Attrib_HookValueInt(0, "mod_projectile_heat_follow_crosshair", weapon);
				HR_followCrosshair[entity] = follow_crosshair != 0 ? true : false;
				
				int no_predict_target_speed = TF2Attrib_HookValueInt(0, "mod_projectile_heat_no_predict_target_speed", weapon);
				HR_predictTargetSpeed[entity] = no_predict_target_speed != 0 ? false : true;
				
				HR_speed[entity] = CalculateProjectileSpeed(weapon);
				
				if (HR_speed[entity] < 0)
					HR_speed[entity] = -HR_speed[entity];
			}
			else
				HR_enabled[entity] = false;
		}
		
		PrintToServer("HR_minDotProduct %f", HR_minDotProduct[entity]);
		PrintToServer("HR_aimTIme %f", HR_aimTIme[entity]);
		PrintToServer("HR_aimStartTime %f", HR_aimStartTime[entity]);
		PrintToServer("HR_accelerationTime %f", HR_accelerationTime[entity]);
		PrintToServer("HR_accelerationStart %f", HR_accelerationStart[entity]);
		PrintToServer("HR_followCrosshair %d", HR_followCrosshair[entity] ? 1 : 0);
		PrintToServer("HR_predictTargetSpeed %d", HR_predictTargetSpeed[entity] ? 1 : 0);
		PrintToServer("HR_speed %f", HR_speed[entity]);
	}
}