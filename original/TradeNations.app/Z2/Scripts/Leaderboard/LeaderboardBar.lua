waxClass{"LeaderboardBar", LeaderboardBarSuper}

print "Loaded LeaderboardBar"

local function disableButton(button)
    local fadedColor = UIColor:colorWithRed_green_blue_alpha(0, 0, 0, 0.15)
    button:setEnabled(false)
    button:setBackgroundColor(fadedColor)
end

function viewWillShow(self)
    self.super:viewWillShow()
    local leaderboardService = self:owner().leaderboardService
    local leaderboardCount = #(leaderboardService.leaderboards)
    if leaderboardCount <= 1 then
        self:titleButton():setHidden(true)
    end

    local timespan = string.upper(leaderboardService:timespan())
    if string.match(timespan, "DAY") then
        disableButton(self:dailyButton())
    elseif string.match(timespan, "WEEK") then
        disableButton(self:weeklyButton())
    elseif string.match(timespan, "LIFE") then
        disableButton(self:lifetimeButton())
    end
end

function dailyButtonPressed(self, sender)
    local owner = self:owner()
    owner.leaderboardService:setTimespan("Today")
    owner:refreshScores()
end

function weeklyButtonPressed(self, sender)
    local owner = self:owner()
    owner.leaderboardService:setTimespan("ThisWeek")
    owner:refreshScores()
end

function lifetimeButtonPressed(self, sender)
    local owner = self:owner()
    owner.leaderboardService:setTimespan("Lifetime")
    owner:refreshScores()
end

function titleButtonPressed(self, sender)
    self:owner():titleButtonPressed(sender)
end
