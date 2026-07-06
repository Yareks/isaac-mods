local mymod = RegisterMod("AIsaac",1.0);

local moveX = {0,0,0,0} -- 1 for right, -1 for left
local moveY = {0,0,0,0} -- 1 for down, -1 for up
local shootX = {0,0,0,0} -- 1 for right, -1 for left
local shootY = {0,0,0,0} -- 1 for down, -1 for up
local attackcharged = {false,false,false,false} --check if players charge type weapon is ready to fire
local attackheld = {0,0,0,0} --how long have they been charging an attack
local rockstuckcooldown = {0,0,0,0}
local lastplayerpos = {Vector(0,0),Vector(0,0),Vector(0,0),Vector(0,0)}
local aroundrockdirection = {0,0,0,0}
local incorner = {-1,-1,-1,-1}

local avoidrange = 105
local firerange = 70
local pickupdistance = 0
local enemydistance = 0
local chaserange = 0
local shoottolerance = 35
local bossroom = false
local ignoreenemiesitems = false
local bombcooldown = 0
local highestshopprice = 0
local visitedcrawlspace = false
local greedmodecooldown = 0
local greedmodebuttonpos = Vector(320,400)
local greedexitopen = false
local rockavoidwarmup = 0
local rockavoidcooldowndefault = 35

local playerID = 0

local player1AIenabled = false
local player2AIenabled = true
local player3AIenabled = true
local player4AIenabled = true

local avoidDangers = true
local shootEnemies = true
local shootFires = true
local shootPoops = true
local goaroundrockspits = true
local avoidCorners = true
local avoidotherplayers = true
local followplayer1 = true
 --0 for off, 1 for player1 only, 2 for all ais
local getPickups = 2
local usePillsCards = 2
local getItems = 2
local getTrinkets = 2
local useItems = 2
local pressButtons = 2
local moveToDoors = 2
local bombThings = 2
local usebeggarsandmachines = 2
local goesshopping = 2
local takesdevildeals = 2

local multisettingmin = 0 --setting needs to be higher than this to be applied

debug_text = " "





function ischaractermeleeattacker(player)
    if player:GetPlayerType() == PlayerType.PLAYER_THEFORGOTTEN then return true end
    if player:GetName() == "Moth" then return true end
    if player:GetActiveWeaponEntity() ~= nil then
        local pweapon = player:GetActiveWeaponEntity()
        if pweapon.Type == 8 then
            if pweapon.Variant > 1 and pweapon.Variant < 4 then return true end
            if pweapon.Variant > 8 and pweapon.Variant < 12 then return true end
        end
    end
    return false
end

function mymod:tick()
	mymod:loaddata()
	--check if the current player is set to AI enabled
	playerID = 0
	playerID = Game():GetFrameCount() % Game():GetNumPlayers()
	multisettingmin = 0
	if (playerID == 0 and (player1AIenabled or Isaac.GetChallenge() == Isaac.GetChallengeIdByName("AIsaac"))) or (playerID == 1 and player2AIenabled) or (playerID == 2 and player3AIenabled) or (playerID == 3 and player4AIenabled) then
		local player = Isaac.GetPlayer(playerID);
		--workaround for tainted soul/forgotten
        if REPENTANCE then
            if player:GetPlayerType() == 40 and playerID == 1 and player1AIenabled == false then
                moveX[playerID+1] = 0
                moveY[playerID+1] = 0
                shootX[playerID+1] = 0
                shootY[playerID+1] = 0
                return
            end
        end
        --prevent AI from trying to do stuff that isn't possible (co-op babies are limited)
		local activecharacter = true
		if not InfinityTrueCoopInterface and not REPENTANCE then
			activecharacter = false
		end
        if REPENTANCE and player.Variant == 1 then
            activecharacter = false
        end
		if playerID == 0 then
			activecharacter = true
		end
        if REPENTANCE and player:IsCoopGhost() then
            activecharacter = false
			multisettingmin = 1
        end
        local tempgetPickups = getPickups+0
        local tempusePillsCards = usePillsCards+0
        local tempgetItems = getItems+0
        local tempgetTrinkets = getTrinkets+0
        local tempuseItems = useItems+0
        local tempmoveToDoors = moveToDoors+0
        local tempbombThings = bombThings+0
        local tempusebeggarsandmachines = usebeggarsandmachines+0
        local tempgoesshopping = goesshopping+0
        local temptakesdevildeals = takesdevildeals+0
		if activecharacter == false then
			if getPickups > 1 then
				tempgetPickups = 1
			end
			if usePillsCards > 1 then
				tempusePillsCards = 1
			end
			if getItems > 1 then
				tempgetItems = 1
			end
			if getTrinkets > 1 then
				tempgetTrinkets = 1
			end
			if useItems > 1 then
				tempuseItems = 1
			end
			if moveToDoors > 1 then
				tempmoveToDoors = 1
			end
			if bombThings > 1 then
				tempbombThings = 1
			end
			if usebeggarsandmachines > 1 then
				tempusebeggarsandmachines = 1
			end
			if goesshopping > 1 then
				tempgoesshopping = 1
			end
			if takesdevildeals > 1 then
				temptakesdevildeals = 1
			end
		end
		--check for player1 only settings
		if playerID > 0 then
			multisettingmin = 1
		end
		
		--handle AI behaviour
		ignoreenemiesitems = false
		if Isaac.GetChallenge() == Isaac.GetChallengeIdByName("AIsaac") then
			--give AI some items to help it out
			if player:HasCollectible(185) == false then
				player:AddCollectible(185,0,true)
				player:AddCollectible(138,0,true)
				player:AddCollectible(3,0,true)
				player:AddCollectible(218,0,true)
				player:AddCollectible(242,0,true)
				player:AddCollectible(259,0,true)
				player:AddCollectible(292,0,true)
				if player:HasCollectible(260) == false then
					player:AddCollectible(260,0,true)
				end
			end
		else --give ai players spectral and homing
			if REPENTANCE then
				if player:GetName() ~= "Remiel" and player.FrameCount > 5 then
					player.TearFlags = player.TearFlags | TearFlags.TEAR_SPECTRAL
					player.TearFlags = player.TearFlags | TearFlags.TEAR_HOMING
				end
			else
				if player.TearFlags %2 == 0 and player.FrameCount > 5 and player.ControlsEnabled and player:GetName() ~= "Remiel" then
					player.TearFlags = player.TearFlags + 1
					player.TearFlags = player.TearFlags + 4
				end
			end
		end
		local currentRoom = Game():GetLevel():GetCurrentRoom()
		--use consumables
		if tempusePillsCards > multisettingmin then
			if player:GetPill(0) > 0 then
				local pilleffectID = Game():GetItemPool():GetPillEffect(player:GetPill(0))
				player:UsePill(pilleffectID, player:GetPill(0))
				player:SetPill(0, 0)
			end
			if player:GetCard(0) > 0 and player:GetCard(0) ~= 46 then
				player:UseCard(player:GetCard(0))
				player:SetCard(0, 0)
			end
            --single use pocket actives
            if REPENTANCE and player:GetActiveItem(3) > 0 and player:NeedsCharge(3) == false then
                player:UseActiveItem(player:GetActiveItem(3), 0, 3)
                player:RemoveCollectible(player:GetActiveItem(3), true, 3, true)
            end
		end
		--use items
        if tempuseItems > multisettingmin and (currentRoom:IsClear() == false or currentRoom:GetAliveBossesCount() > 0) then
            if player:GetActiveItem() > 0 and player:NeedsCharge() == false and player:GetActiveCharge() > 0 then
                player:UseActiveItem(player:GetActiveItem(), true, true, true, true)
                player:DischargeActiveItem()
            end
            --use pocket active items
            if REPENTANCE and player:GetActiveItem(2) > 0 and player:NeedsCharge(2) == false then
                player:UseActiveItem(player:GetActiveItem(2), 0, 2)
                player:SetActiveCharge(0, 2)
            end
		end
		--get entity positions and determine actions
		pickupdistance = 9999999999
		enemydistance = 9999999999
		highestshopprice = -1
		moveX[playerID+1] = 0
		moveY[playerID+1] = 0
		shootX[playerID+1] = 0
		shootY[playerID+1] = 0
		local topleft = currentRoom:GetTopLeftPos()
		local bottomright = currentRoom:GetBottomRightPos()
		local topright = Vector(bottomright.X,topleft.Y)
		local bottomleft = Vector(topleft.X,bottomright.Y)
		local tilecount = currentRoom:GetGridSize()
		local keycount = player:GetNumKeys()
		local bombcount = player:GetNumBombs()
		if keycount == 0 and player:HasGoldenKey() then
			keycount = 1
		end
		if player:HasCollectible(380) then
			keycount = player:GetNumCoins()
		end
		if bombcount == 0 and player:HasGoldenBomb() then
			bombcount = 1
		end
		--if in mega satan room move up to start the battle
		if Game():GetLevel():GetCurrentRoomDesc().GridIndex == -1 and currentRoom:GetType() == 5 and player.Position.Y > currentRoom:GetCenterPos().Y then
			moveY[playerID+1] = -1
		end
		--go to another room when clear
		if tempmoveToDoors > multisettingmin then
			if currentRoom:IsClear() and ignoreenemiesitems == false then
				--go through doors
				local angelroom = false
				roomcheckcount = 9999999999
				for i = 0, 7 do
					local door = currentRoom:GetDoor(i)
					if not door then
						--no door at this position
					elseif door:IsRoomType(RoomType.ROOM_CURSE) and currentRoom:GetType() ~= RoomType.ROOM_CURSE and (Game():GetLevel():GetRoomByIdx(door.TargetRoomIndex).VisitedCount > 0 or player:GetHearts() + player:GetSoulHearts() < 6) then
						--dont waste health on curse doors
					elseif door:IsOpen() == false and (door:IsRoomType(RoomType.ROOM_SECRET) or door:IsRoomType(RoomType.ROOM_SUPERSECRET)) then
						--dont go for hidden secret room doors
					else
						if door:IsOpen() or ((door:IsRoomType(RoomType.ROOM_TREASURE) or door:IsRoomType(RoomType.ROOM_LIBRARY) or (tempgoesshopping > multisettingmin and door:IsRoomType(RoomType.ROOM_SHOP))) and keycount > 0) or (door:IsRoomType(RoomType.ROOM_ARCADE) and player:GetNumCoins() > 0) then
							--get door to room visited the least times
							if Game():GetLevel():GetRoomByIdx(door.TargetRoomIndex).VisitedCount <= roomcheckcount or (Game():IsGreedMode() and Game():GetLevel():GetCurrentRoomDesc().GridIndex == 84 and door:IsOpen() and i == 3) or (Game():GetLevel():GetRoomByIdx(door.TargetRoomIndex).VisitedCount == 0 and (door:IsRoomType(RoomType.ROOM_DEVIL) or door:IsRoomType(RoomType.ROOM_ANGEL) or ((door:IsRoomType(RoomType.ROOM_TREASURE) or (tempgoesshopping > multisettingmin and door:IsRoomType(RoomType.ROOM_SHOP))) and (door:IsOpen() or keycount > 0)) or (door:IsRoomType(RoomType.ROOM_ARCADE) and (door:IsOpen() or player:GetNumCoins() > 0)))) then
								roomcheckcount = Game():GetLevel():GetRoomByIdx(door.TargetRoomIndex).VisitedCount
								--go for angel rooms
								if roomcheckcount == 0 and (door:IsRoomType(RoomType.ROOM_ANGEL) or door:IsRoomType(RoomType.ROOM_DEVIL)) then
									roomcheckcount = -5
									angelroom = true
								end
								--go for treasure rooms
								if roomcheckcount == 0 and door:IsRoomType(RoomType.ROOM_TREASURE) and (door:IsOpen() or keycount > 0) then
									roomcheckcount = -5
								end
								--go for arcade rooms
								if roomcheckcount == 0 and door:IsRoomType(RoomType.ROOM_ARCADE) and (door:IsOpen() or player:GetNumCoins() > 0) then
									roomcheckcount = -5
								end
								--go for shops and libraries
								if roomcheckcount == 0 and ((door:IsRoomType(RoomType.ROOM_SHOP) and tempgoesshopping > multisettingmin) or door:IsRoomType(RoomType.ROOM_LIBRARY)) and (door:IsOpen() or keycount > 0) then
									roomcheckcount = -5
								end
								--go for secret rooms
								if roomcheckcount == 0 and (door:IsRoomType(RoomType.ROOM_SECRET) or door:IsRoomType(RoomType.ROOM_SUPERSECRET)) and door:IsOpen() then
									roomcheckcount = -5
								end
								--go for mega satans room
								if roomcheckcount == 0 and Game():GetLevel():GetStage() == 11 and Game():GetLevel():GetCurrentRoomDesc().GridIndex == 84 and door:IsRoomType(RoomType.ROOM_BOSS) then
									roomcheckcount = -5
								end
								--go for greed mode floor exit
								if Game():IsGreedMode() and Game():GetLevel():GetCurrentRoomDesc().GridIndex == 84 and door:IsOpen() and i == 3 and greedmodecooldown < 1 then
									roomcheckcount = -5
									greedexitopen = true
								end
								--move towards chosen door
								local doorpos = door.Position
								local leeway = door.Position:Distance(player.Position)*0.5
								if leeway > 40 then
									leeway = 40
								end
								moveX[playerID+1] = 0
								moveY[playerID+1] = 0
								mymod:simplemovetowards(player.Position, doorpos, leeway)
							end
						end
					end
				end
				--check for crawlspace exit
				if currentRoom:GetType() == 16 then
					visitedcrawlspace = true
					moveX[playerID+1] = -1
					moveY[playerID+1] = -1
				end
				--check for hush door
				if (Game():GetLevel():GetCurrentRoomDesc().VisitedCount > 3 or keycount < 1) and Game():GetLevel():GetStage() == 9 and currentRoom:GetType() ~= RoomType.ROOM_TREASURE then
					mymod:simplemovetowards(player.Position, currentRoom:GetCenterPos().X, 0)
					moveY[playerID+1] = -1
				end
				--go for trapdoor
				if (currentRoom:GetType() == RoomType.ROOM_BOSS and angelroom == false) or (Game():IsGreedMode() and Game():GetLevel():GetCurrentRoomDesc().GridIndex == 110) then
					local trapdooristhere = false
					for g = 1, tilecount do
						if currentRoom:GetGridEntity(g) ~= nil then
							local gridEntity = currentRoom:GetGridEntity(g)
							if gridEntity:GetType() == 17 then
								trapdooristhere = true
							end
						end
					end
					if trapdooristhere then
						local trapdoorpos = currentRoom:GetCenterPos()
						local leeway = trapdoorpos:Distance(player.Position)*0.5
						if leeway > 40 then
							leeway = 40
						end
						moveX[playerID+1] = 0
						mymod:simplemovetowards(player.Position, trapdoorpos, leeway)
						moveY[playerID+1] = 1
						if trapdoorpos.Y < player.Position.Y then
							bossroom = true
						end
						if trapdoorpos.Y > player.Position.Y + 60 then
							bossroom = false
						end
						if bossroom then
							moveY[playerID+1] = -1
						end
					end
				else
					bossroom = false
				end
				--take trapdoor in black market
				if currentRoom:GetType() == RoomType.ROOM_BLACK_MARKET then
					for g = 1, tilecount do
						if currentRoom:GetGridEntity(g) ~= nil then
							local gridEntity = currentRoom:GetGridEntity(g)
							if gridEntity:GetType() == 17 then
								moveX[playerID+1] = 0
								moveY[playerID+1] = 0
								mymod:simplemovetowards(player.Position, gridEntity.Position, 0)
							end
						end
					end
				end
			end
		end
		--check room for poops, rocks and buttons
		if bombcooldown > 0 then
			bombcooldown = bombcooldown - 1
		end
		if (shootPoops and currentRoom:IsClear()) or (tempbombThings > multisettingmin and bombcount > 0 and currentRoom:IsClear()) or (pressButtons > multisettingmin and currentRoom:HasTriggerPressurePlates() and currentRoom:IsClear() == false) or (tempmoveToDoors > multisettingmin and currentRoom:IsClear()) then
			for i = 1, tilecount do
				if currentRoom:GetGridEntity(i) ~= nil then
					local gridEntity = currentRoom:GetGridEntity(i)
					local gridReact = -1
					if currentRoom:IsClear() and shootPoops and gridEntity:GetType() == 14 and gridEntity.State ~= 4 and gridEntity.State ~= 1000 and gridEntity:GetVariant() ~= 1 then
						gridReact = 0
					elseif currentRoom:IsClear() and tempbombThings > multisettingmin and bombcount > 0 and (gridEntity:GetType() == 4 or gridEntity:GetType() == 22) and gridEntity:ToRock() ~= nil and gridEntity.State ~= 2 then
						gridReact = 1
					elseif currentRoom:IsClear() == false and pressButtons > multisettingmin and gridEntity:GetType() == 20 and gridEntity.State ~= 3 then
						gridReact = 2
					elseif currentRoom:IsClear() and tempmoveToDoors > multisettingmin and gridEntity:GetType() == 18 and visitedcrawlspace == false then
						gridReact = 3
					end
					if gridReact > -1 then
						moveX[playerID+1] = 0
						moveY[playerID+1] = 0
						local xdiff = math.abs(gridEntity.Position.X - player.Position.X)
						local ydiff = math.abs((gridEntity.Position.Y+5) - player.Position.Y)
						if xdiff > 45 or ydiff > 45 or gridReact == 3 then
							local temppooppos = gridEntity.Position
							temppooppos.Y = temppooppos.Y+5
							mymod:simplemovetowards(player.Position, temppooppos, 5)
						elseif xdiff < 30 and ydiff < 30 then --dont stand right on top of it
							if xdiff > ydiff then
								if gridEntity.Position.X < player.Position.X then
									moveX[playerID+1] = 1
								else
									moveX[playerID+1] = -1
								end
							else
								if gridEntity.Position.Y+5 < player.Position.Y then
									moveY[playerID+1] = 1
								else
									moveY[playerID+1] = -1
								end
							end
						end
						if gridReact == 0 then --shoot at poops
							if ydiff < shoottolerance and ydiff < xdiff then
								if gridEntity.Position.X > player.Position.X then
									shootX[playerID+1] = 1
								else
									shootX[playerID+1] = -1
								end
							end
							if xdiff < shoottolerance and xdiff < ydiff then
								if gridEntity.Position.Y > player.Position.Y then
									shootY[playerID+1] = 1
								else
									shootY[playerID+1] = -1
								end
							end
							--aim ludovico
							if player:HasWeaponType(WeaponType.WEAPON_LUDOVICO_TECHNIQUE) and player:GetActiveWeaponEntity() ~= nil then
								local ludotear = player:GetActiveWeaponEntity()
								if gridEntity.Position.X > ludotear.Position.X then
									shootX[playerID+1] = 1
								else
									shootX[playerID+1] = -1
								end
								if gridEntity.Position.Y > ludotear.Position.Y then
									shootY[playerID+1] = 1
								else
									shootY[playerID+1] = -1
								end
							end
						--if at a tinted rock bomb it
						elseif gridReact == 1 and bombcooldown < 1 and bombcount > 0 and gridEntity:ToRock() ~= nil and gridEntity.State ~= 2 and gridEntity.Position:Distance(player.Position) < 40 then
							mymod:dropbomb(player)
						end
					end
				end
			end
		end
		--go for greed button
		if Game():IsGreedMode() and Game():GetLevel():GetCurrentRoomDesc().GridIndex == 84 then
			if currentRoom:GetAliveEnemiesCount() == 0 and currentRoom:GetAliveBossesCount() == 0 then
				greedmodecooldown = greedmodecooldown - 1
				if pressButtons > multisettingmin and greedmodecooldown < 1 and greedexitopen == false then
					mymod:simplemovetowards(player.Position, greedmodebuttonpos, 10)
				end
			end
		end
		--check room for relevant entities (enemies, projectiles and pickups)
		local entities = Isaac.GetRoomEntities()
		iteminshop = false
		for ent = 1, #entities do
			local entity = entities[ent]
			if (entity:IsDead() == false or entity.Type == 7) and (entity.Type == 231 and entity.Variant == 700 and entity.SubType == 700) == false and entity.Type ~= 42 and entity.Type ~= 804 and entity.Type ~= 809 then
				local xdiff = math.abs(entity.Position.X - player.Position.X)
				local ydiff = math.abs(entity.Position.Y - player.Position.Y)
				--shoot poops
				if shootPoops and entity.Type == 245 and entity.HitPoints > 1 then
					mymod:simplemovetowards(player.Position, entity.Position, 0)
					if ydiff < shoottolerance and ydiff < xdiff then
						if entity.Position.X > player.Position.X then
							shootX[playerID+1] = 1
						else
							shootX[playerID+1] = -1
						end
					end
					if xdiff < shoottolerance and xdiff < ydiff then
						if entity.Position.Y > player.Position.Y then
							shootY[playerID+1] = 1
						else
							shootY[playerID+1] = -1
						end
					end
					--aim ludovico
					if player:HasWeaponType(WeaponType.WEAPON_LUDOVICO_TECHNIQUE) and player:GetActiveWeaponEntity() ~= nil then
						local ludotear = player:GetActiveWeaponEntity()
						if entity.Position.X > ludotear.Position.X then
							shootX[playerID+1] = 1
						else
							shootX[playerID+1] = -1
						end
						if entity.Position.Y > ludotear.Position.Y then
							shootY[playerID+1] = 1
						else
							shootY[playerID+1] = -1
						end
					end
				end
				--pick up items
				if tempgetPickups > multisettingmin and entity.Type == 5 and ignoreenemiesitems == false and (entity.Variant == 10 and (entity.SubType < 3 or entity.SubType == 5 or entity.SubType == 9) and player:GetHearts() == player:GetEffectiveMaxHearts()) == false and entity:ToPickup():IsShopItem() == false then
					if (entity.Variant == 100 and entity.SubType == 0) == false and (entity.Variant == 50 and entity.SubType == 0) == false and (entity.Variant ~= 51 or (tempbombThings > multisettingmin and entity.Variant == 51 and bombcount > 0 and entity.SubType == 1)) and entity.Variant ~= 52 and entity.Variant ~= 53 and entity.Variant ~= 54 and entity.Variant ~= 58 and (entity.Variant ~= 60 or (entity.Variant == 60 and player:GetNumKeys() > 0 and entity.SubType == 1)) and (entity.Variant == 360 and entity.SubType == 0) == false then
						if (tempusePillsCards <= multisettingmin or player:GetCard(0) > 0) and entity.Variant == 300 then
							--dont get cards or runes
							if entity.Position:Distance(player.Position) < 70 then
								mymod:goaround(player.Position, entity.Position, 35)
							end
						elseif entity.Variant == 300 and entity.SubType == 46 then
							--dont pick up suicide king
							if entity.Position:Distance(player.Position) < 70 then
								mymod:goaround(player.Position, entity.Position, 35)
							end
						elseif (tempusePillsCards <= multisettingmin or player:GetPill(0) > 0) and entity.Variant == 70 then
							--dont get pills
							if entity.Position:Distance(player.Position) < 70 then
								mymod:goaround(player.Position, entity.Position, 35)
							end
						elseif tempgetItems <= multisettingmin and entity.Variant == 100 then
							--dont get passive items
							if entity.Position:Distance(player.Position) < 70 then
								mymod:goaround(player.Position, entity.Position, 35)
							end
						elseif entity.Variant == 90 and (player:GetActiveItem() < 15 or player:NeedsCharge() == false) then
							--dont get batteries
						elseif tempgetItems > multisettingmin and (tempuseItems <= multisettingmin or player:GetActiveItem() > 0) and entity.Variant == 100 and Isaac.GetItemConfig():GetCollectible(entity.SubType).Type == 3 then
							--dont get active items
							if entity.Position:Distance(player.Position) < 70 then
								mymod:goaround(player.Position, entity.Position, 35)
							end
						elseif entity.Variant == 20 and entity.SubType == 6 and (bombcount < 1 or tempbombThings <= multisettingmin) then
							--dont get stuck on sticky nickels
						elseif entity.Variant == 350 and (player:GetTrinket(0) > 0 or tempgetTrinkets <= multisettingmin) then
							--dont go for trinkets if already have one
							if entity.Position:Distance(player.Position) < 70 then
								mymod:goaround(player.Position, entity.Position, 35)
							end
						elseif entity.Variant == 10 and player:CanPickSoulHearts() == false and (entity.SubType == 3 or entity.SubType == 6 or entity.SubType == 8) then
							--dont grab health if full
						elseif entity.Variant == 10 and player:CanPickBoneHearts() == false and entity.SubType == 11 then
							--dont grab health if full
						elseif entity.Variant == 380 and (entity:ToPickup().Touched or (player:CanPickRedHearts() == false and player:GetEffectiveMaxHearts() > 0) or (player:CanPickSoulHearts() == false and player:GetEffectiveMaxHearts() == 0)) then
							--dont go for beds if they cant be used
						elseif entity.Variant == 99 and (player:GetNumCoins() < 1 or entity.SubType == 0) then
							--dont go for paychests if not enough coins
						else
							local distance = entity.Position:Distance(player.Position)
							--get closest item
							if distance < pickupdistance then
								if currentRoom:IsClear() then
									moveX[playerID+1] = 0
									moveY[playerID+1] = 0
								end
								pickupdistance = distance
								if distance > 15 then
									mymod:simplemovetowards(player.Position, entity.Position, 10)
								end
								--let ai move away from paychest to be able to pay more
								if entity.Variant == 99 and entity:GetSprite():IsPlaying("Pay") and entity.Position:Distance(player.Position) < 70 then
									mymod:simplemoveaway(player.Position, entity.Position, 10)
								end
								--bomb stone chests and sticky nickels
								if tempbombThings > multisettingmin and ((entity.Variant == 51 and entity.SubType == 1) or (entity.Variant == 20 and entity.SubType == 6)) and bombcount > 0 and bombcooldown < 1 and distance < 40 then
									mymod:dropbomb(player)
								end
							end
						end
					end
				end
				--buy stuff at shops
				if tempgoesshopping > multisettingmin and entity.Type == 5 and entity:ToPickup():IsShopItem() and entity:ToPickup().Price > -1 then
					local itemprice = entity:ToPickup().Price
					--get most expensive item player can afford
					if entity.Variant == 100 and tempgetItems <= multisettingmin then
						--dont buy items if take items is false
						if entity.Position:Distance(player.Position) < 70 then
							mymod:goaround(player.Position, entity.Position, 35)
							break
						end
					elseif (tempgetItems <= multisettingmin or tempuseItems <= multisettingmin or player:GetActiveItem() > 0) and entity.Variant == 100 and Isaac.GetItemConfig():GetCollectible(entity.SubType).Type == 3 then
						--dont buy active items
						if entity.Position:Distance(player.Position) < 70 then
							mymod:goaround(player.Position, entity.Position, 35)
							break
						end
					elseif entity.Variant == 10 and player:CanPickSoulHearts() == false and (entity.SubType == 3 or entity.SubType == 6 or entity.SubType == 8) then
						--dont buy soul hearts if no room
					elseif entity.Variant == 10 and player:CanPickRedHearts() == false and (entity.SubType < 3 or entity.SubType == 5 or entity.SubType == 9) then
						--dont buy red hearts if no room
					elseif entity.Variant == 90 and (player:GetActiveItem() < 9 or player:NeedsCharge() == false) then
						--dont buy batteries if no active or active fully charged
					elseif itemprice > highestshopprice and itemprice <= player:GetNumCoins() then
						if currentRoom:IsClear() then
							moveX[playerID+1] = 0
							moveY[playerID+1] = 0
						end
						highestshopprice = itemprice
						mymod:simplemovetowards(player.Position, entity.Position, 0)
					end
				end
				--take devil deals
				if entity.Type == 5 and entity:ToPickup().Price < 0 then
					--check for active items
					local takeactiveitem = true
					if entity.Variant == 100 and tempgetItems <= multisettingmin then
						takeactiveitem = false --dont take items if disabled
					elseif entity.Variant == 100 and Isaac.GetItemConfig():GetCollectible(entity.SubType).Type == 3 and (tempuseItems <= multisettingmin or player:GetActiveItem() > 0) then
						takeactiveitem = false --dont take actives if cant use them or already has one
					end
					local itemprice = 0-entity:ToPickup().Price
					if temptakesdevildeals > multisettingmin and itemprice == 3 and player:GetSoulHearts() > 20 and takeactiveitem then
						mymod:simplemovetowards(player.Position, entity.Position, 0)
						if pickupdistance == 9999999999 then
							pickupdistance = 999999
						end
					elseif temptakesdevildeals > multisettingmin and player:GetMaxHearts() > itemprice*4 + 2 and takeactiveitem then
						mymod:simplemovetowards(player.Position, entity.Position, 0)
						if pickupdistance == 9999999999 then
							pickupdistance = 999999
						end
					elseif entity.Position:Distance(player.Position) < 70 then
						--avoid the item to not lose health accidentally
						mymod:goaround(player.Position, entity.Position, 35)
					end
				end
				--use beggars/machines
				if entity.Type == 6 and entity:GetSprite():IsPlaying("Broken") == false and entity:GetSprite():IsFinished("Broken") == false and entity:GetSprite():IsPlaying("CoinJam") == false and entity:GetSprite():IsFinished("CoinJam") == false and entity:GetSprite():IsPlaying("CoinJam2") == false and entity:GetSprite():IsFinished("CoinJam2") == false and entity:GetSprite():IsPlaying("CoinJam3") == false and entity:GetSprite():IsFinished("CoinJam3") == false and entity:GetSprite():IsPlaying("CoinJam4") == false and entity:GetSprite():IsFinished("CoinJam4") == false then
					if entity.Variant == 93 and (entity:GetSprite():IsPlaying("PayPrize") or entity:GetSprite():IsPlaying("PayNothing")) and entity:GetSprite():GetFrame() < 9 then
						--check for dead beggar
					else
						--machines/beggard to avoid
						if entity.Position:Distance(player.Position) < 80 then
							if entity.Variant == 2 or entity.Variant == 5 or entity.Variant == 10 or entity.Variant == 94 then
								mymod:goaround(player.Position, entity.Position, 35)
							end
						end
						--machines/beggars to move towards
						if ((entity.Variant == 1 or entity.Variant == 4 or entity.Variant == 6 or entity.Variant == 8 or entity.Variant == 11) and tempusebeggarsandmachines > multisettingmin and player:GetNumCoins() > 0) or ((entity.Variant == 2 or entity.Variant == 3 or entity.Variant == 5 or entity.Variant == 12) and bombcount > 0 and tempbombThings > multisettingmin) or (tempusebeggarsandmachines > multisettingmin and entity.Variant == 7 and player:GetNumKeys() > 0) or (tempusebeggarsandmachines > multisettingmin and entity.Variant == 9 and player:GetNumBombs() > 0) or (tempusebeggarsandmachines > multisettingmin and entity.Variant == 93 and player:GetSoulHearts() > 0) then
							mymod:simplemovetowards(player.Position, entity.Position, 0)
							if pickupdistance == 9999999999 then
								pickupdistance = 999999
							end
						end
						--machines/beggard to bomb
						if tempbombThings > multisettingmin and entity.Position:Distance(player.Position) < 50 and bombcooldown < 1 and bombcount > 0 then
							if entity.Variant == 2 or entity.Variant == 3 or entity.Variant == 5 or entity.Variant == 12 then
								mymod:dropbomb(player)
							end
						end
						--give shell game beggar space to spawn flies
						if entity.Position:Distance(player.Position) < 70 then
							if entity:GetSprite():IsPlaying("Shell1Prize") or entity:GetSprite():IsPlaying("Shell2Prize") or entity:GetSprite():IsPlaying("Shell3Prize") then
								mymod:simplemoveaway(player.Position, entity.Position, 0)
							end
						end
					end
				end
				--shoot at fires and tnt barrels
				if shootFires and entity.Type == 33 and entity.HitPoints > 1 and entity.Variant < 2 then
					if currentRoom:IsClear() then
						moveX[playerID+1] = 0
						moveY[playerID+1] = 0
					end
					local distance = entity.Position:Distance(player.Position)
					if currentRoom:IsClear() and distance > firerange then
						mymod:simplemovetowards(player.Position, entity.Position, 10)
					end
					if distance < firerange+10 then
						if ydiff < shoottolerance then
							if entity.Position.X > player.Position.X then
								shootX[playerID+1] = 1
							else
								shootX[playerID+1] = -1
							end
						end
						if xdiff < shoottolerance then
							if entity.Position.Y > player.Position.Y then
								shootY[playerID+1] = 1
							else
								shootY[playerID+1] = -1
							end
						end
					end
					--aim ludovico
					if enemydistance == 9999999999 and player:HasWeaponType(WeaponType.WEAPON_LUDOVICO_TECHNIQUE) and player:GetActiveWeaponEntity() ~= nil then
						local ludotear = player:GetActiveWeaponEntity()
						if entity.Position.X > ludotear.Position.X then
							shootX[playerID+1] = 1
						else
							shootX[playerID+1] = -1
						end
						if entity.Position.Y > ludotear.Position.Y then
							shootY[playerID+1] = 1
						else
							shootY[playerID+1] = -1
						end
					end
				end
				--bomb blue/purple fires
				if tempbombThings > multisettingmin and entity.Type == 33 and entity.HitPoints > 1 and entity.Variant > 1 and entity.Variant ~= 4 and bombcooldown < 1 and bombcount > 0 then
					if currentRoom:IsClear() then
						moveX[playerID+1] = 0
						moveY[playerID+1] = 0
					end
					local distance = entity.Position:Distance(player.Position)
					if currentRoom:IsClear() and distance > firerange-20 then
						mymod:simplemovetowards(player.Position, entity.Position, 10)
					end
					if distance < firerange then
						mymod:dropbomb(player)
					end
				end
				--dont run into fires
				if avoidDangers and entity.Type == 33 and entity.HitPoints > 1 then
					local distance = entity.Position:Distance(player.Position)
					if distance < firerange then
						ignoreenemiesitems = true
						if math.abs(entity.Position.X - player.Position.X) > math.abs(entity.Position.Y - player.Position.Y) then
							moveY[playerID+1] = 0
							if entity.Position.X < player.Position.X then
								moveX[playerID+1] = 1
							else
								moveX[playerID+1] = -1
							end
						else
							moveX[playerID+1] = 0
							if entity.Position.Y < player.Position.Y then
								moveY[playerID+1] = 1
							else
								moveY[playerID+1] = -1
							end
						end
					end
				end
				--avoid dangers and shoot at enemies
				if entity.Type == 4 or (entity.Type > 8 and entity.Type < 1000 and entity.Type ~= 17 and entity.Type ~= 42 and entity.Type ~= 33 and entity.Type ~= 292 and entity.Type ~= 667 and entity.Type ~= 804) then
					if ignoreenemiesitems == false and (entity.Type == 4 or entity.HitPoints > 0.5) and entity:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) == false and (entity.Type == 231 and entity.Variant == 2 and entity.SubType == 1) == false then
						local distance = entity.Position:Distance(player.Position)
						--get closest enemy
						if distance < enemydistance then
							if entity:IsVulnerableEnemy() or entity.Type == 27 or entity.Type == 204 then
								enemydistance = distance
							end
							if shootEnemies then
								chaserange = -player.TearHeight * 10.5
								if ischaractermeleeattacker(player) then
									chaserange = 60
								end
								if REPENTANCE and player:HasCollectible(579) then --spirit sword
									chaserange = 60
								end
								--try to stay in shooting range
								if distance > chaserange then
									mymod:simplemovetowards(player.Position, entity.Position, 0)
								end
								if distance > chaserange*0.66 and entity:IsVulnerableEnemy() == false and (entity.Type == 27 or entity.Type == 204) then
									mymod:simplemovetowards(player.Position, entity.Position, 0)
								end
								--move inline to shoot
								if xdiff > ydiff then
									if ydiff > 9 then
										if entity.Position.Y > player.Position.Y then
											moveY[playerID+1] = 1
										else
											moveY[playerID+1] = -1
										end
									end
								else
									if xdiff > 9 then
										if entity.Position.X > player.Position.X then
											moveX[playerID+1] = 1
										else
											moveX[playerID+1] = -1
										end
									end
								end
								--dont get stuck diagonally near enemy
								local directiontoenemy = Vector(xdiff,ydiff):Normalized()
								if math.abs(directiontoenemy.X - directiontoenemy.Y) < 0.45 and distance < avoidrange+30 then
									if xdiff > ydiff then
										moveX[playerID+1] = 0
									else
										moveY[playerID+1] = 0
									end
								end
								--shoot
								if entity:IsVulnerableEnemy() then
									if ydiff < shoottolerance and ydiff < xdiff then
										if entity.Position.X > player.Position.X then
											shootX[playerID+1] = 1
										else
											shootX[playerID+1] = -1
										end
									end
									if xdiff < shoottolerance and xdiff < ydiff then
										if entity.Position.Y > player.Position.Y then
											shootY[playerID+1] = 1
										else
											shootY[playerID+1] = -1
										end
									end
								end
								--aim ludovico
								if player:HasWeaponType(WeaponType.WEAPON_LUDOVICO_TECHNIQUE) and player:GetActiveWeaponEntity() ~= nil then
									local ludotear = player:GetActiveWeaponEntity()
									if entity.Position.X > ludotear.Position.X then
										shootX[playerID+1] = 1
									else
										shootX[playerID+1] = -1
									end
									if entity.Position.Y > ludotear.Position.Y then
										shootY[playerID+1] = 1
									else
										shootY[playerID+1] = -1
									end
								end
							end
							--try not to get hit
							if avoidDangers and entity.Type ~= 245 and entity.Type ~= 302 and (currentRoom:IsClear() == false or (entity.Type ~= 42 and (entity.Type == 44 and entity.Variant == 0) == false and entity.Type ~= 202 and entity.Type ~= 203)) then
								local temprange = avoidrange
								if ischaractermeleeattacker(player) then
									avoidrange = 50
								end
								if player:GetPlayerType() == PlayerType.PLAYER_AZAZEL and player:HasCollectible(118) == false then
									avoidrange = -player.TearHeight*3
								end
								--try to dodge charging enemies
								if distance < avoidrange*2.5 and (math.abs(entity.Velocity.X)>6 or math.abs(entity.Velocity.Y)>6) then
									if math.abs(entity.Velocity.X) > math.abs(entity.Velocity.Y) then
										--vertical dodge
										if (entity.Velocity.X > 0 and entity.Position.X < player.Position.X) or (entity.Velocity.X < 0 and entity.Position.X > player.Position.X) then
											if entity.Position.Y < player.Position.Y then
												moveY[playerID+1] = 1
											else
												moveY[playerID+1] = -1
											end
										end
									else
										--horizontal dodge
										if (entity.Velocity.Y > 0 and entity.Position.Y < player.Position.Y) or (entity.Velocity.Y < 0 and entity.Position.Y > player.Position.Y) then
											if entity.Position.X < player.Position.X then
												moveX[playerID+1] = 1
											else
												moveX[playerID+1] = -1
											end
										end
									end
								end
								--dodge close enemies
								if distance < avoidrange then
									local direction = entity.Velocity:Normalized()
									--check for diagonally moving enemies
									local diagonaldodge = false
									if math.abs(math.abs(direction.X) - math.abs(direction.Y)) < 0.3 then
										if direction.X > 0 then
											if direction.Y > 0 then
												if player.Position.X > entity.Position.X and player.Position.Y > entity.Position.Y then
													diagonaldodge = true
													if xdiff > ydiff then
														moveY[playerID+1] = -1
													else
														moveX[playerID+1] = -1													
													end
												end
											else
												if player.Position.X > entity.Position.X and player.Position.Y < entity.Position.Y then
													diagonaldodge = true
													if xdiff > ydiff then
														moveY[playerID+1] = 1
													else
														moveX[playerID+1] = -1												
													end
												end
											end
										else
											if direction.Y > 0 then
												if player.Position.X < entity.Position.X and player.Position.Y > entity.Position.Y then
													diagonaldodge = true
													if xdiff > ydiff then
														moveY[playerID+1] = -1
													else
														moveX[playerID+1] = 1												
													end
												end
											else
												if player.Position.X < entity.Position.X and player.Position.Y < entity.Position.Y then
													diagonaldodge = true
													if xdiff > ydiff then
														moveY[playerID+1] = 1
													else
														moveX[playerID+1] = 1													
													end
												end
											end
										end
									end
									if diagonaldodge == false then
										if entity.Type ~= 9 or xdiff < ydiff then
											if entity.Position.X < player.Position.X then
												moveX[playerID+1] = 1
											else
												moveX[playerID+1] = -1
											end
										end
										if entity.Type ~= 9 or xdiff > ydiff then
											if entity.Position.Y < player.Position.Y then
												moveY[playerID+1] = 1
											else
												moveY[playerID+1] = -1
											end
										end
									end
								end
								if ischaractermeleeattacker(player) or player:GetPlayerType() == PlayerType.PLAYER_AZAZEL then
									avoidrange = temprange
								end
							end
						end
					end
				end
				--avoid lasers
				if avoidDangers and entity.Type == 7 then
					if entity.Parent == nil or entity.Parent.Index ~= player.Index then
						local startpoint = entity.Position
						local endpoint = entity:ToLaser():GetEndPoint()
						local midpoint = Vector((startpoint.X+endpoint.X)*0.5, (startpoint.Y+endpoint.Y)*0.5)
						local earlypoint = Vector((startpoint.X+midpoint.X)*0.5, (startpoint.Y+midpoint.Y)*0.5)
						local latepoint = Vector((midpoint.X+endpoint.X)*0.5, (midpoint.Y+endpoint.Y)*0.5)
						local closestpoint = Vector(0,0)
						if player.Position:Distance(midpoint) < player.Position:Distance(earlypoint) and player.Position:Distance(midpoint) < player.Position:Distance(latepoint) then
							closestpoint = midpoint
						elseif player.Position:Distance(earlypoint) < player.Position:Distance(latepoint) then
							closestpoint = earlypoint
							if player.Position:Distance(startpoint) < player.Position:Distance(earlypoint) then
								closestpoint = startpoint
							end
						else
							closestpoint = latepoint
							if player.Position:Distance(endpoint) < player.Position:Distance(latepoint) then
								closestpoint = endpoint
							end
						end
						if player.Position:Distance(closestpoint) < 75 then
							mymod:simplemoveaway(player.Position, entity.Position, 0)
						end
					end
				end
                --avoid shop items if not set to shop
                if tempgoesshopping <= multisettingmin and entity.Type == 5 and entity:ToPickup():IsShopItem() and entity:ToPickup().Price > -1 then
                    if entity.Position:Distance(player.Position) < 60 then
                        mymod:goaround(player.Position, entity.Position, 30)
                    end
                end
			end
		end
		--go around rocks if doesnt have flying
		if player.CanFly == false and goaroundrockspits and enemydistance > 1000 then
			rockavoidwarmup = rockavoidwarmup + 1
			if rockavoidwarmup > 20 and (moveX[playerID+1] ~= 0 or moveY[playerID+1] ~= 0) then
				if math.abs(player.Position.X - lastplayerpos[playerID+1].X) < 0.05 and math.abs(player.Position.Y -  lastplayerpos[playerID+1].Y) < 0.05 then
					--once its determined that the current path is blocked select a new direction to move
					--check if it already tried one of the directions and got stuck in the same spot, try different direction
					if (moveX[playerID+1] == 1 and moveY[playerID+1] == 1) then
						if aroundrockdirection[playerID+1] == 1 then
							aroundrockdirection[playerID+1] = 4
						else
							aroundrockdirection[playerID+1] = 1
						end
					elseif moveX[playerID+1] == 1 and moveY[playerID+1] == -1 then
						if aroundrockdirection[playerID+1] == 2 then
							aroundrockdirection[playerID+1] = 3
						else
							aroundrockdirection[playerID+1] = 2
						end
					elseif moveX[playerID+1] == -1 and moveY[playerID+1] == 1 then
						if aroundrockdirection[playerID+1] == 3 then
							aroundrockdirection[playerID+1] = 2
						else
							aroundrockdirection[playerID+1] = 3
						end
					elseif moveX[playerID+1] == -1 and moveY[playerID+1] == -1 then
						if aroundrockdirection[playerID+1] == 4 then
							aroundrockdirection[playerID+1] = 1
						else
							aroundrockdirection[playerID+1] = 4
						end
					elseif moveX[playerID+1] == 1 then
						if aroundrockdirection[playerID+1] == 4 and rockstuckcooldown[playerID+1] < rockavoidcooldowndefault-1 then
							aroundrockdirection[playerID+1] = 2
						elseif aroundrockdirection[playerID+1] == 3 then
							aroundrockdirection[playerID+1] = 4
						else
							aroundrockdirection[playerID+1] = 3
						end
					elseif moveX[playerID+1] == -1 then
						if aroundrockdirection[playerID+1] == 1 and rockstuckcooldown[playerID+1] < rockavoidcooldowndefault-1 then
							aroundrockdirection[playerID+1] = 3
						elseif aroundrockdirection[playerID+1] == 2 then
							aroundrockdirection[playerID+1] = 1
						else
							aroundrockdirection[playerID+1] = 2
						end
					elseif moveY[playerID+1] == 1 then
						if aroundrockdirection[playerID+1] == 3 and rockstuckcooldown[playerID+1] < rockavoidcooldowndefault-1 then
							aroundrockdirection[playerID+1] = 4
						elseif aroundrockdirection[playerID+1] == 1 then
							aroundrockdirection[playerID+1] = 3
						else
							aroundrockdirection[playerID+1] = 1
						end
					elseif moveY[playerID+1] == -1 then
						if aroundrockdirection[playerID+1] == 2 and rockstuckcooldown[playerID+1] < rockavoidcooldowndefault-1 then
							aroundrockdirection[playerID+1] = 1
						elseif aroundrockdirection[playerID+1] == 4 then
							aroundrockdirection[playerID+1] = 2
						else
							aroundrockdirection[playerID+1] = 4
						end
					end
					rockstuckcooldown[playerID+1] = rockavoidcooldowndefault
				end
				--move in the chosen direction get out of stuck position
				--but try not to accidentally leave the room while finding a new path
				if rockstuckcooldown[playerID+1] > 0 then
					if aroundrockdirection[playerID+1] == 1 then
						if player.Position.X - topleft.X > 30 then
							moveX[playerID+1] = -1
						end
						if bottomright.Y - player.Position.Y > 30 then
							moveY[playerID+1] = 1
						end
					elseif aroundrockdirection[playerID+1] == 2 then
						if player.Position.X - topleft.X > 30 then
							moveX[playerID+1] = -1
						end
						if player.Position.Y - topleft.Y > 30 then
							moveY[playerID+1] = -1
						end
					elseif aroundrockdirection[playerID+1] == 3 then
						if bottomright.X - player.Position.X > 30 then
							moveX[playerID+1] = 1
						end
						if bottomright.Y - player.Position.Y > 30 then
							moveY[playerID+1] = 1
						end
					elseif aroundrockdirection[playerID+1] == 4 then
						if bottomright.X - player.Position.X > 30 then
							moveX[playerID+1] = 1
						end
						if player.Position.Y - topleft.Y > 30 then
							moveY[playerID+1] = -1
						end
					end
				end
			end
		else
			rockavoidwarmup = 0
		end
		rockstuckcooldown[playerID+1] = rockstuckcooldown[playerID+1] - 1
		if rockstuckcooldown[playerID+1] < -35 then
			aroundrockdirection[playerID+1] = 0
		end
		if currentRoom:GetFrameCount() < 2 then
			aroundrockdirection[playerID+1] = 0
			rockavoidwarmup = 0
		end
		lastplayerpos[playerID+1] = player.Position
		--dont get stuck in crawlspace
		if currentRoom:GetType() == 16 then
			--BEAST fight
            if REPENTANCE and Game():GetLevel():GetStage() == 13 then
                if player.Position.Y > 400 then
                    moveY[playerID+1] = -1
                end
			elseif pickupdistance > 9999999 then --no items in room
				if Game():GetLevel():GetCurrentRoomDesc().Data.Variant == 1 then --go to black market
					if player.Position.X < 150 and player.Position.Y < 360 then
						moveY[playerID+1] = 1
					end
					if player.Position.X < 480 and player.Position.Y > 340 then
						moveX[playerID+1] = 1
					end
					if player.Position.X > 480 then
						moveY[playerID+1] = -1
					end
					if player.Position.X > 480 and player.Position.Y < 320  then
						moveX[playerID+1] = 1
					end
				else --go back up ladder
					if player.Position.X > 220 and player.Position.Y < 340 then
						moveX[playerID+1] = 1
						moveY[playerID+1] = 1
					end
					if player.Position.X > 220 and player.Position.Y > 340 then
						moveX[playerID+1] = -1
						moveY[playerID+1] = 1
					end
				end
			else --room still has items
				if player.Position.X < 140 then
					moveY[playerID+1] = 1
				end
				if player.Position.Y > 340 and player.Position.X < 490 then
					moveX[playerID+1] = 1
				end
			end
		end
		--avoid black market trapdoor if still going for items
		if currentRoom:GetType() == RoomType.ROOM_BLACK_MARKET and pickupdistance < 9999999999 then
			for g = 1, tilecount do
				if currentRoom:GetGridEntity(g) ~= nil then
					local gridEntity = currentRoom:GetGridEntity(g)
					if gridEntity:GetType() == 17 and player.Position:Distance(gridEntity.Position) < 150 then
						moveY[playerID+1] = 1
					end
				end
			end
		end
		--dont overlap with other players
		if avoidotherplayers and Game():GetNumPlayers() > 1 then
			for i = 0, Game():GetNumPlayers()-1 do
				local otherplayerpos = Isaac.GetPlayer(i).Position
				if i ~= playerID and player.Position:Distance(otherplayerpos) < 40 then
					if player.Position.X > otherplayerpos.X and bottomright.X - player.Position.X > 20 then
						moveX[playerID+1] = 1
					elseif player.Position.X - topleft.X > 20 then
						moveX[playerID+1] = -1
					end
					if player.Position.Y > otherplayerpos.Y and bottomright.Y - player.Position.Y > 20 then
						moveY[playerID+1] = 1
					elseif player.Position.Y - topleft.Y > 20 then
						moveY[playerID+1] = -1
					end
				end
			end
		end
		--avoid spikes and red poops
		if avoidDangers then
			for i = 1, tilecount do
				if currentRoom:GetGridEntity(i) ~= nil then
					local gridEntity = currentRoom:GetGridEntity(i)
					if (((gridEntity:GetType() == 8 or gridEntity:GetType() == 25 or (gridEntity:GetType() == 9 and gridEntity.State == 0)) and player.CanFly == false) or (gridEntity:GetType() == 14 and gridEntity:GetVariant() == 1 and gridEntity.State < 4)) and gridEntity.Position:Distance(player.Position) < 70 then
						if math.abs(gridEntity.Position.X - player.Position.X) > math.abs(gridEntity.Position.Y - player.Position.Y) then
							if gridEntity.Position.X > player.Position.X then
								moveX[playerID+1] = -1
								if gridEntity:GetType() == 14 and gridEntity:GetVariant() == 1 and gridEntity.State < 4 and currentRoom:IsClear() then
									shootX[playerID+1] = 1
								end
							else
								moveX[playerID+1] = 1
								if gridEntity:GetType() == 14 and gridEntity:GetVariant() == 1 and gridEntity.State < 4 and currentRoom:IsClear() then
									shootX[playerID+1] = -1
								end
							end
						else
							if gridEntity.Position.Y > player.Position.Y then
								moveY[playerID+1] = -1
								if gridEntity:GetType() == 14 and gridEntity:GetVariant() == 1 and gridEntity.State < 4 and currentRoom:IsClear() then
									shootY[playerID+1] = 1
								end
							else
								moveY[playerID+1] = 1
								if gridEntity:GetType() == 14 and gridEntity:GetVariant() == 1 and gridEntity.State < 4 and currentRoom:IsClear() then
									shootY[playerID+1] = -1
								end
							end
						end
					end
				end
			end
		end
		--avoid greed mode spiked button
		if Game():IsGreedMode() and Game():GetLevel():GetCurrentRoomDesc().GridIndex == 84 then
			if currentRoom:GetAliveEnemiesCount() > 0 or currentRoom:GetAliveBossesCount() > 0 then
				greedmodecooldown = 150
				if player.Position:Distance(greedmodebuttonpos) < 120 then
					mymod:goaround(player.Position, greedmodebuttonpos, 60)
				end
			end
		end
		--dont get stuck in room corners 
		if avoidCorners and pickupdistance > 75 and currentRoom:IsClear() == false then			
			if player.Position:Distance(topleft) < 60 then
				if incorner[playerID+1] < 0 then
					if math.abs(player.Position.X-topleft.X) > math.abs(player.Position.Y-topleft.Y) then
						incorner[playerID+1] = 1
					else
						incorner[playerID+1] = 3
					end
				end
			elseif player.Position:Distance(topright) < 60 then
				if incorner[playerID+1] < 0 then
					if math.abs(player.Position.X-topleft.X) > math.abs(player.Position.Y-topleft.Y) then
						incorner[playerID+1] = 0
					else
						incorner[playerID+1] = 2
					end
				end
			elseif player.Position:Distance(bottomleft) < 60 then
				if incorner[playerID+1] < 0 then
					if math.abs(player.Position.X-topleft.X) > math.abs(player.Position.Y-topleft.Y) then
						incorner[playerID+1] = 2
					else
						incorner[playerID+1] = 0
					end
				end
			elseif player.Position:Distance(bottomright) < 60 then
				if incorner[playerID+1] < 0 then
					if math.abs(player.Position.X-topleft.X) > math.abs(player.Position.Y-topleft.Y) then
						incorner[playerID+1] = 3
					else
						incorner[playerID+1] = 1
					end
				end
			else
				incorner[playerID+1] = -1
			end
			if incorner[playerID+1] == 0 then
				moveX[playerID+1] = 1
				moveY[playerID+1] = 1
			elseif incorner[playerID+1] == 1 then
				moveX[playerID+1] = -1
				moveY[playerID+1] = 1
			elseif incorner[playerID+1] == 2 then
				moveX[playerID+1] = -1
				moveY[playerID+1] = -1
			elseif incorner[playerID+1] == 3 then
				moveX[playerID+1] = 1
				moveY[playerID+1] = -1
			end
		end
		--if shot a charge attack ready the next one
		if attackheld[playerID+1] < 0 then
			attackheld[playerID+1] = attackheld[playerID+1] + 1
		end
		if attackheld[playerID+1] > 0 then
			attackheld[playerID+1] = attackheld[playerID+1] - 1
		end
		if attackcharged[playerID+1] then
			attackcharged[playerID+1] = false
		end
		--if in cleared room and is not player 1 and does not enter new rooms
		--and there is no other move target then follow player1
		if followplayer1 and currentRoom:IsClear() and playerID > 0 and moveX[playerID+1] == 0 and moveY[playerID+1] == 0 then
			local player1pos = Isaac.GetPlayer(0).Position
			if player1pos:Distance(player.Position) > 120 then
				if player1pos.X > player.Position.X + 40 then
					moveX[playerID+1] = 1
				elseif player1pos.X < player.Position.X - 40 then
					moveX[playerID+1] = -1
				end
				if player1pos.Y > player.Position.Y + 40 then
					moveY[playerID+1] = 1
				elseif player1pos.Y < player.Position.Y - 40 then
					moveY[playerID+1] = -1
				end
			end
		end
        --avoid doors and trapdoors
		if tempmoveToDoors <= multisettingmin then
            for g = 1, tilecount do
                if currentRoom:GetGridEntity(g) ~= nil then
                    local gridEntity = currentRoom:GetGridEntity(g)
                    if gridEntity:GetType() > 15 and gridEntity:GetType() < 19 then
                        --is it close
                        if gridEntity.Position:Distance(player.Position) < 70 then
                            --move away
                            mymod:goaround(player.Position, gridEntity.Position, 55)
                        end
                    end
                end
            end
        end
        --check for mirrored world
        if REPENTANCE and currentRoom:IsMirrorWorld() then
            moveX[playerID+1] = -1*moveX[playerID+1]
            shootX[playerID+1] = -1*shootX[playerID+1]
        end
	end
end

local holdingleft = {false,false,false,false}
local holdingright = {false,false,false,false}
local holdingup = {false,false,false,false}
local holdingdown = {false,false,false,false}
local attackingleft = {false,false,false,false}
local attackingright = {false,false,false,false}
local attackingup = {false,false,false,false}
local attackingdown = {false,false,false,false}
function mymod:keyInput(entity, inputHook, buttonAction)
	for j = 1, Game():GetNumPlayers() do
		if (j == 1 and (player1AIenabled or Isaac.GetChallenge() == Isaac.GetChallengeIdByName("AIsaac"))) or (j == 2 and player2AIenabled) or (j == 3 and player3AIenabled) or (j == 4 and player4AIenabled) then
			local player = Isaac.GetPlayer(j-1)
			if entity ~= nil and entity.Index == player.Index then
                local subplayer = false
                if REPENTANCE then
                    --ignore players inputs if character is not player main character (esau/strawman)
                    if player:GetName() == "Keeper" and Isaac.GetPlayer(0):HasCollectible(667) then
                        subplayer = true
                    elseif player:GetName() == "Esau" or (j > 1 and player.ControllerIndex == 0) then
                        subplayer = true
                    end
                    --workaround for tainted soul/forgotten
                    if player:GetPlayerType() == 40 and player1AIenabled == false then
                        return returnvalue
                    end
                end
				local returnvalue = Input.GetActionValue(buttonAction, player.ControllerIndex)
				if inputHook == InputHook.GET_ACTION_VALUE then
					--move either AI determined direction or player instructed direction
					if buttonAction == 0 then --left
						if returnvalue == 1 then
							holdingleft[j] = true
						else
							holdingleft[j] = false
						end
						if moveX[j] == -1 and (holdingright[j] == false or subplayer) then --move left
							returnvalue = 1
						elseif subplayer then
							returnvalue = 0
						end
					end
					if buttonAction == 1 then --right
						if returnvalue == 1 then
							holdingright[j] = true
						else
							holdingright[j] = false
						end
						if moveX[j] == 1 and (holdingleft[j] == false or subplayer) then --move right
							returnvalue = 1
						elseif subplayer then
							returnvalue = 0
						end
					end
					if buttonAction == 2 then --up
						if returnvalue == 1 then
							holdingup[j] = true
						else
							holdingup[j] = false
						end
						if moveY[j] == -1 and (holdingdown[j] == false or subplayer) then --move up
							returnvalue = 1
						elseif subplayer then
							returnvalue = 0
						end
					end
					if buttonAction == 3 then --down
						if returnvalue == 1 then
							holdingdown[j] = true
						else
							holdingdown[j] = false
						end
						if moveY[j] == 1 and (holdingup[j] == false or subplayer) then --move down
							returnvalue = 1
						elseif subplayer then
							returnvalue = 0
						end
					end
					--shooting directions
					if buttonAction == 4 then --attack left
						if returnvalue > 0.75 then
							attackingleft[j] = true
						else
							attackingleft[j] = false
						end
						if subplayer and shootX[j] == 0 and attackingleft[j] then
							returnvalue = 0
                            player:SetShootingCooldown(1)
						elseif shootX[j] == -1 and (attackingright[j] == false or subplayer) then
							returnvalue = 1
						elseif subplayer then
							returnvalue = 0
						end
					end
					if buttonAction == 5 then --attack right
						if returnvalue > 0.75 then
							attackingright[j] = true
						else
							attackingright[j] = false
						end
						if subplayer and shootX[j] == 0 and attackingright[j] then
							returnvalue = 0
                            player:SetShootingCooldown(1)
						elseif shootX[j] == 1 and (attackingleft[j] == false or subplayer) then
							returnvalue = 1
						elseif subplayer then
							returnvalue = 0
						end
					end
					if buttonAction == 6 then --attack up
						if returnvalue > 0.75 then
							attackingup[j] = true
						else
							attackingup[j] = false
						end
						if subplayer and shootY[j] == 0 and attackingup[j] then
							returnvalue = 0
                            player:SetShootingCooldown(1)
						elseif shootY[j] == -1 and (attackingdown[j] == false or subplayer) then
							returnvalue = 1
						elseif subplayer then
							returnvalue = 0
						end
					end
					if buttonAction == 7 then --attack down
						if returnvalue > 0.75 then
							attackingdown[j] = true
						else
							attackingdown[j] = false
						end
						if subplayer and shootY[j] == 0 and attackingdown[j] then
							returnvalue = 0
                            player:SetShootingCooldown(1)
						elseif shootY[j] == 1 and (attackingup[j] == false or subplayer) then
							returnvalue = 1
						elseif subplayer then
							returnvalue = 0
						end
						--make character face down if charging with no target
						if mymod:isChargeWeapon(player) and shootX[j] == 0 and shootY[j] == 0 and (player:GetName() ~= "Moth" or Game():GetFrameCount() % 60 < 5) then
							returnvalue = 1
						end
					end
					return returnvalue
				end
				--trick game into making attack inputs, any return inside ISACTIONPRESSED is considered input
				--(since attack control above doesn't work unless theres some input)
				--also get if ai is using charge type weapon and how long they've been charging it
				if inputHook == InputHook.IS_ACTION_PRESSED and buttonAction > 3 and buttonAction < 8 and (shootX[j] ~= 0 or shootY[j] ~= 0 or mymod:isChargeWeapon(player)) and attackcharged[j] == false then
					if ischaractermeleeattacker(player) then
						attackheld[j] = attackheld[j] + 1
						if attackheld[j] > 5 then
							attackheld[j] = -5
							if player:GetName() == "Moth" then
								attackheld[j] = -9
							end
						end
					else
						attackheld[j] = attackheld[j] + 1
						if player:HasWeaponType(WeaponType.WEAPON_LUDOVICO_TECHNIQUE) then
							attackheld[j] = 5
						elseif player:HasWeaponType(WeaponType.WEAPON_ROCKETS) and (shootX[j] ~= 0 or shootY[j] ~= 0) then
							if attackheld[j] > 3 and (shootX[j] ~= 0 or shootY[j] ~= 0) then
								attackheld[j] = -5
								return returnvalue
							end
						elseif player:HasWeaponType(WeaponType.WEAPON_BRIMSTONE) then
							if attackheld[j] > player.MaxFireDelay*9 and (shootX[j] ~= 0 or shootY[j] ~= 0) then
								attackheld[j] = -40
								return returnvalue
							end
						elseif player:HasWeaponType(WeaponType.WEAPON_KNIFE) then
							if attackheld[j] > player.MaxFireDelay*25 and (shootX[j] ~= 0 or shootY[j] ~= 0) then
								attackheld[j] = -5
								return returnvalue
							end
						elseif player:HasWeaponType(WeaponType.WEAPON_MONSTROS_LUNGS) then
							if attackheld[j] > player.MaxFireDelay*8 and (shootX[j] ~= 0 or shootY[j] ~= 0) then
								attackheld[j] = -5
								return returnvalue
							end
						elseif player:HasWeaponType(WeaponType.WEAPON_TECH_X) then
							if attackheld[j] > player.MaxFireDelay*13.5 and (shootX[j] ~= 0 or shootY[j] ~= 0) then
								attackheld[j] = -5
								return returnvalue
							end
						elseif player:HasCollectible(69) then
							if attackheld[j] > player.MaxFireDelay*5 and (shootX[j] ~= 0 or shootY[j] ~= 0) then
								attackheld[j] = -5
								return returnvalue
							end
						elseif player:HasCollectible(316) then
							if attackheld[j] > player.MaxFireDelay*10 and (shootX[j] ~= 0 or shootY[j] ~= 0) then
								attackheld[j] = -5
								return returnvalue
							end
						end
					end
					--if attack not fully charged keep charging
					if attackheld[j] < 1 then
						attackcharged[j] = true
					end
					if attackcharged[j] == false then
						return returnvalue
					end
				end
			end
		end
	end
end

--check if ai is using a charge type weapon
function mymod:isChargeWeapon(player)
	if player:HasWeaponType(WeaponType.WEAPON_BRIMSTONE) or player:HasWeaponType(WeaponType.WEAPON_KNIFE) or player:HasWeaponType(WeaponType.WEAPON_MONSTROS_LUNGS) or player:HasWeaponType(WeaponType.WEAPON_TECH_X) then
		return true
	elseif player:HasCollectible(69) or player:HasCollectible(316) then
		return true
	end
	return false
end


--let player enable AI for players in console
function mymod:onCmd(cmd, param)
	if cmd == "player1AI" then
		mymod:loaddata()
		if player1AIenabled then
			player1AIenabled = false
			Isaac.ConsoleOutput("Player1 AI disabled")
		else
			player1AIenabled = true
			Isaac.ConsoleOutput("Player1 AI enabled")
		end
		mymod:savedata()
	end
	if cmd == "player2AI" then
		mymod:loaddata()
		if player2AIenabled then
			player2AIenabled = false
			Isaac.ConsoleOutput("Player2 AI disabled")
		else
			player2AIenabled = true
			Isaac.ConsoleOutput("Player2 AI enabled")
		end
		mymod:savedata()
	end
	if cmd == "player3AI" then
		mymod:loaddata()
		if player3AIenabled then
			player3AIenabled = false
			Isaac.ConsoleOutput("Player3 AI disabled")
		else
			player3AIenabled = true
			Isaac.ConsoleOutput("Player3 AI enabled")
		end
		mymod:savedata()
	end
	if cmd == "player4AI" then
		mymod:loaddata()
		if player4AIenabled then
			player4AIenabled = false
			Isaac.ConsoleOutput("Player4 AI disabled")
		else
			player4AIenabled = true
			Isaac.ConsoleOutput("Player4 AI enabled")
		end
		mymod:savedata()
	end
end


--mod config menu stuff
local MCM = nil
if ModConfigMenu then
    MCM = require("scripts.modconfig")
	MCM.UpdateCategory("Player AI", {
		Info = "AIsaac settings"
	})
	--boolean settings
	MCM.AddSetting("Player AI", { 
		Type = MCM.OptionType.BOOLEAN,
		CurrentSetting = function()
			return player1AIenabled
		end,
		Display = function()
			if player1AIenabled then
				return "Player1 AI is enabled"
			else
				return "Player1 AI is disabled"
			end
		end,
		OnChange = function(currentBool)
			mymod:loaddata()
			player1AIenabled = currentBool
			mymod:savedata()
		end,
		Info = {
			"Enable or disable AI for player1."
		}
	})
	MCM.AddSetting("Player AI", { 
		Type = MCM.OptionType.BOOLEAN,
		CurrentSetting = function()
			return player2AIenabled
		end,
		Display = function()
			if player2AIenabled then
				return "Player2 AI is enabled"
			else
				return "Player2 AI is disabled"
			end
		end,
		OnChange = function(currentBool)
			mymod:loaddata()
			player2AIenabled = currentBool
			mymod:savedata()
		end,
		Info = {
			"Enable or disable AI for player2."
		}
	})
	MCM.AddSetting("Player AI", { 
		Type = MCM.OptionType.BOOLEAN,
		CurrentSetting = function()
			return player3AIenabled
		end,
		Display = function()
			if player3AIenabled then
				return "Player3 AI is enabled"
			else
				return "Player3 AI is disabled"
			end
		end,
		OnChange = function(currentBool)
			mymod:loaddata()
			player3AIenabled = currentBool
			mymod:savedata()
		end,
		Info = {
			"Enable or disable AI for player3."
		}
	})
	MCM.AddSetting("Player AI", { 
		Type = MCM.OptionType.BOOLEAN,
		CurrentSetting = function()
			return player4AIenabled
		end,
		Display = function()
			if player4AIenabled then
				return "Player4 AI is enabled"
			else
				return "Player4 AI is disabled"
			end
		end,
		OnChange = function(currentBool)
			mymod:loaddata()
			player4AIenabled = currentBool
			mymod:savedata()
		end,
		Info = {
			"Enable or disable AI for player4."
		}
	})
	MCM.AddSpace("Player AI")
	MCM.AddSetting("Player AI", {
		Type = MCM.OptionType.BOOLEAN,
		CurrentSetting = function()
			return avoidDangers
		end,
		Display = function()
			local displaystring = "Avoids danger : "
			if avoidDangers then
				return displaystring .. "True"
			else
				return displaystring .. "False"
			end
		end,
		OnChange = function(currentBool)
			mymod:loaddata()
			avoidDangers = currentBool
			mymod:savedata()
		end,
		Info = {
			"Set whether AI tries to avoid danger."
		}
	})
	MCM.AddSetting("Player AI", {
		Type = MCM.OptionType.BOOLEAN,
		CurrentSetting = function()
			return shootEnemies
		end,
		Display = function()
			local displaystring = "Shoots enemies : "
			if shootEnemies then
				return displaystring .. "True"
			else
				return displaystring .. "False"
			end
		end,
		OnChange = function(currentBool)
			mymod:loaddata()
			shootEnemies = currentBool
			mymod:savedata()
		end,
		Info = {
			"Set whether AI tries to shoot enemies."
		}
	})
	MCM.AddSetting("Player AI", {
		Type = MCM.OptionType.BOOLEAN,
		CurrentSetting = function()
			return shootFires
		end,
		Display = function()
			local displaystring = "Shoots fires : "
			if shootFires then
				return displaystring .. "True"
			else
				return displaystring .. "False"
			end
		end,
		OnChange = function(currentBool)
			mymod:loaddata()
			shootFires = currentBool
			mymod:savedata()
		end,
		Info = {
			"Set whether AI tries to shoot fires."
		}
	})
	MCM.AddSetting("Player AI", {
		Type = MCM.OptionType.BOOLEAN,
		CurrentSetting = function()
			return shootPoops
		end,
		Display = function()
			local displaystring = "Shoots poops : "
			if shootPoops then
				return displaystring .. "True"
			else
				return displaystring .. "False"
			end
		end,
		OnChange = function(currentBool)
			mymod:loaddata()
			shootPoops = currentBool
			mymod:savedata()
		end,
		Info = {
			"Set whether AI tries to shoot poops."
		}
	})
	MCM.AddSetting("Player AI", {
		Type = MCM.OptionType.BOOLEAN,
		CurrentSetting = function()
			return goaroundrockspits
		end,
		Display = function()
			local displaystring = "Basic pathfinding : "
			if goaroundrockspits then
				return displaystring .. "True"
			else
				return displaystring .. "False"
			end
		end,
		OnChange = function(currentBool)
			mymod:loaddata()
			goaroundrockspits = currentBool
			mymod:savedata()
		end,
		Info = {
			"Set whether AI tries to go around rocks/pits.",
			"(if it doesn't have flying)"
		}
	})
	MCM.AddSetting("Player AI", {
		Type = MCM.OptionType.BOOLEAN,
		CurrentSetting = function()
			return avoidCorners
		end,
		Display = function()
			local displaystring = "Avoids room corners : "
			if avoidCorners then
				return displaystring .. "True"
			else
				return displaystring .. "False"
			end
		end,
		OnChange = function(currentBool)
			mymod:loaddata()
			avoidCorners = currentBool
			mymod:savedata()
		end,
		Info = {
			"Set whether AI tries to avoid the corners of the room.",
			"(helps prevent it getting stuck in the corner)"
		}
	})
	MCM.AddSetting("Player AI", {
		Type = MCM.OptionType.BOOLEAN,
		CurrentSetting = function()
			return avoidotherplayers
		end,
		Display = function()
			local displaystring = "Personal space : "
			if avoidotherplayers then
				return displaystring .. "True"
			else
				return displaystring .. "False"
			end
		end,
		OnChange = function(currentBool)
			mymod:loaddata()
			avoidotherplayers = currentBool
			mymod:savedata()
		end,
		Info = {
			"Set whether AI moves away from players if it gets too close.",
			"(helps prevent multiple AIs just bunching together)"
		}
	})
	MCM.AddSetting("Player AI", {
		Type = MCM.OptionType.BOOLEAN,
		CurrentSetting = function()
			return followplayer1
		end,
		Display = function()
			local displaystring = "Follow you : "
			if followplayer1 then
				return displaystring .. "True"
			else
				return displaystring .. "False"
			end
		end,
		OnChange = function(currentBool)
			mymod:loaddata()
			followplayer1 = currentBool
			mymod:savedata()
		end,
		Info = {
			"AI follows player 1 when no other targets.",
			"(prevents AI sitting in end of big rooms)"
		}
	})
	--non booolean settings
	MCM.AddSpace("Player AI")
	MCM.AddSetting("Player AI", {
		Type = MCM.OptionType.NUMBER,
		CurrentSetting = function()
			return getPickups
		end,
		Minimum = 0,
		Maximum = 2,
		Display = function()
			local displaystring = "Grabs pickups : "
			if getPickups == 2 then
				return displaystring .. "True"
			elseif getPickups == 1 then
				return displaystring .. "Player1 only"
			else
				return displaystring .. "False"
			end
		end,
		OnChange = function(currentNum)
			mymod:loaddata()
			getPickups = currentNum
			mymod:savedata()
		end,
		Info = {
			"Set whether AI picks up things in the room."
		}
	})
	MCM.AddSetting("Player AI", {
		Type = MCM.OptionType.NUMBER,
		CurrentSetting = function()
			return bombThings
		end,
		Minimum = 0,
		Maximum = 2,
		Display = function()
			local displaystring = "Bombs things : "
			if bombThings == 2 then
				return displaystring .. "True"
			elseif bombThings == 1 then
				return displaystring .. "Player1 only"
			else
				return displaystring .. "False"
			end
		end,
		OnChange = function(currentNum)
			mymod:loaddata()
			bombThings = currentNum
			mymod:savedata()
		end,
		Info = {
			"Set whether AI bombs tinted rocks, some beggars/machines,",
			"stone chests, sticky nickels and blue/purple fires."
		}
	})
	MCM.AddSetting("Player AI", {
		Type = MCM.OptionType.NUMBER,
		CurrentSetting = function()
			return usePillsCards
		end,
		Minimum = 0,
		Maximum = 2,
		Display = function()
			local displaystring = "Uses cards/pills : "
			if usePillsCards == 2 then
				return displaystring .. "True"
			elseif usePillsCards == 1 then
				return displaystring .. "Player1 only"
			else
				return displaystring .. "False"
			end
		end,
		OnChange = function(currentNum)
			mymod:loaddata()
			usePillsCards = currentNum
			mymod:savedata()
		end,
		Info = {
			"Set whether AI picks up and uses cards/runes/pills."
		}
	})
	MCM.AddSetting("Player AI", {
		Type = MCM.OptionType.NUMBER,
		CurrentSetting = function()
			return usebeggarsandmachines
		end,
		Minimum = 0,
		Maximum = 2,
		Display = function()
			local displaystring = "Uses beggars/machines : "
			if usebeggarsandmachines == 2 then
				return displaystring .. "True"
			elseif usebeggarsandmachines == 1 then
				return displaystring .. "Player1 only"
			else
				return displaystring .. "False"
			end
		end,
		OnChange = function(currentNum)
			mymod:loaddata()
			usebeggarsandmachines = currentNum
			mymod:savedata()
		end,
		Info = {
			"Set whether AI tries to use certain beggars and slot machines."
		}
	})
	MCM.AddSetting("Player AI", {
		Type = MCM.OptionType.NUMBER,
		CurrentSetting = function()
			return getItems
		end,
		Minimum = 0,
		Maximum = 2,
		Display = function()
			local displaystring = "Grabs items : "
			if getItems == 2 then
				return displaystring .. "True"
			elseif getItems == 1 then
				return displaystring .. "Player1 only"
			else
				return displaystring .. "False"
			end
		end,
		OnChange = function(currentNum)
			mymod:loaddata()
			getItems = currentNum
			mymod:savedata()
		end,
		Info = {
			"Set whether AI picks up items."
		}
	})
	MCM.AddSetting("Player AI", {
		Type = MCM.OptionType.NUMBER,
		CurrentSetting = function()
			return getTrinkets
		end,
		Minimum = 0,
		Maximum = 2,
		Display = function()
			local displaystring = "Grabs trinkets : "
			if getTrinkets == 2 then
				return displaystring .. "True"
			elseif getTrinkets == 1 then
				return displaystring .. "Player1 only"
			else
				return displaystring .. "False"
			end
		end,
		OnChange = function(currentNum)
			mymod:loaddata()
			getTrinkets = currentNum
			mymod:savedata()
		end,
		Info = {
			"Set whether AI picks up trinkets (if it doesn't have one)."
		}
	})
	MCM.AddSetting("Player AI", {
		Type = MCM.OptionType.NUMBER,
		CurrentSetting = function()
			return useItems
		end,
		Minimum = 0,
		Maximum = 2,
		Display = function()
			local displaystring = "Uses actives : "
			if useItems == 2 then
				return displaystring .. "True"
			elseif useItems == 1 then
				return displaystring .. "Player1 only"
			else
				return displaystring .. "False"
			end
		end,
		OnChange = function(currentNum)
			mymod:loaddata()
			useItems = currentNum
			mymod:savedata()
		end,
		Info = {
			"Set whether AI picks up and uses active items."
		}
	})
	MCM.AddSetting("Player AI", {
		Type = MCM.OptionType.NUMBER,
		CurrentSetting = function()
			return goesshopping
		end,
		Minimum = 0,
		Maximum = 2,
		Display = function()
			local displaystring = "Goes shopping : "
			if goesshopping == 2 then
				return displaystring .. "True"
			elseif goesshopping == 1 then
				return displaystring .. "Player1 only"
			else
				return displaystring .. "False"
			end
		end,
		OnChange = function(currentNum)
			mymod:loaddata()
			goesshopping = currentNum
			mymod:savedata()
		end,
		Info = {
			"Set whether AI goes into shops and buys things."
		}
	})
	MCM.AddSetting("Player AI", {
		Type = MCM.OptionType.NUMBER,
		CurrentSetting = function()
			return takesdevildeals
		end,
		Minimum = 0,
		Maximum = 2,
		Display = function()
			local displaystring = "Devil deals : "
			if takesdevildeals == 2 then
				return displaystring .. "True"
			elseif takesdevildeals == 1 then
				return displaystring .. "Player1 only"
			else
				return displaystring .. "False"
			end
		end,
		OnChange = function(currentNum)
			mymod:loaddata()
			takesdevildeals = currentNum
			mymod:savedata()
		end,
		Info = {
			"Set whether AI takes devil deals."
		}
	})
	MCM.AddSetting("Player AI", {
		Type = MCM.OptionType.NUMBER,
		CurrentSetting = function()
			return pressButtons
		end,
		Minimum = 0,
		Maximum = 2,
		Display = function()
			local displaystring = "Presses buttons : "
			if pressButtons == 2 then
				return displaystring .. "True"
			elseif pressButtons == 1 then
				return displaystring .. "Player1 only"
			else
				return displaystring .. "False"
			end
		end,
		OnChange = function(currentNum)
			mymod:loaddata()
			pressButtons = currentNum
			mymod:savedata()
		end,
		Info = {
			"Set whether AI tries to stand on pressure plates."
		}
	})
	MCM.AddSetting("Player AI", {
		Type = MCM.OptionType.NUMBER,
		CurrentSetting = function()
			return moveToDoors
		end,
		Minimum = 0,
		Maximum = 2,
		Display = function()
			local displaystring = "Changes rooms : "
			if moveToDoors == 2 then
				return displaystring .. "True"
			elseif moveToDoors == 1 then
				return displaystring .. "Player1 only"
			else
				return displaystring .. "False"
			end
		end,
		OnChange = function(currentNum)
			mymod:loaddata()
			moveToDoors = currentNum
			mymod:savedata()
		end,
		Info = {
			"Set whether AI moves to a different room if the room is clear.",
			"(and there's nothing of interest to it in the room)"
		}
	})
end

function mymod:savedata()
	local str = ""
	--get boolean settings
	if player1AIenabled then
		str = str .. "T"
	else
		str = str .. "F"
	end
	if player2AIenabled then
		str = str .. "T"
	else
		str = str .. "F"
	end
	if player3AIenabled then
		str = str .. "T"
	else
		str = str .. "F"
	end
	if player4AIenabled then
		str = str .. "T"
	else
		str = str .. "F"
	end
	if avoidDangers then
		str = str .. "T"
	else
		str = str .. "F"
	end
	if shootEnemies then
		str = str .. "T"
	else
		str = str .. "F"
	end
	if shootFires then
		str = str .. "T"
	else
		str = str .. "F"
	end
	if shootPoops then
		str = str .. "T"
	else
		str = str .. "F"
	end
	if goaroundrockspits then
		str = str .. "T"
	else
		str = str .. "F"
	end
	if avoidCorners then
		str = str .. "T"
	else
		str = str .. "F"
	end
	if avoidotherplayers then
		str = str .. "T"
	else
		str = str .. "F"
	end
	if followplayer1 then
		str = str .. "T"
	else
		str = str .. "F"
	end
	--get non boolean settings
	str = str .. getPickups
	str = str .. usePillsCards
	str = str .. getItems
	str = str .. getTrinkets
	str = str .. useItems 
	str = str .. pressButtons
	str = str .. moveToDoors
	str = str .. bombThings 
	str = str .. usebeggarsandmachines
	str = str .. goesshopping 
	str = str .. takesdevildeals 
	Isaac.SaveModData(mymod, str)
end

function mymod:loaddata()
	local str = Isaac.LoadModData(mymod)
	if str == nil or str == "" or str:len() < 22 then
		mymod:savedata()
	else
		player1AIenabled = false
		player2AIenabled = true
		player3AIenabled = true
		player4AIenabled = true
		avoidDangers = true
		shootEnemies = true
		shootFires = true
		shootPoops = true
		goaroundrockspits = true
		avoidCorners = true
		avoidotherplayers = true
		followplayer1 = true
		getPickups = 2
		usePillsCards = 2
		getItems = 2
		getTrinkets = 2
		useItems = 2
		pressButtons = 2
		moveToDoors = 2
		bombThings = 2
		usebeggarsandmachines = 2
		goesshopping = 2
		takesdevildeals = 2
		local index = 1
		if string.sub(str, index, index) == "T" then
			player1AIenabled = true
		end
		index = index + 1
		if string.sub(str, index, index) == "F" then
			player2AIenabled = false
		end
		index = index + 1
		if string.sub(str, index, index) == "F" then
			player3AIenabled = false
		end
		index = index + 1
		if string.sub(str, index, index) == "F" then
			player4AIenabled = false
		end
		index = index + 1
		if string.sub(str, index, index) == "F" then
			avoidDangers = false
		end
		index = index + 1
		if string.sub(str, index, index) == "F" then
			shootEnemies = false
		end
		index = index + 1
		if string.sub(str, index, index) == "F" then
			shootFires = false
		end
		index = index + 1
		if string.sub(str, index, index) == "F" then
			shootPoops = false
		end
		index = index + 1
		if string.sub(str, index, index) == "F" then
			goaroundrockspits = false
		end
		index = index + 1
		if string.sub(str, index, index) == "F" then
			avoidCorners = false
		end
		index = index + 1
		if string.sub(str, index, index) == "F" then
			avoidotherplayers = false
		end
		index = index + 1
		if string.sub(str, index, index) == "F" then
			followplayer1 = false
		end
		index = index + 1
		getPickups = tonumber(string.sub(str, index, index))
		index = index + 1
		usePillsCards = tonumber(string.sub(str, index, index))
		index = index + 1
		getItems = tonumber(string.sub(str, index, index))
		index = index + 1
		getTrinkets = tonumber(string.sub(str, index, index))
		index = index + 1
		useItems = tonumber(string.sub(str, index, index))
		index = index + 1
		pressButtons = tonumber(string.sub(str, index, index))
		index = index + 1
		moveToDoors = tonumber(string.sub(str, index, index))
		index = index + 1
		bombThings = tonumber(string.sub(str, index, index))
		index = index + 1
		usebeggarsandmachines = tonumber(string.sub(str, index, index))
		index = index + 1
		goesshopping = tonumber(string.sub(str, index, index))
		index = index + 1
		takesdevildeals = tonumber(string.sub(str, index, index))
		if takesdevildeals == nil then
			takesdevildeals = 2
		end
	end
end

function mymod:newfloor()
	visitedcrawlspace = false
	greedexitopen = false
end

--use when ai should avoid touching something but still keep going in the same general direction
--if player is less than mindistance away from the target forget about general direction and just move away
function mymod:goaround(playerpos, avoidposition, mindistance)
	local Xcheck = math.abs(playerpos.X - avoidposition.X)
	local Ycheck = math.abs(playerpos.Y - avoidposition.Y)
	if playerpos:Distance(avoidposition) < mindistance then
		mymod:simplemoveaway(playerpos, avoidposition, 10)
	else
		if moveX[playerID+1] == -1 and moveY[playerID+1] == -1 then
			if Xcheck > Ycheck then
				moveX[playerID+1] = 1
			else
				moveY[playerID+1] = 1
			end
		elseif moveX[playerID+1] == 1 and moveY[playerID+1] == -1 then
			if Xcheck < Ycheck then
				moveY[playerID+1] = 1
			else
				moveX[playerID+1] = -1
			end
		elseif moveX[playerID+1] == 1 and moveY[playerID+1] == 1 then
			if Xcheck > Ycheck then
				moveX[playerID+1] = -1
			else
				moveY[playerID+1] = -1
			end
		elseif moveX[playerID+1] == -1 and moveY[playerID+1] == 1 then
			if Xcheck < Ycheck then
				moveY[playerID+1] = -1
			else
				moveX[playerID+1] = 1
			end
		elseif moveX[playerID+1] == -1 then
			if playerpos.Y < avoidposition.Y then
				moveY[playerID+1] = -1
			else
				moveY[playerID+1] = 1
			end
		elseif moveY[playerID+1] == -1 then
			if playerpos.X < avoidposition.X then
				moveX[playerID+1] = -1
			else
				moveX[playerID+1] = 1
			end
		elseif moveX[playerID+1] == 1 then
			if playerpos.Y < avoidposition.Y then
				moveY[playerID+1] = -1
			else
				moveY[playerID+1] = 1
			end
		elseif moveY[playerID+1] == 1 then
			if playerpos.X < avoidposition.X then
				moveX[playerID+1] = -1
			else
				moveX[playerID+1] = 1
			end
		end
	end
end

--have ai drop a bomb
function mymod:dropbomb(player)
	Isaac.Spawn(4, 0, 0, player.Position, player.Velocity*0.33, nil);
	player:AddBombs(-1)
	bombcooldown = 60
end

--make ai move towards something, diagonally first then straight line
--the lower the tolerance the more accurate the player tries to be
function mymod:simplemovetowards(playerpos, targetposition, tolerance)
	if targetposition.X > playerpos.X + tolerance then
		moveX[playerID+1] = 1
	elseif targetposition.X < playerpos.X - tolerance then
		moveX[playerID+1] = -1
	end
	if targetposition.Y > playerpos.Y + tolerance then
		moveY[playerID+1] = 1
	elseif targetposition.Y < playerpos.Y - tolerance then
		moveY[playerID+1] = -1
	end
end

--make ai move away from something, diagonally first then straight line
--the lower the tolerance the more accurate the player tries to be
function mymod:simplemoveaway(playerpos, avoidposition, tolerance)
	if avoidposition.X > playerpos.X + tolerance then
		moveX[playerID+1] = -1
	elseif avoidposition.X < playerpos.X - tolerance then
		moveX[playerID+1] = 1
	end
	if avoidposition.Y > playerpos.Y + tolerance then
		moveY[playerID+1] = -1
	elseif avoidposition.Y < playerpos.Y - tolerance then
		moveY[playerID+1] = 1
	end
end


function mymod:debuginfo()
	Isaac.RenderText(debug_text, 50, 50, 0, 255, 0, 255)
end


mymod:AddCallback(ModCallbacks.MC_INPUT_ACTION , mymod.keyInput)
mymod:AddCallback(ModCallbacks.MC_POST_UPDATE, mymod.tick);
mymod:AddCallback(ModCallbacks.MC_EXECUTE_CMD, mymod.onCmd);
mymod:AddCallback(ModCallbacks.MC_POST_RENDER, mymod.debuginfo);
mymod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, mymod.newfloor);