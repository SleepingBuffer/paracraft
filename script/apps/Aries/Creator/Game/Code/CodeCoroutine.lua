--[[
Title: Code Coroutine
Author(s): LiXizhi
Date: 2018/5/30
Desc: call back functions or the main function that must be executed in a separate coroutine. 
All coroutines share the same CodeAPI environment, except for current actor. 
MakeCallbackFunc will restore last actor and coroutine context.
Run the same coroutine multiple times will cause the previous one to stop forever.
use the lib:
-------------------------------------------------------
NPL.load("(gl)script/apps/Aries/Creator/Game/Code/CodeCoroutine.lua");
local CodeCoroutine = commonlib.gettable("MyCompany.Aries.Game.Code.CodeCoroutine");
local co = CodeCoroutine:new():Init(codeBlock);
co:SetFunction(func)
co:SetActor(actor)
co:Run();
-------------------------------------------------------
]]
NPL.load("(gl)script/apps/Aries/Creator/Game/Code/CodeAPI.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Code/CodeActor.lua");
local CodeAPI = commonlib.gettable("MyCompany.Aries.Game.Code.CodeAPI");
local CodeCoroutine = commonlib.inherit(commonlib.gettable("System.Core.ToolBase"), commonlib.gettable("MyCompany.Aries.Game.Code.CodeCoroutine"));
CodeCoroutine:Signal("finished");

function CodeCoroutine:ctor()
end

function CodeCoroutine:Init(codeBlock)
	self.codeBlock = codeBlock;
	return self;
end

function CodeCoroutine:Destroy()
	CodeCoroutine._super.Destroy(self);
end

function CodeCoroutine:SetFunction(code_func)
	self.code_func = code_func;
end

function CodeCoroutine:AddTimer(timer)
	self.timers = self.timers or {}
	self.timers[timer] = true;
end

function CodeCoroutine:RemoveTimer(timer)
	if(self.timers) then
		self.timers[timer] = nil;
	end
end

function CodeCoroutine:KillAllTimers()
	if(self.timers) then
		for timer, _ in pairs(self.timers) do
			self.codeBlock:KillTimer(timer);
		end
		self.timers = nil;
	end
end

function CodeCoroutine:KillTimer(timer)
	self:RemoveTimer(timer);
	self:GetCodeBlock():KillTimer(timer);
end

function CodeCoroutine:MakeCallbackFunc(callbackFunc)
	return function(...)
		if(not self.isStopped) then
			self:SetCurrentCodeContext();
			if(callbackFunc) then
				callbackFunc(...);
			end
		end
	end
end

function CodeCoroutine:SetTimer(callbackFunc, dueTime, period)
	local timer = self:GetCodeBlock():SetTimer(self:MakeCallbackFunc(callbackFunc), dueTime, period);
	self:AddTimer(timer);
	return timer;
end

function CodeCoroutine:SetTimeout(duration, callbackFunc)
	local timer = self:GetCodeBlock():SetTimeout(duration, function(timer)
		self:SetCurrentCodeContext()
		self:RemoveTimer(timer);
		if(callbackFunc and not self.isStopped) then
			callbackFunc(timer);
		end
	end);
	self:AddTimer(timer);
	return timer;
end

function CodeCoroutine:SetActor(actor)
	self.actor = actor;
end

function CodeCoroutine:GetActor()
	return self.actor;
end

function CodeCoroutine:GetCodeBlock()
	return self.codeBlock;
end

-- @return : "running", "dead", "suspended", nil
function CodeCoroutine:GetStatus()
	return self.co and coroutine.status(self.co);
end

function CodeCoroutine:IsRunning()
	return not self.isStopped;
end

-- the coroutine has finished the last line of its code, but it may not be stopped, since it may still contain valid timers such as playing animations. 
function CodeCoroutine:IsFinished()
	return self.isFinished;
end

function CodeCoroutine:SetFinished()
	if(not self.isFinished) then
		self.isFinished = true;
		self:finished();
	end
end

-- when stopped, it can no longer be resumed
function CodeCoroutine:Stop()
	self.isStopped = true;
	self:SetFinished();
	-- we need to stop the last coroutine timers, before starting a new one. 
	self:KillAllTimers();
end

function CodeCoroutine:SetCurrentCodeContext()
	GameLogic.GetCodeGlobal():SetCurrentCoroutine(self);
end

-- Run the same coroutine multiple times will cause the previous one to stop forever.
function CodeCoroutine:Run(msg, onFinishedCallback)
	self:Stop();
	self.isStopped = false;
	self.isFinished = false;
	self.codeBlock:Connect("beforeStopped", self, self.Stop, "UniqueConnection");
	if(self.code_func) then
		self.co = coroutine.create(function()
			local result, r2, r3, r4 = self:RunImp(msg);
			self:SetFinished();
			self.codeBlock:Disconnect("beforeStopped", self, self.Stop);
			if(onFinishedCallback) then
				onFinishedCallback(result, r2, r3, r4);
			end
			return result, r2, r3, r4;
		end)
		local ok, result, r2, r3, r4 = self:Resume();
		if(ok and self.isFinished) then
			return result, r2, r3, r4;
		end
	end
end

local lastErrorCallstack = "";
function CodeCoroutine.handleError(x)
	lastErrorCallstack = commonlib.debugstack(2, 5, 1);
	return x;
end

function CodeCoroutine:RunImp(msg)
	local code_func = self.code_func;
	if(code_func) then
		setfenv(code_func, self:GetCodeBlock():GetCodeEnv());
		local ok, result, r2, r3, r4 = xpcall(code_func, CodeCoroutine.handleError, msg);

		if(not ok) then
			if(result:match("_stop_all_")) then
				self:GetCodeBlock():StopAll();
			elseif(result:match("_restart_all_")) then
				self:GetCodeBlock():RestartAll();
			else
				LOG.std(nil, "error", "CodeCoroutine", "%s\n%s", result, lastErrorCallstack);
				local msg = format(L"运行时错误: %s\n在%s", tostring(result), self:GetCodeBlock():GetFilename());
				self:GetCodeBlock():send_message(msg, "error");
			end
		end
		return result, r2, r3, r4;
	end
end

function CodeCoroutine:Resume(err, msg, p3, p4)
	if(self.co and not self.isStopped) then
		self:SetCurrentCodeContext();
		return coroutine.resume(self.co, err, msg, p3, p4);
	end
end

-- CAUTION: only call this inside coroutine
function CodeCoroutine:Yield()
	if(self.co) then
		return coroutine.yield();
	end
end
