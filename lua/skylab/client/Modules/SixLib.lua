if not SSLE then 
    return 
end 

function SSLE:GetWindow(element)
    if IsValid(element) == false then return end 
     
    while element:GetParent() ~= vgui.GetWorldPanel() do 
        element = element:GetParent()
    end

    return element 
end
