--pipe-dreams - a System for creating and using pipes for liquid transport.
local usage = [====[

pipe-dreams
by Amostubal
====================
version 1.0 for dfhack 43.05r2

Credits: A lot of this came from stewing down a bunch of things from roses and
a few other scripts...not all of these concepts came from me.

Usage:
    This is a complete pipe System and liquid mover script, once its activated
it listens to the DF game for the things it needs to create its pipe System and
move liquids.

Commands:
    -enable  - initiates pipe-dreams, restarts saved sources and sinks.
    -disable - stops pipe-dreams, including sources and sinks.
    -verbose on|off- enables|disables verbose mode
    -help    - dispalys this info.
    -setup   - displays setup info.

Nothing else is needed when running pipe-dreams, the rest is automated from the
code.

How does it work?  Well it keeps track of pipes, inputs, and outputs.
When an Input is connected to a pipe, reactions at the shop can remove liquids
from location near it, and place it into a counter System based on the total of
all the pipes connected to it.  Once a pipe System's counters are full, than it
will force input sinks to stop.  If input circles(singular operation inputs) are
used than the pipe System can only fill to the max counter level.  Any attempt
beyond that will not increase the counters.

When an Output is attached to a pipe, reactions at the shop can add liquids to
locations near it, and remove the amount from the prior mentioned counter
System.  If the counter System drops to 0, outputs will not function until the
counter System is replenished from actions at inputs.

]====]

local setup = [====[

pipe-dreams
by Amostubal
====================
Setup:
In the raws you need to have the following files:
  building_pipe_dreams.txt
  reaction_pipe_dreams.txt
and the pipe-dreams.lua needs to be in your raw/scripts folder.

the command "pipe-dreams -enable" needs to be passed to DFHack either directly
once a map is loaded or through raw/onMapLoad.init in fort mode only.

this initiates the script, loads the buildings in building_pipe_dreams.txt and
the reactions from reaction_pipe_dreams to the currently operating entity.

"pipe-dreams -disable" stops the listening scripts etc, which will stop all sinks
and sources.

Changing building_pipe_dreams.txt:
  If you look at the beginning of the file there is a section that is written as
"- START PIPE DREAMS
 ...
 - END PIPE DREAMS"

  This is the section that pipe-dreams will read for information on what to add
to an entity.
COMMAND LINE:"- <ENTITY_ID> <BUILDING_ID> <PIPEDREAM_ID>"
EXAMPLE LINE:"- MOUNTAIN NSP_1 NS_PIPE"

  ENTITY_ID is the race that needs the building. i.e. MOUNTAIN for Dwarf.
  BUILDING_ID is the actual ID of the building. i.e WATERPUMP, NSP_1, etc
  PIPEDREAM_ID is an ID of the building usage. IDs available:
    NS_PIPE - pipe runs North to South
    EW_PIPE - pipe runs East to West
    VC_PIPE - vertical and corner pipes.
    WORKSHOP - location where work is done.

Changing reaction_pipe_dreams.txt:
  If you look at the beginning of the file there is a section that is written as
"- START PIPE DREAMS
 ...
 - END PIPE DREAMS"

  This is the section that pipe-dreams will read for information on what to add
to an entity. The lines after start should look like this:
COMMAND LINE:"- <ENTITY_ID> <BUILDING_ID> <REACTION_ID> <I|O|A> <W|M|A> <LEVEL> <<ALL>|<OFFSETS>>"
EXAMPLE LINE:"- WATERPUMP PIPE_DREAM_INPUT_ON I W 1 [ 0 -1 0 ]"
EXAMPLE LINE:"- WATERPUMP PIPE_DREAM_INPUT-OFF I W 8 [ 0 -1 0 ]"

  BUILDING_ID is the actual ID of the building that gets the reaction.
  <I|O(|A)> - I is an Input reaction.
            - O is an Output reaction.
            - A is only used with LEVEL = 8 after it. See below.
  <W|M(|A)> - W is Water.
            - M is Magma.
            - A is only used with LEVEL = 8 after it. See below.
  LEVEL is the level of fluid that the reaction will raise or drop a location.
        i.e 0 to 7 ; 8 is equivalent to off.
  OFFSETS is the offset from the worker's location.
        i.e. [-2 0 -1] will cause the operation at 2 west, 1 below of worker
        location when the reaction is activated.
  TODO: A and ALL are for a future edition and only documented here for refrence.
  ALL - targets all potential targets in an OFF reaction.
    i.e.  "I W 8 ALL" - targets all Water Inputs and turn them off.
          "O W 8 ALL" - targets all Water Outputs and turns them off.
          "I A 8 ALL" - targets all W|M Inputs and turns them off.
          "A A 8 ALL" - Targets all W|M I|O and turns them off.

]====]

--INITIALIZING VARIABLES AND PROCESSING INITIAL ARGUMENTS
local utils = require 'utils'
local persistTable = require 'persist-table'
persistTable.GlobalTable.pipeDreamsTable = persistTable.GlobalTable.pipeDreamsTable or {}
local pipeDreamsTable = persistTable.GlobalTable.pipeDreamsTable
pipeDreamsTable.VERBOSE = pipeDreamsTable.VERBOSE or "OFF"
pipeDreamsTable.AddBuilding = "off"
pipeDreamsTable.Pipes = pipeDreamsTable.Pipes or {}
pipeDreamsTable.Systems = pipeDreamsTable.Systems or {}
pipeDreamsTable.BuildingList = pipeDreamsTable.BuildingList or {}
pipeDreamsTable.ReactionList = pipeDreamsTable.ReactionList or {}
pipeDreamsTable.LiquidTable = pipeDreamsTable.LiquidTable or {}
pipeDreamsTable.BuildCustomType = pipeDreamsTable.BuildCustomType or {}
pipeDreamsTable.CheckList = pipeDreamsTable.CheckList or {}

liquidTable = pipeDreamsTable.LiquidTable
Pipes = persistTable.GlobalTable.pipeDreamsTable.Pipes
Systems = persistTable.GlobalTable.pipeDreamsTable.Systems
CheckList = persistTable.GlobalTable.pipeDreamsTable.CheckList



local validArgs = validArgs or utils.invert({
  'enable',
  'disable',
  'help',
  'setup',
  'verbose',
  'report',
})

local args = utils.processArgs({...}, validArgs)

if args.help then
  print(usage)
  return
end

if args.setup then
  print(setup)
  return
end

if args.verbose then
  if args.verbose == "ON" then
    pipeDreamsTable.VERBOSE = args.verbose
  elseif args.verbose == "OFF" then
    pipeDreamsTable.VERBOSE = args.verbose
  else
    print("pipe-dreams verbose setting must be either ON or OFF.")
    return
  end
end

local VERBOSE = false
if pipeDreamsTable.VERBOSE == "ON" then
  VERBOSE = true
end

if args.report then
  local t="\t" -- I type so many of them...
  print( "Printing LiquidTable" )
  print( "Index\ttype\tlevel\tx\ty\tz\tmagma?\tbID" )
  for _,i in pairs(liquidTable._children) do
    local L = liquidTable[i]
    if L.Magma then local magma = "yes" else magma = "no" end
    print( i..t..L.Type..t..L.Depth..t..L.x..t..L.y..t..L.z..t..magma..t..L.Building )
  end
  print( "Printing Pipes" )
  print( "Id\tpipetype\tx1\tx2\ty1\ty2\tz\tSystem" )
  for _,i in pairs(Pipes._children) do
    local P = Pipes[i]
    print( i..t..P.PIPETYPE.."  "..t..P.x1..t..P.x2..t..P.y1..t..P.y2..t..P.z..t..P.System )
  end
  print( "Printing Systems" )
  print( "Id\tsize\twater\tmagma" )
  for _,i in pairs(Systems._children) do
    local S = Systems[i]
    print( i..t..S.Size..t..S.CountW..t..S.CountM )
  end
  return
end





--[[
FUNCTIONS FOR THE REST OF THE SCRIPT THAT RUNS LATER.
  INCLUDES:
    LoadBuildings()
    LoadReactions()
    UpdateLiquids()
    LiquidSink( sink_id )
    LiquidSource( source_id )
    SystemCombine( sys_id_1, sys_id_2 )
    CompareBuilding( pipe_id )
    AddBuilding()
    SystemTrace( pipe_id , TraceTable )
    DeleteBuilding( pipe_id )
    CheckBuilding()



--]]

function LoadBuildings()
  local recordOn = false
  for line in io.lines("raw/objects/building_pipe_dreams.txt") do
    if line == "- END PIPE DREAMS" then
      recordOn = false
    elseif line == "- START PIPE DREAMS" then
      recordOn = true
    elseif recordOn then
      if VERBOSE then print(line) end
      local recordLine={}
      for word in string.gmatch(line, "[%w_]+") do
        table.insert(recordLine,word)
      end

      -- create a commandline to checks entity and make the change
      local commandLine = 'modtools/if-entity -id "'..recordLine[1]
      commandLine = commandLine..'" -cmd [ modtools/change-build-menu add '
      commandLine = commandLine..recordLine[2]..' MACHINES ]'
      if VERBOSE then print( commandLine ) end
      dfhack.run_command( commandLine )
      local b = dfhack.script_environment('modtools/change-build-menu').GetWShopType(recordLine[2])
      if VERBOSE then print(b.type,b.subtype,b.custom) end
      -- record it

      pipeDreamsTable.BuildingList[recordLine[2]]={} -- the building
      pipeDreamsTable.BuildingList[recordLine[2]].TYPE = tostring(b.type)
      pipeDreamsTable.BuildingList[recordLine[2]].SUBTYPE = tostring(b.subtype)
      pipeDreamsTable.BuildingList[recordLine[2]].CUSTOM = tostring(b.custom)
      pipeDreamsTable.BuildingList[recordLine[2]].PIPETYPE = recordLine[3]
      pipeDreamsTable.BuildCustomType[b.custom] = recordLine[2]
    end
  end
  return
end





function UnloadBuildings()
  local recordOn = false
  for line in io.lines("raw/objects/building_pipe_dreams.txt") do
    if line == "- END PIPE DREAMS" then
      recordOn = false
    elseif line == "- START PIPE DREAMS" then
      recordOn = true
    elseif recordOn then
      if VERBOSE then print(line) end
      local recordLine={}
      for word in string.gmatch(line, "[%w_]+") do
        table.insert(recordLine,word)
      end

      -- create a commandline that checks the identity than reverts the change
      local commandLine = 'modtools/if-entity -id "'..recordLine[1]
      commandLine = commandLine..'" -cmd [ modtools/change-build-menu revert '
      commandLine = commandLine..recordLine[2]..' MACHINES ]'
      if VERBOSE then print( commandLine ) end
      dfhack.run_command( commandLine )

    end
  end
  return
end





function LoadReactions()
  local recordOn = false
  local reactionList=pipeDreamsTable.ReactionList
  for line in io.lines("raw/objects/reaction_pipe_dreams.txt") do
    if line == "- END PIPE DREAMS" then
      recordOn = false
    elseif line == "- START PIPE DREAMS" then
      recordOn = true
    elseif recordOn then
      if VERBOSE then print(line) end
      local recordLine={}
      for word in string.gmatch(string.sub(line,3), "[%w_-]+") do
        table.insert(recordLine,word)
      end
      -- record it
      local reaction = recordLine[2]
      reactionList[reaction]=reactionList[reaction] or {}
      -- this is written like this incase there are multiple buildings with same reaction
      reactionList[reaction].BUILDING = reactionList[reaction].BUILDING or {}
      -- builds a list of keys that are the building names
      reactionList[reaction].BUILDING[recordLine[1]] = "TRUE"
      -- may go back and rewrite these to be under the building key list above.
      reactionList[reaction].TYPE = recordLine[3]
      reactionList[reaction].LIQUID = recordLine[4]
      reactionList[reaction].LEVEL = recordLine[5]
      reactionList[reaction].OFFSET = {}
      reactionList[reaction].OFFSET.X = recordLine[6]
      reactionList[reaction].OFFSET.Y = recordLine[7]
      reactionList[reaction].OFFSET.Z = recordLine[8]
      -- prepare information for reaction trigger.
      local rlr = reactionList[reaction]
      local pos = rlr.OFFSET.X..' '..rlr.OFFSET.Y..' '..rlr.OFFSET.Z
      local source=""
      local liquid=""
      local level=""
      if rlr.LEVEL == "OFF" then
        level = "-remove"
      else
        if rlr.TYPE == "I" then source = "-sink " end
        if rlr.TYPE == "O" then source = "-source " end
        if rlr.LIQUID == "M" then liquid = "-magma " end
        if rlr.LEVEL == "8" then
          level = "-remove"
          source = ""
          liquid = ""
        else
          level = rlr.LEVEL
        end
      end
      -- create the reaction trigger
      local cmd = 'modtools/reaction-trigger -reactionName '..reaction..' '
        cmd = cmd..'-command [ pipe-dreams-source -unit \\\\WORKER_ID '
        cmd = cmd..'-building \\\\BUILDING_ID '
        cmd = cmd..'-offset [ '.. pos..' ] '..liquid..source..level..' ]'
        if VERBOSE then print( cmd ) end
        dfhack.run_command( cmd )

    end
  end
  return
end





function UnloadReactions()
  --[[
  -- Need to figure a way to remove the reaction?!?!  This block is just being
  stored until a way is discovered.

  local recordOn = false
  for line in io.lines("raw/objects/reaction_pipe_dreams.txt") do
    if line == "- END PIPE DREAMS" then
      recordOn = false
    elseif line == "- START PIPE DREAMS" then
      recordOn = true
    elseif recordOn then
      if VERBOSE then print(line) end
      local recordLine={}
      for word in string.gmatch(string.sub(line,3), "[%w_-]+") do
        table.insert(recordLine,word)
      end
    end
  end
  --]]
  return
end





-- Initiates any saved liquid sources and sinks
function UpdateLiquids(n)
  liquidTable = persistTable.GlobalTable.pipeDreamsTable.LiquidTable
  for _,i in pairs(liquidTable._children) do
    liquid = liquidTable[i]
    if liquid.Type == 'Source' then
      LiquidSource(i)
    elseif liquid.Type == 'Sink' then
      LiquidSink(i)
    end
  end
  return
end





function LiquidSource(n)
  n = tostring(n)
  local persistTable = require 'persist-table'
  liquidTable = persistTable.GlobalTable.pipeDreamsTable.LiquidTable
  liquid = liquidTable[n]
  if liquid then
    x = tonumber(liquid.x)
    y = tonumber(liquid.y)
    z = tonumber(liquid.z)
    depth = tonumber(liquid.Depth)
    magma = liquid.Magma
    check = tonumber(liquid.Check)
    block = dfhack.maps.ensureTileBlock(x,y,z)
    dsgn = block.designation[x%16][y%16]
    flow = block.liquid_flow[x%16][y%16]
    flow.temp_flow_timer = 10
    flow.unk_1 = 10
    if liquid.Count == "YES" then
      Pipes = persistTable.GlobalTable.pipeDreamsTable.Pipes
      Systems = persistTable.GlobalTable.pipeDreamsTable.Systems
      bID = liquid.Building
      if not Pipes[bID] then
        liquid = nil
      end
      sID = Pipes[bID].System
      if not Systems[sID] then
        liquid = nil
      end
      LSS = Systems[sID]
      if magma then Count = tonumber(LSS.CountM) else Count = tonumber(LSS.CountW) end
      if dsgn.flow_size < depth and Count > 0 then -- we have Count and its less than depth
        if Count >= ( depth - dsgn.flow_size ) then --Count >= than difference
          Count = Count - ( depth - dsgn.flow_size )
          dsgn.flow_size = depth
          if magma then dsgn.liquid_type = true end
          block.flags.update_liquid = true
          block.flags.update_liquid_twice = true
        else                                       -- 0 < Count < than difference
          dsgn.flow_size = dsgn.flow_size + Count
          Count = 0
          if magma then dsgn.liquid_type = true end
          block.flags.update_liquid = true
          block.flags.update_liquid_twice = true
        end
      end
      if magma then LSS.CountM = tostring(Count) else LSS.CountW = tostring(Count) end
    else -- Backwards Compatibility.
      if dsgn.flow_size < depth then dsgn.flow_size = depth end
      if magma then dsgn.liquid_type = true end
      block.flags.update_liquid = true
      block.flags.update_liquid_twice = true
    end
    dfhack.timeout(check,'ticks',
                   function ()
                     dfhack.script_environment('pipe-dreams').LiquidSource(n)
                   end
                  )
  end
  return
end





function LiquidSink(n)
  n = tostring(n)
  local persistTable = require 'persist-table'
  liquidTable = persistTable.GlobalTable.pipeDreamsTable.LiquidTable
  liquid = liquidTable[n]
  if liquid then
    x = tonumber(liquid.x)
    y = tonumber(liquid.y)
    z = tonumber(liquid.z)
    depth = tonumber(liquid.Depth)
    magma = liquid.Magma
    check = tonumber(liquid.Check)
    block = dfhack.maps.ensureTileBlock(x,y,z)
    dsgn = block.designation[x%16][y%16]
    flow = block.liquid_flow[x%16][y%16]
    flow.temp_flow_timer = 10
    flow.unk_1 = 10
    if liquid.Count == "YES" then
      Pipes = persistTable.GlobalTable.pipeDreamsTable.Pipes
      Systems = persistTable.GlobalTable.pipeDreamsTable.Systems
      bID = liquid.Building
      if not Pipes[bID] then
        liquid = nil
      end
      sID = Pipes[bID].System
      if not Systems[sID] then
        liquid = nil
      end
      LSS = Systems[sID]
      size = tonumber(LSS.Size)
      Count = size - tonumber(LSS.CountM) - tonumber(LSS.CountW) --Count now equals the max it can take.
      if dsgn.flow_size > depth and Count > 0 then -- We have Count and its greater than depth
        if Count >= ( dsgn.flow_size - depth ) then -- count is greate than difference
          Count = dsgn.flow_size - depth --Count now equals the difference.
          dsgn.flow_size = depth
          if magma then dsgn.liquid_type = true end
          block.flags.update_liquid = true
          block.flags.update_liquid_twice = true
        else -- Count is less than difference
          dsgn.flow_size = dsgn.flow_size - Count --Count is the new difference.
          if magma then dsgn.liquid_type = true end
          block.flags.update_liquid = true
          block.flags.update_liquid_twice = true
        end
      else
      -- It didn't do anything so set this Count to 0
        Count = 0
      end
      if magma then
        LSS.CountM = tostring(tonumber(LSS.CountM) + Count)
      else
        LSS.CountW = tostring(tonumber(LSS.CountW) + Count)
      end
    else -- Backwards Compatibility.
      if dsgn.flow_size > depth then dsgn.flow_size = depth end
      if magma then dsgn.liquid_type = true end
      block.flags.update_liquid = true
      block.flags.update_liquid_twice = true
    end
    dfhack.timeout(check,'ticks',
                   function ()
                     dfhack.script_environment('pipe-dreams').LiquidSink(n)
                   end
                  )
  end
  return
end





function SystemCombine( aID, bID )

  if aID == bID then return end -- they are the same ID.

  local Pipes = pipeDreamsTable.Pipes
  local Systems = pipeDreamsTable.Systems

  -- 2 different Systems so combine them.
  aSys=tostring(Pipes[aID].System)
  bSys=tostring(Pipes[bID].System)
  if aSys == bSys then return end -- they are the same system?!?

  local WCounter = tonumber(Systems[aSys].CountW) + tonumber(Systems[bSys].CountW)
  local MCounter = tonumber(Systems[aSys].CountM) + tonumber(Systems[bSys].CountM)
  local Size = tonumber(Systems[aSys].Size) + tonumber(Systems[bSys].Size)

  if tonumber(aSys) > tonumber(bSys) then
  -- switch the numbers so that aSys is bSys and bSys is aSys
    if VERBOSE then print("Switching Asys to Bsys: "..aSys.." to "..bSys ) end
    aSys, bSys = bSys, aSys
    if VERBOSE then print("Asys | Bsys after: "..aSys.." | "..bSys ) end
  end      

  for _,pID in pairs(Systems[bSys].Pipes._children) do
    Pipes[pID].System = aSys
    Systems[aSys].Pipes[pID] = pID
  end

  Systems[aSys].CountW = tostring(WCounter)
  Systems[aSys].CountM = tostring(MCounter)
  Systems[aSys].Size = tostring(Size)
  Systems[bSys] = nil
  return
end





function comparebuilding(bID)
  Pipes = pipeDreamsTable.Pipes
  Systems = pipeDreamsTable.Systems

  for _,pID in pairs(Pipes._children) do
    --check to see if the pipes could connect.
    if not ( Pipes[bID].PIPETYPE == "WORKSHOP" and Pipes[pID].PIPETYPE == "WORKSHOP" ) and not ( bID == pID ) then
    -- blocks direct workshop to workshop connections and ignore if you find the same ID.

      if Pipes[bID].D and Pipes[pID].U then
        -- they have up/down connections since all things with an up connection
        -- have a down Connection.  We can just test for both here.
        if Pipes[bID].x1 == Pipes[pID].x1 and Pipes[bID].y1 == Pipes[pID].y1 then 
          if (tonumber(Pipes[bID].z) - 1 ) == tonumber(Pipes[pID].z) then
        -- the new pipe is above the test pipe.  set connection array.
          Pipes[bID].D = pID
          Pipes[pID].U = bID
          SystemCombine( pID , bID )
          elseif ( tonumber(Pipes[bID].z) + 1 ) == tonumber(Pipes[pID].z) then
        -- the new pipe is below the test pipe.  set connection array.
          Pipes[bID].U = pID
          Pipes[pID].D = bID
          SystemCombine( pID , bID )
          end
        end
      end

      if Pipes[bID].N and Pipes[pID].S and Pipes[bID].z == Pipes[pID].z then
      -- they have North/South connections since all things with a North
      -- Connection have a South Connections.  We can just test for both here.
        local isNorth = false
        local isSouth = false
        if (tonumber(Pipes[bID].y1) - 1) == tonumber(Pipes[pID].y2) then
          -- pID is on the line to the north of bID
          isNorth = true
        elseif (tonumber(Pipes[bID].y2) + 1) == tonumber(Pipes[pID].y1) then
          -- pID is on the line to the south of bID
          isSouth = true
        end
        if isNorth or isSouth then
          for i = 0, tonumber(Pipes[bID].Width) - 1 do
            for j = 0, tonumber(Pipes[pID].Width) - 1 do
            --[[  Just a little diagram of how the buildings variables align. for
            X1,Y1 - X2,Y1  later refrence.  here "i" refers to across the bID and
             |building|    "j" refers for across the pID/Pipes[pID].
            X1,Y2 - X1,Y2
            --]]
              if (tonumber(Pipes[bID].x1) + i) == (tonumber(Pipes[pID].x1) + j) then
                if isNorth then
                --we have a match on North Side of bID
                  Pipes[bID].N[tostring(i+1)]= pID
                  Pipes[pID].S[tostring(j+1)] = bID
                  SystemCombine( pID , bID )
                else
                --we must have a match on South Side of bID
                  Pipes[bID].S[tostring(i+1)]= pID
                  Pipes[pID].N[tostring(j+1)] = bID
                  SystemCombine( pID , bID )
                end
              end
            end
          end
        end
      end

      if Pipes[bID].E and Pipes[pID].W and Pipes[bID].z == Pipes[pID].z then
      -- they have east/west connections since all things with East Connection
      -- have a West Connections.  We can just test for both here.
        local isEast = false
        local isWest = false
        if (tonumber(Pipes[bID].x1) - 1) == tonumber(Pipes[pID].x2) then
          -- pID is on the line to the west of bID
          isWest = true
        elseif (tonumber(Pipes[bID].x2) + 1) == tonumber(Pipes[pID].x1) then
          -- pID is on the line to the east of bID
          isEast = true
        end
        if isEast or isWest then
          for i = 0, tonumber(Pipes[bID].Length) - 1 do
            for j = 0, tonumber(Pipes[pID].Length) - 1 do
            --[[  Just a little diagram of how the buildings variables align. for
            X1,Y1 - X2,Y1  later refrence.  here "i" refers to across the bID and
             |building|    "j" refers for across the pID/Pipes[pID].
            X1,Y2 - X1,Y2
            --]]
              if (tonumber(Pipes[bID].y1) + i) == (tonumber(Pipes[pID].y1) + j) then
                if isEast then
                --we have a match on East Side of bID
                  Pipes[bID].E[tostring(i+1)]= pID
                  Pipes[pID].W[tostring(j+1)] = bID
                  SystemCombine( pID , bID )
                else
                --we must have a match on West Side of bID
                  Pipes[bID].W[tostring(i+1)]= pID
                  Pipes[pID].E[tostring(j+1)] = bID
                  SystemCombine( pID , bID )
                end
              end
            end
          end
        end
      end
    end
  end
  return
end





function AddBuilding()

  if VERBOSE then print("AddBuilding is running!") end
  Pipes = pipeDreamsTable.Pipes
  Systems = pipeDreamsTable.Systems
  CheckList = pipeDreamsTable.CheckList

  for _,bID in pairs(CheckList._children) do
    local building = df.building.find(tonumber(bID))
    if not (building) then
    -- Do Nothing ... this building doesn't exist!
      CheckList[bID] = nil

    elseif ( Pipes[bID] ) then
    -- DO NOTHING.... this building has already been added.
      CheckList[bID] = nil

    elseif  building.construction_stage == 3  then
    -- Its complete!
      if VERBOSE then print("Creating building: "..bID) end

    -- Lets add it to pipes and build a System for it.
      ThisPipeIs = pipeDreamsTable.BuildCustomType[building.custom_type]
      PipeBuild = pipeDreamsTable.BuildingList[ThisPipeIs]

    -- so we track the pipe System according to the building Id.
      Pipes[bID] = {}
      Pipes[bID].PIPETYPE = PipeBuild.PIPETYPE

    -- Now we store additional information on the size of the building.
      Pipes[bID].x1 = tostring(building.x1)
      Pipes[bID].x2 = tostring(building.x2)
      Pipes[bID].y1 = tostring(building.y1)
      Pipes[bID].y2 = tostring(building.y2)
      Pipes[bID].z  = tostring(building.z)
      Pipes[bID].Width = tostring(building.x2 - building.x1 + 1)
      Pipes[bID].Length = tostring(building.y2 - building.y1 + 1)
      Pipes[bID].Size = tostring(tonumber(Pipes[bID].Width) * tonumber(Pipes[bID].Length) * 7 )
      if Pipes[bID].PIPETYPE == "WORKSHOP" then
      -- WORKSHOPS don't get a size for magma/water storage.
        Pipes[bID].Size = "0"
      end
    -- This sets up the connection arrays.  0 = no connection. otherwise ID of
    -- the building connected.
      if not ( Pipes[bID].PIPETYPE == "EW_PIPE" ) then
      -- establish an array of north/south connections based on building width.
      -- important if we ever want to add in larger than 1 width pipes in future.
        Pipes[bID].N={}
        Pipes[bID].S={}
        for i = 1, tonumber(Pipes[bID].Width) do
          Pipes[bID].N[tostring(i)]="0"
          Pipes[bID].S[tostring(i)]="0"
        end
      end
      if not ( Pipes[bID].PIPETYPE == "NS_PIPE" ) then
      -- establish an array of east/west connections based on building width.
      -- important if we ever want to add in larger than 1 width pipes in future.
        Pipes[bID].E={}
        Pipes[bID].W={}
        for i = 1, tonumber(Pipes[bID].Width) do
          Pipes[bID].E[tostring(i)]="0"
          Pipes[bID].W[tostring(i)]="0"
        end
      end
      if Pipes[bID].PIPETYPE == "VC_PIPE" then
      -- only possibility for Up and Down connections is a Vertical Control Pipe.
        Pipes[bID].U="0"
        Pipes[bID].D="0"
      end

      -- Create its System.
      Pipes[bID].System = bID
      Systems[bID] = {}
      Systems[bID].CountW = "0"
      Systems[bID].CountM = "0"
      Systems[bID].Size = tostring(Pipes[bID].Size)
      Systems[bID].Pipes={}
      Systems[bID].Pipes[bID] = bID

      -- now we need to check if any other pipes are connected to this pipe
  
      comparebuilding(bID)

      -- remove it from the CheckList! Its done!
      CheckList[bID] = nil

      -- we break here... this kicks the loop out and lets the game relax a second.
      break
      -- it doesn't get the kick until it's added a building... This just gives the
      -- game a total break of 100 ticks before it starts searching for another bID
      -- to add.  It doesn't kick out on the delete bIDs (already recorded and missing).
    end

  end

  -- clean up! is there any more children left?
  if (#CheckList._children) == 0 then
  -- all the children are gone... so don't run the timeout!
    pipeDreamsTable.AddBuilding = "off"
    if VERBOSE then print("Adding building completed!") end
  else
  -- we have children left so keep checking on them!
    dfhack.timeout(100,'ticks',
                   function ()
                     dfhack.script_environment('pipe-dreams').AddBuilding(bID)
                   end
                  )
  end
  return
end





function SystemTrace(pID, excludeTraceTable)
  Pipes = pipeDreamsTable.Pipes
  Systems = pipeDreamsTable.Systems

  if VERBOSE then
    if excludeTraceTable.Initiate then
      print("SystemTrace - Initiating a Trace.")
    else
      print("SystemTrace - Continuing a Trace.")
    end
    print("LostPipe: "..excludeTraceTable.LostPipe.."Size: "..excludeTraceTable.Size.."NewSysID: "..excludeTraceTable.NewSysID)
  end

  -- saves these value for later computations.
  local initiate = excludeTraceTable.Initiate
  local lostPipe = excludeTraceTable.LostPipe

  -- no matter if this is the first run or the last run! the next is not the initiate.
  excludeTraceTable.Initiate = false

  -- get the size and add it to the table
  excludeTraceTable.Size = excludeTraceTable.Size + tonumber(Pipes[pID].Size)
  
  --we add this pID to the NewSysPipes and excludeTraceTable!
  excludeTraceTable[pID]=pID
  excludeTraceTable.NewSysPipes[pID]=pID
  if initiate or ( tonumber(excludeTraceTable.NewSysID) > tonumber(pID) ) then
    excludeTraceTable.NewSysID = pID
  end

  if Pipes[pID].U then
    if Pipes[pID].U == lostPipe then
      Pipes[pID].U = "0"
    elseif not( excludeTraceTable[Pipes[pID].U] ) then
      -- we haven't excluded this one yet so we send a SystemTrace there:
      tID = Pipes[pID].U
      excludeTraceTable = SystemTrace(tID, excludeTraceTable)
    end
    if Pipes[pID].D == lostPipe then
      Pipes[pID].D = "0"
    elseif not( excludeTraceTable[Pipes[pID].D] ) then
      -- we haven't excluded this one yet so we send a SystemTrace there:
      tID = Pipes[pID].D
      excludeTraceTable = SystemTrace(tID, excludeTraceTable)
    end
  end
  if Pipes[pID].N then
    for _,ns in pairs(Pipes[pID].N._children) do
      if Pipes[pID].N[ns] == lostPipe then
        Pipes[pID].N[ns] = "0"
      elseif not( excludeTraceTable[Pipes[pID].N[ns]] ) then
        -- we haven't excluded this one yet so we send a SystemTrace there:
        tID = Pipes[pID].N[ns]
        excludeTraceTable = SystemTrace(tID, excludeTraceTable)
      end
      if Pipes[pID].S[ns] == lostPipe then
        Pipes[pID].S[ns] = "0"
      elseif not( excludeTraceTable[Pipes[pID].S[ns]] ) then
        -- we haven't excluded this one yet so we send a SystemTrace there:
        tID = Pipes[pID].S[ns]
        excludeTraceTable = SystemTrace(tID, excludeTraceTable)
      end
    end
  end
  if Pipes[pID].E then
    for _,ew in pairs(Pipes[pID].E._children) do
      if Pipes[pID].E[ew] == lostPipe then
        Pipes[pID].E[ew] = "0"
      elseif not( excludeTraceTable[Pipes[pID].E[ew]] ) then
        -- we haven't excluded this one yet so we send a SystemTrace there:
        tID = Pipes[pID].E[ew]
        excludeTraceTable = SystemTrace(tID, excludeTraceTable)
      end
      if Pipes[pID].W[ew] == lostPipe then
        Pipes[pID].W[ew] = "0"
      elseif not( excludeTraceTable[Pipes[pID].W[ew]] ) then
        -- we haven't excluded this one yet so we send a SystemTrace there:
        tID = Pipes[pID].W[ew]
        excludeTraceTable = SystemTrace(tID, excludeTraceTable)
      end
    end
  end

  if initiate then
  -- this was an initiate call and we now need to build a system around the data collected!

    -- store the sID to make the rest easy!
    sID = tostring(excludeTraceTable.NewSysID)

    -- Does it Exist?
    if Systems[sID] then
    -- the sID doesn't exist create it!
      Systems[sID] = {}
    else
    -- the sID does exist, so we destroy the sID's Pipe list.
      Systems[sID].Pipes = nil
    end

    -- Set System Size
    Systems[sID].Size = tostring(excludeTraceTable.Size)

    -- set the Magma first!
    if excludeTraceTable.StoredCountM > excludeTraceTable.Size then
      Systems[sID].CountM = tostring(excludeTraceTable.Size)
      excludeTraceTable.StoredCountM = excludeTraceTable.StoredCountM - excludeTraceTable.Size
    else
      Systems[sID].CountM = tostring(excludeTraceTable.StoredCountM)
      excludeTraceTable.StoredCountM = 0
    end

    -- set the Water second!
    if excludeTraceTable.StoredCountW > (tonumber(Systems[sID].Size) - tonumber(Systems[sID].CountM)) then
      Systems[sID].CountW = tostring(tonumber(Systems[sID].Size) - tonumber(Systems[sID].CountM))
      excludeTraceTable.StoredCountW =excludeTraceTable.StoredCountW - tonumber(Systems[sID].CountW)
    else
      Systems[sID].CountW=tostring(excludeTraceTable.StoredCountW)
      excludeTraceTable.StoredCountW = 0
    end

    -- set the pipes and their system connection!
    Systems[sID].Pipes = {}
    for k,v in pairs(excludeTraceTable.NewSysPipes) do
      -- it doesn't even matter as everytime we added in a k=v it was pID=pID.
      Systems[sID].Pipes[k]=v
      Pipes[k].System = sID
    end

    -- Now we need to prepare the excludeTraceTable to send back to DeleteBuilding.
    excludeTraceTable.Initiate = true
    excludeTraceTable.NewSysPipes = nil
    excludeTraceTable.NewSysPipes = {}
    excludeTraceTable.NewSysID = "0"
    excludeTraceTable.Size = 0

    if VERBOSE then
      local S =Systems[sID]
      print("SystemTrace - A system completed.")
      print( "new-sID:"..sID.." Size: "..S.Size.." Water: "..S.CountW.." Magma: "..S.CountM )
    end
    -- this lets the DeleteBuilding script know the script made a new system.
    excludeTraceTable.CompletedSystem = true

  end

  -- Now we send it back to the future!?!?!
  return excludeTraceTable

end





function DeleteBuilding(pID)
  Pipes = pipeDreamsTable.Pipes
  Systems = pipeDreamsTable.Systems

  -- establish the excludeTraceTable
  local excludeTraceTable = {}
  excludeTraceTable.Size = 0
  excludeTraceTable.LostPipe = pID
  excludeTraceTable.Initiate = true
  excludeTraceTable.CompletedSystem = false
  excludeTraceTable.NewSysID = "0"
  excludeTraceTable.NewSysPipes = {}
  excludeTraceTable.StoredCountW = tonumber(Systems[Pipes[pID].System].CountM)
  excludeTraceTable.StoredCountM = tonumber(Systems[Pipes[pID].System].CountM)
  -- set ignored IDs to not be traced.
  excludeTraceTable[pID] = pID
  excludeTraceTable["0"] = "0"

  if Pipes[pID].System == pID then
  -- This pipe system is attached to this pipe as an ID so delete it.
    Systems[pID] = nil
  end

  if Pipes[pID].U then
    if not( excludeTraceTable[Pipes[pID].U] ) then
      -- we haven't excluded this one yet so we send a SystemTrace there:
      tID = Pipes[pID].U
      excludeTraceTable = SystemTrace(tID, excludeTraceTable)
    end
    if not( excludeTraceTable[Pipes[pID].D] ) then
      -- we haven't excluded this one yet so we send a SystemTrace there:
      tID = Pipes[pID].D
      excludeTraceTable = SystemTrace(tID, excludeTraceTable)
    end
  end
  if Pipes[pID].N then
    for _,ns in pairs(Pipes[pID].N._children) do
      if not( excludeTraceTable[Pipes[pID].N[ns]] ) then
        -- we haven't excluded this one yet so we send a SystemTrace there:
        tID = Pipes[pID].N[ns]
        excludeTraceTable = SystemTrace(tID, excludeTraceTable)
      end
      if not( excludeTraceTable[Pipes[pID].S[ns]] ) then
        -- we haven't excluded this one yet so we send a SystemTrace there:
        tID = Pipes[pID].S[ns]
        excludeTraceTable = SystemTrace(tID, excludeTraceTable)
      end
    end
  end
  if Pipes[pID].E then
    for _,ew in pairs(Pipes[pID].E._children) do
      if not( excludeTraceTable[Pipes[pID].E[ew]] ) then
        -- we haven't excluded this one yet so we send a SystemTrace there:
        tID = Pipes[pID].E[ew]
        excludeTraceTable = SystemTrace(tID, excludeTraceTable)
      end
      if not( excludeTraceTable[Pipes[pID].W[ew]] ) then
        -- we haven't excluded this one yet so we send a SystemTrace there:
        tID = Pipes[pID].W[ew]
        excludeTraceTable = SystemTrace(tID, excludeTraceTable)
      end
    end
  end

  -- Now the Pipe should of been deleted from all connection data and the pipes
  -- it was connected to are aligned into other systems that don't inlcude this
  -- pipe in their lists.  So we can just nil this and it will disappear.
  Pipes[pID] = nil

  return

end





function CheckBuilding()
  if VERBOSE then print("CheckBuilding is running!") end
  Pipes = pipeDreamsTable.Pipes
  Systems = pipeDreamsTable.Systems
  CheckList = pipeDreamsTable.CheckList

  for _,pID in ipairs(Pipes._children) do
    local pBuilding = df.building.find(tonumber(pID))
    if not ( pBuilding ) then
      DeleteBuilding(pID)
    end
  end

  for _,building in ipairs(df.global.world.buildings.other.WORKSHOP_CUSTOM) do
    if building.custom_type then
      bID = tostring(building.id)
      if Pipes[bID] or CheckList[bID] then
      -- do nothing
      elseif pipeDreamsTable.BuildCustomType[building.custom_type] then
      -- add the bID to the CheckList
        if VERBOSE then print(bID.." is added to the checklist.") end
        CheckList[bID] = bID
      end
    end
  end

  if not ( (#CheckList._children) == 0 ) and pipeDreamsTable.AddBuilding == "off" then
  if VERBOSE then print("AddBuilding initialized!") end
  --run addbuilding!
    AddBuilding()
  --this line sets the setting that keeps it from running multiple addbuildings.
    pipeDreamsTable.AddBuilding = "on"
  end
  return
end





-- Here we continue the main body of the script
pipeEvents = require "plugins.eventful"
pipeEvents.enableEvent( pipeEvents.eventType.BUILDING,100 )

if args.enable then
  -- turns on modtools/change-build-menu in case it isn't on.
  dfhack.run_script( "modtools/change-build-menu", "start" )
  LoadBuildings()
  LoadReactions()
  -- runs the UpdateLiquids and turns on all saved Sinks and Sources.
  UpdateLiquids()
  CheckBuilding()
  -- Construct the building listener.
  pipeEvents.onBuildingCreatedDestroyed.pipeBuildings = function(building)
    CheckBuilding()
  end
  print("pipe-dreams enabled.")
elseif args.disable then
  UnloadReactions()
  UnloadBuildings()
  -- zero these tables after Unloading the reaction-triggers and buildings.
  pipeDreamsTable.ReactionList = nil
  pipeDreamsTable.BuildingList = nil
  pipeDreamsTable.LiquidTable = nil
  pipeDreamsTable.Pipes = nil
  pipeDreamsTable.Systems = nil
  pipeEvents.onBuildingCreatedDestroyed.pipeBuildings = function(buildingID)
  end
  print("pipe-dreams disabled.")
end
