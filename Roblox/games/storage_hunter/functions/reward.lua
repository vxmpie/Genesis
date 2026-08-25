local Reward = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

Reward.Status = {
    Daily = 0,
    Achievements = 0,
    Collections = 0,
    Museum = 0,
    Meteors = 0,
    ClubQuests = 0,
    CowTrades = 0,
    MarketRolls = 0,
    DrinksBought = 0,
    StaffHired = 0
}

local function getEventsFolder()
    return ReplicatedStorage:FindFirstChild("Events")
end

function Reward.Init(Config, DB)
    task.spawn(function()
        while task.wait(2) do
            if not Config.Get("StopAllAutomation", false) then
                local events = getEventsFolder()
                if events then
                    if Config.Get("AutoClaimDailyReward", true) then
                        pcall(function()
                            local daily = events:FindFirstChild("DailyReward")
                            local claim = daily and daily:FindFirstChild("ClaimDailyReward")
                            if claim then
                                claim:InvokeServer()
                                Reward.Status.Daily = Reward.Status.Daily + 1
                            end
                        end)
                    end

                    if Config.Get("AutoClaimAchievements", true) then
                        pcall(function()
                            local ach = events:FindFirstChild("Achievements")
                            local claimAch = ach and ach:FindFirstChild("ClaimAchievement")
                            if claimAch then
                                claimAch:InvokeServer()
                                Reward.Status.Achievements = Reward.Status.Achievements + 1
                            end
                        end)
                    end

                    if Config.Get("AutoClaimMuseumRewards", true) then
                        pcall(function()
                            local museum = events:FindFirstChild("Museum")
                            local claimGifts = museum and museum:FindFirstChild("ClaimGifts")
                            if claimGifts then
                                claimGifts:InvokeServer()
                                Reward.Status.Museum = Reward.Status.Museum + 1
                            end
                        end)
                    end

                    if Config.Get("AutoClaimClubQuests", true) then
                        pcall(function()
                            local club = events:FindFirstChild("Club")
                            local claimClub = club and club:FindFirstChild("ClaimQuest")
                            if claimClub then
                                claimClub:InvokeServer()
                                Reward.Status.ClubQuests = Reward.Status.ClubQuests + 1
                            end
                        end)
                    end

                    if Config.Get("AutoSubmitCows", false) then
                        pcall(function()
                            local alien = events:FindFirstChild("AlienCowTrade") or events:FindFirstChild("AlienInvasion")
                            local submitCow = alien and alien:FindFirstChild("SubmitCow")
                            if submitCow then
                                submitCow:FireServer()
                                Reward.Status.CowTrades = Reward.Status.CowTrades + 1
                            end
                        end)
                    end

                    if Config.Get("AutoBuyLuckEnergyDrinks", false) then
                        pcall(function()
                            local energyShop = events:FindFirstChild("EnergyShop")
                            local buyDrink = energyShop and energyShop:FindFirstChild("BuyEnergyDrink")
                            if buyDrink then
                                buyDrink:InvokeServer("Luck Drink 1")
                                Reward.Status.DrinksBought = Reward.Status.DrinksBought + 1
                            end
                        end)
                    end
                end
            end
        end
    end)
end

return Reward
