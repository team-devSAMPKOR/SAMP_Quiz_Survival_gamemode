/*@u4bi v.01
  @Quiz_Survival_gamemode
  @https://github.com/u4bi
*/
#include <a_samp>
#include <a_mysql>
#include <foreach>

/*MANAGER 100 */
#define INIT        100
#define SQL         101

/*init 200 */
#define GAMEMODE    200
#define SERVER      201
#define MYSQL       202
#define THREAD      203
#define USERDATA    204

/*query 300 */
#define CHECK       300
#define REGIST      301
#define SAVE        302
#define LOAD        303

/*Dialog 400 */
#define DL_LOGIN    400
#define DL_REGIST   401
#define DL_INFO     402
#define DL_QUIZ     403

/*ZONE BASE */
#define USED_ZONE 932

main(){}

forward check(playerid);
forward regist(playerid, pass[]);
forward save(playerid);
forward load(playerid);
forward ServerThread();

/* variable */
new zoneBase[932];
new infoMessege[3][502] = {
	"{FFFF00}QUIZ SERVER{FFFFFF}\n\n 문화상품권 발굴 서바이벌 퀴즈 게임모드입니다.\n\n1단계부터 10단계까지의 미션을 통과하여 문화상품권을 챙취하세요.\n\n{FFFF00}상품{FFFFFF}\n\n1등 : 문화상품권 30,000원 (선착순 1인)\n2등 : 문화상품권 10,000원 (선착순 1인)\n3등 : 문화상품권 5,000원   (선착순 2인)\n\n{FFFF00}게임방법{FFFFFF}\n\n /tip : 문제를 확인하세요.",
	"{FFFF00}PASS STAGE PEOPLE\n\n단계별 미션 통과자{FFFFFF}\n\nStage 1 :\t\t %d명\nStage 2 :\t\t %d명\nStage 3 :\t\t %d명\nStage 4 :\t\t %d명\nStage 5 :\t\t %d명\nStage 6 :\t\t %d명\nStage 7 :\t\t %d명\nStage 8 :\t\t %d명\nStage 9 :\t\t %d명\nStage 10 :\t\t %d명\n\n{FFFF00}당신은 현재 %d단계입니다.\n",
	"{FFFFFF}rootcode10@gmail.com\n 하이오"
};

new tipArray [ ] [  ] [ ] = {
	{
		"얼굴없는 두 바위 속에 갖혀버린 그들의 원한 서린 영혼의 수",
		"어릴적 부둣가 할아버지의 서재에서 잠이든 순간",
		"꿈이 담긴 상자속 그들의 일그러진 보물 매립지",
		"삼각자, 원 7개, 빛나는 태양, 높이 올라가라",
		"7계단을 내려가니 풍덩 그 앞으로 걸어가라"
	},
	{
		"",
		"",
		"",
		"",
		""
	},
	{
		"",
		"",
		"",
		"",
		""
	},
	{
		"",
		"",
		"",
		"",
		""
	},
	{
		"",
		"",
		"",
		"",
		""
	},
	{
		"",
		"",
		"",
		"",
		""
	},
	{
		"",
		"",
		"",
		"",
		""
	},
	{
		"",
		"",
		"",
		"",
		""
	},
	{
		"",
		"",
		"",
		"",
		""
	},
	{
		"",
		"",
		"",
		"",
		""
	}
};

enum USER_MODEL{
 	ID,
	NAME[MAX_PLAYER_NAME],
	PASS[24],
	ADMIN,
	MONEY,
	KILLS,
	DEATHS,
	SKIN,
	Float:POS_X,
	Float:POS_Y,
	Float:POS_Z,
	Float:ANGLE,
 	Float:HP,
 	Float:AM
}
new USER[MAX_PLAYERS][USER_MODEL];

enum INGAME_MODEL{
	bool:LOGIN,
	bool:SPAWN_CAR,
	Float:SPAWN_POS_X,
	Float:SPAWN_POS_Y
}
new INGAME[MAX_PLAYERS][INGAME_MODEL];

enum DYNAMIC_INGAME_MODEL{
	bool:SPAWN_CAR,
	SPAWN_CAR_NUM
}
new DYNAMIC_INGAME[MAX_PLAYERS][DYNAMIC_INGAME_MODEL];

static mysql;
/* call back ------------------------------------------------------------------------------------------------
	@ OnGameModeExit
	@ OnGameModeInit -> manager(INIT)
	@ OnPlayerRequestClass -> join(playerid, type) ->
                                            <- return function -> login0/regist1
                                            manager(SQL, CHECK, playerid) : join user id check
	@ OnDialogResponse -> 	@ login dialog
                            @ regist dialog

	@ OnPlayerCommandText ->@ /sav : data save

	@ OnPlayerDisconnect -> @ data save
	                        @ init enum
	                        
	@ OnPlayerDeath  -> @ death
*/

public OnGameModeExit(){return 1;}
public OnGameModeInit(){
	manager(INIT, GAMEMODE);
	manager(INIT, SERVER);
	manager(INIT, MYSQL);
	manager(INIT, THREAD);
	return 1;
}

public OnPlayerRequestClass(playerid, classid){
	if(INGAME[playerid][LOGIN]) return SendClientMessage(playerid,-1,"already login");
	join(playerid, manager(SQL, CHECK, playerid));
	setupGangzone(playerid);
	SetPlayerColor(playerid, 0xE6E6E6E6);
	return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[]){
	if(!response) if(dialogid == DL_LOGIN || dialogid == DL_REGIST) return Kick(playerid);

	switch(dialogid){
		case DL_LOGIN  : checked(playerid, inputtext);
		case DL_REGIST : manager(SQL, REGIST, playerid, inputtext);
		case DL_INFO   : info(playerid,listitem);
	}
	return 1;
}

stock info(playerid, listitem){
	new result[502];
	if(listitem ==1) format(result,sizeof(result), infoMessege[listitem],0,0,0,0,0,0,0,0,0,0,1);
	else format(result,sizeof(result), infoMessege[listitem]);
	ShowPlayerDialog(playerid, DL_QUIZ, DIALOG_STYLE_MSGBOX, "manager",result, "Close", "");
}

public OnPlayerCommandText(playerid, cmdtext[]){
	if(!strcmp("/sav", cmdtext)){
	    if(GetPlayerWeapon(playerid) == 46) return SendClientMessage(playerid,-1,"not save (reason: Parachute Weapon)");
	    if(GetPlayerAnimationIndex(playerid) == 1130) return SendClientMessage(playerid,-1,"not save (reason: Fail Anim)");
		if(!INGAME[playerid][LOGIN]) return SendClientMessage(playerid,-1,"not login");
		manager(SQL, SAVE, playerid);
		SendClientMessage(playerid,-1,"   data save");
        return 1;
    }
	if(!strcmp("/help", cmdtext)){
		ShowPlayerDialog(playerid, DL_INFO, DIALOG_STYLE_LIST, "manager", "Game Rule\nRound Stats\nfeedback\n","Select", "Cancel");
        return 1;
 	}
	if(!strcmp("/tip", cmdtext)){
		new result[502];
		new stage = 1;
		new unit = 1;
		new puz[][] = {"퍼즐조각 (3번째)"};
		
		format(result,sizeof(result), "{FFFF00}단서 %d : 단서를 추적하시오.{FFFFFF}\n\n%s\n%s\n\n{FFFF00}출제코드 : MJ161024100%d{FFFFFF}\n단서 유효기한(2016/10/24~2016/11/01)",stage,tipArray[0][0],puz[0],unit);
		ShowPlayerDialog(playerid, DL_QUIZ, DIALOG_STYLE_MSGBOX, "manager",result, "Close", "");
        return 1;
 	}
	return 0;
}

public OnPlayerDisconnect(playerid, reason){
	if(INGAME[playerid][LOGIN])	manager(SQL, SAVE, playerid);
	manager(INIT, USERDATA, playerid);
	DestroyVehicle(DYNAMIC_INGAME[playerid][SPAWN_CAR_NUM]);
	return 1;
}

public OnPlayerDeath(playerid, killerid, reason){
	death(playerid, killerid, reason);
	DestroyVehicle(DYNAMIC_INGAME[playerid][SPAWN_CAR_NUM]);
	return 1;
}

stock spawnCar(playerid){
	new carid;
	do{
	    carid = randMin(400,611);
	}
	while(isRejectCar(carid));
	
	DYNAMIC_INGAME[playerid][SPAWN_CAR] = true;
	manager(SQL, SAVE, playerid);
	DYNAMIC_INGAME[playerid][SPAWN_CAR_NUM] = CreateVehicle(carid, USER[playerid][POS_X], USER[playerid][POS_Y], USER[playerid][POS_Z], USER[playerid][ANGLE], -1, -1, -1);
	PutPlayerInVehicle(playerid, DYNAMIC_INGAME[playerid][SPAWN_CAR_NUM], 0);
	SendClientMessage(playerid,-1,"join a web server connection");
	SendClientMessage(playerid,-1,"원할한 게임 진행을 위해 서버웹에 접속해주시기 바랍니다.");
	return 1;
}
stock isRejectCar(carid){
	new result;
	switch(carid){
	    case 425,430,432,435,441,446,449,450,452,453,454,460,464,465,472,473,476,
		484,493,501,537,538,564,569,570,584,590,591,594,606,607,608,610,611 : result =1;
	    default : result =0;
	}
	return result;
}
/* manager ------------------------------------------------------------------------------------------------------------------------------
    @ manager(INIT, GAMEMODE);
    @ manager(INIT, SERVER);
    @ manager(INIT, MYSQL);
    @ manager(INIT, THREAD);
    @ manager(INIT, USERDATA, playerid);
	
    @ manager(SQL, CHECK, playerid); return function : login0/regist1

    @ manager(SQL, REGIST, playerid, pass[]);
    @ manager(SQL, SAVE, playerid);
    @ manager(SQL, LOAD, playerid);
*/
stock manager(model, type, playerid = -1, text[] = ""){
    new result;
    switch(model){
        case INIT :{
            switch(type){
                case GAMEMODE : mode();
                case SERVER   : server();
                case MYSQL    : dbcon();
                case THREAD   : thread();
                case USERDATA : cleaning(playerid);
            }
        }
        case SQL : {
            switch(type){
                case CHECK  : result = check(playerid);
                case REGIST : regist(playerid,text);
                case SAVE   : save(playerid);
                case LOAD   : load(playerid);
            }
        }
    }
    return result;
}

/* function ----------------------------------------------------------------------------------------------------------------
	@ checked(playerid, password)
	@ join(playerid, type)
*/
stock checked(playerid, password[]){
	if(strlen(password) == 0) return join(playerid, 1), SendClientMessage(playerid,-1,"password length");
	if(strcmp(password, USER[playerid][PASS])) return join(playerid, 1), SendClientMessage(playerid,-1,"login fail");

	SendClientMessage(playerid,-1,"login success");
	INGAME[playerid][LOGIN] = true;
	manager(SQL, LOAD, playerid);
	return 1;
}

stock join(playerid, type){
	switch(playerid, type){
	    case 0 : ShowPlayerDialog(playerid, DL_REGIST, DIALOG_STYLE_PASSWORD, "manager", "Regist plz", "join", "quit");
	    case 1 : ShowPlayerDialog(playerid, DL_LOGIN, DIALOG_STYLE_PASSWORD, "manager", "Login plz", "join", "quit");
	}
	return 1;
}

/*SQL -----------------------------------------------------------------------------------------------------------------------------
	@ check(playerid)
	@ regist(playerid, pass)
	@ save(playerid)
	@ load(playerid)
*/
public check(playerid){
	new query[128], result;
	GetPlayerName(playerid, USER[playerid][NAME], MAX_PLAYER_NAME);
	mysql_format(mysql, query, sizeof(query), "SELECT ID, PASS FROM `userlog_info` WHERE `NAME` = '%s' LIMIT 1", USER[playerid][NAME]);
	mysql_query(mysql, query);

	result = cache_num_rows();
	if(result){
		USER[playerid][ID] 	= cache_get_field_content_int(0, "ID");
		cache_get_field_content(0, "PASS", USER[playerid][PASS], mysql, 24);
	}
	return result;
}

public regist(playerid, pass[]){
	fixSpawnPos(playerid);
	format(USER[playerid][PASS],24, "%s",pass);

	new query[256];
	GetPlayerName(playerid, USER[playerid][NAME], MAX_PLAYER_NAME);
	mysql_format(mysql, query, sizeof(query), "INSERT INTO `userlog_info` (`NAME`,`PASS`,`ADMIN`,`MONEY`,`KILLS`,`DEATHS`,`SKIN`,`POS_X`,`POS_Y`,`POS_Z`,`ANGLE`,`HP`,`AM`) VALUES ('%s','%s',%d,%d,%d,%d,%d,%f,%f,%f,%f,%f,%f)", USER[playerid][NAME], USER[playerid][PASS],
	USER[playerid][ADMIN] = 0,
	USER[playerid][MONEY] = 1000,
	USER[playerid][KILLS] = 0,
	USER[playerid][DEATHS] = 0,
	USER[playerid][SKIN] = 26,
	USER[playerid][POS_X] = INGAME[playerid][SPAWN_POS_X],
 	USER[playerid][POS_Y] = INGAME[playerid][SPAWN_POS_Y],
	USER[playerid][POS_Z] = 1200.000,
	USER[playerid][ANGLE] = 255.7507,
	USER[playerid][HP] = 100.0,
	USER[playerid][AM] = 100.0);

	mysql_query(mysql, query);
	USER[playerid][ID] = cache_insert_id();

	SendClientMessage(playerid,-1,"regist success");
	INGAME[playerid][LOGIN] = true;
	spawn(playerid);
}

public save(playerid){
	GetPlayerPos(playerid,USER[playerid][POS_X],USER[playerid][POS_Y],USER[playerid][POS_Z]);
	GetPlayerFacingAngle(playerid, USER[playerid][ANGLE]);

	new query[256];
	mysql_format(mysql, query, sizeof(query), "UPDATE `userlog_info` SET `ADMIN`=%d,`MONEY`=%d,`KILLS`=%d,`DEATHS`=%d,`SKIN`=%d,`POS_X`=%f,`POS_Y`=%f,`POS_Z`=%f,`ANGLE`=%f,`HP`=%f,`AM`=%f WHERE `ID`=%d",
	USER[playerid][ADMIN], USER[playerid][MONEY], USER[playerid][KILLS], USER[playerid][DEATHS], USER[playerid][SKIN], USER[playerid][POS_X],
	USER[playerid][POS_Y], USER[playerid][POS_Z], USER[playerid][ANGLE], USER[playerid][HP], USER[playerid][AM], USER[playerid][ID]);

	mysql_query(mysql, query);
}

public load(playerid){
	new query[128];
	mysql_format(mysql, query, sizeof(query), "SELECT * FROM `userlog_info` WHERE `ID` = %d LIMIT 1", USER[playerid][ID]);
	mysql_query(mysql, query);

	USER[playerid][ADMIN]   = cache_get_field_content_int(0, "ADMIN");
	USER[playerid][MONEY]   = cache_get_field_content_int(0, "MONEY");
	USER[playerid][KILLS]   = cache_get_field_content_int(0, "KILLS");
	USER[playerid][DEATHS]  = cache_get_field_content_int(0, "DEATHS");
	USER[playerid][SKIN]    = cache_get_field_content_int(0, "SKIN");
	USER[playerid][POS_X]   = cache_get_field_content_float(0, "POS_X");
	USER[playerid][POS_Y]   = cache_get_field_content_float(0, "POS_Y");
	USER[playerid][POS_Z]   = cache_get_field_content_float(0, "POS_Z");
	USER[playerid][ANGLE]   = cache_get_field_content_float(0, "ANGLE");
	USER[playerid][HP]      = cache_get_field_content_float(0, "HP");
	USER[playerid][AM]      = cache_get_field_content_float(0, "AM");
	spawn(playerid);
}

/* ingame function -----------------------------------------------------------------------------------------------------------------------------
	@ spawn(playerid)
*/
stock spawn(playerid){
	SetSpawnInfo(playerid, 0, USER[playerid][SKIN], USER[playerid][POS_X], USER[playerid][POS_Y], USER[playerid][POS_Z], USER[playerid][ANGLE], 0, 0, 0, 0, 0, 0);
	SpawnPlayer(playerid);
	ResetPlayerMoney(playerid);
	GivePlayerMoney(playerid, USER[playerid][MONEY]);
	SetPlayerHealth(playerid, USER[playerid][HP]);
	SetPlayerArmour(playerid, USER[playerid][AM]);
}

/*INIT -----------------------------------------------------------------------------------------------------------------------------
	@ thread() -> ServerThread()
	@ server()
	@ mode()
	@ dbcon()
	@ cleaning(playerid) : init enum
*/
stock thread(){
	SetTimer("ServerThread", 500, true);
}
stock server(){
	SetGameModeText("Blank Script");
	EnableStuntBonusForAll(0);
	DisableInteriorEnterExits();
	ShowPlayerMarkers(PLAYER_MARKERS_MODE_OFF);
	AddPlayerClass(0,0,0,0,0,0,0,0,0,0,0);
	gangZone();
}
stock mode(){}
/* TODO : README
	scriptfiles/database.cfg [new file]

	hostname=localhost
	username=
	database=
	password=

*/
stock dbcon(){
    new db_key[4][128] = {"hostname", "username", "database", "password"};
    new db_value[4][128];

    new File:cfg=fopen("database.cfg", io_read);
    new temp[64], tick =0;

    while(fread(cfg, temp)){
        if(strcmp(temp, db_key[tick])){
            new pos = strfind(temp, "=");
            strdel(temp, 0, pos+1);
            new len = strlen(temp);
            if(tick != 3)strdel(temp, len-2, len);
            db_value[tick] = temp;
        }
        tick++;
    }
    mysql = mysql_connect(db_value[0], db_value[1], db_value[2], db_value[3]);
    mysql_set_charset("euckr");

    if(!mysql_errno(mysql))print("db connection success.");
}

stock cleaning(playerid){
	new temp[USER_MODEL];
	new temp2[INGAME_MODEL];
	new temp3[DYNAMIC_INGAME_MODEL];
	USER[playerid] = temp;
	INGAME[playerid] = temp2;
	DYNAMIC_INGAME[playerid] = temp3;
}

/* SERVER THREAD -----------------------------------------------------------------------------------------------------------------------------
	foreach
	    eventMoney : timer 500 give money +1
*/

public ServerThread(){
    foreach (new i : Player){
        eventMoney(i);
        isSpawning(i);
    }
}

/* stock -----------------------------------------------------------------------------------------------------------------------------
	@ eventMoney(playerid) -> giveMoney(playerid,money)
*/

stock gangZone(){
	new pos[4] = { -3000, 2800, -2800, 3000 };
	new fix = 200, tick = 0;
	
	for(new i = 0; i < USED_ZONE; i++){
		tick++;
		if(tick == 31){
			tick = 1;
			pos[0] = -3000;
			pos[1] = pos[1] - fix;
			pos[2] = -2800;
			pos[3] = pos[3] - fix;
		}
		zoneBase[i] = GangZoneCreate(pos[0], pos[1], pos[2], pos[3]);
		pos[0] = fix + pos[0];
		pos[2] = fix + pos[2];
	}
}

stock setupGangzone(playerid){
	new zoneCol[2] = { 0xFFFFFF99, 0xAFAFAF99};
	new flag = 0, flag2 = 0, tick = 0;
	
	for(new i = 0; i < USED_ZONE; i++){
		tick++;
		if(tick == 31){
			tick = 1;
			flag2 = !flag2;
		}
		flag = !flag;
		if(flag == 1){
			if(flag2 == 1){
				GangZoneShowForPlayer(playerid, zoneBase[i], zoneCol[0]);
			}else{
				GangZoneShowForPlayer(playerid, zoneBase[i], zoneCol[1]);
			}
		}
		else if(!flag2){
			GangZoneShowForPlayer(playerid, zoneBase[i], zoneCol[0]);
		}else{
			GangZoneShowForPlayer(playerid, zoneBase[i], zoneCol[1]);
		}
	}
	return 0;
}

stock randMin(min, max){ return random(max - min) + min;}
stock fixSpawnPos(playerid){
	INGAME[playerid][SPAWN_POS_X] = randMin(-3000,3000);
	INGAME[playerid][SPAWN_POS_Y] = randMin(-3000,3000);
}

stock isSpawning(playerid){
	if(DYNAMIC_INGAME[playerid][SPAWN_CAR]) return 1;
	if(GetPlayerAnimationIndex(playerid) == 1130) return GivePlayerWeapon(playerid, 46, 1);
	if(GetPlayerAnimationIndex(playerid) == 1224) return spawnCar(playerid);
	return 1;
}

stock eventMoney(playerid){giveMoney(playerid, 1);}
stock giveMoney(playerid,money){
	ResetPlayerMoney(playerid);
	GivePlayerMoney(playerid, USER[playerid][MONEY]+=money);
}

stock death(playerid, killerid, reason){
	fixSpawnPos(playerid);

	DYNAMIC_INGAME[playerid][SPAWN_CAR] = false;
	
	USER[playerid][POS_X]   = INGAME[playerid][SPAWN_POS_X];
 	USER[playerid][POS_Y]   = INGAME[playerid][SPAWN_POS_Y];
	USER[playerid][POS_Z]   = 1200.000;
	USER[playerid][DEATHS] -= 1;
	USER[playerid][HP]      = 100.0;
	USER[playerid][AM]      = 100.0;
	
	spawn(playerid);
	if(reason == 255) return 1;
	USER[killerid][KILLS] += 1;
	return 1;
}
