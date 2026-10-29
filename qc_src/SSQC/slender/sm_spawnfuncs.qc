void() info_key_spot = {if(deathmatch){remove(self);return;}}; // Sleeper: This gives keys a preassigned spawn placement. Needs unique ID. Use .sm_itemspot_id.
void() info_memento_spot = {if(deathmatch){remove(self);return;}}; // Sleeper: This gives mementos a preassigned spawn placement. Needs unique ID. Use .sm_itemspot_id.
void() info_page_spot = {if(deathmatch){remove(self);return;}}; // Sleeper: This gives pages a preassigned spawn placement. Needs unique ID. Use .sm_itemspot_id.

void(vector pos, vector angle, float id, string clname, void() func) func_SpawnItem =
{
    local entity e = spawn ();
        
    e.origin = pos;
    e.angles = angle;
    e.sm_itemspot_id = id;
            
    e.classname = clname; // Sleeper: Mostly for safety
          
    // Sleeper: Change self to the new entity and initialize it
    SUB_CallAsSelf (e, func);
};

void(vector pos, vector angle, float ai_style, string clname, void() func) func_SpawnEnemy =
{
    local entity e = spawn ();
        
    e.origin = pos;
    e.angles = angle;
    e.style = ai_style;
            
    e.classname = clname; // Sleeper: Mostly for safety
          
    // Sleeper: Change self to the new entity and initialize it
    SUB_CallAsSelf (e, func);
};