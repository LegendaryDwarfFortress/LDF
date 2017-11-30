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
    skill_restriction DwarfSkillRestrictions.txt
        
        
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
local RestrictLines = {}
RestrictOnCompletedList={}
RestrictOnInitiatedList={}
local VERBOSE = false
local QUIET = false
local TIMEOUT = false
for line in io.lines( ... ) do
  table.insert( RestrictLines, line )
end

local NewEntry = true
local EntryROCL = 1
local EntryROIL = 1
local CurrentEntry = "NEW"
RestrictOnCompletedList[EntryROCL]={}
RestrictOnInitiatedList[EntryROIL]={}

for _i,line in ipairs( RestrictLines ) do
  if ( string.len( line ) > 0 ) then
    if line == "<verbose>" then -- turns on Verbose DFHack messages for testing
      VERBOSE = true

    elseif line == "<quiet>" then -- turns off ingame announcements
      QUIET = true

    elseif line == "<cancel>" then
      if CurrentEntry=="NEW" or CurrentEntry=="ROIL" then  -- must be new or a ROIL already
        RestrictOnInitiatedList[EntryROIL].cancel = true
        CurrentEntry = "ROIL"
      end  -- ignored for ROCL

    elseif string.sub( line, 1, 6 ) == "<race:" then
      local race = {}
      for word in string.gmatch(string.sub( line, 7, -2 ), "[%w_]+") do
        race[word] = true
      end
      if CurrentEntry=="ROIL" then -- so its a ROIL already
        RestrictOnInitiatedList[EntryROIL].race = race
      else                         -- its either new or a ROCL
        CurrentEntry="ROCL"
        RestrictOnCompletedList[EntryROCL].race = race
      end

    elseif string.sub( line, 1, 10 ) == "<building:" then
      local building = {}
      for word in string.gmatch(string.sub( line, 11, -2 ), "[%w_]+") do
        building[word] = true
      end
      if CurrentEntry=="NEW" or CurrentEntry=="ROIL" then  -- must be new or a ROIL already
        CurrentEntry = "ROIL"
        RestrictOnInitiatedList[EntryROIL].building = building
      end -- ignored for ROCL

    elseif string.sub( line, 1, 7 ) == "<caste:" then
      local caste = {}
      for word in string.gmatch(string.sub( line, 8, -2 ), "[%w_]+") do
        caste[word] = true
      end
      if CurrentEntry=="ROIL" then -- so its a ROIL
        RestrictOnInitiatedList[EntryROIL].caste = caste
      else                         -- so its a ROCL
        RestrictOnCompletedList[EntryROCL].caste = caste
      end

    elseif string.sub( line, 1, 7 ) == "<skill:" then
      local skill={}
      local NewSkill=true
      local ThisSkill
      local ThisSkillLevel
      for word in string.gmatch(string.sub( line, 8, -2 ), "[%w_]+") do
        if NewSkill then
          ThisSkill = word
          NewSkill = false
        else
          ThisSkillLevel = word
          skill[ThisSkill] = ThisSkillLevel
          NewSkill = true
        end
      end
      if CurrentEntry=="ROIL" then -- so its a ROIL
        RestrictOnInitiatedList[EntryROIL].skill = skill
      else                         -- so its a ROCL
        RestrictOnCompletedList[EntryROCL].skill = skill
      end

    elseif line == "<turnoff>" then
      if CurrentEntry=="ROIL" then -- so its a ROIL
        RestrictOnInitiatedList[EntryROIL].turnoff = true
      end                          -- ignored if its a ROCL

    elseif string.sub( line, 1, 10 ) == "<announce:" then
      if CurrentEntry=="ROIL" then -- so its a ROIL
        RestrictOnInitiatedList[EntryROIL].announce = string.sub( line, 11, -2 )
      else                         -- so its a ROCL
        RestrictOnCompletedList[EntryROCL].announce = string.sub( line, 11, -2 )
      end

    elseif line == "<end>" then
      -- this calls for a full stop of the restriction list and anything after
      -- this call is ignored completely... in this way the rest of the file can
      -- be used for notes.
      break
    else
      if CurrentEntry=="ROIL" then  -- hit a non command line while a ROIL so reset
        EntryROIL = EntryROIL + 1
        RestrictOnInitiatedList[EntryROIL]={}
        CurrentEntry="NEW"

      elseif CurrentEntry=="ROCL" then  -- hit a non command line while a ROCL so reset
        EntryROCL = EntryROCL + 1
        RestrictOnCompletedList[EntryROCL]={}
        CurrentEntry="NEW"
      end
    end
  end
end

function PrintLists()
  print()
  print("----- Skill_restriction mod -----")
  print("settings:")
  print("Verbose:",VERBOSE)
  print("Quiet Mode:",QUIET)
  print("On Completed Restrictions:")
  PrintRestrictList(RestrictOnCompletedList)
  print("On Initiated Restrictions:")
  PrintRestrictList(RestrictOnInitiatedList)
end

function PrintRestrictList(ThisList)
  for _i = 1, #ThisList do
    local CommandIs = tostring(_i).."."
    if ThisList[_i].race then
      CommandIs = CommandIs.." race:"
      for race,value in pairs( ThisList[_i].race ) do
        CommandIs = CommandIs.." "..race
      end
      CommandIs = CommandIs
    end
    if ThisList[_i].building then
      CommandIs = CommandIs.." building:"
      for building,value in pairs( ThisList[_i].building ) do
        CommandIs = CommandIs.." "..building
      end
      CommandIs = CommandIs
    end
    if ThisList[_i].caste then
      CommandIs = CommandIs.."\n caste:"
      for caste,value in pairs( ThisList[_i].caste ) do
        CommandIs = CommandIs.." "..caste
      end
      CommandIs = CommandIs
    end
    if ThisList[_i].skill then
      CommandIs = CommandIs.."\n skill:"
      local count = 0
      for skill,level in pairs( ThisList[_i].skill ) do
        if count == 5 then
          CommandIs = CommandIs.."\n       "
          count = 0
        end
        CommandIs = CommandIs.." "..skill.." = "..level
        count = count + 1
      end
      CommandIs = CommandIs
    end
    if ThisList[_i].cancel then
      CommandIs = CommandIs.."\n cancel: true"
    end
    if ThisList[_i].turnoff then
      CommandIs = CommandIs.."\n turnoff: true"
    end
    if ThisList[_i].announce then
      CommandIs = CommandIs.."\n announce: "..ThisList[_i].announce
    end
    print(CommandIs)
    CommandIs = ""
  end
end

function getUnitSkill(skillId, unit)
    local skill = df.unit_skill:new()
    local foundSkill = false
 
    for k, soulSkill in ipairs(unit.status.current_soul.skills) do
        if soulSkill.id == skillId then
            skill = soulSkill
            foundSkill = true
            break
        end
    end
 
    if foundSkill then
    else
        skill.id = skillId
        skill.experience = 0
        skill.rating = 0
    end
    
    return skill
end

if VERBOSE then
 PrintLists()
end

function verbose(job,mode)
  local command
  if mode == "C" then
    mode = "completed"
  else
    mode = "initiated"
  end
  if job.job_type then
    command = df.job_type.attrs[job.job_type].caption
    if df.job_skill.attrs[df.job_type.attrs[job.job_type].skill].caption then
      command = command .. " using " .. df.job_skill.attrs[df.job_type.attrs[job.job_type].skill].caption .. " skill"
    end
    if dfhack.job.getWorker(job) then
      local unit = dfhack.job.getWorker(job)
      local unitname = dfhack.TranslateName(dfhack.units.getVisibleName(unit))
      command = command .. " " .. mode .. " by " .. unitname
    else
      command = command .. " " .. mode .. " by no one ..."
    end
    if dfhack.job.getHolder(job) then
      local buildingname = getBuildingNameFromJob(job)
      command = command .. " at this Building: " .. buildingname
    end
  end
  if command then
    print(command)
  end
end

function getBuildingNameFromJob(job)
  if dfhack.job.getHolder(job) then
    local building = dfhack.job.getHolder(job)
    if df.workshop_type[building.type] == "Custom" then 
      local thisType = df.building_def.find(building.custom_type)
      return thisType.name
    else
      return df.workshop_type[building.type]
    end
  else
    return "NO BUILDING"
  end
end

function CullSkill( skill, unitId, level )
  dfhack.run_script('modtools/skill-change', '-skill', skill, '-mode', 'set', '-granularity', 'level', '-unit', unitId, '-value', level )
  dfhack.run_script('modtools/skill-change', '-skill', skill, '-mode', 'set', '-granularity', 'experience', '-unit', unitId, '-value', 0 )
end

function ResetTimeout()
  TIMEOUT=false
end

function MakeAnnouncement( ThisAnnounce, uName, sName, jName, bName, pos )
  if TIMEOUT == false then 
    ThisAnnounce, _j = string.gsub( ThisAnnounce, "UNIT", uName )
    ThisAnnounce, _j = string.gsub( ThisAnnounce, "SKILLNAME", string.lower(sName) )
    ThisAnnounce, _j = string.gsub( ThisAnnounce, "JOB", string.lower(jName) )
    ThisAnnounce, _j = string.gsub( ThisAnnounce, "BUILDING", string.lower(bName) )
    dfhack.gui.showAnnouncement(ThisAnnounce, COLOR_LIGHTCYAN)
    if VERBOSE then
      print(ThisAnnounce)
    end
    TIMEOUT = true
    dfhack.timeout(1,'months',
                 function ()
                  dfhack.script_environment('skill_restriction').ResetTimeout()
                 end
                )
  end
end

jobCheck = require('plugins.eventful')
jobCheck.enableEvent(jobCheck.eventType.JOB_COMPLETED,1)
jobCheck.onJobCompleted.LFD_RestrictionCompleted = function(job)
  if VERBOSE then
    verbose(job,"C")
  end
  if job.job_type and dfhack.job.getWorker(job) then
    local unit = dfhack.job.getWorker(job)
    local uRace = tostring(df.global.world.raws.creatures.all[unit.race].creature_id)
    local uCaste = tostring(df.global.world.raws.creatures.all[unit.race].caste[unit.caste].caste_id)
    local jSkill = tostring(df.job_skill[df.job_type.attrs[job.job_type].skill])
    for _i = 1, #RestrictOnCompletedList do
      thisR = RestrictOnCompletedList[_i]
      -- if it doesn't have all three its bad in the first place.... should check this before we get here.
      if thisR.race and thisR.caste and thisR.skill then
        if ( thisR.race[uRace] or thisR.race[ALL] ) and ( thisR.caste[uCaste] or thisR.caste[ALL] ) and ( thisR.skill[jSkill] ) then
          local uSkill = getUnitSkill(df.job_skill[jSkill], unit)
          if uSkill.rating >= tonumber(thisR.skill[jSkill]) then
            CullSkill( jSkill, unit.id, tonumber(thisR.skill[jSkill]) )
            if thisR.announce and not QUIET then
              local uName = dfhack.TranslateName(dfhack.units.getVisibleName(unit))
              local sName = tostring(df.job_skill.attrs[df.job_type.attrs[job.job_type].skill].caption) or "no skill name"
              local jName = tostring(df.job_type.attrs[job.job_type].caption) or "no job name"
              local bName = getBuildingNameFromJob(job) or "no building"
              MakeAnnouncement( thisR.announce, uName, sName, jName, bName )
            end
          end
        end        
      end
    end
  end
end

jobCheck.enableEvent(jobCheck.eventType.JOB_INITIATED,1)
jobCheck.onJobInitiated.LFD_RestrictionInitiated = function(job)
  if VERBOSE then
    verbose(job,"I")
  end
end