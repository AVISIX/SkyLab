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

	self.lastRatings = {}

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

function self:OnFileAdded() end 
function self:OnFolderAdded() end 
function self:OnDeleted() end 

function self:SetShowFiles(status)
	if not status then return end 
	self.showfiles = status 
end

function self:CreateFileNode(parent, filename)
	if not parent or not filename or not parent.AddNode then return end 
	if self.loaded[parent.directory .. filename] then return end 

	local super = self 

	local fileNode = parent:AddNode(filename)

	fileNode.type = "file"
	fileNode.filename = filename 
	fileNode.directory = parent.directory  
	fileNode.path = parent.directory .. filename 
	fileNode.root = self.root 

	fileNode.Label:SetTextColor(self.colors.text)

	local extension = string.GetExtensionFromFilename(filename)
	if SSLE.imageextensions[extension] then 
		fileNode:SetIcon("icon16/page_white_camera.png")
	elseif SSLE.videoextensions[extension] then 
		fileNode:SetIcon("icon16/page_white_cd.png")
	elseif SSLE.codeextensions[extension] then 
		fileNode:SetIcon("icon16/page_white_code_red.png")
	else
		fileNode:SetIcon("icon16/page_white.png")
	end

	fileNode.OnMenuConstructed = function() end
	fileNode.OnMenuConstructionFinished = function() end 
	fileNode.OnOptionAdded = function() end 
	fileNode.DoRightClick = function(self)
		local menu = DermaMenu()

		self:OnMenuConstructed(menu)

		local function option(i, c)
			menu:AddOption(i, c)
			self:OnOptionAdded(menu, i)
		end

		if self.root == "DATA" then 
			option("Delete", function()
				SSLE:Confirm("Delete '" .. self.Label:GetText() .. "'?", function()
					if not self.directory then return end 
					file.Delete(self.directory .. self.filename)
					super:Reload(true)
					super:OnDeleted(self.directory .. self.filename)
				end, SSLE:GetWindow(self))
			end)
		end
		
		option("Copy Root", function() SetClipboardText(self.root) end)
		option("Copy Filepath", function() SetClipboardText(self.directory .. self.filename) end)

		self:OnMenuConstructionFinished(menu)

		menu:Open()
	end 

	if not self.loaded[parent.directory .. filename] then 
		self.loaded[parent.directory .. filename] = fileNode
 	end 

	self:FileNodeCreated(fileNode)
end

function self:CreateFolderNode(parent, directory, foldername)
	if self.loaded[directory] then return self.loaded[directory] end  

	if not foldername then 
		local subs = string.Split(directory, "/")
		foldername = subs[#subs]
	end

	local tree = self 
	local root = self.root 

	local node = parent:AddNode(foldername)
	node.OnMenuConstructed = function() end
	node.OnMenuConstructionFinished = function() end 
	node.OnOptionAdded = function() end 
	node.DoRightClick = function(self)
		local menu = DermaMenu()

		node:OnMenuConstructed(menu)

		local function option(i, c)
			menu:AddOption(i, c)
			node:OnOptionAdded(menu, i)
		end

		option(node.m_bExpanded == true and "Close" or "Open", function()
			node:SetExpanded(!node.m_bExpanded) 
			tree:Construct(root, node.directory, node, 1)
			tree:NodeExpanded(node)
		end)

		if root == "DATA" then 
			option("New File", function()
				SSLE:TextConfirm("Enter File Name", function(text)
					if string.gsub(text, "%s", "") == "" then return end 

					local newDir = directory 

					if newDir == root then 
						newDir = "" 
					end

					newDir = newDir .. text .. ".txt"

					file.Write(newDir, "")

					tree:Reload(true)
					
					tree:OnFileAdded(newDir)
				end, SSLE:GetWindow(self))
			end)

			option("New Folder", function()
				SSLE:TextConfirm("Enter Folder Name", function(text)
					if string.gsub(text, "%s", "") == "" then return end 

					local newDir = directory 

					if newDir == root then 
						newDir = "" 
					end

					newDir = newDir .. text .. "/"

					file.CreateDir(newDir)

					tree:Reload(true)
					
					local newNode = tree:NodeForDirectory(newDir)

					tree:OnFolderAdded(newDir)

					if IsValid(newNode) == false then return end  

					tree:OpenDirectory(root, newDir, tree.superNode, false, false)
				end, SSLE:GetWindow(tree))	
			end)

			local fi, fo = tree.fileCache[node.directory][1], tree.fileCache[node.directory][2]
			if #(fi or {}) == 0 and #(fo or {}) == 0  then 
				option("Delete", function()
					SSLE:Confirm("Delete '" .. node.Label:GetText() .. "'?", function()
						if not node.directory then return end 
						file.Delete(node.directory)
						tree:Reload(true)
						tree:OnDeleted(node.directory)
					end, SSLE:GetWindow(self))
				end)
			end 
		end 
	
		option("Copy Root", function()
			SetClipboardText(root)
		end)	

		option("Copy Filepath", function()
			SetClipboardText(directory)
		end)	

		node:OnMenuConstructionFinished(menu)
		
		menu:Open()
	end

	node.Label:SetTextColor(self.colors.text)
	node.directory = directory
	node.type = "folder"
	node.Expander.DoClick = function(s) 
		local node = s:GetParent()
		node:SetExpanded(!node.m_bExpanded) 
		self:Construct(root, node.directory, node, 1)
		self:NodeExpanded(node)
	end

	self:NodeCreated(node) 
	self.loaded[directory] = node 
	
	return node 
end

function self:AddFileNodes(directory, shouldQueue)
	if self.showfiles == false then return end  
	local fi, _ = self:LoadFiles(directory, self.root) 
	local node = self:NodeForDirectory(directory) 
	if not node then return end 
	if shouldQueue == nil then shouldQueue = true end 

	local c = 0
	for k, v in pairs(fi) do 
		if not v then continue end 
		
		if c < 25 or shouldQueue == false then 
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
		self:AddFileNodes(directory, shouldQueue)
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

			local newParent = self:CreateFolderNode(parent, newdir, v)

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

function self:GetSelectedNode()
	return self.selectedNode 
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

	local super = self 

	rn.DoRightClick = function(self)
		local menu = DermaMenu()

		if root == "DATA" then 
			menu:AddOption("New File", function()
				SSLE:TextConfirm("Enter File Name", function(text)
					if string.gsub(text, "%s", "") == "" then return end 

					local newDir = text .. ".txt"

					if directory ~= root then 
						newDir = directory .. newDir 
					end

					file.Write(newDir, "")

					super:Reload(true)

					super:OnFileAdded(newDir)

				end, SSLE:GetWindow(self))
			end)

			menu:AddOption("New Folder", function()
				SSLE:TextConfirm("Enter Folder Name", function(text)
					if string.gsub(text, "%s", "") == "" then return end 

					local newDir = text .. "/"

					if directory ~= root then 
						newDir = directory .. newDir 
					end

					file.CreateDir(newDir)

					super:Reload(true)

					local newNode = super:NodeForDirectory(newDir)

					super:OnFolderAdded(newDir)

					if IsValid(newNode) == false then return end  

					super:OpenDirectory(root, newDir, rn, false, false)
				end, SSLE:GetWindow(self))	
			end)
		end 

		menu:Open()
	end

	self:NodeCreated(rn)
	
	self.root = root 
	self.loaded[directory ~= "" and directory or root] = rn

	self.superNode = rn 

	self:Construct(root, directory, rn, 1, 0, false)
end

function self:Reload(openLastDirectory)
	if openLastDirectory == nil then openLastDirectory = true end 

	local lastDir 
	local sNode = self:GetSelectedNode()

	if sNode.type == "file" then 
		sNode = sNode:GetParent()
	end
	
	if sNode.m_bExpanded == true then 
		lastDir = sNode.directory 
	end

	self:SetRoot(self.root, self.superNode.directory ~= self.root and self.superNode.directory)

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

function self:SearchFile(root, directory, file, useLCS, limit)
	self.lastRatings = self:_SearchFile(root, directory, file, useLCS, {}, limit)
	return self.lastRatings 
end

function self:_SearchFile(root, directory, file, useLCS, ratings, limit)
	if not root or not directory or not file then return nil end 
	local parent = self:NodeForDirectory(directory)

	ratings = ratings or {}

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
		return #(toCheck or ratings) > limit 
	end

	if reachedLimit() == true then return ratings end 

	local function check()
		local files = (self.fileCache[directory] or {})[1] or {}
		for _, v in pairs(files) do
			if not v then continue end 
			local f = fixFile(v) 
			if useLCS == true then 
				local _,_,s = string.find(string.lower(f), "(" .. string.lower(file) .. ")")
				if s then 
					table.insert(ratings, 
					{
						root = root,
						directory = directory,
						file = v,
						fixed = f
					})
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

		local a, b, c, d, e = self:_SearchFile(root, directory .. v .. "/", file, useLCS, ratings)

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

function self:RevealSearchResults(ratings)
	if not ratings then 
		ratings = self.lastRatings 
		if not ratings then return end 
	end

	self.queue = {}

	local deletionQueue = {}

	local function registerSubnodesForDeletion(n)
		for k, v in pairs(n:GetChildNodes() or {}) do  
			if not v then continue end 
			local fp = v.directory .. (v.filename and v.filename or "")
			deletionQueue[fp] = v
			registerSubnodesForDeletion(v)
		end
	end

	registerSubnodesForDeletion(self.superNode)

	for k, v in ipairs(ratings) do 
		if not v then continue end 

		local subs = string.Split(v.directory .. v.file, "/")
		local constructor = ""

		for k, v in ipairs(subs) do 
			if not v or v == "" or string.gsub(v, "%s", "") == "" then continue end 

			local prevConstructor = constructor 

			if k == #subs and subs[#subs]:find("(%.)[a-zA-Z]+$") then 
				constructor = constructor .. v
				if not self.loaded[constructor] then  
					self:CreateFileNode(self:NodeForDirectory(prevConstructor), v) -- If the File exists but the Node hasnt been loaded yet, add it manually.
				end 
			else 
				constructor = constructor .. v .. "/"  
				if not self.loaded[constructor] then  
					self:CreateFolderNode(prevConstructor ~= "" and self:NodeForDirectory(constructor) or self.superNode, constructor, v) -- Same shit but for Folders ;)
				end 
			end 

			if deletionQueue[constructor] then deletionQueue[constructor] = nil end 

			local node = self:NodeForDirectory(constructor)

			if not node or node.type ~= "folder" or not node.SetExpanded then continue end

			node:SetExpanded(true)
		end
	end

	for _, v in pairs(deletionQueue) do
		if self.loaded[_] then self.loaded[_] = nil end
		v:Remove() 
	end
end

vgui.Register("DSleekFileTree", self, "DTree")