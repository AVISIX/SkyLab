if not SSLE then 
	return 
end

local cache = SSLE.modules.cache 

local function gc(s, d) return tonumber(cache:Value4Key(s) or tostring(d)) or d end

local function checkFilepath(root, dir)
    if not dir then 
        local dirs = string.Split(root, "/")

        if #dirs >= 2 then
            root = validateRoot(dirs[1][1] == ">" and string.sub(dirs[1], 2, #dirs[1]) or dirs[1])
            dir = table.concat(dirs, "/", 2, #dirs) 
        end
    else
        dir = (dir[1] == ">" and string.sub(dir, 2, #dir) or dir)
    end

    return root, dir
 end

 local function addOutline(element, col)
    local x, y = element:GetPos()
    local ow, oh = element:GetSize()
    draw.RoundedBox(0, x - 1, y - 1, ow + 2, oh + 2, col)
end

local function dark(i)
    return Color(i,i,i)
end

local self = {}

skylab_editor_search_timer_counter = 0
function self:CreateViews()
    skylab_editor_search_timer_counter = skylab_editor_search_timer_counter + 1

    local super = self 
    local owner = self 

    if self.filename == "" then -- User didn't select a File  
        self.seperator = vgui.Create("DHorizontalDivider", self)
        self.seperator:SetLeftMin(100)
        self.seperator:SetRightMin(465)
        self.seperator:SetLeftWidth(gc("SkyLab Seperator W", 150))
        self.seperator:Dock(FILL)   
        self.seperator.Paint = function(self, w, h) 
            draw.RoundedBox(0,0,0,w,h,dark(150)) 
        end

        self.sidebar = vgui.Create("DSleekPanel")
        self.sidebar.Paint = function(self,w,h) end 

        self.maincontainer = vgui.Create("DSleekPanel")
        owner = self.maincontainer

        self.seperator:SetRight(self.maincontainer)
        self.seperator:SetLeft(self.sidebar)    
    end

    self.navbar = vgui.Create("DSleekPanel", owner)
    self.navbar:Dock(TOP)

    self.footer = vgui.Create("DSleekPanel", owner)
    self.footer:Dock(BOTTOM)
    self.footer.Paint = function(self,w,h) 
        draw.RoundedBox(0,0,0,w,h,Color(0,255,0))
    end 

    self.main = vgui.Create("DSleekPanel", owner)
    self.main:Dock(FILL)
    self.main.Paint = function(self,w,h) 
        draw.RoundedBox(0,0,0,w,h,Color(0,0,255))
    end 

    self:CreateElements()
end

function self:IsFolderSelected()
    return self.filename == ""
end 

function self:OpenFile(root, fileDir)
    if not fileDir then return end 
    if file.Exists(fileDir, root) == false then return end 

    local fileName = string.GetFileFromFilename(fileDir)

    if string.gsub(fileName, "%s", "") == "" then return end 

    local extension = string.GetExtensionFromFilename(fileName)

    local editor = vgui.Create("DSyntaxBox")
    
    local found = false 
    for id, _ in pairs(SSLE.profiles) do 
        local profile = SSLE.GetProfile(id)
        
        if not profile then continue end 
        
        local found = false 

        if profile.filetype and profile.filetype == extension then 
            editor:SetProfile(profile)
            found = true 
        end

        if found == true then break end 

        if not profile.commonDirectories then continue end 

        for _, directory in pairs(profile.commonDirectories) do 
            if directory.root == self.root and string.GetPathFromFilename(fileDir):find(directory.directory) and profile.defaultContent then 
                editor:SetProfile(profile)
                found = true 
                break
            end
        end

        if found == true then break end 
    end

    editor:SetText(file.Read(fileDir, root))
    editor:Dock(FILL)

    self.tabulator:AddTab(fileName, editor, true)
end

function self:CreateElements()
    super = self 

    if IsValid(self.seperator) == true then
        local blockSearch = false
  
        self.searchbar = vgui.Create("DSleekTextBox", self.sidebar)
        self.searchbar:Dock(TOP)
        self.searchbar:SetFont("Consolas", 16)
        self.searchbar:SetPlaceholderText("Search...")
        self.searchbar.TextChanged = function(self) 
            if blockSearch == true then 
                blockSearch = false 
                return 
            end 

            local tid = "search_editor_textchanged_timer" .. skylab_editor_search_timer_counter

            if timer.Exists(tid) == true then timer.Remove(tid) end 
            
            timer.Create(tid, 1, 1, function()
                local text = self:GetText()

                super.tree:Reload()

                if text == "" then return end

                local tree = super.tree 
                local root = tree.root 
                local dir  = tree.superNode.directory

                if not root or not dir then return end 

                super.tree:SearchFile(root, dir, text, true, 25) -- All the Search results :D 
                tree:RevealSearchResults()
            end)
        end

        self.tree = vgui.Create("DSleekFileTree", self.sidebar)
        self.tree:Dock(FILL)
        self.tree:SetShowFiles(true)
        self.tree.OnMousePressed = function(self)
            self:RequestFocus()
        end
        self.tree.NodeCreated = function(self, node)
            node.OnMenuConstructionFinished = function(self, menu)
                menu:AddOption("Open in FileBrowser", function() 
                    SSLE:OpenBrowser(">" .. super.tree.root .. "/" .. node.directory, function(r, d)
                        super:OpenDirectory(r, d)
                    end)
                end)
            end
        end
        self.tree.FileNodeCreated = function(self, node)
            local tree = self

            node.Label.DoDoubleClick = function() 
                super:OpenFile(tree.root, node.path)
                node:InternalDoClick() 
            end

            node.OnMenuConstructed = function(self, menu)
                menu:AddOption("Open", function()
                    super:OpenFile(tree.root, node.path)
                end)
            end

            node.OnMenuConstructionFinished = function(self, menu)
                menu:AddOption("Open in FileBrowser", function() 
                    SSLE:OpenBrowser(">" .. super.tree.root .. "/" .. node.directory, function(r, d) super:OpenDirectory(r, d) end)

                    if not SSLE.browserPopup then return end 

                    local browser = SSLE.browserWindow
                    local list    = browser.list 

                    list:ClearSelection()

                    local found = false     
                    
                    ::again::

                    for _, v in pairs(list:GetLines()) do 
                        if not v then continue end 
                        local text = v:GetColumnText(1) or ""
                        if node.filename:find(text .. "(%.).*") then 
                            v:SetSelected(true)
                            list:OnRowSelected(v:GetID(), v)
                            found = true
                            break 
                        end
                    end

                    if found == false then 
                        list.queue = {}
                        browser:ReloadList(false)
                        found = true
                        goto again  
                    end           
                end)
            end
        end 
        self.tree.OnFileAdded = function(self, dir) -- When a File gets added, insert the default content from the profile for the language
            if not dir or #dir == 0 then return end 
            for id, _ in pairs(SSLE.profiles) do 
                local profile = SSLE.GetProfile(id)
                
                if not profile or not profile.commonDirectories then continue end 
                
                for _, directory in pairs(profile.commonDirectories) do 
                    if directory.root == self.root and string.GetPathFromFilename(dir):find(directory.directory) and profile.defaultContent then 
                        file.Append(dir, profile.defaultContent)
                        break
                    end
                end
            end
        end
        self.tree:SetRoot(self.root, self.directory)

        self.reload = vgui.Create("DSleekButton", self.sidebar)
        self.reload:Dock(BOTTOM)
        self.reload:SetImage("icon16/arrow_refresh.png", 5)
        self.reload:SetText("Reload")
        self.reload:SetImageTextLayout(B_LAYOUT_LEFT)
        self.reload.OnClick = function() 
            blockSearch = true 
            super.searchbar:SetText("")
            super.tree:Reload(true) 
            super.tree:RequestFocus()
        end
    end



    -- Navbar Elements
    self.oBrowser = vgui.Create("DSleekButton", self.navbar)
    self.oBrowser:Dock(LEFT)
    self.oBrowser:SetText("Open Filebrowser")
    self.oBrowser:SetImage("icon16/folder_heart.png", 5)
    self.oBrowser:SetImageTextLayout(B_LAYOUT_LEFT)
    self.oBrowser:SetFont("Consolas", 14)
    self.oBrowser:SizeToContents()
    self.oBrowser.OnClick = function()
        SSLE:OpenBrowser(function(r, d) super:OpenDirectory(r, d) end)
    end

    self.saveFile = vgui.Create("DSleekButton", self.navbar)
    self.saveFile:Dock(LEFT)
    self.saveFile:SetImage("icon16/disk.png", 5)
    self.saveFile:SizeToContents()
    SSLE:Tooltip(self.saveFile, "Save the File")

    self.addFile = vgui.Create("DSleekButton", self.navbar)
    self.addFile:Dock(LEFT)
    self.addFile:SetImage("icon16/page_add.png", 5)
    self.addFile:SizeToContents()
    SSLE:Tooltip(self.addFile, "Add a new Tab")

    self.delFile = vgui.Create("DSleekButton", self.navbar)
    self.delFile:Dock(LEFT)
    self.delFile:SetImage("icon16/page_delete.png", 5)
    self.delFile:SizeToContents()
    SSLE:Tooltip(self.delFile, "Close this Tab")

    self.saveexit = vgui.Create("DSleekButton", self.navbar)
    self.saveexit:Dock(RIGHT)
    self.saveexit:SetImage("icon16/house_go.png", 5)
    self.saveexit:SetText("Save & Exit")
    self.saveexit:SetImageTextLayout(B_LAYOUT_LEFT)
    self.saveexit:SetFont("Consolas", 14)
    self.saveexit:SizeToContents()   

    self.settings = vgui.Create("DSleekButton", self.navbar)
    self.settings:Dock(RIGHT)
    self.settings:SetImage("icon16/cog.png", 5)
    self.settings:SizeToContents()   
    SSLE:Tooltip(self.settings, "Open Settings")
    
    self.colorpicker = vgui.Create("DSleekButton", self.navbar)
    self.colorpicker:Dock(RIGHT)
    self.colorpicker:SetImage("icon16/palette.png", 5)
    self.colorpicker:SizeToContents()   
    SSLE:Tooltip(self.colorpicker, "Open Colorpicker")
    
    self.soundbrowser = vgui.Create("DSleekButton", self.navbar)
    self.soundbrowser:Dock(RIGHT)
    self.soundbrowser:SetImage("icon16/bell.png", 5)
    self.soundbrowser:SizeToContents()   
    SSLE:Tooltip(self.soundbrowser, "Open Soundbrowser")



    -- Main 
    self.tabulator = vgui.Create("DSleekTabulator", self.main)
    self.tabulator:Dock(FILL)

    if IsValid(self.seperator) == false then self:OpenFile(self.root, self.directory) end 
end

function self:Init()
    self.lastDir = ""
    self.root = ""
    self.directory = ""
    self.filename = ""
end

function self:Close()
    if IsValid(self.seperator) == true then 
        cache:Value4Key("SkyLab Seperator W", self.seperator:GetLeftWidth())
    end 

	self:BeforeClose()
	self:SetVisible( false )
    self:Remove()
end

function self:OpenDirectory(root, directory, filename)
    if not root then return end 

    if not directory then 
        root, directory = checkFilepath(root)
    end

    filename = filename or string.GetFileFromFilename(directory)

    self.root = root 
    self.directory = directory 
    self.filename = filename 

    if IsValid(self.main) == false or self.root .. "/" .. self.directory .. self.filename ~= self.lastDir then 
        self:CreateViews()
        self.lastDir = self.root .. "/" .. self.directory .. self.filename 
    end 

    self:SetVisible(true)

    self:Clear()

    self:CreateViews()
end

vgui.Register("SkyLab_Editor", self, "DSleekWindow") 