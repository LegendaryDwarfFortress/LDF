-- flow/source.lua v0.8 | DFHack 43.05
local usage = [====[

pipe-dreams-source
by Amostubal
====================
Credits: Based on roses flow/source.

Usage:
    This is the source creator part of pipe-dreams, its the target for reaction
triggers.  certain things are totally removed from the original script since its
not to be used for flowtypes etc.  making the script reduced in size.
  Additionally since it is involved in the pipe system created in LDF additional
code for the internalized counter system was added.

Commands:
  -help            - Gives this usage block
  -unit            - ability to target the unit that does the reaction.
  -location        - target a specific location?!?! don't think this is working.
  -offset          - offset from the point the point from the above.
  -source          - tells us to add a source.
  -sink            - tells us to add a sink.
  -remove          - tells us to remove something.
  -removeAll       - tells us to removeAll sinks and sources.
  -removeAllSource - tells us to remove only all sources.
  -removeAllSink   - tells us to reomve only all sinks.
  -magma           - tells us to use magma instead of water.
  -check           - how often to update this location.
  -noCount         - adds backwards compatability, noCount sources and sinks act
                     as the original flow/source sources and sinks.
  -building        - so we can see what pipe systems its attached to.
]====]
local persistTable = require 'persist-table'
persistTable.GlobalTable.pipeDreamsTable=persistTable.GlobalTable.pipeDreamsTable or {}
pipeDreamsTable = persistTable.GlobalTable.pipeDreamsTable
pipeDreamsTable.LiquidTable = pipeDreamsTable.LiquidTable or {}
liquidTable = pipeDreamsTable.LiquidTable

local utils = require 'utils'
validArgs = validArgs or utils.invert({
 'help',
 'unit',
 'location',
 'offset',
 'source',
 'sink',
 'remove',
 'removeAll',
 'removeAllSource',
 'removeAllSink',
 'magma',
 'check',
 'noCount',
 'building',
 'report',
})
local args = utils.processArgs({...}, validArgs)

if args.help then
  print( usage )
  return
end

if args.report then
  print( "Printing LiquidTable" )
  print( "Index\ttype\tlevel\tx\ty\tz" )
  for _,i in pairs(liquidTable._children) do
    local L = liquidTable[i]
    print( i.."\t"..L.Type.."\t"..L.Depth.."\t"..L.x.."\t"..L.y.."\t"..L.z )
  end
  return
end

pos = {}
if args.unit and tonumber(args.unit) then
 pos = df.unit.find(tonumber(args.unit)).pos
elseif args.location then
 pos.x = args.location[1]
 pos.y = args.location[2]
 pos.z = args.location[3]
elseif not (args.removeAll or args.removeAllSource or args.removeAllSink or args.report) then
  print('No unit or location selected')
  return
end

offset = args.offset or {0,0,0}
check = tonumber(args.check) or 12
x = pos.x + offset[1]
y = pos.y + offset[2]
z = pos.z + offset[3]


number = tostring(df.global.cur_year)..tostring(df.global.cur_year_tick).."0"..tostring(x)..tostring(y)..tostring(z)

if args.noCount then
  Count = "NO"
else
  Count = "YES"
end

if args.building then
  Building = args.building
else
  Building = ""
end

if args.removeAll then
  persistTable.GlobalTable.pipeDreamsTable.LiquidTable = {}
elseif args.removeAllSource then
  for _,i in pairs(liquidTable._children) do
    liquid = liquidTable[i]
    if liquid.Type == 'Source' then
      liquidTable[i] = nil
    end
  end
elseif args.removeAllSink then
  for _,i in pairs(liquidTable._children) do
    liquid = liquidTable[i]
    if liquid.Type == 'Sink' then
      liquidTable[i] = nil
    end
  end
elseif args.remove then
  for _,i in pairs(liquidTable._children) do
    liquid = liquidTable[i]
    if tonumber(liquid.x) == x and tonumber(liquid.y) == y and tonumber(liquid.z) == z then
      liquidTable[i] = nil
    end
  end
elseif args.source then
  depth = args.source
  for _,i in pairs(liquidTable._children) do
    liquid = liquidTable[i]
    if tonumber(liquid.x) == x and tonumber(liquid.y) == y and tonumber(liquid.z) == z then
    liquidTable[i] = nil
    end
  end
  liquidTable[number] = {}
  liquidTable[number].x = tostring(x)
  liquidTable[number].y = tostring(y)
  liquidTable[number].z = tostring(z)
  liquidTable[number].Depth = tostring(depth)
  liquidTable[number].Check = tostring(check)
  liquidTable[number].Count = tostring(Count)
  liquidTable[number].Building = tostring(Building)
  if args.magma then liquidTable[number].Magma = 'true' end
  liquidTable[number].Type = 'Source'
  dfhack.script_environment('pipe-dreams').LiquidSource(number)
elseif args.sink then
  depth = args.sink
  for _,i in pairs(liquidTable._children) do
    liquid = liquidTable[i]
    if tonumber(liquid.x) == x and tonumber(liquid.y) == y and tonumber(liquid.z) == z then
    liquidTable[i] = nil
    end
  end
  liquidTable[number] = {}
  liquidTable[number].x = tostring(x)
  liquidTable[number].y = tostring(y)
  liquidTable[number].z = tostring(z)
  liquidTable[number].Depth = tostring(depth)
  liquidTable[number].Check = tostring(check)
  liquidTable[number].Count = tostring(Count)
  liquidTable[number].Building = tostring(Building)
  if args.magma then liquidTable[number].Magma = 'true' end
  liquidTable[number].Type = 'Sink'
  dfhack.script_environment('pipe-dreams').LiquidSink(number)
end
