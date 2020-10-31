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

    if self.filename == "" then -- User didn't select a Folder 
        self.seperator = vgui.Create("DHorizontalDivider", self)
        self.seperator:SetLeftMin(100)
        self.seperator:SetRightMin(200)
        self.seperator:SetLeftWidth(gc("SkyLab Seperator W", 150))
        self.seperator:Dock(FILL)   
        self.seperator.Paint = function(self, w, h) draw.RoundedBox(0,0,0,w,h,dark(150)) end

        self.sidebar = vgui.Create("DPanel")
        self.sidebar.Paint = function(self,w,h) 
            draw.RoundedBox(0,0,0,w,h,Color(0,255,0)) 
        end 

        self.maincontainer = vgui.Create("DPanel")
        super = self.maincontainer

        self.seperator:SetRight(self.maincontainer)
        self.seperator:SetLeft(self.sidebar)
    end

    self.topbar = vgui.Create("DPanel", super)
    self.topbar:Dock(TOP)
    self.topbar.Paint = function(self,w,h) 
        draw.RoundedBox(0,0,0,w,h,Color(255,0,0))
    end 

    self.main = vgui.Create("DPanel", super)
    self.main:Dock(FILL)
    self.main.Paint = function(self,w,h) 
        draw.RoundedBox(0,0,0,w,h,Color(0,0,255))
    end 

    self:CreateElements()
end

function self:CreateElements()
    super = self 

    if IsValid(self.seperator) == true then
        local blockSearch = false
  
        self.searchbar = vgui.Create("DSleekTextBox", self.sidebar)
        self.searchbar:Dock(TOP)
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
                local root = super.tree.root 
                local dir  = super.tree.superNode.directory

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
            node.OnMenuConstructionFinished = function(self, menu)
                menu:AddOption("Open in FileBrowser", function() 
                    SSLE:OpenBrowser(">" .. super.tree.root .. "/" .. node.directory, function(r, d)
                        super:OpenDirectory(r, d)
                    end)

                    if not SSLE.browserPopup then return end 

                    local browser = SSLE.browserWindow
                    local list    = browser.list 

                    list:ClearSelection()

                    local found = false     
                    
                    ::again::

                    for _, v in pairs(list:GetLines()) do 
                        if not v then continue end 
                        local text = v:GetColumnText(1) 
                        if not text then continue end 
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
        end
    end


end

function self:Init()
    self.lastDir = ""
    self.root = ""
    self.directory = ""
    self.filename = ""

    self:CreateViews()
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
end

vgui.Register("SkyLab_Editor", self, "DSleekWindow") 