# CSAR_MOOSE (BETA Testing)
Refactoring Ciribob's excellent CSAR script into Moose as object-oriented FSM

## Testing
* You need a late activated infantry group ("Downed Pilot" below) to stand in for the actual pilot. 
* Setup is currently in lines 186ff of this file, or you can use `myCSAR.<setting> = <value>` after instantiating the object.
* Test mission setup  - the test missions contains a trigger to load the CSAR_Moose.lua from your drive. Edit the link to a fitting location.
* Once the mission is started and Moose is loaded, use the F10 menu to load the file itself. 
* Apart from the class itself, the file contains the below setup at the end for a test mission.
* Watch the dcs.log with Notepad++ or the like for errors.

      local BlueCsar = CSAR:New(coalition.side.BLUE,"Downed Pilot","Luftrettung")
      BlueCsar.csarOncrash = true
      BlueCsar:__Start(5)
     
* Available options/defaults currently are:

        self.csarOncrash = true -- If set to true, will generate a csar when a plane crashes as well.
        self.allowDownedPilotCAcontrol = false -- Set to false if you don't want to allow control by Combined arms.
        self.enableForAI = true -- set to false to disable AI units from being rescued.
        self.smokecolor = 4 -- Color of smokemarker for blue side, 0 is green, 1 is red, 2 is white, 3 is orange and 4 is blue
        self.coordtype = 1 -- Use Lat/Long DDM (0), Lat/Long DMS (1), MGRS (2), Bullseye imperial (3) or Bullseye metric (4) for coordinates.
        self.immortalcrew = true -- Set to true to make wounded crew immortal
        self.invisiblecrew = false -- Set to true to make wounded crew insvisible 
        self.messageTime = 30 -- Time to show longer messages for in seconds 
        self.pilotRuntoExtractPoint = true -- Downed Pilot will run to the rescue helicopter up to self.extractDistance METERS 
        self.loadDistance = 75 -- configure distance for pilot to get in helicopter in meters.
        self.extractDistance = 500 -- Distance the Downed pilot will run to the rescue helicopter
        self.loadtimemax = 135 -- seconds
        self.radioSound = "beacon.ogg" -- the name of the sound file to use for the Pilot radio beacons. If this isnt added to the mission BEACONS WONT WORK!
        self.allowFARPRescue = true --allows pilot to be rescued by landing at a FARP or Airbase
        self.max_units = 6 --number of pilots that can be carried
        self.useprefix = true  -- Use the Prefixed defined below, Requires Unit have the Prefix defined below 
        self.csarPrefix = { "helicargo", "MEDEVAC"} -- prefixes used for useprefix=true
        self.template = Template or "generic" -- template for downed pilot
        self.mashprefix = {"MASH"} -- prefixes used to find MASHes (#GROUP Objects)
        self.autosmoke = false -- automatically smoke location when heli is near
        
* Known Issues

      * Takes >1min to board > 1 pilot

* To test

      * Hover boarding
      * Rescue on landing at/close to Airbase
