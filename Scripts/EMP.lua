dofile "Libs/Debugger.lua"
sm.isDev = true
-- the following code prevents re-load of this file, except if in '-dev' mode.  -- fixes broken sh*t by devs.
if EMP and not sm.isDev then -- increases performance for non '-dev' users.
	return
end 

dofile "Libs/GameImprovements/interactable.lua"
dofile "Libs/MoreMath.lua"

BACKUP_setPower, BACKUP_setValue, BACKUP_setActive = BACKUP_setPower, BACKUP_setValue, BACKUP_setActive
if not BACKUP_setPower then -- make a backup of setPower, setValue, setActive
	BACKUP_setPower = sm.interactable.setPower
	BACKUP_setValue = sm.interactable.setValue
	BACKUP_setActive = sm.interactable.setActive
	--mpPrint("made a backup of setPower, setValue, setActive")
end 

mpPrint("loading EMP.lua")

-- EMP.lua --
EMP = class( nil )
EMP.maxParentCount = -1
EMP.maxChildCount = 0
EMP.connectionInput =  sm.interactable.connectionType.power + sm.interactable.connectionType.logic
EMP.connectionOutput = 0
EMP.colorNormal = sm.color.new( 0xaaaaaaff )
EMP.colorHighlight = sm.color.new( 0xaaaaaaff )
EMP.poseWeightCount = 3

local affectedInteractables = {}

function EMP.server_onFixedUpdate(self, dt)
	
	local parentActive = false
	for k, v in pairs(self.interactable:getParents()) do
		if not sm.interactable.isNumberType(v) then
			parentActive = parentActive or v.active
		end
	end
	if parentActive and not self.parentWasActive then
		self:server_clientInteract()
	end
	self.parentWasActive = parentActive
	
	
	if EMPDeactivation == sm.game.getCurrentTick() then -- repair to normal functions
		self:server_repairFunctions()
	end
	
	
	if self.interactable.active then -- calculate particle location for all affected interactables near players. with randomness
		self.interactable.active = false
		
		local particleLocations = {}
		
		local randomness = math.ceil(table.size(affectedInteractables)/100)
		
		for k, interactable in pairs(affectedInteractables) do
			if math.random(randomness) == 1 and interactable and sm.exists(interactable) then
				local pos = interactable:getShape().worldPosition
				
				table.insert(particleLocations, pos)
			end
		end
		
		self.network:sendToClients("client_createParticlesAt", particleLocations)
	end
	
	self.interactable:setPower(0) -- make vulnerable to other EMP's
end

function EMP.server_onDestroy(self) -- repair to normal functions
	self:server_repairFunctions()
end

function EMP.server_repairFunctions(self)
	affectedInteractables = {}
	sm.interactable.setPower  = BACKUP_setPower 
	sm.interactable.setValue  = BACKUP_setValue 
	sm.interactable.setActive = BACKUP_setActive
	-- applying changed for userdata!
	self.interactable.setPower = sm.interactable.setPower
	self.interactable.setValue = sm.interactable.setValue
	self.interactable.setActive = sm.interactable.setActive
end

-- function EMP.getPlayerPositions(self) -- can be used to get player locations so it only does particles there
-- 	local playerPositions = {}
-- 	for k, v in pairs(sm.player.getAllPlayers()) do
-- 		table.insert(playerPositions, v.character.worldPosition)
-- 	end
-- 	return playerPositions
-- end


function EMP.server_clientInteract(self)
	if affectedInteractables[self.interactable.id] then return end -- can't operate while incapacitated
	
	self.interactable.active = true
	local activationtime, range
	
	for k, v in pairs(self.interactable:getParents()) do
		if sm.interactable.isNumberType(v) then
			local color = tostring(v:getShape().color)
			if color == "eeeeeeff" then -- time
				activationtime = (activationtime or 0) + v.power
			else -- range
				range = (range or 0) + v.power/4
			end
		end
	end
	
	EMPDeactivation = sm.game.getCurrentTick() + (activationtime or 120) -- ticks, global so that any EMP can deactivate scrambling
	range = range or 100 -- blocks to meters
	
	local position = self.shape.worldPosition
	-- overwriting! :
	function sm.interactable.setPower(interactable, value)
		if affectedInteractables[interactable.id] then
			-- affected interactable
			BACKUP_setPower(interactable, 0)
		elseif self.interactable.active and (interactable:getShape().worldPosition - position):length() < range then
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
		elseif self.interactable.active and (interactable:getShape().worldPosition - position):length() < range then
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
		elseif self.interactable.active and (interactable:getShape().worldPosition - position):length() < range then
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


-- client: 

function EMP.client_onInteract(self)
	self.network:sendToServer("server_clientInteract")
end

function EMP.client_createParticlesAt(self, particleLocations)
	for k, particleLocation in pairs(particleLocations) do
		if math.random(2) == 1 then
			sm.effect.playEffect( "Projectile - Hit" , particleLocation, nil, nil )
		else
			sm.particle.createParticle( "construct_welding", particleLocation )
		end
	end
end
