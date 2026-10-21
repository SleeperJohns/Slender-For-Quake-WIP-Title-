float(float tracknum) SM_Page_Track = {return clamp((3 + (((self.sounds - 1) * (self.weapon - ((self.sounds - 1) * 2))) % 100) + tracknum), 3, 255);}; // Sleeper: If Track 2 is a "NULL" track, then we can shift off of 3, depending on the music style we want.

float(float progress) SM_MusicSet_EightPages = // Sleeper: If there were just 8 collectibles: 1–2, 3–4, 5–6, 7–8.
{
    if ((progress > 0 && progress <= 25) || (progress <= 0 && sm_slenderman_aggression > 0)) return SM_Page_Track(SM_TRACK1); // Sleeper: First collectible pickup or when Slender Man's aggression passively kicks in.
    else if (progress <= 50) return SM_Page_Track(SM_TRACK2);
    else if (progress <= 75) return SM_Page_Track(SM_TRACK3);

    return (progress <= 100 || progress >= 100) ? SM_Page_Track(SM_TRACK4) : 2;
};

float(float progress) SM_MusicSet_SMS = // Sleeper: If there were just 8 collectibles: 1-2, 3, 4, 5, 6, 7-8.
{
    if ((progress > 0 && progress <= 37.5) || (progress <= 0 && sm_slenderman_aggression > 0)) return SM_Page_Track(SM_TRACK1); // Sleeper: First collectible pickup or when Slender Man's aggression passively kicks in.
    else if (progress <= 50) return SM_Page_Track(SM_TRACK2);
    else if (progress <= 62.5) return SM_Page_Track(SM_TRACK3);
    else if (progress <= 75) return SM_Page_Track(SM_TRACK4);
    else if (progress <= 87.5) return SM_Page_Track(SM_TRACK5);

    return (progress <= 100 || progress >= 100) ? SM_Page_Track(SM_TRACK6) : 2;
};

void() SM_Page_Music = // Sleeper: Technically, the only control the map editor should be able to control, is the style of the page music. Track 2 should be set across the board unless there's a gameplay reason.
{
    local float target_track, progress, max_collect, collect, musicset;

    max_collect = (sm_max_collectibles < 8) ? 8 : sm_max_collectibles; // Sleeper: If the max collectible value is under 8, then we shouldn't have music anymore intense that the max value.
    collect = sm_collectibles;
    progress = (collect / max_collect) * 100;
    target_track = sm_current_track;
    musicset = self.sounds;
    target_track = (intermission_running) ? SM_Page_Track(SM_TRACK1) : ((musicset == SM_EIGHT_PAGES_MUSICSET) ? SM_MusicSet_EightPages(progress) : SM_MusicSet_SMS(progress));

    if (sm_current_track == target_track) return;

    sm_current_track = target_track;
    WriteByte (MSG_ALL, SVC_CDTRACK);
    WriteByte (MSG_ALL, target_track); // Sleeper: Track to play.
    if (target_track > 2) WriteByte (MSG_ALL, target_track); // Sleeper: Loop track.
};
