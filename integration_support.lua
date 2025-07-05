  -- RuneReader Recast
-- Copyright (c) Michael Sutton 2025
-- Licensed under the GNU General Public License v3.0 (GPLv3)
-- You may use, modify, and distribute this file under the terms of the GPLv3 license.
-- See: https://www.gnu.org/licenses/gpl-3.0.en.html

  RuneReader = RuneReader or {}

  function RuneReader:GetUpdatedValues()
   local fullResult = ""
    if  Hekili  and (RuneReaderRecastDBPerChar.HelperSource == 0) then
      fullResult = RuneReader:Hekili_UpdateValues(1) --Standard code39 for now.....
    --  print("from Hekili", fullResult)
      return fullResult
    elseif ConRO and (RuneReaderRecastDBPerChar.HelperSource == 2) then
      fullResult = RuneReader:ConRO_UpdateValues(1) --Standard code39 for now.....
     -- print("from ConRo", fullResult)
      return fullResult
    else
    -- Fallback to AssistedCombat as it should always be available. if prior arnt selected or not available
    fullResult = RuneReader:AssistedCombat_UpdateValues(1)
       --   print("from Combat Assist", fullResult)
    end

    return fullResult
end