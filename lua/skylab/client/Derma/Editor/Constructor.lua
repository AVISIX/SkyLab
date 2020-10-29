if not SSLE then 
	return 
end

local cache = SSLE.modules.cache 

local self = {}
self.__index = self 

local defaultX, defaultY = 0,   0
local defaultW, defaultH = 760, 480

function self:Open(root, directory, file)
	if not root then 
		root = cache:Value4Key("SkyLab Last Closed Directory") or ""
		if root == "" then return end 
	end 

	if IsValid(self.window) == false then 
		self.window = vgui.Create("SkyLab_Editor")
		self.window:SetTitle("SkyLab Editor")
		self.window:SetIcon("icon16/pencil.png")
		self.window:SetDraggable(true) 
		self.window:SetSizable(true)
		self.window:SetMinWidth(defaultW)
		self.window:SetMinHeight(defaultH)
		self.window:MakePopup()
	end

	self.window:OpenDirectory(root, directory, file)

	local function gc(s, d) return tonumber(cache:Value4Key(s) or tostring(d)) or d end

	self.window:SetPos(gc("SkyLab Editor X", defaultX), gc("SkyLab Editor Y", defaultY))
	self.window:SetSize(gc("SkyLab Editor W", defaultW), gc("SkyLab Editor H", defaultH))

	self.window.BeforeClose = function(self) 
		cache:Value4Key("SkyLab Editor H", self:GetTall())
		cache:Value4Key("SkyLab Editor W",  self:GetWide())

		local x, y = self:GetPos()

		cache:Value4Key("SkyLab Editor X", x)
		cache:Value4Key("SkyLab Editor Y", y)

		cache:Value4Key("SkyLab Last Closed Directory", self.root .. "/" .. self.directory)

		self:Remove()
	end
end

function self:isActive()
	if not self.window then return false end 
	return self.window:IsVisible()
end	

SSLE.editor = self  