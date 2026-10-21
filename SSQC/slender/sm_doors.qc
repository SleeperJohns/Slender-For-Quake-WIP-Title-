entity() door_check_key = // Sleeper: Check if the player's key chain contain the key that matches the door.
{
    local entity head = other.next_key;
    while (head != world)
    {
        if (head.key_target == self.key_targetname) return head; // Sleeper: Match found.
        head = head.next_key; // Sleeper: Move to next key in player's chain.
    }

    return world; // Sleeper: No key found.
};

void() SM_Event_Reset_All_Doors =
{
    local entity door, master, oself;

    // Sleeper: Find all doors.
    door = find(world, classname, "door");
    while (door != world)
    {
        // Sleeper: Check if the door has a key-target and close it.
        master = door.owner;
        if (master.key_targetname != "")
        {
            // Sleeper: Close these doors.
            if (master.state == STATE_TOP || master.state == STATE_UP)
            {
                oself = self;
                self = master;
                do 
                {
                    door_go_down (); 
                    self.sm_door_touched = FALSE; 
                    self = self.enemy;
                } while ((self != master) && (self != world));

                self = oself;
            }
        }

        door = find(door, classname, "door");
    }
};

void(entity ent) sm_remove_key =  // Sleeper: Remove the key from everyone's key chain.
{
    local entity pl, current;

    pl = find(world, classname, "player");
    while (pl != world)
    {
        if (pl.next_key == ent) pl.next_key = ent.next_key;
        else
        {
            current = pl.next_key;
            while (current != world)
            {
                if (current.next_key == ent)
                {
                    current.next_key = ent.next_key;
                    current = world;
                }
                else current = current.next_key;
            }
        }
        pl = find(pl, classname, "player");
    }

    sm_keys -= 1;
    ent.next_key = world;
};

void() doorSM_touch =
{
    local entity key, pl;

    if ((other.health <= 0) || (other.classname != "player")) return;
    if (self.owner.attack_finished > time) return;
	self.owner.attack_finished = time + 2;

    if (self.sm_door_touched == TRUE) return; // Sleeper: Don't touch the same door.

    key = door_check_key ();
    if ((self.key_targetname != key.key_targetname) || (key == world)) // Sleeper: Player doesn't have the matching key, or doesn't have any key at all.
    {
        centerprint (other, sprintf("You need the %s for this door\n", self.netname));
        sm_keys_failed += 1;
//      sound (self, CHAN_VOICE, "doors/soundfile.wav", 1, ATTN_NORM);
        return;
    }

    // Sleeper: Announce that a door has been opened by a specific player.
    pl = find(world, classname, "player");
    while (pl != world)
    {
        centerprint (pl, sprintf("%s opened the %s door\n", (pl == other) ? "You" : other.netname, self.netname));
        pl = find(pl, classname, "player"); // Move to the next player
    }

    sprint (other, sprintf("You used the %s key\n", self.netname));
//  sound (self, CHAN_VOICE, "doors/soundfile.wav", 1, ATTN_NORM);

    sm_remove_key (key); // Sleeper: Remove this key from the global chain.
	self.sm_door_touched = TRUE;
	if (self.enemy) self.enemy.sm_door_touched = TRUE;
    door_use ();
};

// Sleeper: We can simply use the original door function to use this, as long we don't use normal gold or silver keys.