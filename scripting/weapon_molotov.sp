/*  SM Weapon Molotov
 *
 *  Copyright (C) 2021 Francisco 'Franc1sco' García
 * 
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) 
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT 
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with 
 * this program. If not, see http://www.gnu.org/licenses/.
 */

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <csutils>
#include <fpvm_interface>

public Plugin:myinfo =
{
	name = "SM Weapon Molotov",
	author = "Franc1sco franug",
	description = "",
	version = "0.1",
	url = "http://steamcommunity.com/id/franug"
};

Handle kv, array_weapons, array_weapons_molotov;

float _attackDelay[MAXPLAYERS + 1];

ConVar cvar_delay, cvar_speed;

public void OnPluginStart()
{
	cvar_delay = CreateConVar("sm_weaponmolotov_delay", "0.5", "Delay for each molotov");
	cvar_speed = CreateConVar("sm_weaponmolotov_velocity", "500.0", "Velocity for molotov");
}

public OnMapStart()
{
	RefreshKV();
	Downloads();
	
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			OnClientPostAdminCheck(client);
		}
	}
}

public void RefreshKV()
{
	char sConfig[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sConfig, PLATFORM_MAX_PATH, "configs/molotov_weapon/configuration.txt");
	
	if(kv != INVALID_HANDLE) CloseHandle(kv);
	
	kv = CreateKeyValues("MolotovWeapon");
	FileToKeyValues(kv, sConfig);
	
	if(array_weapons != INVALID_HANDLE) CloseHandle(array_weapons);
	array_weapons = CreateArray(64);
	
	if(array_weapons_molotov != INVALID_HANDLE) CloseHandle(array_weapons_molotov);
	array_weapons_molotov = CreateArray();
	
	char temp[64];
	char cwmodel[PLATFORM_MAX_PATH], cwmodel2[PLATFORM_MAX_PATH], cwmodel3[PLATFORM_MAX_PATH];
	
	if(KvGotoFirstSubKey(kv))
	{
		do
		{
			KvGetSectionName(kv, temp, 64);
			
			PushArrayString(array_weapons, temp);
			
			KvGetString(kv, "model", cwmodel, PLATFORM_MAX_PATH, "none");
			KvGetString(kv, "worldmodel", cwmodel2, PLATFORM_MAX_PATH, "none");
			KvGetString(kv, "dropmodel", cwmodel3, PLATFORM_MAX_PATH, "none");
			
			if(!StrEqual(cwmodel, "none"))
			{
				PushArrayCell(array_weapons_molotov, PrecacheModel(cwmodel));
			}
				
			if(!StrEqual(cwmodel2, "none"))
				PrecacheModel(cwmodel2);
				
			if(!StrEqual(cwmodel3, "none"))
				PrecacheModel(cwmodel3);
			
			
		} while (KvGotoNextKey(kv));
	}
	KvRewind(kv);
}

void Downloads()
{
	char imFile[PLATFORM_MAX_PATH];
	char line[192];
	
	BuildPath(Path_SM, imFile, sizeof(imFile), "configs/molotov_weapon/downloads.txt");
	
	Handle file = OpenFile(imFile, "r");
	
	if(file != INVALID_HANDLE)
	{
		while (!IsEndOfFile(file))
		{
			if(!ReadFileLine(file, line, sizeof(line)))
			{
				break;
			}
			
			TrimString(line);
			if(strlen(line) > 0 && FileExists(line))
			{
				AddFileToDownloadsTable(line);
			}
		}

		CloseHandle(file);
	}
	else
	{
		LogError("[SM] no file found for downloads (configs/molotov_weapon/downloads.txt)");
	}
}

public void OnClientPostAdminCheck(int client)
{
	_attackDelay[client] = 0.0;
	
	if (GetArraySize(array_weapons) == 0)return;
	
	char items[64];
	char cwmodel[PLATFORM_MAX_PATH], cwmodel2[PLATFORM_MAX_PATH], cwmodel3[PLATFORM_MAX_PATH];
	for(int i=0;i<GetArraySize(array_weapons);++i)
	{
		GetArrayString(array_weapons, i, items, 64);
		
		KvJumpToKey(kv, items);
		
		KvGetString(kv, "model", cwmodel, PLATFORM_MAX_PATH, "none");
		KvGetString(kv, "worldmodel", cwmodel2, PLATFORM_MAX_PATH, "none");
		KvGetString(kv, "dropmodel", cwmodel3, PLATFORM_MAX_PATH, "none");
	
		char flag[8];
		KvGetString(kv, "flag", flag, 8, "");
	
		if(HasPermission(client, flag)) FPVMI_SetClientModel(client, items, !StrEqual(cwmodel, "none")?PrecacheModel(cwmodel):-1, !StrEqual(cwmodel2, "none")?PrecacheModel(cwmodel2):-1, cwmodel3);
	
		KvRewind(kv);
		
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if(IsClientInGame(client) && IsPlayerAlive(client) && buttons & IN_ATTACK)
	{
		char classname[64];
		GetClientWeapon(client, classname, 64);
		//PrintToConsole(client, "paso1");
		if (!molotovWeapon(client, classname))return;
		//PrintToConsole(client, "paso2");
		float currentTime = GetGameTime();
		
		buttons &= ~IN_ATTACK;
		
		int currentweapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
		SetEntPropFloat(currentweapon, Prop_Send, "m_flNextPrimaryAttack", currentTime + 999999.0);
		//SetEntPropFloat(client, Prop_Send, "m_flNextAttack", 0.0);
		
		if(_attackDelay[client]+cvar_delay.FloatValue < currentTime)
		{
			//PrintToConsole(client, "paso3");
			molotovAttack(client);
			_attackDelay[client] = currentTime;
		}
		
	}
}

void molotovAttack(int client)
{
	float cleyepos[3], cleyeangle[3], fVel[3];
	
	GetClientEyePosition(client, cleyepos);
	GetClientEyeAngles(client, cleyeangle);	
	
	GetAngleVectors(cleyeangle, fVel, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(fVel, cvar_speed.FloatValue);
	
	CSU_ThrowGrenade(client, GrenadeType_Molotov, cleyepos, fVel);
}

bool molotovWeapon(client, char classname[64])
{
	
	int index = FPVMI_GetClientViewModel(client, classname);
	
	//PrintToConsole(client, "paso1 2 con index %i", index);
	
	if (index == -1)return false;
	
	//PrintToConsole(client, "paso1 3");
	int find;
	
	for(int i=0;i<GetArraySize(array_weapons_molotov);++i)
	{
		find = GetArrayCell(array_weapons_molotov, i);
		
		if (find == index)return true;
	}
	
	return false;
}

stock bool HasPermission(int iClient, char[] flagString) 
{
	if(StrEqual(flagString, "")) 
	{
		return true;
	}
	
	AdminId admin = GetUserAdmin(iClient);
	
	if(admin != INVALID_ADMIN_ID)
	{
		int count, found, flags = ReadFlagString(flagString);
		for (int i = 0; i <= 20; i++) 
		{
			if(flags & (1<<i)) 
			{
				count++;
				
				if(GetAdminFlag(admin, view_as<AdminFlag>(i))) 
				{
					found++;
				}
			}
		}

		if(count == found)
		{
			return true;
		}
	}

	return false;
} 