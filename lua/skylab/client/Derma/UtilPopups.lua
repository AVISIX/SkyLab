if not SSLE then 
	return 
end

function SSLE:TextConfirm(placeholder, okCallback, cancelCallback, parent)
    if not placeholder or not okCallback then return end 
    
    if type(cancelCallback) ~= "function" then 
        parent         = cancelCallback 
        cancelCallback = function() end 
    end

    local window = vgui.Create("DSleekWindow")
    window:SetIcon("icon16/textfield_add.png")
    window:SetTitle(placeholder)
    window:SetDraggable(true) 
    window:SetSizable(false)
    window:SetWidth(300)
    window:SetHeight(100)
    window:SetPaintShadow(true)
    window:MakePopup()

    if not parent then 
        window:SetPos(ScrW() / 2 - window:GetWide() / 2, ScrH() / 2 - window:GetTall() / 2)
    else 
        local x, y = parent:GetPos()
        local w, h = parent:GetSize()
        window:SetPos(x + w / 2 - window:GetWide() / 2, y + h / 2 - window:GetTall() / 2) 
    end

    window.BeforeClose = cancelCallback 

    local textbox = vgui.Create("DSleekTextBox", window)
    textbox:Dock(TOP)
    textbox:SetSize(0,35)
    textbox:SetPlaceholderText(placeholder .. "...")
    textbox:SetFont("Consolas", 16)

    local confirm = vgui.Create("DSleekButton", window)
    confirm:Dock(FILL)
    confirm:SetText("Confirm")
    confirm:SetFont("Consolas", 16)
    confirm:SetImage("icon16/spellcheck.png", 15)
    confirm:SetImageTextLayout(B_LAYOUT_LEFT)
    confirm.OnClick = function(self)
        if textbox.text == "" then return end 
        okCallback(textbox.text)
        window:Remove()
    end

    textbox.OnKeyCombo = function(self, a, b)
        if b == KEY_ENTER then 
            confirm:OnClick()
        end
    end

    textbox:RequestFocus()
end

function SSLE:Confirm(placeholder, okCallback, cancelCallback, parent)
    if not placeholder or not okCallback then return end 
    
    if type(cancelCallback) ~= "function" then 
        parent         = cancelCallback 
        cancelCallback = function() end 
    end

    local window = vgui.Create("DSleekWindow")
    window:SetIcon("icon16/textfield_add.png")
    window:SetTitle(placeholder)
    window:SetDraggable(true) 
    window:SetSizable(false)
    window:SetWidth(250)
    window:SetHeight(90)
    window:SetPaintShadow(true)
    window:MakePopup()

    if not parent then 
        window:SetPos(ScrW() / 2 - window:GetWide() / 2, ScrH() / 2 - window:GetTall() / 2)
    else 
        local x, y = parent:GetPos()
        local w, h = parent:GetSize()
        window:SetPos(x + w / 2 - window:GetWide() / 2, y + h / 2 - window:GetTall() / 2) 
    end

    window.BeforeClose = cancelCallback 

    local label = vgui.Create("DButton", window)
    label:Dock(TOP)
    label:SetDisabled(true)
    label:SetHeight(30)
    label:SetText(placeholder)
    label.Paint = function() end 
    label:SetTextColor(Color(255,255,255))
    label:SetCursor("none")

    local cancel = vgui.Create("DSleekButton", window)
    cancel:Dock(RIGHT)
    cancel:SetText("Cancel")
    cancel:SetFont("Consolas", 16)
    cancel:SetImage("icon16/cross.png", 10)
    cancel:SetImageTextLayout(B_LAYOUT_LEFT)
    cancel.OnClick = function(self)
        cancelCallback()
        window:Remove()
    end
    cancel:SizeToContents()

    local ok = vgui.Create("DSleekButton", window)
    ok:Dock(LEFT)
    ok:SetText("Okay")
    ok:SetFont("Consolas", 16)
    ok:SetImage("icon16/tick.png", 10)
    ok:SetImageTextLayout(B_LAYOUT_LEFT)
    ok.OnClick = function(self)
        okCallback()
        window:Remove()
    end

    local w, h = cancel:GetSize()
    ok:SetSize(w,h)
end