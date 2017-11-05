-- fix-cannibal allow non-citizen sentients to be butchered again
-- author burrito25man
-- special thanks to expwnent for the bulk of his code, Atomic Chicken for his !!SCIENCE!!, and Nilsou for pointing me in the right direction
-- as well as Putnam and Fleeting Frames for guidance :D
-- from Amostubal - fixed the arguments for help and added a verbose mode to cut down on the chatter.

local usage = [====[

fix-cannibal
===============================
This tool fixes a current (43.05) bug that makes sentient creatures unbutcherable in fortress
mode even with correct ethics.
options:
    -help - displays this help file.
    -verbose - turns on the verbose messaging for debugging/verification.
    -enable - turns on the script.
    -disable - turns off the script.

]====]


local eventful = require 'plugins.eventful'
local utils = require 'utils'
VERBOSE = false
ENABLED = false or ENABLED

validArgs = validArgs or utils.invert ({
 'help',
 'verbose',
 'enable',
 'disable'
})

local args = utils.processArgs({...}, validArgs)

if args.help then
  print(usage)
  return
end

if args.verbose then
  VERBOSE = true
end

if args.enable then

  eventful.enableEvent(eventful.eventType.UNLOAD,1)
  eventful.onUnload.fixcannibal = function()
  end

  eventful.enableEvent(eventful.eventType.UNIT_DEATH, 1) --requires iterating through all units
  eventful.onUnitDeath.fixcannibal = function(unitId)
    local unit = df.unit.find(unitId)
    if not unit then
      return
    end

    corpses = {} -- Not sure what this is needed for?

    local entsrc = df.historical_entity.find(df.global.ui.civ_id)
    local entity = df.historical_entity.find(unit.civ_id)

    if entity ~= entsrc then
      for _,corpses in ipairs(df.global.world.items.other.ANY_CORPSE) do
        if corpses.unit_id == unit.id then
          if corpses.flags.dead_dwarf == true then
            corpses.flags.dead_dwarf = false
            if VERBOSE then print('dead_dwarf flag of '..dfhack.TranslateName(dfhack.units.getVisibleName(unit))..' was set to false.') end
          end
        end
      end
    end
  end

  if VERBOSE then
    print('Fix-cannibal script is now enabled in verbose mode.')
  else
    print('Fix-cannibal script is now enabled.')
  end
  ENABLED = true
  print(ENABLED)


elseif args.disable then
  if ENABLED then 
    eventful.onUnitDeath.fixcannibal = function()
    end
    print('fix-cannibal script is now disabled.')
    ENABLED = false
  else 
    print('fix-cannibal script was not enabled first. type "fix-cannibal -help" for instructions')
  end

else
  if ENABLED then 
    print('fix-cannibal script is currently enabled.')
  else 
    print('fix-cannibal script is currently disabled.')
  end
  print('Type "fix-cannibal -help" for usage instructions.')
end

