float() SM_Slenderman_Aggression_Scalar =
{
    local float aggr_multi = (!cvar("scratch1")) ? ((skill >= 3) ? 1.5 : (skill == 2) ? 1.25 : (skill == 0) ? 0.5 : 1.0) : clamp(cvar("scratch1"), 0.5, 2); // Sleeper: Slendy's aggression multiplier.
    local float collect_items = (self.count * sm_collectibles); // Sleeper: Make Slender Man angrier with each package pickup.
    local float collect_keys = (self.cnt * sm_keys); // Sleeper: Make Slender Man angrier with each key pickup.
    local float keys_failure = (self.frags * sm_keys_failed); // Sleeper: Make Slender Man angrier when a player tries to open the wrong door with the wrong key.
    local float active_time = sm_activeplayer_timecount; // Sleeper: Make Slender Man angrier over time.
    local float max_aggr = self.armorvalue; // Sleeper: We don't want Slender Man to have an aneurysm. 

    return clamp((((collect_items + collect_keys + keys_failure) * aggr_multi) + active_time), 1, max_aggr); // Sleeper: Combine values.
};

float() SM_Check_AlivePlayers = // Sleeper: Count living players.
{
    local entity pl;
    local float  count = 0;

    for (pl = find(world, classname, "player"); pl != world; pl = find(pl, classname, "player")) 
    {
    	if (pl.health <= 0) continue;
    	count += 1;
	}

    return count;
};

float() SM_Check_ActivePlayers = // Sleeper: Count all active players.
{
    local entity pl;
    local float  count = 0;

    for (pl = find(world, classname, "player"); pl != world; pl = find(pl, classname, "player")) count += 1;
    return count;
};

void() remove_all_slender_monsters = // Sleeper: Removes all Slender monsters from the map.
{
    remove_slenderman (); // Sleeper: Bye, bye Slender Man.
};

float() SM_Event_Count_Pages =
{
    local entity pages;
    local float  page_count = 0;

    for (pages = find(world, classname, "item_page"); pages; collectibles = find(pages, classname, "item_page")) page_count += 1; // Sleeper: Count for pages.
    return page_count;
};

float() SM_Event_Count_Mementos =
{
    local entity mementos;
    local float  memento_count = 0;

    for (mementos = find(world, classname, "item_page"); mementos; collectibles = find(mementos, classname, "item_page")) memento_count += 1; // Sleeper: Count for pages.
    return memento_count;
};

float() SM_Event_Count_Collectibles = {return SM_Event_Count_Pages() + SM_Event_Count_Mementos();};

float() SM_Event_Count_Keys =
{
    local entity keys;
    local float  key_count = 0;

    for (keys = find(world, classname, "item_keySM"); keys; keys = find(keys, classname, "item_keySM")) key_count += 1;
    return key_count;
};

void() SM_Event_SetMax_Collectibles =
{
    sm_max_collectibles = (skill >= 2) ? self.dmg : self.wait; // Sleeper: .wait sets the traditional value of collectibles on a map, .dmg sets a higher value for harder difficulties. I.E: 8 for easy and normal, 10 for hard and above.  
    sm_max_keys = (skill >= 2) ? self.volume : self.distance; // Sleeper: .distance sets the traditional value of keys on a map, .volume sets a higher value for harder difficulties. 
};

void() SM_Event_Spawn_Slenderman =
{
    local entity spot = SelectSlenderSpawnPoint (); // Sleeper: We should only ever need one, even though we might have multiple slender men walking around.
    func_SpawnEnemy (spot.origin, spot.angles, self.style, "monster_slenderman", monster_slenderman);
};

void(string item) SM_Event_Despawn_Item =
{
    local entity check;

    // Sleeper: Make things invisible and untouchable.
    for (check = find(world, classname, item); check; check = find(check, classname, item))
    {
        if (check.model != string_null) check.mdl = check.model; // Sleeper: Save off the model.
        check.model = string_null;
        check.solid = SOLID_NOT;
    }
};

void(string info, string item, void() func) SM_Event_Spawn_Item =
{
    local entity spot;

    // Sleeper: Spawn items.
    for (spot = find(world, classname, info); spot; spot = find(spot, classname, info)) func_SpawnItem (spot.origin, spot.angles, spot.sm_itemspot_id, item, func);
    
    // Sleeper: Despawn everything.
    SM_Event_Despawn_Item (item);
};

void() SM_Event_Spawn_Pages =
{
    // Sleeper: Spawn pages.
    SM_Event_Spawn_Item ("info_page_spot", "item_page", item_page);
    
    // Sleeper: Despawn everything.
    SM_Event_Despawn_Item ("item_page");
};

void() SM_Event_Spawn_Mementos =
{
    // Sleeper: Spawn mementos.
    SM_Event_Spawn_Item ("info_memento_spot", "item_memento", item_memento);
    
    // Sleeper: Despawn everything.
    SM_Event_Despawn_Item ("item_memento");
};

void() SM_Event_Spawn_Keys =
{
    // Sleeper: Spawn keys.
    SM_Event_Spawn_Item ("info_key_spot", "item_keySM", item_keySM);
    
    // Sleeper: Despawn everything.
    SM_Event_Despawn_Item ("item_keySM");
};

void() SM_Event_Spawn_All = {SM_Event_Spawn_Pages();SM_Event_Spawn_Mementos();SM_Event_Spawn_Keys();};

void(string info, string item) SM_Event_Randomize_Item = // Sleeper: This is our respawn function that randomizes item locations.
{
    local entity spot, search, check;
    local float  id, count, index, roll, done, total, remaining, needed;

    SM_Event_Despawn_Item (item); // Sleeper: Hide everything if it hasn't been already.

    id = 0;
    needed = (item == "item_keySM") ? sm_max_keys : sm_max_collectibles; // Sleeper: Sets how many needs things are needed.
    dprint (sprintf("%s needed: %g\n", item, needed));

    // Sleeper: Total up the ID groups.
    for (spot = find(world, classname, info); spot; spot = find(spot, classname, info))
    {
        id = spot.sm_itemspot_id;
        done = FALSE;

        for (check = find(world, classname, info); check != spot; check = find(check, classname, info))
        {
            if (check.sm_itemspot_id == id)
            {
                done = TRUE;
                break;
            }
        }
        if (done == FALSE) total += 1;
    }

    remaining = total;
    dprint (sprintf("%s spots found: %g\n", item, remaining));

    // Sleeper: Loop through all collectibles to select which ones to appear.
    for (spot = find(world, classname, item); spot; spot = find(spot, classname, item))
    {
        id = spot.sm_itemspot_id;
        done = FALSE;

        for (check = find(world, classname, item); check != spot; check = find(check, classname, item))
        {
            if (check.sm_itemspot_id == id)
            {
                done = TRUE;
                break;
            }
        }

        if (done == FALSE)
        {
            count = 0;

            // Sleeper: Count how many collectibles share an ID group.
            for (search = find(world, classname, item); search; search = find(search, classname, item)) if (search.sm_itemspot_id == id) count += 1;

            // Sleeper: Determine if this group should reveal a collectible based on random chance or maximum collectible requirement.
            if (needed > 0)
            {
                if ((remaining == needed) || ((random() * 100) > 10))
                {
                    index = floor(random() * count);
                    roll = 0;

                    // Sleeper: Make this item appear.
                    for (search = find(world, classname, item); search; search = find(search, classname, item))
                    {
                        if (search.sm_itemspot_id == id)
                        {
                            if (roll == index)
                            {
                                search.model = search.mdl;
                                search.solid = SOLID_TRIGGER;
                            }
                            roll += 1;
                        }
                    }
                    needed -= 1;
                }
            }
            remaining -= 1;
        }
    }
};

void() SM_Event_Reset_Pages = {sm_collectibles = 0; SM_Event_Randomize_Item("info_page_spot", "item_page");};
void() SM_Event_Reset_Mementos = {sm_collectibles = 0; SM_Event_Randomize_Item("info_memento_spot", "item_memento");};
void() SM_Event_Reset_Keys = {sm_keys = 0; SM_Event_Reset_All_Doors(); SM_Event_Randomize_Item("info_key_spot", "item_keySM");};
void() SM_Event_Reset_All = {SM_Event_Reset_Pages();SM_Event_Reset_Mementos();SM_Event_Reset_Keys();};

void() SM_Event_Setup_Pages =
{
    // Sleeper: Spawn pages on all spots (they will be forced to be appear despawned).
    SM_Event_Spawn_Pages ();

    // Sleeper: Find random locations to make pages appear at.
    SM_Event_Reset_Pages ();
};

void() SM_Event_Setup_Mementos =
{
    // Sleeper: Spawn pages on all spots (they will be forced to be appear despawned).
    SM_Event_Spawn_Mementos ();

    // Sleeper: Find random locations to make pages appear at.
    SM_Event_Reset_Mementos ();
};

void() SM_Event_Setup_Keys =
{
    // Sleeper: Spawn pages on all spots (they will be forced to be appear despawned).
    SM_Event_Spawn_Keys ();

    // Sleeper: Find random locations to make pages appear at.
    SM_Event_Reset_Keys ();
};

void() SM_Event_Setup_All = {SM_Event_Setup_Pages();SM_Event_Setup_Mementos();SM_Event_Setup_Keys();};

void() SM_Event_Setup_Collectibles =
{
    if (sm_spawned_items == TRUE) return;

    SM_Event_Setup_All ();
    sm_spawned_items = TRUE;
};

void() SM_Event_Collectibles =
{
    SM_Event_SetMax_Collectibles ();

    if (intermission_running) return;
    SM_Event_Setup_Collectibles ();
};

void() SM_Event_Reset = 
{
    if (SM_Check_ActivePlayers()) return; // Sleeper: Players active, do nothing.

    sm_current_track = 2; // Sleeper: Null out the music.
    sm_event_clock = sm_activeplayer_timecount = 0; // Sleeper: Zero out everything.  

    if (sm_world_clock >= ((60 * 60) * 3)) // Sleeper: Every 3 hours, restart the server.
    {
        localcmd ("restart\n");
        return;
    }

    if ((sm_inactivity_clock % 60) == 0) SM_Event_Reset_All (); // Sleeper: Every 60 second interval of inactivity time, randomize collectible locations when there are no players active.

    if (sm_slenderman_count > 0) remove_all_slender_monsters (); // Sleeper: Remove all enemies from the map when there are no players active.
    sm_inactivity_clock += 0.1;
};

void(entity pl) SM_Event_Player_Loop_Keys = // Sleeper: Mechanically useless, but gives somewhat an indicator of how many keys we have.
{
    if (sm_keys > 0)
    {
        if (sm_keys <= 1)
        {
            if (!(pl.items & IT_KEY1)) pl.items |= IT_KEY1; // Sleeper: Give Silver Key.
            pl.items &= ~IT_KEY2; // Sleeper: Remove Gold Key.
            return;
        }

        if (!(pl.items & IT_KEY1)) pl.items |= IT_KEY1; // Sleeper: Give Silver Key.
        if (!(pl.items & IT_KEY2)) pl.items |= IT_KEY2; // Sleeper: Give Gold Key.
        return;
    }

    pl.items &= ~IT_KEY1; // Sleeper: Remove Silver Key.
    pl.items &= ~IT_KEY2; // Sleeper: Remove Gold Key.
};

void() SM_Event_Player_Loop =
{
    local entity pl = find(world, classname, "player");
    while (pl != world)
    {
        SM_Event_Player_Loop_Keys (pl);  
        pl = find(pl, classname, "player");
    }
};

void() SM_Event_ActivePlayers =
{
    local float interval = self.delay;
    local float penalty = self.ltime;

    if (!SM_Check_ActivePlayers()) // Sleeper: If there are no active players, remove all Slender monsters from the map.
    {
        SM_Event_Reset ();
        return;
    }

    SM_Event_Player_Loop ();
    sm_inactivity_clock = 0;

    if (self.style == SM_AI_WEEPING_ANGEL && sm_collectibles <= 0) return; // Sleeper: Don't do anything yet until a player has picked up a collectible.

    sm_event_clock += 0.1; // Sleeper: Increment the event clock by 0.1 seconds. (This is what you use for timed events specific to gameplay.)
    if ((sm_event_clock % interval) <= 0) sm_activeplayer_timecount += penalty; // Sleeper: Increment whenever aggressive time threshold gets crossed. This will increase the aggression of Slender Man passively over time.
};

void() SM_Event_Slenderman =
{
    if (!SM_Check_Slenderman_SpawnConditions()) return;

    sm_slenderman_aggression = SM_Slenderman_Aggression_Scalar (); // Sleeper: Apply Slender Man's aggression curve.

    if (self.state & SM_SLENDERMAN_ACTIVE) return; // Sleeper: Slender Man is already active, so don't spawn another one.

    SM_Event_Spawn_Slenderman (); // Sleeper: Spawn Slender Man. (Reminder: Calling this will spawn 1-4 Slender Men depending on the skill level.)
    self.state |= SM_SLENDERMAN_ACTIVE; // Sleeper: Slender Man is now active.
};

void() SM_Event_ActiveMonsters =
{
    SM_Event_Slenderman (); // Sleeper: Spawn Slender Man if the conditions are met.
};

void() SM_Event_World = // Sleeper: Could place world effect events here too, such as fog, weather, etc. 
{
    sm_world_clock += 0.1; // Sleeper: Increment the world clock by 0.1 seconds.
    SM_Page_Music ();
    SM_Event_Collectibles (); // Sleeper: Collectible routines.
};

void() SM_Event_Pipeline = // Sleeper: All events must run through here.
{  
    SM_Event_World (); // Sleeper: World routines. (They should be allowed to be active all the time.)

    if (intermission_running) return; // Sleeper: Don't run events during intermission.

    SM_Event_ActivePlayers (); // Sleeper: Player routines.
    SM_Event_ActiveMonsters (); // Sleeper: Monster routines.
};

void() SM_Events =
{
    self.nextthink = time + 0.1;
    self.think = SM_Events; // Sleeper: Keep the event manager running.
    SM_Event_Pipeline (); // Sleeper: Run all events through the pipeline like it's a Player Think.
};

// Sleeper: Can be spawned in QC, or spawned via a map editor.
void() event_manager =
{
    if (deathmatch) // Sleeper: Don't run the event manager in deathmatch.
    {
        remove (self);
        return;
    }

    dprint ("Event Manager: Initialized\n");

    PrecacheSlender (); // Sleeper: Precache all Slender materials.

    sm_entitymanager = self;

    self.targetname = "sm_event_manager";
    self.state = SM_INACTIVE_MONSTERS; // Sleeper: Set the state to inactive monsters.
    sm_inactivity_clock = sm_world_clock = sm_event_clock = sm_activeplayer_timecount = sm_collectibles = sm_keys = sm_keys_failed = sm_slenderman_aggression = 0; // Sleeper: We haven't spawned Slender Man yet.

    // Sleeper: Mainly for mapping if mappers want to set their difficulty curves. Default is based off of Eight Pages.
    if (!self.wait) self.wait = (SM_Event_Count_Collectibles() < 8) ? SM_Event_Count_Collectibles() : 8; // Sleeper: Minimum collectible target (used for Easy and Normal skill).
    if (!self.dmg) self.dmg = 10; // Sleeper: Maximum collectible target (use for Hard skill and higher).
    if (!self.distance) self.distance = 0; // Sleeper: Minimum keys.
    if (!self.volume) self.volume = 0; // Sleeper: Maximum keys.
    if (!self.sounds) self.sounds = SM_EIGHT_PAGES_MUSICSET; // Sleeper: What page musicset will we be playing? ((world).sounds is for intro/ambience reasons.)
    if (!self.weapon) self.weapon = SM_EIGHTPAGES_TRACKCOUNT; // Sleeper: How many tracks does this musicset have?
    if (!self.count) self.count = 1; // Sleeper: How many points do we want to put towards aggression when players pick up collectibles?
    if (!self.ltime) self.ltime = 1; // Sleeper: How many points do we want to put towards aggression when players hit a time-threshold?
    if (!self.cnt) self.cnt = 0; // Sleeper: How many points do we want to put towards aggression when players pick up a key?
    if (!self.frags) self.frags = 0; // Sleeper: How many points do we want to put towards aggression when players touch the wrong door with the wrong key?
    if (!self.delay) self.delay = (60 * 5); // Sleeper: What will be the time-threshold value? (Doesn't need "time +" to work).
    if (!self.style) self.style = SM_AI_EIGHT_PAGES; // Sleeper: What kind of AI-Style do we want? (Original Eight Pages, Slender Man's Shadow (FPSC), SMS's (FPSC) Prison (Weeping Angel))
    if (!self.armorvalue) self.armorvalue = (self.style == SM_AI_EIGHT_PAGES) ? ((skill >= 2) ? 10 : 8) : ((skill >= 2) ? 120 : 100); // Sleeper: What will be the max aggression value?

    sm_current_track = 2; // Sleeper: No page musicset should play yet.
    self.nextthink = time + 0.1;
    self.think = SM_Events; // Sleeper: Start the event manager.
};