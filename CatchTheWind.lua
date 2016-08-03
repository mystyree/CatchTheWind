local Addon = CreateFrame("FRAME");


local letterBox;

--TODO
--CatchTheWind
--
-- Cinematic Quests AddOn
-- 
--x * Zoom in when interacting with an NPC
--x * Zoom out on GOSSIP_CLOSE
--x * Hide UIParent, show cinematic view (aka letterbox) and set subtitles
--x * When choosing QuestRewards, show all options and an "ACCEPT" option
--x * Only show cinematic scenes (aka letterbox) whenever the player chooses a quest
--x * Show Accept/Decline buttons 
--x * Animate Text. Gradient like Storyline
--x * GetTitleText + GetProgressText + GetObjectiveText + GetRewardText
-- * Set a close-plan to player when deciding "ACCEPT/DECLINE" and choosing rewards.
-- 
-- QUEST PROGRESS > QUEST COMPLETE > QUEST FINISHED (it means you stop interacting with a NPC about a quest) > QUEST LOG UPDATED

-- BUGS:
--x * When interacting with merchants: GOSSIP SHOW > CLOSE > MERCHANT SHOW
--x * When the line is too big, it gets out of the screen
--x * UIParent cannot be hidden when zooming in (after choosing a quest = QUEST_DETAIL)

--x = Done/Fixed

--------------------
--UTILS
--------------------

local timer = CreateFrame("FRAME");

local function createTimer(after, func)
	local total = 0;
	timer:SetScript("OnUpdate", function(self, elapsed)
		total = total + elapsed;
		if(total > after) then
			self:SetScript("OnUpdate", nil);
			func();
		end
	end);
end


local function cancelTimer()
	timer:SetScript("OnUpdate", nil);
end


--split a text (multiple lines) and store all lines in a table - each entry is a line
local function splitText(text)
	local lines, nextLine = {};
	while string.find(text,"\n") do
		nextLine = string.sub(text,0, string.find(text, "\n"));
		if not (strtrim(nextLine) == "") then
			table.insert(lines, nextLine);
		end
		text = string.sub(text, string.find(text, "\n")+1, -1);	
	end
	if not (strtrim(text) == "") then
		table.insert(lines, string.sub(text, 0, string.find(text, "\n")));
	end
	return lines;
end



--creates a button frame
local function createButton(name, parent, text, point, xOfs, yOfs, onClickFunc)
	local buttonFrame = CreateFrame("FRAME", name, parent);
	buttonFrame:SetSize(200,50);
	buttonFrame:SetPoint(point, xOfs, yOfs);
	
	buttonFrame.fontString = buttonFrame:CreateFontString();
	buttonFrame.fontString:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE");
	buttonFrame.fontString:SetText(text);
	buttonFrame.fontString:SetTextColor(0.3, 0.3, 0.3, 1);
	buttonFrame.fontString:SetPoint("CENTER");
	
	buttonFrame:EnableMouse(true);
	buttonFrame:SetScript("OnMouseUp", onClickFunc);
	buttonFrame:SetScript("OnEnter", function(self)
		self.fontString:SetTextColor(1, 1, 1, 1);
	end);
	buttonFrame:SetScript("OnLeave", function(self)
		self.fontString:SetTextColor(0.3, 0.3, 0.3, 1);
	end);
	
	
	buttonFrame:Hide();
	
	return buttonFrame;
end



--fontString animator
local animateFrame = CreateFrame("FRAME");
local function animateText(fontString)
	local total, numChars = 0, 0;
	fontString:SetAlphaGradient(0,20);
	animateFrame:SetScript("OnUpdate", function(self, elapsed)
		numChars = numChars + 0.25;
		fontString:SetAlphaGradient(numChars,20);
		if(numChars == string.len(fontString:GetText())) then
			self:SetScript("OnUpdate", nil);
		end
	end);
end


-------------------------------



--UIFrameFadeOut doesn't hide the frame in the end.
--Also, UIFrameFade calls :Show() which taints whenever the player is in-combat. (UIParent:Show())
local frameFader = CreateFrame("FRAME");
local function hideLetterBox()
	--UIFrameFadeIn(UIParent, 0.25, 0, 1);	It's not advised to use UIFrameFade on "UIParent" because it taints the code
	local alpha = UIParent:GetAlpha();
	frameFader:SetScript("OnUpdate", function(self, elapsed)
		if(alpha < 1) then
			alpha = alpha + 0.05;
			UIParent:SetAlpha(alpha);
		else
			frameFader:SetScript("OnUpdate", nil);
		end
	
	end);
	
	UIFrameFadeOut(letterBox, 0.25, 1, 0);
	local total = 0;
	letterBox:SetScript("OnUpdate", function(self, elapsed)
		total = total + elapsed;
		if(total > 0.25) then
			letterBox:SetScript("OnUpdate", nil);
			letterBox:Hide();
		end
	end);
end


local function showLetterBox()
--	local alpha = UIParent:GetAlpha();
--	frameFader:SetScript("OnUpdate", function(self, elapsed)
--		if(alpha > 0) then
--			alpha = alpha - 0.05;
--			UIParent:SetAlpha(alpha);
--		else
--			frameFader:SetScript("OnUpdate", nil);
--		end
--	end);
	UIParent:SetAlpha(0);
	UIFrameFadeIn(letterBox, 0.25, 0, 1);
end


--starts the interaction (text/speech) after a quest event
--TODO: GET A BETTER NAME
local function startInteraction()
	letterBox.acceptButton:Hide();
	letterBox.declineButton:Hide();
	
	letterBox.rewardPanel:Hide();
	
	letterBox.text = splitText(letterBox.text);
	letterBox.textIndex = 1;
	letterBox.questText:SetText(letterBox.text[letterBox.textIndex]);
	animateText(letterBox.questText);
end


local function createQuestRewardPanel()

	--quest reward panel
	letterBox.rewardPanel = CreateFrame("FRAME", "CTWrewardPanel", letterBox);
	letterBox.rewardPanel:SetPoint("LEFT");
	
	
	--quest reward panel title
	letterBox.rewardPanel.title = letterBox.rewardPanel:CreateFontString();
	letterBox.rewardPanel.title:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE");
	letterBox.rewardPanel.title:SetTextColor(1, 1, 1, 1);
	letterBox.rewardPanel.title:SetText("Choose your reward");
	letterBox.rewardPanel.title:SetPoint("TOP", 0, -18);
	
	--quest reward items buttons(blizz has 10 buttons)
	--refactor > extract code
	
	for i=1, 10 do
		local btn = CreateFrame("BUTTON", "CTWrewardPanelItem"..i, letterBox.rewardPanel, "LargeItemButtonTemplate, QuestInfoRewardItemCodeTemplate");
		btn:SetSize(48,48);
		
		btn.type = "choice";
		btn.objectType = "item";
		
		_G[btn:GetName().."NameFrame"]:Hide();
		_G[btn:GetName().."Name"]:Hide();
		
		_G[btn:GetName().."IconTexture"]:SetTexCoord(0.075,0.925,0.075,0.925);
		_G[btn:GetName().."IconTexture"]:SetSize(38,38)
		_G[btn:GetName().."IconTexture"]:ClearAllPoints();
		_G[btn:GetName().."IconTexture"]:SetPoint("CENTER", btn, 0, 0);
		
		btn:SetBackdrop(
			{bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true, tileSize = 22, edgeSize = 22,
			insets = { left = 6, right = 6, top = 6, bottom = 6 }}
		);
		
		btn:SetPoint("TOP", 0, (-i)*56);
		
		btn:SetScript("OnEnter", function(self)
			GameTooltip:SetParent(WorldFrame);
			GameTooltip:SetFrameStrata("TOOLTIP");
			ShoppingTooltip1:SetParent(WorldFrame);
			ShoppingTooltip2:SetParent(WorldFrame);
			ShoppingTooltip3:SetParent(WorldFrame);
			
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
			GameTooltip:SetQuestItem(self.type, self:GetID());
			GameTooltip_ShowCompareItem(GameTooltip);

			
			--TODO
			--clean this tooltip code a little bit
			
		end);
		btn:SetScript("OnLeave", function()
			GameTooltip:SetParent(UIParent);
			GameTooltip:Hide();
			ShoppingTooltip1:SetParent(UIParent);
			ShoppingTooltip2:SetParent(UIParent);
			ShoppingTooltip3:SetParent(UIParent);
			ResetCursor();
		end);
		
		btn:SetScript("OnClick", function(self, button)
			for i=1, GetNumQuestChoices() do
				_G["CTWrewardPanelItem"..i.."IconTexture"]:SetVertexColor(0.5,0.5,0.5,1);
			end
			_G[self:GetName().."IconTexture"]:SetVertexColor(1,1,1,1);
			QuestInfoItem_OnClick(self);
		end);
		
		btn:Hide();
	end
	
	letterBox.rewardPanel:Hide();
end



local function setUpLetterBox()
	letterBox = CreateFrame("FRAME", "CatchTheWind", WorldFrame);
	letterBox:SetSize(GetScreenWidth(), GetScreenHeight())
	letterBox:SetAllPoints();
	
	letterBox:SetFrameStrata("HIGH");
	letterBox:SetFrameLevel(10);
	
	letterBox.bottomPanel = letterBox:CreateTexture();
	letterBox.bottomPanel:SetTexture(0,0,0);
	letterBox.bottomPanel:SetSize(GetScreenWidth(), GetScreenHeight()/7);
	letterBox.bottomPanel:SetPoint("BOTTOM");
	
	letterBox.topPanel = letterBox:CreateTexture();
	letterBox.topPanel:SetTexture(0,0,0);
	letterBox.topPanel:SetSize(GetScreenWidth(), GetScreenHeight()/7);
	letterBox.topPanel:SetPoint("TOP");
	
	
	letterBox.questText = letterBox:CreateFontString(nil, "OVERLAY");
	letterBox.questText:SetSize(GetScreenWidth()*0.75, GetScreenHeight()/7)
	letterBox.questText:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE"); --WoW Font
	letterBox.questText:SetTextColor(0.9, 0.9, 0.9, 1);
	letterBox.questText:SetPoint("BOTTOM", 0, 0);
	
	
	createQuestRewardPanel();
	
	
	letterBox.acceptButton = createButton("CTWacceptButton", letterBox, "Accept", "BOTTOMRIGHT", 0, GetScreenHeight()/28, function(self, button)
		QuestDetailAcceptButton_OnClick();
		hideLetterBox();
	end);

	letterBox.declineButton = createButton("CTWdeclineButton", letterBox, "Decline", "BOTTOMLEFT", 0, GetScreenHeight()/28, function(self, button)
		QuestDetailDeclineButton_OnClick();
		hideLetterBox();
	end);
	
	
	letterBox:Hide();
	
	letterBox:SetScript("OnMouseUp", function(self, button)
		if(self.textIndex == #self.text) then
			if(self.acceptButton.fontString:GetText() == "Continue") then
				if(IsQuestCompletable()) then
					self.acceptButton:Show();
					self.acceptButton:SetScript("OnMouseUp", QuestProgressCompleteButton_OnClick);
				else
					self.acceptButton:Hide();
				end
			else
				self.acceptButton:Show();
			end
			self.declineButton:Show();
			return;
		end
		self.textIndex = self.textIndex + 1;
		self.questText:SetText(self.text[self.textIndex]);
		animateText(self.questText);
	end);
	
	
	QuestFrame:HookScript("OnHide", function()
		hideLetterBox();
	end);
	
end

------------
--ADDON SCRIPTS

local function onPlayerLogin()
	SaveView(5);
	setUpLetterBox();
end

local function onGossipShow()
	cancelTimer();
	SetView(2);
end


local function onQuestDetail()
	cancelTimer();
	letterBox.text = GetQuestText();
	
	letterBox.acceptButton.fontString:SetText("Accept");
	letterBox.acceptButton:SetScript("OnMouseUp", function(self, button)
		QuestDetailAcceptButton_OnClick();
		hideLetterBox();
	end);
	letterBox.declineButton.fontString:SetText("Decline");
	
	showLetterBox();
	
	startInteraction();
end


local function onQuestProgress()
	cancelTimer();
	letterBox.text = GetProgressText();
	
	letterBox.acceptButton.fontString:SetText("Continue");
	letterBox.acceptButton:SetScript("OnMouseUp", QuestProgressCompleteButton_OnClick);
	
	letterBox.declineButton.fontString:SetText("Goodbye");
	
	showLetterBox();
	
	startInteraction();
end


local function onQuestComplete()
	cancelTimer();
	if(not letterBox:IsShown()) then
		showLetterBox();
	end
	
	letterBox.text = GetRewardText();
	
	startInteraction();
	
	letterBox.acceptButton.fontString:SetText("Thank you");
	letterBox.acceptButton:SetScript("OnMouseUp", function(self, button)
		if(QuestInfoFrame.itemChoice == 0 and GetNumQuestChoices() > 0 ) then
			UIFrameFlash(letterBox.rewardPanel, 0.5, 0.5, 1.5, true, 0, 0);
		else
			QuestRewardCompleteButton_OnClick();
			hideLetterBox();
		end
	end);
	
	letterBox.declineButton:Hide();
	
	--if there is quest rewards to choose > show quest rewards
	if(GetNumQuestChoices() > 0) then
		local btn;
		
		--show icons of quests rewards
		for i=1, GetNumQuestChoices() do
			btn = _G["CTWrewardPanelItem"..i];
			
			local name, texture, numItems, quality, isUsable = GetQuestItemInfo(btn.type, i);
			SetItemButtonTexture(btn, texture);
			_G[btn:GetName().."IconTexture"]:SetVertexColor(0.5,0.5,0.5,1);

			btn:SetID(i);
			btn:Show();
		end
		
		--hide remain unused frames
		for i=GetNumQuestChoices()+1, 10 do
			_G["CTWrewardPanelItem"..i]:Hide();
		end
		
		--set quest reward panel in the correct position (i.e. centered)
		letterBox.rewardPanel:SetSize(200, (GetNumQuestChoices())*56);
		letterBox.rewardPanel:SetPoint("LEFT", 0, 18);
		
		letterBox.rewardPanel:Show();
	else
		letterBox.rewardPanel:Hide();
	end
end




Addon.scripts = {
	["PLAYER_LOGIN"] = onPlayerLogin,
	["GOSSIP_SHOW"] = onGossipShow,
	["QUEST_DETAIL"] = onQuestDetail,
	["QUEST_PROGRESS"] = onQuestProgress,
	["QUEST_COMPLETE"] = onQuestComplete,
};


local moving = false;
Addon:SetScript("OnEvent", function(self, event)
	if(Addon.scripts[event]) then
		Addon.scripts[event]();
	elseif((event == "GOSSIP_CLOSED" or event == "MERCHANT_CLOSED" or event == "TRAINER_CLOSED" or event == "QUEST_FINISHED" or event == "TAXIMAP_CLOSED") and not moving) then
		--a timer is needed because when interacting with merchants/trainers or choosing quests, "GOSSIP_CLOSED" will be
		--triggered and right after a "MERCHANT_SHOW" will pop up and cancel this timer.
		letterBox.rewardPanel:Hide();
		createTimer(0.05, function()
			SetView(5);
			moving = true;
			createTimer(0.5, function() moving = false end);
		end);
	elseif(event == "MERCHANT_SHOW" or event == "TRAINER_SHOW" or event == "TAXIMAP_OPENED") then
		cancelTimer();
	end
end);


Addon:RegisterEvent("GOSSIP_SHOW");
Addon:RegisterEvent("MERCHANT_SHOW");
Addon:RegisterEvent("TRAINER_SHOW");
Addon:RegisterEvent("TAXIMAP_OPENED");

Addon:RegisterEvent("GOSSIP_CLOSED");
Addon:RegisterEvent("MERCHANT_CLOSED");
Addon:RegisterEvent("TRAINER_CLOSED");
Addon:RegisterEvent("TAXIMAP_CLOSED");

Addon:RegisterEvent("QUEST_DETAIL");
Addon:RegisterEvent("QUEST_PROGRESS");
Addon:RegisterEvent("QUEST_COMPLETE");
Addon:RegisterEvent("QUEST_FINISHED");

Addon:RegisterEvent("PLAYER_LOGIN");
