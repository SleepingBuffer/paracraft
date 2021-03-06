--[[
Title: CodeAPI
Author(s): LiXizhi
Date: 2018/5/16
Desc: sandbox API environment, see also CodeGlobals for shared API and globals.
use the lib:
-------------------------------------------------------
NPL.load("(gl)script/apps/Aries/Creator/Game/Code/CodeAPI.lua");
local CodeAPI = commonlib.gettable("MyCompany.Aries.Game.Code.CodeAPI");
local api = CodeAPI:new(codeBlock);
-------------------------------------------------------
]]
NPL.load("(gl)script/apps/Aries/Creator/Game/Code/CodeAPI_Events.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Code/CodeAPI_MotionLooks.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Code/CodeAPI_Sensing.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Code/CodeAPI_Sound.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Code/CodeAPI_Data.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Code/CodeAPI_Control.lua");

-- all public environment methods. 
local s_env_methods = {
	"resume", 
	"yield", 
	"checkyield",
	"GetEntity",
	"restart",
	"exit",
	"xpcall",
	-- Data
	"print",
	"log",
	"echo",
	"setActorValue",
	"getActorValue",
	"showVariable",
	"include",
	"getActor",
	"cmd",

	-- Motion
	"move",
	"moveTo",
	"moveForward",
	"walk",
	"walkForward",
	"turn",
	"turnTo",
	"bounce",
	"velocity",
	"getX",
	"getY",
	"getZ",
	"getFacing",
	"getPos",
	"setPos",
	-- Looks
	"say",
	"show",
	"hide",
	"anim",
	"play",
	"playLoop",
	"playSpeed",
	"playBone",
	"stop",
	"scale",
	"scaleTo",
	"getPlayTime",
	"getScale",
	"focus",
	"camera",
	"setMovie",
	"setMovieProperty",
	"playMovie",
	"stopMovie",

	-- Events
	"registerClickEvent",
	"registerKeyPressedEvent",
	"registerAnimationEvent",
	"registerBroadcastEvent",
	"registerBlockClickEvent",
	"registerStopEvent",
	"broadcast",
	"broadcastAndWait",
	"registerNetworkEvent",
	"broadcastNetworkEvent",
	"sendNetworkEvent",

	-- Control
	"wait",
	"waitUntil",
	"registerCloneEvent",
	"clone",
	"delete",
	"run",
	"runForActor",
	"becomeAgent",
	"setOutput",

	-- Sensing
	"isTouching",
	"registerCollisionEvent",
	"broadcastCollision",
	"distanceTo",
	"calculatePushOut",
	"isKeyPressed",
	"isMouseDown",
	"getTimer",
	"resetTimer",
	"ask",

	-- Sound
	"playNote",
	"playSound",
	"stopSound",
	"playMusic",
}
local GameLogic = commonlib.gettable("MyCompany.Aries.Game.GameLogic")

local CodeAPI = commonlib.gettable("MyCompany.Aries.Game.Code.CodeAPI");
local env_imp = commonlib.gettable("MyCompany.Aries.Game.Code.env_imp");
CodeAPI.__index = CodeAPI;


-- @param actor: CodeActor that this code API is controlling. 
function CodeAPI:new(codeBlock)
	local o = {
		codeblock = codeBlock,
		check_count = 0,
	};
	o._G = GameLogic.GetCodeGlobal():GetCurrentGlobals();

	CodeAPI.InstallMethods(o);
	setmetatable(o, GameLogic.GetCodeGlobal():GetCurrentMetaTable());
	return o;
end

-- install functions to code environment
function CodeAPI.InstallMethods(o)
	for _, func_name in ipairs(s_env_methods) do
		local f = function(...)
			return env_imp[func_name](o, ...);
		end
		o[func_name] = f;
	end
end


-- yield control until all async jobs are completed
-- @param bExitOnError: if true, this function will handle error 
-- @return err, msg: err is true if there is error. 
function env_imp:yield(bExitOnError)
	local err, msg, p3, p4;
	if(self.co) then
		if(self.fake_resume_res) then
			err, msg = unpack(self.fake_resume_res);
			self.fake_resume_res = nil;
			return err, msg;
		else
			self.check_count = 0;
			err, msg, p3, p4 = self.co:Yield();
			if(err and bExitOnError) then
				env_imp.exit(self);
			end
		end
	end
	return err, msg, p3, p4;
end

-- resume from where jobs are paused last. 
-- @param err: if there is error, this is true, otherwise it is nil.
-- @param msg: error message in case err=true
function env_imp:resume(err, msg, p3, p4)
	if(self.co) then
		if(self.co:GetStatus() == "running") then
			self.fake_resume_res = {err, msg, p3, p4};
			return;
		else
			self.fake_resume_res = nil;
		end
		local res, err, msg = self.co:Resume(err, msg, p3, p4);
	end
end

-- calling this function 100 times will automatically yield and resume until next tick (1/30 seconds)
-- we will automatically insert this function into while and for loop. One can also call this manually
function env_imp:checkyield()
	self.check_count = self.check_count + 1;
	if(self.check_count > 100) then
		if(self.codeblock:IsAutoWait()) then
			env_imp.wait(self, env_imp.GetDefaultTick(self));
		else
			self.check_count = 0;
		end
	end
end

-- private: 
function env_imp:GetDefaultTick()
	if(not self.default_tick) then
		self.default_tick = self.codeBlock and self.codeBlock:GetDefaultTick() or 0.02;
	end
	return self.default_tick;
end
