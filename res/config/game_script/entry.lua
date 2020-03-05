local pipe = require "entry/pipe"
local func = require "entry/func"
local coor = require "entry/coor"

local state = {
    warningShaderMod = false,
    
    items = {},
    addedItems = {},
    checkedItems = {},
    
    stations = {},
    entries = {},
    
    linkEntries = false,
    built = {},
    builtLevelCount = {}
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

local decomp = function(params)
    local group = {}
    for slotId, m in pairs(params.modules) do
        local groupId = (slotId - slotId % 10000) / 10000 % 10
        if not group[groupId] then
            group[groupId] = {
                modules = {},
                params = m.params,
                transf = m.transf
            }
        end
        group[groupId].modules[slotId - groupId * 10000] = m
    end
    return group
end

local addEntry = function(id)
    if (state.linkEntries) then
        local entity = game.interface.getEntity(id)
        if (entity) then
            local isEntry = entity.fileName == "street/underpass_entry.con"
            local isStation = entity.fileName == "station/rail/mus.con"
            local isBuilt = isStation and entity.params and entity.params.isFinalized == 1
            if (isEntry or isStation) then
                local layoutId = "underpass.link." .. tostring(id) .. "."
                local hLayout = gui.boxLayout_create(layoutId .. "layout", "HORIZONTAL")
                local label = gui.textView_create(layoutId .. "label", isEntry and tostring(id) or entity.name .. (isBuilt and _("BUILT") or ""), 300)
                local icon = gui.imageView_create(layoutId .. "icon",
                    isEntry and
                    "ui/construction/street/underpass_entry_small.tga" or
                    "ui/construction/station/rail/mus_small.tga"
                )
                local locateView = gui.imageView_create(layoutId .. "locate.icon", "ui/design/window-content/locate_small.tga")
                local locateBtn = gui.button_create(layoutId .. "locate", locateView)
                local checkboxView = gui.imageView_create(layoutId .. "checkbox.icon",
                    func.contains(state.checkedItems, id)
                    and "ui/design/components/checkbox_small_valid.tga"
                    or "ui/design/components/checkbox_small_invalid.tga"
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
                            checkboxView:setImage("ui/design/components/checkbox_small_invalid.tga")
                            game.interface.sendScriptEvent("__underpassEvent__", "uncheck", {id = id})
                        else
                            checkboxView:setImage("ui/design/components/checkbox_small_valid.tga")
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
            if (state.linkEntries) then
                state.linkEntries:close()
                game.interface.sendScriptEvent("__underpassEvent__", "construction", {})
            end
        end)
        game.gui.window_setPosition(state.linkEntries.id, 200, 200)
    end
end

local checkFn = function()
    if (state.linkEntries) then
        local stations = func.filter(state.checkedItems, function(e) return func.contains(state.stations, e) end)
        local entries = func.filter(state.checkedItems, function(e) return func.contains(state.entries, e) end)
        local built = func.filter(state.checkedItems, function(e) return func.contains(state.built, e) end)

        if (#stations > 0) then
            if (#stations - #built + func.fold(built, 0, function(t, b) return (state.builtLevelCount[b] or 99) + t end) > 8) then
                game.gui.setEnabled(state.linkEntries.button.id, false)
                state.linkEntries.desc:setText(_("STATION_MAX_LIMIT"), 200)
            elseif (#entries > 0 or (#built > 0 and #stations > 1)) then
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

local buildStation = function(entries, stations, built)
    local ref = built and #built > 0 and built[1] or stations[1]
    local vecRef, rotRef, _ = coor.decomposite(ref.transf)
    local iRot = coor.inv(cov(rotRef))
    
    local groups = {}
    local entry = {}
    
    if (built and #built > 0) then
        for _, b in ipairs(built) do
            local group = decomp(b.params)
            for gId, g in pairs(group) do
                if (gId == 9) then
                    for _, m in ipairs(g.modules) do
                        m.transf = coor.I() * m.transf * b.transf
                        table.insert(entry, m)
                    end
                else
                    g.transf = coor.I() * g.transf * b.transf
                    table.insert(groups, g)
                end
            end
        end
    end
    
    for _, e in ipairs(stations) do
        table.insert(groups, {
            modules = e.params.modules,
            params = func.with(pure(e.params), {isFinalized = 1}),
            transf = e.transf
        })
    end
    
    for _, e in ipairs(entries) do
        local g = {
            metadata = {entry = true},
            name = "street/underpass_entry.module",
            variant = 0,
            transf = e.transf,
            params = func.with(pure(e.params), {isStation = true})
        }
        table.insert(entry, g)
    end
    
    local modules = {}
    for i, g in ipairs(groups) do
        local vec, rot, _ = coor.decomposite(g.transf)
        local transf = iRot * rot * coor.trans((vec - vecRef) .. iRot)
        for slotId, m in pairs(g.modules) do
            m.params = g.params
            m.transf = transf
            modules[slotId + i * 10000] = m
        end
    end
    
    for i, e in ipairs(entry) do
        local vec, rot, _ = coor.decomposite(e.transf)
        e.transf = iRot * rot * coor.trans((vec - vecRef) .. iRot)
        modules[90000 + i] = e
    end
    
    if (built and #built > 1) then local _ = built * pipe.range(2, #built) * pipe.map(pipe.select("id")) * pipe.forEach(game.interface.bulldoze) end
    local _ = stations * (built and pipe.noop() or pipe.range(2, #stations)) * pipe.map(pipe.select("id")) * pipe.forEach(game.interface.bulldoze)
    local _ = entries * pipe.map(pipe.select("id")) * pipe.forEach(game.interface.bulldoze)
    
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
        if (built and #built > 1) then
            for _, b in ipairs(built) do
                state.builtLevelCount[b.id] = nil
            end
        end
        state.builtLevelCount[newId] = #groups
        state.items = func.filter(state.items, function(e) return not func.contains(state.checkedItems, e) end)
        state.checkedItems = {}
        state.stations = func.filter(state.stations, function(e) return func.contains(state.items, e) end)
        state.entries = func.filter(state.entries, function(e) return func.contains(state.items, e) end)
        state.built = func.filter(state.built, function(e) return func.contains(state.items, e) end)
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
            state.builtLevelCount = data.builtLevelCount or {}
            state.built = data.built or {}
        end
    end,
    guiUpdate = function()
        if (#state.items < 1) then
            closeWindow()
            state.addedItems = {}
        elseif (#state.items - #state.built > 0 or #state.built > 1) then
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
                state.built = func.filter(state.built, function(e) return not func.contains(param, e) end)
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
                local entries = pipe.new
                    * state.checkedItems
                    * pipe.filter(function(e) return func.contains(state.entries, e) end)
                    * pipe.map(game.interface.getEntity)
                    * pipe.filter(pipe.noop())
                
                local built = pipe.new
                    * state.checkedItems
                    * pipe.filter(function(e) return func.contains(state.built, e) end)
                    * pipe.map(game.interface.getEntity)
                    * pipe.filter(pipe.noop())
                
                local stations = pipe.new
                    * state.checkedItems
                    * pipe.filter(function(e) return func.contains(state.stations, e) and not func.contains(state.built, e) end)
                    * pipe.map(game.interface.getEntity)
                    * pipe.filter(pipe.noop())
                
                if (#built > 0 and (#entries + #stations) > 0) then
                    buildStation(entries, stations, built)
                elseif (#built > 1) then
                    buildStation(entries, stations, built)
                elseif (#stations == 0 and #entries > 1) then
                    buildUnderpass(entries)
                elseif (#stations > 0 and #entries > 0) then
                    buildStation(entries, stations)
                end
            elseif (name == "select") then
                if not func.contains(state.built, param.id) then
                    state.items[#state.items + 1] = param.id
                    state.stations[#state.stations + 1] = param.id
                    state.built[#state.built + 1] = param.id
                    state.builtLevelCount[param.id] = param.nbGroup
                end
            end
        end
    end,
    guiHandleEvent = function(id, name, param)
        if (name == "select") then
            local entity = game.interface.getEntity(param)
            if (entity.type == "STATION_GROUP") then
                local lastVisited = false
                local nbGroup = 0
                local cons = game.interface.getEntities({pos = entity.pos, radius = 9999}, {type = "CONSTRUCTION", includeData = true, fileName = "station/rail/mus.con"})
                for _, s in ipairs(entity.stations) do
                    for _, c in pairs(cons) do
                        if c.params and c.params.isFinalized == 1 and func.contains(c.stations, s) then
                            lastVisited = c.id
                            nbGroup = #(func.filter(func.keys(decomp(c.params)), function(g) return g < 9 end))
                        end
                    end
                end
                if lastVisited then
                    game.interface.sendScriptEvent("__underpassEvent__", "select", {id = lastVisited, nbGroup = nbGroup})
                end
            end
        end
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
