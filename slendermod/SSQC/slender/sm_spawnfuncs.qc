void() info_key_spot = // Sleeper: This gives keys a preassigned spawn placement. Needs unique ID. Use .sm_itemspot_id.
{
    if (deathmatch) 
    {
        remove (self); 
        return;
    } 
    
    if (self.ent_mdl) precache_model (self.ent_mdl); 
    if (self.ent_snd) precache_sound (self.ent_snd);
};

void() info_memento_spot = // Sleeper: This gives mementos a preassigned spawn placement. Needs unique ID. Use .sm_itemspot_id.
{
    if (deathmatch) 
    {
        remove (self); 
        return;
    } 
    
    if (self.ent_mdl) precache_model (self.ent_mdl); 
    if (self.ent_snd) precache_sound (self.ent_snd);
};

void() info_page_spot = // Sleeper: This gives pages a preassigned spawn placement. Needs unique ID. Use .sm_itemspot_id.
{
    if (deathmatch) 
    {
        remove (self); 
        return;
    } 
    
    if (self.ent_mdl) precache_model (self.ent_mdl); 
    if (self.ent_snd) precache_sound (self.ent_snd);
};
// Sleeper: Each of the above info spots is equipped with 2 strings to allow mappers to freely set a model and sound. 
// The purpose of these strings are to pass through models or sounds to pickup items without worrying about precaching.
// Useful if people simply care only about mapping.

void(vector pos, vector angle, float id, string mdl, string snd, string clname, void() func) func_SpawnItem =
{
    local entity e = spawn ();
        
    e.origin = pos; // Sleeper: Where do we want it?
    e.angles = angle; // Sleeper: Where should it face?
    e.model = mdl; // Sleeper: What should it appear to be?
    e.noise = snd; // Sleeper: What should the pick up sound effect sound like?
    e.sm_itemspot_id = id;
            
    e.classname = clname; // Sleeper: Mostly for safety
          
    // Sleeper: Change self to the new entity and initialize it.
    SUB_CallAsSelf (e, func);
};

void(vector pos, vector angle, float ai_style, string clname, void() func) func_SpawnEnemy =
{
    local entity e = spawn ();
        
    e.origin = pos;
    e.angles = angle;
    e.style = ai_style;
            
    e.classname = clname; // Sleeper: Mostly for safety
          
    // Sleeper: Change self to the new entity and initialize it.
    SUB_CallAsSelf (e, func);
};