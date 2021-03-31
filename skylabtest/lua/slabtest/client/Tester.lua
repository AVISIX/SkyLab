include("slabtest/client/utils.lua")

local function open()
    if IsValid(TESTWINDAW) == false or IsValid(TESTWINDAW.view) == false then 
        TESTWINDAW = vgui.Create("DFrame")
        TESTWINDAW:SetPos( ScrW() / 2 - 600 , ScrH() / 2 - 700 / 2 )
        TESTWINDAW:SetSize( 700, 700 )
        TESTWINDAW:SetTitle( "Derma SyntaxBox V8" )
        TESTWINDAW:SetDraggable( true )
        TESTWINDAW:MakePopup()
        TESTWINDAW:SetSizable(true)
        TESTWINDAW:SetMinWidth(200)
        TESTWINDAW:SetMinHeight(100)
        TESTWINDAW.view = vgui.Create("SleekRichTextBox", TESTWINDAW)
    end 

 --   TESTWINDAW.view:SetProfile(prof)
	TESTWINDAW.view:Dock(FILL)
   -- TESTWINDAW.view:SetFont("Consolas", 16)

    TESTWINDAW.view:AddText([[function DataContext:SmartFolding(startLine) -- Uses Whitespace differences to detect folding
        if not self.context[startLine] then return end 
    
        if string.gsub(self.context[startLine].text, "%s", "") == "" then return end 
    
        local startLeft = getLeftLen(self.context[startLine].text)               
        local nextLeft  = getLeftLen((self.context[startLine + 1] or {}).text)     
    
        local function peekNextFilledLine(start, minLen)
            start = start + 1
    
            while self.context[start] and (string.gsub((self.context[start] or {}).text or "", "%s", "") == "") do  
                if minLen and getLeftLen(self.context[start].text) < minLen then break end 
                start = start + 1
            end
    
            return self.context[start], start
        end
    
        if nextLeft <= startLeft then -- If its smaller, then check if its a whitespace line, if yes, skip all of them until the first filled comes up, then check again.
            local nextFilled, lookup = peekNextFilledLine(startLine, nextLeft)
    
            if not nextFilled or lookup - 1 == startLine then return end 
    
            startLine = lookup
            nextLeft = getLeftLen(nextFilled.text)     
        
            if nextLeft <= startLeft then return end 
        end 
    
        startLine = startLine + 2 
    
        -- uwu so many while luwps howpfuwwy it doewsnt fwuck up x3 (may god have mercy with my soul)
    
        while true do
            if not self.context[startLine] then return startLine - 2 end 
            
            local currentLeft = getLeftLen(self.context[startLine].text) 
    
            if currentLeft < nextLeft then 
                local nextReal = peekNextFilledLine(startLine - 1)
    
                if not nextReal or (nextReal.text ~= "" and getLeftLen(nextReal.text) < nextLeft) then 
                    return startLine - 2
                end  
            end
    
            startLine = startLine + 1
        end
    
        return startLine
    end]])
    --    TESTWINDAW.view:SetText(file.Read("expression2/Projects/Mechs/Spidertank/Spidertank_NewAnim/spiderwalker-v1.txt", "DATA"))
--  TESTWINDAW.view:SetText(file.Read("expression2/libraries/e2parser_v2.txt", "DATA"))
--TESTWINDAW.view:SetText(file.Read("expression2/crashmaster.txt", "DATA"))
end

concommand.Add("sopen", function( ply, cmd, args )
    open()
end)

open()

print("lol")