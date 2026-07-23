waxClass{"Leaderboard", LeaderboardSuper}

print "Loaded Leaderboard"

function viewWillShow(self)
	self.super:viewWillShow()
    self.leaderboardService = self:master():leaderboardService()
    self.leaderboardService:setDefaultUserSelections()
    self.leaderboardService:loadPreviousUserSelections()
    self:registerForNotifications()
    self:scrollView():enterLoadingState()
    self.leaderboardService:getLeaderboards()
end

function leaderboardService(self)
    return self.leaderboardService
end

function registerForNotifications(self)
    local notificationCenter = NSNotificationCenter:defaultCenter()

    notificationCenter:addObserver_selector_name_object(
        self,
        "didGetLeaderboardsNotification",
        "LeaderboardDidGetLeaderboards",
        nil
    )

    notificationCenter:addObserver_selector_name_object(
        self,
        "didGetScoresNotification",
        "LeaderboardDidGetScores",
        nil
    )

    notificationCenter:addObserver_selector_name_object(
        self,
        "requestFailedNotification",
        "LeaderboardGetLeaderboardsFailed",
        nil
    )

    notificationCenter:addObserver_selector_name_object(
        self,
        "requestFailedNotification",
        "LeaderboardGetScoresFailed",
        nil
    )
end

function populateTitleList(self)
    local scrollView = self:titleListScrollView()
    scrollView:enterLoadingState()
    scrollView:removeContentViews()

    local leaderboards = self.leaderboardService.leaderboards
    for index, leaderboard in ipairs(leaderboards) do
        scrollView:addViewNamed_withData_owner("LeaderboardListItem", leaderboard, self)
    end

    scrollView:exitLoadingState()
end

function populateScrollView(self)
    local scrollView = self:scrollView()
    scrollView:setVerticalSpacing(0)
    scrollView:removeContentViews()
    scrollView:addViewNamed_withData_owner("LeaderboardHeader", nil, self)

    local leaderboardService = self.leaderboardService
    scrollView:addViewNamed_withData_owner(
        "LeaderboardBar",
        leaderboardService:currentLeaderboard(),
        self
    )

    scrollView:addViewNamed_withData_owner(
        "LeaderboardPage",
        leaderboardService:leaderboardPageData(),
        self
    )

    scrollView:exitLoadingState()
end

function refreshScores(self)
    self:scrollView():enterLoadingStateAnimated(false)
    self.leaderboardService:getScores()
end

function friendsButtonPressed(self, sender)
    local leaderboardService = self.leaderboardService
    if not leaderboardService:shouldGetFriendScores() then
        leaderboardService:setShouldGetFriendScores(true)
        self:refreshScores()
    end
end

function everyoneButtonPressed(self, sender)
    local leaderboardService = self.leaderboardService
    if leaderboardService:shouldGetFriendScores() then
        leaderboardService:setShouldGetFriendScores(false)
        self:refreshScores()
    end
end

local function beginAnimationsWithContext(context)
    UIView:beginAnimations_context(nil, context)
    UIView:setAnimationBeginsFromCurrentState(true)
    UIView:setAnimationDuration(0.15)
    UIView:setAnimationCurve(UIViewAnimationCurveEaseInOut)
end

function titleButtonPressed(self, sender)
    local titleListPopup = self:titleListPopup()
    beginAnimationsWithContext(titleListPopup)
    UIView:setAnimationDelegate(self)
    UIView:setAnimationDidStopSelector("populateTitleList")
    titleListPopup:setAlpha(1.0)
    UIView:commitAnimations()
end

function dismissedTitleList(self, sender)
    local titleListPopup = self:titleListPopup()
    beginAnimationsWithContext(titleListPopup)
    titleListPopup:setAlpha(0.0)
    UIView:commitAnimations()
    self:titleListScrollView():removeContentViews()
end

function didGetLeaderboardsNotification(self, notification)
    self:populateTitleList()
    self:refreshScores()
end

function didGetScoresNotification(self, notification)
    self:populateScrollView()
end

function requestFailedNotification(self, notification)
    self:master():showSimpleError(notification:userInfo():objectForKey("description"))
end

function getFakeLeaderboards(self)
    self.leaderboards = {
        {
            id = "tn-gold",
            displayName = "Gold Earned",
            timespans = {
                "Today",
                "Yesterday",
                "This Week",
                "Last Week",
                "Lifetime"
            },
            decreasing = true
        },
        {
            id = "tn-sheep",
            displayName = "Sheep Fluffed",
            timespans = {
                "Today",
                "Yesterday",
                "This Week"
            },
            decreasing = true
        },
        {
            id = "tn-trades",
            displayName = "Trades Completed",
            timespans = {
                "Today",
                "Yesterday"
            },
            decreasing = true
        },
        {
            id = "tn-horses",
            displayName = "Horses Mounted",
            timespans = {
                "Today",
                "Yesterday"
            },
            decreasing = true
        },
        {
            id = "tn-cats",
            displayName = "Cats Petted",
            timespans = {
                "Today",
                "Yesterday"
            },
            decreasing = true
        },
        {
            id = "tn-lumber",
            displayName = "Lumber Chopped",
            timespans = {
                "Today",
                "Yesterday"
            },
            decreasing = true
        },
        {
            id = "tn-baker",
            displayName = "Cookies Baked",
            timespans = {
                "Lifetime"
            },
            decreasing = true
        }
    }
    self:getFakeScores()
end

function getFakeMyScore(self)
    self.score.username = "UrbanHouseplantFace5000"
    self.score.player = ";lkdfjalkfjasl;kjdf;lk"
    self.score.rank = "37"
    self.score.score = "278"
end

function getFakeScores(self)
    if self.shouldGetFriendScores then
        self:getFakeFriendScores()
    else
        self:getFakeGlobalScores()
    end
    self:getFakeMyScore()
    self:populateScrollView()
end

function getFakeGlobalScores(self)
    self.score.otherScores = {
        {
            username = "Vexxed",
            player = ";lkdfjalkfjasl;kjdf;lk",
            rank = "1",
            score = "99999999"
        },
        {
            username = "tomh",
            player = ";lkdfjalkfjasl;kjdf;lk",
            rank = "2",
            score = "9181982"
        },
        {
            username = "Dracko22",
            player = ";lkdfjalkfjasl;kjdf;lk",
            rank = "3",
            score = "8123123"
        },
        {
            username = "Dannz0rz",
            player = ";lkdfjalkfjasl;kjdf;lk",
            rank = "4",
            score = "872387"
        },
        {
            username = "StockOption",
            player = ";lkdfjalkfjasl;kjdf;lk",
            rank = "5",
            score = "791231"
        },
        {
            username = "Fazu",
            player = ";lkdfjalkfjasl;kjdf;lk",
            rank = "6",
            score = "639893"
        },
        {
            username = "Area51Official",
            player = ";lkdfjalkfjasl;kjdf;lk",
            rank = "7",
            score = "590898"
        }
    }
end

function getFakeFriendScores(self)
    self.score.otherScores = {
        {
            username = "Vexxed",
            player = ";lkdfjalkfjasl;kjdf;lk",
            rank = "1",
            score = "99999999"
        },
        {
            username = "tomh",
            player = ";lkdfjalkfjasl;kjdf;lk",
            rank = "2",
            score = "9181982"
        },
        {
            username = "Dannz0rz",
            player = ";lkdfjalkfjasl;kjdf;lk",
            rank = "4",
            score = "872387"
        },
        {
            username = "Fazu",
            player = ";lkdfjalkfjasl;kjdf;lk",
            rank = "6",
            score = "639893"
        }
    }
end
