--Similar to UIFrameFadeIn
--Hide the frame in the end.
--Shows the frame if it's not protected - important when touching protected frames.
--It also sets the alpha to "1" after hiding.

--frame: frame to fade in/out
--duration:	time that takes the animation
--startAlpha: starting alpha
--endAlpha: ending alpha
--hideEnd: if true, hides the frame in the end.

local frameFadeManager = CreateFrame("FRAME");

local queueFrame = {};
local size = 0;

local GetTime = GetTime;


function frameFade(frame, duration, startAlpha, endAlpha, hideEnd)

	if(size > 0) then
		if(not queueFrame[frame]) then
			size = size + 1;
		end
		queueFrame[frame] = { GetTime(), GetTime()+duration, duration, startAlpha, endAlpha, hideEnd};
		frame:SetAlpha(startAlpha);
		if(not frame:IsProtected()) then
			frame:Show();
		end
		return;
	end
	
	local currentTime, newAlpha;
	
	size = 1;
	queueFrame[frame] = { GetTime(), GetTime()+duration, duration, startAlpha, endAlpha, hideEnd};
	if(not frame:IsProtected()) then
		frame:Show();
	end
	
	frameFadeManager:SetScript("OnUpdate", function(self, elapsed)
		currentTime = GetTime();
		for frame, animationInfo in pairs(queueFrame) do
			local startTime, endTime, duration, startAlpha, endAlpha, hideEnd = unpack(animationInfo);
			
			--setting new alpha
			local timeElapsed = currentTime - startTime;
			newAlpha = endAlpha*(timeElapsed/duration) + startAlpha*((endTime - currentTime)/duration);
			
			frame:SetAlpha(newAlpha);
			
			if(currentTime > endTime) then
				frame:SetAlpha(endAlpha);
				if(hideEnd and not frame:IsProtected()) then
					frame:Hide();
					frame:SetAlpha(1);
				end
				queueFrame[frame] = nil;
				size = size - 1;
				if(size == 0) then
					self:SetScript("OnUpdate", nil);
				end
			end
		end	
	end);
	
end

function cancelFade(frame)
	queueFrame[frame] = nil;
end


---UPDATED Blizzard tooltip func - used on CatchTheWind.xml
function CTW_GameTooltip_ShowCompareItem(self, shift)
	GameTooltip_ShowCompareItem(self,shift);

	local shoppingTooltip1, shoppingTooltip2 = unpack(self.shoppingTooltips);
	if(CatchTheWind:IsShown() and shoppingTooltip2:IsShown()) then
		
		local item, link = self:GetItem();
		
		local side = "left";
		local rightDist = 0;
		local leftPos = self:GetLeft();
		local rightPos = self:GetRight();
		if ( not rightPos ) then
			rightPos = 0;
		end
		if ( not leftPos ) then
			leftPos = 0;
		end
	
		rightDist = GetScreenWidth() - rightPos;
	
		if (leftPos and (rightDist < leftPos)) then
			side = "left";
		else
			side = "right";
		end
		
		shoppingTooltip2:SetOwner(shoppingTooltip1, "ANCHOR_NONE");
		shoppingTooltip2:ClearAllPoints();
		if ( side and side == "left" ) then
			shoppingTooltip2:SetPoint("TOPRIGHT", shoppingTooltip1, "TOPRIGHT", 0, shoppingTooltip1:GetHeight());
		else
			shoppingTooltip2:SetPoint("TOPLEFT", shoppingTooltip1, "TOPLEFT", 0, shoppingTooltip1:GetHeight());
		end
		shoppingTooltip2:SetHyperlinkCompareItem(link, 2, shift, self);
		shoppingTooltip2:Show();
	end
	
end

function CTW_DressUpItemLink(link)
	if ( not link or not IsDressableItem(link) ) then
		return;
	end
	
	if ( not CTWDressUpModel:IsShown() ) then
		CTWDressUpModel:Show();
		CTWDressUpModel:SetUnit("player");
	end
	
	CTWDressUpModel:TryOn(link);
end