waxClass{"LeaderboardHeader", LeaderboardHeaderSuper}

print "Loaded LeaderboardHeader"

local function disableButton(button)
    local fadedColor = UIColor:colorWithRed_green_blue_alpha(0, 0, 0, 0.15)
    button:setEnabled(false)
    button:setBackgroundColor(fadedColor)
end

function viewWillShow(self)
    self.super:viewWillShow()
    local session = self:master():session()
    self:gameTitle():setText(session:gameName())
    self:gameIconView():configureWithData(session:iconUrl())
    local shouldHideFriendButton = self:owner().leaderboardService:shouldGetFriendScores()
    if shouldHideFriendButton then
        disableButton(self:friendsButton())
    else
        disableButton(self:everyoneButton())
    end
end

function helpButtonPressed(self, sender)
    local bodyText = "Leaderboards are a way for you to show off your progress and compete with your friends."
    local data = { title = "Leaderboards", body = bodyText }
    self:master():showDialogViewWithName_data("GenericMessageDialog", data)
end

function friendsButtonPressed(self, sender)
    self:owner():friendsButtonPressed(sender)
end

function everyoneButtonPressed(self, sender)
    self:owner():everyoneButtonPressed(sender)
end
