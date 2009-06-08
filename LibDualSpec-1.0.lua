--[[
LibDualSpec-1.0 - Adds dual spec support to individual AceDB-3.0 databases
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
      prior written authorization from the LibDualSpec project manager.
    * Neither the name of the LibDualSpec authors nor the names of its contributors
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

local MAJOR, MINOR = "LibDualSpec-1.0", 1
assert(LibStub, MAJOR.." requires LibStub")
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

--------------------------------------------------------------------------------
-- Library data
--------------------------------------------------------------------------------

lib.talentGroup = lib.talentGroup or GetActiveTalentGroup()
lib.eventFrame = lib.eventFrame or CreateFrame("Frame")

lib.registry = lib.registry or {}
lib.options = lib.options or {}
lib.mixin = lib.mixin or {}

--------------------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------------------

local registry = lib.registry
local options = lib.options
local mixin = lib.mixin

-- "Externals"
local AceDB3 = LibStub('AceDB-3.0', true)
local AceDBOptions3 = LibStub('AceDBOptions-3.0', true)

--------------------------------------------------------------------------------
-- Localization
--------------------------------------------------------------------------------

local L_DUALSPEC_DESC, L_ENABLED, L_ENABLED_DESC, L_DUAL_PROFILE
local L_DUAL_PROFILE_DESC

L_DUALSPEC_DESC = 'Here you can select a profile for your character alternate spec.'
L_ENABLED = 'Enable profile switch'
L_ENABLED_DESC = 'Check this box to automatically swicth to the selected profile on alternate spec activation.'
L_DUAL_PROFILE = 'Dual profile'
L_DUAL_PROFILE_DESC = 'Select the profile to switch to when the alternate spec is activated.'

--------------------------------------------------------------------------------
-- Mixin
--------------------------------------------------------------------------------

function mixin:IsDualSpecEnabled()
	return registry[self].db.char.enabled
end

function mixin:SetDualSpecEnabled(value)
	local db = registry[self].db
	if value and not db.char.talentGroup then
		db.char.talentGroup = lib.talentGroup
		db.char.profile = self:GetCurrentProfile()
		db.char.enabled = true	
	else
		db.char.enabled = value
		self:CheckDualSpecState()
	end
end

function mixin:GetDualSpecProfile()
	return registry[self].db.char.profile or self:GetCurrentProfile()
end

function mixin:SetDualSpecProfile(value)
	registry[self].db.char.profile = value
end

function mixin:CheckDualSpecState()
	local db = registry[self].db
	if db.char.enabled and db.char.talentGroup ~= lib.talentGroup then
		local currentProfile = self:GetCurrentProfile()
		local newProfile = db.char.profile
		db.char.talentGroup = lib.talentGroup
		if newProfile ~= currentProfile then
			self:SetProfile(newProfile)
			db.char.profile = currentProfile
		end
	end
end

--------------------------------------------------------------------------------
-- AceDB-3.0 support
--------------------------------------------------------------------------------

local function EmbedMixin(target)
	for k,v in pairs(mixin) do
		rawset(target, k, v)
	end
end

-- Upgrade existing mixins
for target in pairs(registry) do
	EmbedMixin(target)
end

function lib:EnhanceDatabase(target, name)
	AceDB3 = AceDB3 or LibStub('AceDB-3.0', true)
	if type(target) ~= "table" then
		error("Usage: LibDualSpec:EnhanceAceDB3(target): target should be a table.", 2)
	elseif not AceDB3 or not AceDB3.db_registry[target] then
		error("Usage: LibDualSpec:EnhanceAceDB3(target): target should be an AceDB-3.0 database.", 2)
	elseif target.parent then
		error("Usage: LibDualSpec:EnhanceAceDB3(target): cannot enhance a namespace.", 2)
	elseif registry[target] then
		return
	end
	local db = target:GetNamespace(MAJOR, true) or target:RegisterNamespace(MAJOR)
	registry[target] = { name = name, db = db	}
	EmbedMixin(target)
	target:CheckDualSpecState()
end

--------------------------------------------------------------------------------
-- AceDBOptions-3.0 support
--------------------------------------------------------------------------------

local function NoDualSpec()
	return GetNumTalentGroups() == 1
end

options.dualSpecDesc = {
	name = L_DUALSPEC_DESC,
	type = 'description',
	order = 40.1,
	hidden = NoDualSpec,
}

options.enabled = {
	name = L_ENABLED,
	desc = L_ENABLED_DESC,
	type = 'toggle',
	order = 40.2,
	get = function(info) return info.handler.db:IsDualSpecEnabled() end,
	set = function(info, value) info.handler.db:SetDualSpecEnabled(value) end,
	hidden = NoDualSpec,
}

options.alternateProfile = {
	name = L_DUAL_PROFILE,
	desc = L_DUAL_PROFILE_DESC,
	type = 'select',
	order = 40.3,
	get = function(info) return info.handler.db:GetDualSpecProfile() end,
	set = function(info, value) info.handler.db:SetDualSpecProfile(value) end,
	values = "ListProfiles",
	arg = "common",
	hidden = NoDualSpec,
	disabled = function(info) return not info.handler.db:IsDualSpecEnabled() end,
}

function lib:EnhanceOptions(optionTable, target)
	AceDBOptions3 = AceDBOptions3 or LibStub('AceDBOptions-3.0', true)
	if type(optionTable) ~= "table" then
		error("Usage: LibDualSpec:EnhanceAceDBOptions3(optionTable, target): optionTable should be a table.", 2)
	elseif type(target) ~= "table" then
		error("Usage: LibDualSpec:EnhanceAceDBOptions3(optionTable, target): target should be a table.", 2)
	elseif not (AceDBOptions3 and AceDBOptions3.optionTables[target]) then
		error("Usage: LibDualSpec:EnhanceAceDBOptions3(optionTable, target): optionTable is not an AceDBOptions-3.0 table.", 2)
	elseif optionTable.handler.db ~= target then
		error("Usage: LibDualSpec:EnhanceAceDBOptions3(optionTable, target): optionTable must be the option table of target.", 2)
	elseif not registry[target] then
		error("Usage: LibDualSpec:EnhanceAceDBOptions3(optionTable, target): EnhanceAceDB3(target) should be called before EnhanceAceDBOptions3(optionTable, target).", 2)
	elseif optionTable.plugins and optionTable.plugins[MAJOR] then
		return
	end
	if not optionTable.plugins then
		optionTable.plugins = {}
	end
	optionTable.plugins[MAJOR] = options
end

--------------------------------------------------------------------------------
-- Inspection
--------------------------------------------------------------------------------

local function iterator(registry, key)
	local data
	key, data = next(registry, key)
	if key then
		return key, data.name
	end
end

function lib:IterateDatabases()
	return iterator, lib.registry
end

--------------------------------------------------------------------------------
-- Switching logic
--------------------------------------------------------------------------------

lib.eventFrame:RegisterEvent('PLAYER_TALENT_UPDATE')
lib.eventFrame:SetScript('OnEvent', function()
	local newTalentGroup = GetActiveTalentGroup()
	if lib.talentGroup ~= newTalentGroup then
		lib.talentGroup = newTalentGroup
		for target in pairs(registry) do
			target:CheckDualSpecState()
		end
	end
end)

