function get_papyrus_source_subdirs(dir)
    local subdirs = {}
    for _, file in ipairs(os.files(path.join(dir, "**.psc"))) do
        local dir = path.directory(file)
        if subdirs[dir] == nil then
            subdirs[dir] = true
        end
    end
    return subdirs
end

rule("papyrus", function()
    set_extensions(".psc")

    on_load(function(target)
        target:set("kind", "object")
        target:set("default", true)
        target:add("includedirs", 
        "extern/main/res/scripts/source/", 
        "extern/skyui/dist/Data/Scripts/Headers/",
        "extern/uiextensions/")
    end)

    on_buildcmd_files(function(target, batchcmds, sourcebatch, opt)
        -- envs
        local skyrim_home = path.absolute(os.getenv("SKYRIM_HOME"))
        local papyrus_compiler = path.join(skyrim_home, "/Papyrus Compiler/PapyrusCompiler.exe")
        local tesv_includes = path.join(skyrim_home, "/Data/Scripts/Source/")
        local flags = path.join(tesv_includes, "TESV_Papyrus_Flags.flg")
        assert(os.exists(skyrim_home), "SKYRIM_HOME not found in environment")
        assert(os.exists(papyrus_compiler), "PapyrusCompiler.exe not found in " .. papyrus_compiler)
        assert(os.exists(tesv_includes), "Skyrim source directory not found in " .. tesv_includes)
        assert(os.exists(flags), "TESV_Papyrus_Flags.flg not found in " .. flags)

        -- includes
        local includes = ""
        for _, i in ipairs(target:get("includedirs")) do
            includes = includes .. i .. ";"
        end
        includes = includes .. tesv_includes
        -- batchcmds:show_progress(opt.progress, "${color.build.object}includes %s", includes)
        -- collect source files by directory
        local batchdirs = {}
        for _, sourcefile in ipairs(sourcebatch.sourcefiles) do
            local dir = path.directory(sourcefile)
            if batchdirs[dir] == nil then
                batchdirs[dir] = {}
            end
            table.insert(batchdirs[dir], sourcefile)
        end
        
        -- compile each directory
        for dir, files in pairs(batchdirs) do
            local outputdir = path.directory(dir)
            batchcmds:show_progress(opt.progress, "${color.build.object}compiling.papyrus %s", dir)
            batchcmds:vrunv(papyrus_compiler, {
                path.absolute(dir),
                "-i=" .. dir .. ";" .. includes,
                "-o=" .. outputdir,
                "-f=" .. flags,
                "-a"
            })

            -- add deps
            for _, file in ipairs(files) do
                local dependfile = target:dependfile(path.join(outputdir, path.basename(file) .. ".pex"))
                batchcmds:set_depmtime(os.mtime(dependfile))
                batchcmds:set_depcache(dependfile)
            end
        end
        -- add deps
        batchcmds:add_depfiles(sourcebatch.sourcefiles)
    end)
end)
