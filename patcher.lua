print("Patcher loaded")

GDPatch.patch_script_as_text("main/dev.gdc", function(ctx, src)
    do
        local pat = "SaveLoadManager%.load%(%)"
        local s, e = src:find(pat)
        print("Keep save on load patch: " .. (s and 1 or 0))
        if s then
            local new = "if SaveLoadManager.has_save(): await SaveLoadManager.load(); SaveLoadManager.save()"
            src = src:sub(1, s - 1) .. new .. src:sub(e + 1)
        end
    end
    return src
end)
