waxClass{"LeaderboardPage", LeaderboardPageSuper}

print "Loaded LeaderboardPage"

local function disableButton(button)
    local fadedColor = UIColor:colorWithRed_green_blue_alpha(0, 0, 0, 0.15)
    button:setEnabled(false)
    button:setBackgroundColor(fadedColor)
end

function sortEntriesByRank(self)
    local entries = self:parameters().scores
    table.sort(entries, function(a,b) return a.rank < b.rank end)
    return entries
end

local function convertSecondsToTimeString(seconds)
    local days = math.floor(seconds / 86400)
    if days > 1 then
        return string.format("%d days", days)
    elseif days > 0 then
        return "1 day"
    end

    seconds = seconds - days * 86400
    local hours = math.floor(seconds / 3600)
    if hours > 1 then
        return string.format("%d hours", hours)
    elseif hours > 0 then
        return "1 hour"
    end

    seconds = seconds - hours * 3600
    local minutes = math.floor(seconds / 60)
    if minutes > 1 then
        return string.format("%d minutes", minutes);
    elseif minutes > 0 then
        return "1 minute"
    else
        return "Less than a minute"
    end
end

function setUpResetTime(self)
    local resetTime = self:parameterForKey("resetTime")
    if resetTime then
        if resetTime < 0 then
            self:timeLabel():setText("Missed by")
            resetTime = -resetTime
        end
        resetTime = convertSecondsToTimeString(resetTime)
        self:resetTime():setText(resetTime)
    else
        self:resetTime():superview():setHidden(true)
    end
end

function viewWillShow(self)
    self.super:viewWillShow()
    local scrollView = self:scrollView()
    local scrollViewFrame = scrollView:frame()
    scrollView:enterLoadingState()
    scrollView:setVerticalSpacing(0)
    scrollView:setAlignment(0)

    self:setUpResetTime()

    -- Users shouldn't see zero-based ranks
    local rank = self:parameterForKey("rank")
    if type(rank) == "number" then
        self:rank():setText("" .. rank+1)
    end
    
    local myUsername = self:parameterForKey("username")

    local entries = self:sortEntriesByRank()
    if entries == nil or #entries == 0 then
        local entry = { rank = "None", username = "None", score = 0 }
        scrollView:addViewNamed_withData_owner("LeaderboardPageEntry", entry, self)
    else
        local leaderboardService = self:owner().leaderboardService
        local displayingFriends = leaderboardService:shouldGetFriendScores()
        if displayingFriends then
            for index, entry in ipairs(entries) do
                entry.rank = index
                if entry.username and entry.username == myUsername then
                    self:rank():setText("" .. index)
                end
                scrollView:addViewNamed_withData_owner("LeaderboardPageEntry", entry, self)
            end
        else
            for index, entry in ipairs(entries) do
                -- Users shouldn't see zero-based ranks
                entry.rank = entry.rank + 1
                scrollView:addViewNamed_withData_owner("LeaderboardPageEntry", entry, self)
            end
        end
    end
    scrollView:exitLoadingState()

    -- Resize the parent view based on the scroll view content size
    local contentSize = scrollView:contentSize()
    local sizeDifference = contentSize.height - scrollViewFrame.height
    local parentView = self:view()
    local parentFrame = parentView:frame()
    parentFrame.height = parentFrame.height + sizeDifference
    parentView:setFrame(parentFrame)

    local timespan = string.upper(self:owner().leaderboardService:timespan())
    if string.match(timespan, "TODAY") then
        disableButton(self:currentButton())
        self:currentButtonLabel():setText("Today")
        self:previousButtonLabel():setText("Yesterday")
    elseif string.match(timespan, "YESTERDAY") then
        disableButton(self:previousButton())
        self:currentButtonLabel():setText("Today")
        self:previousButtonLabel():setText("Yesterday")
    elseif string.match(timespan, "THISWEEK") then
        disableButton(self:currentButton())
        self:currentButtonLabel():setText("This Week")
        self:previousButtonLabel():setText("Last Week")
    elseif string.match(timespan, "LASTWEEK") then
        disableButton(self:previousButton())
        self:currentButtonLabel():setText("This Week")
        self:previousButtonLabel():setText("Last Week")
    elseif string.match(timespan, "LIFE") then
        self:resetTime():superview():setHidden(true)
        self:currentButtonLabel():superview():setHidden(true)
        self:previousButtonLabel():superview():setHidden(true)
    end
end

local function toCurrent(timespan)
    if timespan == "Yesterday" then
        return "Today"
    elseif timespan == "LastWeek" then
        return "ThisWeek"
    end
end

local function toPrevious(timespan)
    if timespan == "Today" then
        return "Yesterday"
    elseif timespan == "ThisWeek" then
        return "LastWeek"
    end
end

function convertTimespan(self, convert)
    local leaderboardService = self:owner().leaderboardService
    local timespan = convert(leaderboardService:timespan())
    leaderboardService:setTimespan(timespan)
end

function currentButtonPressed(self, sender)
    self:convertTimespan(toCurrent)
    self:owner():refreshScores()
end

function previousButtonPressed(self, sender)
    self:convertTimespan(toPrevious)
    self:owner():refreshScores()
end
