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

-- crie uma screen gui e dentro coloque um text label chamado "Timer"
-- Coloque este LocalScript dentro do ScreenGui que contém o TextLabel "Timer".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local timerEvent = ReplicatedStorage:WaitForChild("RoundTimer")
local timerLabel = script.Parent:WaitForChild("Timer")

timerEvent.OnClientEvent:Connect(function(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local minutes = math.floor(seconds / 60)
    local remainingSeconds = seconds % 60
    timerLabel.Text = string.format("%02d:%02d", minutes, remainingSeconds)
end)

-- created by: KL_ZH7/NULL
