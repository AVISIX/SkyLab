--[[
    Custom Filebrowser

    Author: Sixmax
    Contact: sixmax@gmx.de

    Copyright, all rights reserved

    License: CC BY-NC-ND 3.0
    Licensed to Team Skylon (Sixmax & Evaneos[KOWAR])
]]


if not SSLE then 
	return 
end

local paths = {
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

-- These characters are NOT allowed in windows filepaths
local invalidChars = {
    ["<"]  = 1, 
    [">"]  = 1, 
    [":"]  = 1, 
    ["\""] = 1, 
    ["/"]  = 1, 
    ["\\"] = 1, 
    ["|"]  = 1, 
    ["?"]  = 1, 
    ["*"]  = 1
}

local function hasLower(hs, n)
    if not hs or not n then return nil end 
    for v, _ in pairs(hs) do 
        if string.lower(v) == string.lower(n) then 
            return v 
        end
    end     
    return nil 
end

local function addOutline(element, col)
    local x, y = element:GetPos()
    local ow, oh = element:GetSize()
    draw.RoundedBox(0, x - 1, y - 1, ow + 2, oh + 2, col)
end

local function dark(i)
    return Color(i,i,i)
end

local function validateRoot(root)
    local result = root 

    if not paths[root] then 
        if paths[string.lower(root)] then 
            return string.lower(root)
        elseif paths[string.upper(root)] then 
            return string.upper(root)
        end 

        return hasLower(paths, root) or "DATA" 
    end

    return result 
end

local function containsInvalid(str)
    if not str then return false end 
    for i = 1, #str, 1 do 
        if invalidChars[str[i]] ~= nil then return true end 
    end
    return false 
end

local function GetFontSize(name)
    surface.SetFont(name)
    return surface.GetTextSize(" ")
end

local function limitWidth(str, font, max)
    local w, h = GetFontSize(font)
    if #str * w > max then 
        return ".." .. string.sub(str, -(max / w) + 2, #str)
    end
    return str 
end

local function getPathArgs(path)
    if not path then return "","","" end 
    local dirs = string.Split(path, "/") or {}
    local temp = {}
    for i, dir in pairs(dirs) do 
        if containsInvalid(dir) == true then 
            break 
        end     
        temp[i] = dir 
    end
    local subs = ""
    local fn = ""
    if #temp > 1 then 
        subs = table.concat(temp, "/", 2, #temp - 1) or ""
        fn = temp[#temp] or ""
    end
    return temp[1] or "", subs, fn
end

skylab_filebrowser_search_timer_counter = 0

local filebrowser = {}

local cache = SSLE.modules.cache

function filebrowser:RootSwapped()
    --self.fileinfo.preview:ResetPreview()
    self:ClearPreview()
end

function filebrowser:GetFavorites()
    local f = cache:Value4Key("SkyLab FileBrowser Favorites")
    if not f then return nil end 
    return util.JSONToTable(f)
end

function filebrowser:AddFavorite(root, directory)
    local favorites = self:GetFavorites() or {}
    favorites[root] = favorites[root] or {}
    if favorites[root][directory] ~= nil then return end
    favorites[root][directory] = 1
    cache:Value4Key("SkyLab FileBrowser Favorites", util.TableToJSON(favorites))
end

function filebrowser:RemoveFavorite(root, directory)
    local favorites = self:GetFavorites() or {}
    favorites[root] = favorites[root] or {}
    if favorites[root][directory] == nil then return end
    favorites[root][directory] = nil 
    cache:Value4Key("SkyLab FileBrowser Favorites", util.TableToJSON(favorites))
end

function filebrowser:HasFavorite(root, directory)
    local favorites = self:GetFavorites() or {}
    if not favorites[root] then return false end 
    if not favorites[root][directory] then return false end
    return true 
end

function filebrowser:ClearFavorites()
    cache:Value4Key("SkyLab FileBrowser Favorites", "{}")
end

function filebrowser:ClearPreview()
    self.fileinfo.preview:ResetPreview()
    self.fileinfo.info:Reset()
end

function filebrowser:Init()
    self.colors = {}

    self.colors.background = Color(55,55,55)
    self.colors.pathbg     =  Color(85,85,85)
    self.colors.buttonsbg  = Color(85,85,85)
    self.colors.textcolor  = Color(0,255,255)

    self.files = {}

    self.root = ""

    local super = self

    -- Init this shit
    self.searchbar = {}
    self.dock = {}
    self.tree = {}
    self.list = {}
    self.fileinfo = {}
    self.leftdiv = {}
    self.rightdiv = {}
    self.pathbox = {}
    self.backbutton = {}
    self.scrollbar = {}
    self.treereload = {}

    self.rootIcons = {
        GAME = "icon16/controller.png",
        LUA  = "icon16/monitor_link.png",
        DATA = "icon16/folder_page.png",
        lcl  = "icon16/basket.png",
        LuaMenu = "icon16/application_home.png",
        DOWNLOAD = "icon16/drive_disk.png",
        MOD = "icon16/new.png",
        BASE_PATH = "icon16/sitemap_color.png",
        EXECUTABLE_PATH = "icon16/lightning.png",
        THIRDPARTY = "icon16/pill.png",
        WORKSHOP = "icon16/application_link.png"
    }

    local parent = self 

    local topBar = vgui.Create("DPanel", self)
    topBar:Dock(TOP)
    topBar:SetSize(0,26.5)

    local dock = vgui.Create("DSleekIconDock", topBar)
    dock:Dock(LEFT)
    dock:DockMargin(5,5,0,0) 
    dock:SetAutoResize(true)
    local function checkCache(r)
        if not r then return false end 
        local cached = cache:Value4Key("SkyLab_AD4"..r)
        if cached then 
            local dirs = string.Split(cached, "/")
            local root = ""
            if dirs[1][1] == ">" then root = string.sub(dirs[1], 2, #dirs[1]) end
            if root ~= r then return false end 
            parent:SetDirectory(cached, false, false, false)
            return true 
        end
        return false 
    end
    local function loadLastDir(newRoot)
        cache:Value4Key("SkyLab_AD4" .. parent.root, parent.directory)
        parent:SetDirectory(newRoot, false, true, false)
        checkCache(parent.tree.root)
        self:RootSwapped()
    end
    local function iButton(r, i)
        i = i or self.rootIcons[r]
        if not i then return nil end  
        local b = dock:AddIcon(i, function()
            if parent.tree.root == r then return end 
            loadLastDir(r)
        end, r)
        b:SetTooltip("Open '" .. r .. "'") 
        return b 
    end
    iButton("GAME")
    iButton("LUA")
    iButton("DATA")
    iButton("lcl")
    iButton("LuaMenu")
    iButton("DOWNLOAD")
    iButton("MOD")
    iButton("BASE_PATH")
    iButton("EXECUTABLE_PATH")
    iButton("THIRDPARTY")
    iButton("WORKSHOP")

    -- Searchbar
    local search = vgui.Create("DSleekTextBox", topBar)
    search:SetPlaceholderText("Search...")
    search:SetTooltip("Search in the selected Directory and Subdirectories")
    search:Dock(RIGHT)
    search:SetSize(425,0)
    search:DockMargin(0,5,5,0) 
    search.FocusChanged = function(self, status)
        if status == false and self.lastFocus ~= status then 
            --   parent:SetDirectory(self.text, false, false)
            parent:RequestFocus()
        end
        self.lastFocus = status
    end

    local tid = "search_filebrowser_textchanged_timer" .. skylab_filebrowser_search_timer_counter
    local blockSearch = false 
    do   
        local super = self 
        search.TextChanged = function(self) 
            if blockSearch == true then 
                blockSearch = false 
                return 
            end 

            if timer.Exists(tid) == true then timer.Remove(tid) end 
            timer.Create(tid, 1, 1, function()
                local text = search:GetText()

                if text == "" then 
                    super:ReloadList()
                    return 
                end

                if not super.directory or not super.root then return end 

                local dir = super.directory 

                if dir[1] == ">" then dir = string.sub(dir, 2, #dir) end 

                local ratings = super.tree:SearchFile(super.tree.root, super.tree:SelectedDirectory(), text, true, 25)

                if ratings then 
                    super:ClearPreview()
                    super.list:Clear()

                    for k, v in pairs(ratings[#text] or {}) do
                        if not v then continue end 

                        local s = string.Split(v.file, ".")
                        local directory = v.directory .. v.file 

                        super.list:QueueLine(s[1] or "-", "." .. (s[#s] or "-"), getFilesize(directory, super.tree.root), function(line)
                            line.directory = directory 
                            line.root = v.root
                            line.filename = s[1] or "-"
                            line.filetype = s[2] or "-"
                            line.OnRightClick = function(self)
                                local menu = DermaMenu()

                                menu:AddOption("Open", function()
                                    super.OnOpen((self.root or "DATA").."/"..(self.directory or ""))
                                end)

                                menu:AddOption("Copy Filepath", function()
                                    SetClipboardText(self.directory)
                                end)

                                menu:AddOption("Copy Root", function()
                                    SetClipboardText(self.root)
                                end)

                                menu:Open()
                            end	
                        end)
                    end
                end
            end)
        end
    end 

    topBar.Paint = function(self, w, h)
        addOutline(search, super.colors.buttonsbg)
        addOutline(dock, super.colors.buttonsbg)
    end

    -- Directory Textbox
    local pathbox = vgui.Create("DSleekTextBox", self)
    pathbox:Dock(TOP)
    pathbox:DockMargin(86,6,86,0) -- 86 6 6 0
    pathbox:SetSize(0,24)
    pathbox:SetFont("Consolas", 16)
    pathbox.lastFocus = false  
    pathbox:SetPlaceholderText("Enter a Directory")
    pathbox.FocusChanged = function(self, status)
        if status == false and self.lastFocus ~= status then 
            parent:SetDirectory(self.text, false, false, false)
            parent:RequestFocus()
        end
        self.lastFocus = status
    end
    pathbox.OnKeyCombo = function(self, a, b)
        if not a and not b then return end 
        if b == KEY_ENTER then 
            parent:SetDirectory(self.text, false, false, true)
            parent:ReloadList()
        elseif a == KEY_LCONTROL and b == KEY_V then 
            parent:SetDirectory(self.text, false, false, true)
            parent:ReloadList()
        end
    end

    local backbutton = vgui.Create("DSleekButton", self)
    backbutton:SetImage("icon16/door_out.png", 5)
    backbutton:SetFont("Consolas", 16) 
    backbutton:SetPos(6,6 + 26)
    backbutton:SetSize(36,24)
    backbutton.OnClick = function(self, d)
        if string.gsub(parent.directory, "%s", "") == "" then return end 

        -- Check Path
        parent:SetDirectory(parent.pathbox.text, false, false, true)

        -- Set Path
        local directories = string.Split(parent.directory, "/")
        parent.directory = table.concat(directories, "/", 1, math.max(#directories - 2, 1)) 
        parent:SetDirectory(parent.directory, false, false, true)

        -- Click parent folder
        local nodeDirectory = table.concat(directories, "/", 2, #directories - 2) .. "/"
        local node = parent.tree.loaded[(nodeDirectory == "/" and parent.tree.root or nodeDirectory)] 

        if node then 
            parent.tree:SetSelectedItem(node)
            parent.tree:ScrollToChild(node)
        end

        parent:ClearPreview()
    end

    local reload = vgui.Create("DSleekButton", self)
    reload:SetImage("icon16/arrow_refresh.png", 5)
    reload:SetFont("Consolas", 16)
    reload:SetPos(24 + 19,6 + 26)
    reload:SetSize(36,24)
    reload.OnClick = function(self, delay, code)
        parent.tree:Reload(true)
        parent:ReloadList()
        parent.favorites:Update()
        parent:ClearPreview()
    end

    local openbutton = vgui.Create("DSleekButton", self)
    openbutton:SetText("Open")
    openbutton:SetImage("icon16/folder_go.png", 3)
    openbutton:SetImageTextLayout(B_LAYOUT_LEFT)
    openbutton:SetFont("Consolas", 18) 
    openbutton:SetSize(73,24)
    openbutton.OnClick = function(self, delay, code)
        if code ~= MOUSE_LEFT then return end 
        local iLine, pnl = parent.list:GetSelectedLine()
        if not iLine or not pnl then
            if parent.tree:SelectedDirectory() == "" then return end 
            parent.OnOpen(parent.tree.root, parent.tree:SelectedDirectory())
            return 
        end 
        parent.OnOpen((pnl.root or "DATA") .. "/" .. (pnl.directory or ""))
    end
    self.openbutton = openbutton 

    local tree = vgui.Create("DSleekFileTree")
    tree.NodeSelected = function(self, node)
        if timer.Exists(tid) == true then timer.Remove(tid) end 
        parent.list:ClearQueue()
        blockSearch = true -- bruh 
        parent.searchbar:SetText("")
        -- When selected in a Node, add it to the path

        local final = ">" .. self.root .. "/"
        if node.directory ~= self.root then
            final = final.. node.directory 
        end
        parent:SetDirectory(final, false, true)
    end
    tree.NodeCreated = function(self, node)
        node.Label.DoDoubleClick = function() end -- 2x Click sucks
        node.OnOptionAdded = function(self, menu, option)
            if option ~= "Open" then return end
            local r, d = tree.root, node.directory  
            if not r or not d or string.gsub(d, "[%s/]*", "") == "" then return end 
            menu:AddOption("Open in Editor", function()
                local d = tree.root .. "/" .. node.directory 
                
                local dirs = string.Split(d, "/") or {}
                if dirs[#dirs]:find(".") then 
                    d = table.concat(dirs, "/", 1, #dirs - 1) 
                end 

                parent.OnOpen(d)
            end)
        end
        node.OnMenuConstructionFinished = function(self, menu) -- Add & Remove Favorites
            local r, d = tree.root, node.directory 
            if not r or not d then return end 
            if parent:HasFavorite(r, d) == false then 
                menu:AddOption("Add to Favorites", function() 
                    parent:AddFavorite(tree.root, node.directory) 
                    parent.favorites:Update()
                end)    	
            else 
                menu:AddOption("Remove from Favorites", function() 
                    parent:RemoveFavorite(tree.root, node.directory) 
                    parent.favorites:Update()
                end)    	
            end 
        end		
    end
    
    local favorites = vgui.Create("DSleekTree")
    favorites.owner = self 
    scrollbarOverride(favorites.VBar)
    local function createRoot()
        favorites.root = favorites:AddNode("Favorites", "icon16/star.png")
        favorites.root.Label:SetTextColor(favorites.colors.text)    
        favorites.root:SetExpanded(true)
    end
    createRoot()
    local function fixNode(node)
        node.Label.DoDoubleClick = function() 
            node:InternalDoClick() 
            node:DoDoubleClick()
        end
        node.DoDoubleClick = function() end 
    end
    function favorites:Update()
        local root = favorites.root 
        
        if not root then 
            createRoot() 
        elseif root:GetChildNodeCount() > 0 then 
            favorites.root:Remove()
            createRoot() 
            root = favorites.root
        end 
        
        local favs = parent:GetFavorites()
        if not favs then return end 

        local function addRoot(r)
            if not r or not parent.rootIcons[r] then return end 
            local node = root:AddNode(r, parent.rootIcons[r])
            node.Label:SetTextColor(favorites.colors.text)   
            node:SetExpanded(true) 
            return node 
        end

        local added = {}

        for r, dirs in pairs(favs) do 
            if not r or not dirs then continue end

            if not added[r] then added[r] = addRoot(r) end
            local superNode = added[r] 
            if not superNode then continue end 

            for dir, _ in pairs(dirs) do 
                if not dir then continue end 

                local node = superNode:AddNode(dir, "icon16/folder.png")
                node.Label:SetTextColor(favorites.colors.text)  
                node.root = r 
                node.directory = dir 
                node:SetExpanded(true) 
                fixNode(node)
                local function o()
                    parent:SetDirectory(">" .. r .. "/" .. dir, false, false, r == parent.tree.root)
                    parent.tree.selectedNode:SetExpanded(true)
                    parent.tree:ScrollToChild(node)
                end
                node.DoDoubleClick = o 
                node.DoRightClick = function(self)
                    local menu = DermaMenu()

                    menu:AddOption("Open", o)

                    menu:AddOption("Remove from Favorites", function() 
                        parent:RemoveFavorite(node.root, node.directory) 
                        parent.favorites:Update()
                    end)   

                    menu:AddOption("Copy to Clipboard", function()
                        SetClipboardText(node.directory)
                    end)

                    menu:Open()
                end

                local d = string.Split(node.directory or "", "/") 
                node:SetTooltip("..." .. d[math.max(#d - 1, 1)] .. "/")
            end

            if superNode:GetChildNodeCount() == 0 then 
                superNode:Remove()
                continue
            end
        end
    end
    favorites:Update()

    local leftpanel = vgui.Create("DPanel")
    leftpanel.Paint = function(self,w,h) draw.RoundedBox(0,0,0,w,h,Color(255,0,0)) end

    local hDivider = vgui.Create("DVerticalDivider", leftpanel)
    hDivider:Dock(FILL)
    hDivider:SetTop(tree)
    hDivider:SetBottom(favorites)
    hDivider.Paint = function(self, w, h) draw.RoundedBox(0,0,0,w,h,dark(150)) end
    hDivider:SetTopHeight(tonumber(cache:Value4Key("SkyLab - Filebrowser - LeftVerticalDivider - Pos") or "450") or 450) 
    hDivider.OnMouseReleased = function(self, code)
        if code == MOUSE_LEFT then 
            cache:Value4Key("SkyLab - Filebrowser - LeftVerticalDivider - Pos", self.m_iTopHeight)
            self:SetCursor( "none" )
            self:SetDragging( false )
            self:MouseCapture( false )
            self:SetCookie( "TopHeight", self.m_iTopHeight )
        end
    end

    local centerpanel = vgui.Create("DPanel")

    local list = vgui.Create("DSleekListView", centerpanel)
    list:SetMultiSelect(false)
    list:Dock(FILL)
    do 
        local n = list:AddColumn("Name")
        local t = list:AddColumn("Type")
        local s = list:AddColumn("Size")

        n:SetMinWidth(100) 
        t:SetMinWidth(30)
        s:SetMinWidth(30)

        n:SetWidth(tonumber(cache:Value4Key("SkyLab - Filebrowser - ListLCol") or "140") or 140)  
        t:SetWidth(tonumber(cache:Value4Key("SkyLab - Filebrowser - ListCCol") or "40") or 40)
        s:SetWidth(tonumber(cache:Value4Key("SkyLab - Filebrowser - ListRCol") or "40") or 40)

        list.n, list.t, list.s = n, t, s
    end 
    do 
        local lastDir = ""
        list.OnRowSelected = function( self, index, pnl )
            if not pnl.root or not pnl.directory then return end 
            if lastDir ~= pnl.root..pnl.directory then 
                parent.fileinfo:SetFile(pnl.root, pnl.directory)
                lastDir = pnl.root..pnl.directory
            end
        end
        list.DoDoubleClick = function(self, id, pnl)
            parent.OnOpen((pnl.root or "DATA").."/"..(pnl.directory or ""))
        end
    end 

    local fileinfo = vgui.Create("DSleekFileViewer")
    fileinfo.OnPreviewLoaded = function(self) parent.fileinfo:UpdateLayout() end

    local rightdivplane = vgui.Create("DPanel") -- We put the right divider into a panel that is to the right of the left divider
    local rightdivider = vgui.Create("DHorizontalDivider", rightdivplane)
    rightdivider:SetLeft(centerpanel)
    rightdivider:SetRight(fileinfo)
    rightdivider:Dock(FILL)
    rightdivider:SetLeftMin(240)
    rightdivider:SetRightMin(240)
    rightdivider:SetLeftWidth(tonumber(cache:Value4Key("SkyLab - Filebrowser - RightDivider - Pos") or "240") or 240)
    rightdivider.Paint = function(self, w, h) draw.RoundedBox(0,0,0,w,h,dark(150)) end
    rightdivider.OnMouseReleased = function(self, code)
        if code == MOUSE_LEFT then 
            cache:Value4Key("SkyLab - Filebrowser - RightDivider - Pos", self:GetLeftWidth())
            self:SetCursor( "none" )
            self:SetDragging( false )
            self:MouseCapture( false )
            self:SetCookie( "LeftWidth", self:GetLeftWidth() )
        end
    end

    local leftdivider = vgui.Create("DHorizontalDivider", self)
    leftdivider:SetLeft(leftpanel)
    leftdivider:SetRight(rightdivplane)
    leftdivider:SetLeftMin(160) -- 480 / 3
    leftdivider:SetRightMin(480)
    leftdivider:Dock(FILL)
    leftdivider:DockMargin(0,10,0,0)
    leftdivider:SetLeftWidth(tonumber(cache:Value4Key("SkyLab - Filebrowser - LeftDivier - Pos") or "240") or 240)
    leftdivider.Paint = function(self, w, h) draw.RoundedBox(0,0,0,w,h,dark(150)) end
    leftdivider.OnMouseReleased = function(self, code)
        if code == MOUSE_LEFT then 
            cache:Value4Key("SkyLab - Filebrowser - LeftDivier - Pos", self:GetLeftWidth())
            self:SetCursor( "none" )
            self:SetDragging( false )
            self:MouseCapture( false )
            self:SetCookie( "LeftWidth", self:GetLeftWidth() )
        end
    end

    self.searchbar = search 
    self.treereload = treereload
    self.tree = tree 
    self.list = list 
    self.fileinfo = fileinfo 
    self.leftdiv = leftdivider
    self.rightdiv = rightdivider
    self.pathbox = pathbox 
    self.backbutton = backbutton   
    self.scrollbar = scrollbar
    self.dock = dock 
    self.reload = reload 
    self.favorites = favorites

    self.lastDirectory = "directory placeholder, please ignore."
end

function filebrowser:ReloadList(shouldQueue)
    if shouldQueue == nil then shouldQueue = true end 
    self:ClearPreview()
    self.list:Clear()

    local super = self 

    local selectedDir = self.tree:SelectedDirectory() or ""

    if selectedDir == "" then return end 

    local files = ((self.tree.fileCache[selectedDir] or {})[1] or {})

    if #files == 0 then 
        self.tree:LoadFiles(self.tree.root, selectedDir) 
        files = ((self.tree.fileCache[selectedDir] or {})[1] or {})
        if #files == 0 then 
            return 
        end 
    end 

    for k, v in pairs(files) do
        if not v or string.gsub(v, "%s", "") == "" then continue end 
        local s = string.Split(v, ".")
        local directory = selectedDir .. v

        local function exec(line)
            if not line then return end 
            line.directory = directory 
            line.root = self.tree.root or "DATA"
            line.filename = s[1] or "-"
            line.filetype = s[2] or "-"
            line.OnRightClick = function(self)
                local menu = DermaMenu()
                menu:AddOption("Open", function()
                    super.OnOpen((self.root or "DATA").."/"..(self.directory or ""))
                end)
                menu:AddOption("Copy Filepath", function()
                    SetClipboardText(self.directory)
                end)
                menu:AddOption("Copy Root", function()
                    SetClipboardText(self.root)
                end)			
                menu:Open()
            end	
        end 

        if shouldQueue == false then 
            exec(self.list:AddLine(s[1] or "-", "." .. (s[#s] or "-"), getFilesize(directory, self.tree.root)))
            continue 
        end

        self.list:QueueLine(s[1] or "-", "." .. (s[#s] or "-"), getFilesize(directory, self.tree.root), exec)
    end
end

function filebrowser:OnOpen(directory) end 

function filebrowser:OnMousePressed(code)
    self:RequestFocus()
end

function filebrowser:PerformLayout(w, h)
    local x, y = self.pathbox:GetPos()
    local pw, ph = self.pathbox:GetSize()

    self.openbutton:SetPos(x + pw + 7.5,y)

    do 
        local r = self.reload 
        self.reload:SetPos(x - r:GetWide() - 7.5,y)
    end 

    do 
        local r = self.backbutton 
        self.backbutton:SetPos(x - self.reload:GetWide() - r:GetWide() - 9,y)
    end 

    do 
        local dx,dy = self.dock:GetLastIconPos()
        local dw, dh = self.dock:GetSize()
        self.searchbar:SetPos(dw + dx + 7.5,dy)
    --    self.searchbar:SetSize(self.dock:GetWide() + 7.5, self.dock:GetTall())
    end
end

function filebrowser:Paint(w, h)
    -- Background
    draw.RoundedBox(0, 0, 0, w, h, self.colors.background)

    -- Path 
    addOutline(self.pathbox, self.colors.buttonsbg)

    -- Buttons Background
    addOutline(self.reload, self.colors.buttonsbg)
    addOutline(self.backbutton, self.colors.buttonsbg)

    addOutline(self.openbutton, self.colors.buttonsbg)
    addOutline(self.dock, self.colors.buttonsbg)

    addOutline(self.searchbar, self.colors.buttonsbg)
end

function filebrowser:SetDirectory(directory, openOnFileDir, shouldQueue, animate)
    if directory == nil then return end 

    if openOnFileDir == nil then openOnFileDir = false end 

    if directory[1] == ">" then 
        directory = string.sub(directory, 2, #directory)
    end

    local root, subs, fname = getPathArgs(directory)

    root  = root or ""
    subs  = subs or ""
    fname = "" --fname or ""

    if self.lastDirectory == root..subs..fname and string.gsub(subs, "/", "") ~= "" then return end 
    self.lastDirectory = root..subs..fname 

    self:ClearPreview()

    do 
        local newRoot  = validateRoot(root) or ""

        if newRoot ~= root then 
            subs = ""
            fname = ""
        end

        root = newRoot 
    end

    directory = root 

    if string.gsub(subs, "%s", "") == "" then 
        directory = directory .. "/"
    else 
        directory = directory .. "/" .. subs 
    end

    if subs[#subs] ~= "/" and directory[#directory] ~= "/" then 
        directory = directory .. "/"
    end

    if string.gsub(fname, "%s", "") ~= "" then 
        if #string.Split(fname, ".") > 1 then 
            directory = directory .. fname 
            if openOnFileDir == true then 
                self:OnOpen(directory)
                self.root = root 
                self.directory = ">" .. directory
                self.pathbox:SetText(self.directory)
                return root, subs, fname 
            end       
        else 
            --   directory = directory .. fname .. "/"
        end
    elseif directory[#directory] ~= "/" then 
        directory = directory .. "/"
    end 

    -- Init Root
    if not self.lastRoot or (self.lastRoot and self.lastRoot ~= root) then 
        self.tree:SetRoot(root)
        self.lastRoot = root 
    end

    if shouldQueue == nil then shouldQueue = true end 
    self.tree:OpenDirectory(root, subs .. "/", nil, shouldQueue, animate)

    self:ReloadList()

    self.dock:SetSelected(root)
   
    self.root = root 
    self.directory = ">" .. directory
    self.pathbox:SetText(self.directory)

    if root then 
        local s = string.Split(subs or "", "/")
        self.searchbar:SetPlaceholderText("Search in " .. (s[#s] or root) .. "/...")
    end 

    return root, subs, fname 
end

function filebrowser:GetDirectory()
    self:SetDirectory(self.directory)
    return string.sub(self.directory, 2, #self.directory)
end

vgui.Register("DSleekFileBrowser", filebrowser, "DPanel")

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

local DEBUG = true  

function SSLE:OpenBrowser(directory, onOpen, onClose, parent)
    if not onOpen and not onClose and not directory and not parent then return end 

    if type(directory) == "function" then 
        parent    = onClose 
        onClose   = onOpen 
        onOpen    = directory 
        directory = SSLE.modules.cache:Value4Key("SSLE-LastDir-Local") 
    end

    local function kill()
        if DEBUG == true then 
            self.browserPopup:Remove() 
        end
    end

    directory = directory or ""
    onOpen    = onOpen  or function() end 
    onClose   = onClose or kill

    if not self.browserPopup 
    or not self.browserWindow 
    or IsValid(self.browserPopup) == false 
    or IsValid(self.browserWindow) == false then 
        self.browserPopup   = vgui.Create("DSleekWindow")
        self.browserWindow  = vgui.Create("DSleekFileBrowser", self.browserPopup)
        self.browserPopup.Close = function(self)
            self:SetVisible(false)
            kill()
        end
    end

    local popup   = self.browserPopup 
    local browser = self.browserWindow 

    popup:SetIcon("icon16/folder_heart.png")

    popup:SetVisible(true)

    local root, subs, fname = browser:SetDirectory(directory, false, false, false)

    -- Save position & size in SQLite DB
    local function save()
        SSLE.modules.cache:Value4Key("SkyLab - Filebrowser - ListLCol", browser.list.n:GetWide() or 140)
        SSLE.modules.cache:Value4Key("SkyLab - Filebrowser - ListCCol", browser.list.t:GetWide() or 40)
        SSLE.modules.cache:Value4Key("SkyLab - Filebrowser - ListRCol", browser.list.s:GetWide() or 40)

        local x, y = popup:GetPos()
        SSLE.modules.cache:Value4Key("SkyLab - Filebrowser - X", x)
        SSLE.modules.cache:Value4Key("SkyLab - Filebrowser - Y", y)
    end

    -- Scroll to the last directory 
    if subs then 
        local node = browser.tree:NodeForDirectory(subs .. "/")
        if node then 
            browser.tree:ScrollToChild(node)
        end 
    end

    browser.OnOpen = function(root, dir) 
        root, dir = checkFilepath(root, dir)
        save()
        onOpen(root, dir)
        popup:SetVisible(false)
        popup.OnClose = function() -- override it again, we dont want to trigger the onClose callback 
            save()
            kill()
            return true 
        end     
        popup:Close()
    end 

    browser:Dock(FILL)

    -- Save current size to sqlite db 
    popup.OnSizeChanged = function(self, w, h)
        SSLE.modules.cache:Value4Key("SkyLab - Filebrowser Last Width", w)
        SSLE.modules.cache:Value4Key("SkyLab - Filebrowser Last Height", h)
    end

    local lastWidth  = math.max(tonumber(SSLE.modules.cache:Value4Key("SkyLab - Filebrowser Last Width") or "760") or 760, 760)
    local lastHeight = math.max(tonumber(SSLE.modules.cache:Value4Key("SkyLab - Filebrowser Last Height") or "480") or 480, 480)

	popup:SetSize( lastWidth, lastHeight )
	popup:SetTitle( "SkyLab Filebrowser" )
	popup:SetDraggable( true ) 
	popup:MakePopup()
	popup:SetSizable(true)
	popup:SetMinWidth(760)
    popup:SetMinHeight(480)
    
    -- You aint moving out my screen!
    popup:SetEnableBoundariesClamp(true)

    if parent == nil or parent == false then 
        local px = tonumber(SSLE.modules.cache:Value4Key("SkyLab - Filebrowser - X") or "-1") or -1 
        local py = tonumber(SSLE.modules.cache:Value4Key("SkyLab - Filebrowser - Y") or "-1") or -1 
        if (px == -1 or py == -1) then 
            popup:Center()
        else 
            if parent == false or parent == nil then 
                popup:SetPos(px, py)
            else     
                popup:Center()
            end
        end
    else
        local pw, ph = popup:GetSize()
        local x,y    = parent:GetPos()
        local w, h   = parent:GetSize()
        popup:SetPos(x + w / 2 - pw / 2, y + h / 2 - ph / 2)
    end

    popup.OnClose = function()
        save()
        SSLE.modules.cache:Value4Key("SSLE-LastDir-Local", browser.directory or "") 
        local root, dir = checkFilepath(browser.directory or "")
        onClose(root, dir)
        kill()
        return true 
    end

    return popup, browser 
end
