self = {}

function self:Init()
    self.colors = {}
    self.colors.background = Color(45,45,45)
end

function self:PaintAfter(w, h)
end

function self:Paint(w, h)
    draw.RoundedBox(0,0,0,w,h,self.colors.background)
    self:PaintAfter(w, h)
end

vgui.Register("DSleekPanel", self, "DPanel")