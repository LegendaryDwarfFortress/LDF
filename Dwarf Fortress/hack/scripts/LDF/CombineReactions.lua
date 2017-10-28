--Combine Reactions a script to enforce the use of details on random jobs.
local usage = [====[

CombineReactions
==================
Combine Reactions uses an onJobInitiated eventful listener to watch for
registered reactions that need to have their details set.  This forces players
to utilize the detail option on a job prior to it becoming initiated otherwise
the job is canceled and removed.

Arguments::
    -register [ list of reaction names ]

Example::
    CombineReactions -register [ DWAARF_COMBINE_10_STONE DWARF_COMBINE_10_WOOD ]

As many reactions as are desired to be targetted can be added to the line
indefinitely, seperated only by a space.  The reaction cannot have a space
inside its definition name.  Only one call should be made as this does not save
the list between calls and any additional calls will rewrite the previous list.

Written by Amostubal.
]====]

local utils=require 'utils'

validArgs = validArgs or utils.invert ({
 'register'
})

local args = utils.processArgs({...}, validArgs)


local JobList = {}
if ... then 
  for i,_ in ipairs(args.register) do
    JobList[_]=true
  end
else
  error("no variables")
end

CROJI = require('plugins.eventful')
CROJI.enableEvent(CROJI.eventType.JOB_INITIATED,1)
CROJI.onJobInitiated.CombineReactions_OJI = function(job)
  if JobList[job.reaction_name] and job.mat_index == -1 then
    dfhack.gui.showAnnouncement("The job: "..dfhack.job.getName(job)..", is canceled, please set details.", COLOR_RED)
    dfhack.job.removeJob(job)
  end
end
