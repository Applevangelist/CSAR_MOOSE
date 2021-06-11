# CSAR_MOOSE
Refactoring Ciribob's excellent CSAR script into Moose as object-oriented FSM

## Testing
-- You need a late activated infantry group ("Downed Pilot" below) to stand in for the actual pilot. 
-- Setup is currently in lines 186ff of this file, or you can use `myCSAR.<setting> = <value> after instantiating the object.
-- Test mission setup on GH

      local BlueCsar = CSAR:New(coalition.side.BLUE,"Downed Pilot","Luftrettung")
      BlueCsar:__Start(5)
