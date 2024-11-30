#include <sourcemod>

#pragma newdecls required

ConVar CvarEnable;
ConVar CvarCooldown;
ConVar CvarFreezeDelay;
ConVar CvarMaxInvalidJumps;
ConVar CvarMinOngroundTicks;
ConVar CvarVelocityMax;

bool Enable;
float Cooldown;
float FreezeDelay;
int MaxInvalidJumps;
int MinOngroundTicks;
float VelocityMax;

// Время, в течение которого считается кол-во невалидных прыжков (=curr_time + COOLDOWN * MAX_INVALID_JUMPS)
float Record[MAXPLAYERS + 1];

// Время перезарядки нормального прыжка (time + COOLDOWN)
float JumpCooldown[MAXPLAYERS + 1];

// Кол-во невалидных прыжков, сделанных раньше чем JumpCooldown (time + COOLDOWN)
int InvalidJumps[MAXPLAYERS + 1];

// Время блокировки невалидных прыжков (time + COOLDOWN * MAX_INVALID_JUMPS)
float Block[MAXPLAYERS + 1];

// Время заморозки при блокировке очередного невалидного прыжка (time + FREEZE_DELAY)
float Freeze[MAXPLAYERS + 1];

// Оффсеты
int m_vecAbsVelocity = -1;

public Plugin myinfo =
{
    name = "AntiCrawlJumpSpam",
    author = "hEl",
    description = "Prevents jump spam in crawlspace",
    version = "1.0",
    url = "https://github.com/CSS-SWZ/AntiCrawlJumpSpam"
};

public void OnPluginStart()
{
	CvarEnable = CreateConVar("sm_acjs_enable", "1", "Enable/Disable crawlspace jump spam prevention", 0, true, 0.0, true, 1.0);
	CvarEnable.AddChangeHook(OnConVarChanged);
	Enable = CvarEnable.BoolValue;

	CvarCooldown = CreateConVar("sm_acjs_cooldown", "0.4", "The time interval that defines a jump as invalid", 0, true, 0.1, true, 2.0);
	CvarCooldown.AddChangeHook(OnConVarChanged);
	Cooldown = CvarCooldown.FloatValue;

	CvarFreezeDelay = CreateConVar("sm_acjs_freeze_delay", "0.5", "Client freeze time after a jumpspam attempt being blocked", 0, true, 0.01, true, 2.0);
	CvarFreezeDelay.AddChangeHook(OnConVarChanged);
	FreezeDelay = CvarFreezeDelay.FloatValue;

	CvarMaxInvalidJumps = CreateConVar("sm_acjs_jumps_max", "3", "Number of invalid jumps to start blocking jumpspams", 0, true, 1.0, true, 10.0);
	CvarMaxInvalidJumps.AddChangeHook(OnConVarChanged);
	MaxInvalidJumps = CvarMaxInvalidJumps.IntValue;
	
	CvarMinOngroundTicks = CreateConVar("sm_acjs_onground_min", "5", "Number of ticks a blocked player must stand on the ground for his next jump not to be blocked", 0, true, 0.0, true, 100.0);
	CvarMinOngroundTicks.AddChangeHook(OnConVarChanged);
	MinOngroundTicks = CvarMinOngroundTicks.IntValue;

	CvarVelocityMax = CreateConVar("sm_acjs_velocity_max", "300");
	CvarVelocityMax.AddChangeHook(OnConVarChanged);
	VelocityMax = CvarVelocityMax.FloatValue;

	AutoExecConfig(true, "plugin.AntiCrawlJumpSpam");

	HookEvent("player_jump", Event_PlayerJump);
}

public void OnMapStart()
{
	m_vecAbsVelocity = FindDataMapInfo(0, "m_vecAbsVelocity");
}

public void OnConVarChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	if(cvar == CvarEnable)
	{
		bool old = Enable;
		Enable = cvar.BoolValue;

		if(old == Enable)
			return;

		if(!Enable)
		{
			for(int i = 1; i <= MaxClients; ++i)
			{
				if(!IsClientInGame(i) || !IsPlayerAlive(i))
					continue;

				if(!Freeze[i])
					continue;

				if(GetEntityMoveType(i) == MOVETYPE_NONE)
					SetEntityMoveType(i, MOVETYPE_WALK);
			}

		}
	}
	else if(cvar == CvarCooldown)
	{
		Cooldown = cvar.FloatValue;
	}
	else if(cvar == CvarFreezeDelay)
	{
		FreezeDelay = cvar.FloatValue;
	}
	else if(cvar == CvarMaxInvalidJumps)
	{
		MaxInvalidJumps = cvar.IntValue;
	}
	else if(cvar == CvarMinOngroundTicks)
	{
		MinOngroundTicks = cvar.IntValue;
	}
	else if(cvar == CvarVelocityMax)
	{
		VelocityMax = cvar.FloatValue;
	}
}

public void Event_PlayerJump(Event event, const char[] name, bool dontBroadcast)
{
	if(!Enable)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	float time = GetGameTime();

	// Игрок заблокирован, подсчет прыжков пропускается хотя кулдаун все еще записываем
	if(Block[client] >= time)
	{
		Block[client] += Cooldown;
		JumpCooldown[client] = time + Cooldown;
		return;
	}

	// Время подсчета невалидных прыжков истекло, запускаем заного
	if(time >= Record[client])
	{
		InvalidJumps[client] = 0;
		Record[client] = time + Cooldown * float(MaxInvalidJumps);
	}

	// Сделан невалидный прыжок
	if(JumpCooldown[client] >= time)
	{
		++InvalidJumps[client];

		// Блокируем невалидные прыжки на такое же время, как время подсчета
		if(InvalidJumps[client] >= MaxInvalidJumps)
		{
			InvalidJumps[client] = 0;
			Record[client] = 0.0;
			Block[client] = time + Cooldown * float(MaxInvalidJumps);
		}
	}

	// Время после которого прыжок считается нормальным
	JumpCooldown[client] = time + Cooldown;
}

public Action OnPlayerRunCmd(int client, int& buttons)
{
	if(!Enable)
		return Plugin_Continue;

	static float time;
	time = GetGameTime();

	static bool onground;
	static int onground_ticks[MAXPLAYERS + 1];

	if(!IsPlayerAlive(client))
	{
		onground_ticks[client] = 0;
		return Plugin_Continue;
	}

	// Истекла ли заморозка у игрока?
	if(Freeze[client])
	{
		onground_ticks[client] = 0;
		if(Freeze[client] >= time)
			return Plugin_Continue;

		Freeze[client] = 0.0;

		if(GetEntityMoveType(client) == MOVETYPE_NONE)
			SetEntityMoveType(client, MOVETYPE_WALK);
	}

	// Игрок не попал еще под блокировку, поэтому пропускаем наказание
	if(time > Block[client])
	{
		onground_ticks[client] = 0;
		return Plugin_Continue;
	}

	onground = !!(GetEntityFlags(client) & FL_ONGROUND);

	if(onground)
	{
		++onground_ticks[client];
	}
	else
	{
		onground_ticks[client] = 0;
	}

	if(buttons & IN_JUMP && JumpCooldown[client] >= time && onground && onground_ticks[client] <= MinOngroundTicks)
	{

		// Обновляем время блокировки с учетом время заморозки поскольку игрок не понял 
		Block[client] = time + FreezeDelay + Cooldown * float(MaxInvalidJumps);

		if(IsClientFreezable(client))
		{
			buttons &= ~IN_JUMP;
			Freeze[client] = time + FreezeDelay;
			SetEntityMoveType(client, MOVETYPE_NONE);
		}

		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public void OnClientPutInServer(int client)
{
	ResetClientVars(client);
}

public void OnClientDisconnect(int client)
{
	ResetClientVars(client);
}

void ResetClientVars(int client)
{
	InvalidJumps[client] = 0;
	Record[client] = 0.0;
	JumpCooldown[client] = 0.0;
	Block[client] = 0.0;
	Freeze[client] = 0.0;
}

stock bool IsClientFreezable(int client)
{
	// Игрок на лифте/пропе/голове чьей-то xD
	if(GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") > 0)
		return false;
	
	if(VelocityMax > 0)
	{
		float velocity[3];
		float magnitude;
	
		GetEntDataVector(client, m_vecAbsVelocity, velocity);
	
		magnitude = SquareRoot(Pow(velocity[0], 2.0) + Pow(velocity[1], 2.0));
	
		// Игрок не набрал большой скорости
		if(VelocityMax >= magnitude)
			return false;
	}
	
	return true;
}