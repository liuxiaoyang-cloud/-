-- 底部对齐处理：找到每张图最低非透明像素行，将内容整体下移，
-- 使物品底边紧贴画布最底部（消除底部多余透明空白）
function Start()
    local ok, err = pcall(function()
        local items = {
            -- 原始 12 种物品 (v4)
            { name = "item_pencil_v4",   src = "image/item_pencil_v4_20260526090812.png"   },
            { name = "item_stapler_v4",  src = "image/item_stapler_v4_20260526090934.png"  },
            { name = "item_folder_v4",   src = "image/item_folder_v4_20260526090830.png"   },
            { name = "item_coffee_v4",   src = "image/item_coffee_v4_20260526090828.png"   },
            { name = "item_eraser_v4",   src = "image/item_eraser_v4_20260526090852.png"   },
            { name = "item_scissors_v4", src = "image/item_scissors_v4_20260526090815.png" },
            { name = "item_notebook_v4", src = "image/item_notebook_v4_20260526090813.png" },
            { name = "item_tape_v4",     src = "image/item_tape_v4_20260526090914.png"     },
            { name = "item_stamp_v4",    src = "image/item_stamp_v4_20260526090820.png"    },
            { name = "item_mug_v4",      src = "image/item_mug_v4_20260526090823.png"      },
            { name = "item_clips_v4",    src = "image/item_clips_v4_20260526091024.png"    },
            { name = "item_note_v4",     src = "image/item_note_v4_20260526091132.png"     },
            -- 新增 12 种物品 (v1)
            { name = "item_ruler_v1",       src = "image/item_ruler_v1_20260526093604.png"       },
            { name = "item_calculator_v1",  src = "image/item_calculator_v1_20260526093737.png"  },
            { name = "item_ballpen_v1",     src = "image/item_ballpen_v1_20260526093539.png"      },
            { name = "item_highlighter_v1", src = "image/item_highlighter_v1_20260526093545.png" },
            { name = "item_binder_clip_v1", src = "image/item_binder_clip_v1_20260526093535.png" },
            { name = "item_correction_v1",  src = "image/item_correction_v1_20260526093532.png"  },
            { name = "item_marker_v1",      src = "image/item_marker_v1_20260526093537.png"      },
            { name = "item_pushpin_v1",     src = "image/item_pushpin_v1_20260526093535.png"     },
            { name = "item_lamp_v1",        src = "image/item_lamp_v1_20260526093550.png"        },
            { name = "item_phone_v1",       src = "image/item_phone_v1_20260526093538.png"       },
            { name = "item_plant_v1",       src = "image/item_plant_v1_20260526093819.png"       },
            { name = "item_calendar_v1",    src = "image/item_calendar_v1_20260526093819.png"    },
        }

        for _, item in ipairs(items) do
            local img = cache:GetResource("Image", item.src)
            assert(img, "无法加载: " .. item.src)

            local w = img:GetWidth()
            local h = img:GetHeight()

            -- 从底部向上扫描，找到最低非透明行
            local lastRow = -1
            for y = h - 1, 0, -1 do
                if lastRow >= 0 then break end
                for x = 0, w - 1 do
                    local c = img:GetPixel(x, y)
                    if c.a > 0.01 then
                        lastRow = y
                        break
                    end
                end
            end

            if lastRow < 0 then
                print("[skip-transparent] " .. item.name)
            else
                local shift = (h - 1) - lastRow
                print(string.format("[%s] w=%d h=%d lastRow=%d shift=%d px",
                    item.name, w, h, lastRow, shift))

                -- 创建新图像，把内容整体下移 shift 行
                local newImg = Image()
                newImg:SetSize(w, h, 4)
                newImg:Clear(Color(0, 0, 0, 0))

                for y = 0, lastRow do
                    for x = 0, w - 1 do
                        newImg:SetPixel(x, y + shift, img:GetPixel(x, y))
                    end
                end

                local dstPath = "/workspace/assets/image/" .. item.name .. "_ba.png"
                assert(newImg:SavePNG(dstPath), "SavePNG 失败: " .. dstPath)
                print("[saved] " .. dstPath)
            end
        end

        print("=== 全部处理完成 ===")
    end)

    if not ok then
        log:Write(LOG_ERROR, "[bottom-align] " .. tostring(err))
    end
    engine:Exit()
end
