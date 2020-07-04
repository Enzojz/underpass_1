local pipe = require "entry/pipe"
local func = require "entry/func"
local coor = require "entry/coor"
-- local dump = require "luadump"
local state = {
    warningShaderMod = false,
    
    items = {},
    addedItems = {},
    checkedItems = {},
    
    stations = {},
    entries = {},
    
    windows = {
        window = false,
        desc = false,
        icon = false,
        button = false,
        list = false
    },
    built = {},
    builtLevelCount = {},
    
    fn = {}
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

local removeEntry = function(id)
    if (state.windows.window) then
        local comp = api.gui.util.getById(("underpass.entities.%d"):format(id))
        if comp then
            state.windows.list:removeItem(comp)
            comp:destroy()
        end
        state.addedItems = func.filter(state.addedItems, function(e) return e ~= id end)
        state.checkedItems = func.filter(state.checkedItems, function(e) return e ~= id end)
    end
end

local addEntry = function(id)
    if (state.windows.window) then
        local entity = game.interface.getEntity(id)
        if (entity) then
            local isEntry = func.contains(state.entries, id)
            local isStation = func.contains(state.stations, id)
            local isBuilt = isStation and entity.params and entity.params.isFinalized == 1
            if (isEntry or isStation) then
                local check = api.gui.comp.CheckBox.new(
                    "",
                    "ui/design/components/checkbox_invalid.tga",
                    "ui/design/components/checkbox_valid.tga"
                )
                local lable = api.gui.comp.TextView.new(isEntry and tostring(id) or entity.name .. (isBuilt and _("BUILT") or ""))
                
                local icon = api.gui.comp.ImageView.new(
                    isEntry and
                    "ui/construction/street/underpass_entry_small.tga" or
                    "ui/construction/station/rail/mus_small.tga"
                )
                local locateView = api.gui.comp.ImageView.new("ui/design/window-content/locate_small.tga")
                local locateBtn = api.gui.comp.Button.new(locateView, true)
                
                check:setGravity(0, 0.5)
                locateBtn:setGravity(0, 0.5)
                icon:setGravity(0, 0.5)
                lable:setGravity(-1, 0.5)
                
                local layout = api.gui.layout.BoxLayout.new("HORIZONTAL")
                local comp = api.gui.comp.Component.new("")
                comp:setLayout(layout)
                
                check:setId(("underpass.check.%d"):format(id))
                comp:setId(("underpass.entities.%d"):format(id))
                
                layout:addItem(locateBtn)
                layout:addItem(check)
                layout:addItem(icon)
                layout:addItem(lable)
                
                locateBtn:onClick(function()
                    local pos = entity.position
                    game.gui.setCamera({pos[1], pos[2], pos[3], -4.77, 0.2})
                end)
                
                check:onToggle(
                    function()
                        if (func.contains(state.checkedItems, id)) then
                            table.insert(state.fn, function()game.interface.sendScriptEvent("__underpassEvent__", "uncheck", {id = id}) end)
                        else
                            table.insert(state.fn, function()game.interface.sendScriptEvent("__underpassEvent__", "check", {id = id}) end)
                        end
                    end
                )
                state.windows.list:addItem(comp)
                state.addedItems[#state.addedItems + 1] = id
            end
        end
    end
end

local createWindow = function()
    if (not state.windows.window and #state.items > 0) then
        local finishIcon = api.gui.comp.ImageView.new("ui/construction/street/underpass_entry_op.tga")
        local finishButton = api.gui.comp.Button.new(finishIcon, true)
        local desc = api.gui.comp.TextView.new("")
        local hLayout = api.gui.layout.BoxLayout.new("HORIZONTAL")
        
        hLayout:addItem(finishButton)
        hLayout:addItem(desc)
        
        local hcomp = api.gui.comp.Component.new("")
        hcomp:setLayout(hLayout)
        
        local vLayout = api.gui.layout.BoxLayout.new("VERTICAL")
        local wcomp = api.gui.comp.Component.new("")
        wcomp:setLayout(vLayout)
        
        state.windows.window = api.gui.comp.Window.new("", wcomp)
        state.windows.window:setId("underpass.window")
        
        vLayout:addItem(hcomp)
        
        state.windows.window:onClose(function()
            state.windows.window:setVisible(false, false)
            table.insert(state.fn, function()
                game.interface.sendScriptEvent("__underpassEvent__", "window.close", {})
            end)
        end)
        
        finishButton:onClick(function()
            if (state.windows.window) then
                table.insert(state.fn, function()
                    game.interface.sendScriptEvent("__underpassEvent__", "construction", {})
                end)
            end
        end)
        
        state.windows.button = finishButton
        state.windows.icon = finishIcon
        state.windows.desc = desc
        state.windows.list = vLayout
        
        game.gui.window_setPosition("underpass.window", 200, 200)
    end
end

local showWindow = function()
    if state.windows.window and #state.items > 0 then
        state.windows.window:setVisible(true, false)
    elseif not state.windows.window and #state.items > 0 then
        createWindow()
    end
end

local checkFn = function()
    if (state.windows.window) then
        local stations = func.filter(state.checkedItems, function(e) return func.contains(state.stations, e) end)
        local entries = func.filter(state.checkedItems, function(e) return func.contains(state.entries, e) end)
        local built = func.filter(state.checkedItems, function(e) return func.contains(state.built, e) end)
        
        if (#stations > 0) then
            if (#stations - #built + func.fold(built, 0, function(t, b) return (state.builtLevelCount[b] or 99) + t end) > 8) then
                state.windows.button:setEnabled(false)
                state.windows.desc:setText(_("STATION_MAX_LIMIT"))
            elseif (#entries > 0 or (#built > 0 and #stations > 1)) then
                state.windows.button:setEnabled(true)
                state.windows.desc:setText(_("STATION_CAN_FINALIZE"))
            else
                state.windows.button:setEnabled(false)
                state.windows.desc:setText(_("STATION_NEED_ENTRY"))
            end
            state.windows.icon:setImage("ui/construction/station/rail/mus_op.tga", false)
            state.windows.window:setTitle(_("STATION_CON"))
        elseif (#stations == 0) then
            if (#entries > 1) then
                state.windows.button:setEnabled(true)
                state.windows.desc:setText(_("UNDERPASS_CAN_FINALIZE"))
            else
                state.windows.button:setEnabled(false)
                state.windows.desc:setText(_("UNDERPASS_NEED_ENTRY"))
            end
            state.windows.icon:setImage("ui/construction/street/underpass_entry_op.tga", false)
            state.windows.window:setTitle(_("UNDERPASS_CON"))
        else
            state.windows.button:setEnabled(false)
        end
        
        if #state.items == 0 then
            state.windows.window:setVisible(false, false)
        end
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
            name = e.params.modules[1].name,
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
    end
end

local buildUnderpass = function(entries)
    local ref = entries[1]
    local vecRef, rotRef, _ = coor.decomposite(ref.transf)
    local iRot = coor.inv(cov(rotRef))
    local _ = entries * pipe.range(2, #entries) * pipe.map(pipe.select("id")) * pipe.forEach(game.interface.bulldoze)
    local newId = game.interface.upgradeConstruction(
        ref.id,
        ref.fileName,
        func.with(
            pure(ref.params),
            {
                modules = func.map(entries,
                    function(entry)
                        local vec, rot, _ = coor.decomposite(entry.transf)
                        return {
                            metadata = {entry = true},
                            name = entry.params.modules[1].name,
                            variant = 0,
                            transf = iRot * rot * coor.trans((vec - vecRef) .. iRot),
                            params = pure(entry.params)
                        }
                    end)
            }))
    if newId then
        state.items = func.filter(state.items, function(e) return not func.contains(state.checkedItems, e) end)
        state.entries = func.filter(state.entries, function(e) return func.contains(state.items, e) end)
        state.checkedItems = {}
    end
end

local script = {
    save = function()
        if not state then state = {} end
        if not state.items then state.items = {} end
        if not state.checkedItems then state.checkedItems = {} end
        if not state.stations then state.stations = {} end
        if not state.entries then state.entries = {} end
        if not state.built then state.built = {} end
        if not state.builtLevelCount then state.builtLevelCount = {} end
        
        return state
    end,
    load = function(data)
        if data then
            state.items = data.items or {}
            state.checkedItems = data.checkedItems or {}
            state.stations = data.stations or {}
            state.entries = data.entries or {}
            state.builtLevelCount = data.builtLevelCount or {}
            state.built = data.built or {}
        end
    end,
    guiUpdate = function()
        for _, f in ipairs(state.fn) do f() end
        state.fn = {}
        
        if #state.addedItems < #state.items then
            showWindow()
        end
        
        if state.windows.window then
            if (#state.addedItems < #state.items) then
                for i = #state.addedItems + 1, #state.items do
                    addEntry(state.items[i])
                end
            elseif (#state.addedItems > #state.items) then
                local remove = func.filter(state.addedItems, function(i) return not func.contains(state.items, i) end)
                for _, id in ipairs(remove) do
                    removeEntry(id)
                end
            else
                local check = {}
                for _, id in ipairs(state.items) do
                    check[id] = false
                end
                for _, id in ipairs(state.checkedItems) do
                    check[id] = true
                end
                for id, c in pairs(check) do
                    local check = api.gui.util.getById(("underpass.check.%d"):format(id))
                    check:setSelected(c, false)
                end
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
                
                entries =
                    entries * pipe.filter(function(e) return e.fileName == "street/underpass_entry.con" end) +
                    entries * pipe.filter(function(e) return e.fileName ~= "street/underpass_entry.con" end)
                
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
            elseif (name == "window.close") then
                state.items = func.filter(state.items, function(i) return not func.contains(state.built, i) or func.contains(state.checkedItems, i) end)
                state.built = func.filter(state.built, function(b) return func.contains(state.checkedItems, b) end)
            end
        end
    end,
    guiHandleEvent = function(id, name, param)
        if id == "mainView" and name == "select" then
            local entity = game.interface.getEntity(param)
            if (entity and entity.type == "CONSTRUCTION" and entity.fileName == "street/underpass_entry.con") then
                if func.contains(state.items, entity.id) then
                    showWindow()
                end
            elseif (entity and entity.type == "STATION_GROUP") then
                local lastVisited = false
                local nbGroup = 0
                local map = api.engine.system.streetConnectorSystem.getStation2ConstructionMap()
                for _, id in ipairs(api.engine.getComponent(param, api.type.ComponentType.STATION_GROUP).stations) do
                    local conId = map[id]
                    if conId then
                        local con = api.engine.getComponent(conId, api.type.ComponentType.CONSTRUCTION)
                        if (con.fileName == "station/rail/mus.con" and con.params.isFinalized and con.params.isFinalized == 1) then
                            lastVisited = conId
                            nbGroup = #(func.filter(func.keys(decomp(con.params)), function(g) return g < 9 end))
                        elseif func.contains(state.items, conId) then
                            showWindow()
                        end
                    end
                end
                
                if lastVisited then
                    if not api.gui.util.getById("mus.config." .. param) then
                        local w = api.gui.util.getById("temp.view.entity_" .. param)
                        local layout = w:getLayout()
                        local subWindow = layout:getItem(1)
                        local subLayout = subWindow:getLayout():getItem(0)
                        local buttonText = api.gui.comp.TextView.new(_("UNDERGROUND_EXTEND"))
                        local buttonImage = api.gui.comp.ImageView.new("ui/icons/game-menu/configure.tga")
                        local buttonLayout = api.gui.layout.BoxLayout.new("HORIZONTAL")
                        local buttonComp = api.gui.comp.Component.new("")
                        buttonLayout:addItem(buttonImage)
                        buttonLayout:addItem(buttonText)
                        buttonComp:setLayout(buttonLayout)
                        local button = api.gui.comp.Button.new(buttonComp, true)
                        buttonText:setName("ConfigureButton::Text")
                        button:setName("ConfigureButton")
                        button:setId("mus.config." .. param)
                        
                        subLayout:addItem(button)

                        button:onClick(function()
                            table.insert(state.fn, function()
                            game.interface.sendScriptEvent("__underpassEvent__", "select", {id = lastVisited, nbGroup = nbGroup})
                            end)
                        end)
                    end
                end
            end
        end
        if name == "builder.apply" then
            local toRemove = param.proposal.toRemove
            local toAdd = param.proposal.toAdd
            if not (toRemove and #toRemove == 1 and toAdd and #toAdd == 1 and toRemove[1] == param.result[1]) then
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
    end
}

function data()
    return script
end
