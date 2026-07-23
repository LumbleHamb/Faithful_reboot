waxClass{"LeaderboardListItem", LeaderboardListItemSuper}

print "Loaded LeaderboardListItem"

function buttonPressed(self, sender)
    local owner = self:owner()
    local index = self:parameterForKey("index")
    owner.leaderboardService:setIndex(index)
    owner:refreshScores()
    owner:dismissedTitleList(sender)
end
