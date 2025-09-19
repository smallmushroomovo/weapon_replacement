#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <clientprefs>

#define PLUGIN_VERSION "3.2"

// 武器定义
#define WEAPON_P2000 "weapon_hkp2000"
#define WEAPON_USP "weapon_usp_silencer"
#define WEAPON_M4A4 "weapon_m4a1"
#define WEAPON_M4A1 "weapon_m4a1_silencer"
#define WEAPON_MP7 "weapon_mp7"
#define WEAPON_MP5 "weapon_mp5sd"
#define WEAPON_DEAGLE "weapon_deagle"
#define WEAPON_R8 "weapon_revolver"
#define WEAPON_FIVESEVEN "weapon_fiveseven"
#define WEAPON_TEC9 "weapon_tec9"
#define WEAPON_CZ75 "weapon_cz75a"

// 武器价格枚举
enum WeaponPrice {
    PRICE_P2000 = 200,
    PRICE_USP = 200,
    PRICE_M4A4 = 3100,
    PRICE_M4A1 = 2900,
    PRICE_MP7 = 1500,
    PRICE_MP5 = 1500,
    PRICE_DEAGLE = 700,
    PRICE_R8 = 600,
    PRICE_FIVESEVEN = 500,
    PRICE_TEC9 = 500,
    PRICE_CZ75 = 500
};

// 玩家偏好设置的枚举结构
enum struct PlayerPrefs {
    bool ReplaceP2000;    // 是否替换P2000为USP
    bool ReplaceM4A4;     // 是否替换M4A4为M4A1-S
    bool ReplaceMP7;      // 是否替换MP7为MP5-SD
    bool ReplaceDeagle;   // 是否替换沙漠之鹰为R8左轮
    bool ReplacePistols;  // 是否替换FN57/TEC9为CZ75
    bool SettingsLoaded;  // 玩家设置是否已加载
}

// 全局变量
Handle g_hWeaponPrefCookie;                    // Cookie句柄用于存储玩家偏好
ConVar g_cvDefaultP2000, g_cvDefaultM4A4, g_cvDefaultMP7, g_cvDefaultDeagle, g_cvDefaultPistols; // 默认武器替换设置
ConVar g_cvGameType, g_cvGameMode;            // 游戏模式和类型ConVar
bool g_bIsDeathmatch;                         // 是否为死亡竞赛模式
PlayerPrefs g_Prefs[MAXPLAYERS + 1];          // 玩家偏好数组
ArrayList g_hWeaponReplaceQueue[MAXPLAYERS + 1]; // 武器替换队列
StringMap g_WeaponPrices;                     // 武器价格映射
StringMap g_WeaponSlots;                      // 武器槽位映射

public Plugin myinfo = 
{
    name = "CS:GO 武器替换",
    author = "Deepseek and Grok",
    description = "根据玩家偏好自动替换武器",
    version = PLUGIN_VERSION,
    url = "https://github.com/smallmushroomovo/weapon_replacement"
};

void InitializeWeaponPrices()
{
    g_WeaponPrices = new StringMap();
    g_WeaponPrices.SetValue(WEAPON_P2000, PRICE_P2000);
    g_WeaponPrices.SetValue(WEAPON_USP, PRICE_USP);
    g_WeaponPrices.SetValue(WEAPON_M4A4, PRICE_M4A4);
    g_WeaponPrices.SetValue(WEAPON_M4A1, PRICE_M4A1);
    g_WeaponPrices.SetValue(WEAPON_MP7, PRICE_MP7);
    g_WeaponPrices.SetValue(WEAPON_MP5, PRICE_MP5);
    g_WeaponPrices.SetValue(WEAPON_DEAGLE, PRICE_DEAGLE);
    g_WeaponPrices.SetValue(WEAPON_R8, PRICE_R8);
    g_WeaponPrices.SetValue(WEAPON_FIVESEVEN, PRICE_FIVESEVEN);
    g_WeaponPrices.SetValue(WEAPON_TEC9, PRICE_TEC9);
    g_WeaponPrices.SetValue(WEAPON_CZ75, PRICE_CZ75);
}

void InitializeWeaponSlots()
{
    g_WeaponSlots = new StringMap();
    g_WeaponSlots.SetValue(WEAPON_USP, 1);
    g_WeaponSlots.SetValue(WEAPON_P2000, 1);
    g_WeaponSlots.SetValue(WEAPON_FIVESEVEN, 1);
    g_WeaponSlots.SetValue(WEAPON_TEC9, 1);
    g_WeaponSlots.SetValue(WEAPON_CZ75, 1);
    g_WeaponSlots.SetValue(WEAPON_DEAGLE, 1);
    g_WeaponSlots.SetValue(WEAPON_R8, 1);
    g_WeaponSlots.SetValue(WEAPON_M4A4, 0);
    g_WeaponSlots.SetValue(WEAPON_M4A1, 0);
    g_WeaponSlots.SetValue(WEAPON_MP7, 0);
    g_WeaponSlots.SetValue(WEAPON_MP5, 0);
}

public void OnPluginStart()
{
    // 注册命令
    RegConsoleCmd("sm_gunsettings", Command_GunSettings, "打开武器替换设置菜单");
    RegConsoleCmd("sm_resetguns", Command_ResetSettings, "将武器偏好重置为默认值");
    
    // 创建ConVar配置项
    g_cvDefaultP2000 = CreateConVar("sm_weapon_default_p2000", "1", "默认是否将P2000替换为USP (0 = 否, 1 = 是)", 0, true, 0.0, true, 1.0);
    g_cvDefaultM4A4 = CreateConVar("sm_weapon_default_m4a4", "0", "默认是否将M4A4替换为M4A1-S (0 = 否, 1 = 是)", 0, true, 0.0, true, 1.0);
    g_cvDefaultMP7 = CreateConVar("sm_weapon_default_mp7", "1", "默认是否将MP7替换为MP5-SD (0 = 否, 1 = 是)", 0, true, 0.0, true, 1.0);
    g_cvDefaultDeagle = CreateConVar("sm_weapon_default_deagle", "1", "默认是否将沙漠之鹰替换为R8左轮 (0 = 否, 1 = 是)", 0, true, 0.0, true, 1.0);
    g_cvDefaultPistols = CreateConVar("sm_weapon_default_pistols", "1", "默认是否将FN57/TEC9替换为CZ75 (0 = 否, 1 = 是)", 0, true, 0.0, true, 1.0);
    
    // 创建用于存储玩家偏好的Cookie
    g_hWeaponPrefCookie = RegClientCookie("weapon_replacement_prefs", "玩家武器替换偏好", CookieAccess_Protected);
    
    // 绑定事件
    HookEvent("item_purchase", Event_ItemPurchase);
    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_death", Event_PlayerDeath);
    
    // 获取游戏模式和类型ConVar
    g_cvGameType = FindConVar("game_type");
    g_cvGameMode = FindConVar("game_mode");
    
    // 监听游戏模式变化
    if (g_cvGameType != null) g_cvGameType.AddChangeHook(OnGameModeChanged);
    if (g_cvGameMode != null) g_cvGameMode.AddChangeHook(OnGameModeChanged);
    
    // 初始化武器替换队列
    for (int i = 0; i <= MAXPLAYERS; i++)
    {
        g_hWeaponReplaceQueue[i] = new ArrayList(ByteCountToCells(64));
    }
    
    // 初始化武器价格和槽位
    InitializeWeaponPrices();
    InitializeWeaponSlots();
    
    // 加载翻译文件和配置文件
    LoadTranslations("common.phrases");
    AutoExecConfig(true, "weapon_replacement");
    
    // 为已连接的玩家加载设置
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i) && AreClientCookiesCached(i))
        {
            OnClientCookiesCached(i);
        }
    }
    
    CheckGameMode();
}

public void OnGameModeChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    CheckGameMode();
}

void CheckGameMode()
{
    // 检查游戏模式是否为死亡竞赛
    if (g_cvGameType == null || g_cvGameMode == null)
    {
        g_bIsDeathmatch = false;
        return;
    }
    
    g_bIsDeathmatch = (g_cvGameType.IntValue == 1 && g_cvGameMode.IntValue == 2);
}

public void OnConfigsExecuted()
{
    // 配置加载完成后，为所有玩家加载默认设置
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i) && AreClientCookiesCached(i))
        {
            LoadPlayerSettings(i);
        }
    }
}

public void OnClientCookiesCached(int client)
{
    if (IsFakeClient(client)) return;
    
    LoadPlayerSettings(client);
}

void LoadPlayerSettings(int client)
{
    // 加载玩家保存的武器偏好设置
    char sCookieValue[32];
    GetClientCookie(client, g_hWeaponPrefCookie, sCookieValue, sizeof(sCookieValue));
    
    // 设置默认值
    g_Prefs[client].ReplaceP2000 = g_cvDefaultP2000.BoolValue;
    g_Prefs[client].ReplaceM4A4 = g_cvDefaultM4A4.BoolValue;
    g_Prefs[client].ReplaceMP7 = g_cvDefaultMP7.BoolValue;
    g_Prefs[client].ReplaceDeagle = g_cvDefaultDeagle.BoolValue;
    g_Prefs[client].ReplacePistols = g_cvDefaultPistols.BoolValue;
    
    if (strlen(sCookieValue) > 0)
    {
        char sSettings[5][8];
        if (ExplodeString(sCookieValue, ",", sSettings, sizeof(sSettings), sizeof(sSettings[])) == 5)
        {
            for (int i = 0; i < 5; i++)
            {
                TrimString(sSettings[i]);
                if (!IsValidNumber(sSettings[i]))
                {
                    SavePlayerSettings(client);
                    g_Prefs[client].SettingsLoaded = true;
                    return;
                }
            }
            
            g_Prefs[client].ReplaceP2000 = StringToInt(sSettings[0]) != 0;
            g_Prefs[client].ReplaceM4A4 = StringToInt(sSettings[1]) != 0;
            g_Prefs[client].ReplaceMP7 = StringToInt(sSettings[2]) != 0;
            g_Prefs[client].ReplaceDeagle = StringToInt(sSettings[3]) != 0;
            g_Prefs[client].ReplacePistols = StringToInt(sSettings[4]) != 0;
        }
        else
        {
            SavePlayerSettings(client);
        }
    }
    else
    {
        SavePlayerSettings(client);
    }
    
    g_Prefs[client].SettingsLoaded = true;
}

bool IsValidNumber(const char[] str)
{
    // 验证字符串是否为有效数字（0或1）
    if (strlen(str) == 0) return false;
    for (int i = 0; i < strlen(str); i++)
    {
        if (!IsCharNumeric(str[i])) return false;
    }
    int value = StringToInt(str);
    return (value == 0 || value == 1);
}

public Action Command_GunSettings(int client, int args)
{
    if (!IsValidClient(client))
    {
        ReplyToCommand(client, "[SM] 你必须在游戏中才能使用此命令！");
        return Plugin_Handled;
    }
    
    if (!g_Prefs[client].SettingsLoaded)
    {
        ReplyToCommand(client, "[SM] 设置尚未加载，请稍后再试！");
        return Plugin_Handled;
    }
    
    ShowWeaponSettingsMenu(client);
    return Plugin_Handled;
}

public Action Command_ResetSettings(int client, int args)
{
    if (!IsValidClient(client))
    {
        ReplyToCommand(client, "[SM] 你必须在游戏中才能使用此命令！");
        return Plugin_Handled;
    }
    
    // 重置为默认设置
    g_Prefs[client].ReplaceP2000 = g_cvDefaultP2000.BoolValue;
    g_Prefs[client].ReplaceM4A4 = g_cvDefaultM4A4.BoolValue;
    g_Prefs[client].ReplaceMP7 = g_cvDefaultMP7.BoolValue;
    g_Prefs[client].ReplaceDeagle = g_cvDefaultDeagle.BoolValue;
    g_Prefs[client].ReplacePistols = g_cvDefaultPistols.BoolValue;
    
    SavePlayerSettings(client);
    PrintToChat(client, "[SM] 武器偏好已重置为默认值！");
    
    if (IsPlayerAlive(client))
    {
        CheckAndReplaceWeapons(client);
    }
    
    ShowWeaponSettingsMenu(client);
    return Plugin_Handled;
}

void ShowWeaponSettingsMenu(int client)
{
    // 显示武器替换设置菜单
    Menu menu = new Menu(WeaponSettingsMenuHandler, MENU_ACTIONS_ALL);
    menu.SetTitle("武器替换设置 (%N)", client);
    
    char buffer[64];
    Format(buffer, sizeof(buffer), "P2000 → USP消音版: %s", g_Prefs[client].ReplaceP2000 ? "启用" : "禁用");
    menu.AddItem("p2000", buffer);
    
    Format(buffer, sizeof(buffer), "M4A4 → M4A1-S: %s", g_Prefs[client].ReplaceM4A4 ? "启用" : "禁用");
    menu.AddItem("m4a4", buffer);
    
    Format(buffer, sizeof(buffer), "MP7 → MP5-SD: %s", g_Prefs[client].ReplaceMP7 ? "启用" : "禁用");
    menu.AddItem("mp7", buffer);
    
    Format(buffer, sizeof(buffer), "沙漠之鹰 → R8左轮: %s", g_Prefs[client].ReplaceDeagle ? "启用" : "禁用");
    menu.AddItem("deagle", buffer);
    
    Format(buffer, sizeof(buffer), "FN57/TEC9 → CZ75: %s", g_Prefs[client].ReplacePistols ? "启用" : "禁用");
    menu.AddItem("pistols", buffer);
    
    menu.ExitButton = true;
    menu.Display(client, 30);
}

public int WeaponSettingsMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        char item[32];
        menu.GetItem(param2, item, sizeof(item));
        
        bool recheck = false;
        if (StrEqual(item, "p2000"))
        {
            g_Prefs[client].ReplaceP2000 = !g_Prefs[client].ReplaceP2000;
            PrintToChat(client, "[SM] P2000 → USP消音版: %s", g_Prefs[client].ReplaceP2000 ? "已启用" : "已禁用");
            recheck = (g_Prefs[client].ReplaceP2000 && GetClientTeam(client) == CS_TEAM_CT);
        }
        else if (StrEqual(item, "m4a4"))
        {
            g_Prefs[client].ReplaceM4A4 = !g_Prefs[client].ReplaceM4A4;
            PrintToChat(client, "[SM] M4A4 → M4A1-S: %s", g_Prefs[client].ReplaceM4A4 ? "已启用" : "已禁用");
            recheck = (g_Prefs[client].ReplaceM4A4 && GetClientTeam(client) == CS_TEAM_CT);
        }
        else if (StrEqual(item, "mp7"))
        {
            g_Prefs[client].ReplaceMP7 = !g_Prefs[client].ReplaceMP7;
            PrintToChat(client, "[SM] MP7 → MP5-SD: %s", g_Prefs[client].ReplaceMP7 ? "已启用" : "已禁用");
            recheck = g_Prefs[client].ReplaceMP7;
        }
        else if (StrEqual(item, "deagle"))
        {
            g_Prefs[client].ReplaceDeagle = !g_Prefs[client].ReplaceDeagle;
            PrintToChat(client, "[SM] 沙漠之鹰 → R8左轮: %s", g_Prefs[client].ReplaceDeagle ? "已启用" : "已禁用");
            recheck = g_Prefs[client].ReplaceDeagle;
        }
        else if (StrEqual(item, "pistols"))
        {
            g_Prefs[client].ReplacePistols = !g_Prefs[client].ReplacePistols;
            PrintToChat(client, "[SM] FN57/TEC9 → CZ75: %s", g_Prefs[client].ReplacePistols ? "已启用" : "已禁用");
            recheck = g_Prefs[client].ReplacePistols;
        }
        
        SavePlayerSettings(client);
        if (IsPlayerAlive(client) && recheck)
        {
            CheckAndReplaceWeapons(client);
        }
        ShowWeaponSettingsMenu(client);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    
    return 0;
}

void SavePlayerSettings(int client)
{
    // 保存玩家武器偏好设置到Cookie
    char sCookieValue[32];
    Format(sCookieValue, sizeof(sCookieValue), "%d,%d,%d,%d,%d",
        g_Prefs[client].ReplaceP2000,
        g_Prefs[client].ReplaceM4A4,
        g_Prefs[client].ReplaceMP7,
        g_Prefs[client].ReplaceDeagle,
        g_Prefs[client].ReplacePistols);
    
    SetClientCookie(client, g_hWeaponPrefCookie, sCookieValue);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidClient(client) || !IsPlayerAlive(client))
        return Plugin_Continue;
    
    g_hWeaponReplaceQueue[client].Clear();
    // 增加延迟以确保武器生成
    CreateTimer(g_bIsDeathmatch ? 3.0 : 1.0, Timer_CheckInitialWeapons, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    return Plugin_Continue;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsValidClient(client))
    {
        g_hWeaponReplaceQueue[client].Clear();
    }
    return Plugin_Continue;
}

public Action Timer_CheckInitialWeapons(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (!IsValidClient(client) || !IsPlayerAlive(client) || !g_Prefs[client].SettingsLoaded)
        return Plugin_Stop;
    
    CheckAndReplaceWeapons(client);
    return Plugin_Stop;
}

void CheckAndReplaceWeapons(int client)
{
    // 按固定顺序替换武器，先主武器后副武器，防止槽冲突
    if (GetClientTeam(client) == CS_TEAM_CT)
    {
        if (g_Prefs[client].ReplaceM4A4)
        {
            // 检查主武器槽是否已被替换
            if (FindWeapon(client, WEAPON_M4A1) == -1)
                ReplaceWeapon(client, WEAPON_M4A4, WEAPON_M4A1);
        }
        if (g_Prefs[client].ReplaceP2000)
        {
            if (FindWeapon(client, WEAPON_USP) == -1)
                ReplaceWeapon(client, WEAPON_P2000, WEAPON_USP);
        }
        if (g_Prefs[client].ReplacePistols)
        {
            if (FindWeapon(client, WEAPON_CZ75) == -1)
                ReplaceWeapon(client, WEAPON_FIVESEVEN, WEAPON_CZ75);
        }
    }
    else if (GetClientTeam(client) == CS_TEAM_T && g_Prefs[client].ReplacePistols)
    {
        if (FindWeapon(client, WEAPON_CZ75) == -1)
            ReplaceWeapon(client, WEAPON_TEC9, WEAPON_CZ75);
    }
    
    if (g_Prefs[client].ReplaceMP7)
    {
        // 检查主武器槽是否已被替换
        if (FindWeapon(client, WEAPON_MP5) == -1)
            ReplaceWeapon(client, WEAPON_MP7, WEAPON_MP5);
    }
    if (g_Prefs[client].ReplaceDeagle)
    {
        if (FindWeapon(client, WEAPON_R8) == -1)
            ReplaceWeapon(client, WEAPON_DEAGLE, WEAPON_R8);
    }
}

public Action Event_ItemPurchase(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidClient(client) || !IsPlayerAlive(client) || !g_Prefs[client].SettingsLoaded)
        return Plugin_Continue;

    char weapon[32];
    event.GetString("weapon", weapon, sizeof(weapon));
    
    // 标准化武器名称
    char normalizedWeapon[32];
    strcopy(normalizedWeapon, sizeof(normalizedWeapon), weapon);
    if (StrContains(normalizedWeapon, "weapon_") == 0)
    {
        strcopy(normalizedWeapon, sizeof(normalizedWeapon), weapon[7]);
    }
    
    // 清理过期的替换队列
    g_hWeaponReplaceQueue[client].Clear();
    
    // 根据偏好处理武器替换
    if (g_Prefs[client].ReplaceP2000 && StrEqual(normalizedWeapon, "hkp2000"))
    {
        if (FindWeapon(client, WEAPON_USP) == -1)
            ReplaceWeapon(client, WEAPON_P2000, WEAPON_USP);
    }
    else if (g_Prefs[client].ReplaceM4A4 && StrEqual(normalizedWeapon, "m4a1"))
    {
        // 防止重复替换
        if (FindWeapon(client, WEAPON_M4A1) == -1)
            ReplaceWeapon(client, WEAPON_M4A4, WEAPON_M4A1);
    }
    else if (g_Prefs[client].ReplaceMP7 && StrEqual(normalizedWeapon, "mp7"))
    {
        if (FindWeapon(client, WEAPON_MP5) == -1)
            ReplaceWeapon(client, WEAPON_MP7, WEAPON_MP5);
    }
    else if (g_Prefs[client].ReplaceDeagle && StrEqual(normalizedWeapon, "deagle"))
    {
        if (FindWeapon(client, WEAPON_R8) == -1)
            ReplaceWeapon(client, WEAPON_DEAGLE, WEAPON_R8);
    }
    else if (g_Prefs[client].ReplacePistols)
    {
        if (GetClientTeam(client) == CS_TEAM_CT && StrEqual(normalizedWeapon, "fiveseven"))
        {
            if (FindWeapon(client, WEAPON_CZ75) == -1)
                ReplaceWeapon(client, WEAPON_FIVESEVEN, WEAPON_CZ75);
        }
        else if (GetClientTeam(client) == CS_TEAM_T && StrEqual(normalizedWeapon, "tec9"))
        {
            if (FindWeapon(client, WEAPON_CZ75) == -1)
                ReplaceWeapon(client, WEAPON_TEC9, WEAPON_CZ75);
        }
    }
    
    return Plugin_Continue;
}

void ReplaceWeapon(int client, const char[] oldWeapon, const char[] newWeapon)
{
    // 将替换请求加入队列
    char replaceInfo[64];
    Format(replaceInfo, sizeof(replaceInfo), "%s;%s", oldWeapon, newWeapon);
    g_hWeaponReplaceQueue[client].PushString(replaceInfo);
    
    DataPack pack = new DataPack();
    pack.WriteCell(GetClientUserId(client));
    pack.WriteString(replaceInfo);
    // 调整替换延迟以减少冲突
    float delay = g_bIsDeathmatch ? 0.5 : 0.2;
    CreateTimer(delay, Timer_ProcessWeaponReplace, pack, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_ProcessWeaponReplace(Handle timer, DataPack pack)
{
    pack.Reset();
    int client = GetClientOfUserId(pack.ReadCell());
    char replaceInfo[64];
    pack.ReadString(replaceInfo, sizeof(replaceInfo));
    delete pack;
    
    if (!IsValidClient(client) || !IsPlayerAlive(client))
    {
        return Plugin_Stop;
    }
    
    int index = g_hWeaponReplaceQueue[client].FindString(replaceInfo);
    if (index == -1)
    {
        return Plugin_Stop;
    }
    
    g_hWeaponReplaceQueue[client].Erase(index);
    
    char parts[2][32];
    if (ExplodeString(replaceInfo, ";", parts, sizeof(parts), sizeof(parts[])) != 2)
    {
        return Plugin_Stop;
    }
    
    char oldWeapon[32], newWeapon[32];
    strcopy(oldWeapon, sizeof(oldWeapon), parts[0]);
    strcopy(newWeapon, sizeof(newWeapon), parts[1]);
    
    int weapon = FindWeapon(client, oldWeapon);
    if (weapon == -1)
    {
        return Plugin_Stop;
    }
    
    // 检查目标武器是否已存在，防止重复替换
    if (FindWeapon(client, newWeapon) != -1)
    {
        // 直接删除旧武器而不是丢弃
        if (RemovePlayerItem(client, weapon))
        {
            AcceptEntityInput(weapon, "Kill");
        }
        return Plugin_Stop;
    }
    
    // 获取武器价格
    int oldPrice, newPrice;
    if (!g_WeaponPrices.GetValue(oldWeapon, oldPrice) || !g_WeaponPrices.GetValue(newWeapon, newPrice))
    {
        return Plugin_Stop;
    }
    
    // 处理武器替换 - 根据游戏模式使用不同的顺序
    int newWeaponEnt = -1;
    
    if (g_bIsDeathmatch)
    {
        // 死亡竞赛模式：先添加新武器再删除旧武器
        newWeaponEnt = GivePlayerItem(client, newWeapon);
        if (newWeaponEnt != -1 && IsValidEntity(newWeaponEnt))
        {
            EquipPlayerWeapon(client, newWeaponEnt);
            
            // 删除旧武器
            if (RemovePlayerItem(client, weapon))
            {
                AcceptEntityInput(weapon, "Kill");
            }
        }
    }
    else
    {
        // 非死亡竞赛模式：先删除旧武器再添加新武器
        if (RemovePlayerItem(client, weapon))
        {
            AcceptEntityInput(weapon, "Kill");
        }
        
        newWeaponEnt = GivePlayerItem(client, newWeapon);
        if (newWeaponEnt != -1 && IsValidEntity(newWeaponEnt))
        {
            EquipPlayerWeapon(client, newWeaponEnt);
        }
    }
    
    if (newWeaponEnt == -1 || !IsValidEntity(newWeaponEnt))
    {
        return Plugin_Stop;
    }
    
    // 设置活动武器
    int slot = GetWeaponSlot(newWeapon);
    if (slot != -1 && GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon") != newWeaponEnt)
    {
        ClientCommand(client, "use %s", newWeapon);
    }
    
    // 调整玩家金钱
    if (oldPrice != newPrice)
    {
        int currentMoney = GetEntProp(client, Prop_Send, "m_iAccount");
        int moneyDiff = oldPrice - newPrice; // 正数表示退款，负数表示扣款
        int newMoney = currentMoney + moneyDiff;
        newMoney = (newMoney < 0) ? 0 : (newMoney > 16000) ? 16000 : newMoney;
        SetEntProp(client, Prop_Send, "m_iAccount", newMoney);
    }
    
    return Plugin_Stop;
}

int FindWeapon(int client, const char[] weaponClass)
{
    // 查找玩家身上的指定武器
    int i = 0;
    int weapon = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
    while (weapon != -1)
    {
        char classname[32];
        if (GetEntityClassname(weapon, classname, sizeof(classname)) && StrEqual(classname, weaponClass))
            return weapon;
        weapon = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", ++i);
    }
    return -1;
}

int GetWeaponSlot(const char[] weapon)
{
    // 获取武器的插槽位置
    int slot;
    if (g_WeaponSlots.GetValue(weapon, slot))
        return slot;
    return -1;
}

bool IsValidClient(int client)
{
    // 验证客户端是否有效
    return (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client));
}

public void OnClientDisconnect(int client)
{
    // 玩家断开连接时清理数据
    g_Prefs[client].ReplaceP2000 = false;
    g_Prefs[client].ReplaceM4A4 = false;
    g_Prefs[client].ReplaceMP7 = false;
    g_Prefs[client].ReplaceDeagle = false;
    g_Prefs[client].ReplacePistols = false;
    g_Prefs[client].SettingsLoaded = false;
    g_hWeaponReplaceQueue[client].Clear();
}

public void OnPluginEnd()
{
    // 插件结束时清理所有武器替换队列
    for (int i = 0; i <= MAXPLAYERS; i++)
    {
        delete g_hWeaponReplaceQueue[i];
    }
    delete g_WeaponPrices;
    delete g_WeaponSlots;
}