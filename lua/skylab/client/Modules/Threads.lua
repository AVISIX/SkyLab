if not SSLE or SERVER then 
	return 
end

local threading = {}
threading.__index = threading 

local thread = {super = threading}
thread.__index = thread 

local queue = {}
hook.Remove("Think", "SSLE_Threading_Threads_GarbageCollector")
hook.Add("Think", "SSLE_Threading_Threads_GarbageCollector", function()
	if #queue > 0 then 
		for k, v in pairs(queue) do 
			threading.bank[v] = nil 
		end
		queue = {}
	end
end)

do 
	function thread:Setup(id, callback)
		if not id or not callback then return end 

		self.id = id 
		self.thread = coroutine.create(function() callback(self) end)
		self.unstarted = true 

		return self
	end

	function thread:GetID()
		return self.id 
	end

	function thread:GetThread()
		return self.thread 
	end

	function thread:GetState()
		local s = coroutine.status(self.thread)

		if self.unstarted == true then return "unstarted" end 
		if s == "suspended" then       return "paused"    end
		if s == "running" then	       return "running"   end
		if s == "dead" then            return "dead"      end

		return "unstarted"
	end

	function thread:Start()
		if self:GetState() == "dead" or self:GetState() == "running" then return end 
		self.unstarted = false 
		return coroutine.resume(self.thread)
	end 

	function thread:Pause()
		if self:GetState() ~= "running" then return end  
		coroutine.yield(self.thread)
	end

	function thread:Continue()
		if self:GetState() == "paused" or self:GetState() == "unstarted" then return end  
		self.unstarted = false 
		return self:Start()
	end

	function thread:Redirect(id)
		if self:GetState() == "paused" or self:GetState() == "unstarted" then return false end   

		if not id then return false end 

		if type(id) == "thread" then 
			local status = id:Start()
			if status == false then 
				self:Continue() 
				return false
			end
		elseif type(id) == "string" then 
			local t = threading:GetThread(id)

			if not t then 
				self:Continue()
				return false 
			end

			local status = t:Start()

			if status == false then 
				self:Continue()
				return false
			end
		else 
			self:Continue()
			return false 
		end

		self:Pause()

		return true 
	end

	function thread:Kill()
		table.insert(queue, self.id)
		self:Pause()
	end
end  

do 
	local function registerThread(id, callback)
		if not id or not callback then return end 
		if not threading.bank then threading.bank = {} end 
		if threading.bank[id] then return end 
		threading.bank[id] = table.Copy(thread):Setup(id, callback) 
		return threading.bank[id]
	end

	function threading:Create(id, callback)
		if not id and not callback then return end 
		if type(id) == "function" then 
			callback = id 
			id = randomWord(20)
			while threading.bank[id] do id = randomWord(20) end
			return registerThread(id, callback)  
		end
		return registerThread(id, callback) 
	end

	function threading:GetThread(id)
		if not id then return end 
		return self.bank[id]
	end
end 

SSLE.modules = SSLE.modules or {}
SSLE.modules.threading = threading 
