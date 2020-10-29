if not SSLE then 
	return 
end

local function dark(i)
    return Color(i,i,i)
end


do 
    local self = {}

    function self:Init()
        self.colors = {}
        self.colors.background = dark(50)
        self.colors.outline = dark(120)

        scrollbarOverride(self.VBar)

        -- File Preview 
        self.preview = vgui.Create("DSleekFilePreview", self)
        self.preview:SetSize(210,210)
        self.preview.colors.background = self.colors.background

        -- File Info 
        self.info = vgui.Create("DSleekFileInfo", self)
        self.info.colors.background = self.colors.background

        local parent = self 

        self.VBar.OnMouseWheeled = function(self, delta)
            if ( !self:IsVisible() ) then return false end

            -- Check if the preview of the preview is hovered (yes naming sucks sorry)
            if parent.preview.type == "text" 
            and parent.preview.preview:IsHovered() == true 
            and parent.preview.preview:CanScroll() == true then return false end 

            return self:AddScroll( delta * -2 )
        end

        -- Panel Layout 
        self.pnlCanvas.PerformLayout = function(self, w, h) 
            if not parent.preview then return end 

            local scrollW = parent.VBar:GetWide()

            do -- Position File Preview 
                local newW = math.Clamp(w - 10,10,400)

                parent.preview:SetPos(w / 2 - parent.preview:GetWide() / 2 - 1, 1)

                local function default()
                    parent.preview:SetSize(newW,newW)
                end

                if parent.preview.type == "image" then 
                    if not parent.preview.preview.material then 
                        default()
                        return 
                    end

                    local Texture = parent.preview.preview.material 

                    if not Texture then 
                        default()
                        return
                    end 

                    local iw = Texture:Width()
                    local ih = Texture:Height()

                    parent.preview:SetSize(newW,ih * (newW / iw))
                else 
                    default()
                end
            end
            
            do -- Position File Info 
                local previewX, previewY = parent.preview:GetPos() 
                local previewHeight      = parent.preview:GetTall()
                local previewWidth       = parent.preview:GetWide() 

                parent.info:SetPos(previewX, previewY + previewHeight + 10)
                parent.info:SetSize(previewWidth, 200)
            end
        end

        self.root = ""
        self.file = ""
    end

    function self:UpdateLayout(w, h)
        if not self.preview then return end 
        local w2, h2 = self:GetSize()
        w = w or w2 
        h = h or h2 
        self.pnlCanvas.PerformLayout(w, h)
        self:PerformLayout()
    end

    function self:DrawPreviewOutline()
        local px, py = self.pnlCanvas:GetPos()

        do 
            local x, y = self.preview:GetPos()
            y = y + py 
            local w, h = self.preview:GetSize() 
            draw.RoundedBox(0,x - 1, y - 1,w + 2,h + 2,self.colors.outline)
        end 

        do 
            local x, y = self.info:GetPos()
            y = y + py         
            local w, h = self.info:GetSize() 
            draw.RoundedBox(0,x - 1, y - 1,w + 2,h + 2,self.colors.outline)
        end 
    end

    function self:Paint(w,h)
        draw.RoundedBox(0,0,0,w,h,self.colors.background)

        self:DrawPreviewOutline()
    end

    function self:SetFile(root, directory)
        if not directory then return end 

        self.root = root 
        self.file = directory 

        self.info:SetFile(root, directory)
        self.preview:SetPreview(root, directory, self.OnPreviewLoaded)
    end

    function self:OnPreviewLoaded() end

    function self:GetFile()
        return self.file 
    end

    vgui.Register("DSleekFileViewer", self, "DScrollPanel")
end 