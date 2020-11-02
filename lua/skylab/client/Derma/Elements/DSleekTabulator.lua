--[[
    To Do:
        - Add Dropdown on the right to select current tab

]]

if not SSLE then return end 

self = {}

function self:Init()
    self.colors.activeTab = Color(220,110,0)

    self.button = vgui.Create("DSleekButton", self)
    self.button:Dock(FILL)
    self.button.OnClick = function(_, delay, code)
        self:OnMouseClicked(delay, code)
    end
    self.isActive = false 
end

function self:SetText(text)
    if not text then return end 
    self.button:SetText(text)
end

function self:SetIcon(icon)
    if not icon then return end 
    self.button:SetImage(icon)
end

function self:SetEnableClose(b)
    if not b then return end 

    if b == false and IsValid(self.closeButton) == true then 
        self.closeButton:Remove()
    else 
        self.closeButton = vgui.Create("DSleekButton", self)
        --[[ 
        self.closeButton.SetImageSizeOffset = function(self, status)
            if not status then return end 
            self.originalSizeOffset = status 
            self.imageSizeOffset = status 
            self.image:Dock(NODOCK)
        end
        self.closeButton.Paint = function(self, w, h) 
            if self:IsHovered() == true then 
                self.imageSizeOffset = self.originalSizeOffset - 4
            else 
                self.imageSizeOffset = self.originalSizeOffset 
            end

            self:PerformLayout(w,h)
        end ]]
        SSLE:Tooltip(self.closeButton, "Close '" .. self.button.text .. "'?")
        self.closeButton.Paint = function() end 
        self.closeButton:SetImage("icon16/cross.png", 4.5)
        self.closeButton:Dock(RIGHT) 
        self.closeButton:SetVisible(false)
        self.closeButton:SetWide(self.closeButton.image:GetWide()/4)
        self.closeButton.colors.outline = self.closeButton.colors.background 
        self.closeButton.OnClick = function() 
            self:OnMouseClicked(MOUSE_LEFT)
            self:OnCloseClicked()
        end

        self.button:Dock(FILL)
    end

    self.closeButton.colors.background = self.button.colors.background 

    self:InvalidateLayout(true)
end

function self:GetButton()
    return self.button 
end

function self:SizeToContents()
    self.button:SizeToContents()
    
    local w = self.button:GetWide()

    if IsValid(self.closeButton) == true then 
        w = w + self.closeButton:GetWide()
    end

    self:SetWide(w)
end

function self:SetActiveTab(s)
    if s == nil then s = true end 
    self.isActive = s 
    self.button.colors.background = (s == true and self.colors.activeTab or self.colors.background)
    self.button.clickstrength = (s == true and 1.25 or 1.75)
    self.closeButton.colors.background = self.button.colors.background 
end

function self:Think()
    if (self.button:IsHovered() == true and self:LocalCursorPos() > self:GetWide() - self.closeButton:GetWide()) or self.closeButton:IsHovered() == true then 
        self.closeButton:SetVisible(true)
    else 
        self.closeButton:SetVisible(false)
        self:InvalidateLayout(true)
    end
end

function self:OnCloseClicked() end

function self:OnLeftClick() end
function self:OnRightClick() end 
function self:OnMouseClicked(delay, code)
  --  self = self:GetParent()
    if code == MOUSE_LEFT then 
        self:OnLeftClick(delay)
    elseif code == MOUSE_RIGHT then 
        self:OnRightClick(delay)
    end
end 

vgui.Register("DSleekTab", self, "DSleekPanel")







 

self = {}

function self:Init()
    self.scroller = vgui.Create("DHorizontalScroller", self)
    self.scroller:Dock(TOP)
    self.scroller:SetOverlap(-1)
    self.scroller.super = self 

    function self.scroller:PerformLayout()

        local w, h = self:GetSize()
    
        self.pnlCanvas:SetTall( h - 1 )
    
        local x = 0
    
        for k, v in pairs( self.Panels ) do
            if ( !IsValid( v ) ) then continue end
            if ( !v:IsVisible() ) then continue end
    
            v:SetPos( x, 0 )
            v:SetTall( h )
            if ( v.ApplySchemeSettings ) then v:ApplySchemeSettings() end
    
            x = x + v:GetWide() - self.m_iOverlap
    
        end
    
        self.pnlCanvas:SetWide( x + self.m_iOverlap )
    
        if ( w < self.pnlCanvas:GetWide() ) then
            self.OffsetX = math.Clamp( self.OffsetX, 0, self.pnlCanvas:GetWide() - self:GetWide() )
        else
            self.OffsetX = 0
        end
    
        self.pnlCanvas.x = self.OffsetX * -1
    
        self.btnLeft:SetSize( 15, 15 )
        self.btnLeft:AlignLeft( 4 )
        self.btnLeft:AlignBottom( 5 )
    
        self.btnRight:SetSize( 15, 15 )
        self.btnRight:AlignRight( 4 )
        self.btnRight:AlignBottom( 5 )
    end

    self.scroller.btnLeft:SetVisible(false)
    self.scroller.btnRight:SetVisible(false)

    self.canvas = vgui.Create("DSleekPanel", self)
    self.canvas:Dock(FILL)

    self.tabs = {}

    self.colors.scrollIndicator = Color(220,110,0)

    self.activeView = {}
end

function self:GetName()
    return "DSleekTabulator"
end

function self:IsValidTab(k)

    local v 
    if type(k) == "number" then 
        v = self.tabs[k]
    else 
        v = k 
    end

    if not v then return false end 

    local view = v.view 
    local tab  = v.tab 

    if IsValid(view) == false or IsValid(tab) == false then 

        if IsValid(view) == true then 
            view:Remove()
        elseif IsValid(tab) == true then 
            tab:Remove()
        end

        self.tabs[k] = nil 

        return false 
    end 

    return true 
end

function self:ClearActive()
    for k, v in pairs(self.tabs) do 
        if self:IsValidTab(v) == false then continue end 

        if v.tab.isActive == true then self:OnTabDeactivated(v) end

        v.view:SetVisible(false)
        v.tab:SetActiveTab(false)
    end
end

function self:ActivateTab(n)    
    self:ClearActive()

    if self:IsValidTab(n) == false then return end

    self.tabs[n].tab:SetActiveTab(true)

    self:OnTabActivated(self.tabs[n])
end

function self:AddTab(title, view, autoFocus)
    if not title or IsValid(view) == false then return end 

    if autoFocus == nil then autoFocus = false end 

    local super = self 

    local tab = vgui.Create("DSleekTab") 
    tab:SetText(title)
    tab:SetEnableClose(true)
    tab:SizeToContents()

    table.insert(self.tabs, {
        view = view,
        tab  = tab  
    })

    local entry = self.tabs[#self.tabs]

    tab.entry  = entry
    view.entry = entry 

    tab.OnLeftClick    = function(self, delay) super:ActivateTab(self.index) end
    tab.OnCloseClicked = function(self, delay) super:RemoveTab(self.index)   end 

    function tab:OnMenuConstructed() end 
    function tab:OnMenuConstructionFinished() end 
    tab.OnRightClick   = function(self, delay) 
        local menu = DermaMenu()

        self:OnMenuConstructed()

        menu:AddOption("Close", function()
            super:RemoveTab(self.entry)
        end)

        self:OnMenuConstructionFinished()

        menu:Open()
    end

    tab.index = #self.tabs 

    view:SetVisible(false)
    view:SetParent(self.canvas)
    
    self.scroller:AddPanel(tab)

    self:OnTabAdded(self.tabs[#self.tabs], tab, view)

    return tab 
end

function self:RemoveTab(n)
    if self:IsValidTab(n) == false then return end 

    if type(n) == "number" then 
        self.tabs[n].tab:Remove()
        self.tabs[n].view:Remove()     
        self.tabs[n] = nil 
        self.scroller.Panels[n] = nil  

        self.scroller:InvalidateLayout(true)
        return 
    end

    n.tab:Remove()
    n.view:Remove()

    self.scroller:InvalidateLayout(true)
end

function self:OnTabAdded() end
function self:OnTabActivated() end 
function self:OnTabDeactivated() end

function self:Think()

    local activeTab 

    for k, v in pairs(self.tabs) do 
        if self:IsValidTab(v) == false then continue end 
        if v.tab.isActive == false then continue end 

        v.view:SetVisible(true)

        activeTab = k
    end

    if not activeTab and #self.tabs > 0 then 
        local n = 1

        if self.lastActive ~= nil and self.lastActive > 1 then 
            n = math.max(self.lastActive - 1, 1)
        else
            while n < #self.tabs and self:IsValidTab(n) == false do n = n + 1 end
        end

        self:ActivateTab(n)
    end

    self.lastActive = activeTab
end

function self:PaintAfter(w, h)
    local scroller = self.scroller 
    local canvasW = scroller.pnlCanvas:GetWide()

    if canvasW <= w then return end 

    draw.RoundedBox(0,(w / canvasW) * -scroller.pnlCanvas.x, self.scroller:GetTall() - 1, w * (w / canvasW), 1,self.colors.scrollIndicator)
end

vgui.Register("DSleekTabulator", self, "DSleekPanel")