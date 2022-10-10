-- AngryPeds
-- ver 0.1
-- by YungAncestor.  https://github.com/YungAncestor/AngryPeds

-- the max distance between a ped to be chosen and the target
PED_SELECT_RANGE = 100

-- which weapon(s) to give to the npc, accepts table or a single hash
PED_WEAPONS = {0x22D8FE39, 0x7F7497E5, 0x476BF155, 0xB62D1F67}

-- set ped's combat range. you may want to set to 0 to make the ped close enough to shoot the target, if you want them to use a stun gun.
-- 0: Near   1: Medium   2: Far
PED_ATTACK_RANGE = 2

--
--
--

function get_dist(coord1, coord2, ignorez)
	return MISC.GET_DISTANCE_BETWEEN_COORDS(coord1.x, coord1.y, coord1.z, coord2.x, coord2.y, coord2.z, ignorez)
end

function get_entity_coords(entity)
	local entity_pos = ENTITY.GET_ENTITY_COORDS(entity, true)
	return entity_pos
end

function get_local_coords()
	local local_pos = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID(), true)
	notify("X:"..local_pos.x.." Y:"..local_pos.y.." Z:"..local_pos.z)
	return local_pos
end

function get_closest_ped_from_player(ind, range)
	local target = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(ind)
	return get_closest_ped_from_entity(target, range)
end

function get_closest_ped_from_entity(target, range)
	local selfpedid = PLAYER.PLAYER_PED_ID()
	local player_coords = get_entity_coords(target)
	local allpeds = entities.get_peds()
	local ped_coords = nil
	local closest_dist = 114514
	local this_dist = 0
	local closest_pedid = 0
	if not range then range=114514 end
	for k,v in ipairs(allpeds) do
		ped_coords = get_entity_coords(v)
		this_dist = get_dist(player_coords, ped_coords, true)
		-- check if ped is:
		-- not target
		-- not dead
		-- not player
		-- not self
		-- in range
		-- then, compare the distance with recorded minimum
		if this_dist > 0 and not (v == target)  and (PED.IS_PED_DEAD_OR_DYING(v, true)==0) and (PED.IS_PED_A_PLAYER(v)==0) and not (v == selfpedid) and this_dist < closest_dist and this_dist < range then
			closest_dist = this_dist
			closest_pedid = v
		end
	end
	if not (closest_pedid == 0) then log("get_closest_ped_from_entity: PedID:"..closest_pedid..", Distance:"..closest_dist.." from target "..target) end
	return closest_pedid
end

function get_random_ped_from_entity(target, range)
	local selfpedid = PLAYER.PLAYER_PED_ID()
	local coords = get_entity_coords(target)
	local newpedid = 0
	if newpedid == 0 or newpedid == selfpedid or newpedid == targetid then
		newpedid = PED.GET_RANDOM_PED_AT_COORD(coords.x, coords.y, coords.z, range, range, range, 26)
		if newpedid == 0 or newpedid == selfpedid then
			log("get_random_ped_from_entity: GET_RANDOM_PED_AT_COORD didn't return a ped.")	
			newpedid = 0
		end
	end
	if not (newpedid==0) then log("get_random_ped_from_entity: "..newpedid) end
	return newpedid
end

function make_ped_attack(npc, playerpedid, weaponhash, range)
	entities.request_control(npc, function(handle)
		-- terminate the ped's action if not in a vehicle or fleeing
		local ped_veh = PED.GET_VEHICLE_PED_IS_IN(handle, false)
		if (ped_veh == 0) or (PED.IS_PED_FLEEING(handle) == 1) then
			TASK.CLEAR_PED_TASKS_IMMEDIATELY(handle)
		else
			if not (ped_veh == 0) then
				ENTITY.SET_ENTITY_INVINCIBLE(ped_veh, true)
			end
		end
		-- give weapons to ped
		if type(weaponhash) == "table" then
			for k,v in ipairs(weaponhash) do
				WEAPON.GIVE_WEAPON_TO_PED(handle, v, 9999, true, false)
			end
		else
			WEAPON.GIVE_WEAPON_TO_PED(handle, weaponhash, 9999, true, false)
		end
		-- give ped godmode
		ENTITY.SET_ENTITY_INVINCIBLE(handle, true)
		PED.SET_PED_CAN_RAGDOLL(handle, false)
		PED.SET_PED_CAN_RAGDOLL_FROM_PLAYER_IMPACT(handle, false)
		PED.SET_PED_SUFFERS_CRITICAL_HITS(handle, false)
		-- set ped to be very agressive
		PED.SET_PED_CAN_SWITCH_WEAPON(handle, true)
		PED.SET_PED_ACCURACY(handle, 100.0)
		PED.SET_PED_AS_ENEMY(handle, true)
		PED.SET_PED_COMBAT_ABILITY(handle, 2)
		PED.SET_PED_COMBAT_RANGE(handle, range)
		PED.SET_PED_COMBAT_ATTRIBUTES(handle, 0, true)
		PED.SET_PED_COMBAT_ATTRIBUTES(handle, 1, true)
		PED.SET_PED_COMBAT_ATTRIBUTES(handle, 2, true)
		PED.SET_PED_COMBAT_ATTRIBUTES(handle, 3, true)
		PED.SET_PED_COMBAT_ATTRIBUTES(handle, 5, true)
		PED.SET_PED_COMBAT_ATTRIBUTES(handle, 20, true)
		PED.SET_PED_COMBAT_ATTRIBUTES(handle, 46, true)
		PED.SET_PED_COMBAT_ATTRIBUTES(handle, 52, true)
		PED.SET_PED_COMBAT_ATTRIBUTES(handle, 63, false)
		PED.SET_PED_FLEE_ATTRIBUTES(handle, 0, false)
		TASK.TASK_SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(handle, true)
		TASK.TASK_COMBAT_PED(handle, playerpedid, 0, 16)
	end)
end

function log(text)
	system.log("AngryPeds", tostring(text))
end

function notify(text)
	local str_text = tostring(text)
	system.notify("AngryPeds", str_text, 0, 255, 0, 255)
	system.log("AngryPeds", str_text)
end

--
--
--

function go_angry(target)
	-- do nothing if player offline to avoid self crashing
	if NETWORK.NETWORK_IS_PLAYER_CONNECTED(target) == 0 then return end
	-- get target's PedID
	local selectedPlayer = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(target)
	if PED.IS_PED_DEAD_OR_DYING(selectedPlayer, true)==0 then
		--get a nearby pad
		local npc = get_closest_ped_from_entity(selectedPlayer, PED_SELECT_RANGE)
		if npc==0 then
			notify("Can't find a ped for player "..target)
		else
			if PED.IS_PED_IN_COMBAT(npc, selectedPlayer)==0 then
				make_ped_attack(npc, selectedPlayer, PED_WEAPONS, PED_ATTACK_RANGE)
				notify("You made ped "..npc.." attack player "..target)
			end
		end
	end
end

--
--
--

angrymenu = ui.add_player_submenu("AngryPeds")

ui.add_click_option("Angry NPC", angrymenu, function()
	local target = online.get_selected_player()
	go_angry(target)
end)

angryloop = ui.add_bool_option("Angry NPC Loop", angrymenu, function()
	while ui.get_value(angryloop)==true do
		local target = online.get_selected_player()
		if NETWORK.NETWORK_IS_PLAYER_CONNECTED(target) == 0 then break end
		go_angry(target)
		system.yield(1000)
	end
end)

---
---
---

while true do
	system.yield()
end
