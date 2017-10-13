--LDF - Guild Test code.
local usage = [====[

testguild
====================
LDF script for the testing of individuals to verify their skills are high enough
to be accepted into a guild. 

Arguments::

    -unit id
        set the target unit
    -guild
        guild name as written in caste minus MALE_ and FEMALE_
    -race
        race name
    -skills
        skills to test for, these will be listed inside a [brackets]
    -level
        level of skills to be tested for.
    -anyskill
        only 1 is needed to pass otherwise all the stated skills are needed.
    -anycaste
        will make switches based on sex instead of standard castes (MALE FEMALE).
		
Notes:  If no -skills is present then the test is passed automatically.
]====]
local utils=require 'utils'



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



validArgs = validArgs or utils.invert ({
 'level',
 'skills',
 'unit',
 'guild',
 'race',
 'help',
 'anyskill',
 'anycaste'
})

local args = utils.processArgs({...}, validArgs)

if not ... or args.help then
  print(usage)
  return
end

if not args.unit then
  error 'specify a unit'
end

if not args.race or not args.guild then
  error 'Specficy a target form.'
end


local unit = df.unit.find(tonumber(args.unit))
local unitname = dfhack.TranslateName(dfhack.units.getVisibleName(unit))
local pass = false

if args.race == tostring(df.global.world.raws.creatures.all[unit.race].creature_id) then
  if args.skills and args.level then 
    for i,skillname in ipairs(args.skills) do
      skill = getUnitSkill(df.job_skill[skillname], unit)
      if args.anyskill then
        if skill.rating >= tonumber(args.level) then
          pass = true
        end
      elseif skill.rating < tonumber(args.level) then
		local unitname = dfhack.units.getVisibleName(unit)
		dfhack.gui.showAnnouncement(unitname.." has failed a test to join the "..string.lower(args.guild).." guild.", COLOR_LIGHTCYAN)
	    print('Unit failed skill test.  (all must pass)')
        return
	  end
    end
  else
    pass = true
  end
  
  if pass == false then
    dfhack.gui.showAnnouncement(unitname.." has failed a test to join the "..string.lower(args.guild).." guild.", COLOR_LIGHTCYAN)
    print('Unit failed skill test.  (one must pass)')
    return
  end

  local suffix

  if args.anycaste then
    if unit.sex == 1 then
      suffix = "MALE_"
    else
      suffix = "FEMALE_"
    end
  elseif unit.caste < 2 then --the first 2 castes 0 and 1 are usually male and female.
    if unit.sex == 1 then
      suffix = "MALE_"
    else
      suffix = "FEMALE_"
    end
  else
    dfhack.gui.showAnnouncement(unitname.." has been refused entry into the "..string.lower(args.guild).." guild.", COLOR_LIGHTCYAN)
    print('Unit cannot change castes, already in a special caste.')
    return
  end

  dfhack.gui.showAnnouncement(unitname.." has been accepted into the "..string.lower(args.guild).." guild.", COLOR_LIGHTCYAN)

  args.guild=suffix..args.guild

  dfhack.run_script('modtools/transform-unit', '-unit', unit.id, '-race', args.race, '-caste', args.guild, '-keepInventory', 1)

else
  dfhack.gui.showAnnouncement(unitname.." has been refused entry into the "..string.lower(args.guild).." guild.", COLOR_LIGHTCYAN)
  print('Unit cannot change castes, already in a special caste.')
  error 'attempted to change the race of a unit, reject transformation.'
end

