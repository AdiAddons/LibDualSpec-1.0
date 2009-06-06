--[[
LibDoppelganger-1.0 - Library providing automatic profile switching 
Copyright (C) 2009 Adirelle

All rights reserved.

Redistribution and use in source and binary forms, with or without 
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice, 
      this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice, 
      this list of conditions and the following disclaimer in the documentation 
      and/or other materials provided with the distribution.
    * Redistribution of a stand alone version is strictly prohibited without 
      prior written authorization from the LibDoppelganger project manager. 
    * Neither the name of the LibDoppelganger authors nor the names of its contributors 
      may be used to endorse or promote products derived from this software without 
      specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--]]

local MAJOR, MINOR = "LibDoppelganger-1.0", 1
assert(LibStub, MAJOR.." requires LibStub")
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

lib.talentGroup = lib.talentGroup or GetActiveTalentGroup()
lib.aceDB2Registry = lib.aceDB2Registry or {}
lib.aceDB3Registry = lib.aceDB3Registry or {}

local aceDB2Registry = lib.aceDB2Registry
local aceDB3Registry = lib.aceDB3Registry

local AceDB2 = AceLibrary and AceLibrary:HasInstance('AceDB-2.0') and AceLibrary:GetInstance('AceDB-2.0')
local AceDB3 = LibStub('AceDB-3.0', true)
local AceDBOptions3 = LibStub('AceDBOptions-3.0', true)

lib.eventFrame = lib.eventFrame or CreateFrame("Frame")
local eventFrame = lib.eventFrame

--------------------------------------------------------------------------------
-- AceDB-3.0 support
--------------------------------------------------------------------------------

function lib:EnhanceAceDB3(target)
	AceDB3 = AceDB3 or LibStub('AceDB-3.0', true)
	if not AceDB3 or not AceDB3.db_registry[target] then
		error("Usage: LibDoppelganger:EnhanceAceDB3(target): target should be an AceDB-3.0 database.", 2)
	elseif target.parent then
		error("Usage: LibDoppelganger:EnhanceAceDB3(target): cannot enhance a namespace.", 2)
	end
	local db = target:GetNamespace(MAJOR, true) or target:RegisterNamespace(MAJOR)
	if not db.char.talentGroup then
		db.char.talentGroup = lib.talentGroup
		db.char.alternateProfile = target:GetCurrentProfile()
		db.char.autoSwitch = false	
	end
	aceDB3Registry[target] = db
	lib:UpdateAceDB3(target, db)
end

function lib:UpdateAceDB3(target, db)
	if db.char.autoSwitch and db.char.talentGroup ~= lib.talentGroup then
		local currentProfile = target:GetCurrentProfile()
		local newProfile = db.char.alternateProfile
		db.char.talentGroup = lib.talentGroup
		if newProfile ~= currentProfile then
			target:SetProfile(newProfile)
			db.char.alternateProfile = currentProfile
		end
	end
end

function lib:AceDB3TalentSwitch()
	for target, db in pairs(aceDB3Registry) do
		lib:UpdateAceDB3(target, db)
	end
end

--------------------------------------------------------------------------------
-- AceDBOptions-3.0 support
--------------------------------------------------------------------------------

lib.ace3OptionTables = lib.ace3OptionTables or {}
local ace3OptionTables = lib.ace3OptionTables

local ace3Options = {
	doppelgangerDesc = {
		name = 'You can select a profile to switch to when you activate your alternate talents',
		type = 'description',
		order = 40.1,
		hidden = 'HasOnlyOneTalentGroup',
	},
	autoSwitch = {
		name = 'Automatically switch',
		desc = 'Check this box to automatically swich to your alternate profile on talent switch.',
		type = 'toggle',
		order = 40.2,
		get = 'GetAutoSwitch',
		set = 'SetAutoSwitch',
		hidden = 'HasOnlyOneTalentGroup',
	},
	alternateProfile = {
		name = 'Alternate profile',
		desc = 'Select the profile to activate',
		type = 'select',
		order = 40.3,
		get = "GetAlternateProfile",
		set = "SetAlternateProfile",
		values = "ListProfiles",
		arg = "common",
		hidden = 'HasOnlyOneTalentGroup',
		disabled = function(info) return not info.handler:GetAutoSwitch(info) end,
	},
}

local function GetAce3OptionTable(target)
	local optionTable = ace3OptionTables[target] or {}
	for name, option in pairs(ace3Options) do
		optionTable[name] = option
	end
	return optionTable
end

for target, optionTable in pairs(ace3OptionTables) do
	for name, option in pairs(ace3Options) do
		optionTable[name] = option
	end
end

local ace3handlerPrototype = {}

lib.ace3OptionHandlers = lib.ace3OptionHandlers or {}
local ace3OptionHandlers = lib.ace3OptionHandlers

function ace3handlerPrototype:GetAutoSwitch(info)
	local db = aceDB3Registry[ace3OptionHandlers[info.handler]]
	return db.char.autoSwitch
end

function ace3handlerPrototype:SetAutoSwitch(info, value)
	local db = aceDB3Registry[ace3OptionHandlers[info.handler]]
	db.char.autoSwitch = value
end

function ace3handlerPrototype:GetAlternateProfile(info)
	local db = aceDB3Registry[ace3OptionHandlers[info.handler]]
	return db.char.alternateProfile
end

function ace3handlerPrototype:SetAlternateProfile(info, value)
	local db = aceDB3Registry[ace3OptionHandlers[info.handler]]
	db.char.alternateProfile = value
end

function ace3handlerPrototype:HasOnlyOneTalentGroup()
	return GetNumTalentGroups() == 1
end

local function EnhanceAce3OptionHandler(handler, target)
	ace3OptionHandlers[handler] = target
	for k,v in pairs(ace3handlerPrototype) do
		handler[k] = v
	end
end

for handler, target in pairs(ace3OptionHandlers) do
	EnhanceAce3OptionHandler(handler, target)
end

function lib:EnhanceAceDBOptions3(options)
	local target = options and options.handler and options.handler.db
	AceDBOptions3 = AceDBOptions3 or LibStub('AceDBOptions-3.0', true)
	local optionTable = AceDBOptions3 and AceDBOptions3.optionTables[target]
	if not optionTable then
		error("Usage: LibDoppelganger:EnhanceAceDBOptions3(target): no AceDBOptions-3.0 options for target.", 2)
	end
	if not optionTable.plugins then
		optionTable.plugins = {}
	end
	optionTable.plugins[MAJOR] = GetAce3OptionTable(target)
	EnhanceAce3OptionHandler(optionTable.handler, target)
end

--------------------------------------------------------------------------------
-- AceDB-2.0 support
--------------------------------------------------------------------------------

function lib:EnhanceAceDB2(target)
	AceDB2 = AceDB2 or (AceLibrary and AceLibrary:HasInstance('AceDB-2.0') and AceLibrary('AceDB-2.0'))
	if not AceDB2 or not AceDB2.registry[target] then
		error("Usage: LibDoppelganger:EnhanceAceDB2(db): db should embed AceDB-2.0.", 2)
	elseif target.db.db then
		error("Usage: LibDoppelganger:EnhanceAceDB2(db): cannot enhance a namespace.", 2)
	end
	local db = target:AcquireDBNamespace(MAJOR)
	if not db.char.talentGroup then
		db.char.talentGroup = lib.talentGroup
		db.char.alternateProfile = select(2, target:GetProfile())
		db.char.autoSwitch = false		
	end
	aceDB2Registry[target] = db
	lib:UpdateAceDB2(target, db)
end

function lib:UpdateAceDB2(target, db)
	if db.char.autoSwitch and db.char.talentGroup ~= lib.talentGroup then
		local _, currentProfile = target:GetCurrentProfile()
		local newProfile = db.char.alternateProfile
		db.char.talentGroup = lib.talentGroup
		if newProfile ~= currentProfile then
			target:SetProfile(newProfile)
			db.char.alternateProfile = currentProfile
		end
	end
end

function lib:AceDB2TalentSwitch()
	for target, db in pairs(aceDB2Registry) do
		lib:UpdateAceDB2(target, db)
	end
end

--------------------------------------------------------------------------------
-- Switching logic
--------------------------------------------------------------------------------

eventFrame:SetScript('OnEvent', function(self, event, ...) self[event](self, event, ...) end)
eventFrame:RegisterEvent('PLAYER_TALENT_UPDATE')
function eventFrame:PLAYER_TALENT_UPDATE()
	local newTalentGroup = GetActiveTalentGroup()
	if lib.talentGroup ~= newTalentGroup then
		lib.talentGroup = newTalentGroup
		lib:AceDB3TalentSwitch()
		lib:AceDB2TalentSwitch()
	end
end

--------------------------------------------------------------------------------
-- Mass testing
--------------------------------------------------------------------------------

--[=[@debug@
AceDB3 = AceDB3 or LibStub('AceDB-3.0', true)
if AceDB3 then
	for target in pairs(AceDB3.db_registry) do
		if not target.parent then
			lib:EnhanceAceDB3(target)
		end
	end
end
--@end-debug@]=]
