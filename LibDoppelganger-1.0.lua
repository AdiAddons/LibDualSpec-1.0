--[[
LibDoppelganger-1.0 - Adds dual spec support to AceDB databases
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

--------------------------------------------------------------------------------
-- Library data
--------------------------------------------------------------------------------

lib.talentGroup = lib.talentGroup or GetActiveTalentGroup()
lib.eventFrame = lib.eventFrame or CreateFrame("Frame")

lib.ace3Registry = lib.ace3Registry or {}
lib.ace3OptionRegistry = lib.ace3OptionRegistry or {}
lib.ace3HandlerPrototype = lib.ace3HandlerPrototype or {}

lib.ace2Registry = lib.ace2Registry or {}
lib.ace2OptionRegistry = lib.ace2OptionRegistry or {}
lib.ace2HandlerPrototype = lib.ace2HandlerPrototype or {}

--------------------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------------------

local ace3Registry = lib.ace3Registry
local ace3OptionRegistry = lib.ace3OptionRegistry
local ace3HandlerPrototype = lib.ace3HandlerPrototype

local ace2Registry = lib.ace2Registry
local ace2OptionRegistry = lib.ace2OptionRegistry
local ace2HandlerPrototype = lib.ace2HandlerPrototype

-- "Externals"
local AceDB2 = AceLibrary and AceLibrary:HasInstance('AceDB-2.0') and AceLibrary:GetInstance('AceDB-2.0')
local AceDB3 = LibStub('AceDB-3.0', true)
local AceDBOptions3 = LibStub('AceDBOptions-3.0', true)

--------------------------------------------------------------------------------
-- Localization
--------------------------------------------------------------------------------

local L_DOPPELGANGER_DESC, L_AUTOSWITCH, L_AUTOSWITCH_DESC, L_ALTERNATE_PROFILE
local L_ALTERNATE_PROFILE_DESC

L_DOPPELGANGER_DESC = 'You can select a profile to switch to when you activate your alternate talents'
L_AUTOSWITCH = 'Automatically switch'
L_AUTOSWITCH_DESC = 'Check this box to automatically swich to your alternate profile on talent switch.'
L_ALTERNATE_PROFILE = 'Alternate profile'
L_ALTERNATE_PROFILE_DESC = 'Select the profile to activate'

--------------------------------------------------------------------------------
-- AceDB-3.0 support
--------------------------------------------------------------------------------

local function UpdateAceDB3(target, db)
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

function lib:EnhanceAceDB3(target)
	AceDB3 = AceDB3 or LibStub('AceDB-3.0', true)
	if type(target) ~= "table" then
		error("Usage: LibDoppelganger:EnhanceAceDB3(target): target should be a table.", 2)
	elseif not AceDB3 or not AceDB3.db_registry[target] then
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
	ace3Registry[target] = db
	UpdateAceDB3(target, db)
end

--------------------------------------------------------------------------------
-- AceDBOptions-3.0 support
--------------------------------------------------------------------------------

local function HasOnlyOneTalentGroup()
	return GetNumTalentGroups() == 1
end

-- Handler methods

function ace3HandlerPrototype:GetAutoSwitch(info)
	return self.db.char.autoSwitch
end

function ace3HandlerPrototype:SetAutoSwitch(info, value)
	self.db.char.autoSwitch = value
	UpdateAceDB3(self.target, self.db)
end

function ace3HandlerPrototype:GetAlternateProfile(info)
	return self.db.char.alternateProfile
end

function ace3HandlerPrototype:SetAlternateProfile(info, value)
	self.db.char.alternateProfile = value
end

function ace3HandlerPrototype:ListProfiles(info)
	return self.optionTable.handler:ListProfiles(info)
end

local function EnhanceAceDBOptions3(optionTable, handler)
	-- Embed our handler methods
	for k,v in pairs(ace3HandlerPrototype) do
		handler[k] = v
	end
	
	-- Create the option table if need be
	if not optionTable.plugins then
		optionTable.plugins = {}
	end
	if not optionTable.plugins[MAJOR] then
		optionTable.plugins[MAJOR] = {}
	end

	-- Add our options
	local options = optionTable.plugins[MAJOR]
	
	options.doppelgangerDesc = {
		name = L_DOPPELGANGER_DESC,
		type = 'description',
		handler = handler,
		order = 40.1,
		hidden = HasOnlyOneTalentGroup,
	}

	options.autoSwitch = {
		name = L_AUTOSWITCH,
		desc = L_AUTOSWITCH_DESC,
		type = 'toggle',
		handler = handler,
		order = 40.2,
		get = 'GetAutoSwitch',
		set = 'SetAutoSwitch',
		hidden = HasOnlyOneTalentGroup,
	}

	options.alternateProfile = {
		name = L_ALTERNATE_PROFILE,
		desc = L_ALTERNATE_PROFILE_DESC,
		type = 'select',
		handler = handler,
		order = 40.3,
		get = "GetAlternateProfile",
		set = "SetAlternateProfile",
		values = "ListProfiles",
		arg = "common",
		hidden = HasOnlyOneTalentGroup,
		disabled = function(info) return not info.handler:GetAutoSwitch(info) end,
	}
end

function lib:EnhanceAceDBOptions3(optionTable, target)
	AceDBOptions3 = AceDBOptions3 or LibStub('AceDBOptions-3.0', true)
	if type(optionTable) ~= "table" then
		error("Usage: LibDoppelganger:EnhanceAceDBOptions3(optionTable, target): optionTable should be a table.", 2)
	elseif type(target) ~= "table" then
		error("Usage: LibDoppelganger:EnhanceAceDBOptions3(optionTable, target): target should be a table.", 2)
	elseif not (AceDBOptions3 and AceDBOptions3.optionTables[target]) then
		error("Usage: LibDoppelganger:EnhanceAceDBOptions3(optionTable, target): optionTable is not an AceDBOptions-3.0 table.", 2)
	elseif optionTable.handler.db ~= target then
		error("Usage: LibDoppelganger:EnhanceAceDBOptions3(optionTable, target): optionTable must be the option table of target.", 2)
	elseif not ace3Registry[target] then
		error("Usage: LibDoppelganger:EnhanceAceDBOptions3(optionTable, target): EnhanceAceDB3(target) should be called before EnhanceAceDBOptions3(optionTable, target).", 2)
	end
	if not ace3OptionRegistry[optionTable] then
		ace3OptionRegistry[optionTable] = {
			optionTable = optionTable,
			target = target,
			db = ace3Registry[target],
		}
	end
	EnhanceAceDBOptions3(optionTable, ace3OptionRegistry[optionTable])
end

-- Upgrade existing handlers and option tables
for optionTable, handler in pairs(ace3OptionRegistry) do
	EnhanceAceDBOptions3(optionTable, handler)
end

--------------------------------------------------------------------------------
-- AceDB-2.0 support
--------------------------------------------------------------------------------

local function UpdateAceDB2(target, db)
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

function lib:EnhanceAceDB2(target)
	AceDB2 = AceDB2 or (AceLibrary and AceLibrary:HasInstance('AceDB-2.0') and AceLibrary('AceDB-2.0'))
	if type(target) ~= "table" then
		error("Usage: LibDoppelganger:EnhanceAceDB2(target): target be a table.", 2)
	elseif not AceDB2 or not AceDB2.registry[target] then
		error("Usage: LibDoppelganger:EnhanceAceDB2(target): target should embed AceDB-2.0.", 2)
	--elseif target.db and target.db.db then
	--	error("Usage: LibDoppelganger:EnhanceAceDB2(target): cannot enhance a namespace.", 2)
	end
	local db = target:AcquireDBNamespace(MAJOR)
	if not db.char.talentGroup then
		db.char.talentGroup = lib.talentGroup
		db.char.alternateProfile = select(2, target:GetProfile())
		db.char.autoSwitch = false		
	end 
	ace2Registry[target] = db
	UpdateAceDB2(target, db)
end

--------------------------------------------------------------------------------
-- AceDB-2.0 option support
--------------------------------------------------------------------------------

function ace2HandlerPrototype:GetAlternateProfile()
	return self.db.char.alternateProfile
end

function ace2HandlerPrototype:SetAlternateProfile(value)
	self.db.char.alternateProfile = value
end

function ace2HandlerPrototype:GetAutoSwitch()
	return self.db.char.autoSwitch
end

function ace2HandlerPrototype:SetAutoSwitch(value)
	self.db.char.autoSwitch = value
	UpdateAceDB(self.target, self.db)
end

local function EnhanceAceDBOptions2(optionTable, handler)
	-- Update the handler
	for k,v in pairs(ace2HandlerPrototype) do
		handler[k] = v
	end
	
	-- Update the option table
	local options = optionTable.profile.args

	-- Enforce ordering of existing options
	options.choose.order = 1
	options.copy.order = 2
	options.other.order = 3
	options.delete.orger = 4
	options.reset.order = 5
	
	-- Add our options
	options.autoSwitch = {
		cmdName = L_AUTOSWITCH,
		guiName = L_AUTOSWITCH,
		desc = L_AUTOSWITCH_DESC,
		usage = 'L_AUTOSWITCH_USAGE',
		order = 1.1,
		handler = handler,
		type = 'text',
		get = "GetAutoSwitch",
		set = "SetAutoSwitch",
		--hidden = HasOnlyOneTalentGroup,
	}
	
	options.alternateProfile = {
		cmdName = L_ALTERNATE_PROFILE,
		guiName = L_ALTERNATE_PROFILE,
		desc = L_ALTERNATE_PROFILE_DESC,
		usage = 'L_ALTERNATE_PROFILE_USAGE',
		order = 1.1,
		type = 'text',
		handler = handler,
		get = "GetAlternateProfile",
		set = "SetAlternateProfile",
		validate = handler.target['acedb-profile-list'],
		-- hidden = HasOnlyOneTalentGroup,
	}
end

function lib:EnhanceAceDBOptions2(optionTable, target)
	AceDB2 = AceDB2 or (AceLibrary and AceLibrary:HasInstance('AceDB-2.0') and AceLibrary('AceDB-2.0'))
	if type(optionTable) ~= "table" then
		error("Usage: LibDoppelganger:EnhanceAceDBOptions2(optionTable, target): optionTable should be a table.", 2)
	elseif type(target) ~= "table" then
		error("Usage: LibDoppelganger:EnhanceAceDBOptions2(optionTable, target): target should be a table.", 2)
	elseif not AceDB2 or not AceDB2.registry[target] then
		error("Usage: LibDoppelganger:EnhanceAceDBOptions2(optionTable, target): optionTable is not an AceDB-2.0 table.", 2)
	elseif not ace2Registry[target] then
		error("Usage: LibDoppelganger:EnhanceAceDBOptions2(optionTable, target): EnhanceAceDB2(target) should be called before EnhanceAceDBOptions2(optionTable, target).", 2)
	end
	if not ace2OptionRegistry[target] then
		ace2OptionRegistry[target] = {
			target = target,
			db = ace2Registry[target] 
		}
	end
	EnhanceAceDBOptions2(optionTable, ace2OptionRegistry[target])
end

-- Upgrade existing option tables
for optionTable, handler in pairs(ace2OptionRegistry) do
	EnhanceAceDBOptions2(optionTable, handler)
end

--------------------------------------------------------------------------------
-- Switching logic
--------------------------------------------------------------------------------

lib.eventFrame:RegisterEvent('PLAYER_TALENT_UPDATE')
lib.eventFrame:SetScript('OnEvent', function()
	local newTalentGroup = GetActiveTalentGroup()
	if lib.talentGroup ~= newTalentGroup then
		lib.talentGroup = newTalentGroup
		for target, db in pairs(ace3Registry) do
			UpdateAceDB3(target, db)
		end
		for target, db in pairs(ace2Registry) do
			UpdateAceDB2(target, db)
		end
	end
end)

