dofile "Libs/Debugger.lua"
sm.isDev = true
-- the following code prevents re-load of this file, except if in '-dev' mode.  -- fixes broken sh*t by devs.
if EMP and not sm.isDev then -- increases performance for non '-dev' users.
	return
end 

mpPrint("loading EMP.lua")  -- TODO: lock out reloading, even when sm.isDev !!!


local BACKUP_setPower, BACKUP_setValue, BACKUP_setActive -- will make a new backup on script reload (-dev) !!!
if not BACKUP_setPower then -- make a backup of setPower, setValue, setActive
	BACKUP_setPower = sm.interactable.setPower
	BACKUP_setValue = sm.interactable.setValue
	BACKUP_setActive = sm.interactable.setActive
	--mpPrint("made a backup of setPower, setValue, setActive")
end 


-- EMP.lua --
EMP = class( nil )
EMP.maxParentCount = -1
EMP.maxChildCount = 0
EMP.connectionInput =  sm.interactable.connectionType.power + sm.interactable.connectionType.logic
EMP.connectionOutput = 0
EMP.colorNormal = sm.color.new( 0xaaaaaaff )
EMP.colorHighlight = sm.color.new( 0xaaaaaaff )
EMP.poseWeightCount = 3

EMP.range = 40

local affectedInteractables = {}

function EMP.server_onFixedUpdate(self, dt)
	
	if EMPDeactivation == sm.game.getCurrentTick() then -- repair to normal functions
		sm.interactable.setPower  = BACKUP_setPower 
		sm.interactable.setValue  = BACKUP_setValue 
	    sm.interactable.setActive = BACKUP_setActive
		-- applying changed for userdata!
		self.interactable.setPower = sm.interactable.setPower
		self.interactable.setValue = sm.interactable.setValue
		self.interactable.setActive = sm.interactable.setActive
	end
	
	if self.interactable.active then -- calculate particle location for all affected interactables near players. with randomness
		self.interactable.active = false
		
		local particleLocations = {}
		
		local playerPositions = self:getPlayerPositions()
		
		for k, interactable in pairs(affectedInteractables) do
			if math.random(2) == 1 and interactable and sm.exists(interactable) then
				local pos = interactable:getShape().worldPosition
				
				for k, playerPosition in pairs(playerPositions) do 
					if (playerPosition - pos):length() < 10 then
						table.insert(particleLocations, pos)
					end
				end
			end
		end
		
		self.network:sendToClients("client_createParticlesAt", particleLocations)
	end
end

function EMP.server_onDestroy(self) -- repair to normal functions
	sm.interactable.setPower  = BACKUP_setPower 
	sm.interactable.setValue  = BACKUP_setValue 
	sm.interactable.setActive = BACKUP_setActive
	-- applying changed for userdata!
	self.interactable.setPower = sm.interactable.setPower
	self.interactable.setValue = sm.interactable.setValue
	self.interactable.setActive = sm.interactable.setActive
end

function EMP.getPlayerPositions(self)
	local playerPositions = {}
	for k, v in pairs(sm.player.getAllPlayers()) do
		table.insert(playerPositions, v.character.worldPosition)
	end
	return playerPositions
end

function EMP.server_clientInteract(self)
	self.interactable.active = true
	
	EMPDeactivation = sm.game.getCurrentTick() + 120 -- ticks, global so that any EMP can deactivate scrambling
	
	local range = self.range / 4 -- blocks to meters
	
	
	-- overwriting! :
	function sm.interactable.setPower(interactable, value)
		if affectedInteractables[interactable.id] then
			-- affected interactable
			BACKUP_setPower(interactable, 0)
		elseif self.interactable.active and (interactable:getShape().worldPosition - self.shape.worldPosition):length() < range then
			-- add to affected interactables
			affectedInteractables[interactable.id] = interactable
		else 
			-- not start of emp or out of range
			BACKUP_setPower(interactable, value)
		end
	end
	function sm.interactable.setValue(interactable, value)
		if affectedInteractables[interactable.id] then
			-- affected interactable
			BACKUP_setValue(interactable, 0)
		elseif self.interactable.active and (interactable:getShape().worldPosition - self.shape.worldPosition):length() < range then
			-- add to affected interactables
			affectedInteractables[interactable.id] = interactable
		else 
			-- not start of emp or out of range
			BACKUP_setValue(interactable, value)
		end
	end
	function sm.interactable.setActive(interactable, value)
		if affectedInteractables[interactable.id] then
			-- affected interactable
			BACKUP_setActive(interactable, false)
		elseif self.interactable.active and (interactable:getShape().worldPosition - self.shape.worldPosition):length() < range then
			-- add to affected interactables
			affectedInteractables[interactable.id] = interactable
		else 
			-- not start of emp or out of range
			BACKUP_setActive(interactable, value)
		end
	end
	
	-- applying changed for userdata! :
	self.interactable.setPower = sm.interactable.setPower
	self.interactable.setValue = sm.interactable.setValue
	self.interactable.setActive = sm.interactable.setActive
end



function EMP.client_onInteract(self)
	self.network:sendToServer("server_clientInteract")
end

function EMP.client_createParticlesAt(self, particleLocations)
	

end
