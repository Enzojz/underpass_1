-- local dump = require "luadump"
local pipe = require "entry/pipe"
local func = require "entry/func"
local coor = require "entry/coor"

local state = {
    warningShaderMod = false,
    entries = {},
    linkEntries = false
}

local cov = function(m)
    return func.seqMap({0, 3}, function(r)
        return func.seqMap({1, 4}, function(c)
            return m[r * 4 + c]
        end)
    end)
end

local pure = function(pa)
    local params = {}
    for key, value in pairs(pa) do
        if (key ~= "seed") then
            params[key] = value
        end
    end
    return params
end

local script = {
    save = function() return state end,
    load = function(data)
        if data then
            state.entries = {}
            for i = 1, #data.entries do
                state.entries[i] = data.entries[i]
            end
        end
    end,
    handleEvent = function(src, id, name, param)
        if (id == "__underpassEvent__") then
            if (name == "remove") then
                state.entries = func.filter(state.entries, pipe.contains(param, e))
            elseif (name == "new") then
                state.entries[#state.entries + 1] = param.id
            elseif (name == "construction") then
                local entries = pipe.new * state.entries
                    * pipe.map(game.interface.getEntity)
                    * pipe.filter(pipe.noop())
                if (#entries > 1) then
                    local ref = entries[1]
                    local vecRef, rotRef, _ = coor.decomposite(ref.transf)
                    local iRot = coor.inv(cov(rotRef))
                    local _ = entries * pipe.range(2, #entries) * pipe.map(pipe.select("id")) * pipe.forEach(game.interface.bulldoze)
                    local newId = game.interface.upgradeConstruction(
                        ref.id,
                        "street/underpass_entry.con",
                        func.with(
                            pure(ref.params),
                            {
                                modules = func.map(entries,
                                    function(entry)
                                        local vec, rot, _ = coor.decomposite(entry.transf)
                                        return {
                                            metadata = {entry = true},
                                            name = "street/underpass_entry.module",
                                            variant = 0,
                                            transf = iRot * rot * coor.trans((vec - vecRef) .. iRot),
                                        }
                                    end)
                            }))
                    if newId then state.entries = {} end
                end
            end
        end
    end,
    guiHandleEvent = function(id, name, param)
        if name == "builder.apply" then
            local toRemove = param.proposal.toRemove
            local toAdd = param.proposal.toAdd
            if toRemove then
                local params = {}
                for i = 1, #toRemove do if func.contains(state.entries) then params[#params + 1] = toRemove[i] end end
                if (#params > 0) then
                    if state.entries < 2 then
                        if state.linkEntries then
                            state.linkEntries:close()
                        end
                    end
                    game.interface.sendScriptEvent("__underpassEvent__", "remove", params)
                end
            end
            if toAdd and #toAdd > 0 then
                for i = 1, #toAdd do
                    local con = toAdd[i]
                    if (con.fileName == [[street/underpass_entry.con]]) then
                        if (not game.config.shaderMod) then
                            if not state.warningShaderMod then
                                local textview = gui.textView_create(
                                    "underpass.warning.textView",
                                    _([["Underpass" mod requires "Shader Enhancement" mod, you will see strange texture without this mod.]]),
                                    400
                                )
                                local layout = gui.boxLayout_create("underpass.warning.boxLayout", "VERTICAL")
                                layout:addItem(textview)
                                state.warningShaderMod = gui.window_create(
                                    "underpass.warning.window",
                                    _("Warning"),
                                    layout
                                )
                                state.warningShaderMod:onClose(function()state.warningShaderMod = false end)
                            end
                            
                            local mainView = game.gui.getContentRect("mainView")
                            local mainMenuHeight = game.gui.getContentRect("mainMenuTopBar")[4] + game.gui.getContentRect("mainMenuBottomBar")[4]
                            local size = game.gui.calcMinimumSize(state.warningShaderMod.id)
                            local y = mainView[4] - size[2] - mainMenuHeight
                            local x = mainView[3] - size[1]
                            
                            game.gui.window_setPosition(state.warningShaderMod.id, x * 0.5, y * 0.5)
                            game.gui.setHighlighted(state.warningShaderMod.id, true)
                        end
                        if #state.entries > 0 then
                            if not state.linkEntries then
                                local finishIcon = gui.imageView_create("underpass.link.icon", "ui/construction/street/underpass_entry_op.tga")
                                local finishButton = gui.button_create("underpass.link.button", finishIcon)
                                local vLayout = gui.boxLayout_create("underpass.link.vLayout", "VERTICAL")
                                vLayout:addItem(finishButton)
                                state.linkEntries = gui.window_create("underpass.link.window", _("Underpass\nConstruction"), vLayout)
                                state.linkEntries:onClose(function()state.linkEntries = false end)
                                
                                finishButton:onClick(function()
                                    state.linkEntries:close()
                                    game.interface.sendScriptEvent("__underpassEvent__", "construction", {})
                                end)
                                game.gui.window_setPosition(state.linkEntries.id, 200, 200)
                            end
                        end
                        game.interface.sendScriptEvent("__underpassEvent__", "new", {id = param.result[1]})
                    end
                end
            end
        end
    end
}

function data()
    return script
end
