if not SSLE then 
	MsgC(Color(255,0,0), "Couldn't mount Custom List Line.") 
	return 
end

local function dark(i)
    return Color(i,i,i)
end


local self = {}

function self:Init()
    self.colors = {}
    self.colors.text = dark(220)
    self.colors.hovered = Color(240,110,0,25)
    self.colors.selected = Color(240,110,0,50)
end

function self:SetColumnText( i, strText )

	if ( type( strText ) == "Panel" ) then

		if ( IsValid( self.Columns[ i ] ) ) then self.Columns[ i ]:Remove() end

		strText:SetParent( self )
		self.Columns[ i ] = strText
		self.Columns[ i ].Value = strText
		return

	end

	if ( !IsValid( self.Columns[ i ] ) ) then

        self.Columns[ i ] = vgui.Create( "DListViewLabel", self )
        self.Columns[i]:SetTextColor(self.colors.text)
		self.Columns[ i ]:SetMouseInputEnabled( false )

	end

	self.Columns[ i ]:SetText( tostring( strText ) )
	self.Columns[ i ].Value = strText
	return self.Columns[ i ]

end

function self:Paint(w, h)
    if self:IsHovered() and self.m_bSelected == false then 
        draw.RoundedBox(0,0,0,w,h, self.colors.hovered)
    elseif self.m_bSelected == true then 
        draw.RoundedBox(0,0,0,w,h, self.colors.selected)
    end
end

vgui.Register("DSleekListLine", self, "DListView_Line")