  RuneReader = RuneReader or {}

  function RuneReader:GetUpdatedValues()
   local fullResult = ""
    if  Hekili  and (RuneReaderRecastDBPerChar.HelperSource == 0) then
      fullResult = RuneReader:Hekili_UpdateValues(1) --Standard code39 for now.....
     -- print("from Hekili", fullResult)
      
      return fullResult
    end
    if ConRO and (RuneReaderRecastDBPerChar.HelperSource == 3) then
      fullResult = RuneReader:ConRO_UpdateValues(1) --Standard code39 for now.....
     -- print("from ConRo", fullResult)

      return fullResult
    end
    -- Fallback to AssistedCombat as it should always be available. if prior arnt selected or not available
    fullResult = RuneReader:AssistedCombat_UpdateValues(1)
     --     print("from Combat Assist", fullResult)

    return fullResult
end