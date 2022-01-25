-- ----------------------------------------------------
-- Provide Moho with the name of this script object
-- ----------------------------------------------------
ScriptName = "SS_Ch_VisemesImport"

-- **************************************************
-- (Adobe Character Animator) Ch Visemes Import
-- [Ch] Visemes Keydata import to Switch Layer
-- version:	01.00 MH12/MH13.5+ #520124
-- by Sam Cogheil (SimplSam)
-- **************************************************

--[[ ***** Licence & Warranty *****

    Copyright 2022 - Sam Cogheil (SimplSam)

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at:

        http://www.apache.org/licenses/LICENSE-2.0

    Conditions require preservation of copyright and license notices.

    You must retain, in the Source form of any Derivative Works that
    You distribute, all copyright, patent, trademark, and attribution
    notices from the Source form of the Work, excluding those notices
    that do not pertain to any part of the Derivative Works.

	You can:
		Use   - use/reuse freely, even commercially
		Adapt - remix, transform, and build upon for any purpose
		Share - redistribute the material in any medium or format

	Adapt / Share under the following terms:
		Attribution - You must give appropriate credit, provide a link to
        the Apache 2.0 license, and	indicate if changes were made. You may
        do so in any reasonable manner, but not in any way that suggests
        the licensor endorses you or your use.

    Licensed works, modifications and larger works may be distributed
    under different License terms and without source code.

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

    The Developer Sam Cogheil / SimplSam will not be liable for any direct,
    indirect or consequential loss of actual or anticipated - data, revenue,
    profits, business, trade or goodwill that is suffered as a result of the
    use of the software provided.

]]--

--[[
    ***** SPECIAL THANKS to:
	*    Stan (and team) @ MOHO Scripting -- https://mohoscripting.com
	*    The friendly faces @ Lost Marble / Moho Forum -- https://www.lostmarble.com/forum
]]

SS_Ch_VisemesImport = {}
local SS_Ch_VisemesImportDialog = {}

function SS_Ch_VisemesImport:Name()
	return "SS Import Ch Visemes keys"
end

function SS_Ch_VisemesImport:Version()
	return "1.0 #520124"
end

function SS_Ch_VisemesImport:UILabel()
	return "Import Ch Visemes keys"
end

function SS_Ch_VisemesImport:Description()
	return "Import Ch Visemes keydata"
end

function SS_Ch_VisemesImport:Creator()
	return "Sam Cogheil (SimplSam)"
end

function SS_Ch_VisemesImport:IsRelevant(moho)
    return (moho.layer:LayerType() == MOHO.LT_SWITCH)
end

SS_Ch_VisemesImport.clipData = {}
SS_Ch_VisemesImport.aeHeader = "Adobe After Effects 8.0 Keyframe Data"
SS_Ch_VisemesImport.aeFooter = "End of Keyframe Data"
SS_Ch_VisemesImport.visemes  = {"Neutral", "Aa", "D", "Ee", "F", "L", "M", "Oh", "R", "S", "Uh", "W-Oo"}
SS_Ch_VisemesImport.verbose  = true

function SS_Ch_VisemesImport:Run(moho)
    local mohodoc = moho.document
    self.clipData = {}
    if (self:LoadText(moho:ClipboardText())) then
        mohodoc:PrepUndo(moho.layer, true)
        mohodoc:SetDirty()
        self:ApplyKeys(moho)
    end
end

function SS_Ch_VisemesImport:split(s, sep)
    local fields = {}
    s:gsub( string.format("([^%s]+)", sep), function(c) fields[#fields+1] = c end )
    return fields
end

function SS_Ch_VisemesImport.dprint(...)
    if (SS_Ch_VisemesImport.verbose) then
        print("[SS Ch Visemes Import] ", table.concat({...}, " "))
    end
end


-- Load Text
function SS_Ch_VisemesImport:LoadText(clipboard)
    local clipText, preText = "", "Check Clipboard - "
    local iLine = 0
    local line, token, lead, value, trail, header, subhead, fieldc, fheads, fdatas

    if (clipboard) then
        if (select(3, string.find(clipboard, "^%s*([%S ]+)%s")) == self.aeHeader) then
            if (select(3, string.find(clipboard, "%s+([%S ]+)%s*$")) == self.aeFooter) then
                clipText = clipboard:gsub("\r","") -- remove CR's
            else
                self.dprint(preText .. "Missing Footer: '", self.aeFooter, "'"); return false
            end
        else
            self.dprint(preText .. "Missing Header: '", self.aeHeader, "'"); return false
        end
    else
        self.dprint(preText .. "Clipboard Empty"); return false
    end
    local clipLines = self:split(clipText, "\n")

    local function GetLine()
        value, trail = "", ""
        repeat
            iLine = iLine + 1
            line = clipLines[iLine]
            line = line and string.gsub(string.gsub(line, "^[ ]*", ""), "[ \n]*$", "") or nil --< trim
        until not line or (line ~= "" and string.sub(line, 1, 1) ~= "#")
        _,_, lead, token, value, trail = string.find(line or "", "(\t?)([^\t\n]+)\t?([^\t\n]*)\t?([^\t\n]*)")
        token = token or ""
    end

    -- burn 1st line (header)
    GetLine()
    -- Doc properties (not used)
    GetLine()
    while (lead == '\t') do
        self.clipData[token] = value
        GetLine()
    end

    -- Keyframe data
    while (token ~= self.aeFooter) and (value ~= nil) do
        if (lead ~= '\t') then -- header
            header, subhead = token, value --< Field heads (i.e. [Frame][seconds])
            self.clipData[header] = self.clipData[header] or {}
            GetLine()
            fheads = self:split(line, "\t")
            fieldc = #fheads
        else
            fdatas = self:split(line, "\t")
            if (fieldc >= #fdatas) then
                local tmpTbl = {}
                for i = 1, fieldc do
                    if (fieldc == #fdatas) then
                        tmpTbl[fheads[i]] = fdatas[i] or 0
                    else -- faux frame 0
                        tmpTbl[fheads[i]] = fdatas[i-1] or 0
                    end
                end
                table.insert(self.clipData[header], tmpTbl)
            else
                -- unexpected #data fields
                self.dprint("head/data #fields mismatch [#".. fieldc .. " vs '" .. line:sub(2):gsub("\t","; ") .."'] @ " .. header)
            end
        end
        GetLine()
    end
    return true
end


-- Apply K<eys
function SS_Ch_VisemesImport:ApplyKeys(moho)
    local switchLayer = moho:LayerAsSwitch(moho.layer)
    local animChannel = switchLayer
    local defaultVis = self.visemes[1]
    local property = "Time Remap"
    local field = "seconds"
    local when, valS, valN
    if self.clipData[property] then
        for idata, data in ipairs(self.clipData[property]) do
            when = LM.Round(data["Frame"] +1)
            valS = data[field] +1
            valN = self.visemes[valS] or defaultVis
            animChannel:SetValue(when, valN)
        end
        animChannel:SetValue(0, defaultVis)
    end
end