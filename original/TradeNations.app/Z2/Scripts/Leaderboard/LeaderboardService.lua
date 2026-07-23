waxClass{"LeaderboardService", JujuService}

print "Loaded LeaderboardService"

local GetFriendScoresFirstRank = 0
local GetFriendScoresCount = 100

function initWithConfig(self, config)
    self = self.super:initWithConfig_andName(config, "Z2LeaderboardService")
    self.playerScore = {}
    self.scores = {}
    self.leaderboards = {}
    self.resetTime = "None"
    return self
end

function setDefaultUserSelections(self)
    self._index = 1
    self._timespan = "Today"
    self._shouldGetFriendScores = false
end

function index(self)
    return self._index
end

function currentUserUUID(self)
    return self:session():user():uuid()
end

function setIndex(self, index)
    local key = self:currentUserUUID() .. "_index"
    self:persistObject_forKey(index, key)
    self._index = index
end

function timespan(self)
    return self._timespan
end

function setTimespan(self, timespan)
    local key = self:currentUserUUID() .. "_timespan"
    self:persistObject_forKey(timespan, key)
    self._timespan = timespan
end

function shouldGetFriendScores(self)
    return self._shouldGetFriendScores
end

function setShouldGetFriendScores(self, shouldGetFriendScores)
    local number = 0
    if shouldGetFriendScores then number = 1 end
    local key = self:currentUserUUID() .. "_shouldGetFriendScores"
    self:persistObject_forKey(number, key)
    self._shouldGetFriendScores = shouldGetFriendScores
end

function leaderboardPageData(self)
    local data = {
        resetTime = self.resetTime,
        scores = self.scores
    }

    -- Fold the player score into the table too
    for key, value in pairs(self.playerScore) do
        data[key] = value
    end

    return data
end

function loadPreviousUserSelections(self)
    local uuid = self:currentUserUUID()
    local persistentData = self:persistentData()
    for key, value in pairs(persistentData) do
        -- Start at index 0, treat uuid as simple string
        local location = key:find(uuid, 0, true)
        if location ~= nil then
            local strippedKey = key:match("_%a+")
            self[strippedKey] = value
        end
    end

    -- Special case for booleans
    local value = self._shouldGetFriendScores
    if value ~= true and value == 1 then
        value = true
    else
        value = false
    end
    self._shouldGetFriendScores = value

end

function clearPlayerScore(self)
    local user = self:session():user()
    local playerScore = self.playerScore
    playerScore.username = user:username()
    playerScore.player = user:uuid()
    playerScore.rank = "None"
    playerScore.score = 0
end

local function clearTable(table)
    for key, value in pairs(table) do
        table[key] = nil
    end
end

function loadLeaderboardData(self, data)
    local leaderboards = self.leaderboards
    clearTable(leaderboards)
    for index, value in ipairs(data) do
        local item = data[index]
        item.index = index
        leaderboards[index] = item;
    end
end

function loadScoreData(self, data)
    local scores = self.scores
    clearTable(scores)
    for index, value in ipairs(data) do
        scores[index] = data[index]
    end
end

function loadPlayerScoreData(self, data)
    local playerScore = self.playerScore
    if data == nil then
        self:clearPlayerScore()
    else
        for key, value in pairs(data) do
            playerScore[key] = value
        end
    end

    if self._shouldGetFriendScores and type(playerScore.rank) == "number" then
        -- Friends score list does not include me, so add me in
        local scores = self.scores
        scores[(#scores)+1] = playerScore
    end
end

function currentLeaderboard(self)
    return self.leaderboards[self._index]
end

function currentLeaderboardData(self)
    local data = {
        id = self:currentLeaderboard().id,
        timespan = self._timespan
    }
    return data
end

function getLeaderboards(self)
    local request = ZPRequestMessage:requestToService_command_data_target_action(
        "lb",
        "getLeaderboards",
        nil,
        self,
        "getLeaderboardsResponse:"
    )
    self:networkSessionManager():sendRequest(request)
end

function getLeaderboardsResponse(self, response)
    if response:isError() then
        self:postNotification_withError("LeaderboardGetLeaderboardsFailed", response:error())
    else
        local leaderboards = response:data().leaderboards
        self:loadLeaderboardData(leaderboards)
        self:postNotification("LeaderboardDidGetLeaderboards")
    end
end

function getScores(self)
    local command = "getFriendScores"
    local data = self:currentLeaderboardData()
    if not self._shouldGetFriendScores then
        command = "getGlobalScores"
        data.firstRank = GetFriendScoresFirstRank
        data.count = GetFriendScoresCount
    end

    local request = ZPRequestMessage:requestToService_command_data_target_action(
        "lb",
        command,
        data,
        self,
        "getScoresResponse:"
    )
    self:networkSessionManager():sendRequest(request)
end

function getScoresResponse(self, response)
    if response:isError() then
        self:postNotification_withError("LeaderboardGetScoresFailed", response:error())
    else
        local scores = response:data().scores
        self:loadScoreData(scores)
        self:getMyScore()
    end
end

function getMyScore(self)
    local request = ZPRequestMessage:requestToService_command_data_target_action(
        "lb",
        "getMyGlobalScore",
        self:currentLeaderboardData(),
        self,
        "getMyScoreResponse:"
    )
    self:networkSessionManager():sendRequest(request)
end

function getMyScoreResponse(self, response)
    if response:isError() then
        self:postNotification_withError("getMyScore failed", response:error())
    else
        local data = response:data()
        self:loadPlayerScoreData(data.score)
        self.resetTime = data.deadline
        self:postNotification("LeaderboardDidGetScores")
    end
end
