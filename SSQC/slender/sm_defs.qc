// TEMPORARY START
float(float value, float minValue, float maxValue) clamp = {return (value > maxValue) ? maxValue : ((value < minValue) ? minValue : value);};

string(string fmt, ...) sprintf = #627; /* Part of DP_QC_SPRINTF
		'prints' to a formatted temp-string. Mostly acts as in C, however %d assumes floats (fteqcc has arg checking. Use it.).
		type conversions: l=arg is an int, h=arg is a float, and will work as a prefix for any float or int representation.
		float representations: d=decimal, e,E=exponent-notation, f,F=floating-point notation, g,G=terse float, c=char code, x,X=hex
		other representations: i=int, s=string, S=quoted and marked-up string, v=vector, p=pointer
		so %ld will accept an int arg, while %hi will expect a float arg.
		entities, fields, and functions will generally need to be printed as ints with %i. */

float(string map_specify) IsMap = {return (world.model == sprintf("maps/%s.bsp", map_specify)) ? TRUE : FALSE;}; // Sleeper: A more simplier, shorter and convenient way to check for a map.

// slenderman stuff
void() monster_slenderman;
void() remove_slenderman;
void() doorSM_touch;
float() SM_Check_Slenderman_SpawnConditions;
entity() SelectSlenderSpawnPoint; 

// Sleeper: Some of these will need to converted into fields so we can still have each player have their own counts of... gameplay variables. 
// But we can still get it to the point we can treat these fields as one single global across all players if we just loop through them all.
// Such as keys, collectibles, activity timers alike.
entity sm_entitymanager; // Sleeper: To keep track of the event manager.
float sm_collectibles; // Sleeper: How many collectibles players have collected so far.
float sm_keys; // Sleeper: How many keys have players collected?
float sm_max_keys; // Sleeper: How many keys do players need to collect?
float sm_keys_failed; // Sleeper: How many times has players attempts to open the wrong door?
float sm_max_collectibles; // Sleeper: Dependant on difficulty, how many collectibles do players need to collect?
float sm_slenderman_aggression; // Sleeper: How angry is Slender Man?
float sm_activeplayer_timecount; // Sleeper: (In minutes) how long has players been active?
float sm_slenderman_count; // Sleeper: How many Slender Men are there?
float sm_event_clock; // Sleeper: The scary clock.
float sm_world_clock; // Sleeper: Just a tracker for real time.
float sm_current_track; // Sleeper: Tracks what page music we want to use.
float num_players;
float num_alive_players;
float sm_spawned_items;
.float sm_touched; // Sleeper: Has this collectible been touched? (Makes things easier to undo things when there are no active players.)
.float sm_itemspot_id;
.float sm_itemspot_subid;
.entity next_key;
.float key_inventory;
.string key_target;
.string key_targetname;
.float sm_door_touched;

float SM_SMS_TRACKCOUNT = 6;
float SM_EIGHTPAGES_TRACKCOUNT = 4;

enumflags 
{
    SM_INACTIVE_MONSTERS = 0,
    SM_SLENDERMAN_ACTIVE = 1
    // Sleeper: Room for other known characters from the Slender Man mythos, like Kate, and Charlie. However, I wouldn't recommend having more than one mitosis of Slender Man if we use those characters.
};

enum 
{
	SM_NONE_MUSIC = 0, 
    SM_EIGHT_PAGES_MUSICSET = 1,
    SM_7THSTREET_MUSICSET = 2,
    SM_PRISON_MUSICSET = 3
};

enum
{
    SM_TRACK1 = 0,
    SM_TRACK2 = 1,
    SM_TRACK3 = 2,
    SM_TRACK4 = 3,
    SM_TRACK5 = 4,
    SM_TRACK6 = 5
};

enum 
{
    SM_AI_EIGHT_PAGES = 0, // Sleeper: The original Slender Man AI.
    SM_AI_SLENDER_SHADOW = 1, // Sleeper: The normal Slender Man's Shadow AI
    SM_AI_WEEPING_ANGEL = 2 // Sleeper: Weeping Angel (Slender Man's Shadow: Prison AI). They say it's the most brutal.
};

// Sleeper:
// TODO:
// • Slender Man's AI:
//   • This needs to be thoroughly thought out as there's little documentation for each style except for the original 8 pages.

// TEMPORARY END

void() PrecacheSlenderItems =
{
    // Anything that can be picked up.
    // Pages
    // Mementos
    // Keys
};

void() PrecacheSlenderMonsters =
{
    precache_model ("slender/slenderman.mdl");
};

void() PrecacheSlenderWorld =
{
    PrecacheSlenderItems ();
    PrecacheSlenderMonsters ();
};

void() PrecacheSlender =
{
    PrecacheSlenderWorld ();
};

/* // Sleeper: Still here, so we can use the values in the map editor when we need to. Will convert into table later.
float() SM_Max_Aggression = 
{
    // Sleeper: Slender Man's Shadow Maps (none of these are publically documented so this is just a guess).
    if (IsMap("sanatorium")) return 80;
    else if (IsMap("hospice")) return 80;
    else if (IsMap("elementary")) return 100;
    else if (IsMap("mansion")) return 80;
    else if (IsMap("claustrophobia")) return 110;
    else if (IsMap("7thstreet")) return 110;
    else if (IsMap("prison")) return 120; // Sleeper: Hello again, my weeping angel...
    else if (IsMap("carnival")) return 100; // Sleeper: Not publically documented.

    // Sleeper: Based off of the original eight pages (usually 8, but probably better to assume maximum objective collectibles since we can have more than just 8 collectibles).
    return sm_max_collectibles;
};

float() SM_Keys_Value =
{
    // Sleeper: Slender Man's Shadow Maps (Based off of the FPSC version).
//  if (IsMap("sanatorium")) return 0;
//  else if (IsMap("hospice")) return 0;
//  else if (IsMap("elementary")) return 0;
//  else if (IsMap("7thstreet")) return 0;
//  else if (IsMap("prison")) return 0;
//  else if (IsMap("carnival")) return 0;

    if (IsMap("mansion")) return 4;
    else if (IsMap("claustrophobia")) return 9;

    // Sleeper: Eight pages never had keys.
    return 0; 
};

float() SM_FailureKeys_Value =
{
    // Sleeper: Slender Man's Shadow Maps (Based off of the FPSC version).
//  if (IsMap("sanatorium")) return 0;
//  else if (IsMap("hospice")) return 0;
//  else if (IsMap("elementary")) return 0;
//  else if (IsMap("mansion")) return 0;
//  else if (IsMap("7thstreet")) return 0;
//  else if (IsMap("prison")) return 0;
//  else if (IsMap("carnival")) return 0;

    if (IsMap("claustrophobia")) return 10;

    // Sleeper: Eight pages never had keys.
    return 0; 
};

float() SM_Collectible_Value =
{
    // Sleeper: Slender Man's Shadow Maps (Based off of the FPSC version).
// 	if (IsMap("claustrophobia")) return 9; // Sleeper: We do keys here. 
    
    if (IsMap("sanatorium")) return 10;
    else if (IsMap("hospice")) return 10;
    else if (IsMap("elementary")) return 10;
    else if (IsMap("mansion")) return 7;
    else if (IsMap("7thstreet")) return 11;
    else if (IsMap("prison")) return 10; // Sleeper: Hello again, my weeping angel...
    else if (IsMap("carnival")) return 10; // Sleeper: Not publically documented.

    // Sleeper: Based off of the original eight pages.
    return 1; 
};

float() SM_Passive_Aggressive_Time = // Sleeper: This dictates how Slender Man gets passively aggressive over time. The more time a player spends in the map, the more aggressive Slender Man will become.
{
    // Sleeper: Slender Man's Shadow Maps (Based off of the FPSC version).
    if (IsMap("sanatorium")) return 30;
    else if (IsMap("hospice")) return 40;
    else if (IsMap("elementary")) return 20;
    else if (IsMap("mansion")) return 15;
    else if (IsMap("claustrophobia")) return 10;
    else if (IsMap("7thstreet")) return 8.5;
    else if (IsMap("prison")) return (sm_collectibles > 0) ? 3 : 999999; // Sleeper: Hello again, my weeping angel...
    else if (IsMap("carnival")) return 30; // Sleeper: Not publically documented.

    // Sleeper: Based off of the original eight pages.
    return (60 * 5); // Sleeper: Default to 5 minutes for all other maps.
};
*/