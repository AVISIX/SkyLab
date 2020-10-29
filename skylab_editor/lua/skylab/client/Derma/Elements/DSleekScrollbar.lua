local function dark(n)
    return Color(n,n,n)
end

local cols = {}

cols.background  = dark(40)
cols.buttons     = dark(80)
cols.dragging    = dark(170)
cols.gripdefault = dark(140)

do
    local scrollbar = {} 

    function scrollbar:Init()
        self.colors = table.Copy(cols)

        local parent = self

        self.btnUp.Paint = function(self, w, h)
            draw.RoundedBox(0, 0, 0, w, h, parent.colors.buttons)
        end
    
        self.btnDown.Paint = function(self, w, h)
            draw.RoundedBox(0, 0, 0, w, h, parent.colors.buttons)
        end
    
        self.btnGrip.Paint = function(self, w, h)
            if parent.Dragging == true then 
                draw.RoundedBox(0, 0, 0, w, h, parent.colors.dragging)
            else 
                draw.RoundedBox(0, 0, 0, w, h, parent.colors.gripdefault)
            end 
        end

        self.btnGrip:SetCursor("sizens")
    end

    function scrollbar:Paint(w, h)
        draw.RoundedBox(0, 0, 0, w, h, self.colors.background)
    end

    vgui.Register("DSleekScrollbar", scrollbar, "DVScrollBar")
end

function scrollbarOverride(self)
    self.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, cols.background)
    end

    self.btnUp.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, cols.buttons)
    end

    self.btnDown.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, cols.buttons)
    end

    self.btnGrip.Paint = function(self, w, h)
        local parent = self:GetParent()
        if parent.Dragging == true then 
            draw.RoundedBox(0, 0, 0, w, h, cols.dragging)
        else 
            draw.RoundedBox(0, 0, 0, w, h, cols.gripdefault)
        end 
    end

    self.btnGrip:SetCursor("sizens")

    self.btnUp:SetText("+")
    self.btnUp:SetTextColor(Color(255,255,255))
    self.btnDown:SetText("-")
    self.btnDown:SetTextColor(Color(255,255,255))
end

--[[ 

    -- Shit code, dont re-use. broken by garry code

do  
    local grip = {}
 
    function grip:Init() 
        self.colors = {}
        self.colors.background = dark(125)
        self.colors.dragging = dark(175)
    end

    function grip:OnMousePressed()
        self:GetParent():Grip( 1 )
    end

    function grip:Paint( w, h )
        if self:GetParent().Dragging == true then 
            draw.RoundedBox(0,0,0,w,h,self.colors.dragging)
        else   
            draw.RoundedBox(0,0,0,w,h,self.colors.background)
        end 
    end

    vgui.Register("DSleekScrollbarGrip", grip, "DPanel")
end 

do 
    local scrollbar = {}

    function scrollbar:Init()
        self.colors = {}

        self.colors.background = dark(50)
        self.colors.

        self.btnUp = vgui.Create( "DSleekButton", self )
        self.btnUp.colors.background = dark(90)
        self.btnUp:SetText("+")
        self.btnUp:SetFont("Consolas", 15)
        self.btnUp.DoClick = function( self ) self:GetParent():AddScroll( -1 ) end
        self.btnUp.OnClick = function( self ) self:GetParent():AddScroll( -1 ) end

        self.btnDown = vgui.Create( "DSleekButton", self )
        self.btnDown.colors.background = dark(90)
        self.btnDown:SetText("-")
        self.btnDown:SetFont("Consolas", 15)
        self.btnDown.DoClick = function( self ) self:GetParent():AddScroll( 1 ) end
        self.btnDown.OnClick = function( self ) self:GetParent():AddScroll( 1 ) end

    --    self.btnGrip = vgui.Create( "DSleekScrollbarGrip", self )

        self:SetHideButtons( true )
        self:SetSize( 15, 0 )
    end

    function scrollbar:Paint(w, h)
        draw.RoundedBox(0,0,0,w,h,self.colors.background)
    end

    function scrollbar:PerformLayout()

        local Wide = self:GetWide()
        local BtnHeight = Wide
        if ( self:GetHideButtons() ) then BtnHeight = 0 end
        local Scroll = self:GetScroll() / self.CanvasSize
        local BarSize = math.max( self:BarScale() * ( self:GetTall() - ( BtnHeight * 2 ) ), 10 )
        local Track = self:GetTall() - ( BtnHeight * 2 ) - BarSize
        Track = Track + 1
    
        Scroll = Scroll * Track
    
        self.btnGrip:SetPos( 0, BtnHeight + Scroll )
        self.btnGrip:SetSize( Wide, BarSize )
    
        if ( BtnHeight > 0 ) then
            self.btnUp:SetPos( 0, 0, Wide, Wide )
            self.btnUp:SetSize( Wide, BtnHeight )
    
            self.btnDown:SetPos( 0, self:GetTall() - BtnHeight )
            self.btnDown:SetSize( Wide, BtnHeight )
            
            self.btnUp:SetVisible( true )
            self.btnDown:SetVisible( true )
        else
            self.btnUp:SetVisible( false )
            self.btnDown:SetVisible( false )
            self.btnDown:SetSize( Wide, BtnHeight )
            self.btnUp:SetSize( Wide, BtnHeight )
        end

    end

    vgui.Register("DSleekScrollbar", scrollbar, "DVScrollBar")
end 
]]