local descEN = [[This mod helps you create underpass of any topology freely.
Usage:
1. Find entries in Road Construction menu
2. Place at least two entres over the map
3. Click on the finish button that apperas on the screen
4. Finished!

* This mod requires "Shader enhancement" mod to render textures correctly.
]]

local descCN = [[本模可以自由建造人行地道
使用方法:
1. 在道路建设菜单中找到人行地道入口选项
2. 在地图上摆放至少两个入口
3. 点击屏幕上出现的完成按钮
4. 完成建造!

* 本模组需要“着色器增强”模组方可正确渲染
]]


function data()
    return {
        en = {
            ["name"] = "Underpass",
            ["desc"] = descEN,
        },
        zh_CN = {
            ["name"] = "人行地道",
            ["desc"] = descCN,
            ["Wall"] = "墙面",
            ["Tiles 1"] = "瓷砖1",
            ["Tiles 2"] = "瓷砖2",
            ["Floor Style"] = "地面",
            ["Marble 1"] = "大理石1",
            ["Marble 2"] = "大理石2",
            ["Honeycomb"] = "蜂窝",
            ["Concrete"] = "水泥砖",
            ["Asphalt"] = "沥青",
            ["Style"] = "风格",
            ["Glass"] = "玻璃",
            ["Normal"] = "栏杆",
            ["Concrete"] = "水泥",
            ["Width (m)"] = "宽度(米)",
            ["Underpass Entry"] = "地道入口",
            ["An underpass entry"] = "通往人行地道的入口.",
            ["\"Underpass\" mod requires \"Shader Enhancement\" mod, you will see strange texture without this mod."] = [["人行地道"模组需要"着色器增强"模组的支持方可运行，否则您将看到不正常的贴图]],
            ["Warning"] = "警告",
            ["Underpass\nConstruction"] = "建造人行地道"
        }
    }
end
