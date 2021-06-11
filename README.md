# CSAR_MOOSE
Refactoring Ciribob's excellent CSAR script into Moose as object-oriented FSM

## Testing
* You need a late activated infantry group ("Downed Pilot" below) to stand in for the actual pilot. 
* Setup is currently in lines 186ff of this file, or you can use `myCSAR.<setting> = <value>` after instantiating the object.
* Test mission setup  - the test missions contains a trigger to load the CSAR_Moose.lua from your drive. Edit the link to a fitting location.
* Once the mission is started an Moose is loaded, use the F10 menu to load the file itself. 
* Apart from the class itself, the file contains the below setup at the end for a test mission.
* Watch the dcs.log with Notepad++ or the like for errors.

      local BlueCsar = CSAR:New(coalition.side.BLUE,"Downed Pilot","Luftrettung")
      BlueCsar.csarOncrash = true
      BlueCsar:__Start(5)
     
