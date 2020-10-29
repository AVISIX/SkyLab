if not SSLE then 
	MsgC(Color(255,0,0), "Couldn't mount Custom List Column.") 
	return 
end

local function dark(i)
    return Color(i,i,i)
end

do 
    local self = {}

    function self:Init()
        self.Header = vgui.Create( "DSleekButton", self )
        self.Header.OnClick = function(s, delay, code)
            if code == MOUSE_RIGHT or code == MOUSE_LEFT then 
                self:DoClick() 
            end
        end
        self.Header.colors.background = dark(60)
     --   self.Header.DoRightClick = function() self:DoRightClick() end

        self.DraggerBar = vgui.Create( "DListView_DraggerBar", self )

        self:SetMinWidth( 10 )
        self:SetMaxWidth( 19200 )
    end


    vgui.Register("DSleekListColumn", self, "DListView_Column")
end 


do 
    local PANEL = {} 

    function PANEL:DoClick()
    end

    vgui.Register("DSleekListColumn_Plain", PANEL, "DSleekListColumn")
end 
