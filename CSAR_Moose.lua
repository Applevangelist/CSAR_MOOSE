--- **Ops** - Combat Search and Rescue.
--
-- **Main Features:**
--
--    * tbd
--
-- ===
--
-- ### Author: **Applevangelist**
-- @module Ops.CSAR
-- @image OPS_CSAR.png


--- CSAR class.
-- @type CSAR
-- @field #string ClassName Name of the class.
-- @field #number verbose Verbosity level.
-- @field #string lid Class id string for output to DCS log file.
-- @field #number coalition Coalition side number, e.g. `coalition.side.RED`.
-- @extends Core.Fsm#FSM

--- Top of Documentatuion
--
-- ===
--
-- ![Banner Image](..\path\to\CSAR_Main.jpg)
--
-- # The CSAR Concept
-- 
--  * Object oriented refactoring of Ciribob's fantastic CSAR script.
-- 
-- # Basic Usage 
--
--  ## subheadline  
--  
--
-- @field #CSAR
CSAR = {
  ClassName       = "CSAR",
  verbose         =     2,
  lid             =   "",
  coalition       = 1,
  coalitiontxt    = "blue",
  FreeVHFFrequencies = {},
  UsedVHFFrequencies = {},
  takenOff = {},
  csarUnits = {},  -- table of unit names
  downedPilots = {},
  woundedGroups = {},
  landedStatus = {},
  addedTo = {},
  woundedGroups = {}, -- contains the new group of units
  inTransitGroups = {}, -- contain a table for each SAR with all units he has with the original names
  smokeMarkers = {}, -- tracks smoke markers for groups
  heliVisibleMessage = {}, -- tracks if the first message has been sent of the heli being visible
  heliCloseMessage = {}, -- tracks heli close message  ie heli < 500m distance
  max_units = 6, --number of pilots that can be carried
  hoverStatus = {}, -- tracks status of a helis hover above a downed pilot
  pilotDisabled = {}, -- tracks what aircraft a pilot is disabled for
  pilotLives = {}, -- tracks how many lives a pilot has
  useprefix    = true,  -- Use the Prefixed defined below, Requires Unit have the Prefix defined below 
  csarPrefix = {},
  template = nil,
  bluemash = {},
  smokecolor = 4,
  rescues = 0,
}

--- Downed pilots info.
-- @type CSAR.DownedPilot
-- @field #number index Pilot index.
-- @field #string name Name of the spawned group.
-- @field #number side Coalition.
-- @field #string originalUnit Name of the original unit.
-- @field #string desc Description.
-- @field #string typename Typename of Unit.
-- @field #number frequency Frequency of the NDB.
-- @field #string player Player name if applicable.
-- @field Wrapper.Group#GROUP group Spawned group object.
  
--- Known beacons from the available maps
-- @field #CSAR.SkipFrequencies
CSAR.SkipFrequencies = {
  745,381,384,300.50,312.5,1175,342,735,300.50,353.00,
  440,795,525,520,690,625,291.5,300.50,
  435,309.50,920,1065,274,312.50,
  580,602,297.50,750,485,950,214,
  1025,730,995,455,307,670,329,395,770,
  380,705,300.5,507,740,1030,515,330,309.5,348,462,905,352,1210,942,435,
  324,320,420,311,389,396,862,680,297.5,920,662,866,907,309.5,822,515,470,342,1182,309.5,720,528,
  337,312.5,830,740,309.5,641,312,722,682,1050,
  1116,935,1000,430,577,540,550,560,570,
  }
 
--- All slot / Limit settings
-- @field #CSAR.aircraftType
CSAR.aircraftType = {} -- Type and limit
CSAR.aircraftType["SA342Mistral"] = 2
CSAR.aircraftType["SA342Minigun"] = 2
CSAR.aircraftType["SA342L"] = 4
CSAR.aircraftType["SA342M"] = 4
CSAR.aircraftType["UH-1H"] = 4
CSAR.aircraftType["Mi-8MT"] = 8 
CSAR.aircraftType["Mi-24"] = 8 

--- CSAR class version.
-- @field #string version
CSAR.version="0.0.1b13"

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- ToDo list
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- TODO: Everyting
-- WONTDO: Slot blocker etc

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constructor
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Create a new CSAR object and start the FSM.
-- @param #CSAR self
-- @param #number Coalition Coalition side. Can also be passed as a string "red", "blue" or "neutral".
-- @param #string Template Name of the late activated infantry unit standing in for the downed pilot.
-- @param #string Alias An *optional* alias how this object is called in the logs etc.
-- @return #CSAR self
function CSAR:New(Coalition, Template, Alias)
  
  -- Inherit everything from FSM class.
  local self=BASE:Inherit(self, FSM:New()) -- #CSAR
  
  --set Coalition
  if Coalition and type(Coalition)=="string" then
    if Coalition=="blue" then
      self.coalition=coalition.side.BLUE
      self.coalitiontxt = Coalition
    elseif Coalition=="red" then
      self.coalition=coalition.side.RED
      self.coalitiontxt = Coalition
    elseif Coalition=="neutral" then
      self.coalition=coalition.side.NEUTRAL
      self.coalitiontxt = Coalition
    else
      self:E("ERROR: Unknown coalition in CSAR!")
    end
  else
    self.coalition = Coalition
  end
  
  -- Set alias.
  if Alias then
    self.alias=tostring(Alias)
  else
    self.alias="Red Cross"  
    if self.coalition then
      if self.coalition==coalition.side.RED then
        self.alias="Спасение"
      elseif self.coalition==coalition.side.BLUE then
        self.alias="CSAR"
      end
    end
  end
  
  -- Set some string id for output to DCS.log file.
  self.lid=string.format("%s (%s) | ", self.alias, self.coalition and UTILS.GetCoalitionName(self.coalition) or "unknown")
  
  -- Start State.
  self:SetStartState("Stopped")

  -- Add FSM transitions.
  --                 From State  -->   Event        -->     To State
  self:AddTransition("Stopped",       "Start",              "Running")     -- Start FSM.
  self:AddTransition("*",             "Status",             "*")           -- CSAR status update.
  self:AddTransition("*",             "PilotDown",          "*")          -- Downed Pilot added
  self:AddTransition("*",             "Approach",           "*")         -- CSAR heli closing in.
  self:AddTransition("*",             "Boarded",            "*")          -- Pilot boarded.
  self:AddTransition("*",             "Returning",          "*")        -- CSAR returning to base.
  self:AddTransition("*",             "Rescued",            "*")          -- Pilot at MASH.
  self:AddTransition("*",             "Stop",               "Stopped")     -- Stop FSM.

  -- tables, mainly for tracking actions
  self.addedTo = {}
  self.allheligroupset = {} -- GROUP_SET of all helis
  self.csarUnits = {} -- table of CSAR unit names
  self.FreeVHFFrequencies = {}
  self.heliVisibleMessage = {} -- tracks if the first message has been sent of the heli being visible
  self.heliCloseMessage = {} -- tracks heli close message  ie heli < 500m distance
  self.hoverStatus = {} -- tracks status of a helis hover above a downed pilot
  self.inTransitGroups = {} -- contain a table for each SAR with all units he has with the original names
  self.landedStatus = {}
  self.lastCrash = {}
  self.takenOff = {}
  self.smokeMarkers = {} -- tracks smoke markers for groups
  self.UsedVHFFrequencies = {}
  self.woundedGroups = {} -- contains the new group of units
  self.downedPilots = {} -- Replacement woundedGroups
  self.downedpilotcounter = 1
  
  -- settings, counters etc
  self.rescues = 0 -- counter for successful rescue landings at FARP/AFB/MASH
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
  self.csarPrefix = { "helicargo", "MEDEVAC"} -- prefixes used for useprefix=true - DON'T use # in names!
  self.template = Template or "generic" -- template for downed pilot
  self.mashprefix = {"MASH"} -- prefixes used to find MASHes
  self.bluemash = SET_GROUP:New():FilterCoalitions(self.coalition):FilterPrefixes(self.mashprefix):FilterOnce() -- currently only GROUP objects, maybe support STATICs also?
  self.autosmoke = false -- automatically smoke location when heli is near
  
  ------------------------
  --- Pseudo Functions ---
  ------------------------
  
    --- Triggers the FSM event "Start". Starts the CSAR. Initializes parameters and starts event handlers.
  -- @function [parent=#CSAR] Start
  -- @param #CSAR self

  --- Triggers the FSM event "Start" after a delay. Starts the CSAR. Initializes parameters and starts event handlers.
  -- @function [parent=#CSAR] __Start
  -- @param #CSAR self
  -- @param #number delay Delay in seconds.

  --- Triggers the FSM event "Stop". Stops the CSAR and all its event handlers.
  -- @param #CSAR self

  --- Triggers the FSM event "Stop" after a delay. Stops the CSAR and all its event handlers.
  -- @function [parent=#CSAR] __Stop
  -- @param #CSAR self
  -- @param #number delay Delay in seconds.

  --- Triggers the FSM event "Status".
  -- @function [parent=#CSAR] Status
  -- @param #CSAR self

  --- Triggers the FSM event "Status" after a delay.
  -- @function [parent=#CSAR] __Status
  -- @param #CSAR self
  -- @param #number delay Delay in seconds.
  
  --- On After "PilotDown" event. Downed Pilot detected.
  -- @function [parent=#CSAR] OnAfterPilotDown
  -- @param #CSAR self
  -- @param #string From From state.
  -- @param #string Event Event.
  -- @param #string To To state.
  -- @param Wrapper.Group#GROUP Group Group object of the downed pilot.
  -- @param #number Frequency Beacon frequency in kHz.
  -- @param #string Leadername Name of the #UNIT of the downed pilot.
  -- @param #string CoordinatesText String of the position of the pilot. Format determined by self.coordtype.
  
  --- On After "Aproach" event. Heli close to downed Pilot.
  -- @function [parent=#CSAR] OnAfterApproach
  -- @param #CSAR self
  -- @param #string From From state.
  -- @param #string Event Event.
  -- @param #string To To state.
  -- @param #string Heliname Name of the helicopter group.
  -- @param #string Woundedgroupname Name of the downed pilot's group.
  
    --- On After "Boarded" event. Downed pilot boarded heli.
  -- @function [parent=#CSAR] OnAfterBoarded
  -- @param #CSAR self
  -- @param #string From From state.
  -- @param #string Event Event.
  -- @param #string To To state.
  -- @param #string Heliname Name of the helicopter group
  -- @param #string Woundedgroupname Name of the downed pilot's group

    --- On After "Returning" event. Heli can return home with downed pilot(s).
  -- @function [parent=#CSAR] OnAfterReturning
  -- @param #CSAR self
  -- @param #string From From state.
  -- @param #string Event Event.
  -- @param #string To To state.
  -- @param #string Heliname Name of the helicopter group
  -- @param #string Woundedgroupname Name of the downed pilot's group
  
    --- On After "Rescued" event. Pilot(s) have been brought to the MASH/FARP/AFB.
  -- @function [parent=#CSAR] OnAfterRescued
  -- @param #CSAR self
  -- @param #string From From state.
  -- @param #string Event Event.
  -- @param #string To To state.
  -- @param Wrapper.Unit#UNIT HeliUnit Unit of the helicopter
  -- @param #string HeliName Name of the helicopter group
  
  return self
end

------------------------
--- Helper Functions ---
------------------------

--- Function to insert downed pilot tracker object.
-- @param #CSAR self
-- @param Wrapper.Group#GROUP Group The #GROUP object
-- @param #string Groupname Name of the spawned group.
-- @param #number Side Coalition.
-- @param #string OriginalUnit Name of original Unit.
-- @param #string Description Descriptive text.
-- @param #string Typename Typename of unit.
-- @param #number Frequency Frequency of the NDB in Hz
-- @param #string Playername Name of Player (if applicable)
-- @return #CSAR self.
function CSAR:_CreateDownedPilotTrack(Group,Groupname,Side,OriginalUnit,Description,Typename,Frequency,Playername)
  self:I({"_CreateDownedPilotTrack",Groupname,Side,OriginalUnit,Description,Typename,Frequency,Playername})
  
  -- create new entry
  local DownedPilot = {} -- #CSAR.DownedPilot
  DownedPilot.desc = Description or ""
  DownedPilot.frequency = Frequency or 0
  DownedPilot.index = self.downedpilotcounter
  DownedPilot.name = Groupname or ""
  DownedPilot.originalUnit = OriginalUnit or ""
  DownedPilot.player = Playername or ""
  DownedPilot.side = Side or 0
  DownedPilot.typename = Typename or ""
  DownedPilot.group = Group
  
  -- Add Pilot
  local PilotTable = self.downedPilots
  local counter = self.downedpilotcounter
  PilotTable[counter] = {}
  PilotTable[counter] = DownedPilot
  --self.downedPilots[self.downedpilotcounter]=DownedPilot
  self:I({Table=PilotTable})
  self.downedPilots = PilotTable
  -- Increase counter
  self.downedpilotcounter = self.downedpilotcounter+1
end

--- Count pilots on board.
-- @param #CSAR self
-- @param #string _heliName
-- @return #number count  
function CSAR:_PilotsOnboard(_heliName)
  self:T(self.lid .. " _PilotsOnboard")
 local count = 0
  if self.inTransitGroups[_heliName] then
      for _, _group in pairs(self.inTransitGroups[_heliName]) do
          count = count + 1
      end
  end
  return count
end

--- Function to check for dupe eject events.
-- @param #CSAR self
-- @param #string _unitname Name of unit.
-- @return #boolean Outcome
function CSAR:_DoubleEjection(_unitname)

    if self.lastCrash[_unitname] then
        local _time = self.lastCrash[_unitname]

        if timer.getTime() - _time < 10 then
            self:E(self.lid.."Caught double ejection!")
            return true
        end
    end

    self.lastCrash[_unitname] = timer.getTime()
    return false
end

--- Spawn a downed pilot
-- @param #CSAR self
-- @param #number country Country for template.
-- @param Core.Point#COORDINATE point Coordinate to spawn at.
-- @return Wrapper.Group#GROUP group The #GROUP object.
-- @return #string alias The alias name.
function CSAR:_SpawnPilotInField(country,point)
  self:T({country,point})
  local template = self.template
  local alias = string.format("Downed Pilot-%d",math.random(1,10000))
  local coalition = self.coalition
  local pilotcacontrol = self.allowDownedPilotCAcontrol -- is this correct?
  local _spawnedGroup = SPAWN
    :NewWithAlias(template,alias)
    :InitCoalition(coalition)
    :InitCountry(country)
    --:InitAIOnOff(pilotcacontrol)
    :InitDelayOff()
    :SpawnFromCoordinate(point)
  
  --return object
  return _spawnedGroup, alias -- Wrapper.Group#GROUP object
end

--- Add options to a downed pilot
-- @param #CSAR self
-- @param Wrapper.Group#GROUP group Group to use.
function CSAR:_AddSpecialOptions(group)
  self:I(self.lid.." _AddSpecialOptions")
  self:T({group})
  
  local immortalcrew = self.immortalcrew
  local invisiblecrew = self.invisiblecrew
  if immortalcrew then
    local _setImmortal = {
        id = 'SetImmortal',
        params = {
            value = true
        }
    }
    group:SetCommand(_setImmortal)
  end

  if invisiblecrew then
    -- invisible
    local _setInvisible = {
        id = 'SetInvisible',
        params = {
            value = true
        }
    }
    group:SetCommand(_setInvisible) 
  end
  
  group:OptionAlarmStateGreen()
  group:OptionROEHoldFire()

end

--- Function to spawn a CSAR object into the scene.
-- @param #CSAR self
-- @param #number _coalition Coalition
-- @param DCS#country.id _country Country ID
-- @param Core.Point#COORDINATE _point Coordinate
-- @param #string _typeName Typename
-- @param #string _unitName Unitname
-- @param #string _playerName Playername
-- @param #number _freq Frequency
-- @param #boolean noMessage 
-- @param #string _description Description
function CSAR:_AddCsar(_coalition , _country, _point, _typeName, _unitName, _playerName, _freq, noMessage, _description )
  self:I(self.lid .. " _AddCsar")
  self:I({_coalition , _country, _point, _typeName, _unitName, _playerName, _freq, noMessage, _description})
  -- local _spawnedGroup = self:_SpawnGroup( _coalition, _country, _point, _typeName )
  local template = self.template
  local alias = string.format("Downed Pilot-%d",math.random(1,10000))
  local immortalcrew = self.immortalcrew
  local invisiblecrew = self.invisiblecrew
  local _spawnedGroup, _alias = self:_SpawnPilotInField(_country,_point)
  local _typeName = _typeName or "PoW"
  if not noMessage then
    local m = MESSAGE:New("MAYDAY MAYDAY! " .. _typeName .. " is down. ",10,"INFO"):ToCoalition(self.coalition)
  end
  
  if not _freq then
    _freq = self:_GenerateADFFrequency()
    if not _freq then _freq = "333.25" end --noob catch
  end 
  
  if _freq then
    self:_AddBeaconToGroup(_spawnedGroup, _freq)
  end
  
  self:_AddSpecialOptions(_spawnedGroup)
  -- Generate DESCRIPTION text
  local _text = " "
  if _playerName ~= nil then
      _text = "Pilot " .. _playerName .. " of " .. _unitName .. " - " .. _typeName
  elseif _typeName ~= nil then
      _text = "AI Pilot of " .. _unitName .. " - " .. _typeName
  else
      _text = _description
  end
  
  
  self:T({_spawnedGroup, _alias})
  
  local _GroupName = _spawnedGroup:GetName() or _alias
  --local _GroupStructure = { side = _coalition, originalUnit = _unitName, desc = _text, typename = _typeName, frequency = _freq, player = _playerName }
  --self.woundedGroups[_GroupName]=_GroupStructure
  self:_CreateDownedPilotTrack(_spawnedGroup,_GroupName,_coalition,_unitName,_text,_typeName,_freq,_playerName)
  
  --self.woundedGroups[_spawnedGroup:GetName()] = { side = _coalition, originalUnit = _unitName, desc = _text, typename = _typeName, frequency = _freq, player = _playerName } 
  self:_InitSARForPilot(_spawnedGroup, _GroupName, _freq, noMessage)
  
end

--- Function to add a CSAR object into the scene at a zone coordinate. For mission designers wanting to add e.g. PoWs to the scene.
-- @param #CSAR self
-- @param #string _zone Name of the zone.
-- @param #number _coalition Coalition.
-- @param #string _description Description.
-- @param #boolean _randomPoint Random yes or no.
-- @param #boolean _nomessage If nil or false, don't send a message to SAR.
function CSAR:_SpawnCsarAtZone( _zone, _coalition, _description, _randomPoint, _nomessage)
  self:I(self.lid .. " _SpawnCsarAtZone")
  local freq = self:_GenerateADFFrequency()
  local _triggerZone = ZONE:New(_zone) -- trigger to use as reference position
  if _triggerZone == nil then
    self:E("Csar.lua ERROR: Cant find zone called " .. _zone, 10)
    return
  end
  
  local pos = {}
  if _randomPoint then
    local _pos =  _triggerZone:GetRandomPointVec3()
    pos = COORDINATE:NewFromVec3(_pos)
  else
    pos  = _triggerZone:GetCoordinate()
  end
  
  local _country = 0
  if _coalition == coalition.side.BLUE then
    _country = country.id.USA
  elseif _coalition == coalition.side.RED then
    _country = country.id.RUSSIA
  else
    _country = country.id.UN_PEACEKEEPERS
  end
  
  self:_AddCsar(_coalition, _country, pos, "PoW", "Unknown", nil, freq, _nomessage, _description)
end

-- TODO: Split in functions per Event type
--- Event handler.
-- @param #CSAR self
function CSAR:_EventHandler(EventData)
  self:I(self.lid .. " _EventHandler")
  self:T({Event = EventData.id})
  
  local _event = EventData -- Core.Event#EVENTDATA
  
  -- no event  
  if _event == nil or _event.initiator == nil then
    return false
  
  -- take off
  elseif _event.id == EVENTS.Takeoff then -- taken off
    self:I(self.lid .. " Event unit - Takeoff")
      
    local _coalition = _event.IniCoalition
    if _coalition ~= self.coalition then
        return --ignore!
    end
      
    if _event.IniGroupName then
        self.takenOff[_event.IniUnitName] = true
    end
    
    return true
  
  -- player enter unit
  elseif _event.id == EVENTS.PlayerEnterAircraft or _event.id == EVENTS.PlayerEnterUnit then --player entered unit
    self:I(self.lid .. " Event unit - Player Enter")
    
    local _coalition = _event.IniCoalition
    if _coalition ~= self.coalition then
        return --ignore!
    end
    
    if _event.IniPlayerName then
        self.takenOff[_event.IniPlayerName] = nil
    end
    
  -- if its a sar heli, re-add check status script
    for _, _heliName in pairs(self.csarUnits) do    
        if _heliName == _event.IniPlayerName then
            -- add back the status script
            local DownedPilotTable = self.downedPilots
            for _, _groupInfo in pairs(DownedPilotTable) do  -- #CSAR.DownedPilot
                if _groupInfo.side == _event.IniCoalition then
                    local _woundedName = _groupInfo.name
                    self:_CheckWoundedGroupStatus(_heliName,_woundedName)
                end
            end
        end
    end
    
    return true
  
  elseif (_event.id == EVENTS.PilotDead and self.csarOncrash == false) then
      -- Pilot dead
  
      self:I(self.lid .. " Event unit - Pilot Dead")
  
      local _unit = _event.IniUnit
      local _unitname = _event.IniUnitName
      local _group = _event.IniGroup
      
      if _unit == nil then
          return -- error!
      end
  
      local _coalition = _event.IniCoalition
      if _coalition ~= self.coalition then
          return --ignore!
      end
  
      -- Catch multiple events here?
      if self.takenOff[_event.IniUnitName] == true or _group:IsAirborne() then
          if self:_DoubleEjection(_unitname) then
            return
          end
          
          local m = MESSAGE:New("MAYDAY MAYDAY! " .. _unit:GetTypeName() .. " shot down. No Chute!",10,"Info"):ToCoalition(self.coalition)
          -- self:_HandleEjectOrCrash(_unit, true)
      else
          self:I(self.lid .. " Pilot has not taken off, ignore")
      end
  
      return
  
  elseif _event.id == EVENTS.PilotDead or _event.id == EVENTS.Ejection then
      if _event.id == EVENTS.PilotDead and self.csarOncrash == false then 
          return     
      end
      self:I(self.lid .. " Event unit - Pilot Ejected")
  
      local _unit = _event.IniUnit
      local _unitname = _event.IniUnitName
      local _group = _event.IniGroup
      
      if _unit == nil then
          return -- error!
      end
  
      local _coalition = _unit:GetCoalition() 
      if _coalition ~= self.coalition then
          return --ignore!
      end
   
      if self.enableForAI == false and _event.IniPlayerName == nil then
          return
      end

      if not self.takenOff[_event.IniUnitName] and not _group:IsAirborne() then
          self:I(self.lid .. " Pilot has not taken off, ignore")
          return -- give up, pilot hasnt taken off
      end
      
      if self:_DoubleEjection(_unitname) then
        return
      end
          
      local _freq = self:_GenerateADFFrequency()
       self:_AddCsar(_coalition, _unit:GetCountry(), _unit:GetCoordinate()  , _unit:GetTypeName(),  _unit:GetName(), _event.IniPlayerName, _freq, false, 0)
       
      return true
  
  elseif _event.id == EVENTS.Land then
      self:I(self.lid .. " Landing")
      
      if _event.IniUnitName then
          self.takenOff[_event.IniUnitName] = nil
      end
  
      if self.allowFARPRescue then
          
          local _unit = _event.IniUnit  -- Wrapper.Unit#UNIT
          --local _unit = _event.initiator
  
          if _unit == nil then
              self:I(self.lid .. " Unit nil on landing")
              return -- error!
          end
          
          local _coalition = _event.IniCoalition
          if _coalition ~= self.coalition then
              return --ignore!
          end
          
          self.takenOff[_event.IniUnitName] = nil
 
          local _place = _event.Place -- Wrapper.Airbase#AIRBASE
  
          if _place == nil then
              self:I(self.lid .. " Landing Place Nil")
              return -- error!
          end
   
          if _place:GetCoalition() == self.coalition or _place:GetCoalition() == coalition.side.NEUTRAL then
              self:_RescuePilots(_unit)  
          else
              self:I(string.format("Airfield %d, Unit %d", _place:GetCoalition(), _unit:GetCoalition()))
              end
          end
  
          return true
      end

end

--- Initialize the action for a pilot.
-- @param #CSAR self
-- @param Wrapper.Group#GROUP _downedGroup The group to rescue.
-- @param #string _GroupName Name of the Group
-- @param #number _freq Beacon frequency.
-- @param #boolean _nomessage Send message true or false.
function CSAR:_InitSARForPilot(_downedGroup, _GroupName, _freq, _nomessage)
  self:I(self.lid .. " _InitSARForPilot")
  local _leader = _downedGroup:GetUnit(1)
  --local _groupName = _downedGroup:GetName()
  local _groupName = _GroupName
  local _freqk = _freq / 1000
  local _coordinatesText = self:_GetPositionOfWounded(_downedGroup)
  local _leadername = _leader:GetName()
  
  if not _nomessage then
    local _text = string.format("%s requests SAR at %s, beacon at %.2f KHz", _leadername, _coordinatesText, _freqk) 
    self:_DisplayToAllSAR(_text)
  end
  
  for _,_heliName in pairs(self.csarUnits) do
    self:_CheckWoundedGroupStatus(_heliName, _groupName)
  end

   -- trigger FSM event
  self:__PilotDown(2,_downedGroup, _freqk, _leadername, _coordinatesText)
end

--- Check if a name is in downed pilot table
-- @param #CSAR self
-- @param #string name Name to search for.
-- @return #boolean Outcome.
-- @return #CSAR.DownedPilot Table if found else nil.
function CSAR:_CheckNameInDownedPilots(name)
  local PilotTable = self.downedPilots --#CSAR.DownedPilot
  local found = false
  local table = nil
  for _,_pilot in pairs(PilotTable) do
    if _pilot.name == name then
      found = true
      table = _pilot
      break
    end  
  end
  return found, table
end

--- Check if a name is in downed pilot table and remove it.
-- @param #CSAR self
-- @param #string name Name to search for.
-- @return #boolean Outcome.
function CSAR:_RemoveNameFromDownedPilots(name)
  local PilotTable = self.downedPilots --#CSAR.DownedPilot
  local found = false
  for _,_pilot in pairs(PilotTable) do
    if _pilot.name == name then
    local group = _pilot.group -- Wrapper.Group#GROUP
    if not group:IsAlive() then -- don't delete groups which still exist
      found = true
      _pilot.desc = nil
      _pilot.frequency = nil
      _pilot.index = nil
      _pilot.name = nil
      _pilot.originalUnit = nil
      _pilot.player = nil
      _pilot.side = nil
      _pilot.typename = nil
      _pilot.group = nil
    end
   end
  end
  return found
end

--- Check state of wounded group.
-- @param #CSAR self
-- @param #string heliname heliname
-- @param #string woundedgroupname woundedgroupname
function CSAR:_CheckWoundedGroupStatus(heliname,woundedgroupname)
  self:I(self.lid .. " _CheckWoundedGroupStatus")
  local _heliName = heliname
  local _woundedGroupName = woundedgroupname
  self:I({Heli = _heliName, Downed  = _woundedGroupName})
  -- if wounded group is not here then message alread been sent to SARs
  -- stop processing any further
  local _found, _downedpilot = self:_CheckNameInDownedPilots(_woundedGroupName)
  if not _found then
    self:I("...not found in list!")
    return
  end
  
  --local _woundedGroup = self:_GetWoundedGroup(_woundedGroupName)
  --local _woundedGroup = GROUP:FindByName(_woundedGroupName) -- Wrapper.Group#GROUP
  local _woundedGroup = _downedpilot.group 
  local _heliUnit = self:_GetSARHeli(_heliName) -- Wrapper.Unit#UNIT
  
  local _woundedLeader = _woundedGroup:GetUnit(1) -- Wrapper.Unit#UNIT
  local _lookupKeyHeli = _heliName .. "_" .. _woundedLeader:GetID() --lookup key for message state tracking
          
  if _heliUnit == nil then
    self.heliVisibleMessage[_lookupKeyHeli] = nil
    self.heliCloseMessage[_lookupKeyHeli] = nil
    self.landedStatus[_lookupKeyHeli] = nil
    self:I("...helinunit nil!")
    return
  end

  --if self:_CheckGroupNotKIA(_woundedGroup, _woundedGroupName, _heliUnit, _heliName) then
  if _woundedGroup:IsAlive() then
    local _heliCoord = _heliUnit:GetCoordinate()
    local _leaderCoord = _woundedLeader:GetCoordinate()
    local _distance = self:_GetDistance(_heliCoord,_leaderCoord)
    if _distance < 3000 then
      if self:_CheckCloseWoundedGroup(_distance, _heliUnit, _heliName, _woundedGroup, _woundedGroupName) == true then
        -- we're close, reschedule
        self:__Approach(-5,heliname,woundedgroupname)
      end
    else
      self.heliVisibleMessage[_lookupKeyHeli] = nil
      --reschedule as units aren't dead yet , schedule for a bit slower though as we're far away
      self:__Approach(-10,heliname,woundedgroupname)
    end
  else
  self:I("...Downed Pilot KIA?!")
  self:_RemoveNameFromDownedPilots(_downedpilot.name)
  end
end

--- Function to pop a smoke at a wounded pilot's positions.
-- @param #CSAR self
-- @param #string _woundedGroupName Name of the group.
-- @param Wrapper.Group#GROUP _woundedLeader Object of the group.
function CSAR:_PopSmokeForGroup(_woundedGroupName, _woundedLeader)
  self:T(self.lid .. " _PopSmokeForGroup")
  -- have we popped smoke already in the last 5 mins
  local _lastSmoke = self.smokeMarkers[_woundedGroupName]
  if _lastSmoke == nil or timer.getTime() > _lastSmoke then
  
      local _smokecolor = self.smokecolor
      local _smokecoord = _woundedLeader:GetCoordinate()
      _smokecoord:Smoke(_smokecolor)
      self.smokeMarkers[_woundedGroupName] = timer.getTime() + 300 -- next smoke time
  end
end

--- Function to pickup the wounded pilot from the ground.
-- @param #CSAR self
-- @param Wrapper.Unit#UNIT _heliUnit Object of the group.
-- @param #string _pilotName Name of the pilot.
-- @param Wrapper.Group#GROUP _woundedGroup Object of the group.
-- @param #string _woundedGroupName Name of the group.
function CSAR:_PickupUnit(_heliUnit, _pilotName, _woundedGroup, _woundedGroupName)
  self:I(self.lid .. " _PickupUnit")
  local _woundedLeader = _woundedGroup:GetUnit(1)
  
  -- GET IN!
  local _heliName = _heliUnit:GetName()
  local _groups = self.inTransitGroups[_heliName]
  local _unitsInHelicopter = self:_PilotsOnboard(_heliName)
  
  -- init table if there is none for this helicopter
  if not _groups then
      self.inTransitGroups[_heliName] = {}
      _groups = self.inTransitGroups[_heliName]
  end
  
  -- if the heli can't pick them up, show a message and return
  local _maxUnits = self.aircraftType[_heliUnit:GetTypeName()]
  if _maxUnits == nil then
    _maxUnits = self.max_units
  end
  if _unitsInHelicopter + 1 > _maxUnits then
      self:_DisplayMessageToSAR(_heliUnit, string.format("%s, %s. We're already crammed with %d guys! Sorry!", _pilotName, _heliName, _unitsInHelicopter, _unitsInHelicopter), 10)
      return true
  end
  
  local found,downedgrouptable = self:_CheckNameInDownedPilots(_woundedGroupName)
  self.inTransitGroups[_heliName][_woundedGroupName] = downedgrouptable or {}
  --[[
  {
      -- TODO: Fix with #CSAR.DownedPilot
      originalUnit = self.woundedGroups[_woundedGroupName].originalUnit,
      woundedGroup = _woundedGroupName,
      side = self.coalition,
      desc = self.woundedGroups[_woundedGroupName].desc,
      player = self.woundedGroups[_woundedGroupName].player,
  }
  --]]
  _woundedLeader:Destroy()
  
  self:_DisplayMessageToSAR(_heliUnit, string.format("%s: %s I'm in! Get to the MASH ASAP! ", _heliName, _pilotName), 10)
  
  self:__Boarded(5,_heliName,_woundedGroupName)
  
  return true
end

--- Move group to destination.
-- @param #CSAR self
-- @param Wrapper.Group#GROUP _leader
-- @param Core.Point#COORDINATE _destination
function CSAR:_OrderGroupToMoveToPoint(_leader, _destination)
  self:I(self.lid .. " _OrderGroupToMoveToPoint")
  local group = _leader
  local coordinate = _destination:GetVec2()
  --group:RouteGroundTo(_destination,5,"Vee",5)
  group:RouteToVec2(coordinate,2)
end

--- Function to check if heli is close to group.
-- @param #CSAR self
-- @param #number _distance
-- @param Wrapper.Unit#UNIT _heliUnit
-- @param #string _heliName
-- @param Wrapper.Group#GROUP _woundedGroup
-- @param #string _woundedGroupName
-- @return #boolean Outcome
function CSAR:_CheckCloseWoundedGroup(_distance, _heliUnit, _heliName, _woundedGroup, _woundedGroupName)
  self:I(self.lid .. " _CheckCloseWoundedGroup")
  local _woundedLeader = _woundedGroup:GetUnit(1) -- Wrapper.Unit#UNIT
  local _lookupKeyHeli = _heliUnit:GetName() .. "_" .. _woundedLeader:GetID() --lookup key for message state tracking
  
  local _found, _pilotable = self:_CheckNameInDownedPilots(_woundedGroupName) -- #boolean, #CSAR.DownedPilot
  local _pilotName = _pilotable.desc
  --local _pilotName = self.woundedGroups[_woundedGroupName].desc
  --local _pilotName = _woundedGroup:GetName()
  
  local _reset = true
  
  if self.autosmoke == true then
      self:_PopSmokeForGroup(_woundedGroupName, _woundedLeader)
  end
  
  if self.heliVisibleMessage[_lookupKeyHeli] == nil then
      if self.autosmoke == true then
        self:_DisplayMessageToSAR(_heliUnit, string.format("%s: %s. I hear you! Damn, that thing is loud! Land or hover by the smoke.", _heliName, _pilotName), self.messageTime)
      else
        self:_DisplayMessageToSAR(_heliUnit, string.format("%s: %s. I hear you! Damn, that thing is loud! Request a Flare or Smoke if you need", _heliName, _pilotName), self.messageTime)
      end
      --mark as shown for THIS heli and THIS group
      self.heliVisibleMessage[_lookupKeyHeli] = true
  end
  
  if (_distance < 500) then
  
      if self.heliCloseMessage[_lookupKeyHeli] == nil then
          if self.autosmoke == true then
            self:_DisplayMessageToSAR(_heliUnit, string.format("%s: %s. You're close now! Land or hover at the smoke.", _heliName, _pilotName), 10)
          else
            self:_DisplayMessageToSAR(_heliUnit, string.format("%s: %s. You're close now! Land in a safe place, I will go there ", _heliName, _pilotName), 10)
          end
          --mark as shown for THIS heli and THIS group
          self.heliCloseMessage[_lookupKeyHeli] = true
      end
  
      -- have we landed close enough?
      if not _heliUnit:InAir() then
  
          -- if you land on them, doesnt matter if they were heading to someone else as you're closer, you win! :)
        if self.pilotRuntoExtractPoint == true then
            if (_distance < self.extractDistance) then
              local _time = self.landedStatus[_lookupKeyHeli]
              if _time == nil then
                  --self.displayMessageToSAR(_heliUnit, "Landed at " .. _distance, 10, true)
                  self.landedStatus[_lookupKeyHeli] = math.floor( (_distance * self.loadtimemax ) / self.extractDistance )   
                  _time = self.landedStatus[_lookupKeyHeli] 
                  self:_OrderGroupToMoveToPoint(_woundedGroup, _heliUnit:GetCoordinate())
                  self:_DisplayMessageToSAR(_heliUnit, "Wait till " .. _pilotName .. ". Gets in \n" .. _time .. " more seconds.", 10, true)
              else
                  _time = self.landedStatus[_lookupKeyHeli] - 1
                  self.landedStatus[_lookupKeyHeli] = _time
              end
              if _time <= 0 then
                 self.landedStatus[_lookupKeyHeli] = nil
                 return self:_PickupUnit(_heliUnit, _pilotName, _woundedGroup, _woundedGroupName)
              end
            end
        else
          if (_distance < self.loadDistance) then
              return self:_PickupUnit(_heliUnit, _pilotName, _woundedGroup, _woundedGroupName)
          end
        end
      else
  
          local _unitsInHelicopter = self:_PilotsOnboard(_heliName)
          local _maxUnits = self.aircraftType[_heliUnit:GetTypeName()]
          if _maxUnits == nil then
            _maxUnits = self.max_units
          end
          
          if _heliUnit:InAir() and _unitsInHelicopter + 1 <= _maxUnits then
  
              if _distance < 8.0 then
  
                  --check height!
                  local leaderheight = _woundedLeader:GetHeight()
                  if leaderheight < 0 then leaderheight = 0 end
                  local _height = _heliUnit:GetHeight() - leaderheight
  
                  if _height <= 20.0 then
  
                      local _time = self.hoverStatus[_lookupKeyHeli]
  
                      if _time == nil then
                          self.hoverStatus[_lookupKeyHeli] = 10
                          _time = 10
                      else
                          _time = self.hoverStatus[_lookupKeyHeli] - 1
                          self.hoverStatus[_lookupKeyHeli] = _time
                      end
  
                      if _time > 0 then
                          self:_DisplayMessageToSAR(_heliUnit, "Hovering above " .. _pilotName .. ". \n\nHold hover for " .. _time .. " seconds to winch them up. \n\nIf the countdown stops you're too far away!", 10, true)
                      else
                          self.hoverStatus[_lookupKeyHeli] = nil
                          return self:_PickupUnit(_heliUnit, _pilotName, _woundedGroup, _woundedGroupName)
                      end
                      _reset = false
                  else
                      self:_DisplayMessageToSAR(_heliUnit, "Too high to winch " .. _pilotName .. " \nReduce height and hover for 10 seconds!", 5, true)
                  end
              end
          
          end
      end
  end
  
  if _reset then
      self.hoverStatus[_lookupKeyHeli] = nil
  end
  
  return true
end

--- Check if group not KIA.
-- @param #CSAR self
-- @param Wrapper.Group#GROUP _woundedGroup
-- @param #string _woundedGroupName
-- @param Wrapper.Unit#UNIT _heliUnit
-- @param #string _heliName
-- @return #boolean Outcome
function CSAR:_CheckGroupNotKIA(_woundedGroup, _woundedGroupName, _heliUnit, _heliName)
  self:I(self.lid .. " _CheckGroupNotKIA")
  -- check if unit has died or been picked up
  local inTransit = false
  if _woundedGroup and _heliUnit then
    for _currentHeli, _groups in pairs(self.inTransitGroups) do
      if _groups[_woundedGroupName] then
        --local _group = _groups[_woundedGroupName]
        inTransit = true
        self:_DisplayToAllSAR(string.format("%s has been picked up by %s", _woundedGroupName, _currentHeli), self.coalition, _heliName)
        break
      end -- end name check
    end -- end loop
    if not inTransit then
      -- KIA
      self:_DisplayToAllSAR(string.format("%s is KIA ", _woundedGroupName), self.coalition, _heliName)
    end
    --stops the message being displayed again
    self:_RemoveNameFromDownedPilots(_woundedGroupName)
    --self.woundedGroups[_woundedGroupName] = nil
  end
  --continue
  return inTransit
end

--- Monitor in-flight returning groups.
-- @param #CSAR self
-- @param #string heliname Heli name
-- @param #string groupname Group name
function CSAR:_ScheduledSARFlight(heliname,groupname)
  self:I(self.lid .. " _ScheduledSARFlight")

        local _heliUnit = self:_GetSARHeli(heliname)
        local _woundedGroupName = groupname

        if (_heliUnit == nil) then
            --helicopter crashed?
            self.inTransitGroups[heliname] = nil
            return
        end

        if self.inTransitGroups[_heliUnit:GetName()] == nil or self.inTransitGroups[_heliUnit:GetName()][_woundedGroupName] == nil then
            -- Groups already rescued
            return
        end

        local _dist = self:_GetClosestMASH(_heliUnit)

        if _dist == -1 then
            return
        end

        if _dist < 200 and _heliUnit:InAir() == false then
            self:_RescuePilots(_heliUnit)
            return
        end

        --queue up
        self:__Returning(-5,heliname,_woundedGroupName)
end

--- Mark pilot as rescued and remove from tables.
-- @param #CSAR self
-- @param Wrapper.Unit#UNIT _heliUnit
function CSAR:_RescuePilots(_heliUnit)
  self:I(self.lid .. " _RescuePilots")
  local _heliName = _heliUnit:GetName()
  local _rescuedGroups = self.inTransitGroups[_heliName]
  
  if _rescuedGroups == nil then
      -- Groups already rescued
      return
  end
  
  self.inTransitGroups[_heliName] = nil
  
  local _txt = string.format("%s: The pilots have been taken to the\nmedical clinic. Good job!", _heliName)
  
  self:_DisplayMessageToSAR(_heliUnit, _txt, 10)
  -- trigger event
  self:__Rescued(-1,_heliUnit,_heliName)
end

--- Check and return Wrappe.Unit#UNIT based on the name if alive.
-- @param #CSAR self
-- @param #string _unitname Name of Unit
-- @return #UNIT or nil
function CSAR:_GetSARHeli(_unitName)
  self:T(self.lid .. " _GetSARHeli")
  local unit = UNIT:FindByName(_unitName)
  if unit and unit:IsAlive() then
    return unit
  else
    return nil
  end
end

--- Display message to single Unit.
-- @param #CSAR self
-- @param Wrapper.Unit#UNIT _unit
-- @param #string _text
-- @param #number _time
-- @param #boolean _clear
function CSAR:_DisplayMessageToSAR(_unit, _text, _time, _clear)
  self:T(self.lid .. " _DisplayMessageToSAR")
  local group = _unit:GetGroup()
  local _clear = _clear or nil
  local m = MESSAGE:New(_text,_time,"Info",_clear):ToGroup(group)
end

--- Function to get string of a group's position.
-- @param #CSAR self
-- @param Wrapper.Controllable#CONTROLLABLE _woundedGroup Group or Unit object.
-- @return #string Coordinates as Text
function CSAR:_GetPositionOfWounded(_woundedGroup)
  self:T(self.lid .. " _GetPositionOfWounded")
  local _coordinate = _woundedGroup:GetCoordinate()
  local _coordinatesText = "None"
  if _coordinate then
    if self.coordtype == 0 then -- Lat/Long DMTM
      _coordinatesText = _coordinate:ToStringLLDDM()
    elseif self.coordtype == 1 then -- Lat/Long DMS
      _coordinatesText = _coordinate:ToStringLLDMS()  
    elseif self.coordtype == 2 then -- MGRS
      _coordinatesText = _coordinate:ToStringMGRS()  
    elseif self.coordtype == 3 then -- Bullseye Imperial
    local Settings = _SETTINGS:SetImperial()
      _coordinatesText = _coordinate:ToStringBULLS(self.coalition,Settings)
    else -- Bullseye Metric --(medevac.coordtype == 4)
    local Settings = _SETTINGS:SetMetric()
      _coordinatesText = _coordinate:ToStringBULLS(self.coalition,Settings)
    end
  end
  return _coordinatesText
end

--- Display active SAR tasks to player.
-- @param #CSAR self
-- @param #string _unitName Unit to display to
function CSAR:_DisplayActiveSAR(_unitName)
  self:T(self.lid .. " _DisplayActiveSAR")
  local _msg = "Active MEDEVAC/SAR:"  
  local _heli = self:_GetSARHeli(_unitName) -- Wrapper.Unit#UNIT
  if _heli == nil then
      return
  end
  
  local _heliSide = self.coalition
  local _csarList = {}
  
  local _DownedPilotTable = self.downedPilots
  self:T({Table=_DownedPilotTable})
  for _, _value in pairs(_DownedPilotTable) do
    local _groupName = _value.name
    self:I(string.format("Display Active Pilot: %s", tostring(_groupName)))
    self:I({Table=_value})
    --local _woundedGroup = GROUP:FindByName(_groupName)
    local _woundedGroup = _value.group
    if _woundedGroup then  
        local _coordinatesText = self:_GetPositionOfWounded(_woundedGroup) 
        local _helicoord =  _heli:GetCoordinate()
        local _woundcoord = _woundedGroup:GetCoordinate()
        local _distance = self:_GetDistance(_helicoord, _woundcoord)
        self:I({_distance = _distance})
        table.insert(_csarList, { dist = _distance, msg = string.format("%s at %s - %.2f KHz ADF - %.3fKM ", _value.desc, _coordinatesText, _value.frequency / 1000, _distance / 1000.0) })
    end
  end
  
  local function sortDistance(a, b)
      return a.dist < b.dist
  end
  
  table.sort(_csarList, sortDistance)
  
  for _, _line in pairs(_csarList) do
      _msg = _msg .. "\n" .. _line.msg
  end
  
  self:_DisplayMessageToSAR(_heli, _msg, 20)
end

--- Find the closest downed pilot to a heli.
-- @param #CSAR self
-- @param Wrapper.Unit#UNIT _heli Helicopter #UNIT
-- @return #table Table of results
function CSAR:_GetClosestDownedPilot(_heli)
  self:I(self.lid .. " _GetClosestDownedPilot")
  local _side = self.coalition
  local _closestGroup = nil
  local _shortestDistance = -1
  local _distance = 0
  local _closestGroupInfo = nil
  local _heliCoord = _heli:GetCoordinate()
  
  local DownedPilotsTable = self.downedPilots
  for _, _groupInfo in pairs(DownedPilotsTable) do
      local _woundedName = _groupInfo.name
      --local _tempWounded = GROUP:FindByName(_woundedName)
      local _tempWounded = _groupInfo.group
      
      -- check group exists and not moving to someone else
      if _tempWounded then
          local _tempCoord = _tempWounded:GetCoordinate()
          _distance = self:_GetDistance(_heliCoord, _tempCoord)

          if _distance ~= nil and (_shortestDistance == -1 or _distance < _shortestDistance) then
              _shortestDistance = _distance
              _closestGroup = _tempWounded
              _closestGroupInfo = _groupInfo
          end
      end
  end

  return { pilot = _closestGroup, distance = _shortestDistance, groupInfo = _closestGroupInfo }
end

--- Fire a flare at the point of a downed pilot.
-- @param #CSAR self
-- @param #string _unitName Name of the unit.
function CSAR:_SignalFlare(_unitName)
  self:T(self.lid .. " _SignalFlare")
  local _heli = self:_GetSARHeli(_unitName)
  if _heli == nil then
      return
  end
  
  local _closest = self:_GetClosestDownedPilot(_heli)
  
  if _closest ~= nil and _closest.pilot ~= nil and _closest.distance < 8000.0 then
  
      local _clockDir = self:_GetClockDirection(_heli, _closest.pilot)
  
      local _msg = string.format("%s - %.2f KHz ADF - %.3fM - Popping Signal Flare at your %s o\'clock", _closest.groupInfo.desc, _closest.groupInfo.frequency / 1000, _closest.distance, _clockDir)
      self:_DisplayMessageToSAR(_heli, _msg, 20)
      
      local _coord = _closest.pilot:GetCoordinate()
      _coord:FlareRed(_clockDir)
  else
      self:_DisplayMessageToSAR(_heli, "No Pilots within 8KM", 20)
  end
end

--- Display info to all SAR groups.
-- @param #CSAR self
-- @param #string _message
-- @param #number _side
-- @param #string _ignore
function CSAR:_DisplayToAllSAR(_message, _side, _ignore)
  self:T(self.lid .. " _DisplayToAllSAR")
  for _, _unitName in pairs(self.csarUnits) do
    local _unit = self:_GetSARHeli(_unitName)
    if _unit then
      if not _ignore then
          self:_DisplayMessageToSAR(_unit, _message, 10)
      end
    end
  end
end

---Request smoke at closest downed pilot.
--@param #CSAR self
--@param #string _unitName Name of the helicopter
function CSAR:_Reqsmoke( _unitName )
  self:T(self.lid .. " _Reqsmoke")
  local _heli = self:_GetSARHeli(_unitName)
  if _heli == nil then
      return
  end
  local _closest = self:_GetClosestDownedPilot(_heli)
  if _closest ~= nil and _closest.pilot ~= nil and _closest.distance < 8000.0 then
      local _clockDir = self:_GetClockDirection(_heli, _closest.pilot)
      local _msg = string.format("%s - %.2f KHz ADF - %.3fM - Popping Blue smoke at your %s o\'clock", _closest.groupInfo.desc, _closest.groupInfo.frequency / 1000, _closest.distance, _clockDir)
      self:_DisplayMessageToSAR(_heli, _msg, 20)
      local _coord = _closest.pilot:GetCoordinate()
      local color = self.smokecolor
      _coord:Smoke(color)
  else
      self:_DisplayMessageToSAR(_heli, "No Pilots within 8KM", 20)
  end
end

--- Determine distance to closest MASH.
-- @param #CSAR self
-- @param Wrapper.Unit#UNIT _heli Helicopter #UNIT
-- @retunr
function CSAR:_GetClosestMASH(_heli)
  self:I(self.lid .. " _GetClosestMASH")
  local _mashset = self.bluemash -- Core.Set#SET_GROUP
  local _mashes = _mashset:GetSetObjects() -- #table
  local _shortestDistance = -1
  local _distance = 0
  local _helicoord = _heli:GetCoordinate()
  
  for _, _mashUnit in pairs(_mashes) do
      if _mashUnit and _mashUnit:IsAlive() then
          local _mashcoord = _mashUnit:GetCoordinate()
          _distance = self:_GetDistance(_helicoord, _mashcoord)
          if _distance ~= nil and (_shortestDistance == -1 or _distance < _shortestDistance) then
            _shortestDistance = _distance
          end
      end
  end
  
  if _shortestDistance ~= -1 then
      return _shortestDistance
  else
      return -1
  end
end

--- Display onboarded rescued pilots.
-- @param #CSAR self
-- @param #string _unitName Name of the chopper
function CSAR:_CheckOnboard(_unitName)
  self:I(self.lid .. " _CheckOnboard")
    local _unit = self:_GetSARHeli(_unitName)
    if _unit == nil then
        return
    end
    --list onboard pilots
    local _inTransit = self.inTransitGroups[_unitName]

    if _inTransit == nil or #_inTransit == 0 then
        self:_DisplayMessageToSAR(_unit, "No Rescued Pilots onboard", self.messageTime)
    else
        local _text = "Onboard - RTB to FARP/Airfield or MASH: "
        for _, _onboard in pairs(self.inTransitGroups[_unitName]) do
            _text = _text .. "\n" .. _onboard.desc
        end
        self:_DisplayMessageToSAR(_unit, _text, self.messageTime)
    end
end

--- Populate F10 menu for CSAR players.
-- @param #CSAR self
function CSAR:_AddMedevacMenuItem()
  self:I(self.lid .. " _AddMedevacMenuItem")
  
  local coalition = self.coalition
  local allheligroupset = self.allheligroupset
  local _allHeliGroups = allheligroupset:GetSetObjects()

  -- rebuild units table
  local _UnitList = {}
  for _key, _group in pairs (_allHeliGroups) do  
    local _unit = _group:GetUnit(1) -- Asume that there is only one unit in the flight for players
    if _unit then 
      if _unit:IsAlive() then         
        local unitName = _unit:GetName()
          --if not self.csarUnits[unitName] then
            --self.csarUnits[unitName] = unitName
            _UnitList[unitName] = unitName
          --end
      end -- end isAlive
    end -- end if _unit
  end -- end for
  self.csarUnits = _UnitList
  
  -- build unit menus  
  for _, _unitName in pairs(self.csarUnits) do
    local _unit = self:_GetSARHeli(_unitName) -- Wrapper.Unit#UNIT
    if _unit then
      local _group = _unit:GetGroup() -- Wrapper.Group#GROUP
      if _group then
        local groupname = _group:GetName()
        if self.addedTo[groupname] == nil then
          self.addedTo[groupname] = true
          local _rootPath = MENU_GROUP:New(_group,"CSAR")
          local _rootMenu1 = MENU_GROUP_COMMAND:New(_group,"List Active CSAR",_rootPath, self._DisplayActiveSAR,self,_unitName)
          local _rootMenu2 = MENU_GROUP_COMMAND:New(_group,"Check Onboard",_rootPath, self._CheckOnboard,self,_unitName)
          local _rootMenu3 = MENU_GROUP_COMMAND:New(_group,"Request Signal Flare",_rootPath, self._SignalFlare,self,_unitName)
          local _rootMenu4 = MENU_GROUP_COMMAND:New(_group,"Request Smoke",_rootPath, self._Reqsmoke,self,_unitName):Refresh()
        end
      end
    end
  end  
  return
end

--- Return distance in meters between two coordinates.
-- @param #CSAR self
-- @param Core.Point#COORDINATE _point1 Coordinate one
-- @param Core.Point#COORDINATE _point2 Coordinate two
-- @return #number Distance in meters
function CSAR:_GetDistance(_point1, _point2)
  self:T(self.lid .. " _GetDistance")
  local distance = _point1:DistanceFromPointVec2(_point2)
  return distance
end

--- Populate table with available beacon frequencies.
-- @param #CSAR self
function CSAR:_GenerateVHFrequencies()
  self:I(self.lid .. " _GenerateVHFrequencies")
  local _skipFrequencies = self.SkipFrequencies
      
  local FreeVHFFrequencies = {}
  local UsedVHFFrequencies = {}
  
    -- first range
  local _start = 200000
  while _start < 400000 do
  
      -- skip existing NDB frequencies
      local _found = false
      for _, value in pairs(_skipFrequencies) do
          if value * 1000 == _start then
              _found = true
              break
          end
      end

      if _found == false then
          table.insert(FreeVHFFrequencies, _start)
      end
  
      _start = _start + 10000
  end
 
   -- second range
  _start = 400000
  while _start < 850000 do
  
      -- skip existing NDB frequencies
      local _found = false
      for _, value in pairs(_skipFrequencies) do
          if value * 1000 == _start then
              _found = true
              break
          end
      end
  
      if _found == false then
          table.insert(FreeVHFFrequencies, _start)
      end
  
      _start = _start + 10000
  end
  
  -- third range
  _start = 850000
  while _start <= 1250000 do
  
      -- skip existing NDB frequencies
      local _found = false
      for _, value in pairs(_skipFrequencies) do
          if value * 1000 == _start then
              _found = true
              break
          end
      end
  
      if _found == false then
          table.insert(FreeVHFFrequencies, _start)
      end
  
      _start = _start + 50000
  end
  self.FreeVHFFrequencies = FreeVHFFrequencies
end

--- Pop frequency from prepopulated table.
-- @param #CSAR self
-- @return #number frequency
function CSAR:_GenerateADFFrequency()
  self:T(self.lid .. " _GenerateADFFrequency")
  -- get a free freq for a beacon
  if #self.FreeVHFFrequencies <= 3 then
      self.FreeVHFFrequencies = self.UsedVHFFrequencies
      self.UsedVHFFrequencies = {}
  end
  local _vhf = table.remove(self.FreeVHFFrequencies, math.random(#self.FreeVHFFrequencies))
  return _vhf
end

--- Function to determine clockwise direction for flares.
-- @param #CSAR self
-- @param Wrapper.Unit#UNIT _heli The Helicopter
-- @param Wrapper.Group#GROUP _group The downed Group
-- @return #number direction
function CSAR:_GetClockDirection(_heli, _group)
  self:T(self.lid .. " _GetClockDirection")
 
  local _playerPosition = _heli:GetCoordinate() -- get position of helicopter
  local _targetpostions = _group:GetCoordinate() -- get position of downed pilot
  local _heading = _playerPosition:GetHeading() -- heading
  local DirectionVec3 = _playerPosition:GetDirectionVec3( _targetpostions )
  local Angle = _playerPosition:GetAngleDegrees( DirectionVec3 )
  self:T(self.lid .. " _GetClockDirection"..tostring(Angle).." "..tostring(_heading))
  local clock = 12   
  if _heading then
    local Aspect = Angle - _heading
    if Aspect == 0 then Aspect = 360 end
    --clock = math.abs(math.floor(Aspect / 30))
    clock = math.floor(Aspect / 30)
    --clock = UTILS.Round(clock,-2)
  end    
  return clock
end

--- Function to add beacon to downed pilot.
-- @param #CSAR self
-- @param Wrapper.Group#GROUP _group Group #GROUP object.
-- @param #number _freq Frequency to use
function CSAR:_AddBeaconToGroup(_group, _freq)
    self:I(self.lid .. " _AddBeaconToGroup")
    local _group = _group   
    if _group == nil then
        --return frequency to pool of available
        for _i, _current in ipairs(self.UsedVHFFrequencies) do
            if _current == _freq then
                table.insert(self.FreeVHFFrequencies, _freq)
                table.remove(self.UsedVHFFrequencies, _i)
            end
        end
        return
    end
    
    local _radioUnit = _group:GetUnit(1)    
    local Frequency = _freq -- Freq in Hertz
    local Sound =  "l10n/DEFAULT/"..self.radioSound
    trigger.action.radioTransmission(Sound, _radioUnit:GetPositionVec3(), 0, false, Frequency, 1000) -- Beacon in MP only runs for exactly 30secs straight
    --timer.scheduleFunction(self._RefreshRadioBeacons, { _group, _freq }, timer.getTime() + 30)
end

--- Helper function to (re-)add beacon to downed pilot.
-- @param #CSAR self
-- @param #table _args Arguments
function CSAR:_RefreshRadioBeacons()
    self:T(self.lid .. " _RefreshRadioBeacons")
    local PilotTable = self.downedPilots
    for _,_pilot in pairs (PilotTable) do
      local pilot = _pilot -- #CSAR.DownedPilot
      local group = pilot.group
      local frequency = pilot.frequency
      if frequency and frequency > 0 then
        self:_AddBeaconToGroup(group,frequency)
      end
    end
end

  ------------------------------
  --- FSM internal Functions ---
  ------------------------------

--- Function called after Start() event.
-- @param #CSAR self.
-- @param #string From From state.
-- @param #string Event Event triggered.
-- @param #string To To state.
function CSAR:onafterStart(From, Event, To)
  self:T({From, Event, To})
  self:I(self.lid .. "Started.")
  -- event handler
  self:HandleEvent(EVENTS.Takeoff, self._EventHandler)
  self:HandleEvent(EVENTS.Land, self._EventHandler)
  self:HandleEvent(EVENTS.Ejection, self._EventHandler)
  self:HandleEvent(EVENTS.PlayerEnterAircraft, self._EventHandler)
  self:HandleEvent(EVENTS.PlayerEnterUnit, self._EventHandler)
  self:HandleEvent(EVENTS.Dead, self._EventHandler)
  self:_GenerateVHFrequencies()
  if self.useprefix then
    local prefixes = self.csarPrefix or {}
    self.allheligroupset = SET_GROUP:New():FilterCoalitions(self.coalitiontxt):FilterPrefixes(prefixes):FilterCategoryHelicopter():FilterStart()
  else
    self.allheligroupset = SET_GROUP:New():FilterCoalitions(self.coalitiontxt):FilterCategoryHelicopter():FilterStart()
  end
  self:__Status(-10)
  return self
end

--- Function called before Status() event.
-- @param #CSAR self.
-- @param #string From From state.
-- @param #string Event Event triggered.
-- @param #string To To state.
function CSAR:onbeforeStatus(From, Event, To)
  self:T({From, Event, To})
  -- housekeeping
  self:_AddMedevacMenuItem()
  self:_RefreshRadioBeacons()
  for _,_sar in pairs (self.csarUnits) do
    local PilotTable = self.downedPilots
    for _,_entry in pairs (PilotTable) do
      local entry = _entry -- #CSAR.DownedPilot
      local name = entry.name
      self:_CheckWoundedGroupStatus(_sar,name)
    end
  end
  return self
end

--- Function called after Status() event.
-- @param #CSAR self.
-- @param #string From From state.
-- @param #string Event Event triggered.
-- @param #string To To state.
function CSAR:onafterStatus(From, Event, To)
  self:I({From, Event, To})
  -- collect some stats
  local NumberOfSARPilots = 0
  for _, _unitName in pairs(self.csarUnits) do
    NumberOfSARPilots = NumberOfSARPilots + 1
  end
  --[[
  local PilotsInField = 0
  for _, _unitName in pairs(self.woundedGroups) do
    PilotsInField = PilotsInField + 1
  end
  --]]
  local PilotsInFieldN = 0
  for _, _unitName in pairs(self.downedPilots) do
    PilotsInFieldN = PilotsInFieldN + 1
  end
  
  local PilotsBoarded = 0
  for _, _unitName in pairs(self.inTransitGroups) do
    PilotsBoarded = PilotsBoarded + 1
  end
  
  if self.verbose > 0 then
    local text = string.format("%s Active SAR: %d | Downed Pilots in field: %d | Pilots boarded: %d | Rescue (landings): %d",self.lid,NumberOfSARPilots,PilotsInFieldN,PilotsBoarded,self.rescues)
    self:I(text)
    if self.verbose > 1 then
      local m = MESSAGE:New(text,"10","Status"):ToAll()
    end
  end
  self:__Status(-20)
  return self
end

--- Function called after Stop() event.
-- @param #CSAR self.
-- @param #string From From state.
-- @param #string Event Event triggered.
-- @param #string To To state.
function CSAR:onafterStop(From, Event, To)
  self:T({From, Event, To})
  -- event handler
  self:UnHandleEvent(EVENTS.Takeoff)
  self:UnHandleEvent(EVENTS.Land)
  self:UnHandleEvent(EVENTS.Ejection)
  self:UnHandleEvent(EVENTS.PlayerEnterUnit)
  self:UnHandleEvent(EVENTS.PlayerEnterAircraft)
  self:UnHandleEvent(EVENTS.Dead)
  self:T(self.lid .. "Stopped.")
  return self
end

--- Function called before Approach() event.
-- @param #CSAR self.
-- @param #string From From state.
-- @param #string Event Event triggered.
-- @param #string To To state.
-- @param #string Heliname Name of the helicopter group.
-- @param #string Woundedgroupname Name of the downed pilot's group.
function CSAR:onbeforeApproach(From, Event, To, Heliname, Woundedgroupname)
  self:I({From, Event, To, Heliname, Woundedgroupname})
  self:_CheckWoundedGroupStatus(Heliname,Woundedgroupname)
  return self
end

--- Function called before Boarded() event.
-- @param #CSAR self.
-- @param #string From From state.
-- @param #string Event Event triggered.
-- @param #string To To state.
-- @param #string Heliname Name of the helicopter group.
-- @param #string Woundedgroupname Name of the downed pilot's group.
function CSAR:onbeforeBoarded(From, Event, To, Heliname, Woundedgroupname)
  self:I({From, Event, To, Heliname, Woundedgroupname})
  self:_ScheduledSARFlight(Heliname,Woundedgroupname)
  return self
end

--- Function called before Returning() event. 
-- @param #CSAR self.
-- @param #string From From state.
-- @param #string Event Event triggered.
-- @param #string To To state.
-- @param #string Heliname Name of the helicopter group.
-- @param #string Woundedgroupname Name of the downed pilot's group.
function CSAR:onbeforeReturning(From, Event, To, Heliname, Woundedgroupname)
  self:I({From, Event, To, Heliname, Woundedgroupname})
  self:_ScheduledSARFlight(Heliname,Woundedgroupname)
  return self
end

--- Function called before Rescued() event.
-- @param #CSAR self.
-- @param #string From From state.
-- @param #string Event Event triggered.
-- @param #string To To state.
-- @param Wrapper.Unit#UNIT HeliUnit Unit of the helicopter.
-- @param #string HeliName Name of the helicopter group.
function CSAR:onbeforeRescued(From, Event, To, HeliUnit, HeliName)
  self:I({From, Event, To, HeliName, HeliUnit})
  self.rescues = self.rescues + 1
  return self
end

--- Function called before PilotDown() event.
-- @param #CSAR self.
-- @param #string From From state.
-- @param #string Event Event triggered.
-- @param #string To To state.
-- @param Wrapper.Group#GROUP Group Group object of the downed pilot.
-- @param #number Frequency Beacon frequency in kHz.
-- @param #string Leadername Name of the #UNIT of the downed pilot.
-- @param #string CoordinatesText String of the position of the pilot. Format determined by self.coordtype.
function CSAR:onbeforePilotDown(From, Event, To, Group, Frequency, Leadername, CoordinatesText)
  self:T({From, Event, To, Group, Frequency, Leadername, CoordinatesText})
  return self
end
--------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Testing
-- You need a late activated infantry group ("Downed Pilot" below) to stand in for the actual pilot. 
-- Setup is currently in lines 186ff of this file, or you can use `myCSAR.<setting> = <value> after instantiating the object.
-- Test mission setup on GH
-- 
_SETTINGS:SetPlayerMenuOff()
_SETTINGS:SetA2G_BR()
_SETTINGS:SetA2A_BULLS()
_SETTINGS:SetImperial()

local BlueCsar = CSAR:New(coalition.side.BLUE,"Downed Pilot","Luftrettung")
BlueCsar:__Start(5)

function Spawn_CSAR(BlueCSAR)
  BlueCSAR:_SpawnCsarAtZone( "CSAR_Start_1", coalition.side.BLUE,"Pilot Maulwurf", true )
  BlueCSAR:_SpawnCsarAtZone( "CSAR_Start_2", coalition.side.BLUE,"Pilot Schnake", true )
  BlueCSAR:_SpawnCsarAtZone( "CSAR_Start_3", coalition.side.BLUE,"Pilot Chickendog", true )
  BlueCSAR:_SpawnCsarAtZone( "CSAR_Start_4", coalition.side.BLUE,"Pilot Wagner", true )
end

local maulwuerfe = TIMER:New(Spawn_CSAR,BlueCsar)
maulwuerfe:Start(30)

