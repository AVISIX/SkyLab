if not SSLE then
	MsgC(Color(255,0,0), "Couldn't mount Custom TreeView.") 
	return 
end

local function dark(i)
    return Color(i,i,i)
end

local self = {}

function self:Init()

	self.colors = {}
	self.colors.background = dark(50)
	self.colors.text = dark(200)

	self.Paint = function(self, w, h)
		draw.RoundedBox(0,0,0,w,h,self.colors.background)
	end

end

--function self:Paint(w, h)
---	draw.RoundedBox(0,0,0,w,h,self.colors.background)
--end

vgui.Register("DSleekTree", self, "DTree")