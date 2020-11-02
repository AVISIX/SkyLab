if not SSLE then return end 

local tooltip = {}

function tooltip:Paint(w, h)
    draw.RoundedBox(0,0,0,w,h,Color(80,80,80))
    draw.RoundedBox(0,1,1,w - 2,h - 2,Color(35,35,35))

    self:PositionTooltip()
end

vgui.Register("DSleekTooltip", tooltip, "DTooltip")

function SSLE:Tooltip(element, text)
    if not element or not text then return end 

    local label = vgui.Create("BetterLabel")
    label:SetFont("Consolas", 14)
    label:SetText(text)
    label:SetOrientation(TEXT_ALIGN_CENTER)
        
    element:SetTooltipPanelOverride("DSleekTooltip")
    element:SetTooltipPanel(label)

    return label 
end 

function SSLE:LargeTooltip(element, title, text)
    
end
