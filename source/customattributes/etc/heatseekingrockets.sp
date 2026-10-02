// There is a MUCH better way to do this now, but we will not have access to it until SM 1.13, so for now this is the best we can do

enum struct HomingRockets
{
	bool enable;
	bool ignore_disguised_spies;
	bool ignore_stealthed_spies;
	bool follow_crosshair;
	bool predict_target_speed;
	float speed;
	float turn_power;
	float min_dot_product;
	float aim_time;
	float aim_start_time;
	float acceleration;
	float acceleration_time;
	float acceleration_start;
	float gravity;
	bool homed_in;
	bool returning;
	int return_to_sender;
	float homed_in_angle[3];
	
	void Construct()
	{
		this.enable = false;
		this.ignore_disguised_spies = true;
		this.ignore_stealthed_spies = true;
		this.follow_crosshair = false;
		this.predict_target_speed = true;
		this.speed = 1.0;
		this.turn_power = 0.0;
		this.min_dot_product = -0.25;
		this.aim_time = 9999.0;
		this.aim_start_time = 0.0;
		this.acceleration = 0.0;
		this.acceleration_time = 9999.0;
		this.acceleration_start = 0.0;
		this.gravity = 0.0;
		this.homed_in = false;
		this.returning = false;
		this.return_to_sender = 0;
	}
}

HomingRockets g_arrHoming[MAX_EDICTS + 1];

void CheckHomingRockets(int proj)
{
	int weapon = GetEntPropEnt(proj, Prop_Send, "m_hOriginalLauncher");
	int launcher = weapon;
	
	if (launcher == -1)
	{
		//A NULL launcher would indicate this projectile wasn't shot out by a player...
		launcher = BaseEntity_GetOwnerEntity(proj);
		
		//Possibly shot out by a sentry?
		if (launcher != -1 && BaseEntity_IsBaseObject(launcher) && TF2_GetBuilder(launcher) != -1)
			launcher = TF2_GetBuilder(launcher);
	}
	
	if (launcher != -1)
	{
		int provider = weapon != -1 ? weapon : launcher;
		
		if (provider != -1 && (weapon == -1 || BaseEntity_GetOwnerEntity(weapon) != -1 && BaseEntity_IsPlayer(BaseEntity_GetOwnerEntity(weapon))))
		{
			g_arrHoming[proj].Construct();
			
			g_arrHoming[proj].turn_power = TF2Attrib_HookValueFloat(g_arrHoming[proj].turn_power, "mod_projectile_heat_seek_power", provider);
			g_arrHoming[proj].acceleration = TF2Attrib_HookValueFloat(g_arrHoming[proj].acceleration, "projectile_acceleration", provider);
			g_arrHoming[proj].gravity = TF2Attrib_HookValueFloat(g_arrHoming[proj].gravity, "projectile_gravity", provider);
			g_arrHoming[proj].return_to_sender = TF2Attrib_HookValueInt(g_arrHoming[proj].return_to_sender, "return_to_sender", provider);
			if (g_arrHoming[proj].turn_power != 0.0 || g_arrHoming[proj].acceleration != 0.0 || g_arrHoming[proj].gravity != 0.0 || g_arrHoming[proj].return_to_sender != 0)
			{
				SetEntityMoveType(proj, MOVETYPE_CUSTOM);
				//TODO: proj->VPhysicsDestroyObject();
				
				DHooks_HomingRocket(proj);
				
				g_arrHoming[proj].enable = true;
				float min_dot_product = TF2Attrib_HookValueFloat(0.0, "mod_projectile_heat_aim_error", provider);
				if (min_dot_product != 0.0)
					g_arrHoming[proj].min_dot_product = Cosine(DegToRad(ClampFloat(min_dot_product, 0.0, 180.0))); //Should be FastCos... but what is it?
				
				float aim_time = TF2Attrib_HookValueFloat(0.0, "mod_projectile_heat_aim_time", provider);
				if (aim_time != 0.0)
					g_arrHoming[proj].aim_time = aim_time;
				
				float aim_start_time = TF2Attrib_HookValueFloat(0.0, "mod_projectile_heat_aim_start_time", provider);
				if (aim_start_time != 0.0)
					g_arrHoming[proj].aim_start_time = aim_start_time;
				
				float acceleration_time = TF2Attrib_HookValueFloat(0.0, "projectile_acceleration_time", provider);
				if (acceleration_time != 0.0)
					g_arrHoming[proj].acceleration_time = acceleration_time;
				
				float acceleration_start = TF2Attrib_HookValueFloat(0.0, "projectile_acceleration_start_time", provider);
				if (acceleration_start != 0.0)
					g_arrHoming[proj].acceleration_start = acceleration_start;
				
				int follow_crosshair = TF2Attrib_HookValueInt(0, "mod_projectile_heat_follow_crosshair", provider);
				if (follow_crosshair != 0)
					g_arrHoming[proj].follow_crosshair = true;
				
#if 0
				int no_predict_target_speed = TF2Attrib_HookValueInt(0, "mod_projectile_heat_no_predict_target_speed", provider);
				if (follow_crosshair != 0)
					g_arrHoming[proj].predict_target_speed = false;
#endif
				
				g_arrHoming[proj].speed = weapon != -1 ? CalculateProjectileSpeed(weapon) : 1100.0;
				
				if (g_arrHoming[proj].speed < 0)
				{
					g_arrHoming[proj].speed = -g_arrHoming[proj].speed;
				}
			}
			else
				g_arrHoming[proj].enable = false;
		}
	}
}

//CBaseEntity *ent, Vector *pNewPosition, Vector *pNewVelocity, QAngle *pNewAngles, QAngle *pNewAngVelocity
bool PerformCustomPhysics(int ent, float pNewPosition[3], float pNewVelocity[3], float pNewAngles[3], float pNewAngVelocity[3])
{
	if (!g_arrHoming[ent].enable)
		return false;
	
	float time = float(GetEntProp(ent, Prop_Send, "m_flSimulationTime")) - float(GetEntProp(ent, Prop_Send, "m_flAnimTime"));
	
	float speed_calculated = g_arrHoming[ent].speed + g_arrHoming[ent].acceleration * ClampFloat(time - g_arrHoming[ent].acceleration_start, 0.0, g_arrHoming[ent].acceleration_time);
	if (speed_calculated < 0.0 && g_arrHoming[ent].return_to_sender && !g_arrHoming[ent].returning)
	{
		g_arrHoming[ent].returning = true;
		g_arrHoming[ent].speed = 0.0;
		g_arrHoming[ent].acceleration = -g_arrHoming[ent].acceleration;
		g_arrHoming[ent].acceleration_start = time;
	}
	
	float interval = (3000.0 / speed_calculated) * 0.014;
	
	if (!g_arrHoming[ent].returning && g_arrHoming[ent].turn_power != 0.0 && time >= g_arrHoming[ent].aim_start_time && time < g_arrHoming[ent].aim_time && GetGameTickCount() % RoundToCeil(interval / GetTickInterval()) == 0)
	{
		float target_vec[3];
		
		if (g_arrHoming[ent].follow_crosshair)
		{
			int owner = BaseEntity_GetOwnerEntity(ent);
			if (owner != -1)
			{
				float vForward[3];
				float vEyeAngles[3]; GetClientEyeAngles(owner, vEyeAngles);
				GetAngleVectors(vEyeAngles, vForward, NULL_VECTOR, NULL_VECTOR);
				
				float vEyePosition[3]; GetClientEyePosition(owner, vEyePosition);
				float vModified[3];
				vModified[0] = vEyePosition[0] + 4000.0 * vForward[0];
				vModified[1] = vEyePosition[1] + 4000.0 * vForward[1];
				vModified[2] = vEyePosition[2] + 4000.0 * vForward[2];
				
				StringMap adtFilterProps = new StringMap();
				adtFilterProps.SetValue("m_pPassEnt", owner);
				adtFilterProps.SetValue("m_collisionGroup", COLLISION_GROUP_NONE);
				TR_TraceRayFilter(vEyePosition, vModified, MASK_SHOT, RayType_EndPoint, TraceFilter_HomingRocketsFollowCrosshair, adtFilterProps);
				adtFilterProps.Close();
				
				TR_GetEndPosition(target_vec);
			}
		}
		else
		{
			float target_dotproduct = FLT_MIN;
			int target_player = -1;
			
			for (int i = 1; i <= MaxClients; i++)
			{
				if (!IsClientInGame(i))
					continue;
				
				if (!IsPlayerAlive(i))
					continue;
				
				if (TF2_GetClientTeam(i) == TFTeam_Spectator)
					continue;
				
				if (GetClientTeam(i) == BaseEntity_GetTeamNumber(ent))
					continue;
				
				if (g_arrHoming[ent].ignore_disguised_spies)
				{
					if (TF2_IsPlayerInCondition(i, TFCond_Disguised) && TF2_GetDisguiseTeam(i) == view_as<TFTeam>(BaseEntity_GetTeamNumber(ent)))
					{
						//Ignore players disguised as our team
						continue;
					}
				}
				
				if (g_arrHoming[ent].ignore_stealthed_spies)
				{
					if (TF2_IsStealthed(i) && TF2_GetPercentInvisible(i) >= 0.75 && !TF2_IsPlayerInCondition(i, TFCond_CloakFlicker) && !TF2_IsPlayerInCondition(i, TFCond_OnFire) && !TF2_IsPlayerInCondition(i, TFCond_Jarated) && !TF2_IsPlayerInCondition(i, TFCond_Bleeding))
					{
						//Ignore stealthed players that are not exposed
						continue;
					}
				}
				
				float delta[3];
				float vecPlayerWSC[3]; CBaseEntity(i).WorldSpaceCenter(vecPlayerWSC);
				float vecProjWSC[3]; CBaseEntity(ent).WorldSpaceCenter(vecProjWSC);
				SubtractVectors(vecPlayerWSC, vecProjWSC, delta);
				
				float mindotproduct = g_arrHoming[ent].min_dot_product;
				float dotproduct = GetVectorDotProduct(Vector_Normalized(delta), Vector_Normalized(pNewVelocity));
				
				if (dotproduct < mindotproduct)
					continue;
				
				if (dotproduct > target_dotproduct)
				{
					bool noclip = GetEntityMoveType(ent) == MOVETYPE_NOCLIP;
					
					if (!noclip)
					{
						TR_TraceRayFilter(vecPlayerWSC, vecProjWSC, MASK_SOLID_BRUSHONLY, RayType_EndPoint, TraceFilter_HomingRockets, i);
					}
					
					if (noclip || !TR_DidHit() || TR_GetEntityIndex() == ent)
					{
						target_player = i;
						target_dotproduct = dotproduct;
					}
				}
			}
			if (target_player != -1)
			{
				float vecPlayerWSC[3]; CBaseEntity(target_player).WorldSpaceCenter(vecPlayerWSC);
				target_vec = vecPlayerWSC;
				
				float vecProjWSC[3]; CBaseEntity(ent).WorldSpaceCenter(vecProjWSC);
				float target_distance = GetVectorDistance(vecProjWSC, vecPlayerWSC);
				
				if (g_arrHoming[ent].predict_target_speed)
				{
					float vecPlayerAbsVelocity[3]; CBaseEntity(target_player).GetAbsVelocity(vecPlayerAbsVelocity);
					target_vec[0] += vecPlayerAbsVelocity[0] * target_distance / speed_calculated;
					target_vec[1] += vecPlayerAbsVelocity[1] * target_distance / speed_calculated;
					target_vec[2] += vecPlayerAbsVelocity[2] * target_distance / speed_calculated;
				}
			}
		}
		
		if (!Vector_IsZero(target_vec, 0.0))
		{
			float angToTarget[3];
			float vecProjWSC[3]; CBaseEntity(ent).WorldSpaceCenter(vecProjWSC);
			float vecSubtracted[3]; SubtractVectors(target_vec, vecProjWSC, vecSubtracted);
			GetVectorAngles(vecSubtracted, angToTarget);
			
			g_arrHoming[ent].homed_in = true;
			g_arrHoming[ent].homed_in_angle = angToTarget;
		}
		else
		{
			g_arrHoming[ent].homed_in = false;
		}
	}
	if (g_arrHoming[ent].homed_in)
	{
		float ticksPerSecond = 1.0 / GetGameFrameTime();
		pNewAngVelocity[0] = (ApproachAngle(g_arrHoming[ent].homed_in_angle[0], pNewAngles[0], g_arrHoming[ent].turn_power * GetGameFrameTime()) - pNewAngles[0]) * ticksPerSecond;
		pNewAngVelocity[1] = (ApproachAngle(g_arrHoming[ent].homed_in_angle[1], pNewAngles[1], g_arrHoming[ent].turn_power * GetGameFrameTime()) - pNewAngles[1]) * ticksPerSecond;
		pNewAngVelocity[2] = (ApproachAngle(g_arrHoming[ent].homed_in_angle[2], pNewAngles[2], g_arrHoming[ent].turn_power * GetGameFrameTime()) - pNewAngles[2]) * ticksPerSecond;
	}
	if (time < g_arrHoming[ent].aim_time)
	{
		pNewAngles[0] += (pNewAngVelocity[0] * GetGameFrameTime());
		pNewAngles[1] += (pNewAngVelocity[1] * GetGameFrameTime());
		pNewAngles[2] += (pNewAngVelocity[2] * GetGameFrameTime());
	}
	if (g_arrHoming[ent].returning && BaseEntity_GetOwnerEntity(ent) != -1)
	{
		int owner = BaseEntity_GetOwnerEntity(ent);
		
		float vecProjWSC[3]; CBaseEntity(ent).WorldSpaceCenter(vecProjWSC);
		float vecOwnerWSC[3]; CBaseEntity(owner).WorldSpaceCenter(vecOwnerWSC);
		float vecSubtracted[3]; SubtractVectors(vecProjWSC, vecOwnerWSC, vecSubtracted);
		GetVectorAngles(vecSubtracted, pNewAngles);
	}
	
	float vecOrientation[3];
	GetAngleVectors(pNewAngles, vecOrientation, NULL_VECTOR, NULL_VECTOR);
	
	float vec[3];
	vec[0] = 0.0;
	vec[1] = 0.0;
	vec[2] = -g_arrHoming[ent].gravity * time;
	pNewVelocity[0] = vecOrientation[0] * speed_calculated + vec[0];
	pNewVelocity[1] = vecOrientation[1] * speed_calculated + vec[1];
	pNewVelocity[2] = vecOrientation[2] * speed_calculated + vec[2];
	
	pNewPosition[0] += (pNewVelocity[0] * GetGameFrameTime());
	pNewPosition[1] += (pNewVelocity[1] * GetGameFrameTime());
	pNewPosition[2] += (pNewVelocity[2] * GetGameFrameTime());
	
	return true;
}

static bool TraceFilter_HomingRocketsFollowCrosshair(int entity, int contentsMask, StringMap data)
{
	//CTraceFilterIgnoreFriendlyCombatItems
	int iPassEnt = -1;
	data.GetValue("m_pPassEnt", iPassEnt);
	
	int iCollisionGroup;
	data.GetValue("m_collisionGroup", iCollisionGroup);
	
	int iIgnoreTeam;
	data.GetValue("m_iIgnoreTeam", iIgnoreTeam);
	
	if (BaseEntity_IsCombatItem(entity))
	{
		if (BaseEntity_GetTeamNumber(entity) == iIgnoreTeam)
			return false;
		
		//m_bCallerIsProjectile is false here
	}
	
	//CTraceFilterSimple as BaseClass of CTraceFilterIgnoreFriendlyCombatItems
	if (!StandardFilterRules(entity, contentsMask))
		return false;
	
	if (iPassEnt != -1)
	{
		if (!PassServerEntityFilter(entity, iPassEnt))
			return false;
	}
	
	if (!ShouldCollide(entity, iCollisionGroup, contentsMask))
		return false;
	
	if (!TFGameRules_ShouldCollide(iCollisionGroup, BaseEntity_GetCollisionGroup(entity)))
		return false;
	
	return true;
}

static bool TraceFilter_HomingRockets(int entity, int contentsMask, int data)
{
	int iPassEnt = data;
	const int iCollisionGroup = COLLISION_GROUP_NONE;
	
	//CTraceFilterSimple
	if (!StandardFilterRules(entity, contentsMask))
		return false;
	
	if (iPassEnt != -1)
	{
		if (!PassServerEntityFilter(entity, iPassEnt))
			return false;
	}
	
	if (!ShouldCollide(entity, iCollisionGroup, contentsMask))
		return false;
	
	if (!TFGameRules_ShouldCollide(iCollisionGroup, BaseEntity_GetCollisionGroup(entity)))
		return false;
	
	return true;
}