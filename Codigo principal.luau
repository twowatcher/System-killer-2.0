--[[

          ⠀⠀⠀⣀⣀⣀⣀⣀⠀⠀⠀
        ⠀⣠⣶⣿⣿⣿⣿⣿⣿⣶⣄⠀
       ⢰⣿⣿⣿⡿⠿⠿⢿⣿⣿⣿⡆
       ⣿⣿⣿⠃⠀⠀⠀⠀⢹⣿⣿⣿
       ⢿⣿⣿⣦⣄⠀⠀⣠⣴⣿⣿⡿
        ⠙⢿⣿⣿⣿⣿⣿⣿⡿⠋
           ⠈⠛⠿⠿⠛⠁

        S Y S T E M   K I L L E R
--]]

-- 1. use esse codigo como o sistema principal 
-- cole em 'serverscriptservice':

--========================================================--
--            KILLER SYSTEM 2.0                           --
--      Round, intermission, timer, respawn e vitórias    
--           Made by: KL_ZH7/NULL
--========================================================--

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--========================================================--
-- CONFIGURAÇÃO
--========================================================--

local MIN_PLAYERS = 2
local INTERMISSION = 30
local START_COUNTDOWN = 5
local ROUND_TIME = 120
local RESULT_TIME = 5
local TELEPORT_HEIGHT = 3

local USE_KILLER_CHANCE = true
local KILLER_CHANCE_INCREMENT = 10
local KILLER_MAX_CHANCE = 100

--========================================================--
-- REMOTES
--========================================================--

local function getRemote(name)
	local remote = ReplicatedStorage:FindFirstChild(name)

	if remote and remote:IsA("RemoteEvent") then
		return remote
	end

	if remote then
		warn("[KILLER] " .. name .. " existe, mas não é RemoteEvent.")
		return nil
	end

	remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = ReplicatedStorage
	return remote
end

local timerEvent = getRemote("RoundTimer")
local announceEvent = getRemote("AnunciarKiller")
local finalMessageEvent = getRemote("MensagemFinal")
local stateEvent = getRemote("RoundState")
local countdownEvent = getRemote("RoundCountdown")
local playerStatusEvent = getRemote("RoundPlayerStatus")

local function fireAll(remote, ...)
	if remote then
		remote:FireAllClients(...)
	end
end

local function fireClient(remote, player, ...)
	if remote and player and player.Parent == Players then
		remote:FireClient(player, ...)
	end
end

--========================================================--
-- PERSONAGENS
--========================================================--

local charactersFolder = ServerStorage:FindFirstChild("Personagens")
local survivorsFolder = charactersFolder and charactersFolder:FindFirstChild("Sobreviventes")
local killersFolder = charactersFolder and charactersFolder:FindFirstChild("Assassinos")

if not charactersFolder then
	warn("[KILLER] Crie ServerStorage.Personagens.")
end

if not survivorsFolder then
	warn("[KILLER] Crie ServerStorage.Personagens.Sobreviventes.")
end

if not killersFolder then
	warn("[KILLER] Crie ServerStorage.Personagens.Assassinos.")
end

--========================================================--
-- ESTADO DO SISTEMA
--========================================================--

local state = "Waiting"
local roundRunning = false
local roundFinishing = false
local roundNumber = 0
local currentKiller = nil
local roundParticipants = {}
local killerChances = {}

local function setState(newState)
	if state == newState then
		return
	end
	state = newState
	print("[KILLER] Estado: " .. newState)
	fireAll(stateEvent, newState)
end

local function setTimer(seconds)
	fireAll(timerEvent, math.max(0, math.floor(tonumber(seconds) or 0)))
end

local function disconnectDeaths()
	for _, record in pairs(roundParticipants) do
		if record.deathConnection then
			record.deathConnection:Disconnect()
			record.deathConnection = nil
		end
	end
end

local function clearRoundData()
	disconnectDeaths()
	table.clear(roundParticipants)
	currentKiller = nil
	roundFinishing = false
end

--========================================================--
-- PERSONAGENS E TELEPORTE
--========================================================--

local function getRandomModel(folder)
	if not folder then
		return nil
	end

	local models = {}
	for _, object in ipairs(folder:GetChildren()) do
		if object:IsA("Model") then
			table.insert(models, object)
		end
	end

	if #models == 0 then
		warn("[KILLER] Nenhum Model encontrado em " .. folder:GetFullName())
		return nil
	end

	return models[math.random(1, #models)]
end

local function createCharacter(model)
	if not model then
		return nil
	end

	local character = model:Clone()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not root or not root:IsA("BasePart") then
		warn("[KILLER] O modelo " .. model:GetFullName() .. " precisa de Humanoid e HumanoidRootPart.")
		character:Destroy()
		return nil
	end

	character.PrimaryPart = root
	humanoid.Health = humanoid.MaxHealth
	humanoid.PlatformStand = false
	humanoid.AutoRotate = true
	return character
end

local function transformPlayer(player, model)
	if not player or player.Parent ~= Players then
		return nil
	end

	local newCharacter = createCharacter(model)
	if not newCharacter then
		return nil
	end

	local oldCharacter = player.Character
	local oldRoot = oldCharacter and oldCharacter:FindFirstChild("HumanoidRootPart")
	local oldCFrame = oldRoot and oldRoot.CFrame or CFrame.new(0, 10, 0)

	newCharacter.Name = player.Name
	newCharacter:PivotTo(oldCFrame)
	newCharacter.Parent = workspace
	player.Character = newCharacter

	if oldCharacter and oldCharacter ~= newCharacter then
		oldCharacter:Destroy()
	end

	return newCharacter
end

local function getSpawnParts(spawnType)
	local spawns = workspace:FindFirstChild("Spawns")
	if not spawns then
		return {}
	end

	local names
	if spawnType == "Killer" then
		names = { "Killer", "Assassino" }
	elseif spawnType == "Lobby" then
		names = { "Lobby", "Espera" }
	else
		names = { "Survivors", "Sobreviventes" }
	end

	local folder
	for _, name in ipairs(names) do
		folder = spawns:FindFirstChild(name)
		if folder then
			break
		end
	end

	if not folder then
		return {}
	end

	local parts = {}
	for _, object in ipairs(folder:GetDescendants()) do
		if object:IsA("BasePart") then
			table.insert(parts, object)
		end
	end
	return parts
end

local function teleportPlayer(player, spawnType)
	if not player.Character then
		return false
	end

	local parts = getSpawnParts(spawnType)
	if #parts > 0 then
		local spawnPart = parts[math.random(1, #parts)]
		player.Character:PivotTo(spawnPart.CFrame + Vector3.new(0, TELEPORT_HEIGHT, 0))
		return true
	end

	-- Compatibilidade com o sistema antigo: workspace.1 = sobreviventes, workspace.2 = killer.
	if spawnType == "Killer" or spawnType == "Survivors" then
		local oldSpawnName = spawnType == "Killer" and "2" or "1"
		local oldSpawn = workspace:FindFirstChild(oldSpawnName)
		if oldSpawn and oldSpawn:IsA("BasePart") then
			player.Character:PivotTo(oldSpawn.CFrame + Vector3.new(0, TELEPORT_HEIGHT, 0))
			return true
		end
	end

	warn("[KILLER] Spawn não encontrado para " .. spawnType .. ".")
	return false
end

--========================================================--
-- CHANCE DO KILLER
--========================================================--

local function chooseKiller(playersInRound)
	if #playersInRound == 0 then
		return nil
	end

	if not USE_KILLER_CHANCE then
		return playersInRound[math.random(1, #playersInRound)]
	end

	local totalChance = 0
	for _, player in ipairs(playersInRound) do
		local chance = math.max(killerChances[player.UserId] or 1, 1)
		totalChance += chance
	end

	local chosenValue = math.random() * totalChance
	local accumulated = 0
	for _, player in ipairs(playersInRound) do
		accumulated += math.max(killerChances[player.UserId] or 1, 1)
		if chosenValue <= accumulated then
			return player
		end
	end

	return playersInRound[#playersInRound]
end

local function updateKillerChances(killer)
	for _, player in ipairs(Players:GetPlayers()) do
		if player == killer then
			killerChances[player.UserId] = 1
		else
			local oldChance = killerChances[player.UserId] or 1
			killerChances[player.UserId] = math.min(oldChance + KILLER_CHANCE_INCREMENT, KILLER_MAX_CHANCE)
		end
	end
end

--========================================================--
-- ROUND E VITÓRIA
--========================================================--

local function countAliveSurvivors()
	local count = 0
	for player, record in pairs(roundParticipants) do
		if record.role == "Survivor" and record.alive and player.Parent == Players then
			count += 1
		end
	end
	return count
end

local function getRoundResult()
	local killerRecord = currentKiller and roundParticipants[currentKiller]
	if not killerRecord or not killerRecord.alive or currentKiller.Parent ~= Players then
		return "SOBREVIVENTES GANHARAM"
	end

	if countAliveSurvivors() <= 0 then
		return "KILLER GANHOU"
	end

	return nil
end

-- Declarada antes para poder ser chamada de dentro de monitorDeath e PlayerRemoving.
local finishRound

-- CORREÇÃO: verifica o resultado imediatamente (em vez de esperar até 1s
-- pelo próximo tick do loop principal) e finaliza a rodada na hora.
local function checkRoundEnd()
	if not roundRunning or roundFinishing or state ~= "Playing" then
		return
	end

	local result = getRoundResult()
	if result then
		finishRound(result)
	end
end

local function monitorDeath(player, record)
	local character = record.character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end

	record.deathConnection = humanoid.Died:Connect(function()
		if not roundRunning or state ~= "Playing" or record.left or not record.alive then
			return
		end

		record.alive = false
		fireAll(playerStatusEvent, player.Name, "Dead")
		print("[KILLER] Morreu: " .. player.Name)
		checkRoundEnd()
	end)

	-- CORREÇÃO: se o humanoid já estiver com vida <= 0 no momento em que
	-- conectamos o evento Died, o evento já disparou e nunca detectaríamos
	-- a morte. Trata esse caso manualmente aqui.
	if humanoid.Health <= 0 then
		record.alive = false
		fireAll(playerStatusEvent, player.Name, "Dead")
		print("[KILLER] Já estava morto ao conectar: " .. player.Name)
	end

	return true
end

local function prepareRound(playersInRound, killer)
	setState("Preparing")

	for _, player in ipairs(playersInRound) do
		if player.Parent == Players then
			local isKiller = player == killer
			local modelFolder = isKiller and killersFolder or survivorsFolder
			local model = getRandomModel(modelFolder)

			if not model then
				return false
			end

			local record = {
				role = isKiller and "Killer" or "Survivor",
				alive = true,
				left = false,
				character = nil,
				deathConnection = nil,
			}
			roundParticipants[player] = record
			-- CORREÇÃO: CharacterAutoLoads não existe por Player, é global
			-- (Players.CharacterAutoLoads). Isso é controlado uma única vez
			-- no início do script agora, não por jogador aqui.

			record.character = transformPlayer(player, model)
			if not record.character then
				return false
			end

			teleportPlayer(player, isKiller and "Killer" or "Survivors")
			if not monitorDeath(player, record) then
				return false
			end

			fireAll(playerStatusEvent, player.Name, isKiller and "Killer" or "Survivor")
		end
	end

	local preparedCount = 0
	for player, record in pairs(roundParticipants) do
		local humanoid = record.character and record.character:FindFirstChildOfClass("Humanoid")
		if player.Parent == Players and record.character and humanoid and humanoid.Health > 0 then
			preparedCount += 1
		else
			record.alive = false
		end
	end

	return preparedCount >= MIN_PLAYERS and currentKiller and currentKiller.Parent == Players
end

-- CORREÇÃO: agora também reposiciona o jogador em um spawn de "Lobby" após
-- o reset, se essa pasta existir em workspace.Spawns.Lobby (ou .Espera).
-- Sem isso o personagem podia voltar a existir dentro da própria arena.
local function resetParticipant(player, record)
	if player.Parent ~= Players then
		return
	end

	local ok, errorMessage = pcall(function()
		player:LoadCharacter()
	end)

	if not ok then
		warn("[KILLER] Não foi possível resetar " .. player.Name .. ": " .. tostring(errorMessage))
		return
	end

	-- Aguarda o character carregar antes de teleportar para o lobby.
	task.defer(function()
		if player.Parent == Players and player.Character then
			teleportPlayer(player, "Lobby")
		end
	end)
end

finishRound = function(result)
	if not roundRunning or roundFinishing then
		return
	end

	roundFinishing = true
	setState("Ended")
	fireAll(finalMessageEvent, result)
	setTimer(0)
	task.wait(RESULT_TIME)

	disconnectDeaths()
	for player, record in pairs(roundParticipants) do
		resetParticipant(player, record)
	end

	task.wait(1)
	clearRoundData()
	roundRunning = false
	setState("Waiting")
	setTimer(0)
end

--========================================================--
-- INTERMISSION E COUNTDOWN
--========================================================--

local function runIntermission()
	if #Players:GetPlayers() < MIN_PLAYERS then
		setState("Waiting")
		setTimer(0)
		return false
	end

	setState("Intermission")
	for seconds = INTERMISSION, 1, -1 do
		if #Players:GetPlayers() < MIN_PLAYERS then
			setState("Waiting")
			setTimer(0)
			return false
		end
		setTimer(seconds)
		task.wait(1)
	end

	setTimer(0)
	return true
end

local function runStartCountdown()
	setState("Starting")
	for seconds = START_COUNTDOWN, 1, -1 do
		if #Players:GetPlayers() < MIN_PLAYERS then
			setState("Waiting")
			setTimer(0)
			return false
		end

		fireAll(countdownEvent, seconds)
		setTimer(seconds)
		task.wait(1)
	end

	fireAll(countdownEvent, 0)
	setTimer(0)
	return true
end

--========================================================--
-- EXECUÇÃO DA RODADA
--========================================================--

local function runRound()
	if roundRunning then
		return
	end

	if not runIntermission() or not runStartCountdown() then
		return
	end

	local playersInRound = Players:GetPlayers()
	if #playersInRound < MIN_PLAYERS then
		setState("Waiting")
		return
	end

	roundRunning = true
	roundNumber += 1
	local killer = chooseKiller(playersInRound)
	if not killer then
		roundRunning = false
		setState("Waiting")
		return
	end
	currentKiller = killer
	updateKillerChances(killer)

	print("[KILLER] Round " .. roundNumber .. " | Killer: " .. killer.Name)

	if not prepareRound(playersInRound, killer) then
		finishRound("RODADA CANCELADA")
		return
	end

	-- CORREÇÃO: se algum jogador já morreu durante prepareRound (ex.: humanoid
	-- carregou com Health 0), o resultado pode já estar decidido antes mesmo
	-- de a rodada começar a rodar.
	checkRoundEnd()
	if not roundRunning or roundFinishing then
		return
	end

	fireAll(announceEvent, killer.Name)
	setState("Playing")

	for seconds = ROUND_TIME, 1, -1 do
		if not roundRunning or roundFinishing then
			return
		end

		local result = getRoundResult()
		if result then
			finishRound(result)
			return
		end

		setTimer(seconds)
		task.wait(1)
	end

	if roundRunning then
		finishRound("SOBREVIVENTES GANHARAM")
	end
end

--========================================================--
-- ENTRADA E SAÍDA DE JOGADORES
--========================================================--

Players.PlayerAdded:Connect(function(player)
	killerChances[player.UserId] = killerChances[player.UserId] or 1

	if roundRunning then
		fireClient(playerStatusEvent, player, player.Name, "WaitingForNextRound")
	end

	-- CORREÇÃO: como Players.CharacterAutoLoads está desligado globalmente
	-- (ver LOOP PRINCIPAL), precisamos dar o spawn inicial manualmente.
	if not player.Character then
		player:LoadCharacter()
	end
end)

Players.PlayerRemoving:Connect(function(player)
	killerChances[player.UserId] = nil

	local record = roundParticipants[player]
	if not record then
		return
	end

	record.left = true
	record.alive = false

	-- CORREÇÃO: chama checkRoundEnd() diretamente em vez de task.defer,
	-- já que checkRoundEnd já protege contra chamadas fora de estado válido
	-- e contra finalizações duplicadas (via roundFinishing).
	checkRoundEnd()
end)

for _, player in ipairs(Players:GetPlayers()) do
	killerChances[player.UserId] = killerChances[player.UserId] or 1
end

--========================================================--
-- LOOP PRINCIPAL
--========================================================--

math.randomseed(os.clock() * 100000 + os.time())

-- CORREÇÃO: CharacterAutoLoads é uma propriedade do serviço Players (global),
-- não existe por Player individual. Desligamos aqui uma única vez e
-- controlamos o spawn manualmente com player:LoadCharacter() em
-- PlayerAdded e resetParticipant.
Players.CharacterAutoLoads = false

setState("Waiting")
setTimer(0)

while true do
	if not roundRunning then
		runRound()
		-- CORREÇÃO: sem esse wait, quando não há MIN_PLAYERS suficientes,
		-- runRound() retornava na hora e esse loop rodava sem pausa
		-- nenhuma, disparando milhares de eventos por segundo e
		-- estourando a fila dos RemoteEvents (crash do servidor).
		task.wait(1)
	else
		task.wait(0.25)
	end
end
