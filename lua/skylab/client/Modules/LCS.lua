local LCS = {}

-- https://www.lua.org/wshop12/Snyder1.pdf

--http://lua-users.org/lists/lua-l/2009-07/msg00461.html
function LCS.levenshtein(s, t) -- The Wire Editor uses this, but I don't like it. Please use lcs_3b! 
	local d, sn, tn = {}, #s, #t
	local byte, min = string.byte, math.min
	for i = 0, sn do d[i * tn] = i end
	for j = 0, tn do d[j] = j end
	for i = 1, sn do
		local si = byte(s, i)
		for j = 1, tn do
            d[i*tn+j] = min(d[(i-1)*tn+j]+1, d[i*tn+j-1]+1, d[(i-1)*tn+j-1]+(si == byte(t,j) and 0 or 1))
		end
	end
	return d[#d]
end

-- Recursive LCS Implementation
function LCS.lcs_2b(a, b)
    local m = #a
    local n = #b
    if (m == 0) or (n == 0) then
        return 0
    elseif string.sub(a, m, m) == string.sub(b, n, n) then
        return LCS.lcs_2b(string.sub(a, 1, m-1), string.sub(b, 1, n-1)) + 1
    else
        local a1 = LCS.lcs_2b(a, string.sub(b, 1, n-1))
        local b1 = LCS.lcs_2b(string.sub(a, 1, m-1), b)
        return math.max(a1, b1)
    end
end

-- Improved Recursive LCS Implementation
local function _lcs_3b(A, i, B, j)
    if i == 0 or j == 0 then
        return 0
    end
    
    if A[i] == B[j] then 
        return _lcs_3b(A, i-1, B, j-1) + 1 
    end 

    return math.max(_lcs_3b(A, i, B, j-1), _lcs_3b(A, i-1, B, j))
end

function LCS.lcs_3b(A, B)
    return _lcs_3b(A, #A, B, #B)
end

SSLE.modules = SSLE.modules or {}
SSLE.modules.lcs = LCS 