waxClass{"NavigationBar", NavigationBarSuper}

print "Loaded NavigationBar"

-- Local constants
local NavigationBarFadeAlpha = 0.15

-- These should probably be defined elsewhere
local Z2UserRegistrationSourceZ2Live = 0
local Z2UserRegistrationSourceFacebook = 1

-- TODO: Put these in the Z2UIManager class table and require it
local Z2UIMBackgroundViewLayer = "BackgroundLayer"
local Z2UIMBaseViewLayer = "BaseLayer"
local Z2UIMNavigationViewLayer = "NavigationLayer"
local Z2UIMDialogViewLayer = "DialogLayer"
local Z2UIMErrorViewLayer = "ErrorLayer"
local Z2UIMStatusViewLayer = "StatusLayer"
local Z2UIMConnectionViewLayer = "ConnectionLayer"
local Z2UIMForceViewLayer = "ForceLayer"

function viewWillShow(self)
	self.super:viewWillShow()

	local notificationCenter = NSNotificationCenter:defaultCenter()

	notificationCenter:addObserver_selector_name_object(
		self,
		"userDidLoginToFacebook",
		"FacebookDidLogin",
		nil
	)
	notificationCenter:addObserver_selector_name_object(
		self,
		"refreshNavigationButtonStatus",
		"ViewDirectorShown",
		nil
	)
	notificationCenter:addObserver_selector_name_object(
		self,
		"setUpPasswordAndSettingsButtons",
		"FacebookDidLogout",
		nil
	)

	self:setUpNavigationButtons()
	self:setUpPasswordAndSettingsButtons()
end

function userDidLoginToFacebook(self)
	local user = self:master():session():user()
	user:setRegistrationSource(Z2UserRegistrationSourceFacebook)
	self:setUpPasswordAndSettingsButtons()
end

function getLeaderboards(self)
    local request = ZPRequestMessage:requestToService_command_data_target_action(
        "lb",
        "getLeaderboards",
        nil,
        self,
        "getLeaderboardsResponse:"
    )
    self:master():networkSessionManager():sendRequest(request)
end

function setUpNavigationButtons(self, response)
	local gameHasLeaderboards = self:master():session():hasLeaderboards()
    if gameHasLeaderboards then
    	self:leaderboardsButton():setHidden(false)
    	self:leaderboardsLine():setHidden(false)
    else
    	self:removeLeaderboardsButton()
    end

    self:showNavigationButtons()
end

function showNavigationButtons(self)
	self:homeButton():setHidden(false)
	self:homeLine():setHidden(false)

	self:friendsButton():setHidden(false)
	self:friendsLine():setHidden(false)

	self:mailButton():setHidden(false)
	self:mailLine():setHidden(false)

	self:settingsButton():setHidden(false)
end

function removeLeaderboardsButton(self)
	local homeButton = self:homeButton()
	local homeLine = self:homeLine()
	local friendsButton = self:friendsButton()
	local friendsLine = self:friendsLine()
	local mailButton = self:mailButton()
	local mailLine = self:mailLine()
	local settingsButton = self:settingsButton()
	local closeButton = self:closeButton()

	local homeButtonFrame = homeButton:frame()
	local homeLineFrame = homeLine:frame()
	local friendsButtonFrame = friendsButton:frame()
	local friendsLineFrame = friendsLine:frame()
	local mailButtonFrame = mailButton:frame()
	local mailLineFrame = mailLine:frame()
	local settingsButtonFrame = settingsButton:frame()
	local closeButtonFrame = closeButton:frame()

	local totalWidth = closeButtonFrame.x - homeButtonFrame.x
	local buttonWidth = totalWidth / 4

	homeButtonFrame.width = buttonWidth
	homeButton:setFrame(homeButtonFrame)
	homeLineFrame.x = homeButtonFrame.x + buttonWidth
	homeLine:setFrame(homeLineFrame)

	friendsButtonFrame.x = homeButtonFrame.x + buttonWidth
	friendsButtonFrame.width = buttonWidth
	friendsButton:setFrame(friendsButtonFrame)
	friendsLineFrame.x = friendsButtonFrame.x + buttonWidth
	friendsLine:setFrame(friendsLineFrame)

	mailButtonFrame.x = friendsButtonFrame.x + buttonWidth
	mailButtonFrame.width = buttonWidth
	mailButton:setFrame(mailButtonFrame)
	mailLineFrame.x = mailButtonFrame.x + buttonWidth
	mailLine:setFrame(mailLineFrame)

	settingsButtonFrame.x = mailButtonFrame.x + buttonWidth
	settingsButtonFrame.width = buttonWidth
	settingsButton:setFrame(settingsButtonFrame)
end

function setUpPasswordAndSettingsButtons(self)

	local function enableButton(button)
		button:setEnabled(true)
		button:setAlpha(1.0)
	end

	local function disableButton(button)
		button:setEnabled(false)
		button:setAlpha(NavigationBarFadeAlpha)
	end

	disableButton(self:changeIconButton())
	disableButton(self:changePasswordButton())
	disableButton(self:emailSettingsButton())
	disableButton(self:facebookLogoutButton())

	if self:master():session():user():isGuest() then return end

	enableButton(self:changeIconButton())

	if self:master():facebookManager():isConnected() then
		enableButton(self:facebookLogoutButton())
	else
		enableButton(self:changePasswordButton())
		enableButton(self:emailSettingsButton())
	end
end

function home(self)
	self:master():showBaseViewWithName_data("Home", nil)
end

function friends(self)
	self:master():logEvent("JC View Friends List")
	self:master():showBaseViewWithName_data("Friends", nil)
end

function mail(self)
	self:master():showBaseViewWithName_data("IncomingMail", nil)
end

function leaderboards(self)
	self:master():logEvent("JC View Leaderboards")
	self:master():showBaseViewWithName_data("Leaderboard", nil)
end

local function beginAnimationsWithContext(context)
	UIView:beginAnimations_context(nil, context)
	UIView:setAnimationBeginsFromCurrentState(true)
	UIView:setAnimationDuration(0.15)
	UIView:setAnimationCurve(UIViewAnimationCurveEaseInOut)
end

function refreshNavigationButtonStatus(self, notification)

	local clearColor = UIColor:clearColor()
	local function enableButton(button)
		button:setEnabled(true)
		button:setBackgroundColor(clearColor)
	end

	local fadedColor = UIColor:colorWithRed_green_blue_alpha(0, 0, 0, NavigationBarFadeAlpha)
	local function disableButton(button)
		button:setEnabled(false)
		button:setBackgroundColor(fadedColor)
	end

	beginAnimationsWithContext(nil)

	enableButton(self:homeButton())
	enableButton(self:mailButton())
	enableButton(self:friendsButton())
	enableButton(self:leaderboardsButton())

	if self:settingsButton():isEnabled() then
		local baseViewLayer = self:master():viewLayerNamed(Z2UIMBaseViewLayer)
		local currentDirector = baseViewLayer:currentDirector()
		if currentDirector then
			if currentDirector:isKindOfClass(IncomingMail:class()) then
				disableButton(self:mailButton())
			elseif currentDirector:isKindOfClass(Leaderboard:class()) then
				disableButton(self:leaderboardsButton())
			elseif currentDirector:isKindOfClass(Friends:class()) then
				disableButton(self:friendsButton())
			elseif currentDirector:isKindOfClass(Home:class()) then
				local user = self:master():session():user()
				if user then
					local userUUID = user:uuid()
					local currentUUID = currentDirector:parameterForKey("uuid")
					if currentUUID == userUUID then
						disableButton(self:homeButton())
					end
				end
			end
		end
	end

	UIView:commitAnimations()
end

function settings(self)
	-- TODO: Find out why we're posting this notification
	NSNotificationCenter:defaultCenter():postNotificationName_object("ViewDirectorShown", nil)

	self:settingsButton():setEnabled(false)
	self:refreshNavigationButtonStatus(nil)
	self:setUpPasswordAndSettingsButtons()

	local settingsPopup = self:settingsPopup()
	beginAnimationsWithContext(settingsPopup)
	settingsPopup:setAlpha(1.0)

	-- TODO: Find out why this isn't working
	-- local scaleTransform = CGAffineTransformMakeScale(1, 1)
	-- self:settingsPopup():setTransform(scaleTransform)

	UIView:commitAnimations()
end

function hideSettings(self)
	self:settingsButton():setEnabled(true)
	self:refreshNavigationButtonStatus(nil)

	local settingsPopup = self:settingsPopup()
	beginAnimationsWithContext(settingsPopup)
	settingsPopup:setAlpha(0.0)

	-- TODO: Find out why this isn't working
	-- local scaleTransform = CGAffineTransformMakeScale(0, 0)
	-- self:settingsPopup():setTransform(scaleTransform)

	UIView:commitAnimations()
end

function emailSettings(self)
	self:master():showDialogViewWithName_data("EmailSettings", nil)
	self:hideSettings()
end

function facebookLogout(self, sender)
	-- TODO: During JujuLib -> Z2Lib refactor, rename all of these managers
	local master = self:master()
	master:logEvent("JC Removed Facebook")
	local facebook = master:facebookManager()
	local networkSession = master:networkSessionManager()

	local data = { onFinish = "logout", onFinishTarget = facebook }
	local sessionVariables = networkSession:sessionVariables()
	if sessionVariables.hasZ2Credentials then
		master:showBaseViewWithName_data("ConfirmPassword", data)
	else
		data.username = master:session():user():username()
		master:showDialogViewWithName_data("Register", data)
	end

	self:hideSettings()
end

function changePassword(self)
	self:master():showDialogViewWithName_data("ChangePassword", nil)
	self:hideSettings()
end

function changeIcon(self)
	self:master():showDialogViewWithName_data("ChangeIcon", nil)
	self:hideSettings()
end

function logout(self)
	local master = self:master()
	master:logEvent("JC Switched User")
	master:loginManager():logout()
	master:dismissBaseView()
end

function close(self)
	self:master():dismissBaseView()
end

function back(self)
	local menuLayer = self:master():viewLayerNamed(Z2UIMBaseViewLayer)
	if menuLayer:hasAnyBackHistory() then
		menuLayer:back()
	else
		self:master():dismissBaseView()
	end
end
