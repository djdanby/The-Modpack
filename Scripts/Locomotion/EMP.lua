
-- EMP.lua --
EMP = class( nil )
EMP.maxParentCount = -1
EMP.maxChildCount = 0
EMP.connectionInput =  sm.interactable.connectionType.power + sm.interactable.connectionType.logic
EMP.connectionOutput = 0
EMP.colorNormal = sm.color.new( 0xaaaaaaff )
EMP.colorHighlight = sm.color.new( 0xaaaaaaff )
EMP.poseWeightCount = 3
