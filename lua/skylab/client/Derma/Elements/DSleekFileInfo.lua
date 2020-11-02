if not SSLE then 
	return 
end

local function dark(i)
    return Color(i,i,i)
end

local function limitWidth(str, charW, max)
    if #str * charW > max then 
        return ".." .. string.sub(str, -(max / charW) + 2, #str)
    end
    return str 
end

local fontbank = {}

local self = {}

function self:Init()
	self.colors.infotype   = Color(220,110,0) 
	self.colors.infodata   = dark(225)

	self.labels = {}

	self.file = {}
	self.root = ""
	self.directory = ""

	self.font = {
		w  = 0,
		h  = 0,
		s  = 0,
		n  = "",
		an = "",
		w  = 0
	}

	self:SetFont("Consolas", 18, 600)
end 

function self:SetFont(font, size, weight, otherConfig)
	font   = font or "Consolas"
	size   = size or 16 
	weight = weight or 500

	size = math.Clamp(size, 8, 48)

	local name = "FiFXD"..font..size 
	if not fontbank[name] then 
		local config = {
			font = font,
			size = size,
			weight = weight
		}

		if otherConfig then table.Merge(config, otherConfig) end

		surface.CreateFont(name, config)

		fontbank[name] = config 
	end

	surface.SetFont(name)
	
	local w, h  = surface.GetTextSize(" ")
	
	self.font = {
		w = w,
		h = h, 
		s = size,
		weight = weight,
		n = name,
		an = font
	}
end

function self:Reset()
	for i, info in pairs(self.labels) do 
		if not info then continue end 

		local iLabel = info[1]
		local dLabel = info[2]

		if iLabel then iLabel:Remove() end 
		if dLabel then dLabel:Remove() end 
	end 
	self.labels = {}
end

function self:SetFile(root, directory)
	if not root then return end 
	if not directory then return end 

	self.root = root 
	self.directory = directory 

	local bytes = file.Size(directory, root) 

	self.file = {}

	local function add(id, text)
		self.file[#self.file + 1] = {
			id = id, 
			text = text
		}
	end

	add("Directory", directory)
	add("Root", root)
	add("Extension", "." .. (string.GetExtensionFromFilename(directory or "") or "Invalid Extension"))
	add("Total Bytes", bytes)
	add("Actual size", getFilesize(bytes))
	add("Last change", os.date("%d.%m.%Y", file.Time(directory, root)))

	-- Delete old labels 
	if #self.labels > 0 then 
		for _, labels in pairs(self.labels) do 
			if labels[1].Remove then labels[1]:Remove() end
			if labels[2].Remove then labels[2]:Remove() end
		end
	end

	self.labels = {}

	local function setLabelDefaults(el)
		if not el then return end 
		el:SetCursor("hand")
		el:SetMouseInputEnabled(true)
		el.DoClick = function(self)
			if not self.GetText or not self:GetText() or self:GetText() == "" then return end 
			SetClipboardText(self.defaultText and self.defaultText or self:GetText())
		end
	end

	for _, f in pairs(self.file) do
		local id = f.id 
		local data = f.text
		
		if not id or not data then continue end 

 		local infotypelabel = vgui.Create("DLabel", self)
		infotypelabel:SetText(id .. ": ")
		infotypelabel:SetFont(self.font.n)
		infotypelabel:SetTextColor(self.colors.infotype)

		local datalabel = vgui.Create("DLabel", self)
		datalabel.defaultText = tostring(data or "") 
		datalabel:SetText(data)
		datalabel:SetFont(self.font.n)
		datalabel:SetTextColor(self.colors.infodata)
		datalabel:SetTooltip("Copy to Clipboard")

--		setLabelDefaults(infotypelabel)
		setLabelDefaults(datalabel)

		table.insert(self.labels, {infotypelabel, datalabel})
	end
end

function self:Paint(w, h)
	draw.RoundedBox(0,0,0,w,h,self.colors.background)

	if not self.labels or #self.labels == 0 then 
		draw.SimpleText("-", self.font.n, w / 2 - self.font.w / 2, h / 2 - self.font.h / 2, Color(255,255,255))
	end 
end

function self:PerformLayout(w, h)
	if not self.labels then return end 
	if #self.labels == 0 then return end 

	local sep = (h / #self.labels) - self.font.h / 2
	
	for i, info in pairs(self.labels) do 
		if not info then continue end 

		local iLabel = info[1]
		local dLabel = info[2]

		if not iLabel or not dLabel then break end 

		iLabel:SetPos(10, i * sep)
		iLabel:SizeToContents()
		iLabel:SetSize(iLabel:GetWide(), self.font.h)

		local iW, iH = iLabel:GetSize()

		dLabel:SetPos(10 + iW, i * sep)
		dLabel:SetSize(9999, self.font.h)
		dLabel:SetText(limitWidth(dLabel.defaultText, self.font.w, w - 20 - iW ))
	end
end

vgui.Register("DSleekFileInfo", self, "DSleekPanel")