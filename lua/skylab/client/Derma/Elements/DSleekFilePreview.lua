if not SSLE then 
	return 
end

local function dark(i)
    return Color(i,i,i)
end

local images = {
    png = 1,
    jpg = 1,
    vtf = 1,
    vmt = 1
}

local texts = {
    txt = 1,
    lua = 1,
    dat = 1,
    json = 1
}

do 
    local self = {}

    function self:Init()
        self.colors = {}
        self.colors.background = dark(50)
        self.colors.outline = dark(120)

        self.filepath = ""
        self.preview = {}    
        self.file = ""
        self:SetPreview("", "")
    end 

    function self:Paint(w, h)
        draw.RoundedBox(0,0,0,w,h,self.colors.outline)
        draw.RoundedBox(0,1,1,w-2,h-2,self.colors.background)
    end

    -- Text, Image, Binary, Default 
    function self:SetPreview(root, filepath, callback, maxsize, type)
        maxsize = maxsize or 480
        callback = callback or function() end 
        if not root then type = "default" end 
        if not filepath or string.gsub(filepath, "%s", "") == "" then type = "default" end 
        if type ~= "text" and type ~= "image" then type = "default" end

        local extension = string.GetExtensionFromFilename(filepath)
        
        if filepath ~= self.filepath and self.preview ~= nil and self.preview.Remove then 
            self.preview:Remove()
        end

        if SSLE.textextensions[extension] or SSLE.codeextensions[extension] then 
            if file.Size(filepath, root) / 1024 > 50 then 
                type = "default" -- Its not worth the processing power to display such large files 
            else 
                type = "text"
            end 
        elseif SSLE.imageextensions[extension] then 
            type = "image"
        else 
            type = "default"
        end

        self.type = type 

        if type == "text" then 
            self.preview = vgui.Create("DSyntaxBox", self)         

            self.preview:Dock(FILL)

            --self.preview:SetFont("Consolas", tonumber(SSLE.modules.cache:Value4Key("SkyLab - FileBrowser - TextPreview - Fontsize") or "") or 8)

            self.preview:SetFont("Consolas", 10)

            do -- Set correct syntax Profile 
                local profileFound = false 
                for id, _ in pairs(SSLE.profiles) do 
                    local profile = SSLE.GetProfile(id)

                    -- For custom langs such as e2 or sf
                    if profile.commonDirectories then 
                        for _, directory in pairs(profile.commonDirectories) do 
                            if directory.root == root and string.GetPathFromFilename(filepath):find(directory.directory) then 
                                profileFound = true 
                                self.preview:SetProfile(profile)
                                break
                            end
                        end
                    end

                    if profile.filetype == extension and profile.commonDirectories == nil then 
                        self.preview:SetProfile(profile)
                        profileFound = true 
                        break 
                    end            
                end

                if profileFound == false then 
                    self.preview:SetProfile(SSLE.GetProfile("Default"))
                end
            end 

            -- Read file 
            local contents = file.Read(filepath, root) or ""

            --[[ 
            do -- Anti Lag
                local vL = math.ceil(maxsize / self.preview.font.h)
                local lines = string.Split(contents, "\n")
                if #lines > vL then 
                    contents = table.concat(lines, "\n", 1, vL)
                end
            end]] 

            self.preview:SetText(contents)

            -- Override functions 
            self.preview.PaintCaret = function() end 
            self.preview.OnMousePressed = function() end 
       --     self.preview.OnMouseWheeled = function() end 

            self.preview.SetCaret = function() end 
            self.preview.CheckAreaSelection = function() end 

            self.preview.StartSelection = function() end 
            self.preview.EndSelection = function() end 
            
            self.preview._TextChanged = function() end 
            self.preview._KeyCodePressed = function() end 

            self.preview.scrollBar.Paint = function() end 
            self.preview.scrollBar.btnUp.Paint = function() end 
            self.preview.scrollBar.btnDown.Paint = function() end 
            self.preview.scrollBar.btnGrip.Paint = function() end 
            self.preview.scrollBar:SetSize(0,0)

            self.preview:ParseVisibleLines()

            -- We dont need to re-parse everything all the time since the code isnt being changed 
            self.preview.ParseVisibleLines = function(self)
                self:ParseChangedVisibleLines()
            end

            self.preview.OnKeyCodePressed = function() end 

    --        self.preview.FontChanged = function(self, font, size)
    --            SSLE.modules.cache:Value4Key("SkyLab - FileBrowser - TextPreview - Fontsize", size)
    --        end

        elseif type == "image" then 
            local parent = self 
            self.preview = vgui.Create("DImage", self)
            self.preview.SetImage = function(self, dir)
                if not dir then return end
                self.ImageName = dir
                local Mat = Material( dir )
                self.material = Mat 
                self:SetMaterial( Mat )
                self:FixVertexLitMaterial()
                callback()
            end
            self.preview:SetImage(root.."/"..filepath)
            self.preview:Dock(FILL)

        else 

            self.preview = vgui.Create("DLabel", self)
            self.preview:SetText("No Preview")
        end

        callback()

      --  self.lastType = type 

        self.file = filepath 
    end

    function self:PerformLayout(w, h)
        if self.type == "default" then 
            local pw, ph = self.preview:GetSize()
            self.preview:SetPos(w / 2 - pw / 2, h / 2 - ph / 2)
        end
    end

    function self:ResetPreview()
        if self.preview then self.preview:Remove() end 
        self:SetPreview("","")
    end

    vgui.Register("DSleekFilePreview", self, "DPanel")
end
