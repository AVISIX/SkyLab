--[[
	To Do:

	- Implement usage for https://wiki.facepunch.com/gmod/DTree_Node:GetChildNodeCount 
	  and https://wiki.facepunch.com/gmod/DTree_Node:GetChildNodes
	  to Color the lines differently.
]]

if not SSLE then 
	MsgC(Color(255,0,0), "Couldn't mount Custom FileTree.") 
	return 
end

local function contains(haystack, needle)
	if not haystack or not needle then return false end 
	return haystack:find(needle) ~= nil 
end

local function dark(i)
    return Color(i,i,i)
end

local self = {} 

local filequeue = {}
do 
	local lastTime = 0
	local cur = 1
	hook.Add("Think", "DSleekFileTree_File_Construction_Queue", function()
		if RealTime() <= lastTime then return end 
		if #filequeue == 0 then return end 
		if cur > #filequeue then cur = 1 end 

		local entry = filequeue[cur]

		if entry and entry.super and entry.super.CreateFileNode then 
			entry.super:CreateFileNode(entry.parent, entry.filename)
		end 

		table.remove(filequeue, cur)

		cur = cur + 1
		if cur > #filequeue then cur = 1 end 
		lastTime = RealTime() + 0.01	
	end)
end

local folderqueue = {}
do 
	local lastTime = 0
	local cur = 1
	hook.Add("Think", "DSleekFileTree_Folder_Construction_Queue", function()
		if RealTime() <= lastTime then return end 
		if #folderqueue == 0 then return end 

		if cur > #folderqueue then cur = 1 end 

		local entry = folderqueue[cur]

		if entry and entry.super and entry.super.LoadFiles then 
			local fi, fo = entry.super:LoadFiles(entry.directory, entry.root)
			entry.callback(fi, fo, entry.root, entry.directory)
			entry.super:AddFileNodes(entry.directory)
		end 

		table.remove(folderqueue, cur)

		cur = cur + 1
		if cur > #folderqueue then cur = 1 end 
		lastTime = RealTime() + 0.05 
	end)
end 

function self:Init()
	self.colors = {}
	self.colors.background = dark(50)
	self.colors.text = dark(200)

	self.roots = {
		["GAME"] = 1,
		["LUA"] = 1,
		["lcl"] = 1,
		["lsv"] = 1,
		["LuaMenu"] = 1,
		["DATA"] = 1,
		["DOWNLOAD"] = 1,
		["MOD"] = 1,
		["BASE_PATH"] = 1,
		["EXECUTABLE_PATH"] = 1,
		["THIRDPARTY"] = 1,
		["WORKSHOP"] =1
	}

	self.showfiles = false

	self.loaded = {}

	self.fileCache = {}

	self.selectedNode = {}

	scrollbarOverride(self.VBar)
end 

function self:Paint(w, h)
	draw.RoundedBox(0,0,0,w,h,self.colors.background)
end

-- Override these
function self:NodeSelected(node) end
function self:NodeExpanded(node) end
function self:NodeCreated(node)  end
function self:FileNodeCreated(node) end

function self:SetShowFiles(status)
	if not status then return end 
	self.showfiles = status 
end

function self:CreateFileNode(parent, filename)
	if not parent or not filename or not parent.AddNode then return end 

	local fileNode = parent:AddNode(filename)

	fileNode.type = "file"
	fileNode.filename = filename 
	fileNode.directory = parent.directory  
	fileNode.root = self.root 

	fileNode.Label:SetTextColor(self.colors.text)

	local extension = string.GetExtensionFromFilename(filename)
	if SSLE.imageextensions[extension] then 
		fileNode:SetIcon("icon16/page_white_camera.png")
	elseif SSLE.videoextensions[extension] then 
		fileNode:SetIcon("icon16/page_white_cd.png")
	elseif SSLE.codeextensions[extension] then 
		fileNode:SetIcon("icon16/page_white_code_reg.png")
	else
		fileNode:SetIcon("icon16/page_white.png")
	end

	fileNode.OnMenuConstructed = function() end
	fileNode.OnMenuConstructionFinished = function() end 
	fileNode.OnOptionAdded = function() end 
	fileNode.DoRightClick = function(self)
		local menu = DermaMenu()

		self:OnMenuConstructed(menu)

		menu:AddOption("Copy Root", function() SetClipboardText(self.root) end)
		self:OnOptionAdded(menu, "Copy Root")

		menu:AddOption("Copy Filepath", function() SetClipboardText(self.directory .. self.filename) end)
		self:OnOptionAdded(menu, "Copy Filepath")

		self:OnMenuConstructionFinished(menu)

		menu:Open()
	end

	self:FileNodeCreated(fileNode)
end

function self:AddFileNodes(directory)
	if self.showfiles == false then return end  
	local fi, _ = self:LoadFiles(directory, self.root) 
	local node = self:NodeForDirectory(directory) 
	if not node then return end 

	local c = 0
	for k, v in pairs(fi) do 
		if not v then continue end 
		
		if c < 25 then 
			self:CreateFileNode(node, v)
			c = c + 1
			continue 
		end 

		table.insert(filequeue, {
			filename = v,
			directory = directory,
			root = self.root, 
			parent = node,
			super = self
		})
	end

end

function self:QueueDirectory(directory, root, callback, shouldQueue)
	if self.fileCache[directory] then 
		callback(self.fileCache[directory][1] or {}, self.fileCache[directory][2] or {})
		return 
	end
	
	if shouldQueue == nil then shouldQueue = true end 
	if shouldQueue == false then 
		local fi, fo = self:LoadFiles(directory, root)
		callback(fi, fo)
		self:AddFileNodes(directory)
		return 
	end

	table.insert(folderqueue, {
		directory = directory,
		root = root, 
		callback = callback,
		super = self
	})
end

function self:LoadFiles(directory, root)
	if not directory or not root then return end 
	if self.fileCache[directory] then return self.fileCache[directory][1], self.fileCache[directory][2] end 
	if directory == root or directory == "/" then directory = "" end 

	local fi, fo = file.Find(directory .. "*", root)

	self.fileCache[string.gsub(directory, "%s", "") == "" and root or directory] = {fi,fo}

	return fi, fo 
end

-- Create the Filetree recursively 
function self:Construct(root, directory, parent, maxRecursion, curRecursion, shouldQueue)
	if not root or not directory or not parent then return end 

	if type(curRecursion) == "boolean" or type(curRecursion) == "string" then 
		shouldQueue  = curRecursion
		curRecursion = 0
	elseif type(maxRecursion) == "boolean" or type(maxRecursion) == "string" then 
		shouldQueue  = maxRecursion
		maxRecursion = 0 
	end

	maxRecursion = maxRecursion or math.huge -- If its not defined, then just keep constructing 
	curRecursion = curRecursion or 0

	if shouldQueue == nil then shouldQueue = true end 
	local tree = self 

	self:QueueDirectory(directory, root, function(fi, fo, kill)
		fi = fi or {}
		fo = fo or {}
		
		-- If it has files, set its Icon to something else
		if #fi > 0 
		and directory ~= "" 
		and directory ~= root 
		and parent 
		and parent.SetIcon 
		and parent:GetIcon() ~= "icon16/application_xp_terminal.png"
		then 
			parent:SetIcon("icon16/folder_page.png")
		end

		for k,v in pairs(fo or {}) do 
			if string.gsub(v, "%s", "") == "" or v == "/" then continue end 

			local newdir = (directory ~= root and directory or "") .. v .. "/"

			local newParent 
			if not self.loaded[newdir] and parent.AddNode then 
				newParent = parent:AddNode(v)
				newParent.OnMenuConstructed = function() end
				newParent.OnMenuConstructionFinished = function() end 
				newParent.OnOptionAdded = function() end 
				newParent.DoRightClick = function(self)
					local menu = DermaMenu()

					newParent:OnMenuConstructed(menu)

					menu:AddOption("Open", function()   
						newParent:SetExpanded(true)
						tree:SetSelectedItem(newParent) 
					end)
					newParent:OnOptionAdded(menu, "Open")

					menu:AddOption("Copy Root", function()     SetClipboardText(root)   end)
					newParent:OnOptionAdded(menu, "Copy Root")	

					menu:AddOption("Copy Filepath", function() SetClipboardText(newdir) end)
					newParent:OnOptionAdded(menu, "Copy Filepath")		

					newParent:OnMenuConstructionFinished(menu)
					
					menu:Open()
				end

				self:NodeCreated(newParent) 
				self.loaded[newdir] = newParent 
			else 
				newParent = self.loaded[newdir]
			end

			newParent.Label:SetTextColor(self.colors.text)
			newParent.directory = newdir
			newParent.type = "folder"
			newParent.Expander.DoClick = function(s) 
				local node = s:GetParent()
				node:SetExpanded(!node.m_bExpanded) 
				self:Construct(root, node.directory, node, 1)
				tree:NodeExpanded(node)
			end

			if curRecursion < maxRecursion then 
				self:Construct(root, newdir, newParent, maxRecursion, curRecursion + 1, shouldQueue)
			end
		end
	end, shouldQueue)
end

function self:OpenDirectory(root, directory, parent, shouldQueue, animate)
	if shouldQueue == nil then shouldQueue = true end
	if not root or not directory then return end
	if not parent then parent = self:NodeForDirectory(directory) end 

	if animate == nil then animate = true end  
	animate = !animate 

	local tree = self 
	local directories = string.Split(directory, "/")

	local constructor = ""
	local node 
	for k, v in pairs(directories) do 
		if v == "" or string.gsub(v, "%s", "") == "" then continue end 

		constructor = constructor .. v .. "/"

		node = self:NodeForDirectory(constructor)
		if not node then break end 

		self:Construct(root, constructor, node, 1, 0, shouldQueue)

		if node.m_bExpanded == true then continue end 

		node:SetExpanded(true, animate)
	end
	
	if node and tree.m_pSelectedItem ~= node then 
		tree:SetSelectedItem(node)
	end 

	return node 
end

function self:SearchFile(root, directory, file, useLCS, ratings, limit)
	if not root or not directory or not file then return nil end 
	local parent = self:NodeForDirectory(directory)

	if type(ratings) == "number" then 
		limit = ratings 
		ratings = {}
	else 
		ratings = ratings or {}
	end 

	if useLCS == nil then useLCS = true end 

	local function fixFile(f)
		if f:find(".") then 
			f = string.Split(f, ".")
			if #f > 2 then f = table.concat(f, ".", 1, #f - 1) end 
			return f[1]
		end
		return f
	end

	local function reachedLimit(toCheck)
		if useLCS == false or not limit or type(limit) ~= "number" or limit == math.huge then return false end 
		local counter = 0
		for _, v in pairs(toCheck or ratings) do 
			if not v or type(v) ~= "table" then continue end 
			counter = counter + #v 
			if counter >= limit then return true end 
		end 
		return false 
	end

	if reachedLimit() == true then return ratings end 

	local function check()
		local files = self.fileCache[directory][1]
		for _, v in pairs(files) do
			if not v then continue end 
			local f = fixFile(v) 
			if useLCS == true then 
				local lcs_rating = SSLE.modules.lcs.lcs_3b(file, f) -- Use LCS to see which are the most similar 
				if lcs_rating >= #file then 
					if not ratings[lcs_rating] then ratings[lcs_rating] = {} end
					table.insert(ratings[lcs_rating], {root=root,directory=directory,file=v,fixed=f})
				end
			elseif f == file  then -- If LCS is disabled, just search for the exactly same word
				return root, directory, files, self.fileCache[directory][2], ratings
			end
		end
		return nil 
	end

	if not self.fileCache[directory] then  
		self:LoadFiles(directory, root)
	end

	if useLCS == false then 
		local a,b,c,d,e = check() 
		if a then return a,b,c,d,e end 
	else 
		check()
	end 

	if reachedLimit() == true then return ratings end 

	for k, v in pairs(self.fileCache[directory][2]) do 
		if not v then continue end 

		local a, b, c, d, e = self:SearchFile(root, directory .. v .. "/", file, useLCS, ratings)

		if useLCS == true then 
			if reachedLimit(a) == true then break end 
			ratings = a 
			continue 
		end

		if a then 
			return a,b,c,d,e 
		end 
	end

	if useLCS == true then return ratings end 

	return nil  
end

function self:SelectedDirectory()
	if not self.m_pSelectedItem then return "" end 
	return self.m_pSelectedItem.directory
end

function self:NodeForDirectory(directory)
	return self.loaded[directory == "" and self.root or directory]
end

function self:OnNodeSelected(node)
	self:NodeSelected(node)

	if node.type ~= "folder" then return end 

	self:Construct(self.root, node.directory, node, 1)

	self.selectedNode = node 
end

function self:SetRoot(root, directory)
	if not self.roots[root] then return end 
	
	directory = directory or ""

	self:Clear()

	for k, v in pairs(folderqueue) do 
		if v.super ~= self then continue end 
		table.remove(folderqueue, k)
	end

	self.loaded = {}
	self.fileCache = {}

	local rn = self:AddNode(root .. (directory ~= "" and "/" .. directory or ""), "icon16/application_xp_terminal.png")
	rn.directory = (directory ~= "" and directory or root)
	rn.type      = "folder"
	rn:SetExpanded(true, true)
	rn.Label:SetTextColor(self.colors.text)

	self:NodeCreated(rn)
	
	self.root = root 
	self.loaded[directory ~= "" and directory or root] = rn

	self.superNode = rn 

	self:Construct(root, directory, rn, 1, 0, false)
end

function self:Reload(openLastDirectory)
	if openLastDirectory == nil then openLastDirectory = true end 

	local lastDir = self:SelectedDirectory()

	self:SetRoot(self.root, self.superNode.directory ~= root and self.superNode.directory)

	if openLastDirectory == true and lastDir then 
		self:OpenDirectory(self.root, lastDir, nil, false, false)

		local selected = self:NodeForDirectory(lastDir)

		if not selected then return end 
        
		self:ScrollToChild(selected)
	end
end

function self:GetRoot()
	self:Root().Label:GetText()
end


vgui.Register("DSleekFileTree", self, "DTree")