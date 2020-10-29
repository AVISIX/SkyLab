if not SSLE then 
	MsgC(Color(255,0,0), "Couldn't mount Custom ListView.") 
	return 
end

local function dark(i)
    return Color(i,i,i)
end

local self = {}

dsleeklistview_line_queue_index = 0

function self:Init()

	self.colors = {}
	self.colors.background = dark(50)

	scrollbarOverride(self.VBar)

	self.queue = {}

	local counter = 1
	local timing = 0
	hook.Add("Think", "DSleekListView_Line_Queue_" .. dsleeklistview_line_queue_index, function()
		if not self.queue then return end 
		if #self.queue == 0 then return end 
		if RealTime() <= timing then return end 

		if counter > #self.queue then counter = 1 end 

		local entry = self.queue[counter]
		if entry and entry.callback and entry.args then
			self:OnLineAdded(entry.args)
			entry.callback(self:AddLine(entry.args) )
		end
		table.remove(self.queue, counter)

		counter = counter + 1
		if counter > #self.queue then counter = 1 end

		timing = RealTime() + 0.005
	end)
	dsleeklistview_line_queue_index = dsleeklistview_line_queue_index + 1
end

function self:OnLineAdded() end 

function self:Paint(w, h)
	draw.RoundedBox(0,0,0,w,h,self.colors.background)
end

function self:ClearQueue()
	self.queue = {}
end

-- From Garry Code 
function self:AddLine( ... )

	self:SetDirty( true )
	self:InvalidateLayout()

	local Line = vgui.Create( "DSleekListLine", self.pnlCanvas )
	local ID = table.insert( self.Lines, Line )

	Line:SetListView( self )
	Line:SetID( ID )

	-- This assures that there will be an entry for every column
	for k, v in pairs( self.Columns ) do
		Line:SetColumnText( k, "" )
	end


	for k, v in pairs(type(select(1, ...)) == "table" and select(1, ...) or {...}) do
		Line:SetColumnText( k, v )
	end

	-- Make appear at the bottom of the sorted list
	local SortID = table.insert( self.Sorted, Line )

	if ( SortID % 2 == 1 ) then
		Line:SetAltLine( true )
	end

	self:OnLineAdded({...})

	return Line

end

function self:QueueLine( ... )
	local size = select("#", ...)

	local callback = nil 
	if type(select(size, ...)) == "function" then 
		callback = select(size, ...)
	end

	local args = {}
	for k, v in pairs({...}) do 
		if type(v) == "function" then continue end 
		args[k] = v 
	end

	table.insert(self.queue, {
		callback = callback or function()end,
		args = args 
	})
end	

function self:AddColumn( strName, iPosition )

	local pColumn = nil
	if ( self.m_bSortable ) then
		pColumn = vgui.Create( "DSleekListColumn", self )
	else
		pColumn = vgui.Create( "DSleekListColumn_Plain", self )
	end

	pColumn:SetName( strName )
	pColumn:SetZPos( 10 )

	if ( iPosition ) then

		table.insert( self.Columns, iPosition, pColumn )

		for i = 1, #self.Columns do
			self.Columns[ i ]:SetColumnID( i )
		end

	else

		local ID = table.insert( self.Columns, pColumn )
		pColumn:SetColumnID( ID )

	end

	self:InvalidateLayout()

	return pColumn

end

vgui.Register("DSleekListView", self, "DListView")