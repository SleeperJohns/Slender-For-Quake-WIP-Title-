// Sleeper: These items should never be precached directly by the items themselves, as they're spawned, despawned and respawned at random locations set by their info spots, using the event manager.

void() sm_collectible_touch =
{
    local entity pl;
    local string stxt, ptxt;

    if ((other.health <= 0) || (other.classname != "player")) return;

    sm_collectibles += 1;
    other.frags += 1; // Sleeper: Increment score for this player.
    
    stxt = (self.classname == "item_memento") ? "memento" : ((self.classname == "item_page") ? "page" : "collectible");
    ptxt = sprintf("%s%s %g/%g", self.netname, (sm_max_collectibles == 1) ? "" : "s", sm_collectibles, sm_max_collectibles);

    pl = find(world, classname, "player");
    while (pl != world)
    {
        centerprint (pl, sprintf("%s%s\n", ptxt, (sm_collectibles == sm_max_collectibles) ? "\nFind the exit and escape!" : ""));
        pl = find(pl, classname, "player"); // Sleeper: Move to the next player.
    }

    sprint (other, sprintf("You got a %s\n", stxt));
    sound (other, CHAN_ITEM, self.noise, 1, ATTN_NORM);
    stuffcmd (other, "bf\n");

    self.model = string_null;
	self.solid = SOLID_NOT;
    SUB_UseTargets ();
};

void() item_page =
{
    setmodel (self, self.model);

    // Sleeper: Needs to be filled out.
    self.netname = "Page";
    self.touch = sm_collectible_touch;
};

void() item_memento =
{
    setmodel (self, self.model);

    // Sleeper: Needs to be filled out.
    self.netname = "Memento";
    self.touch = sm_collectible_touch;
};

void() sm_key_touch =
{
    local entity pl;

    if ((other.health <= 0) || (other.classname != "player")) return;

    // Sleeper: Find every player in the map and push this key onto their personal chain.
    pl = find(world, classname, "player");
    while (pl != world)
    {
        self.next_key = pl.next_key;
        pl.next_key = self;
        if (pl != other) centerprint (pl, sprintf("%s picked up the %s key\n", (pl == other) ? "You" : other.netname, self.netname));
        pl = find(pl, classname, "player"); // Sleeper: Move to the next player.
    }

    sm_keys += 1; // Tracks total keys globally 
    sound (other, CHAN_ITEM, self.noise, 1, ATTN_NORM);
    sprint (other, sprintf("You got the %s key\n", self.netname));
    stuffcmd (other, "bf\n");  

    self.model = string_null;
    self.solid = SOLID_NOT;
    SUB_UseTargets ();
};

void() item_keySM =
{
    if (world.worldtype == 0)
    {
        if (!self.noise) self.noise = "misc/medkey.wav";
        if (!self.model) self.mdl = self.model = "progs/w_s_key.mdl";
    }
    else if (world.worldtype == 1)
    {
        if (!self.noise) self.noise = "misc/runekey.wav";
        if (!self.model) self.mdl = self.model = "progs/m_s_key.mdl";
    }
    else if (world.worldtype == 2)
    {
        if (!self.noise) self.noise = "misc/basekey.wav";
        if (!self.model) self.mdl = self.model = "progs/b_s_key.mdl";
    }

    setmodel (self, self.model);

    if (!self.netname) self.netname = "standard";
    self.touch = sm_key_touch;
};