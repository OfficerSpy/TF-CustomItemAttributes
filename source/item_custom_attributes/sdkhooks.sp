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