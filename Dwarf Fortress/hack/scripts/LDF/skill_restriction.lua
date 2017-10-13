--LDF - Skill restriction code.
local usage = [====[

skill_restriction
====================
LDF script for restricting skills in various ways.  A basic single call line
of the race allows it to seek out the file that contains the restriction info.
the restriction info is stored seperately and loaded once onMapLoad so that the
info can be editted outside of the onMapLoad scripts and because of the size of
the restrictions (it would require a huge line to do it directly in a command
line).

Arguments::

    -file name
        set the target file including the path for the file.

    example of init line.
    skill_restriction -file DwarfSkillRestrictions.txt
		
		
File Arguments::
    <race:X>
        race which has restrictions. ALL usable.
    <caste:X>
        caste inside of previous race that has restrictions.  ALL usable.
    <skill:SKILLNAME:LEVEL:CANCEL:TURNOFF>
        SKILLNAME skill has restriction to LEVEL or below for the previous
		RACE:CASTE and the job will be canceled with no product if CANCEL is
        present. If TURNOFF is present that skill will also auto turned off 
		for the unit, TURNOFF also zeros that skill rating hopefully forcing
		other scripts such as autolabor to choose a different unit.
    <building:BUILDING:SKILLNAME:LEVEL>
        BUILDING that has a restriction to anyone with SKILLNAME skill at or
		below given LEVEL.  will automatically cancel the Job results if such
		units attempt to use it.
	<announce:STATEMENT>
        announcements for restrictions made the STATEMENT is used for the 
        announcement and zoom is set to where the unit that trigers the 
        announcement was when the restriction occured.  STATEMENT can contain
        arguments which are UNIT SKILLNAME BUILDING JOB.  Only one of these is
        needed behind each caste set and building set of restrictions.
		
	example:
    <race:DWARF><caste:MALE>
        <skill:BREWING:5><announce:UNIT feels like hes not gaining anything while JOB.>

        So the dwarf who is level 5 will have is experience set to 0 when brewing and 
        an announcement of "McUrist feels like hes not gaining anything while brewing 
        plants." will be made.

    <building:ADVANCED_BLAST_FURNACE:SMELT:5><announce:UNIT can't use BUILDING.>

        so a dwarf of low level attempts to use this furnace... the materials
        are lost and an announcement is made of "McUrist can't use Advanced Blast Furnace."

    <race:ELF><caste:ALL>
        <skill:WOODCUTTING:0:CANCEL:TURNOFF>

        so you set a job of woodcutting and an elf somehow has woodcutting
        turned on... this will cancel the job on the unit, and turn off the
        skill on the unit and verify its set to level 0 experience 0.
		
    Additional notes, even though elfs will be restricted, as such... ALL for
    for races would be useful too on an elf base, as you shouldn't be cutting
    down trees at all, no matter the race.  also skill restrictions with no
    race and castes prior to it will be considered as race:ALL caste:ALL .
    anything in the file that is not between < > will be considered a comment
    and ignored.  If race:ALL is used, caste:ALL is assumed.
	
]====]
local utils=require 'utils'

