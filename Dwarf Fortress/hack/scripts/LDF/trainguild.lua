--LDF - Guild Train code.
local usage = [====[

trainguild
====================
LDF script to train a batch of skills, for a guild building.
Arguments::

    -unit id
        set the target unit
    -skills
        list of skills for training
    -points
        number of total points to train the unit by.

]====]
local utils=require 'utils'



validArgs = validArgs or utils.invert ({
 'unit',
 'skills',
 'points',
 'help'
})

local args = utils.processArgs({...}, validArgs)

if not ... or args.help then
  print(usage)
  return
end

local totalSkills = 0

for i,skillname in ipairs(args.skills) do
  totalSkills = totalSkills+1
end

local unit = df.unit.find(tonumber(args.unit))

local pointsPerSkill = tonumber(args.points)/totalSkills

for i,skillname in ipairs(args.skills) do
  thisIncrease = math.floor(pointsPerSkill - 10 + math.random(0,20))
  if thisIncrease > tonumber(args.points) then
    thisIncrease = tonumber(args.points)
  end
  
  args.points = args.points - thisIncrease
  dfhack.run_script('modtools/skill-change', '-skill', skillname, '-mode','add', '-granularity', 'experience', '-unit', unit.id, '-value', thisIncrease, '-max', 5)
end


