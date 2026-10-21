/*
float() SM_Slenderman_AI_Style =
{
    if (IsMap("sanatorium")) return SM_AI_SLENDER_SHADOW;
    else if (IsMap("hospice")) return SM_AI_SLENDER_SHADOW;
    else if (IsMap("elementary")) return SM_AI_SLENDER_SHADOW;
    else if (IsMap("mansion")) return SM_AI_SLENDER_SHADOW;
    else if (IsMap("claustrophobia")) return SM_AI_SLENDER_SHADOW;
    else if (IsMap("7thstreet")) return SM_AI_SLENDER_SHADOW;
    else if (IsMap("prison")) return SM_AI_WEEPING_ANGEL;
    else if (IsMap("carnival")) return SM_AI_SLENDER_SHADOW;

    return SM_AI_EIGHT_PAGES;
};
*/

float() SM_Check_Slenderman_SpawnConditions =
{
    if (!SM_Check_ActivePlayers()) return FALSE; // Sleeper: If there are no active players, don't spawn Slender Man.
    if (self.style == SM_AI_WEEPING_ANGEL && sm_collectibles <= 0) return FALSE; // Sleeper: Must wait until a player has picked up a collectible in Prison.
    if (sm_activeplayer_timecount <= 0) return FALSE; // Sleeper: If there are no collectibles are picked up or the active player time count is 0, don't spawn Slender Man.

    return TRUE;
};

void() remove_slenderman = // Sleeper: Removes all Slender Men from the map.
{
    local entity slendy;

    self.state &= ~SM_SLENDERMAN_ACTIVE; // Sleeper: No players are active, so Slender Man is inactive.
    sm_current_track = 2; // Sleeper: Null out the music.
    sm_event_clock = sm_activeplayer_timecount = sm_slenderman_aggression = 0; // Sleeper: Zero everything out.
    for (slendy = find(world, classname, "monster_slenderman"); slendy; slendy = find(slendy, classname, "monster_slenderman"))
    {
        sm_slenderman_count = clamp(sm_slenderman_count - 1, 0, 4); // Sleeper: Decrement the Slender Man count by 1, but keep it between 0 and 4.
        remove (slendy);
    }
};

entity() SelectSlenderSpawnPoint =
{
    local entity spot, spots, next_spot;
    local float  numspots = 0;

    // Sleeper: Build a list of spot.
    spot = find(world, classname, "info_slender");
    spots = spot; // Sleeper: Remember the head of our local list.
    while (spot != world)
    {
        numspots += 1;
        next_spot = find(spot, classname, "info_slender"); // Sleeper: Find the next spot on the map.
        spot.goalentity = next_spot;
        spot = next_spot;
    }

    if (numspots == 0) return world; // Sleeper: We didn't find a spot for Slender Man.

    // Sleeper: Pick a random spot.
    numspots = rint(random() * (numspots - 1));
    spot = spots;
    while (numspots > 0) 
    {
        spot = spot.goalentity;
        numspots--;
    }
    
    return spot; // Sleeper: Spot selected, now use it.
};

void() slenderman_ai = // Sleeper: Maybe later variants of Slender Man, we'll add in animations similar to Slender: The Arrival where he has walking animations.
{
    // Sleeper: We're working merely off of other people's analysis', as there's little documentation written anywhere on the internet.
};

void() slenderman_think = // Sleeper: The plan is to have Slender's AI code by controlled by a think function. We can do radius checks in combination with either tracebox or traceline to make sure he doesn't end up in walls when teleporting.
{
    self.nextthink = time + 0.1;
    self.think = slenderman_think;
    slenderman_ai ();
};

void(float j) slenderman_mitosis =
{
    local float i;

    sm_slenderman_count = clamp(j, 1, 4); // Sleeper: Keep track how many Slender Men are spawned for the current map.
    for (i = 1; i <= sm_slenderman_count; i++) 
    {
        entity slendy = spawn ();
        slendy.owner = self;
        slendy.solid = SOLID_SLIDEBOX;
        slendy.movetype = MOVETYPE_TOSS;
        slendy.takedamage = DAMAGE_NO;
        slendy.classname = "monster_slenderman";
        slendy.style = (self.style) ? self.style : SM_AI_EIGHT_PAGES; // Sleeper: Passes through the AI style from the event manager.
        slendy.nextthink = time + 0.1;
        slendy.think = slenderman_think;
        setmodel (slendy, "slender/slenderman.mdl");
        setorigin (slendy, self.origin); // Sleeper: We can adjust this later so each mitosis doesn't spawn inside each other.
        setsize (slendy, VEC_HULL2_MIN, VEC_HULL2_MAX);
        total_monsters += 1;
    }
};

void() monster_slenderman =
{
    if (deathmatch)
    {
        remove (self);
        return;
    }

    precache_model ("slender/slenderman.mdl");
    slenderman_mitosis ((self.style == SM_AI_WEEPING_ANGEL) ? 1 : ((skill >= 3) ? 4 : ((skill == 2) ? 2 : 1))); // Sleeper: 4 Slender Men for Nightmare, 2 for Hard, 1 for Easy/Normal.
};

void() info_slender = // Sleeper: This is used to spawn Slender Man at a specific location in the map.
{
    if (deathmatch) // Sleeper: Don't use Slender Man's spawn point in deathmatch.
	{
		remove (self);
		return;
	}
};