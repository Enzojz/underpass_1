local pipe = require "entry/pipe"
local func = require "entry/func"
local coor = require "entry/coor"
local dump = require "luadump"

local state = {
    warningShaderMod = false,
    
    items = {},
    addedItems = {},
    checkedItems = {},

    stations = {},
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
        if (key ~= "seed" and key ~= "modules") then
            params[key] = value
        end
    end
    return params
end

local addEntry = function(id)
    if (state.linkEntries) then
        local entity = game.interface.getEntity(id)
        if (entity) then
            local isEntry = entity.fileName == "street/underpass_entry.con"
            local isStation = entity.fileName == "station/rail/mus.con"
            if (isEntry or isStation) then
                local layoutId = "underpass.link." .. tostring(id) .. "."
                local hLayout = gui.boxLayout_create(layoutId .. "layout", "HORIZONTAL")
                local label = gui.textView_create(layoutId .. "label", isEntry and tostring(id) or entity.name, 150)
                local icon = gui.imageView_create(layoutId .. "icon", 
                    isEntry and
                    "ui/construction/street/underpass_entry_small.tga" or 
                    "ui/construction/station/rail/mus_small.tga"
                )
                local locateView = gui.imageView_create(layoutId .. "locate.icon", "ui/design/window-content/locate_small@2x.tga")
                local locateBtn = gui.button_create(layoutId .. "locate", locateView)
                local checkboxView = gui.imageView_create(layoutId .. "checkbox.icon",
                    func.contains(state.checkedItems, id) 
                    and "ui/design/components/checkbox_small_valid@2x.tga" 
                    or "ui/design/components/checkbox_small_invalid@2x.tga"
                )
                local checkboxBtn = gui.button_create(layoutId .. "checkbox", checkboxView)
                hLayout:addItem(locateBtn)
                hLayout:addItem(checkboxBtn)
                hLayout:addItem(icon)
                hLayout:addItem(label)
                
                locateBtn:onClick(function()
                    local pos = entity.position
                    game.gui.setCamera({pos[1], pos[2], pos[3], -4.77, 0.2})
                end)
                
                checkboxBtn:onClick(
                    function()
                        if (func.contains(state.checkedItems, id)) then
                            checkboxView:setImage("ui/design/components/checkbox_small_invalid@2x.tga")
                            game.interface.sendScriptEvent("__underpassEvent__", "uncheck", {id = id})
                        else
                            checkboxView:setImage("ui/design/components/checkbox_small_valid@2x.tga")
                            game.interface.sendScriptEvent("__underpassEvent__", "check", {id = id})
                        end
                    end
                )
                
                local comp = gui.component_create(layoutId .. "comp", "")
                comp:setLayout(hLayout)
                state.linkEntries.layout:addItem(comp)
                state.addedItems[#state.addedItems + 1] = id
            end
        end
    end
end

local showWindow = function()
    if (not state.linkEntries and #state.items > 0) then
        local finishIcon = gui.imageView_create("underpass.link.icon", "ui/construction/street/underpass_entry_op.tga")
        local finishButton = gui.button_create("underpass.link.button", finishIcon)
        local desc = gui.textView_create("underpass.link.description", "")
        
        local hLayout = gui.boxLayout_create("underpass.link.hLayout", "HORIZONTAL")

        hLayout:addItem(finishButton)
        hLayout:addItem(desc)
        local comp = gui.component_create("underpass.link.hComp", "")
        comp:setLayout(hLayout)

        local vLayout = gui.boxLayout_create("underpass.link.vLayout", "VERTICAL")
        vLayout:addItem(comp)

        state.linkEntries = gui.window_create("underpass.link.window", _("UNDERPASS_CON"), vLayout)
        state.linkEntries.desc = desc
        state.linkEntries.button = finishButton
        state.linkEntries.button.icon = finishIcon
        state.linkEntries.layout = vLayout
        
        state.linkEntries:onClose(function()
            state.linkEntries = false
            state.addedItems = {}
        end)
        
        finishButton:onClick(function()
            state.linkEntries:close()
            game.interface.sendScriptEvent("__underpassEvent__", "construction", {})
        end)
        game.gui.window_setPosition(state.linkEntries.id, 200, 200)
    end
end

local checkFn = function()
    if (state.linkEntries) then
        local stations = func.filter(state.checkedItems, function(e) return func.contains(state.stations, e) end)
        local entries = func.filter(state.checkedItems, function(e) return func.contains(state.entries, e) end)
        if (#stations > 0) then
            if (#entries > 0) then
                game.gui.setEnabled(state.linkEntries.button.id, true)
                state.linkEntries.desc:setText(_("STATION_CAN_FINALIZE"), 200)
            else
                game.gui.setEnabled(state.linkEntries.button.id, false)
                state.linkEntries.desc:setText(_("STATION_NEED_ENTRY"), 200)
            end
            state.linkEntries.button.icon:setImage("ui/construction/station/rail/mus_op.tga")
            state.linkEntries:setTitle(_("STATION_CON"))
        elseif (#stations == 0) then
            if (#entries > 1) then
                game.gui.setEnabled(state.linkEntries.button.id, true)
                state.linkEntries.desc:setText(_("UNDERPASS_CAN_FINALIZE"), 200)
            else
                game.gui.setEnabled(state.linkEntries.button.id, false)
                state.linkEntries.desc:setText(_("UNDERPASS_NEED_ENTRY"), 200)
            end
            state.linkEntries.button.icon:setImage("ui/construction/street/underpass_entry_op.tga")
            state.linkEntries:setTitle(_("UNDERPASS_CON"))
        else
            game.gui.setEnabled(state.linkEntries.button.id, false)
        end
    end
end

local closeWindow = function()
    if (state.linkEntries) then
        local w = state.linkEntries
        state.linkEntries = false
        w:close()
    end
end

local shaderWarning = function()
    if (not game.config.shaderMod) then
        if not state.warningShaderMod then
            local textview = gui.textView_create(
                "underpass.warning.textView",
                _([["SHADER_WARNING"]]),
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
end

local buildStation = function(entries, stations)
    local ref = stations[1]
    local vecRef, rotRef, _ = coor.decomposite(ref.transf)
    local iRot = coor.inv(cov(rotRef))
    local _ = stations * pipe.range(2, #stations) * pipe.map(pipe.select("id")) * pipe.forEach(game.interface.bulldoze)
    -- local _ = entries * pipe.map(pipe.select("id")) * pipe.forEach(game.interface.bulldoze)
    local modules = {}
    for i = 1, #stations do
        local e = stations[i]
        local vec, rot, _ = coor.decomposite(e.transf)
        local params =  pure(e.params)
        for slotId, m in pairs(e.params.modules) do
            modules[slotId + (i - 1) * 10000] = func.with(m, 
            {
                params = params,
                transf = iRot * rot * coor.trans((vec - vecRef) .. iRot),
            })
        end
    end
    local newId = game.interface.upgradeConstruction(
        ref.id,
        "station/rail/mus.con",
        func.with(
            pure(ref.params),
            {
                modules = modules,
                isFinalized = 1
            })
    )
    if newId then
        state.items = func.filter(state.items, function(e) return not func.contains(state.checkedItems, e) end)
        state.checkedItems = {}
        state.stations = func.filter(state.stations, function(e) return func.contains(state.items, e) end)
        state.entries = func.filter(state.entries, function(e) return func.contains(state.items, e) end)
        closeWindow()
    end
end

local buildUnderpass = function(entries)
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
                            params = pure(entry.params)
                        }
                    end)
            }))
    if newId then
        state.items = func.filter(state.items, function(e) return not func.contains(state.checkedItems, e) end)
        state.checkedItems = {}
        closeWindow()
    end
end

local script = {
    save = function() return state end,
    load = function(data)
        if data then
            if (data.items and #data.items ~= #state.items) then
                state.items = {}
                for i = 1, #data.items do state.items[i] = data.items[i] end
            end
            if (data.checkedItems and #data.checkedItems ~= #state.checkedItems) then
                state.checkedItems = {}
                for i = 1, #data.checkedItems do state.checkedItems[i] = data.checkedItems[i] end
            end
            if (data.stations and #data.stations ~= #state.stations) then
                state.stations = {}
                for i = 1, #data.stations do state.stations[i] = data.stations[i] end
            end
            if (data.entries and #data.entries ~= #state.entries) then
                state.entries = {}
                for i = 1, #data.entries do state.entries[i] = data.entries[i] end
            end
        end
    end,
    guiUpdate = function()
        if (#state.items < 1) then
            closeWindow()
            state.addedItems = {}
        elseif (#state.items > 0) then
            showWindow()
            if (#state.addedItems < #state.items) then
                for i = #state.addedItems + 1, #state.items do
                    addEntry(state.items[i])
                end
            elseif (#state.addedItems > #state.items) then
                closeWindow()
            end
            checkFn()
        end
    end,
    handleEvent = function(src, id, name, param)
        if (id == "__underpassEvent__") then
            if (name == "remove") then
                state.items = func.filter(state.items, function(e) return not func.contains(param, e) end)
                state.checkedItems = func.filter(state.checkedItems, function(e) return not func.contains(param, e) end)
                state.entries = func.filter(state.entries, function(e) return not func.contains(param, e) end)
                state.stations = func.filter(state.stations, function(e) return not func.contains(param, e) end)
            elseif (name == "new") then
                state.items[#state.items + 1] = param.id
                state.checkedItems[#state.checkedItems + 1] = param.id
                if (param.isEntry) then state.entries[#state.entries + 1] = param.id
                elseif (param.isStation) then state.stations[#state.stations + 1] = param.id end
            elseif (name == "uncheck") then
                state.checkedItems = func.filter(state.checkedItems, function(e) return e ~= param.id end)
            elseif (name == "check") then
                if (not func.contains(state.checkedItems, param.id)) then
                    state.checkedItems[#state.checkedItems + 1] = param.id
                end
            elseif (name == "construction") then
                local items = pipe.new * state.checkedItems
                    * pipe.map(game.interface.getEntity)
                    * pipe.filter(pipe.noop())
                local entries = pipe.new * state.checkedItems * pipe.filter(function(e) return func.contains(state.entries, e) end)* pipe.map(game.interface.getEntity) * pipe.filter(pipe.noop())
                local stations = pipe.new * state.checkedItems * pipe.filter(function(e) return func.contains(state.stations, e) end)* pipe.map(game.interface.getEntity) * pipe.filter(pipe.noop())
                
                if (#stations == 0 and #entries > 1) then
                    buildUnderpass(entries)
                elseif (#stations > 0 and #entries > 0) then
                    buildStation(entries, stations)
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
                for _, r in ipairs(toRemove) do if func.contains(state.items, r) then params[#params + 1] = r end end
                if (#params > 0) then
                    game.interface.sendScriptEvent("__underpassEvent__", "remove", params)
                end
            end
            if toAdd and #toAdd > 0 then
                for i = 1, #toAdd do
                    local con = toAdd[i]
                    if (con.fileName == [[street/underpass_entry.con]]) then
                        shaderWarning()
                        game.interface.sendScriptEvent("__underpassEvent__", "new", {id = param.result[1], isEntry = true})
                    end
                end
            end
        end
    end
}

function data()
    return script
end
