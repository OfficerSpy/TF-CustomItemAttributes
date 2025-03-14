static bool m_bEnabled[MAX_EDICTS + 1];
static bool m_bIgnoreDisguisedSpies[MAX_EDICTS + 1] = {true, ...};
static bool m_bIgnoreStealthedSpies[MAX_EDICTS + 1] = {true, ...};
static bool m_bFollowCrosshair[MAX_EDICTS + 1];
static bool m_bPredictTargetSpeed[MAX_EDICTS + 1] = {true, ...};
static float m_flSpeed[MAX_EDICTS + 1] = {1.0, ...};
static float m_flTurnPower[MAX_EDICTS + 1];
static float m_flMinDonProduct[MAX_EDICTS + 1] = {-0.25, ...};
static float m_flAimTime[MAX_EDICTS + 1] = {9999.0, ...};
static float m_flAimStartTime[MAX_EDICTS + 1];
static float m_flAcceleration[MAX_EDICTS + 1];
static float m_flAccelerationTime[MAX_EDICTS + 1] = {9999.0, ...};
static float m_flAccelerationStart[MAX_EDICTS + 1];
static float m_flGravity[MAX_EDICTS + 1];
static bool m_bHomedIn[MAX_EDICTS + 1];
static bool m_bReturning[MAX_EDICTS + 1];
static int m_iReturnToSender[MAX_EDICTS + 1];
static float m_vecHomedInAngle[MAX_EDICTS + 1][3];

methodmap HomingRockets
{
	public HomingRockets(int index)
	{
		return view_as<HomingRockets>(index);
	}
	
	property int index
	{
		public get()	{ return view_as<int>(this); }
	}
	
	property bool enable
	{
		public get()	{ return m_bEnabled[this.index]; }
		public set(bool value)	{ m_bEnabled[this.index] = value; }
	}
	
	property bool ignore_disguised_spies
	{
		public get()	{ return m_bIgnoreDisguisedSpies[this.index]; }
		public set(bool value)	{ m_bIgnoreDisguisedSpies[this.index] = value; }
	}
	
	property bool ignore_stealthed_spies
	{
		public get()	{ return m_bIgnoreStealthedSpies[this.index]; }
		public set(bool value)	{ m_bIgnoreStealthedSpies[this.index] = value; }
	}
	
	property bool follow_crosshair
	{
		public get()	{ return m_bFollowCrosshair[this.index]; }
		public set(bool value)	{ m_bFollowCrosshair[this.index] = value; }
	}
	
	property bool predict_target_speed
	{
		public get()	{ return m_bPredictTargetSpeed[this.index]; }
		public set(bool value)	{ m_bPredictTargetSpeed[this.index] = value; }
	}
	
	property float speed
	{
		public get()	{ return m_flSpeed[this.index]; }
		public set(float value)	{ m_flSpeed[this.index] = value; }
	}
	
	property float turn_power
	{
		public get()	{ return m_flTurnPower[this.index]; }
		public set(float value)	{ m_flTurnPower[this.index] = value; }
	}
	
	property float min_dot_product
	{
		public get()	{ return m_flMinDonProduct[this.index]; }
		public set(float value)	{ m_flMinDonProduct[this.index] = value; }
	}
	
	property float aim_time
	{
		public get()	{ return m_flAimTime[this.index]; }
		public set(float value)	{ m_flAimTime[this.index] = value; }
	}
	
	property float aim_start_time
	{
		public get()	{ return m_flAimStartTime[this.index]; }
		public set(float value)	{ m_flAimStartTime[this.index] = value; }
	}
	
	property float acceleration
	{
		public get()	{ return m_flAcceleration[this.index]; }
		public set(float value)	{ m_flAcceleration[this.index] = value; }
	}
	
	property float acceleration_time
	{
		public get()	{ return m_flAccelerationTime[this.index]; }
		public set(float value)	{ m_flAccelerationTime[this.index] = value; }
	}
	
	property float acceleration_start
	{
		public get()	{ return m_flAccelerationStart[this.index]; }
		public set(float value)	{ m_flAccelerationStart[this.index] = value; }
	}
	
	property float gravity
	{
		public get()	{ return m_flGravity[this.index]; }
		public set(float value)	{ m_flGravity[this.index] = value; }
	}
	
	property bool homed_in
	{
		public get()	{ return m_bHomedIn[this.index]; }
		public set(bool value)	{ m_bHomedIn[this.index] = value; }
	}
	
	property bool returning
	{
		public get()	{ return m_bReturning[this.index]; }
		public set(bool value)	{ m_bReturning[this.index] = value; }
	}
	
	property int return_to_sender
	{
		public get()	{ return m_iReturnToSender[this.index]; }
		public set(int value)	{ m_iReturnToSender[this.index] = value; }
	}
	
	property float[] homed_in_angle
	{
		public get()	{ return m_vecHomedInAngle[this.index]; }
		public set(const float value[3])	{ m_vecHomedInAngle[this.index] = value; }
	}
}

//CBaseEntity *ent, Vector *pNewPosition, Vector *pNewVelocity, QAngle *pNewAngles, QAngle *pNewAngVelocity
bool PerformCustomPhysics(int ent, float pNewPosition[3], float pNewVelocity[3], float pNewAngles[3], float pNewAngVelocity[3])
{
	int proj = ent;
	
	HomingRockets homing = HomingRockets(proj);
	
	if (!homing.enable)
		return false;
	
	float time = float(GetEntProp(ent, Prop_Send, "m_flSimulationTime")) - float(GetEntProp(ent, Prop_Send, "m_flAnimTime"));
	float speed_calculated = homing.speed + homing.acceleration & ClampFloat(time - homing.acceleration_start, 0.0, homing.acceleration_time);
	
	if (speed_calculated < 0.0 && homing.return_to_sender && !homing.returning)
	{
		homing.returning = true;
		homing.speed = 0;
		homing.acceleration = -homing.acceleration;
		homing.acceleration_start = time;
	}
	
	float interval = (3000.0 / speed_calculated) * 0.014;
	
	if (!homing.returning && homing.turn_power != 0.0 && time >= homing.aim_start_time && time < homing.aim_time && GetGameTickCount() % RoundToCeil(interval / GetTickInterval()) == 0)
	{
		float target_vec[3];
		
		if (homing.follow_crosshair)
		{
			int owner = BaseEntity_GetOwnerEntity(proj);
			
			if (owner != -1)
			{
				float vecForward[3];
				float vecEyeAngles[3]; GetClientEyeAngles(owner, vecEyeAngles);
				GetAngleVectors(vecEyeAngles, vecForward, NULL_VECTOR, NULL_VECTOR);
				
				Handle hTrace;
				float vecEyePosition[3]; GetClientEyePosition(owner, vecEyePosition);
				float vecModified[3];
				vecModified[0] = vecEyePosition[0] + 4000.0 * vecForward[0];
				vecModified[1] = vecEyePosition[1] + 4000.0 * vecForward[1];
				vecModified[2] = vecEyePosition[2] + 4000.0 * vecForward[2];
				hTrace = TR_TraceRayFilterEx(vecEyePosition, vecModified, MASK_SHOT, RayType_EndPoint, TraceFilter_HomingRocketsFollowCrosshair, owner);
				
				TR_GetEndPosition(target_vec, hTrace);
				
				hTrace.Close();
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
					
					if (GetClientTeam(i) == BaseEntity_GetTeamNumber(proj))
						continue;
					
					if (homing.ignore_disguised_spies)
					{
						if (TF2_IsPlayerInCondition(i, TFCond_Disguised) && TF2_GetDisguiseTeam(i) == BaseEntity_GetTeamNumber(proj))
						{
							//Ignore players disguised as our team
							continue;
						}
					}
					
					if (homing.ignore_stealthed_spies)
					{
						if (TF2_IsStealthed(i) && TF2_GetPercentInvisible(i) >= 0.75 && !TF2_IsPlayerInCondition(i, TFCond_CloakFlicker) && !TF2_IsPlayerInCondition(i, TFCond_OnFire) && !TF2_IsPlayerInCondition(i, TFCond_Jarated) && !TF2_IsPlayerInCondition(i, TFCond_Bleeding))
						{
							//Ignore stealthed players that are not exposed
							continue;
						}
					}
					
					float delta[3];
					float vecPlayerWSC[3]; CBaseEntity(i).WorldSpaceCenter(vecPlayerWSC);
					float vecProjWSC[3]; CBaseEntity(proj).WorldSpaceCenter(vecProjWSC);
					SubtractVectors(vecPlayerWSC, vecProjWSC, delta);
					
					float mindotproduct = homing.min_dot_product;
					float dotproduct = GetVectorDotProduct(Vector_Normalized(delta), Vector_Normalized(pNewVelocity));
					
					if (dotproduct < mindotproduct)
						continue;
					
					if (dotproduct > target_dotproduct)
					{
						bool noclip = GetEntityMoveType(proj) == MOVETYPE_NOCLIP;
						Handle hTrace;
						
						if (!noclip)
						{
							hTrace = TR_TraceRayFilterEx(vecPlayerWSC, vecProjWSC, MASK_SOLID_BRUSHONLY, RayType_EndPoint, TraceFilter_HomingRockets, i);
						}
						
						if (noclip || !TR_DidHit(hTrace) || TR_GetEntityIndex(hTrace) == proj)
						{
							target_player = i;
							target_dotproduct = dotproduct;
						}
						
						if (hTrace)
							hTrace.Close();
					}
				}
				
				if (target_player != -1)
				{
					float vecPlayerWSC[3]; CBaseEntity(target_player).WorldSpaceCenter(vecPlayerWSC);
					target_vec = vecPlayerWSC;
					
					float vecProjWSC[3]; CBaseEntity(proj).WorldSpaceCenter(vecProjWSC);
					float target_distance = GetVectorDistance(vecProjWSC, vecPlayerWSC);
					
					if (homing.predict_target_speed)
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
				float vecProjWSC[3]; CBaseEntity(proj).WorldSpaceCenter(vecProjWSC);
				float vecSubtracted[3]; SubtractVectors(target_vec, vecProjWSC, vecSubtracted);
				GetVectorAngles(vecSubtracted, angToTarget);
				
				homing.homed_in = true;
				homing.homed_in_angle = angToTarget;
			}
			else
			{
				homing.homed_in = false;
			}
		}
		
		if (homing.homed_in)
		{
			float ticksPerSecond = 1.0 / GetGameFrameTime();
			pNewAngVelocity[0] = (ApproachAngle(homing.homed_in_angle[0], pNewAngles[0], homing.turn_power * GetGameFrameTime()) - pNewAngles[0]) * ticksPerSecond;
			pNewAngVelocity[1] = (ApproachAngle(homing.homed_in_angle[1], pNewAngles[1], homing.turn_power * GetGameFrameTime()) - pNewAngles[1]) * ticksPerSecond;
			pNewAngVelocity[2] = (ApproachAngle(homing.homed_in_angle[2], pNewAngles[2], homing.turn_power * GetGameFrameTime()) - pNewAngles[2]) * ticksPerSecond;
		}
		
		if (time < homing.aim_time)
		{
			pNewAngles[0] += (pNewAngVelocity[0] * GetGameFrameTime());
			pNewAngles[1] += (pNewAngVelocity[1] * GetGameFrameTime());
			pNewAngles[2] += (pNewAngVelocity[2] * GetGameFrameTime());
		}
		
		if (homing.returning && BaseEntity_GetOwnerEntity(proj) != -1)
		{
			int owner = BaseEntity_GetOwnerEntity(proj);
			
			float vecProjWSC[3]; CBaseEntity(proj).WorldSpaceCenter(vecProjWSC);
			float vecOwnerWSC[3]; CBaseEntity(owner).WorldSpaceCenter(vecOwnerWSC);
			float vecSubtracted[3]; SubtractVectors(vecProjWSC, vecOwnerWSC, vecSubtracted);
			GetVectorAngles(vecSubtracted, pNewAngles);
		}
		
		float vecOrientation[3];
		GetAngleVectors(pNewAngles, vecOrientation, NULL_VECTOR, NULL_VECTOR);
		
		float vec[3] = {0.0, 0.0, -homing.gravity * time};
		pNewVelocity[0] = vecOrientation[0] * speed_calculated + vec[0];
		pNewVelocity[1] = vecOrientation[1] * speed_calculated + vec[1];
		pNewVelocity[2] = vecOrientation[2] * speed_calculated + vec[2];
		
		pNewPosition[0] += (pNewVelocity[0] * GetGameFrameTime());
		pNewPosition[1] += (pNewVelocity[1] * GetGameFrameTime());
		pNewPosition[2] += (pNewVelocity[2] * GetGameFrameTime());
		
		return true;
	}
}

static bool TraceFilter_HomingRocketsFollowCrosshair(int entity, int contentsMask, int data)
{
	/* CTraceFilterIgnoreFriendlyCombatItems(const CBaseEntity *pEntity, int collisionGroup, bool bNoChain = false) :
		CTraceFilterSimple(pEntity, collisionGroup), m_iTeamNum(pEntity->GetTeamNumber()), m_bNoChain(bNoChain) */
	
	int iTeamNum = GetClientTeam(data);
	if (BaseEntity_IsCombatItem(entity))
	{
		if (BaseEntity_GetTeamNumber(entity) == iTeamNum)
			return false;
		
		//No m_bNoChain
	}
	
	//CTraceFilterSimple
	const int collisionGroup = COLLISION_GROUP_NONE;
	
	//TODO: SDKCall ShouldCollide
	
	return TFGameRules_ShouldCollide(collisionGroup, BaseEntity_GetCollisionGroup(entity));
}

static bool TraceFilter_HomingRockets(int entity, int contentsMask, int data)
{
	//CTraceFilterSimple
	const int collisionGroup = COLLISION_GROUP_NONE;
	
	//TODO: SDKCall ShouldCollide
	
	return TFGameRules_ShouldCollide(collisionGroup, BaseEntity_GetCollisionGroup(entity));
}