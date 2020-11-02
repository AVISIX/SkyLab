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
