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
	
	
	if self.active then -- 1 cycle after self.interactable.active, parts were able to add themselves to  affectedInteractables
		-- calculate particle location for all affected interactables near players. with randomness
		local particleLocations = {}
		
		local randomness = math.ceil(table.size(affectedInteractables)/100)
		
		for k, affectedInteractable in pairs(affectedInteractables) do
			if math.random(randomness) == 1 and affectedInteractable and sm.exists(affectedInteractable[1]) then
				table.insert(particleLocations, affectedInteractable[1]:getShape().worldPosition)
			end
		end
		self.network:sendToClients("client_createParticlesAt", particleLocations)
	end
	
	
	self.active = self.interactable.active
	if self.interactable.active then
		self.interactable.active = false
	end
	
	
	
	local isEmptyTable = table.size(affectedInteractables) == 0
	if isEmptyTable and not self.wasEmptyTable then
		self:server_repairFunctions()
	end
	self.wasEmptyTable = isEmptyTable
	
	self.interactable:setPower(0) -- make vulnerable to other EMP's
end

function EMP.server_onDestroy(self)

end

function EMP.server_repairFunctions(self)
	sm.interactable.setPower  = BACKUP_setPower 
	sm.interactable.setValue  = BACKUP_setValue 
	sm.interactable.setActive = BACKUP_setActive
	-- applying changed for userdata!
	self.interactable.setPower = sm.interactable.setPower
	self.interactable.setValue = sm.interactable.setValue
	self.interactable.setActive = sm.interactable.setActive
end


	-- if EMPDeactivation == sm.game.getCurrentTick() then -- repair to normal functions
		-- self:server_repairFunctions()
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
	
	local EMPDeactivation = sm.game.getCurrentTick() + (activationtime or 120) -- ticks, global so that any EMP can deactivate scrambling
	range = range or 100 -- blocks to meters
	
	local position = self.shape.worldPosition
	
	
	local function HijackedFunction(interactable, value, Original_function)
		if affectedInteractables[interactable.id] then
			-- affected interactable
			Original_function(interactable, 0)
			if affectedInteractables[interactable.id][2] < sm.game.getCurrentTick() then
				affectedInteractables[interactable.id] = nil
				if table.size(affectedInteractables) == 0 then
					EMP.server_repairFunctions({interactable = interactable})
				end
			end
			
		elseif self.active and (interactable:getShape().worldPosition - position):length() < range then
			-- add to affected interactables
			affectedInteractables[interactable.id] = {interactable, EMPDeactivation}
		else 
			-- not start of emp or out of range
			Original_function(interactable, value)
		end
	end
	
	-- overwriting! :
	function sm.interactable.setPower(interactable, value)
		HijackedFunction(interactable, value, BACKUP_setPower)
	end
	function sm.interactable.setValue(interactable, value)
		HijackedFunction(interactable, value, BACKUP_setValue)
	end
	function sm.interactable.setActive(interactable, value)
		HijackedFunction(interactable, value, BACKUP_setActive)
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
	local effect = sm.effect.createEffect( "Collision - Impact" )--, self.interactable )
	effect:setParameter("Size", -10)
	effect:setParameter("Velocity", 11)
	effect:setParameter("Material", 0)
	effect:setPosition(self.shape.worldPosition)
	for x=1,10 do
		effect:start()
	end
end
