-- HUD stuff

function edithud()
    if world.enthavesel() ~= 0 then
        return "%(1)s : %(2)s selected" % { world.entget(), world.enthavesel() }
    end
end

-- core binds

input.bind("ESCAPE", function()
    gui.menu_key_click_trigger()
    if not gui.hide("main") then
        gui.show("main")
    end
end)

-- non-edit tabs

local main_id = tgui.push_tab("Main", tgui.BAR_VERTICAL, tgui.BAR_NORMAL, "icon_maps", function()
    gui.vlist(0, function()
        gui.space(0.01, 0.01, function()
            gui.label("Welcome to OctaForge!", 1.5, 0, 0.8, 0)
        end)
        gui.label("You're running OctaForge developer alpha release.", 1, 1, 1, 1,   function() gui.align(-1, 0) end)
        gui.label("Thanks for downloading, we hope you'll like the", 1, 1, 1, 1,     function() gui.align(-1, 0) end)
        gui.label("engine. Start off by browsing the icons on the left", 1, 1, 1, 1, function() gui.align(-1, 0) end)
        gui.label("and on the bottom, or run a map from table below", 1, 1, 1, 1,    function() gui.align(-1, 0) end)
        gui.label("right away!", 1, 1, 1, 1, function() gui.align(-1, 0) end)
        gui.space(0.01, 0.01, function()
            gui.cond(
                function()
                    return world.hasmap()
                end, function()
                    gui.vlist(0, function()
                        gui.label("Map: Running.", 1.2, 0.8, 0, 0)
                        tgui.button("  stop", function() world.map() end)
                        tgui.button("  show output", function() gui.show("local_server_output") end)
                        tgui.button("  save map", function() network.do_upload() end)
                        tgui.button("  restart map", function() world.restart_map() end)
                    end)
                    gui.vlist(0, function()
                        local glob, user = world.get_all_map_names()

                        gui.color(1, 1, 1, 0.05, 0, 0, function()
                            gui.clamp(1, 1, 1, 1)
                            gui.space(0, 0.005, function()
                                gui.clamp(1, 1, 0, 0)
                                gui.label("User maps")
                            end)
                        end)
                        tgui.scrollbox(0.5, 0.15, function()
                            gui.table(4, 0.01, function()
                                gui.align(-1, -1)
                                for i, map in pairs(user) do
                                    gui.button(
                                        function()
                                            world.map(map)
                                        end, function()
                                            local preview = world.get_map_preview_filename(map)
                                               or tgui.image_path .. "icons/icon_no_preview.png"

                                            gui.stretchedimage(preview, 0.1, 0.1, function()
                                                gui.space(0, 0.01, function()
                                                    gui.align(0, 1)
                                                    gui.label(map, 1, 1, 1, 1, function() gui.align(0, 1) end)
                                                end)
                                            end)
                                            gui.stretchedimage(preview, 0.1, 0.1, function()
                                                gui.space(0, 0.01, function()
                                                    gui.align(0, 1)
                                                    gui.label(map, 1, 1, 1, 1, function() gui.align(0, 1) end)
                                                end)
                                            end)
                                            gui.stretchedimage(preview, 0.1, 0.1, function()
                                                gui.space(0, 0.01, function()
                                                    gui.align(0, 1)
                                                    gui.label(map, 1, 1, 1, 1, function() gui.align(0, 1) end)
                                                end)
                                            end)
                                        end
                                    )
                                end
                            end)
                        end)

                        gui.color(1, 1, 1, 0.05, 0, 0, function()
                            gui.clamp(1, 1, 1, 1)
                            gui.space(0, 0.005, function()
                                gui.clamp(1, 1, 0, 0)
                                gui.label("Global maps")
                            end)
                        end)
                        tgui.scrollbox(0.5, 0.15, function()
                            gui.table(4, 0.01, function()
                                gui.align(-1, -1)
                                for i, map in pairs(glob) do
                                    gui.button(
                                        function()
                                            world.map(map)
                                        end, function()
                                            local preview = world.get_map_preview_filename(map)
                                               or tgui.image_path .. "icons/icon_no_preview.png"

                                            gui.stretchedimage(preview, 0.1, 0.1, function()
                                                gui.space(0, 0.01, function()
                                                    gui.align(0, 1)
                                                    gui.label(map, 1, 1, 1, 1, function() gui.align(0, 1) end)
                                                end)
                                            end)
                                            gui.stretchedimage(preview, 0.1, 0.1, function()
                                                gui.space(0, 0.01, function()
                                                    gui.align(0, 1)
                                                    gui.label(map, 1, 1, 1, 1, function() gui.align(0, 1) end)
                                                end)
                                            end)
                                            gui.stretchedimage(preview, 0.1, 0.1, function()
                                                gui.space(0, 0.01, function()
                                                    gui.align(0, 1)
                                                    gui.label(map, 1, 1, 1, 1, function() gui.align(0, 1) end)
                                                end)
                                            end)
                                        end
                                    )
                                end
                            end)
                        end)
                    end)
                end
            )
        end)
    end)
end)

tgui.push_tab("Screen resolution", tgui.BAR_VERTICAL, tgui.BAR_NORMAL, "icon_resolution", function()
    gui.vlist(0, function()
        gui.hlist(0, function()
            gui.label("Field of view: ")
            tgui.hslider("fov")
        end)
        gui.space(0, 0.01, function() gui.clamp(1, 1, 0, 0) end)
        gui.table(5, 0.02, function()
            gui.vlist(0, function()
                gui.align(0, -1)
                gui.label("4:3")
                tgui.resolutionbox(320, 240)
                tgui.resolutionbox(640, 480)
                tgui.resolutionbox(800, 600)
                tgui.resolutionbox(1024, 768)
                tgui.resolutionbox(1152, 864)
                tgui.resolutionbox(1280, 960)
                tgui.resolutionbox(1400, 1050)
                tgui.resolutionbox(1600, 1200)
                tgui.resolutionbox(1792, 1344)
                tgui.resolutionbox(1856, 1392)
                tgui.resolutionbox(1920, 1440)
                tgui.resolutionbox(2048, 1536)
                tgui.resolutionbox(2800, 2100)
                tgui.resolutionbox(3200, 2400)
            end)
            gui.vlist(0, function()
                gui.align(0, -1)
                gui.label("16:10")
                tgui.resolutionbox(320, 200)
                tgui.resolutionbox(640, 400)
                tgui.resolutionbox(1024, 640)
                tgui.resolutionbox(1280, 800)
                tgui.resolutionbox(1440, 900)
                tgui.resolutionbox(1600, 1000)
                tgui.resolutionbox(1680, 1050)
                tgui.resolutionbox(1920, 1200)
                tgui.resolutionbox(2048, 1280)
                tgui.resolutionbox(2560, 1600)
                tgui.resolutionbox(3840, 2400)
            end)
            gui.vlist(0, function()
                gui.align(0, -1)
                gui.label("16:9")
                tgui.resolutionbox(1024, 600)
                tgui.resolutionbox(1280, 720)
                tgui.resolutionbox(1366, 768)
                tgui.resolutionbox(1600, 900)
                tgui.resolutionbox(1920, 1080)
                tgui.resolutionbox(2048, 1152)
                tgui.resolutionbox(3840, 2160)
            end)
            gui.vlist(0, function()
                gui.align(0, -1)
                gui.label("5:4")
                tgui.resolutionbox(600, 480)
                tgui.resolutionbox(1280, 1024)
                tgui.resolutionbox(1600, 1280)
                tgui.resolutionbox(2560, 2048)
            end)
            gui.vlist(0, function()
                gui.align(0, -1)
                gui.label("5:3")
                tgui.resolutionbox(800, 480)
                tgui.resolutionbox(1280, 768)
                gui.label("Custom")
                engine.newvar("custom_w", engine.VAR_S, tostring(scr_w), true)
                engine.newvar("custom_h", engine.VAR_S, tostring(scr_h), true)
                gui.hlist(0, function()
                    tgui.field("custom_w", 4, function() scr_w = tonumber(custom_w) end)
                    tgui.field("custom_h", 4, function() scr_h = tonumber(custom_h) end)
                end)
            end)
        end)
    end)
end)

local about_id = tgui.push_tab("About", tgui.BAR_HORIZONTAL, tgui.BAR_NORMAL, "icon_about", function()
    gui.vlist(0, function()
        gui.label("Copyright 2011 OctaForge developers.", 1, 0, 1, 0)
        gui.label("Released under MIT license.", 1, 1, 0, 0)
        gui.label("Uses Cube 2 engine. Cube 2:", 1, 1, 1, 1, function() gui.align(-1, 0) end)
        gui.label("  - Wouter van Oortmerssen (aardappel)", 1, 1, 1, 1, function() gui.align(-1, 0) end)
        gui.label("  - Lee Salzman (eihrul)", 1, 1, 1, 1, function() gui.align(-1, 0) end)
        gui.label("Based on Syntensity created by Alon Zakai (kripken)", 1, 1, 1, 1, function() gui.align(-1, 0) end)
        gui.label("Uses Lua scripting language, zlib, SDL, OpenGL.", 1, 1, 1, 1, function() gui.align(-1, 0) end)
    end)
end)

-- edit tabs

tgui.push_tab("Textures", tgui.BAR_HORIZONTAL, tgui.BAR_EDIT, "icon_texgui", function()
    texture.filltexlist()
    gui.fill(1, 0.7, function()
        tgui.scrollbox(1, 0.7, function()
            gui.table(9, 0.01, function()
                gui.align(-1, -1)
                for i = 1, texture.getnumslots() do
                    gui.button(function() texture.set(i - 1) end, function()
                        gui.slotview(i - 1, 0.095, 0.095)
                        gui.slotview(i - 1, 0.095, 0.095, function()
                            gui.modcolor(1, 0.5, 0.5, 0.095, 0.095)
                        end)
                        gui.slotview(i - 1, 0.095, 0.095, function()
                            gui.modcolor(0.5, 0.5, 1, 0.095, 0.095)
                        end)
                    end)
                end
            end)
        end)
    end)
end)

tgui.push_tab("Entities", tgui.BAR_HORIZONTAL, tgui.BAR_EDIT, "icon_entities", function()
    gui.fill(0.3, 0.7, function()
        tgui.scrollbox(0.3, 0.7, function()
            gui.vlist(0, function()
                gui.align(-1, -1)
                for i, class in pairs(entity_classes.list()) do
                    tgui.button_no_bg(class, function() world.spawnent(class) end)
                end
            end)
        end)
    end)
end)

tgui.push_tab("Export entities", tgui.BAR_HORIZONTAL, tgui.BAR_EDIT, "icon_save", function()
    gui.vlist(0, function()
        engine.newvar("newexportfilename", engine.VAR_S, "entities.json")
        gui.hlist(0, function()
            gui.label("filename: ")
            tgui.field("newexportfilename", 30)
        end)
        tgui.button("export", function() world.export_entities(newexportfilename) end)
    end)
end)

tgui.push_action(tgui.BAR_VERTICAL, tgui.BAR_ALL, "icon_exit", function() engine.quit() end)

print(id)

-- show main menu tab
gui.show("main")
tgui.show_tab( main_id)
tgui.show_tab(about_id)
