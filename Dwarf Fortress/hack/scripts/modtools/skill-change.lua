-- Sets or modifies a skill of a unit
--author expwnent
--based on skillChange.lua by Putnam
--TODO: skill rust?
-- amostubal added max, reduce, and verbose options; additionally update rating
-- support for when exp exceeds needed amount.
local help = [====[

modtools/skill-change
=====================
Sets or modifies a skill of a unit.  Args:

:-skill skillName:  set the skill that we're talking about
:-mode (add/set):   are we adding experience/levels or setting them?
:-granularity (experience/level):
                    direct experience, or experience levels?
:-unit id:          id of the target unit
:-value amount:     how much to set/add
:-max amount:       the highest rating that this should not exceed. If not
                    present the rating will not stop at any level.
:-reduce (yes/no):  are we reducing units who are over max? default is no.
                    if a unit is over max rating before this is ran and it
                    set to no, than it will ignore the function completely
                    otherwise if its set to yes, it will process through
                    and reduce the units skill rating to the max mark.
:-verbose:          adds extra information to the DF Console, for testing.
]====]
local utils = require 'utils'

validArgs = validArgs or utils.invert({
 'help',
 'skill',
 'mode',
 'value',
 'granularity',
 'unit',
 'max',
 'reduce',
 'verbose'
})

mode = mode or utils.invert({
 'add',
 'set'
})

reduce = reduce or utils.invert({
 'yes',
 'no'
})

granularity = granularity or utils.invert({
 'experience',
 'level'
})

local args = utils.processArgs({...}, validArgs)

if args.help then
 print(help)
 return
end

if not args.unit or not tonumber(args.unit) or not df.unit.find(tonumber(args.unit)) then
 error 'Invalid unit.'
end
args.unit = df.unit.find(tonumber(args.unit))
args.skill = df.job_skill[args.skill]
args.mode = mode[args.mode or 'set']
args.reduce = reduce[args.reduce or 'no']
args.granularity = granularity[args.granularity or 'level']

if not args.skill then
 error('invalid skill')
end

if not args.value then
 error('invalid value')
else
 args.value = tonumber(args.value)
end

if args.max then
 args.max = tonumber(args.max)
end

local skill
for _,skill_c in ipairs(args.unit.status.current_soul.skills) do
 if skill_c.id == args.skill then
  skill = skill_c
 end
end

if not skill then
 skill = df.unit_skill:new()
 skill.id = args.skill
 utils.insert_sorted(args.unit.status.current_soul.skills,skill,'id')
end

if args.reduce == reduce.no and args.max then
 if skill.rating >= args.max then 
  if args.verbose then
   print('unit exceeds max rating and reduce setting is set to no. No Skill Change')
  end
  return
 end
end

if args.verbose then
 print('old: ' .. skill.rating .. ': ' .. skill.experience)
end

if args.granularity == granularity.experience then
 if args.mode == mode.set then
  skill.experience = args.value
 elseif args.mode == mode.add then
  skill.experience = skill.experience + args.value
 else
  error('bad mode')
 end
elseif args.granularity == granularity.level then
 if args.mode == mode.set then
  skill.rating = args.value
 elseif args.mode == mode.add then
  skill.rating = args.value + skill.rating
 else
  error('bad mode')
 end
else
 error('bad granularity')
end

-- encoding to increase rating since otherwise it wont until they use the skill
while skill.experience >= ( ( ( skill.rating + 1 ) * 100 ) + 400 ) do
 skill.rating = skill.rating + 1 
 skill.experience = skill.experience - ( ( skill.rating * 100 ) + 400 )
end

-- Check for going over args.max we don't check for the reduce option here,
-- Becauuse only being over max pre upgrading skill is an issue.
if args.max then
 if skill.rating >=args.max then
  skill.rating = args.max
  skill.experience = 0
 end
end

if args.verbose then
 print('new: ' .. skill.rating .. ': ' .. skill.experience)
end
