local self = {}

local function dark(n)
    return Color(n,n,n)
end

function self:Init()
    self.colors = {}
    self.colors.background = dark(45)
    self.colors.buttonsbg  = Color(85,85,85)

    self.iconOffset = 7.5

    self.autoSize = false 

    self.selected = nil 

    self.lastIconPos = {x=0,y=0}
    self.iconsWidth = 0

    self.icons = {}
end

dsleekicondockidcounter = 0
function self:AddIcon(icon, callback, id)
    if not icon or not callback then return end 

    local temp = vgui.Create("DImageButton", self)
    temp:SetImage(icon)

    local super = self 
    temp.OnMousePressed = function(self, code) 
        super.selected = temp 
        callback(code)
    end 
    
    if not id then 
        temp.id = dsleekicondockidcounter
        dsleekicondockidcounter = dsleekicondockidcounter + 1
    else 
        temp.id = id 
    end

    local tall = self:GetTall()

    temp:SetSize(tall - 4, tall - 4)
    table.insert(self.icons, temp)

    return temp 
end

function self:SetAutoResize(status)
    self.autoSize = status
end

function self:SetIconSize(element, size)
    local tall = self:GetTall()
    element:SetSize(size, size)
end

function self:GetIconsWidth()
    return self.iconsWidth
end

function self:GetLastIconPos()
    return self.lastIconPos.x, self.lastIconPos.y
end

function self:PerformLayout(w, h)
    self.iconsWidth = 0
    local x = self.iconOffset
    local last 
    for _, icon in pairs(self.icons) do 
        icon:SetPos(x, (self:GetTall() - icon:GetTall()) / 2)

        local add = icon:GetWide() + self.iconOffset

        x = x + add

        self.iconsWidth = self.iconsWidth + add

        last = icon 
    end

    if last then 
        self.lastIconPos = {x=x,y=(self:GetTall() - last:GetTall()) / 2}
    end

    if self.autoSize == false then return end 

    self:SetSize(x, h)
end

function self:SetSelected(icon)
    if type(icon) == "string" then 
        for k, v in pairs(self.icons) do 
            if v.id == icon then 
                self.selected = v 
                break 
            end 
        end
        return 
    end
    self.selected = icon 
end

function self:Paint(w, h)
    draw.RoundedBox(0,0,0,w,h,self.colors.background)

    if not self.selected then return end 

    local function addOutline(element, col)
        local x, y = element:GetPos()
        local ow, oh = element:GetSize()
        draw.RoundedBox(5, x - 1, y - 1, ow + 2, oh + 2, col)
    end

    addOutline(self.selected, self.colors.buttonsbg)
end

vgui.Register("DSleekIconDock", self, "DPanel")