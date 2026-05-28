-- 整蛊老板消消乐  v1
-- 凑齐3个同类物品消除，清空所有格子！

---@diagnostic disable: undefined-global
require "LuaScripts/Utilities/Sample"

-- ============================================================================
-- 配置（COLS/ROWS 为运行时变量，每关由 LEVEL_DEFS 决定）
-- ============================================================================
local COLS             = 3      -- 当前关卡列数（InitGame 中更新）
local ROWS             = 4      -- 当前关卡行数（InitGame 中更新）
local SLOTS            = 3
local MAX_DEPTH        = 4
local MATCH            = 3
local SHELF_GAP        = 8
-- HEADER_H 在 Start()/HandleNanoVGRender 中按 uiScale 动态计算
local HEADER_H         = 62
-- 设计基准分辨率（iPhone 竖屏 390×844）
local DESIGN_W         = 390
local DESIGN_H         = 844
-- UI 缩放系数，Start() 中计算后供全局使用
local uiScale          = 1.0

-- ============================================================================
-- 不规则形状定义表（坐标列表版）
-- 每个形状由若干单格坐标 {行, 列} 组成（1-based）
-- 拼接方式：以单个柜子为单位，通过坐标列表描述每关棚架的轮廓
-- ============================================================================
local SHAPE_DEFS = (function()
    local raw = {
        -- ── 小型 (6格) ───────────────────────────────────────────────────────
        -- 1: 2×3 矩形
        { {1,1},{1,2}, {2,1},{2,2}, {3,1},{3,2} },
        -- 2: T形（上3下1右延伸）
        { {1,1},{1,2},{1,3}, {2,2}, {3,2} },
        -- 3: T形（上1下3）
        { {1,2}, {2,2}, {3,1},{3,2},{3,3} },
        -- 4: L形（左竖3+底横延伸）
        { {1,1}, {2,1},{2,2}, {3,1},{3,2},{3,3} },
        -- 5: J形（右竖3+底横延伸）
        { {1,3}, {2,2},{2,3}, {3,1},{3,2},{3,3} },
        -- 6: S形（两行错排）
        { {1,2},{1,3}, {2,1},{2,2}, {3,1} },
        -- 7: Z形（两行错排反向）
        { {1,1},{1,2}, {2,2},{2,3}, {3,3} },
        -- 8: 竖3+侧翼（十字小）
        { {1,2}, {2,1},{2,2},{2,3}, {3,2} },

        -- ── 中型 (9-13格) ────────────────────────────────────────────────────
        -- 9: 3×3 满格
        { {1,1},{1,2},{1,3}, {2,1},{2,2},{2,3}, {3,1},{3,2},{3,3} },
        -- 10: 4×2 矩形（宽4行2）
        { {1,1},{1,2},{1,3},{1,4}, {2,1},{2,2},{2,3},{2,4} },
        -- 11: 桶形（中宽两端窄）
        { {1,2},{1,3}, {2,1},{2,2},{2,3},{2,4}, {3,1},{3,2},{3,3},{3,4}, {4,2},{4,3} },
        -- 12: H形（两侧竖3+中间横连）
        { {1,1},{1,3}, {2,1},{2,2},{2,3}, {3,1},{3,3}, {4,1},{4,2},{4,3} },
        -- 13: 3×4 矩形
        { {1,1},{1,2},{1,3}, {2,1},{2,2},{2,3}, {3,1},{3,2},{3,3}, {4,1},{4,2},{4,3} },
        -- 14: 4×3 矩形
        { {1,1},{1,2},{1,3},{1,4}, {2,1},{2,2},{2,3},{2,4}, {3,1},{3,2},{3,3},{3,4} },
        -- 15: 楼梯形（左升阶）
        { {1,1}, {2,1},{2,2}, {3,1},{3,2},{3,3}, {4,1},{4,2},{4,3},{4,4} },
        -- 16: 十字形（扩展）
        { {1,2},{1,3}, {2,1},{2,2},{2,3},{2,4}, {3,2},{3,3} },
        -- 17: U形（两侧竖+底横）
        { {1,1},{1,3}, {2,1},{2,3}, {3,1},{3,2},{3,3} },
        -- 18: 菱形（4行交错）
        { {1,2},{1,3}, {2,1},{2,2},{2,3},{2,4}, {3,1},{3,2},{3,3},{3,4}, {4,2},{4,3} },

        -- ── 大型 (14-20格) ───────────────────────────────────────────────────
        -- 19: 4×4 满格
        { {1,1},{1,2},{1,3},{1,4}, {2,1},{2,2},{2,3},{2,4},
          {3,1},{3,2},{3,3},{3,4}, {4,1},{4,2},{4,3},{4,4} },
        -- 20: 3×5 矩形
        { {1,1},{1,2},{1,3}, {2,1},{2,2},{2,3}, {3,1},{3,2},{3,3},
          {4,1},{4,2},{4,3}, {5,1},{5,2},{5,3} },
        -- 21: 六边形（3行宽度不等）
        { {1,2},{1,3},{1,4}, {2,1},{2,2},{2,3},{2,4},{2,5},
          {3,1},{3,2},{3,3},{3,4},{3,5}, {4,2},{4,3},{4,4} },
        -- 22: 大T形（上横5+下竖5）
        { {1,1},{1,2},{1,3},{1,4},{1,5},
          {2,3}, {3,3}, {4,3}, {5,3} },
        -- 23: 王字形（三横+两竖连接）
        { {1,1},{1,2},{1,3},{1,4},
          {2,2},{2,3},
          {3,1},{3,2},{3,3},{3,4},
          {4,2},{4,3},
          {5,1},{5,2},{5,3},{5,4} },
        -- 24: 大桶形（中宽两端窄 5行）
        { {1,2},{1,3},{1,4},
          {2,1},{2,2},{2,3},{2,4},{2,5},
          {3,1},{3,2},{3,3},{3,4},{3,5},
          {4,1},{4,2},{4,3},{4,4},{4,5},
          {5,2},{5,3},{5,4} },
        -- 25: 双十字（上下两个十字连接）
        { {1,2}, {2,1},{2,2},{2,3}, {3,2},{3,3},{3,4},
          {4,1},{4,2},{4,3}, {5,2} },
    }
    local shapes = {}
    for si, cells in ipairs(raw) do
        local vrows, vcols = 0, 0
        for _, pos in ipairs(cells) do
            vrows = math.max(vrows, pos[1])
            vcols = math.max(vcols, pos[2])
        end
        shapes[si] = { cells=cells, vrows=vrows, vcols=vcols, count=#cells }
    end
    return shapes
end)()

-- ============================================================================
-- 关卡配置表
-- 每关定义：shapeIdx（形状索引）、time、types、dupTypes、scoreBonus
-- 每关独立设计
-- shapeIdx: 形状索引(1-25)  time: 时限(秒)
-- types: 物品种类数  layers: 层数  dupTypes: 前后层重叠种类数
-- specials: 特殊格子配方 { {type="locked"|"vert"|"horiz", count=N, ...} }
-- scoreBonus: 过关额外奖励分
-- 设计约束：每 10 关内 shapeIdx 不重复
-- ============================================================================
local LEVEL_DEFS = (function()

-- ── 手工设计的前 50 关 ──────────────────────────────────────────────────────
-- 形状分组备忘（SHAPE_DEFS 索引）：
--   小型 6格:  1=2×3矩  2=T上  3=T下  4=L形  5=J形  6=S形  7=Z形  8=小十字
--   小型 7-9格: (部分形状格数不同，以实际 count 为准)
--   中型:  9=3×3  10=4×2  11=桶形  12=H形  13=3×4  14=4×3  15=楼梯  16=十字+
--           17=U形  18=菱形
--   大型: 19=4×4  20=3×5  21=六边形  22=大T  23=王字  24=大桶  25=双十字
--
-- specials 字段说明（AssignSpecialCells 会读取）：
--   {type="locked", count=N, hits=K}   →  N 个锁定格，各需 K 次消除解锁
--   {type="vert",   count=N, spd=S}    →  N 个垂直移动格，速度 S px/s
--   {type="horiz",  count=N, spd=S}    →  N 个水平移动格，速度 S px/s
-- ============================================================================
local hand = {
--  关  形  时    种  层  重  特殊配方                              奖励
-- ============================================================================
-- 容量约束说明：
--   sh.count = 该形状的格子数
--   LAYER_CAP = sh.count × 3 (每格3槽)
--   当 dupTypes > 0 时：frontLayerCnt = layers - 1
--     types    ≤ frontLayerCnt × sh.count
--     dupTypes ≤ sh.count
--   当 dupTypes = 0 时：
--     types ≤ layers × sh.count
--
-- 形状格子数速查：
--   1=6  2=5  3=5  4=6  5=6  6=5  7=5  8=5
--   9=9  10=8  11=12  12=10  13=12  14=12  15=10  16=8  17=7  18=12
--   19=16  20=15  21=17  22=9  23=16  24=21  25=11
-- ============================================================================

--  1: 2×3矩(6格)，新手，无特殊
--     dupTypes=0 → types ≤ 3×6=18 → 用15，安全
    { shapeIdx=1,  time=180, types=15, layers=3, dupTypes=0,
      specials={},
      scoreBonus=0 },
--  2: T上形(5格)，无特殊
--     dupTypes=0 → types ≤ 3×5=15 → 用15，正好满
    { shapeIdx=2,  time=180, types=15, layers=3, dupTypes=0,
      specials={},
      scoreBonus=0 },
--  3: T下形(5格)，无特殊
--     dupTypes=0 → types ≤ 3×5=15 → 用15
    { shapeIdx=3,  time=180, types=15, layers=3, dupTypes=0,
      specials={},
      scoreBonus=0 },
--  4: L形(6格)，无特殊
--     dupTypes=0 → types ≤ 3×6=18 → 用16
    { shapeIdx=4,  time=180, types=16, layers=3, dupTypes=0,
      specials={},
      scoreBonus=0 },
--  5: J形(6格)，首次出现 1 个锁定格（2次解锁）
--     dupTypes=3 → frontLayerCnt=3-1=2, types ≤ 2×6=12, dupTypes ≤ 6
--     groups = 12+3 = 15 ✓
    { shapeIdx=5,  time=180, types=12, layers=3, dupTypes=3,
      specials={ {type="locked", count=1, hits=2} },
      scoreBonus=0 },
--  6: S形(5格)，1 个锁定格
--     dupTypes=3 → frontLayerCnt=2, types ≤ 2×5=10, dupTypes ≤ 5
--     layers=4: frontLayerCnt=3, types ≤ 3×5=15
--     groups = 15+3 = 18 ✓（用layers=4）
    { shapeIdx=6,  time=180, types=15, layers=4, dupTypes=3,
      specials={ {type="locked", count=1, hits=2} },
      scoreBonus=0 },
--  7: Z形(5格)，1 个锁定格
--     layers=4, dupTypes=5 → frontLayerCnt=3, types ≤ 15, dupTypes ≤ 5
--     groups = 15+5 = 20 ✓
    { shapeIdx=7,  time=180, types=15, layers=4, dupTypes=5,
      specials={ {type="locked", count=1, hits=2} },
      scoreBonus=0 },
--  8: 小十字(5格)，2 个锁定格
--     layers=5, dupTypes=5 → frontLayerCnt=4, types ≤ 4×5=20 → 用20, dupTypes ≤ 5
--     groups = 20+5 = 25 ✓
    { shapeIdx=8,  time=180, types=20, layers=5, dupTypes=5,
      specials={ {type="locked", count=2, hits=2} },
      scoreBonus=0 },
--  9: 3×3(9格)，引入后层
--     layers=4, dupTypes=9 → frontLayerCnt=3, types ≤ 3×9=24(用18), dupTypes ≤ 9
--     groups = 18+9 = 27 ✓
    { shapeIdx=9,  time=180, types=18, layers=4, dupTypes=9,
      specials={ {type="locked", count=1, hits=2} },
      scoreBonus=0 },
-- 10: 4×2矩(8格)，首次出现垂直移动格
--     layers=4, dupTypes=8 → frontLayerCnt=3, types ≤ 3×8=24(用20), dupTypes ≤ 8
--     groups = 20+8 = 28 ✓
    { shapeIdx=10, time=180,  types=20, layers=4, dupTypes=8,
      specials={ {type="vert", count=1, spd=30} },
      scoreBonus=0 },

-- 第 11-20 关：中型形状轮换，特殊格子种类增加
-- 11: 桶形(12格)，1 锁定
--     layers=4, dupTypes=12 → frontLayerCnt=3, types ≤ 3×12=24, dupTypes ≤ 12
--     groups = 18+12 = 30 ✓
    { shapeIdx=11, time=180,  types=18, layers=4, dupTypes=12,
      specials={ {type="locked", count=1, hits=3} },
      scoreBonus=0 },
-- 12: H形(10格)，1 垂直移动
--     layers=4, dupTypes=10 → frontLayerCnt=3, types ≤ 3×10=24(用20), dupTypes ≤ 10
--     groups = 20+10 = 30 ✓
    { shapeIdx=12, time=180,  types=20, layers=4, dupTypes=10,
      specials={ {type="vert", count=1, spd=32} },
      scoreBonus=0 },
-- 13: 3×4矩(12格)，2 锁定
--     layers=4, dupTypes=12 → frontLayerCnt=3, types ≤ 36(用20), dupTypes ≤ 12
--     groups = 20+12 = 32 ✓
    { shapeIdx=13, time=180,  types=20, layers=4, dupTypes=12,
      specials={ {type="locked", count=2, hits=2} },
      scoreBonus=0 },
-- 14: 4×3矩(12格)，1 锁定 + 1 垂直
--     layers=4, dupTypes=12 → frontLayerCnt=3, types ≤ 36(用20), dupTypes ≤ 12
--     groups = 20+12 = 32 ✓
    { shapeIdx=14, time=180,  types=20, layers=4, dupTypes=12,
      specials={ {type="locked", count=1, hits=3},
                 {type="vert",   count=1, spd=34} },
      scoreBonus=0 },
-- 15: 楼梯(10格)，首次出现水平移动
--     layers=4, dupTypes=10 → frontLayerCnt=3, types ≤ 30(用20), dupTypes ≤ 10
--     groups = 20+10 = 30 ✓
    { shapeIdx=15, time=180,  types=20, layers=4, dupTypes=10,
      specials={ {type="horiz", count=1, spd=30} },
      scoreBonus=0 },
-- 16: 十字+(8格)，水平+锁定
--     layers=4, dupTypes=8 → frontLayerCnt=3, types ≤ 24, dupTypes ≤ 8
--     groups = 20+8 = 28 ✓
    { shapeIdx=16, time=180,  types=20, layers=4, dupTypes=8,
      specials={ {type="locked", count=1, hits=3},
                 {type="horiz",  count=1, spd=32} },
      scoreBonus=0 },
-- 17: U形(7格)，1 垂直 + 1 水平
--     layers=5, dupTypes=7 → frontLayerCnt=4, types ≤ 4×7=28(用21), dupTypes ≤ 7
--     groups = 21+7 = 28 ✓
    { shapeIdx=17, time=180,  types=21, layers=5, dupTypes=7,
      specials={ {type="vert",  count=1, spd=36},
                 {type="horiz", count=1, spd=32} },
      scoreBonus=0 },
-- 18: 菱形(12格)，2 锁定
--     layers=4, dupTypes=12 → frontLayerCnt=3, types ≤ 36(用22), dupTypes ≤ 12
--     groups = 22+12 = 34 ✓
    { shapeIdx=18, time=180,  types=22, layers=4, dupTypes=12,
      specials={ {type="locked", count=2, hits=3} },
      scoreBonus=0 },
-- 19: 3×3(9格) 复用（变奏）
--     layers=5, dupTypes=9 → frontLayerCnt=4, types ≤ 4×9=36(用22), dupTypes ≤ 9
--     groups = 22+9 = 31 ✓
    { shapeIdx=9,  time=180,  types=22, layers=5, dupTypes=9,
      specials={ {type="locked", count=1, hits=3},
                 {type="vert",   count=1, spd=38} },
      scoreBonus=0 },
-- 20: 4×2(8格) 复用（变奏）
--     layers=5, dupTypes=8 → frontLayerCnt=4, types ≤ 4×8=32(用24), dupTypes ≤ 8
--     groups = 24+8 = 32 ✓
    { shapeIdx=10, time=180,  types=24, layers=5, dupTypes=8,
      specials={ {type="locked", count=1, hits=3},
                 {type="vert",   count=1, spd=40},
                 {type="horiz",  count=1, spd=36} },
      scoreBonus=0 },

-- 第 21-30 关：大型形状登场，层数更深
-- 21: 4×4满格(16格)，2 锁定
--     layers=5, dupTypes=16 → frontLayerCnt=4, types ≤ 4×16=64(用24), dupTypes ≤ 16
--     groups = 24+16 = 40 ✓
    { shapeIdx=19, time=180,  types=24, layers=5, dupTypes=16,
      specials={ {type="locked", count=2, hits=3} },
      scoreBonus=0 },
-- 22: 3×5矩(15格)，1 垂直 + 2 锁定
--     layers=5, dupTypes=15 → frontLayerCnt=4, types ≤ 60(用24), dupTypes ≤ 15
--     groups = 24+15 = 39 ✓
    { shapeIdx=20, time=180,  types=24, layers=5, dupTypes=15,
      specials={ {type="locked", count=2, hits=3},
                 {type="vert",   count=1, spd=42} },
      scoreBonus=0 },
-- 23: 六边形(17格)，2 水平移动
--     layers=5, dupTypes=17 → frontLayerCnt=4, types ≤ 68(用24), dupTypes ≤ 17
--     groups = 24+17 = 41 ✓
    { shapeIdx=21, time=180,  types=24, layers=5, dupTypes=17,
      specials={ {type="horiz", count=2, spd=40} },
      scoreBonus=0 },
-- 24: 大T形(9格)，2 锁定 + 1 水平
--     layers=5, dupTypes=9 → frontLayerCnt=4, types ≤ 36(用24), dupTypes ≤ 9
--     groups = 24+9 = 33 ✓
    { shapeIdx=22, time=180,  types=24, layers=5, dupTypes=9,
      specials={ {type="locked", count=2, hits=4},
                 {type="horiz",  count=1, spd=42} },
      scoreBonus=0 },
-- 25: 王字形(16格)，1 垂直 + 2 水平
--     layers=5, dupTypes=16 → frontLayerCnt=4, types ≤ 64(用24), dupTypes ≤ 16
--     groups = 24+16 = 40 ✓
    { shapeIdx=23, time=180,  types=24, layers=5, dupTypes=16,
      specials={ {type="vert",  count=1, spd=44},
                 {type="horiz", count=2, spd=40} },
      scoreBonus=0 },
-- 26: 大桶形(21格)，3 锁定
--     layers=5, dupTypes=21 → frontLayerCnt=4, types ≤ 84(用24), dupTypes ≤ 21
--     groups = 24+21 = 45 ✓
    { shapeIdx=24, time=180,  types=24, layers=5, dupTypes=21,
      specials={ {type="locked", count=3, hits=3} },
      scoreBonus=0 },
-- 27: 双十字(11格)，2 垂直 + 1 锁定
--     layers=5, dupTypes=11 → frontLayerCnt=4, types ≤ 44(用24), dupTypes ≤ 11
--     groups = 24+11 = 35 ✓
    { shapeIdx=25, time=180,  types=24, layers=5, dupTypes=11,
      specials={ {type="locked", count=1, hits=4},
                 {type="vert",   count=2, spd=44} },
      scoreBonus=0 },
-- 28: 桶形(12格)（变奏：层5，特殊格更多）
--     layers=5, dupTypes=12 → frontLayerCnt=4, types ≤ 48(用24), dupTypes ≤ 12
--     groups = 24+12 = 36 ✓
    { shapeIdx=11, time=180,  types=24, layers=5, dupTypes=12,
      specials={ {type="locked", count=2, hits=4},
                 {type="horiz",  count=1, spd=44} },
      scoreBonus=0 },
-- 29: H形(10格)（变奏：2垂直+2水平）
--     layers=5, dupTypes=10 → frontLayerCnt=4, types ≤ 40(用24), dupTypes ≤ 10
--     groups = 24+10 = 34 ✓
    { shapeIdx=12, time=180,  types=24, layers=5, dupTypes=10,
      specials={ {type="vert",  count=2, spd=46},
                 {type="horiz", count=2, spd=42} },
      scoreBonus=0 },
-- 30: 楼梯(10格)（变奏：3 锁定 hits=4）
--     layers=6, dupTypes=10 → frontLayerCnt=5, types ≤ 50(用24), dupTypes ≤ 10
--     groups = 24+10 = 34 ✓
    { shapeIdx=15, time=180,  types=24, layers=6, dupTypes=10,
      specials={ {type="locked", count=3, hits=4} },
      scoreBonus=0 },

-- 第 31-40 关：加深难度，层数 6，特殊格子密度加大
-- 31: L形(6格)（变奏：层6）
--     layers=6, dupTypes=6 → frontLayerCnt=5, types ≤ 5×6=30(用24), dupTypes ≤ 6
--     groups = 24+6 = 30 ✓
    { shapeIdx=4,  time=180,  types=24, layers=6, dupTypes=6,
      specials={ {type="locked", count=2, hits=4},
                 {type="vert",   count=1, spd=48} },
      scoreBonus=0 },
-- 32: J形(6格)（变奏：层7，水平+锁）
--     layers=7, dupTypes=6 → frontLayerCnt=6, types ≤ 6×6=36(用24), dupTypes ≤ 6
--     groups = 24+6 = 30 ✓
    { shapeIdx=5,  time=180,  types=24, layers=7, dupTypes=6,
      specials={ {type="locked", count=2, hits=4},
                 {type="horiz",  count=1, spd=46} },
      scoreBonus=0 },
-- 33: Z形(5格)（变奏）
--     layers=8, dupTypes=5 → frontLayerCnt=7, types ≤ 7×5=35(用24), dupTypes ≤ 5
--     groups = 24+5 = 29 ✓
    { shapeIdx=7,  time=180,  types=24, layers=8, dupTypes=5,
      specials={ {type="locked", count=1, hits=4},
                 {type="vert",   count=2, spd=50},
                 {type="horiz",  count=1, spd=46} },
      scoreBonus=0 },
-- 34: S形(5格)（变奏）
--     layers=8, dupTypes=5 → frontLayerCnt=7, types ≤ 35(用24), dupTypes ≤ 5
--     groups = 24+5 = 29 ✓
    { shapeIdx=6,  time=180,  types=24, layers=8, dupTypes=5,
      specials={ {type="locked", count=2, hits=4},
                 {type="horiz",  count=2, spd=48} },
      scoreBonus=0 },
-- 35: T上(5格)（变奏：层8）
--     layers=8, dupTypes=5 → frontLayerCnt=7, types ≤ 35(用24), dupTypes ≤ 5
--     groups = 24+5 = 29 ✓
    { shapeIdx=2,  time=180,  types=24, layers=8, dupTypes=5,
      specials={ {type="locked", count=3, hits=4},
                 {type="vert",   count=1, spd=50} },
      scoreBonus=0 },
-- 36: T下(5格)（变奏：层8）
--     同上 groups = 24+5 = 29 ✓
    { shapeIdx=3,  time=180,  types=24, layers=8, dupTypes=5,
      specials={ {type="locked", count=2, hits=5},
                 {type="horiz",  count=2, spd=50} },
      scoreBonus=0 },
-- 37: 十字+(8格)（变奏：3垂直）
--     layers=6, dupTypes=8 → frontLayerCnt=5, types ≤ 40(用24), dupTypes ≤ 8
--     groups = 24+8 = 32 ✓
    { shapeIdx=16, time=180,  types=24, layers=6, dupTypes=8,
      specials={ {type="vert",   count=3, spd=52} },
      scoreBonus=0 },
-- 38: U形(7格)（变奏：混合4特殊）
--     layers=6, dupTypes=7 → frontLayerCnt=5, types ≤ 35(用24), dupTypes ≤ 7
--     groups = 24+7 = 31 ✓
    { shapeIdx=17, time=180,  types=24, layers=6, dupTypes=7,
      specials={ {type="locked", count=2, hits=4},
                 {type="vert",   count=1, spd=52},
                 {type="horiz",  count=1, spd=50} },
      scoreBonus=0 },
-- 39: 菱形(12格)（变奏：层6，4锁定）
--     layers=6, dupTypes=12 → frontLayerCnt=5, types ≤ 60(用24), dupTypes ≤ 12
--     groups = 24+12 = 36 ✓
    { shapeIdx=18, time=180,  types=24, layers=6, dupTypes=12,
      specials={ {type="locked", count=4, hits=4} },
      scoreBonus=0 },
-- 40: 4×4(16格)（变奏：层6，强化特殊）
--     layers=6, dupTypes=16 → frontLayerCnt=5, types ≤ 80(用24), dupTypes ≤ 16
--     groups = 24+16 = 40 ✓
    { shapeIdx=19, time=180,  types=24, layers=6, dupTypes=16,
      specials={ {type="locked", count=2, hits=5},
                 {type="vert",   count=2, spd=54},
                 {type="horiz",  count=1, spd=50} },
      scoreBonus=0 },

-- 第 41-50 关：高难，大型形状轮换+层数7
-- 41: 3×5(15格)（层7）
--     layers=7, dupTypes=15 → frontLayerCnt=6, types ≤ 90(用24), dupTypes ≤ 15
--     groups = 24+15 = 39 ✓
    { shapeIdx=20, time=180,  types=24, layers=7, dupTypes=15,
      specials={ {type="locked", count=3, hits=5},
                 {type="vert",   count=2, spd=56} },
      scoreBonus=0 },
-- 42: 六边形(17格)（层7）
--     layers=7, dupTypes=17 → frontLayerCnt=6, types ≤ 102(用24), dupTypes ≤ 17
--     groups = 24+17 = 41 ✓
    { shapeIdx=21, time=180,  types=24, layers=7, dupTypes=17,
      specials={ {type="locked", count=2, hits=5},
                 {type="horiz",  count=3, spd=52} },
      scoreBonus=0 },
-- 43: 大T形(9格)（层7）
--     layers=7, dupTypes=9 → frontLayerCnt=6, types ≤ 54(用24), dupTypes ≤ 9
--     groups = 24+9 = 33 ✓
    { shapeIdx=22, time=180,  types=24, layers=7, dupTypes=9,
      specials={ {type="locked", count=3, hits=5},
                 {type="vert",   count=2, spd=56},
                 {type="horiz",  count=1, spd=52} },
      scoreBonus=0 },
-- 44: 王字形(16格)（层7）
--     layers=7, dupTypes=16 → frontLayerCnt=6, types ≤ 96(用24), dupTypes ≤ 16
--     groups = 24+16 = 40 ✓
    { shapeIdx=23, time=180,  types=24, layers=7, dupTypes=16,
      specials={ {type="locked", count=2, hits=5},
                 {type="vert",   count=3, spd=58} },
      scoreBonus=0 },
-- 45: 大桶形(21格)（层7）
--     layers=7, dupTypes=21 → frontLayerCnt=6, types ≤ 126(用24), dupTypes ≤ 21
--     groups = 24+21 = 45 ✓
    { shapeIdx=24, time=180,  types=24, layers=7, dupTypes=21,
      specials={ {type="locked", count=4, hits=5},
                 {type="horiz",  count=2, spd=54} },
      scoreBonus=0 },
-- 46: 双十字(11格)（层7，复杂混合）
--     layers=7, dupTypes=11 → frontLayerCnt=6, types ≤ 66(用24), dupTypes ≤ 11
--     groups = 24+11 = 35 ✓
    { shapeIdx=25, time=180,  types=24, layers=7, dupTypes=11,
      specials={ {type="locked", count=2, hits=5},
                 {type="vert",   count=2, spd=58},
                 {type="horiz",  count=2, spd=54} },
      scoreBonus=0 },
-- 47: 3×4(12格)（层7）
--     layers=7, dupTypes=12 → frontLayerCnt=6, types ≤ 72(用24), dupTypes ≤ 12
--     groups = 24+12 = 36 ✓
    { shapeIdx=13, time=180,  types=24, layers=7, dupTypes=12,
      specials={ {type="locked", count=3, hits=5},
                 {type="vert",   count=2, spd=58},
                 {type="horiz",  count=2, spd=56} },
      scoreBonus=0 },
-- 48: 4×3(12格)（层7）
--     layers=7, dupTypes=12 → frontLayerCnt=6, types ≤ 72(用24), dupTypes ≤ 12
--     groups = 24+12 = 36 ✓
    { shapeIdx=14, time=180,  types=24, layers=7, dupTypes=12,
      specials={ {type="locked", count=4, hits=5},
                 {type="vert",   count=2, spd=60},
                 {type="horiz",  count=1, spd=56} },
      scoreBonus=0 },
-- 49: 小十字(5格)（顶层压轴变奏，层9，极多特殊）
--     layers=9, dupTypes=5 → frontLayerCnt=8, types ≤ 8×5=40(用24), dupTypes ≤ 5
--     groups = 24+5 = 29 ✓
    { shapeIdx=8,  time=180,  types=24, layers=9, dupTypes=5,
      specials={ {type="locked", count=3, hits=5},
                 {type="vert",   count=2, spd=60},
                 {type="horiz",  count=2, spd=58} },
      scoreBonus=0 },
-- 50: 2×3矩(6格)（荣耀回归：最简形状+最深难度，纯粹挑战）
--     layers=9, dupTypes=6 → frontLayerCnt=8, types ≤ 8×6=48(用24), dupTypes ≤ 6
--     groups = 24+6 = 30 ✓
    { shapeIdx=1,  time=180,  types=24, layers=9, dupTypes=6,
      specials={ {type="locked", count=4, hits=5},
                 {type="vert",   count=2, spd=62},
                 {type="horiz",  count=2, spd=60} },
      scoreBonus=0 },
}

-- 50 关后：按 10 关一组循环，每组随机挑 10 个形状（保证不重复），
-- 时间固定 55s，难度参数沿用第 50 关水平，奖励随关卡线性增长。
local SHAPE_CYCLE = {
    -- 组 A (形状 1-10 轮换变奏)
    {1,2,3,4,5,6,7,8,9,10},
    -- 组 B
    {11,12,13,14,15,16,17,18,19,20},
    -- 组 C
    {21,22,23,24,25,1,3,5,7,9},
    -- 组 D
    {2,4,6,8,10,12,14,16,18,20},
    -- 组 E
    {11,13,15,17,19,21,23,25,2,6},
}

-- 形状格子数映射（用于计算容量约束）
-- 约束：types ≤ (layers-1) × shCount, dupTypes ≤ shCount
local SHAPE_CELL_COUNT = {
    6, 5, 5, 6, 6, 5, 5, 5,         -- 1-8
    9, 8,                             -- 9-10
    12, 10, 12, 12, 10, 8, 7, 12,    -- 11-18
    16, 15, 17, 9, 16, 21, 11,       -- 19-25
}

local defs = {}
for i, h in ipairs(hand) do
    defs[i] = h
end

local N = 200
for i = 51, N do
    local groupIdx = math.floor((i - 51) / 10) % #SHAPE_CYCLE + 1
    local posInGroup = (i - 51) % 10 + 1
    local shapeIdx = SHAPE_CYCLE[groupIdx][posInGroup]
    local bonus = 0

    -- 先确定层数
    local numLayers = math.min(10, 7 + math.floor((i - 50) / 50))
    local shCount = SHAPE_CELL_COUNT[shapeIdx] or 8

    -- dupTypes 不超过形状格子数（后层容量上限）
    local maxDup = shCount
    local rawDup = math.min(24, 4 + math.floor((i - 50) / 15))
    local dupTypes = math.min(rawDup, maxDup)

    -- types 不超过前层容量：(layers-1) × shCount
    local frontLayerCnt = numLayers - 1  -- dupTypes > 0 时
    local maxTypes = frontLayerCnt * shCount
    local types = math.min(24, maxTypes)

    defs[i] = {
        shapeIdx  = shapeIdx,
        time      = 180,
        types     = types,
        layers    = numLayers,
        dupTypes  = dupTypes,
        specials  = {
            {type="locked", count=math.min(5, 3 + math.floor((i-50)/30)), hits=5},
            {type="vert",   count=2, spd=math.min(90, 60 + math.floor((i-50)/20)*2)},
            {type="horiz",  count=2, spd=math.min(88, 58 + math.floor((i-50)/20)*2)},
        },
        scoreBonus = bonus,
    }
end

return defs
end)()
local MAX_LEVEL = #LEVEL_DEFS   -- 200

local ITEM_TYPES_COUNT = 24  -- 全部物品种类数

-- ============================================================================
-- 柜子外观风格（每 10 关循环一次，共 5 种）
-- bg1/bg2: 背景渐变上下色  stroke: 描边  hl: 高光  radius: 圆角
-- dark: 是否深色背景（影响物品遮罩亮度）
-- ============================================================================
local SHELF_STYLES = {
    -- 1 奶白清新（默认）
    { bg1={252,253,255}, bg2={235,242,255},
      tray={218,228,248}, slot={190,205,235},
      stroke={180,200,235}, accent={100,150,230},
      shadow={150,170,210}, radius=12, dark=false },
    -- 2 薄荷绿
    { bg1={245,255,252}, bg2={220,248,238},
      tray={195,235,215}, slot={165,215,195},
      stroke={140,200,175}, accent={60,185,140},
      shadow={120,185,160}, radius=10, dark=false },
    -- 3 暖杏米
    { bg1={255,252,244}, bg2={248,235,210},
      tray={235,210,175}, slot={215,188,148},
      stroke={200,170,120}, accent={210,140,60},
      shadow={185,150,100}, radius=10, dark=false },
    -- 4 天蓝冰晶
    { bg1={240,250,255}, bg2={210,238,255},
      tray={175,220,250}, slot={145,200,240},
      stroke={100,180,235}, accent={40,155,225},
      shadow={100,165,220}, radius=14, dark=false },
    -- 5 深空暗紫
    { bg1={38,32,58},   bg2={28,22,48},
      tray={22,18,42},   slot={50,40,80},
      stroke={90,70,140}, accent={160,120,255},
      shadow={15,12,30},  radius=10, dark=true  },
}

-- ============================================================================
-- 办公物品定义（卡通风格）
-- ============================================================================
local ITEM_DEFS = {
    { id="pencil",      r=240, g=200, b=60,  img="image/item_pencil_v5_20260527063745.png"      },
    { id="stapler",     r=40,  g=80,  b=180, img="image/item_stapler_v5_20260527063929.png"     },
    { id="folder",      r=230, g=120, b=40,  img="image/item_folder_v5_20260527063935.png"      },
    { id="coffee",      r=180, g=100, b=50,  img="image/item_coffee_v5_20260527063750.png"      },
    { id="eraser",      r=210, g=140, b=190, img="image/item_eraser_v5_20260527063800.png"      },
    { id="scissors",    r=220, g=50,  b=50,  img="image/item_scissors_v5_20260527063754.png"    },
    { id="notebook",    r=60,  g=100, b=200, img="image/item_notebook_v5_20260527063755.png"    },
    { id="tape",        r=220, g=200, b=80,  img="image/item_tape_v5_20260527063910.png"        },
    { id="stamp",       r=200, g=50,  b=50,  img="image/item_stamp_v5_20260527064215.png"       },
    { id="mug",         r=60,  g=120, b=200, img="image/item_mug_v5_20260527064253.png"         },
    { id="clips",       r=180, g=180, b=190, img="image/item_clips_v5_20260527064029.png"       },
    { id="note",        r=240, g=220, b=60,  img="image/item_note_v5_20260527064030.png"        },
    { id="ruler",       r=100, g=200, b=120, img="image/item_ruler_v5_20260527064144.png"       },
    { id="calculator",  r=80,  g=80,  b=80,  img="image/item_calculator_v5_20260527064219.png"  },
    { id="ballpen",     r=40,  g=160, b=220, img="image/item_ballpen_v5_20260527064020.png"     },
    { id="highlighter", r=255, g=200, b=30,  img="image/item_highlighter_v5_20260527064145.png" },
    { id="binder_clip", r=30,  g=30,  b=30,  img="image/item_binder_clip_v5_20260527064455.png" },
    { id="correction",  r=240, g=240, b=240, img="image/item_correction_v5_20260527064342.png"  },
    { id="marker",      r=220, g=60,  b=140, img="image/item_marker_v5_20260527064452.png"      },
    { id="pushpin",     r=230, g=40,  b=40,  img="image/item_pushpin_v5_20260527064343.png"     },
    { id="lamp",        r=255, g=220, b=80,  img="image/item_lamp_v5_20260527064341.png"        },
    { id="phone",       r=50,  g=50,  b=60,  img="image/item_phone_v5_20260527064347.png"       },
    { id="plant",       r=60,  g=180, b=70,  img="image/item_plant_v5_20260527064355.png"       },
    { id="calendar",    r=220, g=80,  b=80,  img="image/item_calendar_v5_20260527064516.png"    },
}
-- 运行时图片句柄（Start 中加载）
local itemImages     = {}
-- itemImagesDark 已移除，暗化改用 NanoVG 叠色实现

local function GetDef(id)
    for _, t in ipairs(ITEM_DEFS) do
        if t.id == id then return t end
    end
    return ITEM_DEFS[1]
end

-- ============================================================================
-- 全局状态
-- ============================================================================
---@type any
local vg        = nil
local fontId    = -1
local screenW, screenH = 0, 0
local dpr       = 1.0

-- ============================================================================
-- 金手指面板
-- ============================================================================
local _cheat = {
    visible = false,   -- 面板是否展开
    btnW    = 44,      -- 入口按钮宽
    btnH    = 24,      -- 入口按钮高
}

-- ============================================================================
-- 应用阶段：logo → splash（加载条）→ home（主界面）→ game（游戏中）
-- ============================================================================
local appPhase      = "logo"     -- 当前阶段
local logoTimer     = 0.0        -- logo 已播放时长
local LOGO_DUR      = 2.0        -- logo 展示时长（秒）
local logoImage     = -1         -- nvg 图片句柄
local splashBgImage = -1         -- 加载页背景图
local homeBgImage   = -1         -- 主界面完整背景图
local shopBgImage   = -1         -- 商店背景图
-- 导航栏图标（选中/未选中各一套）
local navTrophyActive   = -1
local navTrophyInactive = -1
local navHomeActive     = -1
local navHomeInactive   = -1
local navShopActive     = -1
local navShopInactive   = -1
local homeNavTab        = 2      -- 当前选中 Tab：1=排行榜 2=首页 3=商店
-- 游戏界面 AI 素材
local gameBossImage    = -1      -- 老板角色图
local gameToolHammer   = -1      -- 道具：锤子
local gameToolLightning= -1      -- 道具：闪电
local gameToolRefresh  = -1      -- 道具：刷新
-- 新道具图标
local toolImgElim      = -1      -- 消除道具图标
local toolImgAddtime   = -1      -- 增加时间道具图标（共用 freeze 图标）
local toolImgTransform = -1      -- 变化道具图标
local toolImgFreeze    = -1      -- 冻结道具图标
local toolImgReset     = -1      -- 重置道具图标

-- 开局道具选择弹窗状态
local showLevelStartPopup  = false
local levelStartSelected   = { elim = false, addtime = false }  -- 已选中状态
local levelStartPopupRects = {}   -- 命中区（每帧重建）
local pendingElimAtStart   = 0    -- 开局待执行消除次数（进入游戏后首帧触发）
local gameCardBg       = -1      -- 卡片格子背景纹理
local gameHudBg        = -1      -- HUD 顶栏背景
local iconCoin         = -1      -- 顶栏：金币图标
local iconGem       = -1         -- 顶栏：钻石图标
local iconSettings  = -1         -- 顶栏：设置图标
local splashTimer   = 0.0        -- 加载条已播放时长
local SPLASH_DUR    = 2.2        -- 加载条总时长（秒）
local homeWinStreak = 0          -- 主界面连胜纪录展示（过关后累加）
local homeToastMsg  = ""         -- 主界面提示文字
local homeToastTimer = 0.0       -- 提示剩余显示时长

-- ============================================================
-- 玩家资产（金币 + 道具库存），通过存档持久化
-- ============================================================
local playerCoins  = 2000        -- 玩家金币数（初始2000）
local toolCounts   = { elim=0, addtime=0, transform=0, freeze=0, reset=0 }

-- ============================================================
-- 游戏内道具运行状态
-- ============================================================
local freezeTimer       = 0.0   -- 冻结剩余秒数
local activeToolMode    = nil   -- nil | "transform_select"（变化选择模式）
local toolBtnRects      = {}    -- 游戏内道具按钮命中区 [{x,y,w,h,key}]
local shopBuyRects      = {}    -- 商店购买按钮命中区 [{x,y,w,h,key,price}]
local shopScrollOffset  = 0.0   -- 商店滚动偏移（备用）

-- 道具定义（价格/名称/描述）
local TOOL_DEFS = {
    { key="elim",      name="消除",   desc="消除一组相同物品",          price=500,  img=nil },
    { key="addtime",   name="增加时间", desc="开局增加60秒时间",          price=700,  img=nil },
    { key="transform", name="变化",   desc="选中1种，其余2组变为同类",  price=800,  img=nil },
    { key="freeze",    name="冻结",   desc="冻结倒计时30秒",             price=600,  img=nil },
    { key="reset",     name="重置",   desc="按规则重新生成本关物品",     price=1000, img=nil },
}

-- ============================================================================
-- 玩家存档：保存 / 加载 金币 + 道具库存
-- ============================================================================
local SAVE_FILE = "save_player.json"

local function SavePlayerData()
    local ok, cjson = pcall(require, "cjson")
    if not ok then return end
    local data = {
        coins = playerCoins,
        tools = toolCounts,
        level = currentLevel,
    }
    local file = File(SAVE_FILE, FILE_WRITE)
    if file:IsOpen() then
        file:WriteString(cjson.encode(data))
        file:Close()
    end
end

local function LoadPlayerData()
    local ok, cjson = pcall(require, "cjson")
    if not ok then return end
    if not fileSystem:FileExists(SAVE_FILE) then return end
    local file = File(SAVE_FILE, FILE_READ)
    if not file:IsOpen() then return end
    local raw = file:ReadString()
    file:Close()
    local ok2, data = pcall(cjson.decode, raw)
    if not ok2 or type(data) ~= "table" then return end
    if type(data.coins) == "number" then
        playerCoins = math.max(data.coins, 200)  -- 兜底：至少保留 200 金币
    end
    if type(data.tools) == "table" then
        for _, key in ipairs({"elim","addtime","transform","freeze","reset"}) do
            if type(data.tools[key]) == "number" then
                toolCounts[key] = data.tools[key]
            end
        end
    end
    if type(data.level) == "number" and data.level >= 1 then
        currentLevel = math.min(data.level, MAX_LEVEL)
    end
end

-- 固定柜子尺寸（每个文件柜单元）
local FIXED_CELL_W = 120
local FIXED_CELL_H = 80

local boardX, boardY = 0, 0
local cellW, cellH   = FIXED_CELL_W, FIXED_CELL_H
local itemSize  = 0
local itemH     = 0

---@type table
local grid          = {}
local activeCellList = {}   -- 当前关卡所有有效格子坐标列表，供道具重置使用
local score      = 0
local gameWin    = false
local elimFlashes = {}
local elimAnims   = {}   -- 消除爆炸动画：{x,y,def,scale,alpha,vy,timer}
local pendingCollapses = {}  -- 延迟塌陷：{r,c,delay}
local collapseJustDone = false  -- 本帧是否有塌陷完成（用于触发 CheckWin）

local drag = {
    active = false, srcR=0, srcC=0, srcS=0,
    itemId="", mx=0, my=0, hoverR=0, hoverC=0,
}
local activeTouchId = -1

-- 特效状态
local burstParticles = {}  -- 粒子爆发
local expandRings    = {}  -- 扩散光环
local scorePopups    = {}  -- 分数弹出

-- 道具专属特效状态
-- elimWave: 消除锤击波 {x,y,r,maxR,life,maxLife}
-- transformSwirls: 变化漩涡粒子 [{x,y,vx,vy,r,g,b,size,life,maxLife,angle}]
-- freezeIce: 冻结冰晶 [{x,y,r,g,b,life,maxLife,angle,size}]
-- resetFlash: 重置全屏闪光 {life,maxLife}
-- boardShake: 棋盘震动 {x,y,life,maxLife}
-- gridOverlay: 棋盘格子高亮波浪 [{r,c,life,maxLife,cr,cg,cb}]
local elimWave        = nil
local transformSwirls = {}
local freezeIce       = {}
local resetFlash      = nil
local boardShake      = nil   -- {ox,oy,life,maxLife}
local gridOverlay     = {}    -- 格子叠加高亮

-- 布局区域（每帧动态计算）
local animAreaH  = 0
local toolsAreaH = 0

-- Boss 位置（每帧在 HandleNanoVGRender 中更新）
local bossCX = 0
local bossCY = 0

-- Boss 状态（总物品数 = 每个消除1点伤害）
local bossMaxHP    = COLS * ROWS * SLOTS * 2  -- 72
local bossHP       = bossMaxHP
local bossHitTimer = 0.0  -- 受击动画倒计时（秒）

-- 向 Boss 飞行的物品列表
-- 每项: {sx,sy,ex,ey,t,speed,delay,def}
local flyItems = {}

-- 关卡状态
local currentLevel = 1           -- 当前关卡（1-based）
local totalScore   = 0           -- 跨关累计总分

-- 过关动画状态
local levelClearAnim  = false    -- 是否正在播放过关动画
local levelClearTimer = 0.0      -- 过关动画倒计时
local activeGrid = {}            -- activeGrid[r][c]=true 表示该格子在当前形状中有效

-- 倒计时（每关从 LEVEL_DEFS[currentLevel].time 开始）
local timeLeft    = LEVEL_DEFS[1].time  -- 剩余秒数（浮点）
local gameOver    = false               -- 超时失败标志
local timerWarnTimer = 0.0             -- 低时间数字抖动计时器
local showLevelTable = false           -- 是否显示关卡表面板
gamePaused     = false           -- 游戏是否暂停
showExitConfirm = false          -- 是否显示退出确认对话框

-- ============================================================================
-- 结算界面状态
-- ============================================================================
local SETTLE_MULTS     = {2, 3, 5, 3, 2}  -- 倍率条选项
local SETTLE_COLS      = {            -- 各格配色（橙/黄/绿/黄/橙）
    {220,80,30},  {240,160,20},  {60,190,60},  {240,160,20},  {220,80,30},
}
local showSettlement       = false    -- 是否显示结算界面
local settleClearedLevel   = 1        -- 刚通过的关卡号
local settleBaseCoins      = 10       -- 直接领取金币数
local settleMultIdx        = 3        -- 倍率条当前指向（1-5）
local settleAnimTimer      = 0.0      -- 倍率滚动动画剩余时间
local settleAnimating      = false    -- 是否正在滚动
local settleStepAccum      = 0.0      -- 步进累计计时器（用于控制每格切换间隔）
local settleBtnRects       = {}       -- 结算按钮命中区

-- 宝箱进度（每5关一次，0-4循环）
local chestProgress        = 0        -- 当前进度（0=刚领过宝箱或初始）
local showChestPopup       = false    -- 是否显示宝箱弹窗
local chestRewardCoins     = 0        -- 宝箱金币奖励
local chestRewardToolKey   = nil      -- 宝箱道具奖励 key
local chestPopupBtnRect    = {}       -- 宝箱领取按钮命中区
local imageGem             = -1       -- 结算宝石图标

-- ============================================================================
-- 布局工具
-- ============================================================================
local function CellRect(r, c)
    local x = boardX + (c-1) * (cellW + SHELF_GAP)
    local y = boardY + (r-1) * (cellH + SHELF_GAP)
    -- 移动格子：叠加实时偏移
    if grid and grid[r] and grid[r][c] then
        local cell = grid[r][c]
        x = x + (cell.moveOffsetX or 0)
        y = y + (cell.moveOffsetY or 0)
    end
    return x, y, cellW, cellH
end

local function HitCell(mx, my)
    for r = 1, ROWS do
        for c = 1, COLS do
            if not activeGrid[r] or not activeGrid[r][c] then goto hc_skip end
            local x, y, w, h = CellRect(r, c)
            if mx >= x and mx <= x+w and my >= y and my <= y+h then
                return r, c
            end
            ::hc_skip::
        end
    end
    return 0, 0
end

local function HitSlot(mx, my, r, c)
    local x, y, w, h = CellRect(r, c)
    if mx < x or mx > x+w or my < y or my > y+h then return 0 end
    local pad    = w * 0.06
    local usable = w - pad * 2
    local sw     = usable / SLOTS
    local relX   = mx - x - pad
    local s      = math.floor(relX / sw) + 1
    return math.max(1, math.min(SLOTS, s))
end

-- ============================================================================
-- 层矩阵操作
-- ============================================================================
local function CollapseIfEmpty(r, c)
    local cell = grid[r][c]
    while #cell.layers > 0 do
        local layer = cell.layers[1]
        local allNil = true
        for s = 1, SLOTS do
            if layer[s] then allNil = false; break end
        end
        if allNil then
            table.remove(cell.layers, 1)
        else break end
    end
end

local function FindEmptyFrontSlot(r, c)
    local cell = grid[r][c]
    if #cell.layers == 0 then return 1 end
    for s = 1, SLOTS do
        if not cell.layers[1][s] then return s end
    end
    return 0
end

-- ============================================================================
-- 道具专属特效生成函数
-- ============================================================================

-- 消除道具特效：以棋盘中心为圆心的冲击波 + 屏幕震动
local function SpawnElimToolEffect()
    -- 棋盘中心
    local bx = (screenW - (COLS * (gridW and gridW or 60))) * 0.5
    local by = HEADER_H + (animAreaH or 0) + 8
    local gw = screenW - bx * 2
    local gh = screenH - by - (toolsAreaH or 0) - 8
    local cx2 = bx + gw * 0.5
    local cy2 = by + gh * 0.5
    elimWave = { x=cx2, y=cy2, r=10, maxR=math.max(gw, gh)*0.75, life=0.55, maxLife=0.55 }
    -- 屏幕震动
    boardShake = { life=0.35, maxLife=0.35 }
    -- 16颗金色星芒从中心爆发
    for i = 1, 16 do
        local ang   = (i-1) * math.pi * 2 / 16
        local spd   = 140 + math.random()*100
        local life2 = 0.5 + math.random()*0.2
        table.insert(burstParticles, {
            x=cx2, y=cy2,
            vx=math.cos(ang)*spd, vy=math.sin(ang)*spd,
            r=255, g=200+math.random(50), b=30,
            life=life2, maxLife=life2,
            size=6+math.random()*5, isStar=true,
        })
    end
end

-- 变化道具特效：全棋盘彩虹漩涡粒子 + 每格闪烁高亮
local function SpawnTransformToolEffect()
    local bx = (screenW - (COLS * (gridW and gridW or 60))) * 0.5
    local by = HEADER_H + (animAreaH or 0) + 8
    local gw = screenW - bx * 2
    local gh = screenH - by - (toolsAreaH or 0) - 8
    local cx2 = bx + gw * 0.5
    local cy2 = by + gh * 0.5
    -- 漩涡粒子：从外圈螺旋向中心聚拢
    local RAINBOW = {
        {255,80,80},{255,160,40},{255,230,40},
        {80,220,80},{40,180,255},{160,80,255},
    }
    for i = 1, 48 do
        local ang    = (i-1) * math.pi * 2 / 48
        local dist   = math.min(gw, gh) * 0.45 * (0.6 + math.random()*0.4)
        local sx     = cx2 + math.cos(ang)*dist
        local sy     = cy2 + math.sin(ang)*dist
        -- 速度指向中心 + 切线旋转分量
        local toX    = cx2 - sx
        local toY    = cy2 - sy
        local len    = math.sqrt(toX*toX + toY*toY) + 0.001
        local speed  = 220 + math.random()*120
        local col    = RAINBOW[(i % #RAINBOW)+1]
        local life2  = 0.6 + math.random()*0.25
        table.insert(transformSwirls, {
            x=sx, y=sy,
            vx=(toX/len + math.sin(ang)*0.5)*speed,
            vy=(toY/len - math.cos(ang)*0.5)*speed,
            r=col[1], g=col[2], b=col[3],
            size=4+math.random()*4,
            life=life2, maxLife=life2,
        })
    end
    -- 每个活动格子波浪高亮（延迟依距离中心从近到远）
    for r = 1, ROWS do
        for c = 1, COLS do
            if activeGrid[r] and activeGrid[r][c] then
                local cx3, cy3, cw3, ch3 = CellRect(r, c)
                local cellCX = cx3 + cw3*0.5
                local cellCY = cy3 + ch3*0.5
                local dist2  = math.sqrt((cellCX-cx2)^2+(cellCY-cy2)^2)
                local delay  = dist2 / 400  -- 按距离延迟
                local col2   = RAINBOW[(math.random(#RAINBOW))]
                table.insert(gridOverlay, {
                    r=r, c=c, life=0.55-delay, maxLife=0.55,
                    cr=col2[1], cg=col2[2], cb=col2[3],
                })
            end
        end
    end
end

-- 冻结道具特效：冰晶粒子从棋盘四角汇聚 + 蓝色全格叠加
local function SpawnFreezeToolEffect()
    local bx = (screenW - (COLS * (gridW and gridW or 60))) * 0.5
    local by = HEADER_H + (animAreaH or 0) + 8
    local gw = screenW - bx * 2
    local gh = screenH - by - (toolsAreaH or 0) - 8
    local cx2 = bx + gw * 0.5
    local cy2 = by + gh * 0.5
    -- 从四角射出冰晶
    local corners = {
        {bx, by}, {bx+gw, by}, {bx, by+gh}, {bx+gw, by+gh}
    }
    for _, corner in ipairs(corners) do
        for i = 1, 10 do
            local ang   = math.atan2(cy2-corner[2], cx2-corner[1]) + (math.random()-0.5)*1.2
            local spd   = 180 + math.random()*100
            local life2 = 0.45 + math.random()*0.2
            table.insert(freezeIce, {
                x=corner[1], y=corner[2],
                vx=math.cos(ang)*spd, vy=math.sin(ang)*spd,
                r=160, g=220, b=255,
                size=3+math.random()*5,
                life=life2, maxLife=life2,
                angle=math.random()*math.pi*2,
            })
        end
    end
    -- 所有活动格子蓝色叠加（稍带延迟从外到内）
    for r = 1, ROWS do
        for c = 1, COLS do
            if activeGrid[r] and activeGrid[r][c] then
                local cx3, cy3, cw3, ch3 = CellRect(r, c)
                local cellCX = cx3 + cw3*0.5
                local cellCY = cy3 + ch3*0.5
                local dist2  = math.sqrt((cellCX-cx2)^2+(cellCY-cy2)^2)
                local delay  = dist2 / 500
                table.insert(gridOverlay, {
                    r=r, c=c, life=0.6-delay, maxLife=0.6,
                    cr=80, cg=180, cb=255,
                })
            end
        end
    end
end

-- 重置道具特效：全屏白色闪光 + 每格随机顺序闪烁
local function SpawnResetToolEffect()
    resetFlash = { life=0.45, maxLife=0.45 }
    -- 全部格子彩色闪烁（随机顺序）
    local allCells = {}
    for r = 1, ROWS do
        for c = 1, COLS do
            if activeGrid[r] and activeGrid[r][c] then
                table.insert(allCells, {r=r, c=c})
            end
        end
    end
    -- Fisher-Yates shuffle
    for i = #allCells, 2, -1 do
        local j = math.random(1, i)
        allCells[i], allCells[j] = allCells[j], allCells[i]
    end
    local COLORS = {{255,200,50},{50,220,100},{80,160,255},{255,100,200}}
    for i, cell in ipairs(allCells) do
        local delay = (i-1) * 0.025
        local col   = COLORS[((i-1) % #COLORS)+1]
        table.insert(gridOverlay, {
            r=cell.r, c=cell.c,
            life=0.5-delay, maxLife=0.5,
            cr=col[1], cg=col[2], cb=col[3],
        })
    end
    -- 从棋盘中心爆发彩色粒子
    local bx = (screenW - (COLS * (gridW and gridW or 60))) * 0.5
    local by = HEADER_H + (animAreaH or 0) + 8
    local gw = screenW - bx * 2
    local gh = screenH - by - (toolsAreaH or 0) - 8
    local cx2 = bx + gw*0.5
    local cy2 = by + gh*0.5
    local RCOLS = {{255,80,80},{80,255,120},{255,200,40},{80,160,255},{255,80,200}}
    for i = 1, 30 do
        local ang  = (i-1)*math.pi*2/30
        local spd  = 100 + math.random()*150
        local col2 = RCOLS[(i % #RCOLS)+1]
        local life2 = 0.5 + math.random()*0.25
        table.insert(burstParticles, {
            x=cx2, y=cy2,
            vx=math.cos(ang)*spd, vy=math.sin(ang)*spd-30,
            r=col2[1], g=col2[2], b=col2[3],
            life=life2, maxLife=life2,
            size=5+math.random()*4, isStar=(i%3==0),
        })
    end
end

-- ============================================================================
-- 消除特效
-- ============================================================================
local function SpawnBurst(r, c, def)
    local x, y, w, h = CellRect(r, c)
    local cx2 = x + w / 2
    local cy2 = y + h / 2

    -- 14颗彩色粒子向外爆散
    for i = 1, 14 do
        local angle = (i - 1) * (math.pi * 2 / 14) + (math.random() - 0.5) * 0.5
        local speed = 50 + math.random() * 70
        local life  = 0.42 + math.random() * 0.28
        table.insert(burstParticles, {
            x  = cx2, y  = cy2,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed - 25,
            r  = def.r, g = def.g, b = def.b,
            life = life, maxLife = life,
            size = 3.5 + math.random() * 5,
            isStar = false,
        })
    end

    -- 4颗金色闪星
    for _ = 1, 4 do
        local angle = math.random() * math.pi * 2
        local dist  = math.random() * w * 0.28
        local life  = 0.55 + math.random() * 0.20
        table.insert(burstParticles, {
            x  = cx2 + math.cos(angle) * dist,
            y  = cy2 + math.sin(angle) * dist,
            vx = (math.random() - 0.5) * 35,
            vy = -25 - math.random() * 35,
            r  = 255, g = 230, b = 60,
            life = life, maxLife = life,
            size = 5 + math.random() * 4,
            isStar = true,
        })
    end

    -- 扩散光环
    table.insert(expandRings, {
        x    = cx2, y = cy2,
        curR = 8,   maxR = math.max(w, h) * 0.62,
        life = 0.45, maxLife = 0.45,
        cr   = def.r, cg = def.g, cb = def.b,
    })
    -- 白色快速内环
    table.insert(expandRings, {
        x    = cx2, y = cy2,
        curR = 4,   maxR = math.max(w, h) * 0.32,
        life = 0.25, maxLife = 0.25,
        cr   = 255,  cg = 255,  cb = 255,
    })

    -- 分数弹出
    table.insert(scorePopups, {
        x    = cx2, y = cy2 - h * 0.15,
        vy   = -65,
        text = "+100",
        life = 0.88, maxLife = 0.88,
    })

    -- 飞行物品：MATCH 颗物品带延迟飞向 Boss
    for i = 1, MATCH do
        table.insert(flyItems, {
            sx    = cx2,
            sy    = cy2,
            ex    = bossCX,
            ey    = bossCY,
            t     = -(i - 1) * 0.08,  -- 错开 80ms 延迟
            speed = 1.6,
            def   = def,
        })
    end

    -- 每次消除扣 Boss 血量
    bossHP = math.max(0, bossHP - MATCH)
end

local function DrawBurstParticles()
    for _, p in ipairs(burstParticles) do
        local t = p.life / p.maxLife
        local a = math.floor(t * 235)
        nvgFillColor(vg, nvgRGBA(p.r, p.g, p.b, a))
        if p.isStar then
            -- 四角星
            local s = p.size * (0.4 + t * 0.6)
            nvgSave(vg)
            nvgTranslate(vg, p.x, p.y)
            nvgBeginPath(vg)
            for j = 0, 7 do
                local ang = j * math.pi * 0.25
                local rad = (j % 2 == 0) and s or s * 0.36
                local px2 = math.cos(ang) * rad
                local py2 = math.sin(ang) * rad
                if j == 0 then nvgMoveTo(vg, px2, py2)
                else            nvgLineTo(vg, px2, py2) end
            end
            nvgClosePath(vg)
            nvgFill(vg)
            nvgRestore(vg)
        else
            -- 圆点（随生命缩小）
            local s = math.max(1, p.size * (0.3 + t * 0.7))
            nvgBeginPath(vg)
            nvgCircle(vg, p.x, p.y, s)
            nvgFill(vg)
        end
    end
end

local function DrawExpandRings()
    for _, ring in ipairs(expandRings) do
        local progress = 1 - ring.life / ring.maxLife  -- 0→1
        local t        = ring.life / ring.maxLife       -- 1→0
        local rNow     = ring.curR + (ring.maxR - ring.curR) * progress
        local a        = math.floor(t * t * 210)
        nvgStrokeColor(vg, nvgRGBA(ring.cr, ring.cg, ring.cb, a))
        nvgStrokeWidth(vg, math.max(1, 3.5 * t))
        nvgBeginPath(vg)
        nvgCircle(vg, ring.x, ring.y, rNow)
        nvgStroke(vg)
    end
end

local function DrawScorePopups()
    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    for _, p in ipairs(scorePopups) do
        local t  = p.life / p.maxLife
        local a  = math.floor(math.min(1, t * 2.5) * 255)
        local sz = 20 + (1 - t) * 10  -- 随飘动轻微放大
        -- 阴影
        nvgFontSize(vg, sz)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(a * 0.38)))
        nvgText(vg, p.x + 2, p.y + 2, p.text)
        -- 金色主体
        nvgFillColor(vg, nvgRGBA(255, 218, 30, a))
        nvgText(vg, p.x, p.y, p.text)
    end
end

-- ============================================================================
-- 金手指面板绘制 & 交互
-- ============================================================================

-- 金手指按钮定义（每行一组）
local CHEAT_BTNS = {
    { id="coin500",   label="+500金币",   color={255,200,50}  },
    { id="coin2000",  label="+2000金币",  color={255,170,0}   },
    { id="tools5",    label="道具各+5",   color={100,220,120} },
    { id="tools20",   label="道具各+20",  color={60,200,80}   },
    { id="winlevel",  label="直接过关",   color={80,180,255}  },
    { id="addtime",   label="+60秒",      color={160,120,255} },
}
local cheatBtnRects = {}   -- 每帧重建，{x,y,w,h,id}

local function DrawCheatPanel()
    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 右上角入口按钮
    local btnX = screenW - _cheat.btnW - 4
    local btnY = 4
    nvgFillColor(vg, _cheat.visible and nvgRGBA(255,160,0,230) or nvgRGBA(40,40,40,160))
    nvgBeginPath(vg); nvgRoundedRect(vg, btnX, btnY, _cheat.btnW, _cheat.btnH, 6); nvgFill(vg)
    nvgFontSize(vg, 11)
    nvgFillColor(vg, nvgRGBA(255,255,255,240))
    nvgText(vg, btnX + _cheat.btnW * 0.5, btnY + _cheat.btnH * 0.5, "金手指")

    if not _cheat.visible then return end

    -- 面板背景（右侧悬浮卡片）
    local PAD    = 8
    local BW     = math.min(160, screenW * 0.45)  -- 卡片宽
    local BH     = 32                              -- 每个按钮高
    local GAP    = 6
    local totalH = #CHEAT_BTNS * (BH + GAP) - GAP + PAD * 2 + 20
    local panX   = screenW - BW - PAD
    local panY   = btnY + _cheat.btnH + 4

    -- 面板阴影
    nvgFillColor(vg, nvgRGBA(0,0,0,100))
    nvgBeginPath(vg); nvgRoundedRect(vg, panX+3, panY+3, BW, totalH, 10); nvgFill(vg)
    -- 面板主体
    nvgFillColor(vg, nvgRGBA(20,20,35,240))
    nvgBeginPath(vg); nvgRoundedRect(vg, panX, panY, BW, totalH, 10); nvgFill(vg)
    -- 面板边框
    nvgStrokeColor(vg, nvgRGBA(255,160,0,120))
    nvgStrokeWidth(vg, 1.5)
    nvgBeginPath(vg); nvgRoundedRect(vg, panX, panY, BW, totalH, 10); nvgStroke(vg)

    -- 标题
    nvgFontSize(vg, 12)
    nvgFillColor(vg, nvgRGBA(255,200,60,255))
    nvgText(vg, panX + BW * 0.5, panY + PAD + 7, "★ 金手指 ★")

    -- 每个功能按钮
    cheatBtnRects = {}
    local startY = panY + PAD + 20 + GAP
    for i, btn in ipairs(CHEAT_BTNS) do
        local bx = panX + PAD
        local by = startY + (i-1) * (BH + GAP)
        local bw = BW - PAD * 2
        local cr, cg, cb = btn.color[1], btn.color[2], btn.color[3]

        -- 按钮背景
        nvgFillColor(vg, nvgRGBA(cr, cg, cb, 40))
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, BH, 6); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(cr, cg, cb, 160))
        nvgStrokeWidth(vg, 1)
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, BH, 6); nvgStroke(vg)

        -- 按钮文字
        nvgFontSize(vg, 13)
        nvgFillColor(vg, nvgRGBA(cr, cg, cb, 255))
        nvgText(vg, bx + bw * 0.5, by + BH * 0.5, btn.label)

        table.insert(cheatBtnRects, { x=bx, y=by, w=bw, h=BH, id=btn.id })
    end
end

-- 执行金手指操作
local function ExecCheat(id)
    if id == "coin500" then
        playerCoins = playerCoins + 500
        SavePlayerData()
    elseif id == "coin2000" then
        playerCoins = playerCoins + 2000
        SavePlayerData()
    elseif id == "tools5" then
        for _, key in ipairs({"elim","addtime","transform","freeze","reset"}) do
            toolCounts[key] = (toolCounts[key] or 0) + 5
        end
        SavePlayerData()
    elseif id == "tools20" then
        for _, key in ipairs({"elim","addtime","transform","freeze","reset"}) do
            toolCounts[key] = (toolCounts[key] or 0) + 20
        end
        SavePlayerData()
    elseif id == "winlevel" then
        -- 触发过关：清空棋盘
        if appPhase == "game" then
            for r = 1, ROWS do
                for c = 1, COLS do
                    if activeGrid[r] then activeGrid[r][c] = false end
                    if grid[r] and grid[r][c] then
                        grid[r][c].layers = {}
                    end
                end
            end
        end
    elseif id == "addtime" then
        if appPhase == "game" then
            timeLeft = (timeLeft or 0) + 60
        end
    end
end

-- 金手指点击处理（返回 true 表示事件已消费）
local function HandleCheatTap(mx, my)
    -- 入口按钮
    local btnX = screenW - _cheat.btnW - 4
    local btnY = 4
    if mx >= btnX and mx <= btnX + _cheat.btnW and my >= btnY and my <= btnY + _cheat.btnH then
        _cheat.visible = not _cheat.visible
        return true
    end
    if not _cheat.visible then return false end
    -- 功能按钮
    for _, r in ipairs(cheatBtnRects) do
        if mx >= r.x and mx <= r.x+r.w and my >= r.y and my <= r.y+r.h then
            ExecCheat(r.id)
            _cheat.visible = false
            return true
        end
    end
    -- 点击面板外关闭
    _cheat.visible = false
    return false
end

-- ============================================================================
-- 道具专属特效绘制
-- ============================================================================
local function DrawToolEffects()
    -- 1. boardShake 偏移已在调用侧处理（通过 nvgTranslate），这里只绘制覆盖层

    -- 2. 消除冲击波（橙色扩散圆环）
    if elimWave then
        local progress = 1 - elimWave.life / elimWave.maxLife
        local rNow = elimWave.r + (elimWave.maxR - elimWave.r) * progress
        local t    = elimWave.life / elimWave.maxLife
        local a    = math.floor(t * t * 200)
        -- 外环
        nvgStrokeColor(vg, nvgRGBA(255, 180, 30, a))
        nvgStrokeWidth(vg, math.max(1, 6 * t))
        nvgBeginPath(vg); nvgCircle(vg, elimWave.x, elimWave.y, rNow); nvgStroke(vg)
        -- 内环（稍小 + 白色）
        local rInner = rNow * 0.65
        nvgStrokeColor(vg, nvgRGBA(255, 255, 200, math.floor(a * 0.7)))
        nvgStrokeWidth(vg, math.max(1, 3 * t))
        nvgBeginPath(vg); nvgCircle(vg, elimWave.x, elimWave.y, rInner); nvgStroke(vg)
    end

    -- 3. 格子高亮叠加（变化/冻结/重置共用）
    for _, ov in ipairs(gridOverlay) do
        if ov.life > 0 then
            local t = math.max(0, ov.life / ov.maxLife)
            local a = math.floor(math.sin(t * math.pi) * 160)
            if a > 0 then
                local gx, gy, gw2, gh2 = CellRect(ov.r, ov.c)
                nvgFillColor(vg, nvgRGBA(ov.cr, ov.cg, ov.cb, a))
                nvgBeginPath(vg)
                nvgRoundedRect(vg, gx+2, gy+2, gw2-4, gh2-4, 6)
                nvgFill(vg)
            end
        end
    end

    -- 4. 变化漩涡粒子（彩色圆点）
    for _, p in ipairs(transformSwirls) do
        local t = p.life / p.maxLife
        local a = math.floor(t * 230)
        local s = p.size * (0.4 + t * 0.6)
        nvgFillColor(vg, nvgRGBA(p.r, p.g, p.b, a))
        nvgBeginPath(vg); nvgCircle(vg, p.x, p.y, s); nvgFill(vg)
    end

    -- 5. 冻结冰晶粒子（六角星）
    for _, p in ipairs(freezeIce) do
        local t = p.life / p.maxLife
        local a = math.floor(t * 220)
        local s = p.size * (0.5 + t * 0.5)
        nvgSave(vg)
        nvgTranslate(vg, p.x, p.y)
        nvgRotate(vg, p.angle + (1-t) * math.pi * 0.5)
        nvgFillColor(vg, nvgRGBA(p.r, p.g, p.b, a))
        -- 六角星：6个点
        nvgBeginPath(vg)
        for j = 0, 11 do
            local ang2 = j * math.pi / 6
            local rad  = (j % 2 == 0) and s or s * 0.45
            local px2  = math.cos(ang2) * rad
            local py2  = math.sin(ang2) * rad
            if j == 0 then nvgMoveTo(vg, px2, py2)
            else            nvgLineTo(vg, px2, py2) end
        end
        nvgClosePath(vg); nvgFill(vg)
        nvgRestore(vg)
    end

    -- 6. 重置全屏白色闪光
    if resetFlash then
        local t = resetFlash.life / resetFlash.maxLife
        -- 先亮后暗：t=1→最亮，用 sin 曲线
        local a = math.floor(math.sin(t * math.pi) * 180)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, a))
        nvgBeginPath(vg); nvgRect(vg, 0, 0, screenW, screenH); nvgFill(vg)
    end
end

-- 卡通办公物品绘制
-- ============================================================================
-- DrawItem3D: cx/baseY 是物品底部中心，sz 是 slot 宽度
-- 所有物品在 sz×sz 的正方形区域内绘制，保证视觉大小一致
-- tintColor: nil = 正常；非nil = 暗化（后层效果）
-- ============================================================================
local function DrawItem3D(cx, baseY, sz, def, alpha, tintColor)
    local img = itemImages[def.id]
    if not img then return end

    -- 物品显示尺寸：直接用 sz（slotW），不再二次缩小
    local s    = sz
    local imgX = cx - s * 0.5
    local imgY = baseY - s

    nvgSave(vg)

    if tintColor then
        -- 后层物品：只染色，图片按 0.42 系数暗化绘制
        nvgGlobalAlpha(vg, alpha * 0.75)
        local ip = nvgImagePattern(vg, imgX, imgY, s, s, 0, img, 0.42)
        nvgFillPaint(vg, ip)
        nvgBeginPath(vg)
        nvgRect(vg, imgX, imgY, s, s)
        nvgFill(vg)
    else
        -- 正常绘制
        nvgGlobalAlpha(vg, alpha)
        local ip = nvgImagePattern(vg, imgX, imgY, s, s, 0, img, 1.0)
        nvgFillPaint(vg, ip)
        nvgBeginPath(vg)
        nvgRect(vg, imgX, imgY, s, s)
        nvgFill(vg)
    end

    nvgRestore(vg)
end

-- ============================================================
-- (旧 NanoVG 矢量绘制已移除，改用 AI 生成图片)
-- ============================================================
local function _DrawItem3D_unused(cx, baseY, sz, def, alpha, tintColor)
    local id = def.id
    local s  = sz * 0.88
    local L  = cx - s * 0.5
    local T  = baseY - s
    local dk = tintColor and 0.42 or 1.0
    local ga = alpha * (tintColor and 0.75 or 1.0)
    nvgSave(vg)
    nvgGlobalAlpha(vg, ga)
    local R, G, B = math.floor(def.r*dk), math.floor(def.g*dk), math.floor(def.b*dk)
    local function fc(r,g,b,a) nvgFillColor(vg, nvgRGBA(math.floor(r*dk),math.floor(g*dk),math.floor(b*dk),a or 255)) end
    local function sc2(r,g,b,a) nvgStrokeColor(vg, nvgRGBA(math.floor(r*dk),math.floor(g*dk),math.floor(b*dk),a or 255)) end
    local function fillRR(x,y,w,h,r2, cr,cg,cb,ca) fc(cr,cg,cb,ca) nvgBeginPath(vg) nvgRoundedRect(vg,x,y,w,h,r2) nvgFill(vg) end
    local function fillC(x,y,r2, cr,cg,cb,ca) fc(cr,cg,cb,ca) nvgBeginPath(vg) nvgCircle(vg,x,y,r2) nvgFill(vg) end

    if id == "pencil" then
        -- 铅笔：竖向，黄色笔身 + 粉橡皮 + 尖
        local pw, ph = s*0.22, s*0.90
        local px, py = cx - pw*0.5, T + s*0.10
        fillRR(px, py, pw, ph*0.12, 2, 235,110,130)          -- 橡皮
        fillRR(px, py+ph*0.12, pw, ph*0.06, 0, 185,185,195)  -- 金属箍
        fillRR(px, py+ph*0.18, pw, ph*0.62, 2, R,G,B)        -- 笔身
        fc(200,160,95) nvgBeginPath(vg)                        -- 木质尖
        nvgMoveTo(vg,cx,baseY) nvgLineTo(vg,px,py+ph*0.80) nvgLineTo(vg,px+pw,py+ph*0.80) nvgClosePath(vg) nvgFill(vg)
        fc(40,35,25) nvgBeginPath(vg)                          -- 笔芯
        nvgMoveTo(vg,cx,baseY) nvgLineTo(vg,cx-pw*0.18,py+ph*0.92) nvgLineTo(vg,cx+pw*0.18,py+ph*0.92) nvgClosePath(vg) nvgFill(vg)
        -- 高光
        nvgStrokeWidth(vg,1.0) sc2(255,255,255,70) nvgBeginPath(vg) nvgMoveTo(vg,cx-pw*0.22,py+ph*0.20) nvgLineTo(vg,cx-pw*0.22,py+ph*0.76) nvgStroke(vg)

    elseif id == "eraser" then
        -- 橡皮擦：宽矮圆角块
        local ew, eh = s*0.84, s*0.48
        local ex, ey = cx-ew*0.5, baseY-eh-s*0.06
        fillRR(ex, ey, ew, eh, 5, R,G,B)
        fillRR(ex+ew*0.08, ey+eh*0.22, ew*0.84, eh*0.56, 3, 255,255,255,50) -- 标签
        fillRR(ex+3, ey+3, ew-6, eh*0.28, 3, 255,255,255,70)                 -- 高光

    elseif id == "note" then
        -- 便利贴：正方形 + 折角
        local nw, nh = s*0.86, s*0.82
        local nx, ny = cx-nw*0.5, T+s*0.08
        fillRR(nx, ny, nw, nh, 3, R,G,B)
        nvgStrokeWidth(vg,1.1) sc2(0,0,0,50)
        for i=1,3 do
            local ly = ny+nh*(0.30+i*0.19)
            nvgBeginPath(vg) nvgMoveTo(vg,nx+nw*0.12,ly) nvgLineTo(vg,nx+nw*0.88,ly) nvgStroke(vg)
        end
        local fc2=nw*0.20 fc(0,0,0,30) nvgBeginPath(vg)
        nvgMoveTo(vg,nx+nw-fc2,ny+nh) nvgLineTo(vg,nx+nw,ny+nh) nvgLineTo(vg,nx+nw,ny+nh-fc2) nvgClosePath(vg) nvgFill(vg)
        fillRR(nx+2,ny+2,nw-4,nh*0.20,2,255,255,255,65)

    elseif id == "tape" then
        -- 胶带卷：圆环
        local tr = s*0.42
        local ty2 = baseY - tr - s*0.02
        fillC(cx,ty2,tr, R,G,B)
        nvgStrokeWidth(vg, tr*0.22) sc2(math.max(0,R-30),math.max(0,G-30),math.max(0,B-30))
        nvgBeginPath(vg) nvgCircle(vg,cx,ty2,tr*0.76) nvgStroke(vg)
        fillC(cx,ty2,tr*0.30, 45,40,55,200)   -- 孔
        fillC(cx-tr*0.28,ty2-tr*0.32,tr*0.18, 255,255,255,55) -- 高光

    elseif id == "folder" then
        -- 文件夹：带标签
        local fw, fh = s*0.86, s*0.74
        local fx, fy = cx-fw*0.5, T+s*0.16
        fillRR(fx, fy-fh*0.15, fw*0.40, fh*0.17, 3, R,G,B)  -- 标签
        fillRR(fx, fy, fw, fh, 4, R,G,B)
        fillRR(fx+4,fy+4,fw-8,fh-8,3, 0,0,0,18)
        fillRR(fx+3,fy+3,fw-6,fh*0.20,2, 255,255,255,65)

    elseif id == "notebook" then
        -- 笔记本：带螺旋线圈
        local bw, bh = s*0.72, s*0.86
        local bx, by = cx-bw*0.5+s*0.05, T+s*0.07
        fillRR(bx,by,bw,bh,4, R,G,B)
        fillRR(bx+bw-3,by+4,4,bh-8,2, 235,235,235)  -- 书页侧面
        nvgStrokeWidth(vg,1.0) sc2(255,255,255,65)
        for i=1,4 do nvgBeginPath(vg) nvgMoveTo(vg,bx+bw*0.14,by+bh*(0.28+i*0.15)) nvgLineTo(vg,bx+bw*0.86,by+bh*(0.28+i*0.15)) nvgStroke(vg) end
        nvgStrokeWidth(vg,1.8) sc2(185,185,200)
        for i=0,5 do
            local cy2=by+bh*0.10+i*bh*0.155
            nvgBeginPath(vg) nvgArc(vg,bx-s*0.055,cy2,s*0.055,0,math.pi*2,NVG_CW) nvgStroke(vg)
        end

    elseif id == "stapler" then
        -- 订书机：两段式
        local sw2, sh2 = s*0.84, s*0.52
        local sx2, sy2 = cx-sw2*0.5, baseY-sh2
        fillRR(sx2,sy2+sh2*0.52,sw2,sh2*0.48,4, 75,80,90)     -- 底座
        fillRR(sx2,sy2,sw2,sh2*0.46,4, R,G,B)                  -- 上盖
        fillRR(sx2+sw2*0.08,sy2+sh2*0.38,sw2*0.84,sh2*0.20,0, 195,200,210) -- 金属条
        fillRR(sx2+3,sy2+3,sw2-6,sh2*0.16,3, 255,255,255,65)

    elseif id == "scissors" then
        -- 剪刀：两环 + 交叉刀片
        local scx,scy = cx, baseY-s*0.44
        local hr = s*0.21
        nvgStrokeWidth(vg,s*0.13) sc2(R,G,B)
        fc(255,255,255,45) nvgBeginPath(vg) nvgCircle(vg,scx-s*0.21,scy+s*0.19,hr) nvgFill(vg) nvgStroke(vg)
        nvgBeginPath(vg) nvgCircle(vg,scx+s*0.21,scy+s*0.19,hr) nvgFill(vg) nvgStroke(vg)
        nvgStrokeWidth(vg,s*0.08) sc2(188,193,205)
        nvgLineCap(vg,NVG_ROUND)
        nvgBeginPath(vg) nvgMoveTo(vg,scx-s*0.28,scy+s*0.02) nvgLineTo(vg,scx+s*0.18,scy-s*0.40) nvgStroke(vg)
        nvgBeginPath(vg) nvgMoveTo(vg,scx+s*0.28,scy+s*0.02) nvgLineTo(vg,scx-s*0.18,scy-s*0.40) nvgStroke(vg)
        fillC(scx,scy-s*0.17,s*0.055, 200,200,210)

    elseif id == "coffee" or id == "mug" then
        -- 咖啡杯 / 马克杯
        local cw = s*(id=="mug" and 0.58 or 0.56)
        local ch = s*(id=="mug" and 0.66 or 0.54)
        local cx2,cy2 = cx-cw*0.5, baseY-ch-s*0.06
        if id=="coffee" then fillRR(cx2-s*0.06,baseY-s*0.10,cw+s*0.12,s*0.11,3, 205,195,180) end -- 碟子
        fillRR(cx2,cy2,cw,ch,5, R,G,B)
        nvgStrokeWidth(vg,s*0.09) sc2(R,G,B)
        nvgBeginPath(vg) nvgArc(vg,cx2+cw+s*0.04,cy2+ch*0.36,ch*0.27,-math.pi*0.5,math.pi*0.5,NVG_CW) nvgStroke(vg)
        fillRR(cx2+3,cy2+3,cw-6,ch*0.30,3, 70,42,20)       -- 咖啡
        fillRR(cx2+3,cy2+3,cw-6,ch*0.17,2, 255,255,255,60) -- 高光

    elseif id == "stamp" then
        -- 印章：把手 + 印体
        local stw,sth = s*0.54,s*0.74
        local stx,sty = cx-stw*0.5, T+s*0.12
        fillRR(stx+stw*0.25,sty,stw*0.50,sth*0.50,4, 140,100,70)
        fillRR(stx+stw*0.08,sty+sth*0.40,stw*0.84,sth*0.12,3, 115,82,52)
        fillRR(stx,sty+sth*0.52,stw,sth*0.48,4, R,G,B)
        fillRR(stx+3,baseY-sth*0.20,stw-6,sth*0.13,2, math.max(0,R-45),math.max(0,G-45),math.max(0,B-45))

    elseif id == "clips" then
        -- 回形针：两个重叠 S 形
        nvgStrokeWidth(vg,s*0.10) nvgLineCap(vg,NVG_ROUND)
        local function drawClip(ox,oy,sc3)
            local cr2=s*0.135*sc3
            sc2(R,G,B)
            nvgBeginPath(vg) nvgArc(vg,cx+ox,baseY-s*0.26+oy-cr2,cr2*1.55,math.pi*0.5,math.pi*1.5,NVG_CCW) nvgStroke(vg)
            nvgBeginPath(vg) nvgArc(vg,cx+ox,baseY-s*0.26+oy+cr2,cr2,math.pi*1.5,math.pi*0.5,NVG_CCW) nvgStroke(vg)
            nvgBeginPath(vg) nvgMoveTo(vg,cx+ox+cr2*1.55,baseY-s*0.26+oy-cr2) nvgLineTo(vg,cx+ox+cr2,baseY-s*0.26+oy+cr2) nvgStroke(vg)
        end
        drawClip(-s*0.13,0,1.0) drawClip(s*0.08,s*0.04,0.86)

    elseif id == "ruler" then
        -- 直尺：长条 + 刻度
        local rw, rh = s*0.88, s*0.34
        local rx, ry = cx-rw*0.5, baseY-rh-s*0.10
        fillRR(rx,ry,rw,rh,3, R,G,B)
        fillRR(rx,ry+rh-3,rw,3,0, math.max(0,R-30),math.max(0,G-30),math.max(0,B-30)) -- 底边
        nvgStrokeWidth(vg,0.9) sc2(60,50,30,160)
        for i=0,8 do
            local lx=rx+rw*(i/8.0)
            local th=(i%4==0) and rh*0.52 or rh*0.32
            nvgStrokeWidth(vg,(i%4==0) and 1.2 or 0.8)
            nvgBeginPath(vg) nvgMoveTo(vg,lx,ry+rh*0.08) nvgLineTo(vg,lx,ry+rh*0.08+th) nvgStroke(vg)
        end
        fillRR(rx+2,ry+2,rw-4,rh*0.26,2, 255,255,255,60)

    elseif id == "calculator" then
        -- 计算器：深色机身 + 屏幕 + 按键
        local caw,cah = s*0.74,s*0.88
        local cax,cay = cx-caw*0.5, T+s*0.06
        fillRR(cax,cay,caw,cah,6, 55,55,65)
        fillRR(cax+caw*0.10,cay+cah*0.07,caw*0.80,cah*0.21,3, 135,172,118) -- 屏幕
        local bw2,bh2 = caw*0.20,cah*0.10
        local bsx,bsy = caw*0.09,cah*0.35
        local bgx=(caw-2*bsx-3*bw2)/2
        local bgy=(cah*0.58-4*bh2)/3
        local btnC={{200,200,210},{200,200,210},{200,200,210},{200,200,210},{200,200,210},{200,200,210},{200,200,210},{200,200,210},{200,200,210},{245,162,55},{245,162,55},{88,175,240}}
        for row=0,3 do for col=0,2 do
            local bc=btnC[row*3+col+1] or {200,200,210}
            fillRR(cax+bsx+col*(bw2+bgx),cay+bsy+row*(bh2+bgy),bw2,bh2,2,bc[1],bc[2],bc[3])
        end end

    elseif id == "ballpen" then
        -- 圆珠笔：细长笔身
        local pw2,ph2 = s*0.17,s*0.88
        local px2,py2 = cx-pw2*0.5, T+s*0.04
        fillRR(px2,py2,pw2,ph2*0.80,3, R,G,B)
        fillRR(px2+pw2,py2+ph2*0.03,pw2*0.26,ph2*0.34,1, 180,180,200) -- 夹
        fillRR(px2,py2,pw2,ph2*0.08,3, math.min(255,R+40),math.min(255,G+40),math.min(255,B+40)) -- 顶帽
        fc(55,50,60) nvgBeginPath(vg)
        nvgMoveTo(vg,cx,baseY) nvgLineTo(vg,px2,py2+ph2*0.80) nvgLineTo(vg,px2+pw2,py2+ph2*0.80) nvgClosePath(vg) nvgFill(vg)
        nvgStrokeWidth(vg,1.1) sc2(255,255,255,75)
        nvgBeginPath(vg) nvgMoveTo(vg,cx-pw2*0.20,py2+ph2*0.10) nvgLineTo(vg,cx-pw2*0.20,py2+ph2*0.72) nvgStroke(vg)

    elseif id == "highlighter" then
        -- 荧光笔：粗方形笔
        local hw,hh = s*0.30,s*0.82
        local hx,hy = cx-hw*0.5, T+s*0.06
        fillRR(hx,hy+hh*0.13,hw,hh*0.74,5, R,G,B)
        fillRR(hx-hw*0.04,hy,hw*1.08,hh*0.16,5, math.max(0,R-45),math.max(0,G-45),math.max(0,B-45)) -- 笔帽
        fillRR(hx+hw*0.08,hy+hh*0.87,hw*0.84,hh*0.13,3, 215,195,155) -- 笔头
        fillRR(hx+hw*0.14,hy+hh*0.17,hw*0.22,hh*0.60,2, 255,255,255,78)

    elseif id == "binder_clip" then
        -- 燕尾夹：梯形夹体 + 两根钢丝把手
        local bw2,bh2 = s*0.58,s*0.40
        local bx,by = cx-bw2*0.5, baseY-bh2-s*0.12
        fc(R,G,B) nvgBeginPath(vg)
        nvgMoveTo(vg,bx,by+bh2) nvgLineTo(vg,bx+bw2,by+bh2)
        nvgLineTo(vg,bx+bw2*0.72,by) nvgLineTo(vg,bx+bw2*0.28,by) nvgClosePath(vg) nvgFill(vg)
        -- 两根钢丝
        nvgStrokeWidth(vg,s*0.075) sc2(140,140,155)
        nvgBeginPath(vg) nvgMoveTo(vg,bx+bw2*0.32,by) nvgLineTo(vg,bx-bw2*0.04,by-bh2*0.72) nvgLineTo(vg,cx-bw2*0.06,by-bh2*1.0) nvgStroke(vg)
        nvgBeginPath(vg) nvgMoveTo(vg,bx+bw2*0.68,by) nvgLineTo(vg,bx+bw2*1.04,by-bh2*0.72) nvgLineTo(vg,cx+bw2*0.06,by-bh2*1.0) nvgStroke(vg)

    elseif id == "correction" then
        -- 涂改液：白色小瓶
        local cw2,ch2 = s*0.34,s*0.76
        local cx3,cy3 = cx-cw2*0.5, T+s*0.10
        fillRR(cx3+cw2*0.28,cy3,cw2*0.44,ch2*0.15,3, 220,220,225) -- 瓶盖
        fillRR(cx3,cy3+ch2*0.14,cw2,ch2*0.86,5, 240,240,242)      -- 瓶身
        fillRR(cx3+cw2*0.12,cy3+ch2*0.20,cw2*0.28,ch2*0.50,2, 255,255,255,90) -- 高光
        nvgStrokeWidth(vg,0.8) sc2(180,180,185,180)
        nvgBeginPath(vg) nvgRoundedRect(vg,cx3,cy3+ch2*0.14,cw2,ch2*0.86,5) nvgStroke(vg)

    elseif id == "marker" then
        -- 马克笔：圆柱笔身
        local mw,mh = s*0.26,s*0.82
        local mx,my = cx-mw*0.5, T+s*0.05
        fillRR(mx,my+mh*0.14,mw,mh*0.72,s*0.13, R,G,B)
        fillRR(mx-mw*0.04,my,mw*1.08,mh*0.17,s*0.13, math.max(0,R-40),math.max(0,G-40),math.max(0,B-40)) -- 帽
        fillRR(mx+mw*0.12,my+mh*0.86,mw*0.76,mh*0.14,3, 60,50,45) -- 笔头
        fillRR(mx+mw*0.15,my+mh*0.18,mw*0.20,mh*0.58,2, 255,255,255,75)

    elseif id == "pushpin" then
        -- 图钉：圆头 + 针
        local pr = s*0.30
        local px2,py2 = cx, T+s*0.08+pr
        fillC(px2,py2,pr, R,G,B)
        fillC(px2-pr*0.28,py2-pr*0.32,pr*0.18, 255,255,255,65) -- 高光
        nvgStrokeWidth(vg,s*0.055) sc2(160,155,165)
        nvgBeginPath(vg) nvgMoveTo(vg,cx,py2+pr*0.70) nvgLineTo(vg,cx,baseY) nvgStroke(vg) -- 针

    elseif id == "lamp" then
        -- 台灯：底座 + 灯臂 + 灯罩
        local lbw = s*0.56
        fillRR(cx-lbw*0.5,baseY-s*0.10,lbw,s*0.10,3, 90,85,100) -- 底座
        nvgStrokeWidth(vg,s*0.07) sc2(100,96,112)
        nvgBeginPath(vg) nvgMoveTo(vg,cx-s*0.04,baseY-s*0.10) nvgLineTo(vg,cx-s*0.18,T+s*0.36) nvgStroke(vg) -- 灯臂
        fc(R,G,B) nvgBeginPath(vg) -- 灯罩（梯形）
        nvgMoveTo(vg,cx-s*0.18,T+s*0.36) nvgLineTo(vg,cx-s*0.36,T+s*0.50)
        nvgLineTo(vg,cx+s*0.18,T+s*0.50) nvgLineTo(vg,cx,T+s*0.36) nvgClosePath(vg) nvgFill(vg)
        fillRR(cx-s*0.36,T+s*0.46,s*0.54,s*0.06,2, math.max(0,R-40),math.max(0,G-40),math.max(0,B-40))
        -- 光晕
        local glowPaint = nvgRadialGradient(vg,cx-s*0.09,T+s*0.54,0,s*0.30, nvgRGBA(255,240,150,60), nvgRGBA(255,240,150,0))
        nvgFillPaint(vg,glowPaint) nvgBeginPath(vg) nvgRect(vg,cx-s*0.38,T+s*0.44,s*0.58,s*0.34) nvgFill(vg)

    elseif id == "phone" then
        -- 办公电话：机身 + 话筒
        local pw2,ph2 = s*0.76,s*0.56
        local px2,py2 = cx-pw2*0.5, baseY-ph2-s*0.06
        fillRR(px2,py2,pw2,ph2,6, R,G,B)
        fillRR(px2+pw2*0.06,py2+ph2*0.10,pw2*0.88,ph2*0.36,3, math.min(255,R+30),math.min(255,G+30),math.min(255,B+30)) -- 话筒槽
        -- 按键小点（3×4）
        for row=0,3 do for col=0,2 do
            fillC(px2+pw2*(0.22+col*0.28),py2+ph2*(0.58+row*0.10),s*0.030,200,200,210)
        end end
        fillRR(px2+3,py2+3,pw2-6,ph2*0.22,3, 255,255,255,50)

    elseif id == "plant" then
        -- 植物：花盆 + 茎叶
        local potW,potH = s*0.50,s*0.28
        local potX,potY = cx-potW*0.5, baseY-potH
        fillRR(potX,potY,potW,potH,4, 165,115,75)   -- 花盆
        fillRR(potX+2,potY+2,potW-4,potH*0.38,3, 185,130,88)
        nvgStrokeWidth(vg,s*0.065) sc2(R,G,B)       -- 茎
        nvgBeginPath(vg) nvgMoveTo(vg,cx,potY) nvgLineTo(vg,cx,T+s*0.42) nvgStroke(vg)
        -- 三片叶子
        for _,leaf in ipairs({{-1,0.68,0.32},{1,0.52,0.28},{0,0.36,0.24}}) do
            local lx=cx+leaf[1]*s*0.25
            local ly=T+leaf[2]*s
            local lr=s*leaf[3]
            fc(R,G,B) nvgBeginPath(vg) nvgEllipse(vg,lx,ly,lr,lr*0.65) nvgFill(vg)
            nvgStrokeWidth(vg,0.8) sc2(math.max(0,R-40),math.max(0,G-40),math.max(0,B-40),120)
            nvgBeginPath(vg) nvgMoveTo(vg,lx-lr*0.4,ly) nvgLineTo(vg,lx+lr*0.4,ly) nvgStroke(vg)
        end

    elseif id == "calendar" then
        -- 台历：翻页本
        local cw2,ch2 = s*0.82,s*0.74
        local cx4,cy4 = cx-cw2*0.5, T+s*0.12
        fillRR(cx4,cy4,cw2,ch2,4, 235,235,240)           -- 白页
        fillRR(cx4,cy4,cw2,ch2*0.28,4, R,G,B)            -- 红色头部
        fillRR(cx4+3,cy4+3,cw2-6,ch2*0.20,3, 255,255,255,55)
        -- 数字（简化为大圆角块）
        fillRR(cx4+cw2*0.20,cy4+ch2*0.36,cw2*0.60,ch2*0.38,5, R,G,B)
        fc(255,255,255) nvgFontSize(vg,ch2*0.30) nvgFontFace(vg,"sans")
        nvgTextAlign(vg,NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
        nvgText(vg,cx,cy4+ch2*0.56,"28")
        -- 装订孔
        fillC(cx4+cw2*0.28,cy4,s*0.045, 70,65,80)
        fillC(cx4+cw2*0.72,cy4,s*0.045, 70,65,80)
    else
        -- fallback 圆形
        fillC(cx, baseY-s*0.44, s*0.40, R,G,B)
    end

    nvgRestore(vg)
end

local function DrawElimAnims()
    for _, a in ipairs(elimAnims) do
        if not (a.delay and a.delay > 0) and a.alpha > 0 then
            local sz = itemSize * a.scale * 0.9
            DrawItem3D(a.x, a.y, sz, a.def, a.alpha)
        end
    end
end

-- ============================================================================
-- 绘制收纳格（打开的文件柜风格）
-- ============================================================================
local function DrawShelfCell(r, c)
    local x, y, w, h = CellRect(r, c)
    local cell = grid[r][c]

    -- 根据关卡选择风格（每10关换一次，循环5种）
    local styleIdx = (math.floor((currentLevel - 1) / 10) % 5) + 1
    local st  = SHELF_STYLES[styleIdx]
    local ac  = st.accent
    local sh_col = st.shadow

    -- 文件柜尺寸参数（按柜子实际大小等比缩放）
    local wallT = math.max(4, math.floor(w * 0.065))   -- 左右侧板厚度 ~6.5%
    local topH  = math.max(14, math.floor(h * 0.172))  -- 顶部标签条   ~17%
    local baseH = math.max(9,  math.floor(h * 0.109))  -- 底座高度     ~11%
    local rad   = math.max(2, math.floor(w * 0.037))   -- 圆角半径

    -- 开口内部区域
    local inX = x + wallT
    local inY = y + topH
    local inW = w - wallT * 2
    local inH = h - topH - baseH

    -- ── 1. 投影 ──────────────────────────────────────────────
    local shadowOff = math.max(1.2, w * 0.016)
    for i = 1, 3 do
        local off = i * shadowOff
        local a   = 22 - i * 5
        nvgFillColor(vg, nvgRGBA(sh_col[1], sh_col[2], sh_col[3], a))
        nvgBeginPath(vg)
        nvgRoundedRect(vg, x + off, y + off * 1.2, w, h, rad + 1)
        nvgFill(vg)
    end

    -- ── 2. 柜身主体（钢铁灰渐变）────────────────────────────
    local bodyPaint = nvgLinearGradient(vg, x, y, x + w, y,
        nvgRGBA(195, 200, 208, 255),
        nvgRGBA(155, 162, 172, 255))
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, rad)
    nvgFillPaint(vg, bodyPaint)
    nvgFill(vg)

    -- ── 3. 左侧高光边（金属质感）────────────────────────────
    nvgFillColor(vg, nvgRGBA(230, 235, 240, 120))
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, wallT, h, rad)
    nvgFill(vg)

    -- ── 4. 顶部标签条（accent 色）────────────────────────────
    nvgFillColor(vg, nvgRGBA(ac[1], ac[2], ac[3], 255))
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, topH, rad)
    -- 补底部两个直角（标签条底部不需要圆角）
    nvgRect(vg, x, y + topH - rad, w, rad)
    nvgFill(vg)
    -- 标签条顶部高光
    local labelHi = nvgLinearGradient(vg, 0, y, 0, y + topH * 0.6,
        nvgRGBA(255, 255, 255, 70), nvgRGBA(255, 255, 255, 0))
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x + 2, y + 2, w - 4, topH - 2, rad - 1)
    nvgFillPaint(vg, labelHi)
    nvgFill(vg)
    -- 标签条底部分隔线
    nvgStrokeWidth(vg, 1.0)
    nvgStrokeColor(vg, nvgRGBA(ac[1] - 30, ac[2] - 30, ac[3] - 30, 200))
    nvgBeginPath(vg)
    nvgMoveTo(vg, x, y + topH)
    nvgLineTo(vg, x + w, y + topH)
    nvgStroke(vg)

    -- ── 5. 开口内部（浅灰 + 深度阴影）──────────────────────
    -- 内部底色
    local interiorPaint = nvgLinearGradient(vg, inX, inY, inX, inY + inH,
        nvgRGBA(238, 240, 245, 255),
        nvgRGBA(220, 224, 230, 255))
    nvgBeginPath(vg)
    nvgRect(vg, inX, inY, inW, inH)
    nvgFillPaint(vg, interiorPaint)
    nvgFill(vg)
    -- 内部顶部阴影（营造开口深度感）
    local inTopSh  = math.max(6, math.floor(inH * 0.18))
    local inLeftSh = math.max(5, math.floor(inW * 0.12))
    local topShPaint = nvgLinearGradient(vg, 0, inY, 0, inY + inTopSh,
        nvgRGBA(0, 0, 0, 50), nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(vg)
    nvgRect(vg, inX, inY, inW, inTopSh)
    nvgFillPaint(vg, topShPaint)
    nvgFill(vg)
    -- 内部左侧阴影
    local leftShPaint = nvgLinearGradient(vg, inX, 0, inX + inLeftSh, 0,
        nvgRGBA(0, 0, 0, 35), nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(vg)
    nvgRect(vg, inX, inY, inLeftSh, inH)
    nvgFillPaint(vg, leftShPaint)
    nvgFill(vg)

    -- ── 6. 槽位分隔线（内部竖线）────────────────────────────
    local padX    = math.max(2, math.floor(inW * 0.03))
    local usableW = inW - padX * 2
    local slotW   = usableW / SLOTS
    local divGap  = math.max(3, math.floor(inH * 0.05))
    nvgStrokeWidth(vg, 1.0)
    for s = 1, SLOTS - 1 do
        local lx = inX + padX + s * slotW
        nvgStrokeColor(vg, nvgRGBA(170, 175, 185, 140))
        nvgBeginPath(vg)
        nvgMoveTo(vg, lx, inY + divGap)
        nvgLineTo(vg, lx, inY + inH - divGap)
        nvgStroke(vg)
    end

    -- ── 7. 底座（深灰）──────────────────────────────────────
    local baseY = y + h - baseH
    local basePaint = nvgLinearGradient(vg, x, baseY, x, y + h,
        nvgRGBA(130, 136, 145, 255),
        nvgRGBA(105, 110, 118, 255))
    nvgBeginPath(vg)
    nvgRect(vg, x, baseY, w, baseH - rad)
    nvgRoundedRect(vg, x, baseY + 2, w, baseH - 2, rad)
    nvgFillPaint(vg, basePaint)
    nvgFill(vg)

    -- ── 8. 把手（银色圆角条，居中）──────────────────────────
    local handleW = w * 0.45
    local handleH = baseH * 0.42
    local handleX = x + (w - handleW) * 0.5
    local handleY = baseY + (baseH - handleH) * 0.5
    -- 把手背景阴影
    nvgFillColor(vg, nvgRGBA(60, 65, 72, 80))
    nvgBeginPath(vg)
    nvgRoundedRect(vg, handleX + 1, handleY + 2, handleW, handleH, handleH * 0.5)
    nvgFill(vg)
    -- 把手主体
    local handlePaint = nvgLinearGradient(vg, handleX, handleY, handleX, handleY + handleH,
        nvgRGBA(218, 222, 228, 255),
        nvgRGBA(170, 176, 185, 255))
    nvgBeginPath(vg)
    nvgRoundedRect(vg, handleX, handleY, handleW, handleH, handleH * 0.5)
    nvgFillPaint(vg, handlePaint)
    nvgFill(vg)
    -- 把手高光
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 90))
    nvgBeginPath(vg)
    nvgRoundedRect(vg, handleX + 2, handleY + 1, handleW - 4, handleH * 0.45, handleH * 0.4)
    nvgFill(vg)

    -- ── 9. 外描边 ──────────────────────────────────────────
    nvgStrokeWidth(vg, 1.5)
    nvgStrokeColor(vg, nvgRGBA(100, 106, 115, 180))
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, rad)
    nvgStroke(vg)

    -- ── 10. 悬停高亮 ───────────────────────────────────────
    if drag.active and drag.hoverR == r and drag.hoverC == c then
        local canDrop = (FindEmptyFrontSlot(r, c) > 0)
        if canDrop then
            nvgFillColor(vg, nvgRGBA(255, 230, 80, 50))
            nvgBeginPath(vg)
            nvgRect(vg, inX, inY, inW, inH)
            nvgFill(vg)
            nvgStrokeWidth(vg, 2.5)
            nvgStrokeColor(vg, nvgRGBA(255, 210, 40, 230))
        else
            nvgFillColor(vg, nvgRGBA(255, 70, 70, 40))
            nvgBeginPath(vg)
            nvgRect(vg, inX, inY, inW, inH)
            nvgFill(vg)
            nvgStrokeWidth(vg, 2.5)
            nvgStrokeColor(vg, nvgRGBA(255, 70, 70, 200))
        end
        nvgBeginPath(vg)
        nvgRoundedRect(vg, x, y, w, h, rad)
        nvgStroke(vg)
    end

    -- ── 11. 消除闪光 ───────────────────────────────────────
    for _, f in ipairs(elimFlashes) do
        if f.r == r and f.c == c then
            local fa = math.min(1, f.timer * 2)
            nvgFillColor(vg, nvgRGBA(ac[1], ac[2], ac[3], math.floor(fa * 100)))
            nvgBeginPath(vg)
            nvgRect(vg, inX, inY, inW, inH)
            nvgFill(vg)
        end
    end

    -- ── 12. 物品（绘制在开口内部）────────────────────────────
    local pad        = padX
    local sw         = usableW / SLOTS
    -- 前层物品底部贴近内部底边
    local frontBaseY = inY + inH - 3
    -- 后层向上偏移（露出头部约 18%）
    local layerStep  = itemSize * 1.75 * 0.18

    if #cell.layers > 0 then
        local drawFrom = math.min(#cell.layers, 2)
        for d = drawFrom, 1, -1 do
            local isFront = (d == 1)
            local baseY_d = frontBaseY - (d - 1) * layerStep
            local sz      = itemSize * (isFront and 1.0 or 0.95)

            for s = 1, SLOTS do
                local slotCX = inX + pad + (s - 0.5) * sw
                local itemId = cell.layers[d][s]
                if itemId then
                    local isDragging = isFront and drag.active
                        and drag.srcR == r and drag.srcC == c and drag.srcS == s
                    if not isDragging then
                        if isFront then
                            DrawItem3D(slotCX, baseY_d, sz, GetDef(itemId), 1.0)
                        else
                            local tint = nvgRGBA(45, 40, 55, 220)
                            DrawItem3D(slotCX, baseY_d, sz, GetDef(itemId), 1.0, tint)
                        end
                    end
                end
            end
        end
    end

    -- ── 13. 锁定遮罩 ──────────────────────────────────────
    if cell.locked then
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 110))
        nvgBeginPath(vg)
        nvgRect(vg, inX, inY, inW, inH)
        nvgFill(vg)
        -- 锁图标
        local lx = x + w * 0.5
        local ly = y + h * 0.45
        local lw = w * 0.28
        local lh = h * 0.22
        nvgFillColor(vg, nvgRGBA(255, 220, 60, 230))
        nvgBeginPath(vg)
        nvgRoundedRect(vg, lx - lw*0.5, ly, lw, lh, 3)
        nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(255, 220, 60, 230))
        nvgStrokeWidth(vg, lw * 0.22)
        nvgBeginPath(vg)
        nvgArc(vg, lx, ly, lw * 0.32, math.pi, 0, NVG_CCW)
        nvgStroke(vg)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 180))
        nvgBeginPath(vg)
        nvgCircle(vg, lx, ly + lh * 0.4, lw * 0.11)
        nvgFill(vg)
        nvgFontSize(vg, h * 0.18)
        nvgFontFace(vg, "sans")
        nvgFillColor(vg, nvgRGBA(255, 240, 100, 255))
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgText(vg, lx, ly + lh + h * 0.1, tostring(cell.lockCount))
    end

    -- ── 14. 移动方向指示箭头 ──────────────────────────────
    if cell.moveType then
        local ax  = x + w * 0.5
        local ay  = y + topH * 0.5
        local arw = w * 0.16
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 210))
        nvgBeginPath(vg)
        if cell.moveType == "vert" then
            nvgMoveTo(vg, ax,       ay - arw * 0.6)
            nvgLineTo(vg, ax - arw, ay + arw * 0.4)
            nvgLineTo(vg, ax + arw, ay + arw * 0.4)
            nvgClosePath(vg)
            nvgMoveTo(vg, ax,       ay + arw * 0.8)
            nvgLineTo(vg, ax - arw, ay - arw * 0.2)
            nvgLineTo(vg, ax + arw, ay - arw * 0.2)
            nvgClosePath(vg)
        else
            nvgMoveTo(vg, ax - arw * 1.2, ay)
            nvgLineTo(vg, ax - arw * 0.2, ay - arw * 0.8)
            nvgLineTo(vg, ax - arw * 0.2, ay + arw * 0.8)
            nvgClosePath(vg)
            nvgMoveTo(vg, ax + arw * 1.2, ay)
            nvgLineTo(vg, ax + arw * 0.2, ay - arw * 0.8)
            nvgLineTo(vg, ax + arw * 0.2, ay + arw * 0.8)
            nvgClosePath(vg)
        end
        nvgFill(vg)
    end

end

-- ============================================================================
-- 绘制 Boss（卡通愤怒老板）
-- ============================================================================
local function DrawBoss(cx, cy, size)
    -- 受击抖动
    if bossHitTimer > 0 then
        local t = bossHitTimer / 0.32
        cx = cx + math.sin(bossHitTimer * 85) * t * 5.5
        cy = cy + math.sin(bossHitTimer * 65) * t * 2.5
    end

    local headR  = size * 0.27
    local bodyH  = size * 0.42
    local bodyW  = size * 0.50
    local headCY = cy - bodyH * 0.48
    local bodyCY = cy + headR * 0.08

    -- 投影
    nvgBeginPath(vg)
    nvgEllipse(vg, cx, cy + size * 0.43, bodyW * 0.38, size * 0.04)
    nvgFillColor(vg, nvgRGBA(80, 100, 150, 55))
    nvgFill(vg)

    -- 西装身体
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - bodyW/2, bodyCY - bodyH * 0.20, bodyW, bodyH, bodyW * 0.14)
    nvgFillColor(vg, nvgRGBA(38, 55, 108, 255))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(18, 28, 68, 220))
    nvgStrokeWidth(vg, 1.8)
    nvgStroke(vg)

    -- 白色衬衫 V 领
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - bodyW * 0.15, bodyCY - bodyH * 0.16)
    nvgLineTo(vg, cx + bodyW * 0.15, bodyCY - bodyH * 0.16)
    nvgLineTo(vg, cx + bodyW * 0.09, bodyCY + bodyH * 0.26)
    nvgLineTo(vg, cx,                bodyCY + bodyH * 0.06)
    nvgLineTo(vg, cx - bodyW * 0.09, bodyCY + bodyH * 0.26)
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(242, 246, 255, 255))
    nvgFill(vg)

    -- 红色领带
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - bodyW * 0.065, bodyCY - bodyH * 0.08)
    nvgLineTo(vg, cx + bodyW * 0.065, bodyCY - bodyH * 0.08)
    nvgLineTo(vg, cx + bodyW * 0.042, bodyCY + bodyH * 0.17)
    nvgLineTo(vg, cx,                  bodyCY + bodyH * 0.27)
    nvgLineTo(vg, cx - bodyW * 0.042, bodyCY + bodyH * 0.17)
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(215, 42, 42, 255))
    nvgFill(vg)

    -- 头部（肤色）
    nvgBeginPath(vg)
    nvgCircle(vg, cx, headCY, headR)
    nvgFillColor(vg, nvgRGBA(245, 198, 152, 255))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(188, 132, 84, 220))
    nvgStrokeWidth(vg, 1.5)
    nvgStroke(vg)

    -- 头发（深色，遮住头顶）
    nvgSave(vg)
    nvgScissor(vg, cx - headR * 1.3, headCY - headR * 1.3, headR * 2.6, headR * 1.0)
    nvgBeginPath(vg)
    nvgCircle(vg, cx, headCY, headR * 1.01)
    nvgFillColor(vg, nvgRGBA(28, 18, 10, 255))
    nvgFill(vg)
    nvgRestore(vg)

    -- 愤怒眉毛（向中间下斜）
    nvgStrokeColor(vg, nvgRGBA(40, 25, 8, 255))
    nvgStrokeWidth(vg, headR * 0.15)
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - headR * 0.55, headCY - headR * 0.20)
    nvgLineTo(vg, cx - headR * 0.10, headCY - headR * 0.10)
    nvgStroke(vg)
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx + headR * 0.55, headCY - headR * 0.20)
    nvgLineTo(vg, cx + headR * 0.10, headCY - headR * 0.10)
    nvgStroke(vg)

    -- 眼睛
    nvgFillColor(vg, nvgRGBA(40, 30, 18, 255))
    nvgBeginPath(vg); nvgCircle(vg, cx - headR*0.30, headCY + headR*0.05, headR*0.09); nvgFill(vg)
    nvgBeginPath(vg); nvgCircle(vg, cx + headR*0.30, headCY + headR*0.05, headR*0.09); nvgFill(vg)

    -- 嘴（皱眉，向下弯曲）
    nvgStrokeColor(vg, nvgRGBA(148, 85, 52, 220))
    nvgStrokeWidth(vg, headR * 0.11)
    nvgBeginPath(vg)
    nvgMoveTo(vg,  cx - headR * 0.22, headCY + headR * 0.42)
    nvgQuadTo(vg,  cx,                headCY + headR * 0.54,
                   cx + headR * 0.22, headCY + headR * 0.42)
    nvgStroke(vg)

    -- 受击红色闪光
    if bossHitTimer > 0 then
        local flashA = math.floor((bossHitTimer / 0.32) * 155)
        nvgFillColor(vg, nvgRGBA(255, 75, 55, flashA))
        nvgBeginPath(vg); nvgCircle(vg, cx, headCY, headR); nvgFill(vg)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, cx - bodyW/2, bodyCY - bodyH*0.20, bodyW, bodyH, bodyW*0.14)
        nvgFill(vg)
    end

    -- HP 血量条
    local barW = size * 0.78
    local barH = math.max(7.0, headR * 0.30)
    local barX = cx - barW / 2
    local barY = headCY - headR - barH - headR * 0.30

    nvgBeginPath(vg)
    nvgRoundedRect(vg, barX, barY, barW, barH, barH/2)
    nvgFillColor(vg, nvgRGBA(28, 28, 40, 215))
    nvgFill(vg)

    local hpRatio = (bossMaxHP > 0) and (math.max(0, bossHP) / bossMaxHP) or 0
    if hpRatio > 0 then
        local hR, hG, hB
        if     hpRatio > 0.55 then hR,hG,hB = 65,195,72
        elseif hpRatio > 0.28 then hR,hG,hB = 228,172,28
        else                        hR,hG,hB = 218,52,52 end
        nvgFillColor(vg, nvgRGBA(hR, hG, hB, 255))
        nvgBeginPath(vg)
        nvgRoundedRect(vg, barX, barY, barW * hpRatio, barH, barH/2)
        nvgFill(vg)
    end

    nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 88))
    nvgStrokeWidth(vg, 1.0)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, barX, barY, barW, barH, barH/2)
    nvgStroke(vg)

    -- 名字显示在血条内部（文字+阴影，始终可见）
    local nameSize = math.max(10, barH * 0.72)
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, nameSize)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    -- 阴影
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 120))
    nvgText(vg, cx + 1, barY + barH * 0.5 + 1, "老板")
    -- 主文字（白色）
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 240))
    nvgText(vg, cx, barY + barH * 0.5, "老板")
end

-- ============================================================================
-- 绘制动画区（顶部 Boss 区域）
-- ============================================================================
local function DrawAnimArea()
    local y = HEADER_H
    local w = screenW
    local h = animAreaH

    -- 背景渐变（深蓝灰到中蓝，与游戏区形成明显分层）
    local bgPaint = nvgLinearGradient(vg, 0, y, 0, y + h,
        nvgRGBA(60, 90, 150, 255), nvgRGBA(90, 125, 190, 255))
    nvgBeginPath(vg); nvgRect(vg, 0, y, w, h)
    nvgFillPaint(vg, bgPaint); nvgFill(vg)

    -- 底部木质分隔条
    local deskY = y + h - 12
    local deskPaint = nvgLinearGradient(vg, 0, deskY, 0, deskY + 12,
        nvgRGBA(188, 148, 95, 255), nvgRGBA(155, 112, 65, 255))
    nvgBeginPath(vg); nvgRect(vg, 0, deskY, w, 12)
    nvgFillPaint(vg, deskPaint); nvgFill(vg)
    -- 木纹高光线
    nvgStrokeColor(vg, nvgRGBA(220, 185, 130, 120))
    nvgStrokeWidth(vg, 1.0)
    nvgBeginPath(vg); nvgMoveTo(vg, 0, deskY + 2); nvgLineTo(vg, w, deskY + 2); nvgStroke(vg)

    -- ── Boss 角色（AI 图片） ──────────────────────────────────
    local bossSize = h * 0.82
    local bx = bossCX
    local by = bossCY

    -- 受击抖动
    if bossHitTimer > 0 then
        local t = bossHitTimer / 0.32
        bx = bx + math.sin(bossHitTimer * 85) * t * 5.5
        by = by + math.sin(bossHitTimer * 65) * t * 2.5
    end

    -- Boss 阴影
    nvgBeginPath(vg)
    nvgEllipse(vg, bx, deskY + 4, bossSize * 0.22, bossSize * 0.04)
    nvgFillColor(vg, nvgRGBA(60, 80, 120, 55))
    nvgFill(vg)

    -- Boss 图片（透明背景 PNG，居中绘制）
    if gameBossImage > 0 then
        local imgX = bx - bossSize * 0.5
        local imgY = by - bossSize * 0.5
        -- 受击红色叠层
        local bossAlpha = 1.0
        if bossHitTimer > 0 then bossAlpha = 0.7 end
        local ip = nvgImagePattern(vg, imgX, imgY, bossSize, bossSize, 0, gameBossImage, bossAlpha)
        nvgBeginPath(vg); nvgRect(vg, imgX, imgY, bossSize, bossSize)
        nvgFillPaint(vg, ip); nvgFill(vg)
        -- 受击红闪
        if bossHitTimer > 0 then
            local flashA = math.floor((bossHitTimer / 0.32) * 100)
            nvgFillColor(vg, nvgRGBA(255, 60, 60, flashA))
            nvgBeginPath(vg); nvgRect(vg, imgX, imgY, bossSize, bossSize); nvgFill(vg)
        end
    else
        -- 备用：NanoVG 手绘 Boss
        DrawBoss(bx, by, bossSize)
    end

    -- ── HP 血量条（保留） ────────────────────────────────────
    local barW = bossSize * 0.78
    local barH2 = math.max(7.0, bossSize * 0.08)
    local barX = bx - barW / 2
    local barY2 = by - bossSize * 0.56

    nvgBeginPath(vg); nvgRoundedRect(vg, barX, barY2, barW, barH2, barH2/2)
    nvgFillColor(vg, nvgRGBA(28, 28, 40, 215)); nvgFill(vg)

    local hpRatio = (bossMaxHP > 0) and (math.max(0, bossHP) / bossMaxHP) or 0
    if hpRatio > 0 then
        local hR, hG, hB
        if     hpRatio > 0.55 then hR,hG,hB = 65,195,72
        elseif hpRatio > 0.28 then hR,hG,hB = 228,172,28
        else                        hR,hG,hB = 218,52,52 end
        nvgFillColor(vg, nvgRGBA(hR, hG, hB, 255))
        nvgBeginPath(vg)
        nvgRoundedRect(vg, barX, barY2, barW * hpRatio, barH2, barH2/2)
        nvgFill(vg)
    end
    nvgStrokeColor(vg, nvgRGBA(255,255,255,88)); nvgStrokeWidth(vg,1.0)
    nvgBeginPath(vg); nvgRoundedRect(vg, barX, barY2, barW, barH2, barH2/2); nvgStroke(vg)

    -- 名字
    local nameSize = math.max(10, barH2 * 0.72)
    nvgFontFace(vg, "sans"); nvgFontSize(vg, nameSize)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(0,0,0,120))
    nvgText(vg, bx+1, barY2 + barH2*0.5+1, "老板")
    nvgFillColor(vg, nvgRGBA(255,255,255,240))
    nvgText(vg, bx, barY2 + barH2*0.5, "老板")
end

-- ============================================================================
-- 绘制背景（办公室风格）
-- ============================================================================
local function DrawBackground()
    -- 墙面渐变（中深蓝灰，与动画区形成层次）
    local bgPaint = nvgLinearGradient(vg, 0, 0, 0, screenH,
        nvgRGBA(30, 50, 110, 255), nvgRGBA(22, 38, 88, 255))
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillPaint(vg, bgPaint)
    nvgFill(vg)

    -- 微妙格纹（方格纸效果）
    nvgStrokeColor(vg, nvgRGBA(80, 110, 180, 60))
    nvgStrokeWidth(vg, 0.7)
    local gs = 26
    for x = 0, screenW, gs do
        nvgBeginPath(vg)
        nvgMoveTo(vg, x, HEADER_H)
        nvgLineTo(vg, x, screenH)
        nvgStroke(vg)
    end
    for y = HEADER_H, screenH, gs do
        nvgBeginPath(vg)
        nvgMoveTo(vg, 0, y)
        nvgLineTo(vg, screenW, y)
        nvgStroke(vg)
    end

    -- 顶部装饰横条（与 HUD 分割）
    nvgFillColor(vg, nvgRGBA(160, 188, 228, 80))
    nvgBeginPath(vg)
    nvgRect(vg, 0, HEADER_H, screenW, 3)
    nvgFill(vg)
end

-- ============================================================================
-- 绘制 HUD（导航栏）
-- ============================================================================
local function DrawHUD()
    -- HUD 背景：优先使用 AI 图片，备用渐变
    if gameHudBg and gameHudBg > 0 then
        local ip = nvgImagePattern(vg, 0, 0, screenW, HEADER_H, 0, gameHudBg, 1.0)
        nvgBeginPath(vg); nvgRect(vg, 0, 0, screenW, HEADER_H)
        nvgFillPaint(vg, ip); nvgFill(vg)
    else
        local hudPaint = nvgLinearGradient(vg, 0, 0, 0, HEADER_H,
            nvgRGBA(42, 88, 185, 255), nvgRGBA(28, 66, 155, 255))
        nvgBeginPath(vg); nvgRect(vg, 0, 0, screenW, HEADER_H)
        nvgFillPaint(vg, hudPaint); nvgFill(vg)
    end
    -- 底部金色装饰线
    nvgStrokeColor(vg, nvgRGBA(220, 180, 60, 160))
    nvgStrokeWidth(vg, 2)
    nvgBeginPath(vg)
    nvgMoveTo(vg, 0, HEADER_H); nvgLineTo(vg, screenW, HEADER_H)
    nvgStroke(vg)

    -- ── 左侧：倒计时 ────────────────────────────────────────
    local timerCX  = math.floor(44 * uiScale)             -- 计时器水平中心 x（左侧）
    local timerHalfH = math.floor(14 * uiScale)           -- 背景框半高
    local timerBoxW  = math.floor(58 * uiScale)           -- 背景框宽
    local timerBoxH  = timerHalfH * 2
    local timerBoxX  = timerCX - timerBoxW * 0.5
    local secs    = math.ceil(timeLeft)
    local mins    = math.floor(secs / 60)
    local s       = secs % 60
    local timeStr = string.format("%d:%02d", mins, s)

    -- 低于10秒时：数字抖动 + 变红 + 闪烁背景圆
    if timeLeft <= 10 and not gameOver then
        local pulse = math.abs(math.sin(timerWarnTimer * 3.0))
        nvgBeginPath(vg)
        nvgCircle(vg, timerCX, HEADER_H/2, math.floor(20 * uiScale) + pulse * 4)
        nvgFillColor(vg, nvgRGBA(215, 38, 38, math.floor(120 + pulse * 90)))
        nvgFill(vg)
        local shakeX = math.sin(timerWarnTimer * 18) * (1 - timeLeft/10) * 2.5
        local shakeY = math.cos(timerWarnTimer * 23) * (1 - timeLeft/10) * 1.5
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, math.floor(20 * uiScale))
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgText(vg, timerCX + shakeX, HEADER_H/2 + shakeY, timeStr)
    else
        nvgBeginPath(vg)
        nvgRoundedRect(vg, timerBoxX, HEADER_H/2 - timerHalfH, timerBoxW, timerBoxH, 7)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 55))
        nvgFill(vg)
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, math.floor(18 * uiScale))
        nvgFillColor(vg, timeLeft <= 30 and nvgRGBA(255, 185, 55, 255) or nvgRGBA(178, 218, 255, 255))
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgText(vg, timerCX, HEADER_H/2, timeStr)
    end

    -- ── 中间：游戏名 + 关卡号 ────────────────────────────────
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, math.floor(15 * uiScale))
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(vg, screenW * 0.5, HEADER_H * 0.30, "办公室整理")

    -- 关卡号 + 📋 按钮（中间下行）
    nvgFontSize(vg, math.floor(12 * uiScale))
    nvgFillColor(vg, nvgRGBA(255, 218, 80, 255))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(vg, screenW * 0.5, HEADER_H * 0.72, string.format("第 %d / %d 关", currentLevel, MAX_LEVEL))

    -- 📋 关卡表按钮（关卡号右侧）
    local hudMidX  = screenW * 0.5
    local lvLabelW = math.floor(68 * uiScale)
    local btnX     = hudMidX + lvLabelW * 0.5 + math.floor(4 * uiScale)
    local btnY     = HEADER_H * 0.72
    local btnR     = math.floor(9 * uiScale)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, btnX, btnY - btnR, btnR * 2, btnR * 2, 4)
    if showLevelTable then
        nvgFillColor(vg, nvgRGBA(80, 160, 255, 220))
    else
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 40))
    end
    nvgFill(vg)
    nvgFontSize(vg, math.floor(11 * uiScale))
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 230))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(vg, btnX + btnR, btnY, "≡")

    -- ── 右侧：暂停按钮 + 退出按钮 ───────────────────────────
    local hudBtnSize = math.floor(26 * uiScale)   -- 按钮边长
    local hudBtnGap  = math.floor(6  * uiScale)   -- 按钮间距
    local hudBtnY    = (HEADER_H - hudBtnSize) * 0.5  -- 垂直居中

    -- 退出按钮（最右）
    local exitBtnX = screenW - math.floor(10 * uiScale) - hudBtnSize
    -- 暂停按钮（退出左边）
    local pauseBtnX = exitBtnX - hudBtnGap - hudBtnSize

    -- 暂停按钮背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, pauseBtnX, hudBtnY, hudBtnSize, hudBtnSize, 5)
    nvgFillColor(vg, gamePaused and nvgRGBA(60, 140, 255, 220) or nvgRGBA(255, 255, 255, 35))
    nvgFill(vg)
    -- 暂停图标（两条竖线）
    local pb = math.floor(4 * uiScale)
    local ph = math.floor(12 * uiScale)
    local pcx = pauseBtnX + hudBtnSize * 0.5
    local pcy = hudBtnY + hudBtnSize * 0.5
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 230))
    if gamePaused then
        -- 暂停中：显示播放三角形
        nvgBeginPath(vg)
        nvgMoveTo(vg, pcx - pb, pcy - ph * 0.5)
        nvgLineTo(vg, pcx - pb, pcy + ph * 0.5)
        nvgLineTo(vg, pcx + pb + 2, pcy)
        nvgClosePath(vg); nvgFill(vg)
    else
        -- 运行中：显示两条暂停竖线
        nvgBeginPath(vg)
        nvgRect(vg, pcx - pb - 2, pcy - ph * 0.5, pb, ph); nvgFill(vg)
        nvgBeginPath(vg)
        nvgRect(vg, pcx + 2, pcy - ph * 0.5, pb, ph); nvgFill(vg)
    end

    -- 退出按钮背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, exitBtnX, hudBtnY, hudBtnSize, hudBtnSize, 5)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 35))
    nvgFill(vg)
    -- 退出图标（X）
    local ecx = exitBtnX + hudBtnSize * 0.5
    local ecy = hudBtnY + hudBtnSize * 0.5
    local er  = math.floor(6 * uiScale)
    nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 220))
    nvgStrokeWidth(vg, math.max(1.5, 2.0 * uiScale))
    nvgBeginPath(vg)
    nvgMoveTo(vg, ecx - er, ecy - er); nvgLineTo(vg, ecx + er, ecy + er); nvgStroke(vg)
    nvgBeginPath(vg)
    nvgMoveTo(vg, ecx + er, ecy - er); nvgLineTo(vg, ecx - er, ecy + er); nvgStroke(vg)
end

-- ============================================================================
-- 绘制拖拽物品
-- ============================================================================
local function DrawDragItem()
    if not drag.active then return end
    DrawItem3D(drag.mx, drag.my + itemSize*0.20, itemSize*1.15, GetDef(drag.itemId), 1.0)
end

-- ============================================================================
-- 绘制飞行物品（消除后飞向 Boss 的抛物线动画）
-- ============================================================================
local function DrawFlyItems()
    for _, fi in ipairs(flyItems) do
        if fi.t < 0 then goto continue end  -- 还在延迟中
        local prog = fi.t  -- 0→1
        -- 二次贝塞尔曲线：从格子中心飞向 Boss
        local ctrlX = (fi.sx + fi.ex) * 0.5 - (fi.ey - fi.sy) * 0.25
        local ctrlY = math.min(fi.sy, fi.ey) - math.abs(fi.ex - fi.sx) * 0.55 - 40
        local bx = (1-prog)*(1-prog)*fi.sx + 2*(1-prog)*prog*ctrlX + prog*prog*fi.ex
        local by = (1-prog)*(1-prog)*fi.sy + 2*(1-prog)*prog*ctrlY + prog*prog*fi.ey
        -- 缩放：飞近 boss 时缩小
        local sc = 0.72 - prog * 0.38
        local sz = itemSize * sc
        -- 旋转
        nvgSave(vg)
        nvgTranslate(vg, bx, by)
        nvgRotate(vg, prog * math.pi * 2.2)
        DrawItem3D(0, sz * 0.5, sz, fi.def, 1.0 - prog * 0.25)
        nvgRestore(vg)
        ::continue::
    end
end

-- ============================================================================
-- 绘制道具区（底部工具栏，4个新道具）
-- ============================================================================
local function DrawToolsArea()
    local y = screenH - toolsAreaH
    local w = screenW
    local h = toolsAreaH

    toolBtnRects = {}  -- 每帧重建命中区

    -- 半透明深色底栏
    nvgBeginPath(vg); nvgRect(vg, 0, y, w, h)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 120)); nvgFill(vg)
    -- 顶部分隔线
    nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 40)); nvgStrokeWidth(vg, 1.0)
    nvgBeginPath(vg); nvgMoveTo(vg, 0, y); nvgLineTo(vg, w, y); nvgStroke(vg)

    -- 4个道具按钮配置
    local tools = {
        { key="elim",      img=toolImgElim,      name="消除", ring={240,80,80},   inner={40,10,10}  },
        { key="transform", img=toolImgTransform,  name="变化", ring={180,80,240},  inner={28,10,40}  },
        { key="freeze",    img=toolImgFreeze,     name="冻结", ring={80,180,240},  inner={10,25,45}  },
        { key="reset",     img=toolImgReset,      name="重置", ring={80,220,120},  inner={10,35,18}  },
    }

    -- 标签高度（底部文字）
    local labelH   = math.max(math.floor(13 * uiScale), h * 0.18)
    local labelGap = math.floor(5 * uiScale)
    -- 按钮半径：在工具区高度内尽量大，上限 = 原始上限30 × 1.3
    local btnR = math.floor(math.min(
        (h - labelH - labelGap) * 0.5,   -- 填满工具区的极限
        30 * uiScale * 1.3                -- 原上限 × 1.3 = 39
    ))
    btnR = math.max(math.floor(20 * uiScale), btnR)
    local spacing = w / (#tools + 1)
    -- 圆心 Y：圆 + 间隙 + 标签 整体在工具区垂直居中
    local totalH = btnR * 2 + labelGap + labelH
    local cy2    = y + math.floor((h - totalH) * 0.5) + btnR

    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    for i, tool in ipairs(tools) do
        local bx   = math.floor(spacing * i)
        local rr, rg, rb = tool.ring[1], tool.ring[2], tool.ring[3]
        local ir, ig, ib = tool.inner[1], tool.inner[2], tool.inner[3]
        local cnt  = toolCounts[tool.key] or 0
        local isActive = false
        local isEmpty  = (cnt <= 0)

        -- 记录命中区（用于事件检测）
        table.insert(toolBtnRects, { x=bx-btnR-6, y=cy2-btnR-6, w=(btnR+6)*2, h=(btnR+6)*2+labelH, key=tool.key })

        -- 选中态外圈脉冲光晕
        if isActive then
            nvgBeginPath(vg); nvgCircle(vg, bx, cy2, btnR + 12)
            nvgFillColor(vg, nvgRGBA(rr, rg, rb, 50)); nvgFill(vg)
        end

        -- 外圈淡光晕
        nvgBeginPath(vg); nvgCircle(vg, bx, cy2, btnR + 7)
        nvgFillColor(vg, nvgRGBA(rr, rg, rb, isEmpty and 10 or 22)); nvgFill(vg)

        -- 深色底座
        local alpha1 = isEmpty and 120 or 230
        local alpha2 = isEmpty and 100 or 245
        local basePaint = nvgLinearGradient(vg, bx, cy2-btnR, bx, cy2+btnR,
            nvgRGBA(ir+20, ig+20, ib+20, alpha1), nvgRGBA(ir, ig, ib, alpha2))
        nvgBeginPath(vg); nvgCircle(vg, bx, cy2, btnR)
        nvgFillPaint(vg, basePaint); nvgFill(vg)

        -- 彩色描边（选中态加粗加亮）
        local strokeW = isActive and 3.0 or 2.0
        local strokeA = isEmpty and 80 or (isActive and 255 or 200)
        nvgStrokeWidth(vg, strokeW)
        nvgStrokeColor(vg, nvgRGBA(rr, rg, rb, strokeA))
        nvgBeginPath(vg); nvgCircle(vg, bx, cy2, btnR); nvgStroke(vg)

        -- 图标
        local iconS = (btnR - 3) * 2
        local imgAlpha = isEmpty and 0.35 or 1.0
        if tool.img and tool.img >= 0 then
            local ix = bx - iconS * 0.5
            local iy = cy2 - iconS * 0.5
            nvgSave(vg)
            nvgScissor(vg, ix, iy, iconS, iconS)
            local ip = nvgImagePattern(vg, ix, iy, iconS, iconS, 0, tool.img, imgAlpha)
            nvgBeginPath(vg); nvgRect(vg, ix, iy, iconS, iconS)
            nvgFillPaint(vg, ip); nvgFill(vg)
            nvgRestore(vg)
        else
            local fallbacks = { "✨","🔮","❄️","♻️" }
            nvgFontSize(vg, btnR * 1.0)
            nvgFillColor(vg, nvgRGBA(255,255,255, math.floor(240*imgAlpha)))
            nvgText(vg, bx, cy2, fallbacks[i] or "?")
        end

        -- 顶部高光
        local hlPaint = nvgLinearGradient(vg, bx, cy2-btnR, bx, cy2,
            nvgRGBA(255,255,255, isEmpty and 15 or 45), nvgRGBA(255,255,255,0))
        nvgBeginPath(vg)
        nvgArc(vg, bx, cy2, btnR-1, math.pi, 2*math.pi, NVG_CW)
        nvgClosePath(vg); nvgFillPaint(vg, hlPaint); nvgFill(vg)

        -- 名称
        nvgFontSize(vg, labelH * 0.72)
        nvgFillColor(vg, nvgRGBA(rr, rg, rb, isEmpty and 100 or 210))
        nvgText(vg, bx, cy2 + btnR + labelH * 0.52, tool.name)

        -- 库存数量徽章（右上角）
        if cnt > 0 then
            local badgeR = math.max(8, btnR * 0.35)
            local badgeX = bx + btnR * 0.68
            local badgeY = cy2 - btnR * 0.68
            -- 徽章底色
            nvgBeginPath(vg); nvgCircle(vg, badgeX, badgeY, badgeR)
            nvgFillColor(vg, nvgRGBA(255, 60, 60, 240)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(255,255,255,200)); nvgStrokeWidth(vg, 1.2)
            nvgBeginPath(vg); nvgCircle(vg, badgeX, badgeY, badgeR); nvgStroke(vg)
            -- 数字
            nvgFontSize(vg, badgeR * 1.4)
            nvgFillColor(vg, nvgRGBA(255,255,255,255))
            nvgText(vg, badgeX, badgeY, tostring(math.min(cnt, 99)))
        end

        -- 冻结中提示（蓝色计时器文字）
        if tool.key == "freeze" and freezeTimer > 0 then
            nvgFontSize(vg, labelH * 0.65)
            nvgFillColor(vg, nvgRGBA(120, 200, 255, 230))
            nvgText(vg, bx, cy2 + btnR + labelH * 1.1,
                string.format("%.0fs", math.ceil(freezeTimer)))
        end
    end


end

-- ============================================================================
-- 绘制失败界面（超时）
-- ============================================================================
-- ============================================================================
-- Logo 页（工作室 Logo 展示）
-- ============================================================================
local function DrawLogo()
    -- 淡入：前0.4s；淡出：后0.4s
    local fadeIn  = math.min(1.0, logoTimer / 0.4)
    local fadeOut = math.min(1.0, (LOGO_DUR - logoTimer) / 0.4)
    local alpha   = math.min(fadeIn, fadeOut)

    -- 深色纯色背景（让 Logo 更突出）
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGB(22, 28, 48))
    nvgFill(vg)

    -- 柔和光晕（中心）
    local cx, cy = screenW * 0.5, screenH * 0.5
    local glow = nvgRadialGradient(vg, cx, cy, 0, screenW * 0.55,
        nvgRGBA(80, 160, 255, math.floor(40 * alpha)),
        nvgRGBA(22, 28, 48, 0))
    nvgBeginPath(vg); nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillPaint(vg, glow); nvgFill(vg)

    -- 绘制 AI 生成 Logo 图片（居中）
    if logoImage >= 0 then
        local iw, ih = nvgImageSize(vg, logoImage)
        local maxW = screenW * 0.70
        local maxH = screenH * 0.55
        local scale = math.min(maxW / iw, maxH / ih)
        local dw = iw * scale
        local dh = ih * scale
        local dx = (screenW - dw) * 0.5
        local dy = (screenH - dh) * 0.5 - screenH * 0.03
        local paint = nvgImagePattern(vg, dx, dy, dw, dh, 0, logoImage, alpha)
        nvgBeginPath(vg)
        nvgRect(vg, dx, dy, dw, dh)
        nvgFillPaint(vg, paint)
        nvgFill(vg)
    end

    -- 底部工作室名（淡出前显示）
    local textAlpha = math.floor(alpha * 180)
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, screenH * 0.022)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(180, 200, 255, textAlpha))
    nvgText(vg, screenW * 0.5, screenH * 0.88, "整蛊老板消消乐")
end

-- ============================================================================
-- 加载条页
-- ============================================================================
local function DrawSplash()
    local p = math.min(1.0, splashTimer / SPLASH_DUR)  -- 0→1

    -- AI 生成背景图铺满全屏
    if splashBgImage >= 0 then
        local iw, ih = nvgImageSize(vg, splashBgImage)
        -- cover 模式：按短边缩放，居中裁切
        local scale = math.max(screenW / iw, screenH / ih)
        local dw = iw * scale
        local dh = ih * scale
        local dx = (screenW - dw) * 0.5
        local dy = (screenH - dh) * 0.5
        local bgPaint = nvgImagePattern(vg, dx, dy, dw, dh, 0, splashBgImage, 1.0)
        nvgBeginPath(vg); nvgRect(vg, 0, 0, screenW, screenH)
        nvgFillPaint(vg, bgPaint); nvgFill(vg)
    else
        -- 备用：暖橙渐变
        local bg = nvgLinearGradient(vg, 0,0,0,screenH,
            nvgRGBA(245,168,30,255), nvgRGBA(220,130,18,255))
        nvgBeginPath(vg); nvgRect(vg, 0,0,screenW,screenH)
        nvgFillPaint(vg, bg); nvgFill(vg)
    end

    -- 半透明遮罩（让上层 UI 更清晰）
    nvgBeginPath(vg); nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(20, 15, 40, 100)); nvgFill(vg)

    -- LOGO 大框（红色圆角）
    local logoW = screenW * 0.82
    local logoH = screenH * 0.36
    local logoX = (screenW - logoW) * 0.5
    local logoY = screenH * 0.18
    -- 金色外框光晕
    nvgFillColor(vg, nvgRGBA(255,200,40,80))
    nvgBeginPath(vg); nvgRoundedRect(vg, logoX-8, logoY-8, logoW+16, logoH+16, 36); nvgFill(vg)
    -- 红色主框
    local redBg = nvgLinearGradient(vg, 0, logoY, 0, logoY+logoH,
        nvgRGBA(210,50,50,255), nvgRGBA(160,20,20,255))
    nvgBeginPath(vg); nvgRoundedRect(vg, logoX, logoY, logoW, logoH, 28)
    nvgFillPaint(vg, redBg); nvgFill(vg)
    -- 金色描边
    nvgStrokeColor(vg, nvgRGBA(255,210,40,255))
    nvgStrokeWidth(vg, 4.5)
    nvgBeginPath(vg); nvgRoundedRect(vg, logoX, logoY, logoW, logoH, 28); nvgStroke(vg)

    -- 游戏名（黄色大字，两行：整蛊老板 / 消消乐）
    local titleCX = screenW * 0.5
    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    -- 描边层
    nvgFontSize(vg, screenH * 0.085)
    nvgStrokeWidth(vg, 6)
    nvgStrokeColor(vg, nvgRGBA(160, 60, 0, 255))
    nvgFillColor(vg,   nvgRGBA(255, 220, 30, 255))
    nvgText(vg, titleCX, logoY + logoH*0.30, "整蛊老板")
    -- 第二行
    nvgFontSize(vg, screenH * 0.072)
    nvgText(vg, titleCX, logoY + logoH*0.58, "消消乐")

    -- 副标题白色粗体
    nvgFontSize(vg, screenH * 0.038)
    nvgStrokeWidth(vg, 5)
    nvgStrokeColor(vg, nvgRGBA(30, 60, 180, 255))
    nvgFillColor(vg,   nvgRGBA(255, 255, 255, 255))
    nvgText(vg, titleCX, logoY + logoH*0.82, "★ 清空格子，赢得胜利！ ★")

    -- 星星装饰（两侧）
    local starY = logoY + logoH*0.58
    nvgFontSize(vg, screenH * 0.045)
    nvgFillColor(vg, nvgRGBA(255, 230, 50, 255))
    nvgText(vg, logoX + logoW*0.10, starY, "★")
    nvgText(vg, logoX + logoW*0.90, starY, "★")

    -- 进度条
    local barW  = screenW * 0.78
    local barH  = screenH * 0.032
    local barX  = (screenW - barW) * 0.5
    local barY  = screenH * 0.82
    local barR  = barH * 0.5
    -- 外框（金色）
    nvgFillColor(vg, nvgRGBA(180, 130, 30, 255))
    nvgBeginPath(vg); nvgRoundedRect(vg, barX-3, barY-3, barW+6, barH+6, barR+3); nvgFill(vg)
    -- 背景槽
    nvgFillColor(vg, nvgRGBA(60, 40, 10, 160))
    nvgBeginPath(vg); nvgRoundedRect(vg, barX, barY, barW, barH, barR); nvgFill(vg)
    -- 填充（青色渐变）
    local fillW = math.max(barR*2, barW * p)
    local fillPaint = nvgLinearGradient(vg, barX, barY, barX+fillW, barY,
        nvgRGBA(80, 230, 220, 255), nvgRGBA(40, 180, 200, 255))
    nvgBeginPath(vg); nvgRoundedRect(vg, barX, barY, fillW, barH, barR)
    nvgFillPaint(vg, fillPaint); nvgFill(vg)
    -- 高光
    nvgFillColor(vg, nvgRGBA(255,255,255,60))
    nvgBeginPath(vg); nvgRoundedRect(vg, barX+2, barY+2, fillW-4, barH*0.4, barR); nvgFill(vg)

    -- "Loading..." 文字
    nvgFontSize(vg, screenH * 0.022)
    nvgFillColor(vg, nvgRGBA(255,240,200,200))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(vg, screenW*0.5, barY + barH + screenH*0.025, "Loading...")
end

-- 前向声明（HandleHomeTap 引用 InitGame，InitGame 定义在后面）
local InitGame

-- ============================================================================
-- 主界面点击处理（鼠标/触摸共用）
-- ============================================================================
local function HandleHomeTap(mx, my)
    local navH  = screenH * 0.13
    local navY  = screenH - navH
    local slotW = screenW / 3

    -- 弹窗显示时：优先处理弹窗内点击（覆盖一切其他点击）
    if showLevelStartPopup then
        for _, r in ipairs(levelStartPopupRects) do
            if mx >= r.x and mx <= r.x+r.w and my >= r.y and my <= r.y+r.h then
                if r.id == "close" then
                    showLevelStartPopup = false
                elseif r.id == "tool" then
                    if r.cnt > 0 then
                        -- 切换选中状态
                        levelStartSelected[r.key] = not levelStartSelected[r.key]
                    else
                        homeToastMsg = "库存不足，去商店购买"
                        homeToastTimer = 1.5
                    end
                elseif r.id == "start" then
                    -- 直接开始：消耗已选道具
                    showLevelStartPopup = false
                    pendingElimAtStart  = 0
                    InitGame()
                    if levelStartSelected.elim and toolCounts.elim > 0 then
                        toolCounts.elim = toolCounts.elim - 1
                        pendingElimAtStart = pendingElimAtStart + 1
                    end
                    if levelStartSelected.addtime and toolCounts.addtime > 0 then
                        toolCounts.addtime = toolCounts.addtime - 1
                        timeLeft = timeLeft + 60
                    end
                    SavePlayerData()
                    appPhase = "game"
                elseif r.id == "ad" then
                    -- 看广告后开始：先弹广告，成功后给额外奖励
                    showLevelStartPopup = false
                    sdk:ShowRewardVideoAd(function(result)
                        pendingElimAtStart = 0
                        InitGame()
                        -- 消耗已选道具
                        if levelStartSelected.elim and toolCounts.elim > 0 then
                            toolCounts.elim = toolCounts.elim - 1
                            pendingElimAtStart = pendingElimAtStart + 1
                        end
                        if levelStartSelected.addtime and toolCounts.addtime > 0 then
                            toolCounts.addtime = toolCounts.addtime - 1
                            timeLeft = timeLeft + 60
                        end
                        -- 广告看完才给额外奖励
                        if result.success then
                            pendingElimAtStart = pendingElimAtStart + 1
                            timeLeft = timeLeft + 60
                        end
                        SavePlayerData()
                        appPhase = "game"
                    end)
                end
                return
            end
        end
        -- 点击弹窗外区域：不关闭，仅拦截点击
        return
    end

    -- 开始按钮（绿色大按钮，仅首页 Tab 可见）→ 打开道具选择弹窗
    if homeNavTab == 2 then
        local btnAreaY = navY - screenH * 0.16
        local btnW = screenW * 0.54; local btnH = screenH * 0.075
        local btnX = (screenW - btnW) * 0.5
        if mx >= btnX and mx <= btnX+btnW and my >= btnAreaY and my <= btnAreaY+btnH then
            levelStartSelected = { elim = false, addtime = false }
            showLevelStartPopup = true
            return
        end
    end

    -- 商店购买按钮点击检测（卡片区域，在导航栏之上）
    if homeNavTab == 3 then
        for _, br in ipairs(shopBuyRects) do
            if mx >= br.x and mx <= br.x+br.w and my >= br.y and my <= br.y+br.h then
                if playerCoins >= br.price then
                    playerCoins = playerCoins - br.price
                    toolCounts[br.key] = (toolCounts[br.key] or 0) + 1
                    SavePlayerData()
                    homeToastMsg = string.format("购买成功！%s x1", br.key)
                    homeToastTimer = 1.5
                else
                    homeToastMsg = "金币不足"
                    homeToastTimer = 1.2
                end
                return
            end
        end
    end

    -- 导航栏 Tab 点击检测
    if my >= navY then
        local slot = math.floor(mx / slotW) + 1
        slot = math.max(1, math.min(3, slot))
        if slot ~= homeNavTab then
            homeNavTab = slot
            if slot == 1 then
                homeToastMsg = "排行榜 - 即将开放"
                homeToastTimer = 1.8
            end
        end
        return
    end
end

-- ============================================================================
-- 主界面
-- ============================================================================
-- ── 底部导航栏（独立函数，DrawHome 和 DrawShop 共用）────────────────────────
local function DrawNavBar()
    local navH   = screenH * 0.13
    local navY   = screenH - navH
    local navR   = 20

    local navBg = nvgLinearGradient(vg, 0, navY, 0, screenH,
        nvgRGBA(18, 38, 90, 235), nvgRGBA(10, 22, 60, 250))
    nvgBeginPath(vg)
    nvgRoundedRectVarying(vg, 0, navY, screenW, navH, navR, navR, 0, 0)
    nvgFillPaint(vg, navBg); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(100, 160, 255, 100))
    nvgStrokeWidth(vg, 1.2)
    nvgBeginPath(vg)
    nvgMoveTo(vg, navR, navY); nvgLineTo(vg, screenW - navR, navY)
    nvgStroke(vg)

    local tabs = {
        { id = 1, label = "排行榜", active = navTrophyActive,   inactive = navTrophyInactive },
        { id = 2, label = "首页",   active = navHomeActive,     inactive = navHomeInactive   },
        { id = 3, label = "商店",   active = navShopActive,     inactive = navShopInactive   },
    }
    local slotW  = screenW / 3
    local iconS  = navH * 0.50
    local labelH = navH * 0.22
    local iconTopY = navY + navH * 0.10

    for i, tab in ipairs(tabs) do
        local cx = slotW * (i - 0.5)
        local isActive = (homeNavTab == tab.id)

        if isActive then
            local hlW = slotW * 0.82
            local hlH = navH * 0.88
            local hlX = cx - hlW * 0.5
            local hlY = navY + navH * 0.06
            local glow = nvgRadialGradient(vg, cx, navY + navH*0.45,
                0, hlW * 0.6,
                nvgRGBA(80, 160, 255, 60), nvgRGBA(80, 160, 255, 0))
            nvgBeginPath(vg); nvgRect(vg, cx - hlW, navY, hlW*2, navH)
            nvgFillPaint(vg, glow); nvgFill(vg)
            nvgFillColor(vg, nvgRGBA(60, 120, 240, 50))
            nvgBeginPath(vg)
            nvgRoundedRect(vg, hlX, hlY, hlW, hlH, 12)
            nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(120, 200, 255, 200))
            nvgStrokeWidth(vg, 2)
            nvgBeginPath(vg)
            nvgMoveTo(vg, hlX + 12, navY + navH * 0.06)
            nvgLineTo(vg, hlX + hlW - 12, navY + navH * 0.06)
            nvgStroke(vg)
        end

        local icon = isActive and tab.active or tab.inactive
        local alpha = isActive and 1.0 or 0.55
        if icon > 0 then
            local ix = cx - iconS * 0.5
            local iy = iconTopY
            local ip = nvgImagePattern(vg, ix, iy, iconS, iconS, 0, icon, alpha)
            nvgBeginPath(vg); nvgRect(vg, ix, iy, iconS, iconS)
            nvgFillPaint(vg, ip); nvgFill(vg)
        end

        nvgFontSize(vg, labelH)
        if isActive then
            nvgFillColor(vg, nvgRGBA(120, 210, 255, 255))
        else
            nvgFillColor(vg, nvgRGBA(160, 180, 220, 160))
        end
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgText(vg, cx, iconTopY + iconS + labelH * 0.75, tab.label)
    end
end

local function DrawHome()
    -- ── 整张主界面背景图（铺满全屏） ──────────────────────────
    nvgFillColor(vg, nvgRGBA(30, 75, 150, 255))
    nvgBeginPath(vg); nvgRect(vg, 0, 0, screenW, screenH); nvgFill(vg)
    if homeBgImage > 0 then
        local imgPaint = nvgImagePattern(vg, 0, 0, screenW, screenH, 0, homeBgImage, 1.0)
        nvgBeginPath(vg); nvgRect(vg, 0, 0, screenW, screenH)
        nvgFillPaint(vg, imgPaint); nvgFill(vg)
    end

    -- ── 底部导航栏 ──
    DrawNavBar()

    local navH = screenH * 0.13
    local navY = screenH - navH

    -- ── 可交互叠层：连胜纪录 + 开始按钮区 ─────────────────────
    local btnAreaY = navY - screenH*0.16
    -- 连胜文字
    if homeWinStreak > 0 then
        nvgFillColor(vg, nvgRGBA(255,225,50,255))
        nvgFontSize(vg, screenH*0.022)
        nvgFontFace(vg, "sans")
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgText(vg, screenW*0.5, btnAreaY - screenH*0.018, "连胜纪录  " .. homeWinStreak)
    end
    -- 开始按钮（绿色大按钮）
    local btnW = screenW * 0.54; local btnH = screenH * 0.075
    local btnX = (screenW - btnW)*0.5; local btnY = btnAreaY
    local btnPaint = nvgLinearGradient(vg, 0, btnY, 0, btnY+btnH,
        nvgRGBA(80,200,60,255), nvgRGBA(40,160,30,255))
    nvgBeginPath(vg); nvgRoundedRect(vg, btnX, btnY, btnW, btnH, btnH*0.5)
    nvgFillPaint(vg, btnPaint); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(20,120,10,200)); nvgStrokeWidth(vg,2.5)
    nvgBeginPath(vg); nvgRoundedRect(vg, btnX, btnY, btnW, btnH, btnH*0.5); nvgStroke(vg)
    -- 按钮高光
    nvgFillColor(vg, nvgRGBA(255,255,255,50))
    nvgBeginPath(vg); nvgRoundedRect(vg, btnX+4, btnY+4, btnW-8, btnH*0.4, btnH*0.4); nvgFill(vg)
    -- 按钮文字
    nvgFontSize(vg, btnH * 0.54)
    nvgFillColor(vg, nvgRGBA(255,255,255,255))
    nvgStrokeColor(vg, nvgRGBA(15,90,5,200)); nvgStrokeWidth(vg,3)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(vg, screenW*0.5, btnY + btnH*0.52, "关卡 " .. currentLevel)

    -- ── 顶部状态栏 ────────────────────────────────────────────
    local topBarH = screenH * 0.075
    local topCy   = topBarH * 0.5   -- 垂直居中 y
    -- 半透明深蓝背景
    nvgFillColor(vg, nvgRGBA(20, 55, 130, 220))
    nvgBeginPath(vg); nvgRect(vg, 0, 0, screenW, topBarH); nvgFill(vg)
    -- 底部分割线
    nvgStrokeColor(vg, nvgRGBA(80, 140, 255, 80))
    nvgStrokeWidth(vg, 1)
    nvgBeginPath(vg); nvgMoveTo(vg, 0, topBarH); nvgLineTo(vg, screenW, topBarH); nvgStroke(vg)

    local pad  = topBarH * 0.18   -- 左侧起始内边距
    local cur  = pad               -- 当前 x 游标

    -- 【头像圆】
    local avatarR = topBarH * 0.36
    local avatarCx = cur + avatarR
    -- 外圈金色光晕
    nvgFillColor(vg, nvgRGBA(255, 210, 60, 180))
    nvgBeginPath(vg); nvgCircle(vg, avatarCx, topCy, avatarR + 2); nvgFill(vg)
    -- 头像底色
    nvgFillColor(vg, nvgRGBA(255, 230, 100, 255))
    nvgBeginPath(vg); nvgCircle(vg, avatarCx, topCy, avatarR); nvgFill(vg)
    -- 头像 emoji
    nvgFontSize(vg, avatarR * 1.3)
    nvgFillColor(vg, nvgRGBA(60, 40, 10, 255))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(vg, avatarCx, topCy + avatarR*0.06, "🐥")
    cur = avatarCx + avatarR + topBarH * 0.14

    -- 【金币图标 + 数量】
    local topIconS = topBarH * 0.54
    local topIconY = topCy - topIconS * 0.5
    if iconCoin > 0 then
        local ip = nvgImagePattern(vg, cur, topIconY, topIconS, topIconS, 0, iconCoin, 1.0)
        nvgBeginPath(vg); nvgRect(vg, cur, topIconY, topIconS, topIconS)
        nvgFillPaint(vg, ip); nvgFill(vg)
    else
        nvgFillColor(vg, nvgRGBA(255, 200, 30, 255))
        nvgBeginPath(vg); nvgCircle(vg, cur + topIconS*0.5, topCy, topIconS*0.5); nvgFill(vg)
    end
    cur = cur + topIconS + topBarH * 0.06
    nvgFontSize(vg, topBarH * 0.40)
    nvgFillColor(vg, nvgRGBA(255, 240, 160, 255))
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgText(vg, cur, topCy, tostring(playerCoins))
    local coinTxtW = math.max(2, #tostring(playerCoins)) * topBarH * 0.24
    cur = cur + coinTxtW + topBarH * 0.18

    -- 【钻石图标 + 数量】
    if iconGem > 0 then
        local ip = nvgImagePattern(vg, cur, topIconY, topIconS, topIconS, 0, iconGem, 1.0)
        nvgBeginPath(vg); nvgRect(vg, cur, topIconY, topIconS, topIconS)
        nvgFillPaint(vg, ip); nvgFill(vg)
    else
        nvgFillColor(vg, nvgRGBA(80, 180, 255, 255))
        nvgBeginPath(vg); nvgRect(vg, cur, topCy-topIconS*0.4, topIconS*0.7, topIconS*0.8); nvgFill(vg)
    end
    cur = cur + topIconS + topBarH * 0.06
    nvgFontSize(vg, topBarH * 0.40)
    nvgFillColor(vg, nvgRGBA(150, 220, 255, 255))
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgText(vg, cur, topCy, "0")

    -- 【右侧：设置按钮】
    local settingS = topBarH * 0.58
    local settingX = screenW - pad - settingS
    local settingY = topCy - settingS * 0.5
    if iconSettings > 0 then
        local ip = nvgImagePattern(vg, settingX, settingY, settingS, settingS, 0, iconSettings, 1.0)
        nvgBeginPath(vg); nvgRect(vg, settingX, settingY, settingS, settingS)
        nvgFillPaint(vg, ip); nvgFill(vg)
    else
        nvgFillColor(vg, nvgRGBA(180, 200, 255, 200))
        nvgBeginPath(vg); nvgCircle(vg, settingX + settingS*0.5, topCy, settingS*0.42); nvgFill(vg)
        nvgFontSize(vg, settingS * 0.8)
        nvgFillColor(vg, nvgRGBA(255,255,255,255))
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgText(vg, settingX + settingS*0.5, topCy, "⚙")
    end

    -- ── Toast 提示 ──────────────────────────────────────────
    if homeToastTimer > 0 and homeToastMsg ~= "" then
        local alpha = math.min(1.0, homeToastTimer / 0.3) * 255
        local tw    = screenW * 0.68
        local th    = screenH * 0.052
        local tx    = (screenW - tw) * 0.5
        local ty    = screenH * 0.42
        nvgFillColor(vg, nvgRGBA(20, 20, 40, math.floor(alpha * 0.88)))
        nvgBeginPath(vg); nvgRoundedRect(vg, tx, ty, tw, th, th*0.5); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(100,160,255, math.floor(alpha)))
        nvgStrokeWidth(vg, 1.5)
        nvgBeginPath(vg); nvgRoundedRect(vg, tx, ty, tw, th, th*0.5); nvgStroke(vg)
        nvgFontSize(vg, th * 0.52)
        nvgFillColor(vg, nvgRGBA(220,235,255, math.floor(alpha)))
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgText(vg, screenW*0.5, ty + th*0.52, homeToastMsg)
    end
end

-- ============================================================================
-- 商店界面（覆盖在主界面上，homeNavTab == 3 时显示）
-- ============================================================================
local function DrawShop()
    shopBuyRects = {}  -- 每帧重建

    local navH   = screenH * 0.13
    local navY   = screenH - navH   -- 导航栏顶部 y，商店内容不得低于此

    -- ── 背景图（cover 模式铺满，不透明）─────────────────────────────────────
    if shopBgImage >= 0 then
        local iw, ih = nvgImageSize(vg, shopBgImage)
        local scale  = math.max(screenW / iw, screenH / ih)
        local dw, dh = iw * scale, ih * scale
        local dx, dy = (screenW - dw) * 0.5, (screenH - dh) * 0.5
        local bgPaint = nvgImagePattern(vg, dx, dy, dw, dh, 0, shopBgImage, 1.0)
        nvgBeginPath(vg); nvgRect(vg, 0, 0, screenW, screenH)
        nvgFillPaint(vg, bgPaint); nvgFill(vg)
    else
        -- 备用纯色底
        nvgBeginPath(vg); nvgRect(vg, 0, 0, screenW, screenH)
        nvgFillColor(vg, nvgRGBA(12, 18, 40, 255)); nvgFill(vg)
    end
    -- 轻微暗化，让卡片文字更易读
    nvgBeginPath(vg); nvgRect(vg, 0, 0, screenW, navY)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 80)); nvgFill(vg)

    -- ── 顶部标题栏 ───────────────────────────────────────────────────────────
    local titleH = math.floor(screenH * 0.10)
    local titleBg = nvgLinearGradient(vg, 0, 0, 0, titleH,
        nvgRGBA(20, 35, 90, 220), nvgRGBA(10, 18, 60, 200))
    nvgBeginPath(vg); nvgRect(vg, 0, 0, screenW, titleH)
    nvgFillPaint(vg, titleBg); nvgFill(vg)

    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, titleH * 0.46)
    nvgFillColor(vg, nvgRGBA(255, 220, 80, 255))
    nvgText(vg, screenW * 0.5, titleH * 0.5, "道具商店")

    -- 金币显示（右上角）
    local coinIconS = titleH * 0.42
    local coinX = screenW - coinIconS - 12
    local coinY = (titleH - coinIconS) * 0.5
    if iconCoin >= 0 then
        local ip = nvgImagePattern(vg, coinX, coinY, coinIconS, coinIconS, 0, iconCoin, 1.0)
        nvgBeginPath(vg); nvgRect(vg, coinX, coinY, coinIconS, coinIconS)
        nvgFillPaint(vg, ip); nvgFill(vg)
    end
    nvgFontSize(vg, titleH * 0.36)
    nvgFillColor(vg, nvgRGBA(255, 220, 80, 255))
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgText(vg, coinX - 4, titleH * 0.5, tostring(playerCoins))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- ── 商品卡片（只占 titleH ~ navY 之间区域）───────────────────────────────
    local listH      = navY - titleH - 8          -- 可用列表高度
    local cardMargin = math.floor(listH * 0.025)
    local cardCount  = #TOOL_DEFS                  -- 5 个
    local cardH      = math.floor((listH - cardMargin * (cardCount + 1)) / cardCount)
    cardH = math.max(60, math.min(cardH, 110))
    local cardW      = screenW - 24

    local toolImgs = { toolImgElim, toolImgAddtime, toolImgTransform, toolImgFreeze, toolImgReset }

    for i, td in ipairs(TOOL_DEFS) do
        local cardX = 12
        local cardY = titleH + cardMargin + (i - 1) * (cardH + cardMargin)
        local cnt    = toolCounts[td.key] or 0
        local canBuy = (playerCoins >= td.price)

        -- 卡片背景色（各道具不同色调，半透明深色）
        local r1, g1, b1
        if     td.key == "elim"      then r1,g1,b1 = 90, 20, 20
        elseif td.key == "addtime"   then r1,g1,b1 = 20, 70, 30
        elseif td.key == "transform" then r1,g1,b1 = 55, 15, 80
        elseif td.key == "freeze"    then r1,g1,b1 = 15, 40, 80
        else                              r1,g1,b1 = 20, 55, 35 end
        local cardBg = nvgLinearGradient(vg, cardX, cardY, cardX + cardW, cardY,
            nvgRGBA(r1+30, g1+30, b1+30, 215), nvgRGBA(r1, g1, b1, 200))
        nvgBeginPath(vg); nvgRoundedRect(vg, cardX, cardY, cardW, cardH, 12)
        nvgFillPaint(vg, cardBg); nvgFill(vg)
        -- 描边
        nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 35)); nvgStrokeWidth(vg, 1.2)
        nvgBeginPath(vg); nvgRoundedRect(vg, cardX, cardY, cardW, cardH, 12); nvgStroke(vg)

        -- 道具图标（左侧）
        local iconS = cardH - 14
        local iconX = cardX + 10
        local iconY = cardY + (cardH - iconS) * 0.5
        if toolImgs[i] and toolImgs[i] >= 0 then
            local ip = nvgImagePattern(vg, iconX, iconY, iconS, iconS, 0, toolImgs[i], 1.0)
            nvgBeginPath(vg); nvgRoundedRect(vg, iconX, iconY, iconS, iconS, 8)
            nvgFillPaint(vg, ip); nvgFill(vg)
        else
            nvgFontSize(vg, iconS * 0.65); nvgFillColor(vg, nvgRGBA(255,255,255,200))
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgText(vg, iconX + iconS*0.5, cardY + cardH*0.5,
                ({"✨","⏰","🔮","❄","♻"})[i] or "?")
        end

        -- 名称 + 描述 + 库存
        local textX    = iconX + iconS + 12
        local nameSize = math.max(13, cardH * 0.24)
        nvgFontFace(vg, "sans"); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFontSize(vg, nameSize)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 245))
        nvgText(vg, textX, cardY + cardH * 0.27, td.name)
        nvgFontSize(vg, math.max(10, cardH * 0.18))
        nvgFillColor(vg, nvgRGBA(200, 220, 255, 185))
        nvgText(vg, textX, cardY + cardH * 0.54, td.desc)
        nvgFillColor(vg, nvgRGBA(130, 230, 150, 210))
        nvgText(vg, textX, cardY + cardH * 0.80, string.format("库存: %d", cnt))

        -- 购买按钮（右侧）
        local btnW  = math.max(68, screenW * 0.22)
        local btnH  = math.max(34, cardH * 0.52)
        local btnX  = cardX + cardW - btnW - 10
        local btnY2 = cardY + (cardH - btnH) * 0.5
        local btnR2 = btnH * 0.35
        local btnBg = canBuy
            and nvgLinearGradient(vg, btnX, btnY2, btnX, btnY2+btnH,
                    nvgRGBA(80,210,105,255), nvgRGBA(38,148,58,255))
            or  nvgLinearGradient(vg, btnX, btnY2, btnX, btnY2+btnH,
                    nvgRGBA(75,75,75,210), nvgRGBA(48,48,48,210))
        nvgBeginPath(vg); nvgRoundedRect(vg, btnX, btnY2, btnW, btnH, btnR2)
        nvgFillPaint(vg, btnBg); nvgFill(vg)
        if canBuy then
            nvgStrokeColor(vg, nvgRGBA(130,250,155,160)); nvgStrokeWidth(vg, 1.5)
            nvgBeginPath(vg); nvgRoundedRect(vg, btnX, btnY2, btnW, btnH, btnR2); nvgStroke(vg)
        end
        nvgFontFace(vg, "sans"); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(vg, math.max(12, btnH * 0.38))
        nvgFillColor(vg, canBuy and nvgRGBA(255,255,255,255) or nvgRGBA(130,130,130,200))
        nvgText(vg, btnX + btnW*0.5, btnY2 + btnH*0.36, string.format("%d", td.price))
        nvgFontSize(vg, math.max(10, btnH * 0.28))
        nvgFillColor(vg, canBuy and nvgRGBA(255,232,80,235) or nvgRGBA(110,110,110,160))
        nvgText(vg, btnX + btnW*0.5, btnY2 + btnH*0.72, "金币")

        table.insert(shopBuyRects, { x=btnX, y=btnY2, w=btnW, h=btnH, key=td.key, price=td.price })
    end

    -- ── 底部导航栏（覆盖在商店内容之上）──
    DrawNavBar()
end

-- ============================================================================
-- 开局道具选择弹窗
-- ============================================================================
local function DrawLevelStartPopup()
    levelStartPopupRects = {}

    -- 半透明黑色遮罩
    nvgBeginPath(vg); nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 160)); nvgFill(vg)

    -- 弹窗卡片尺寸（基准 510×620，随 uiScale 等比放大）
    local popW = math.min(screenW - 20, math.floor(510 * uiScale))
    local popH = math.min(screenH * 0.88, math.floor(620 * uiScale))
    local popX = (screenW - popW) * 0.5
    local popY = (screenH - popH) * 0.5

    -- 卡片阴影
    local shadowPaint = nvgBoxGradient(vg, popX+4, popY+10, popW, popH, 16, 28,
        nvgRGBA(0,0,0,140), nvgRGBA(0,0,0,0))
    nvgBeginPath(vg); nvgRoundedRect(vg, popX-6, popY-6, popW+12, popH+16, 18)
    nvgFillPaint(vg, shadowPaint); nvgFill(vg)

    -- 卡片主体（暖米色背景）
    nvgBeginPath(vg); nvgRoundedRect(vg, popX, popY, popW, popH, 16)
    nvgFillColor(vg, nvgRGBA(250, 235, 200, 255)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(210, 160, 80, 200)); nvgStrokeWidth(vg, 2.5)
    nvgBeginPath(vg); nvgRoundedRect(vg, popX, popY, popW, popH, 16); nvgStroke(vg)

    -- ── 顶部蓝色横幅 ──
    local bannerH = math.floor(popH * 0.14)
    local bannerPaint = nvgLinearGradient(vg, popX, popY, popX, popY+bannerH,
        nvgRGBA(60, 160, 255, 255), nvgRGBA(20, 100, 210, 255))
    nvgBeginPath(vg); nvgRoundedRect(vg, popX, popY, popW, bannerH, 14)
    -- 底部两角补成直角
    nvgRect(vg, popX, popY + bannerH - 14, popW, 14)
    nvgFillPaint(vg, bannerPaint); nvgFill(vg)
    -- 横幅描边
    nvgStrokeColor(vg, nvgRGBA(120, 200, 255, 160)); nvgStrokeWidth(vg, 1.5)
    nvgBeginPath(vg); nvgRoundedRect(vg, popX, popY, popW, bannerH, 14)
    nvgRect(vg, popX, popY+bannerH-14, popW, 14); nvgStroke(vg)

    -- 横幅文字 "关卡 X"
    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, bannerH * 0.55)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, popX + popW * 0.5, popY + bannerH * 0.52,
        string.format("关卡 %d", currentLevel))

    -- 关闭按钮（右上角）
    local closeS  = bannerH * 0.52
    local closeX  = popX + popW - closeS - 10
    local closeY  = popY + (bannerH - closeS) * 0.5
    nvgBeginPath(vg); nvgCircle(vg, closeX + closeS*0.5, closeY + closeS*0.5, closeS*0.5)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 50)); nvgFill(vg)
    nvgFontSize(vg, closeS * 0.72)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 230))
    nvgText(vg, closeX + closeS*0.5, closeY + closeS*0.52, "×")
    table.insert(levelStartPopupRects, {
        id="close", x=closeX, y=closeY, w=closeS, h=closeS
    })

    -- ── 选择道具区域 ──
    local sectionY   = popY + bannerH + 12
    nvgFontSize(vg, math.floor(15 * uiScale))
    nvgFillColor(vg, nvgRGBA(120, 70, 30, 200))
    nvgText(vg, popX + popW * 0.5, sectionY + 10, "选择道具")

    -- 两个工具槽：消除 + 增加时间
    local slotTools = {
        { key="elim",    name="消除",    img=toolImgElim,    emoji="✨" },
        { key="addtime", name="增加时间",  img=toolImgAddtime, emoji="⏰" },
    }
    local slotCount  = #slotTools
    local slotS      = math.min(popW * 0.36, 140)
    local slotRadius = slotS * 0.18
    local totalW     = slotCount * slotS + (slotCount - 1) * 30
    local slotStartX = popX + (popW - totalW) * 0.5
    local slotY      = sectionY + 26

    for i, st in ipairs(slotTools) do
        local sx  = slotStartX + (i - 1) * (slotS + 30)
        local sy  = slotY
        local sel = levelStartSelected[st.key]
        local cnt = toolCounts[st.key] or 0

        -- ── 外层深色边框（立体感）──
        local borderC = sel and nvgRGBA(34, 120, 34, 255) or nvgRGBA(180, 90, 10, 255)
        nvgBeginPath(vg); nvgRoundedRect(vg, sx-3, sy-3, slotS+6, slotS+6, slotRadius+3)
        nvgFillColor(vg, borderC); nvgFill(vg)

        -- ── 槽主背景 ──
        local bgPaint
        if sel then
            bgPaint = nvgLinearGradient(vg, sx, sy, sx, sy+slotS,
                nvgRGBA(120, 220, 80, 255), nvgRGBA(60, 170, 40, 255))
        else
            bgPaint = nvgLinearGradient(vg, sx, sy, sx, sy+slotS,
                nvgRGBA(255, 185, 60, 255), nvgRGBA(220, 130, 20, 255))
        end
        nvgBeginPath(vg); nvgRoundedRect(vg, sx, sy, slotS, slotS, slotRadius)
        nvgFillPaint(vg, bgPaint); nvgFill(vg)

        -- ── 顶部高光（糖果质感）──
        local hlPaint = nvgLinearGradient(vg, sx, sy+2, sx, sy+slotS*0.45,
            nvgRGBA(255,255,255,100), nvgRGBA(255,255,255,0))
        nvgBeginPath(vg); nvgRoundedRect(vg, sx+4, sy+4, slotS-8, slotS*0.42, slotRadius*0.7)
        nvgFillPaint(vg, hlPaint); nvgFill(vg)

        -- ── 道具图标（大图，居中）──
        local iconS = slotS * 0.82
        local iconX = sx + (slotS - iconS) * 0.5
        local iconY = sy + (slotS - iconS) * 0.5
        if st.img and st.img >= 0 then
            local ip = nvgImagePattern(vg, iconX, iconY, iconS, iconS, 0, st.img, 1.0)
            nvgBeginPath(vg); nvgRect(vg, iconX, iconY, iconS, iconS)
            nvgFillPaint(vg, ip); nvgFill(vg)
        else
            nvgFontSize(vg, iconS * 0.85)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 230))
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgText(vg, sx + slotS*0.5, sy + slotS*0.5, st.emoji)
        end

        -- ── 右下角角标 ──
        local bdW = slotS * 0.38
        local bdH = slotS * 0.26
        local bdX = sx + slotS - bdW + 2
        local bdY = sy + slotS - bdH + 2
        local bdR = bdH * 0.35
        if sel then
            -- 选中：绿色方形对勾角标
            nvgBeginPath(vg); nvgRoundedRect(vg, bdX, bdY, bdW, bdH, bdR)
            nvgFillColor(vg, nvgRGBA(40, 170, 50, 255)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(255,255,255,180)); nvgStrokeWidth(vg, 1)
            nvgBeginPath(vg); nvgRoundedRect(vg, bdX, bdY, bdW, bdH, bdR); nvgStroke(vg)
            nvgFontSize(vg, bdH * 0.88)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgText(vg, bdX + bdW*0.5, bdY + bdH*0.52, "✓")
        elseif cnt > 0 then
            -- 未选中有库存：蓝色数字角标
            nvgBeginPath(vg); nvgRoundedRect(vg, bdX, bdY, bdW, bdH, bdR)
            nvgFillColor(vg, nvgRGBA(60, 130, 255, 255)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(255,255,255,160)); nvgStrokeWidth(vg, 1)
            nvgBeginPath(vg); nvgRoundedRect(vg, bdX, bdY, bdW, bdH, bdR); nvgStroke(vg)
            nvgFontSize(vg, bdH * 0.82)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgText(vg, bdX + bdW*0.5, bdY + bdH*0.52, tostring(cnt))
        else
            -- 库存为0：半透明遮罩
            nvgBeginPath(vg); nvgRoundedRect(vg, sx, sy, slotS, slotS, slotRadius)
            nvgFillColor(vg, nvgRGBA(0, 0, 0, 100)); nvgFill(vg)
        end

        -- 记录点击区
        table.insert(levelStartPopupRects, {
            id="tool", key=st.key, cnt=cnt,
            x=sx, y=sy, w=slotS, h=slotS
        })
    end

    -- ── 底部两个开始按钮 ──
    local btnH2    = math.max(math.floor(52 * uiScale), popH * 0.11)
    local btnGap   = 10
    local btnW2    = (popW - 30 - btnGap) * 0.5
    local btnBottomY = popY + popH - btnH2 - 14

    -- 开始游戏（绿色）
    local startX = popX + 15
    local startPaint = nvgLinearGradient(vg, startX, btnBottomY, startX, btnBottomY+btnH2,
        nvgRGBA(80, 210, 80, 255), nvgRGBA(30, 160, 30, 255))
    nvgBeginPath(vg); nvgRoundedRect(vg, startX, btnBottomY, btnW2, btnH2, btnH2*0.28)
    nvgFillPaint(vg, startPaint); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(140, 255, 140, 160)); nvgStrokeWidth(vg, 1.5)
    nvgBeginPath(vg); nvgRoundedRect(vg, startX, btnBottomY, btnW2, btnH2, btnH2*0.28); nvgStroke(vg)
    nvgFontSize(vg, btnH2 * 0.42)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(vg, startX + btnW2*0.5, btnBottomY + btnH2*0.52, "开始游戏")
    table.insert(levelStartPopupRects, {
        id="start", x=startX, y=btnBottomY, w=btnW2, h=btnH2
    })

    -- 跟游戏（蓝色 + AD 角标）
    local adX = startX + btnW2 + btnGap
    local adPaint = nvgLinearGradient(vg, adX, btnBottomY, adX, btnBottomY+btnH2,
        nvgRGBA(40, 180, 240, 255), nvgRGBA(10, 120, 200, 255))
    nvgBeginPath(vg); nvgRoundedRect(vg, adX, btnBottomY, btnW2, btnH2, btnH2*0.28)
    nvgFillPaint(vg, adPaint); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(120, 220, 255, 160)); nvgStrokeWidth(vg, 1.5)
    nvgBeginPath(vg); nvgRoundedRect(vg, adX, btnBottomY, btnW2, btnH2, btnH2*0.28); nvgStroke(vg)
    -- 左侧竖排"额外"两字标签
    local tagW  = btnH2 * 0.32
    local tagH  = btnH2 * 0.72
    local tagX  = adX + 6
    local tagY  = btnBottomY + (btnH2 - tagH) * 0.5
    local tagPaint = nvgLinearGradient(vg, tagX, tagY, tagX, tagY+tagH,
        nvgRGBA(255, 215, 40, 255), nvgRGBA(220, 155, 10, 255))
    nvgBeginPath(vg); nvgRoundedRect(vg, tagX, tagY, tagW, tagH, tagW*0.4)
    nvgFillPaint(vg, tagPaint); nvgFill(vg)
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, tagW * 0.78)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(100, 30, 0, 255))
    nvgText(vg, tagX + tagW*0.5, tagY + tagH*0.28, "额")
    nvgText(vg, tagX + tagW*0.5, tagY + tagH*0.72, "外")

    -- 两个道具图标居中
    local miniS  = btnH2 * 0.86
    local iconsW = miniS * 2 + 10
    local ic1X   = adX + btnW2*0.5 - iconsW*0.5
    local ic2X   = ic1X + miniS + 10
    local icY    = btnBottomY + (btnH2 - miniS) * 0.5
    if toolImgElim >= 0 then
        local ip = nvgImagePattern(vg, ic1X, icY, miniS, miniS, 0, toolImgElim, 1.0)
        nvgBeginPath(vg); nvgRect(vg, ic1X, icY, miniS, miniS)
        nvgFillPaint(vg, ip); nvgFill(vg)
    end
    if toolImgAddtime >= 0 then
        local ip = nvgImagePattern(vg, ic2X, icY, miniS, miniS, 0, toolImgAddtime, 1.0)
        nvgBeginPath(vg); nvgRect(vg, ic2X, icY, miniS, miniS)
        nvgFillPaint(vg, ip); nvgFill(vg)
    end

    -- 右上角"看广告"角标（放大版）
    local adBadgeW, adBadgeH = 52, 24
    local adBadgeX = adX + btnW2 - 2
    local adBadgeY = btnBottomY - 2
    nvgBeginPath(vg); nvgRoundedRect(vg, adBadgeX - adBadgeW, adBadgeY, adBadgeW, adBadgeH, 5)
    nvgFillColor(vg, nvgRGBA(255, 200, 30, 255)); nvgFill(vg)
    nvgFontSize(vg, math.floor(13 * uiScale))
    nvgFillColor(vg, nvgRGBA(80, 40, 0, 255))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(vg, adBadgeX - adBadgeW*0.5, adBadgeY + adBadgeH*0.52, "看广告")
    table.insert(levelStartPopupRects, {
        id="ad", x=adX, y=btnBottomY, w=btnW2, h=btnH2
    })
end

-- ============================================================================
-- 结算界面
-- ============================================================================
local function DrawSettlement()
    -- ── 半透明黑底遮罩 ───────────────────────────────────────────────────────
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 160))
    nvgBeginPath(vg); nvgRect(vg, 0, 0, screenW, screenH); nvgFill(vg)

    -- ── 卡片主体 ─────────────────────────────────────────────────────────────
    local cw  = math.min(screenW - 40, math.floor(360 * uiScale))
    local ch  = math.floor(500 * uiScale)
    local cx  = (screenW - cw) * 0.5
    local cy  = (screenH - ch) * 0.5

    -- 卡片阴影
    local shadowPaint = nvgBoxGradient(vg, cx+4, cy+6, cw, ch, 18, 24,
        nvgRGBA(0,0,0,100), nvgRGBA(0,0,0,0))
    nvgBeginPath(vg); nvgRoundedRect(vg, cx, cy, cw, ch, 18)
    nvgFillPaint(vg, shadowPaint); nvgFill(vg)

    -- 卡片白底
    nvgFillColor(vg, nvgRGBA(255, 252, 245, 255))
    nvgBeginPath(vg); nvgRoundedRect(vg, cx, cy, cw, ch, 18); nvgFill(vg)

    -- ── 顶部蓝色横幅 ─────────────────────────────────────────────────────────
    local bannerH = math.floor(52 * uiScale)
    nvgFillColor(vg, nvgRGBA(52, 130, 246, 255))
    nvgBeginPath(vg)
    nvgRoundedRectVarying(vg, cx, cy, cw, bannerH, 18, 18, 0, 0)
    nvgFill(vg)

    nvgFontFace(vg, "sans"); nvgFontSize(vg, math.floor(22 * uiScale))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, cx + cw*0.5, cy + bannerH*0.5,
        string.format("关卡%d 完成！", settleClearedLevel))

    -- ── 金币图标 + 基础金币数 ─────────────────────────────────────────────────
    local gemY = cy + bannerH + math.floor(24 * uiScale)
    local gemR = math.floor(44 * uiScale)
    -- 外圈金色光晕
    local glowPaint = nvgRadialGradient(vg, cx+cw*0.5, gemY+gemR, gemR*0.4, gemR*1.5,
        nvgRGBA(255, 210, 50, 80), nvgRGBA(255, 210, 50, 0))
    nvgBeginPath(vg); nvgCircle(vg, cx+cw*0.5, gemY+gemR, gemR*1.5)
    nvgFillPaint(vg, glowPaint); nvgFill(vg)
    -- 金币图标
    if iconCoin >= 0 then
        local imgPaint = nvgImagePattern(vg, cx+cw*0.5-gemR, gemY, gemR*2, gemR*2, 0, iconCoin, 1.0)
        nvgBeginPath(vg); nvgRect(vg, cx+cw*0.5-gemR, gemY, gemR*2, gemR*2)
        nvgFillPaint(vg, imgPaint); nvgFill(vg)
    else
        nvgFontSize(vg, math.floor(56 * uiScale))
        nvgFillColor(vg, nvgRGBA(255, 200, 40, 255))
        nvgText(vg, cx+cw*0.5, gemY+gemR, "🪙")
    end
    nvgFontSize(vg, math.floor(28 * uiScale)); nvgFontFace(vg, "sans")
    nvgFillColor(vg, nvgRGBA(40, 40, 40, 255))
    nvgText(vg, cx+cw*0.5, gemY + gemR*2 + math.floor(18 * uiScale),
        string.format("× %d", settleBaseCoins))

    -- ── 宝箱进度条 ───────────────────────────────────────────────────────────
    local barY  = gemY + gemR*2 + math.floor(50 * uiScale)
    local barX  = cx + math.floor(20 * uiScale)
    local barW  = cw - math.floor(40 * uiScale)
    local barH  = math.floor(18 * uiScale)
    local prog  = math.min(chestProgress, 5)   -- 显示 0-5
    local pgPct = prog / 5.0

    -- 背景槽
    nvgFillColor(vg, nvgRGBA(220, 215, 205, 255))
    nvgBeginPath(vg); nvgRoundedRect(vg, barX, barY, barW, barH, barH*0.5); nvgFill(vg)
    -- 填充部分
    if pgPct > 0 then
        nvgFillColor(vg, nvgRGBA(255, 180, 30, 255))
        nvgBeginPath(vg)
        nvgRoundedRect(vg, barX, barY, barW * pgPct, barH, barH*0.5)
        nvgFill(vg)
    end
    -- 宝箱图标（右端）
    nvgFontSize(vg, math.floor(22 * uiScale)); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(40,40,40,255))
    nvgText(vg, barX + barW + 6, barY + barH*0.5, "🎁")
    -- 进度文字
    nvgFontSize(vg, math.floor(13 * uiScale)); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(80, 60, 20, 255))
    nvgText(vg, barX + barW*0.5, barY + barH*0.5,
        string.format("%d / 5", prog))

    -- ── 倍率条 ───────────────────────────────────────────────────────────────
    local multY  = barY + barH + math.floor(28 * uiScale)
    local cellW2 = (barW - 8) / 5
    local cellH2 = math.floor(42 * uiScale)

    for i = 1, 5 do
        local c2   = SETTLE_COLS[i]
        local bx   = barX + (i-1)*(cellW2 + 2)
        local by   = multY
        local isHi = (i == settleMultIdx)
        local alpha = isHi and 255 or 180

        -- 格子背景
        nvgFillColor(vg, nvgRGBA(c2[1], c2[2], c2[3], alpha))
        nvgBeginPath(vg)
        nvgRoundedRect(vg, bx, by, cellW2, cellH2, 6)
        nvgFill(vg)
        -- 选中高亮边框
        if isHi then
            nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 240))
            nvgStrokeWidth(vg, 3)
            nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, cellW2, cellH2, 6)
            nvgStroke(vg)
        end
        -- 倍率文字
        nvgFontSize(vg, isHi and math.floor(20 * uiScale) or math.floor(16 * uiScale))
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, bx + cellW2*0.5, by + cellH2*0.5,
            string.format("x%d", SETTLE_MULTS[i]))
    end
    -- 三角形指针（始终显示，跟随当前选中格）
    do
        local arrowX = barX + (settleMultIdx - 1)*(cellW2 + 2) + cellW2*0.5
        local arrowY = multY - math.floor(6 * uiScale)
        local arrowS = math.floor(8 * uiScale)
        nvgFillColor(vg, nvgRGBA(255, 220, 50, 255))
        nvgBeginPath(vg)
        nvgMoveTo(vg, arrowX, arrowY)
        nvgLineTo(vg, arrowX - arrowS, arrowY - arrowS*1.75)
        nvgLineTo(vg, arrowX + arrowS, arrowY - arrowS*1.75)
        nvgClosePath(vg); nvgFill(vg)
    end

    -- ── 两个按钮 ─────────────────────────────────────────────────────────────
    local btnY  = multY + cellH2 + math.floor(24 * uiScale)
    local btnW2 = (barW - 8) * 0.5
    local btnH2 = math.floor(46 * uiScale)
    local btn1X = barX
    local btn2X = barX + btnW2 + 8
    local btnOffY = math.floor(7 * uiScale)  -- 文字上下偏移

    settleBtnRects = {}

    -- "直接领取 10" 按钮（绿色）
    local mult = SETTLE_MULTS[settleMultIdx]
    local directCoins = settleBaseCoins
    nvgFillColor(vg, nvgRGBA(60, 180, 80, 255))
    nvgBeginPath(vg); nvgRoundedRect(vg, btn1X, btnY, btnW2, btnH2, 10); nvgFill(vg)
    nvgFontSize(vg, math.floor(14 * uiScale)); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255,255,255,255))
    nvgText(vg, btn1X + btnW2*0.5, btnY + btnH2*0.5 - btnOffY,
        string.format("已完成 ⭐%d", directCoins))
    nvgFontSize(vg, math.floor(11 * uiScale))
    nvgFillColor(vg, nvgRGBA(220,255,220,220))
    nvgText(vg, btn1X + btnW2*0.5, btnY + btnH2*0.5 + btnOffY, "直接领取")
    table.insert(settleBtnRects, {x=btn1X,y=btnY,w=btnW2,h=btnH2, id="direct"})

    -- "领取 xN AD" 按钮（蓝色）
    nvgFillColor(vg, nvgRGBA(52, 130, 246, 255))
    nvgBeginPath(vg); nvgRoundedRect(vg, btn2X, btnY, btnW2, btnH2, 10); nvgFill(vg)
    nvgFontSize(vg, math.floor(14 * uiScale)); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255,255,255,255))
    nvgText(vg, btn2X + btnW2*0.5, btnY + btnH2*0.5 - btnOffY,
        string.format("看广告 x%d", mult))
    nvgFontSize(vg, math.floor(11 * uiScale))
    nvgFillColor(vg, nvgRGBA(200,230,255,220))
    nvgText(vg, btn2X + btnW2*0.5, btnY + btnH2*0.5 + btnOffY,
        string.format("+%d 金币", directCoins * mult))
    table.insert(settleBtnRects, {x=btn2X,y=btnY,w=btnW2,h=btnH2, id="ad"})
end

-- ============================================================================
-- 宝箱弹窗
-- ============================================================================
local function DrawChestPopup()
    -- 半透明黑底
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 190))
    nvgBeginPath(vg); nvgRect(vg, 0, 0, screenW, screenH); nvgFill(vg)

    local cw  = math.min(screenW - 50, math.floor(320 * uiScale))
    local ch  = math.floor(360 * uiScale)
    local cx  = (screenW - cw) * 0.5
    local cy  = (screenH - ch) * 0.5

    -- 外发光
    local glowPaint = nvgBoxGradient(vg, cx-4, cy-2, cw+8, ch+8, 20, 28,
        nvgRGBA(255, 200, 40, 60), nvgRGBA(0,0,0,0))
    nvgBeginPath(vg); nvgRoundedRect(vg, cx-8, cy-6, cw+16, ch+12, 22)
    nvgFillPaint(vg, glowPaint); nvgFill(vg)

    -- 阴影 + 卡片底色
    local shadowPaint = nvgBoxGradient(vg, cx+4, cy+6, cw, ch, 18, 24,
        nvgRGBA(0,0,0,100), nvgRGBA(0,0,0,0))
    nvgBeginPath(vg); nvgRoundedRect(vg, cx, cy, cw, ch, 18)
    nvgFillPaint(vg, shadowPaint); nvgFill(vg)

    -- 卡片渐变背景（深蓝-深紫营造神秘感）
    local cardPaint = nvgLinearGradient(vg, cx, cy, cx, cy+ch,
        nvgRGBA(18, 20, 60, 255), nvgRGBA(40, 18, 80, 255))
    nvgBeginPath(vg); nvgRoundedRect(vg, cx, cy, cw, ch, 18)
    nvgFillPaint(vg, cardPaint); nvgFill(vg)

    -- 顶部彩色横幅
    local bannerPaint = nvgLinearGradient(vg, cx, cy, cx+cw, cy,
        nvgRGBA(220, 80, 20, 255), nvgRGBA(200, 160, 20, 255))
    nvgBeginPath(vg)
    nvgRoundedRectVarying(vg, cx, cy, cw, 50, 18, 18, 0, 0)
    nvgFillPaint(vg, bannerPaint); nvgFill(vg)

    -- 横幅描边
    nvgStrokeColor(vg, nvgRGBA(255, 220, 100, 120))
    nvgStrokeWidth(vg, 1.5)
    nvgBeginPath(vg)
    nvgRoundedRectVarying(vg, cx, cy, cw, 50, 18, 18, 0, 0)
    nvgStroke(vg)

    nvgFontFace(vg, "sans"); nvgFontSize(vg, math.floor(21 * uiScale))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, cx + cw*0.5, cy + 25, "🎁 宝箱奖励！")

    -- ---- 奖励内容区 ----
    -- 金币图标行
    local rowY = cy + 76
    -- 金币堆 emoji
    nvgFontSize(vg, math.floor(40 * uiScale)); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 220, 60, 255))
    nvgText(vg, cx + cw * 0.30, rowY + 20, "💰")

    -- 金币数量
    nvgFontSize(vg, math.floor(22 * uiScale)); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 220, 60, 255))
    nvgText(vg, cx + cw*0.30 + 28, rowY + 14,
        string.format("+%d", chestRewardCoins))
    nvgFontSize(vg, math.floor(13 * uiScale))
    nvgFillColor(vg, nvgRGBA(200, 200, 200, 220))
    nvgText(vg, cx + cw*0.30 + 28, rowY + 34, "金币")

    -- 竖分割线
    nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 40))
    nvgStrokeWidth(vg, 1)
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx + cw*0.58, rowY - 4)
    nvgLineTo(vg, cx + cw*0.58, rowY + 52)
    nvgStroke(vg)

    -- 道具图标 + 名字（右侧）
    if chestRewardToolKey then
        local toolName = chestRewardToolKey
        local toolImg  = -1
        for _, td in ipairs(TOOL_DEFS) do
            if td.key == chestRewardToolKey then
                toolName = td.name
                if td.key == "elim"      then toolImg = toolImgElim
                elseif td.key == "addtime"   then toolImg = toolImgAddtime
                elseif td.key == "transform" then toolImg = toolImgTransform
                elseif td.key == "freeze"    then toolImg = toolImgFreeze
                elseif td.key == "reset"     then toolImg = toolImgReset
                end
                break
            end
        end
        local iconX = cx + cw*0.66
        local iconSz = 38
        if toolImg and toolImg >= 0 then
            local ip = nvgImagePattern(vg, iconX, rowY+1, iconSz, iconSz, 0, toolImg, 1.0)
            nvgBeginPath(vg); nvgRect(vg, iconX, rowY+1, iconSz, iconSz)
            nvgFillPaint(vg, ip); nvgFill(vg)
        else
            nvgFontSize(vg, math.floor(30 * uiScale))
            nvgFillColor(vg, nvgRGBA(255, 200, 80, 255))
            nvgText(vg, iconX + iconSz*0.5, rowY + 20, "🎀")
        end
        nvgFontSize(vg, math.floor(13 * uiScale)); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(220, 220, 220, 230))
        nvgText(vg, iconX + iconSz*0.5, rowY + 46, toolName .. " ×1")
    end

    -- 分割线
    local divY = cy + 152
    nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 30))
    nvgStrokeWidth(vg, 1)
    nvgBeginPath(vg); nvgMoveTo(vg, cx+16, divY); nvgLineTo(vg, cx+cw-16, divY)
    nvgStroke(vg)

    -- 宝箱大图标（居中）
    nvgFontSize(vg, math.floor(62 * uiScale)); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 210, 50, 255))
    nvgText(vg, cx + cw*0.5, cy + 210, "🎁")

    -- ---- 两个按钮 ----
    local btnH    = 44
    local btnGap  = 10
    local btnW    = (cw - 48) * 0.5   -- 各占一半减间距
    local btn1X   = cx + 16            -- 左按钮（直接领取）
    local btn2X   = cx + 16 + btnW + btnGap  -- 右按钮（AD双倍）
    local btnY    = cy + ch - 58

    -- 直接领取按钮（绿色）
    local g1 = nvgLinearGradient(vg, btn1X, btnY, btn1X, btnY+btnH,
        nvgRGBA(60, 195, 80, 255), nvgRGBA(35, 150, 55, 255))
    nvgBeginPath(vg); nvgRoundedRect(vg, btn1X, btnY, btnW, btnH, 11)
    nvgFillPaint(vg, g1); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(120, 240, 130, 140))
    nvgStrokeWidth(vg, 1.5)
    nvgBeginPath(vg); nvgRoundedRect(vg, btn1X, btnY, btnW, btnH, 11)
    nvgStroke(vg)
    nvgFontSize(vg, math.floor(15 * uiScale)); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, btn1X + btnW*0.5, btnY + btnH*0.5 - 6, "直接领取")
    nvgFontSize(vg, math.floor(12 * uiScale))
    nvgFillColor(vg, nvgRGBA(220, 255, 220, 220))
    nvgText(vg, btn1X + btnW*0.5, btnY + btnH*0.5 + 10,
        string.format("💰%d", chestRewardCoins))

    -- AD双倍按钮（蓝色）
    local g2 = nvgLinearGradient(vg, btn2X, btnY, btn2X, btnY+btnH,
        nvgRGBA(50, 140, 240, 255), nvgRGBA(25, 90, 200, 255))
    nvgBeginPath(vg); nvgRoundedRect(vg, btn2X, btnY, btnW, btnH, 11)
    nvgFillPaint(vg, g2); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(120, 180, 255, 140))
    nvgStrokeWidth(vg, 1.5)
    nvgBeginPath(vg); nvgRoundedRect(vg, btn2X, btnY, btnW, btnH, 11)
    nvgStroke(vg)
    -- AD 小角标
    nvgFillColor(vg, nvgRGBA(255, 220, 30, 255))
    nvgBeginPath(vg); nvgRoundedRect(vg, btn2X + btnW - 36, btnY - 8, 36, 16, 4); nvgFill(vg)
    nvgFontSize(vg, math.floor(10 * uiScale)); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(30, 30, 30, 255))
    nvgText(vg, btn2X + btnW - 13, btnY - 0, "看广告")
    nvgFontSize(vg, math.floor(15 * uiScale)); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, btn2X + btnW*0.5, btnY + btnH*0.5 - 6, "双倍领取")
    nvgFontSize(vg, math.floor(12 * uiScale))
    nvgFillColor(vg, nvgRGBA(180, 230, 255, 220))
    nvgText(vg, btn2X + btnW*0.5, btnY + btnH*0.5 + 10,
        string.format("💰%d", chestRewardCoins * 2))

    -- 写入命中区（列表形式）
    chestPopupBtnRect = {
        {id="direct", x=btn1X, y=btnY, w=btnW, h=btnH},
        {id="ad",     x=btn2X, y=btnY, w=btnW, h=btnH},
    }
end

-- ============================================================================
-- GameOver 浮层
-- ============================================================================
local function DrawGameOver()
    -- 半透明深红遮罩
    nvgFillColor(vg, nvgRGBA(80, 12, 12, 172))
    nvgBeginPath(vg); nvgRect(vg, 0, 0, screenW, screenH); nvgFill(vg)

    -- 白色卡片
    local cw, ch = math.min(screenW - 40, math.floor(310 * uiScale)), math.floor(225 * uiScale)
    local ox, oy = screenW/2, screenH/2
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgBeginPath(vg)
    nvgRoundedRect(vg, ox-cw/2, oy-ch/2, cw, ch, 18)
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(195, 38, 38, 255))
    nvgStrokeWidth(vg, 3)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, ox-cw/2, oy-ch/2, cw, ch, 18)
    nvgStroke(vg)

    -- 顶部红色条
    local topPaint = nvgLinearGradient(vg, 0, oy-ch/2, 0, oy-ch/2+50,
        nvgRGBA(195,38,38,255), nvgRGBA(195,38,38,0))
    nvgBeginPath(vg)
    nvgRoundedRect(vg, ox-cw/2, oy-ch/2, cw, 50, 18)
    nvgFillPaint(vg, topPaint)
    nvgFill(vg)

    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 时间到！
    nvgFontSize(vg, math.floor(32 * uiScale))
    nvgFillColor(vg, nvgRGBA(185, 28, 28, 255))
    nvgText(vg, ox, oy - ch*0.28, "⏰ 时间到！")

    -- 分隔线
    nvgStrokeColor(vg, nvgRGBA(220, 220, 230, 255))
    nvgStrokeWidth(vg, 1.2)
    nvgBeginPath(vg)
    nvgMoveTo(vg, ox - cw*0.38, oy - ch*0.06)
    nvgLineTo(vg, ox + cw*0.38, oy - ch*0.06)
    nvgStroke(vg)

    -- 得分
    nvgFontSize(vg, math.floor(20 * uiScale))
    nvgFillColor(vg, nvgRGBA(80, 80, 120, 255))
    nvgText(vg, ox, oy + ch*0.06, "本局得分: "..score)

    -- 提示
    nvgFontSize(vg, math.floor(15 * uiScale))
    nvgFillColor(vg, nvgRGBA(130, 140, 165, 255))
    nvgText(vg, ox, oy + ch*0.28, "点击重新开始")
end

-- ============================================================================
-- 绘制关卡表覆盖层
-- ============================================================================
-- ============================================================================
-- 暂停遮罩
-- ============================================================================
local function DrawPauseOverlay()
    -- 半透明遮罩
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 140))
    nvgFill(vg)
    -- "已暂停" 文字
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, math.floor(30 * uiScale))
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 230))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(vg, screenW * 0.5, screenH * 0.45, "已暂停")
    nvgFontSize(vg, math.floor(15 * uiScale))
    nvgFillColor(vg, nvgRGBA(200, 220, 255, 180))
    nvgText(vg, screenW * 0.5, screenH * 0.45 + math.floor(36 * uiScale), "点击右上角继续")
end

-- ============================================================================
-- 退出确认对话框
-- ============================================================================
exitConfirmBtnRects = {}   -- { yes={x,y,w,h}, no={x,y,w,h} }

local function DrawExitConfirm()
    -- 半透明遮罩
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 160))
    nvgFill(vg)

    -- 对话框尺寸
    local dlgW = math.min(screenW - 48, math.floor(300 * uiScale))
    local dlgH = math.floor(160 * uiScale)
    local dlgX = (screenW - dlgW) * 0.5
    local dlgY = (screenH - dlgH) * 0.5

    -- 对话框阴影
    local shadow = nvgBoxGradient(vg, dlgX + 4, dlgY + 8, dlgW, dlgH, 14, 20,
        nvgRGBA(0, 0, 0, 120), nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(vg); nvgRoundedRect(vg, dlgX - 4, dlgY - 4, dlgW + 8, dlgH + 10, 16)
    nvgFillPaint(vg, shadow); nvgFill(vg)

    -- 对话框背景
    local dlgPaint = nvgLinearGradient(vg, dlgX, dlgY, dlgX, dlgY + dlgH,
        nvgRGBA(38, 52, 92, 255), nvgRGBA(22, 34, 68, 255))
    nvgBeginPath(vg); nvgRoundedRect(vg, dlgX, dlgY, dlgW, dlgH, 14)
    nvgFillPaint(vg, dlgPaint); nvgFill(vg)

    -- 对话框边框
    nvgStrokeColor(vg, nvgRGBA(100, 140, 230, 120))
    nvgStrokeWidth(vg, 1.5)
    nvgBeginPath(vg); nvgRoundedRect(vg, dlgX, dlgY, dlgW, dlgH, 14); nvgStroke(vg)

    -- 标题
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, math.floor(17 * uiScale))
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(vg, dlgX + dlgW * 0.5, dlgY + math.floor(36 * uiScale), "退出游戏？")

    -- 说明文字
    nvgFontSize(vg, math.floor(13 * uiScale))
    nvgFillColor(vg, nvgRGBA(180, 200, 240, 200))
    nvgText(vg, dlgX + dlgW * 0.5, dlgY + math.floor(66 * uiScale), "当前进度将会丢失")

    -- 按钮
    local btnH   = math.floor(38 * uiScale)
    local btnW   = math.floor((dlgW - 48 * uiScale) * 0.5)
    local btnY2  = dlgY + dlgH - btnH - math.floor(16 * uiScale)
    local yesBX  = dlgX + math.floor(14 * uiScale)
    local noBX   = dlgX + dlgW - math.floor(14 * uiScale) - btnW

    -- 确认退出按钮（红）
    local yesPaint = nvgLinearGradient(vg, yesBX, btnY2, yesBX, btnY2 + btnH,
        nvgRGBA(210, 55, 55, 255), nvgRGBA(170, 30, 30, 255))
    nvgBeginPath(vg); nvgRoundedRect(vg, yesBX, btnY2, btnW, btnH, 8)
    nvgFillPaint(vg, yesPaint); nvgFill(vg)
    nvgFontSize(vg, math.floor(15 * uiScale))
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(vg, yesBX + btnW * 0.5, btnY2 + btnH * 0.5, "退出")

    -- 取消按钮（蓝）
    local noPaint = nvgLinearGradient(vg, noBX, btnY2, noBX, btnY2 + btnH,
        nvgRGBA(60, 120, 220, 255), nvgRGBA(40, 90, 180, 255))
    nvgBeginPath(vg); nvgRoundedRect(vg, noBX, btnY2, btnW, btnH, 8)
    nvgFillPaint(vg, noPaint); nvgFill(vg)
    nvgText(vg, noBX + btnW * 0.5, btnY2 + btnH * 0.5, "继续")

    -- 记录按钮区域供点击检测
    exitConfirmBtnRects = {
        yes = { x = yesBX, y = btnY2, w = btnW, h = btnH },
        no  = { x = noBX,  y = btnY2, w = btnW, h = btnH },
    }
end

-- ============================================================================
-- 关卡表
-- ============================================================================
local function DrawLevelTable()
    -- 半透明遮罩
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 175))
    nvgFill(vg)

    -- 卡片尺寸
    local cardW = math.min(screenW - 32, math.floor(340 * uiScale))
    local rowH  = math.floor(34 * uiScale)
    local headerH2 = math.floor(42 * uiScale)
    local cardH = headerH2 + MAX_LEVEL * rowH + math.floor(36 * uiScale)
    local cardX = (screenW - cardW) / 2
    local cardY = (screenH - cardH) / 2

    -- 卡片阴影
    local shadowPaint = nvgBoxGradient(vg, cardX + 4, cardY + 8, cardW, cardH, 14, 24,
        nvgRGBA(0, 0, 0, 120), nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cardX - 4, cardY - 4, cardW + 8, cardH + 12, 16)
    nvgFillPaint(vg, shadowPaint)
    nvgFill(vg)

    -- 卡片背景
    local bgPaint = nvgLinearGradient(vg, cardX, cardY, cardX, cardY + cardH,
        nvgRGBA(28, 52, 110, 252), nvgRGBA(16, 32, 78, 252))
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cardX, cardY, cardW, cardH, 14)
    nvgFillPaint(vg, bgPaint)
    nvgFill(vg)
    -- 卡片描边
    nvgStrokeWidth(vg, 1.5)
    nvgStrokeColor(vg, nvgRGBA(80, 140, 255, 160))
    nvgStroke(vg)

    -- 标题行
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, math.floor(18 * uiScale))
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(vg, cardX + cardW / 2, cardY + headerH2 / 2, "📋  关卡列表")

    -- 标题分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, cardX + 16, cardY + headerH2)
    nvgLineTo(vg, cardX + cardW - 16, cardY + headerH2)
    nvgStrokeColor(vg, nvgRGBA(80, 140, 255, 100))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    -- 列标题
    local col1 = cardX + cardW * 0.08   -- 关卡
    local col2 = cardX + cardW * 0.30   -- 时间
    local col3 = cardX + cardW * 0.50   -- 种类
    local col4 = cardX + cardW * 0.68   -- 层数
    local col5 = cardX + cardW * 0.88   -- 奖励
    local colHeaderY = cardY + headerH2 + rowH * 0.45

    nvgFontSize(vg, math.floor(11 * uiScale))
    nvgFillColor(vg, nvgRGBA(140, 180, 255, 180))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(vg, col1, colHeaderY, "关")
    nvgText(vg, col2, colHeaderY, "时间")
    nvgText(vg, col3, colHeaderY, "种类")
    nvgText(vg, col4, colHeaderY, "层数")
    nvgText(vg, col5, colHeaderY, "奖励")

    -- 每关数据行
    for i = 1, MAX_LEVEL do
        local def  = LEVEL_DEFS[i]
        local rowY = cardY + headerH2 + rowH * i + rowH * 0.5

        -- 当前关高亮
        if i == currentLevel then
            nvgBeginPath(vg)
            nvgRoundedRect(vg, cardX + 8, rowY - rowH * 0.46, cardW - 16, rowH * 0.92, 6)
            nvgFillColor(vg, nvgRGBA(60, 120, 255, 55))
            nvgFill(vg)
            -- 左侧竖条
            nvgBeginPath(vg)
            nvgRoundedRect(vg, cardX + 8, rowY - rowH * 0.36, 3, rowH * 0.72, 2)
            nvgFillColor(vg, nvgRGBA(100, 200, 255, 230))
            nvgFill(vg)
        end

        -- 已通过的关卡：文字变暗 + 打勾
        local isPassed = (i < currentLevel)
        local isLocked = (i > currentLevel)
        local textAlpha = isPassed and 110 or (isLocked and 140 or 255)

        -- 关卡号
        nvgFontSize(vg, isPassed and math.floor(12 * uiScale) or math.floor(14 * uiScale))
        if i == currentLevel then
            nvgFillColor(vg, nvgRGBA(100, 210, 255, 255))
        elseif isPassed then
            nvgFillColor(vg, nvgRGBA(120, 200, 120, textAlpha))
        else
            nvgFillColor(vg, nvgRGBA(200, 200, 220, textAlpha))
        end
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        if isPassed then
            nvgText(vg, col1, rowY, "✓")
        else
            nvgText(vg, col1, rowY, tostring(i))
        end

        -- 数据列（统一样式）
        nvgFontSize(vg, math.floor(13 * uiScale))
        nvgFillColor(vg, nvgRGBA(220, 235, 255, textAlpha))
        nvgText(vg, col2, rowY, def.time.."s")
        nvgText(vg, col3, rowY, tostring(def.types))
        nvgText(vg, col4, rowY, tostring(def.layers))
        -- 奖励分（金色）
        nvgFillColor(vg, nvgRGBA(255, 210, 60, textAlpha))
        nvgText(vg, col5, rowY, "+"..def.scoreBonus)
    end

    -- 底部"点击关闭"提示
    nvgFontSize(vg, math.floor(12 * uiScale))
    nvgFillColor(vg, nvgRGBA(150, 180, 220, 160))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(vg, cardX + cardW / 2, cardY + cardH - math.floor(14 * uiScale), "点击任意处关闭")
end

-- ============================================================================
-- 绘制过关弹窗（进入下一关前的 2 秒提示）
-- ============================================================================
local function DrawLevelTransition()
    -- 过关进度 0→1
    local prog = 1.0 - (levelClearTimer / 2.2)
    -- 弹入动画：从上方滑入
    local slideY = math.max(0, (1.0 - math.min(1, prog * 3.5)) * (-screenH * 0.25))

    -- 半透明金色遮罩
    nvgFillColor(vg, nvgRGBA(18, 55, 18, math.floor(prog * 148)))
    nvgBeginPath(vg); nvgRect(vg, 0, 0, screenW, screenH); nvgFill(vg)

    local cw, ch = math.min(screenW - 40, math.floor(300 * uiScale)), math.floor(195 * uiScale)
    local ox = screenW / 2
    local oy = screenH / 2 + slideY

    -- 卡片
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgBeginPath(vg)
    nvgRoundedRect(vg, ox-cw/2, oy-ch/2, cw, ch, 18)
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(55, 175, 85, 255))
    nvgStrokeWidth(vg, 3)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, ox-cw/2, oy-ch/2, cw, ch, 18)
    nvgStroke(vg)

    -- 顶部绿色条
    local topPaint = nvgLinearGradient(vg, 0, oy-ch/2, 0, oy-ch/2+50,
        nvgRGBA(55,175,85,255), nvgRGBA(55,175,85,0))
    nvgBeginPath(vg)
    nvgRoundedRect(vg, ox-cw/2, oy-ch/2, cw, 50, 18)
    nvgFillPaint(vg, topPaint)
    nvgFill(vg)

    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 过关标题
    nvgFontSize(vg, math.floor(28 * uiScale))
    nvgFillColor(vg, nvgRGBA(28, 140, 60, 255))
    nvgText(vg, ox, oy - ch*0.26, "第 "..currentLevel.." 关通过！")

    -- 奖励分
    local lvDef = LEVEL_DEFS[math.min(currentLevel, MAX_LEVEL)]
    nvgFontSize(vg, math.floor(16 * uiScale))
    nvgFillColor(vg, nvgRGBA(120, 130, 155, 255))
    nvgText(vg, ox, oy - ch*0.04, "过关奖励  +" .. lvDef.scoreBonus)

    -- 总分
    nvgFontSize(vg, math.floor(20 * uiScale))
    nvgFillColor(vg, nvgRGBA(255, 145, 28, 255))
    nvgText(vg, ox, oy + ch*0.16, "累计得分: " .. totalScore)

    -- 进度倒计时条
    local barW = cw * 0.72
    local barH = 6
    local barX = ox - barW / 2
    local barY = oy + ch * 0.38
    nvgBeginPath(vg)
    nvgRoundedRect(vg, barX, barY, barW, barH, 3)
    nvgFillColor(vg, nvgRGBA(210, 228, 210, 255))
    nvgFill(vg)
    local fillRatio = levelClearTimer / 2.2  -- 1→0 随时间耗尽
    nvgBeginPath(vg)
    nvgRoundedRect(vg, barX, barY, barW * fillRatio, barH, 3)
    nvgFillColor(vg, nvgRGBA(55, 175, 85, 255))
    nvgFill(vg)
end

-- ============================================================================
-- 绘制全通关结算界面
-- ============================================================================
local function DrawWin()
    -- 半透明遮罩
    nvgFillColor(vg, nvgRGBA(18, 38, 80, 172))
    nvgBeginPath(vg); nvgRect(vg, 0, 0, screenW, screenH); nvgFill(vg)

    -- 白色卡片（稍高，显示更多信息）
    local cw, ch = math.min(screenW-40, math.floor(320 * uiScale)), math.floor(240 * uiScale)
    local ox, oy = screenW/2, screenH/2
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgBeginPath(vg)
    nvgRoundedRect(vg, ox-cw/2, oy-ch/2, cw, ch, 18)
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(200, 165, 28, 255))
    nvgStrokeWidth(vg, 3)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, ox-cw/2, oy-ch/2, cw, ch, 18)
    nvgStroke(vg)

    -- 顶部金色条
    local topPaint = nvgLinearGradient(vg, 0, oy-ch/2, 0, oy-ch/2+55,
        nvgRGBA(215,165,28,255), nvgRGBA(215,165,28,0))
    nvgBeginPath(vg)
    nvgRoundedRect(vg, ox-cw/2, oy-ch/2, cw, 55, 18)
    nvgFillPaint(vg, topPaint)
    nvgFill(vg)

    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 全通关标题
    nvgFontSize(vg, math.floor(28 * uiScale))
    nvgFillColor(vg, nvgRGBA(158, 118, 8, 255))
    nvgText(vg, ox, oy - ch*0.32, "🏆 全关卡通关！")

    -- 分隔线
    nvgStrokeColor(vg, nvgRGBA(220, 220, 230, 255))
    nvgStrokeWidth(vg, 1.2)
    nvgBeginPath(vg)
    nvgMoveTo(vg, ox - cw*0.38, oy - ch*0.12)
    nvgLineTo(vg, ox + cw*0.38, oy - ch*0.12)
    nvgStroke(vg)

    -- 关卡信息
    nvgFontSize(vg, math.floor(15 * uiScale))
    nvgFillColor(vg, nvgRGBA(120, 130, 155, 255))
    nvgText(vg, ox, oy + ch*0.01, "共完成  " .. MAX_LEVEL .. "  个关卡")

    -- 总分
    nvgFontSize(vg, math.floor(24 * uiScale))
    nvgFillColor(vg, nvgRGBA(255, 145, 28, 255))
    nvgText(vg, ox, oy + ch*0.18, "总得分: " .. totalScore)

    -- 提示
    nvgFontSize(vg, math.floor(14 * uiScale))
    nvgFillColor(vg, nvgRGBA(130, 140, 165, 255))
    nvgText(vg, ox, oy + ch*0.38, "点击重新挑战")
end

-- ============================================================================
-- 游戏逻辑（与原版相同）
-- ============================================================================
local function CountTypesInFrontLayer(r, c)
    local counts = {}
    local cell = grid[r][c]
    if #cell.layers == 0 then return counts end
    for s = 1, SLOTS do
        local id = cell.layers[1][s]
        if id then counts[id] = (counts[id] or 0) + 1 end
    end
    return counts
end

local function TryEliminate(r, c)
    local cell = grid[r][c]
    if #cell.layers == 0 then return false end
    local counts = CountTypesInFrontLayer(r, c)
    for id, cnt in pairs(counts) do
        if cnt >= MATCH then
            -- 消除前：记录每个待消物品的屏幕坐标，用于爆炸动画
            local cx, cy, cw, ch = CellRect(r, c)
            local pad    = cw * 0.06
            local usable = cw - pad * 2
            local sw2    = usable / SLOTS
            local baseY  = cy + ch - 4
            local removed = 0
            for s = 1, SLOTS do
                if cell.layers[1][s] == id and removed < MATCH then
                    local sx = cx + pad + (s - 0.5) * sw2
                    table.insert(elimAnims, {
                        x = sx, y = baseY,
                        def = GetDef(id),
                        scale = 1.0, alpha = 1.0,
                        vy = -(itemSize * 2.2),   -- 初速向上
                        timer = 0.55, dur = 0.55,
                        delay = removed * 0.05,   -- 三颗微错帧爆开
                    })
                    cell.layers[1][s] = nil
                    removed = removed + 1
                end
            end
            -- 得分随关卡提升（每关 +50%）
            local gain = math.floor(100 * (1 + (currentLevel - 1) * 0.5))
            score = score + gain
            totalScore = totalScore + gain
            table.insert(elimFlashes, {r=r, c=c, timer=1.0})
            SpawnBurst(r, c, GetDef(id))
            -- 延迟塌陷：等消除动画播完后（≈0.60s）再露出后层
            table.insert(pendingCollapses, {r=r, c=c, delay=0.60})
            -- 每次消除成功，所有锁定格子的锁定计数 -1
            for lr = 1, ROWS do
                for lc = 1, COLS do
                    if not activeGrid[lr] or not activeGrid[lr][lc] then goto lock_skip end
                    local lc_ = grid[lr][lc]
                    if lc_.locked then
                        lc_.lockCount = lc_.lockCount - 1
                        if lc_.lockCount <= 0 then
                            lc_.locked    = false
                            lc_.lockCount = 0
                        end
                    end
                    ::lock_skip::
                end
            end
            return true
        end
    end
    return false
end

local function CheckWin()
    for r = 1, ROWS do
        for c = 1, COLS do
            if not activeGrid[r] or not activeGrid[r][c] then goto cw_skip end
            if #grid[r][c].layers > 0 then return false end
            ::cw_skip::
        end
    end
    return true
end

-- 触发过关：加分，进入过关动画，然后显示结算界面
local function TriggerLevelClear()
    local lvDef = LEVEL_DEFS[math.min(currentLevel, MAX_LEVEL)]
    totalScore = totalScore + lvDef.scoreBonus
    score      = score      + lvDef.scoreBonus
    homeWinStreak = homeWinStreak + 1
    print(string.format("[LevelClear] 通过关卡 %d，进入结算界面", currentLevel))
    if currentLevel >= MAX_LEVEL then
        -- 通关所有关卡
        gameWin = true
    else
        -- 过关动画，2 秒后进结算界面
        levelClearAnim  = true
        levelClearTimer = 2.2
    end
end

-- ============================================================================
-- 道具逻辑
-- ============================================================================

-- 消除道具：收集所有可消除的格子（含完整组），随机选一个执行
-- 消除核心逻辑（不检查库存，供 UseToolElim 和开局消除共用）
-- 跨所有格子、所有层统计物品总数，选出数量最多的种类，
-- 移除时优先从前层取，前层不足再取后层，凑满 MATCH 个。
local function DoElimOnce()
    -- 第一步：统计所有格子所有层的物品总数
    local globalCounts = {}
    for r = 1, ROWS do
        for c = 1, COLS do
            if not activeGrid[r] or not activeGrid[r][c] then goto de_cnt end
            local cell = grid[r][c]
            for d = 1, #cell.layers do
                for s = 1, SLOTS do
                    local id = cell.layers[d][s]
                    if id then globalCounts[id] = (globalCounts[id] or 0) + 1 end
                end
            end
            ::de_cnt::
        end
    end
    -- 选出数量最多的物品类型（至少要有 MATCH 个才能消）
    local bestId, bestCnt = nil, 0
    for id, cnt in pairs(globalCounts) do
        if cnt > bestCnt then bestId = id; bestCnt = cnt end
    end
    if not bestId or bestCnt < MATCH then
        homeToastMsg = "当前没有可消除的组"; homeToastTimer = 1.5
        return false
    end
    -- 第二步：移除 MATCH 个 bestId，从前层向后层逐格逐槽查找
    local removed = 0
    local flashedCells = {}
    -- 先扫 layer 1（前层），再扫 layer 2+（后层）
    local maxDepth = 1
    for r = 1, ROWS do
        for c = 1, COLS do
            if activeGrid[r] and activeGrid[r][c] then
                local d = #grid[r][c].layers
                if d > maxDepth then maxDepth = d end
            end
        end
    end
    for d = 1, maxDepth do
        if removed >= MATCH then break end
        for r = 1, ROWS do
            if removed >= MATCH then break end
            for c = 1, COLS do
                if removed >= MATCH then break end
                if not activeGrid[r] or not activeGrid[r][c] then goto de_rem end
                local cell = grid[r][c]
                if d > #cell.layers then goto de_rem end
                local cx2, cy2, cw2, ch2 = CellRect(r, c)
                local pad    = cw2 * 0.06
                local usable = cw2 - pad * 2
                local sw2    = usable / SLOTS
                local baseY  = cy2 + ch2 - 4
                for s = 1, SLOTS do
                    if removed >= MATCH then break end
                    if cell.layers[d][s] == bestId then
                        local sx = cx2 + pad + (s - 0.5) * sw2
                        table.insert(elimAnims, {
                            x = sx, y = baseY, def = GetDef(bestId),
                            scale = 1.0, alpha = 1.0,
                            vy = -(itemSize * 2.2), timer = 0.55, dur = 0.55,
                            delay = removed * 0.05,
                        })
                        cell.layers[d][s] = nil
                        removed = removed + 1
                        if not flashedCells[r * 100 + c] then
                            flashedCells[r * 100 + c] = true
                            table.insert(elimFlashes, {r=r, c=c, timer=1.0})
                            SpawnBurst(r, c, GetDef(bestId))
                            table.insert(pendingCollapses, {r=r, c=c, delay=0.60})
                        end
                    end
                end
                ::de_rem::
            end
        end
    end
    if removed == 0 then
        homeToastMsg = "当前没有可消除的组"; homeToastTimer = 1.5
        return false
    end
    local gain = math.floor(100 * (1 + (currentLevel - 1) * 0.5))
    score      = score + gain
    totalScore = totalScore + gain
    return true
end

-- 消除道具（扣库存版）：只有实际消除了才扣库存
local function UseToolElim()
    if toolCounts.elim <= 0 then return end
    if DoElimOnce() then
        toolCounts.elim = toolCounts.elim - 1
        SpawnElimToolEffect()
        SavePlayerData()
    end
end

-- 冻结道具：倒计时暂停30秒
local function UseToolFreeze()
    if toolCounts.freeze <= 0 then return end
    freezeTimer = freezeTimer + 30.0
    toolCounts.freeze = toolCounts.freeze - 1
    SpawnFreezeToolEffect()
    SavePlayerData()
end

-- 重置道具：把剩余物品按生成规则重新生成
local function UseToolReset()
    if toolCounts.reset <= 0 then return end
    -- 统计当前剩余物品（所有层所有格子），只保留完整组
    local remaining = {}  -- {[typeId] = count}
    for r = 1, ROWS do
        for c = 1, COLS do
            if not activeGrid[r] or not activeGrid[r][c] then goto rst_skip end
            local cell = grid[r][c]
            for d = 1, #cell.layers do
                for s = 1, SLOTS do
                    local id = cell.layers[d][s]
                    if id then remaining[id] = (remaining[id] or 0) + 1 end
                end
            end
            ::rst_skip::
        end
    end
    -- 每种类型只保留完整组数（丢弃余数）
    local validGroups = {}  -- [typeId, typeId, ...]（每种出现 fullGroups 次）
    for id, cnt in pairs(remaining) do
        local fullGroups = math.floor(cnt / MATCH)
        for _ = 1, fullGroups do table.insert(validGroups, id) end
    end
    if #validGroups == 0 then
        homeToastMsg = "没有可重置的物品"; homeToastTimer = 1.5
        return
    end

    -- 清空所有格子
    for r = 1, ROWS do
        for c = 1, COLS do
            if activeGrid[r] and activeGrid[r][c] then
                grid[r][c].layers = {}
            end
        end
    end

    -- 打乱活动格顺序
    local sc = {}
    for _, pos in ipairs(activeCellList) do sc[#sc+1] = pos end
    for i = #sc, 2, -1 do
        local j = math.random(1, i)
        sc[i], sc[j] = sc[j], sc[i]
    end

    -- 使用与 InitGame 相同的循环配对策略分层填入
    -- 每层最多容纳 #sc 种类型（格子数限制）
    -- validGroups 每个元素代表一个"组"（MATCH 个同类型），分配到各层
    local function PlaceGroupsReset(groups, layerIdx)
        local n = #groups
        if n == 0 then return end
        -- 确保格子有该层
        for _, pos in ipairs(sc) do
            local cell = grid[pos[1]][pos[2]]
            while #cell.layers < layerIdx do
                cell.layers[#cell.layers + 1] = {nil, nil, nil}
            end
        end
        -- 打乱 groups 顺序
        local sg = {}
        for _, g in ipairs(groups) do sg[#sg+1] = g end
        for i = #sg, 2, -1 do
            local j = math.random(1, i)
            sg[i], sg[j] = sg[j], sg[i]
        end
        -- 循环配对：格子i分配 primary=sg[i], secondary=sg[(i%n)+1]
        for i = 1, n do
            local cell = sc[i]
            if not cell then break end
            local primary   = sg[i]
            local secondary = sg[(i % n) + 1]
            local assignment = {primary, primary, secondary}
            -- 打乱槽位顺序
            for k = 3, 2, -1 do
                local j = math.random(1, k)
                assignment[k], assignment[j] = assignment[j], assignment[k]
            end
            for s = 1, SLOTS do
                grid[cell[1]][cell[2]].layers[layerIdx][s] = assignment[s]
            end
        end
    end

    -- 按层容量分批放入（每层最多 #sc 种）
    local cap = #sc
    local layerIdx = 1
    local gi = 1
    while gi <= #validGroups do
        local batch = {}
        while gi <= #validGroups and #batch < cap do
            batch[#batch+1] = validGroups[gi]; gi = gi + 1
        end
        PlaceGroupsReset(batch, layerIdx)
        layerIdx = layerIdx + 1
    end

    toolCounts.reset = toolCounts.reset - 1
    SpawnResetToolEffect()
    SavePlayerData()
    -- 重置特效状态
    elimFlashes = {}; elimAnims = {}; pendingCollapses = {}
    flyItems = {}
    bossHP = #validGroups  -- 更新血条
end

-- 变化道具执行：把数量最多的物品类型作为目标，将其他完整组变成该类型
-- targetId: 目标物品类型
local function UseToolTransformExecute(targetId)
    activeToolMode = nil
    -- 跨棋盘统计所有前层中每种"非目标"类型的位置列表
    local otherPos = {}   -- id -> { {r,c,s}, ... }
    for r = 1, ROWS do
        for c = 1, COLS do
            if not activeGrid[r] or not activeGrid[r][c] then goto tf_skip end
            local cell = grid[r][c]
            if #cell.layers == 0 then goto tf_skip end
            for s = 1, SLOTS do
                local id = cell.layers[1][s]
                if id and id ~= targetId then
                    if not otherPos[id] then otherPos[id] = {} end
                    table.insert(otherPos[id], {r, c, s})
                end
            end
            ::tf_skip::
        end
    end
    -- 收集所有可替换槽位（按类型数量降序），替换 MATCH*2 个 → targetId（凑 2 组）
    local sortedIds = {}
    for id, _ in pairs(otherPos) do table.insert(sortedIds, id) end
    table.sort(sortedIds, function(a, b) return #otherPos[a] > #otherPos[b] end)

    -- 把所有槽位按类型优先级展平成列表
    local allSlots = {}
    for _, otherId in ipairs(sortedIds) do
        for _, pos in ipairs(otherPos[otherId]) do
            table.insert(allSlots, pos)
        end
    end

    -- 替换前 MATCH*2 个槽位（即额外变出 2 组目标类型）
    local replaceCount = math.min(MATCH * 2, #allSlots)
    local changed = replaceCount > 0 and 1 or 0
    for i = 1, replaceCount do
        local pos = allSlots[i]
        grid[pos[1]][pos[2]].layers[1][pos[3]] = targetId
    end

    if changed == 0 then
        homeToastMsg = "没有可变化的组"; homeToastTimer = 1.5
        return
    end
    toolCounts.transform = toolCounts.transform - 1
    SpawnTransformToolEffect()
    SavePlayerData()
    -- 变化后立即检测消除
    for r = 1, ROWS do
        for c = 1, COLS do
            if activeGrid[r] and activeGrid[r][c] then
                TryEliminate(r, c)
            end
        end
    end
end

-- 变化道具激活：自动选出数量最多的物品类型，直接执行变化
local function UseToolTransformActivate()
    if toolCounts.transform <= 0 then return end
    -- 跨棋盘统计前层每种物品总数，选出数量最多的作为目标
    local globalCounts = {}
    for r = 1, ROWS do
        for c = 1, COLS do
            if not activeGrid[r] or not activeGrid[r][c] then goto tf_cnt end
            local cell = grid[r][c]
            if #cell.layers == 0 then goto tf_cnt end
            for s = 1, SLOTS do
                local id = cell.layers[1][s]
                if id then globalCounts[id] = (globalCounts[id] or 0) + 1 end
            end
            ::tf_cnt::
        end
    end
    local bestId, bestCnt = nil, 0
    for id, cnt in pairs(globalCounts) do
        if cnt > bestCnt then bestId = id; bestCnt = cnt end
    end
    if not bestId then
        homeToastMsg = "没有可变化的组"; homeToastTimer = 1.5
        return
    end
    UseToolTransformExecute(bestId)
end

-- 前向声明（AssignSpecialCells 定义在 InitGame 之后，需预声明）
local AssignSpecialCells

-- ============================================================================
-- 初始化关卡（进入指定关，保留跨关累计总分）
-- ============================================================================
InitGame = function()
    local lvDef = LEVEL_DEFS[math.min(currentLevel, MAX_LEVEL)]

    -- 更新全局网格尺寸（由形状决定）
    local sh = SHAPE_DEFS[lvDef.shapeIdx]
    ROWS = sh.vrows
    COLS = sh.vcols

    -- 构建 activeGrid：依形状坐标列表标记有效格
    activeGrid = {}
    for r = 1, ROWS do activeGrid[r] = {} end
    for _, pos in ipairs(sh.cells) do
        activeGrid[pos[1]][pos[2]] = true
    end

    -- 固定关卡随机种子：同一关每次生成完全相同的布局
    math.randomseed(currentLevel * 99991 + 7)

    grid = {}
    score = 0        -- 本关分数归零（总分 totalScore 不动）
    gameWin = false
    levelClearAnim  = false
    levelClearTimer = 0.0
    elimFlashes      = {}
    elimAnims        = {}
    pendingCollapses = {}
    burstParticles   = {}
    expandRings    = {}
    scorePopups    = {}
    flyItems       = {}
    -- 道具专属特效重置
    elimWave        = nil
    transformSwirls = {}
    freezeIce       = {}
    resetFlash      = nil
    boardShake      = nil
    gridOverlay     = {}
    -- 本关总物品数 = (types + dupTypes) × MATCH，与消除次数对应
    local lvTypes  = math.min(lvDef.types, #ITEM_DEFS)
    local lvDup    = math.min(lvDef.dupTypes or 0, lvTypes)
    bossMaxHP      = (lvTypes + lvDup) * MATCH
    bossHP         = bossMaxHP
    bossHitTimer   = 0.0
    timeLeft       = lvDef.time
    gameOver       = false
    timerWarnTimer = 0.0
    drag.active    = false
    activeTouchId  = -1
    gamePaused     = false
    showExitConfirm = false
    exitConfirmBtnRects = {}

    for r = 1, ROWS do
        grid[r] = {}
        for c = 1, COLS do
            if activeGrid[r][c] then
                local cell = {
                    layers      = {},
                    -- 特殊格子属性（默认为普通）
                    locked      = false,   -- 是否锁定
                    lockCount   = 0,       -- 解锁所需消除次数
                    moveType    = nil,     -- "vert" | "horiz" | nil
                    moveOffsetX = 0,
                    moveOffsetY = 0,
                    moveSpeed   = 0,
                    moveRange   = 0,
                    moveDir     = 1,
                }
                for d = 1, lvDef.layers do
                    cell.layers[d] = {nil, nil, nil}
                end
                grid[r][c] = cell
            else
                -- 非活动格：放一个空占位（避免 nil 索引崩溃）
                grid[r][c] = { layers={}, inactive=true }
            end
        end
    end

    -- ========================================================================
    -- 有解生成算法（Guaranteed-Solvable Generation）
    -- 核心原则：同一类型的 MATCH(3) 个物品必须全部分配到同一层(layer)
    -- 这样每层内部可以独立完成消除，层与层之间无跨层依赖，彻底杜绝死局。
    --
    -- 算法步骤：
    --   1. 随机选出 typeCount 种物品类型，打乱顺序
    --   2. 将这些类型按 sh.count 一组分配到各前层（每层最多 sh.count 种）
    --   3. dupCount 种从前层类型中选取，单独放入最后一层（后层）
    --   4. 每层内：用"槽位池"均匀分配——把该层所有 slots 列出来并打乱，
    --      然后每种类型取 MATCH 个连续槽位，保证每种恰好 3 个
    -- ========================================================================
    local numLayers  = lvDef.layers
    local typeCount  = math.min(lvDef.types, #ITEM_DEFS)
    local dupCount   = math.min(lvDef.dupTypes or 0, typeCount)

    -- 前层数
    local backLayerIdx  = (dupCount > 0) and numLayers or nil
    local frontLayerCnt = numLayers - (backLayerIdx and 1 or 0)
    frontLayerCnt = math.max(1, frontLayerCnt)

    -- 随机打乱 ITEM_DEFS 索引，选 typeCount 种
    local shuffledIdx = {}
    for i = 1, #ITEM_DEFS do shuffledIdx[i] = i end
    for i = #shuffledIdx, 2, -1 do
        local j = math.random(1, i)
        shuffledIdx[i], shuffledIdx[j] = shuffledIdx[j], shuffledIdx[i]
    end

    -- 前 typeCount 种供前层，其中前 dupCount 种同时也放后层
    local frontTypes = {}
    local dupTypeIds = {}
    for i = 1, typeCount do
        frontTypes[i] = ITEM_DEFS[shuffledIdx[i]].id
    end
    for i = 1, dupCount do
        dupTypeIds[i] = frontTypes[i]
    end

    -- 打乱 frontTypes 顺序（使各层分配随机）
    for i = #frontTypes, 2, -1 do
        local j = math.random(1, i)
        frontTypes[i], frontTypes[j] = frontTypes[j], frontTypes[i]
    end

    -- 有序的活动格列表（用于构造槽位池 & 道具重置）
    activeCellList = {}   -- 赋值到模块级变量，供 UseToolReset 使用
    for _, pos in ipairs(sh.cells) do
        activeCellList[#activeCellList + 1] = {pos[1], pos[2]}
    end

    -- -----------------------------------------------------------------------
    -- PlaceGroupsInLayer: 循环配对策略，保证每格至多2种类型（2个相同+1个不同）
    -- 规则：将 n 种类型分配给 n 个格子，格子i分配 [G[i], G[i], G[(i%n)+1]]
    --   - G[k] 总出现：2次（格k的primary）+ 1次（格k-1的secondary）= 3 = MATCH ✓
    --   - 每格只有2种类型，不会出现[A,B,C]三种不同类型 ✓
    --   - 同种类型所有MATCH个物品仍在同一层，无跨层依赖 ✓
    -- -----------------------------------------------------------------------
    local function PlaceGroupsInLayer(groups, layerIdx)
        local n = #groups
        if n == 0 then return end
        -- 打乱 groups 顺序（随机配对）
        local sg = {}
        for _, g in ipairs(groups) do sg[#sg+1] = g end
        for i = #sg, 2, -1 do
            local j = math.random(1, i)
            sg[i], sg[j] = sg[j], sg[i]
        end
        -- 打乱活动格顺序（随机分配到格子）
        local sc = {}
        for _, pos in ipairs(activeCellList) do sc[#sc+1] = pos end
        for i = #sc, 2, -1 do
            local j = math.random(1, i)
            sc[i], sc[j] = sc[j], sc[i]
        end
        -- 循环配对：格子i分配 primary=G[i], secondary=G[(i%n)+1]
        for i = 1, n do
            local cell = sc[i]
            if not cell then break end
            local primary   = sg[i]
            local secondary = sg[(i % n) + 1]
            -- 构造槽位内容：2个primary + 1个secondary，打乱顺序增加视觉随机性
            local assignment = {primary, primary, secondary}
            for k = 3, 2, -1 do
                local j = math.random(1, k)
                assignment[k], assignment[j] = assignment[j], assignment[k]
            end
            for s = 1, SLOTS do
                grid[cell[1]][cell[2]].layers[layerIdx][s] = assignment[s]
            end
        end
        -- 格子数 > n 时多余格子保持空（CollapseIfEmpty 自动清理）
    end

    -- 1. 前层分配：将 typeCount 种类型按 sh.count 一批分给各前层
    local typeIdx = 1
    for d = 1, frontLayerCnt do
        local layerGroups = {}
        -- 每层最多 sh.count 种（= LAYER_CAP / MATCH），正好填满该层
        local capacity = sh.count
        while typeIdx <= typeCount and #layerGroups < capacity do
            layerGroups[#layerGroups + 1] = frontTypes[typeIdx]
            typeIdx = typeIdx + 1
        end
        if #layerGroups > 0 then
            PlaceGroupsInLayer(layerGroups, d)
        end
    end

    -- 2. 后层分配：与前层相同的循环配对策略
    -- 规则：格子i分配 [G[i], G[i], G[(i%n)+1]]
    -- 这样G[k]出现次数：格k有2个 + 格k-1有1个 = 3个恰好完成消除 ✓
    -- 每格只有2种类型，不会出现[A,B,C]三种不同类型 ✓
    local function PlaceGroupsInLayerBack(groups, layerIdx)
        -- 直接复用前层的循环配对逻辑，保证每种类型恰好出现 MATCH 次
        PlaceGroupsInLayer(groups, layerIdx)
    end

    if backLayerIdx and dupCount > 0 then
        PlaceGroupsInLayerBack(dupTypeIds, backLayerIdx)
    end

    -- 清理空层（只处理活动格）
    for r = 1, ROWS do
        for c = 1, COLS do
            if not activeGrid[r][c] then goto skip_clean end
            local cell = grid[r][c]
            for d = #cell.layers, 1, -1 do
                local isEmpty = true
                for s = 1, SLOTS do
                    if cell.layers[d][s] then isEmpty = false; break end
                end
                if isEmpty then table.remove(cell.layers, d)
                else break end
            end
            CollapseIfEmpty(r, c)
            ::skip_clean::
        end
    end

    -- 后处理：保证每个有物品的格子前层至少有 1 个空槽，避免开局必死
    for r = 1, ROWS do
        for c = 1, COLS do
            if not activeGrid[r][c] then goto skip_postproc end
            local cell = grid[r][c]
            if #cell.layers > 0 then
                local hasEmpty = false
                for s = 1, SLOTS do
                    if not cell.layers[1][s] then hasEmpty = true; break end
                end
                if not hasEmpty then
                    -- 从前层随机取一个物品推到新建的最深层
                    local s = math.random(1, SLOTS)
                    local moved = cell.layers[1][s]
                    cell.layers[1][s] = nil
                    local newLayer = { nil, nil, nil }
                    newLayer[1] = moved
                    table.insert(cell.layers, newLayer)
                end
            end
            ::skip_postproc::
        end
    end

    -- 物品放置完毕后分配特殊格子
    AssignSpecialCells()
end

-- ============================================================================
-- 分配特殊格子（锁定/垂直移动/水平移动）
-- 在 InitGame 最后、物品放置完成后调用
-- 直接读取 LEVEL_DEFS[currentLevel].specials 配方逐项分配
-- ============================================================================
AssignSpecialCells = function()
    local lvDef = LEVEL_DEFS[math.min(currentLevel, MAX_LEVEL)]
    local specials = lvDef.specials
    if not specials or #specials == 0 then return end

    -- 统计有物品且未被标记的活动格
    local filledCells = {}
    for r = 1, ROWS do
        for c = 1, COLS do
            if activeGrid[r] and activeGrid[r][c] and #grid[r][c].layers > 0 then
                table.insert(filledCells, {r = r, c = c})
            end
        end
    end
    -- 打乱顺序，保证每次随机选不同格子
    for i = #filledCells, 2, -1 do
        local j = math.random(1, i)
        filledCells[i], filledCells[j] = filledCells[j], filledCells[i]
    end

    -- 安全上限：至少留 4 个普通格子可操作
    local safeMax = math.max(0, #filledCells - 4)
    local pickIdx = 1   -- 从 filledCells 顺序取格子

    for _, spec in ipairs(specials) do
        local count = math.min(spec.count or 1, safeMax - (pickIdx - 1))
        if count <= 0 then break end

        for _ = 1, count do
            -- 找下一个未分配特殊属性的格子
            while pickIdx <= #filledCells do
                local pos  = filledCells[pickIdx]
                local cell = grid[pos.r][pos.c]
                pickIdx = pickIdx + 1
                if not cell.locked and not cell.moveType then
                    if spec.type == "locked" then
                        cell.locked    = true
                        cell.lockCount = spec.hits or 2
                    elseif spec.type == "vert" then
                        cell.moveType  = "vert"
                        cell.moveDir   = (math.random(0, 1) == 0) and 1 or -1
                        cell.moveSpeed = (spec.spd or 30) + math.random(0, 8)
                        cell.moveRange = math.floor(cellH * 0.28)
                    elseif spec.type == "horiz" then
                        cell.moveType  = "horiz"
                        cell.moveDir   = (math.random(0, 1) == 0) and 1 or -1
                        cell.moveSpeed = (spec.spd or 30) + math.random(0, 8)
                        cell.moveRange = math.floor(cellW * 0.28)
                    end
                    break
                end
            end
        end
    end
end

-- 从第1关重新开始（失败/通关后重置）
-- 失败后：回主界面（连胜清零，分数保留供展示）
local function RestartGame()
    homeWinStreak = 0
    appPhase = "home"
end

-- ============================================================================
-- 拖拽操作（与原版相同）
-- ============================================================================
local function BeginDrag(r, c, mx, my)
    local cell = grid[r][c]
    if #cell.layers == 0 then return end
    if cell.locked then return end  -- 锁定格子不可拖拽
    local s = HitSlot(mx, my, r, c)
    if s == 0 then s = 1 end
    local srcS = 0
    for offset = 0, SLOTS-1 do
        for _, ds in ipairs({0, -offset, offset}) do
            local ts = s + ds
            if ts >= 1 and ts <= SLOTS and cell.layers[1][ts] then
                srcS = ts; break
            end
        end
        if srcS > 0 then break end
    end
    if srcS == 0 then return end
    drag.active = true
    drag.srcR = r; drag.srcC = c; drag.srcS = srcS
    drag.itemId = cell.layers[1][srcS]
    drag.mx = mx; drag.my = my
    drag.hoverR = 0; drag.hoverC = 0
end

local function UpdateDrag(mx, my)
    if not drag.active then return end
    drag.mx = mx; drag.my = my
    local hr, hc = HitCell(mx, my)
    drag.hoverR = hr; drag.hoverC = hc
end

local function EndDrag(mx, my)
    if not drag.active then return end
    drag.active = false
    local tr, tc = HitCell(mx, my)
    if tr == 0 then return end
    local ts = FindEmptyFrontSlot(tr, tc)
    if ts == 0 then return end
    -- 放回原槽：取消
    if tr == drag.srcR and tc == drag.srcC and ts == drag.srcS then return end

    -- 移除原位物品
    grid[drag.srcR][drag.srcC].layers[1][drag.srcS] = nil

    -- 只有确认放到了【其他格子】才触发原格塌陷（后层前移）
    -- 若放回同格不同槽，不塌陷，直接归位
    local movedToOtherCell = (tr ~= drag.srcR or tc ~= drag.srcC)

    -- 放置到目标格
    if #grid[tr][tc].layers == 0 then
        grid[tr][tc].layers = { {nil, nil, nil} }
    end
    grid[tr][tc].layers[1][ts] = drag.itemId

    -- 确认跨格移动后，再检查原格是否需要塌陷
    if movedToOtherCell then
        CollapseIfEmpty(drag.srcR, drag.srcC)
    end

    local changed = true
    while changed do changed = TryEliminate(tr, tc) end
    -- CheckWin 延迟到 pendingCollapses 处理完后执行，避免空 layer 未清除导致误判
end

-- ============================================================================
-- 事件处理
-- ============================================================================
function HandleNanoVGRender(eventType, eventData)
    dpr     = graphics:GetDPR()
    screenW = math.floor(graphics:GetWidth()  / dpr)
    screenH = math.floor(graphics:GetHeight() / dpr)

    -- UI 缩放系数：以 390×844 为设计基准，取宽高缩放比的较小值
    uiScale = math.min(screenW / DESIGN_W, screenH / DESIGN_H)
    uiScale = math.max(0.65, math.min(2.5, uiScale))
    -- HUD 头部高度随屏幕等比缩放
    HEADER_H = math.floor(62 * uiScale)

    -- 布局：三区固定占比，互不挤压
    -- 工具区 15%（min 按 uiScale 缩放）、动画区 12%（min 按 uiScale 缩放）、格子区占剩余
    toolsAreaH = math.max(math.floor(90 * uiScale), math.floor(screenH * 0.15))
    animAreaH  = math.max(math.floor(70 * uiScale), math.floor(screenH * 0.12))

    -- 游戏区可用范围（留外圈间距 BOARD_MARGIN）
    local areaTop    = HEADER_H + animAreaH + 8
    local areaBottom = screenH - toolsAreaH - 8
    local areaH      = areaBottom - areaTop
    local areaW      = screenW

    -- 按 4列×6行 为基准反推单格尺寸，保持 108:128 宽高比（≈0.84375）
    local CELL_RATIO = FIXED_CELL_W / FIXED_CELL_H  -- ≈0.84375
    local MAX_REF_COLS = 4
    local MAX_REF_ROWS = 6
    local BOARD_MARGIN = 10  -- 外圈最小间距（px）

    -- 可放 MAX_REF_COLS 列 / MAX_REF_ROWS 行 时的单格最大尺寸
    local maxCellByW = math.floor((areaW  - BOARD_MARGIN*2 - SHELF_GAP*(MAX_REF_COLS-1)) / MAX_REF_COLS)
    local maxCellByH = math.floor((areaH  - BOARD_MARGIN*2 - SHELF_GAP*(MAX_REF_ROWS-1)) / MAX_REF_ROWS)

    -- 取宽/高约束中较小者，再按比例得另一边
    local cH, cW
    if maxCellByW * CELL_RATIO <= maxCellByH then
        -- 宽方向更紧
        cW = maxCellByW
        cH = math.floor(cW / CELL_RATIO)
    else
        -- 高方向更紧
        cH = maxCellByH
        cW = math.floor(cH * CELL_RATIO)
    end
    cellW = cW
    cellH = cH

    local slotW  = cellW / SLOTS
    itemSize = slotW * 0.92
    itemH    = cellH * 0.80

    local boardW = COLS * cellW + (COLS-1) * SHELF_GAP
    local boardH = ROWS * cellH + (ROWS-1) * SHELF_GAP

    -- 居中摆放
    boardX = math.floor((areaW - boardW) / 2)
    boardY = areaTop + math.floor((areaH - boardH) / 2)

    -- 更新 Boss 位置（动画区垂直 60% 处，水平偏右）
    bossCX = math.floor(screenW * 0.50)
    bossCY = math.floor(HEADER_H + animAreaH * 0.60)

    nvgBeginFrame(vg, screenW, screenH, dpr)

    if appPhase == "logo" then
        DrawLogo()
    elseif appPhase == "splash" then
        DrawSplash()
    elseif appPhase == "home" then
        DrawHome()
        if homeNavTab == 3 then DrawShop() end
        if showLevelStartPopup then DrawLevelStartPopup() end
    else
        -- game 阶段
        DrawBackground()
        DrawAnimArea()
        DrawHUD()
        -- 棋盘震动偏移（消除道具冲击波）
        local shakeOX, shakeOY = 0, 0
        if boardShake then
            local t = boardShake.life / boardShake.maxLife
            local mag = math.floor(t * 7 * math.sin(t * math.pi * 6))
            shakeOX = mag * (math.random(2)==1 and 1 or -1)
            shakeOY = math.floor(mag * 0.5) * (math.random(2)==1 and 1 or -1)
        end
        if shakeOX ~= 0 or shakeOY ~= 0 then nvgSave(vg); nvgTranslate(vg, shakeOX, shakeOY) end
        for r = 1, ROWS do
            for c = 1, COLS do
                if activeGrid[r] and activeGrid[r][c] then
                    DrawShelfCell(r, c)
                end
            end
        end
        DrawExpandRings()
        DrawBurstParticles()
        DrawElimAnims()
        DrawFlyItems()
        DrawScorePopups()
        -- 道具专属特效（在网格上方、UI 下方）
        DrawToolEffects()
        if shakeOX ~= 0 or shakeOY ~= 0 then nvgRestore(vg) end
        DrawDragItem()
        DrawToolsArea()
        if levelClearAnim then DrawLevelTransition() end
        if gameWin then DrawWin() end
        if gameOver then DrawGameOver() end
        if gamePaused then DrawPauseOverlay() end
        if showExitConfirm then DrawExitConfirm() end
        if showLevelTable then DrawLevelTable() end
        if showSettlement then DrawSettlement() end
        if showChestPopup then DrawChestPopup() end
    end

    -- 金手指面板（始终绘制在最顶层）
    DrawCheatPanel()

    nvgEndFrame(vg)
end

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()



    -- Logo 计时推进
    if appPhase == "logo" then
        logoTimer = logoTimer + dt
        if logoTimer >= LOGO_DUR then
            appPhase = "splash"
        end
        return
    end

    -- 加载条计时推进
    if appPhase == "splash" then
        splashTimer = splashTimer + dt
        if splashTimer >= SPLASH_DUR then
            appPhase = "home"
        end
        return
    end

    -- 主界面：只更新 Toast 倒计时
    if appPhase == "home" then
        if homeToastTimer > 0 then
            homeToastTimer = homeToastTimer - dt
        end
        return
    end

    -- 开局消除：InitGame 后首帧执行（库存已在弹窗中预扣，直接执行效果）
    if pendingElimAtStart > 0 then
        for _ = 1, pendingElimAtStart do
            DoElimOnce()
        end
        pendingElimAtStart = 0
    end

    -- 过关动画倒计时推进
    if levelClearAnim then
        levelClearTimer = levelClearTimer - dt
        if levelClearTimer <= 0 then
            levelClearAnim = false
            -- 进入结算界面
            settleClearedLevel = currentLevel
            -- 从随机位置开始持续滚动，等玩家点击广告后停止
            settleMultIdx   = math.random(1, 5)
            settleAnimating = true
            settleStepAccum = 0.0
            -- 宝箱进度推进
            chestProgress = chestProgress + 1
            showSettlement  = true
            showChestPopup  = false
            settleBtnRects  = {}
            chestPopupBtnRect = {}
        end
    end

    -- 结算倍率滚动动画：持续循环，直到玩家点击广告按钮
    if settleAnimating then
        settleStepAccum = settleStepAccum + dt
        local stepInterval = 0.12   -- 每格切换间隔（匀速）
        if settleStepAccum >= stepInterval then
            settleStepAccum = settleStepAccum - stepInterval
            settleMultIdx   = (settleMultIdx % 5) + 1
        end
    end

    -- 冻结计时器消耗
    if freezeTimer > 0 then
        freezeTimer = math.max(0, freezeTimer - dt)
    end

    -- 倒计时推进（胜利/失败/过关动画/结算界面/暂停期间停止；冻结时暂停）
    if not gameWin and not gameOver and not levelClearAnim and not showSettlement and not showChestPopup and not gamePaused then
        if freezeTimer <= 0 then
            timeLeft = timeLeft - dt
            if timeLeft <= 0 then
                timeLeft = 0
                gameOver = true
                drag.active = false
            end
        end
        -- 低于10秒且未冻结时触发数字抖动
        if timeLeft <= 10 and freezeTimer <= 0 then
            timerWarnTimer = timerWarnTimer + dt * 6.0
        end
    end

    -- 消除格闪光
    local newFlashes = {}
    for _, f in ipairs(elimFlashes) do
        f.timer = f.timer - dt * 2.0
        if f.timer > 0 then table.insert(newFlashes, f) end
    end
    elimFlashes = newFlashes

    -- 消除爆炸动画
    local newElim = {}
    for _, a in ipairs(elimAnims) do
        if a.delay and a.delay > 0 then
            a.delay = a.delay - dt
            table.insert(newElim, a)
        else
            a.timer = a.timer - dt
            if a.timer > 0 then
                local p = 1.0 - a.timer / a.dur
                a.scale = 1.0 + math.sin(p * math.pi) * 0.5
                a.alpha = math.max(0, 1.0 - p * p)
                a.y     = a.y + a.vy * dt
                a.vy    = a.vy + 320 * dt  -- 重力回落
                table.insert(newElim, a)
            end
        end
    end
    elimAnims = newElim

    -- 延迟塌陷：消除动画播完后再露出后层
    local newPC = {}
    for _, pc in ipairs(pendingCollapses) do
        pc.delay = pc.delay - dt
        if pc.delay > 0 then
            table.insert(newPC, pc)
        else
            if grid then
                CollapseIfEmpty(pc.r, pc.c)
                collapseJustDone = true
            end
        end
    end
    pendingCollapses = newPC
    -- 有塌陷刚完成，且队列已清空时检查过关
    if collapseJustDone and #pendingCollapses == 0 and not gameWin and not levelClearAnim then
        if CheckWin() then TriggerLevelClear() end
    end
    collapseJustDone = false

    -- 粒子爆发
    local newP = {}
    for _, p in ipairs(burstParticles) do
        p.x    = p.x + p.vx * dt
        p.y    = p.y + p.vy * dt
        p.vy   = p.vy + 160 * dt  -- 模拟重力
        p.life = p.life - dt
        if p.life > 0 then table.insert(newP, p) end
    end
    burstParticles = newP

    -- 扩散光环
    local newR = {}
    for _, ring in ipairs(expandRings) do
        ring.life = ring.life - dt
        if ring.life > 0 then table.insert(newR, ring) end
    end
    expandRings = newR

    -- 移动格子偏移更新（仅在游戏进行中，只处理活动格）
    if not gameWin and not gameOver and not levelClearAnim and grid then
        for mr = 1, ROWS do
            for mc = 1, COLS do
                if not activeGrid[mr] or not activeGrid[mr][mc] then goto move_skip end
                local mc_ = grid[mr][mc]
                if mc_.moveType == "vert" then
                    mc_.moveOffsetY = mc_.moveOffsetY + mc_.moveDir * mc_.moveSpeed * dt
                    if math.abs(mc_.moveOffsetY) >= mc_.moveRange then
                        mc_.moveOffsetY = mc_.moveRange * (mc_.moveDir > 0 and 1 or -1)
                        mc_.moveDir = -mc_.moveDir
                    end
                elseif mc_.moveType == "horiz" then
                    mc_.moveOffsetX = mc_.moveOffsetX + mc_.moveDir * mc_.moveSpeed * dt
                    if math.abs(mc_.moveOffsetX) >= mc_.moveRange then
                        mc_.moveOffsetX = mc_.moveRange * (mc_.moveDir > 0 and 1 or -1)
                        mc_.moveDir = -mc_.moveDir
                    end
                end
                ::move_skip::
            end
        end
    end

    -- 分数弹出
    local newPop = {}
    for _, p in ipairs(scorePopups) do
        p.y    = p.y + p.vy * dt
        p.life = p.life - dt
        if p.life > 0 then table.insert(newPop, p) end
    end
    scorePopups = newPop

    -- 道具专属特效更新
    if elimWave then
        elimWave.life = elimWave.life - dt
        if elimWave.life <= 0 then elimWave = nil end
    end
    if boardShake then
        boardShake.life = boardShake.life - dt
        if boardShake.life <= 0 then boardShake = nil end
    end
    if resetFlash then
        resetFlash.life = resetFlash.life - dt
        if resetFlash.life <= 0 then resetFlash = nil end
    end
    local newSwirls = {}
    for _, p in ipairs(transformSwirls) do
        p.x = p.x + p.vx * dt; p.y = p.y + p.vy * dt
        p.life = p.life - dt
        if p.life > 0 then table.insert(newSwirls, p) end
    end
    transformSwirls = newSwirls
    local newIce = {}
    for _, p in ipairs(freezeIce) do
        p.x = p.x + p.vx * dt; p.y = p.y + p.vy * dt
        p.angle = p.angle + dt * 4
        p.life = p.life - dt
        if p.life > 0 then table.insert(newIce, p) end
    end
    freezeIce = newIce
    local newOv = {}
    for _, ov in ipairs(gridOverlay) do
        ov.life = ov.life - dt
        if ov.life > 0 then table.insert(newOv, ov) end
    end
    gridOverlay = newOv

    -- 飞行物品
    local newFly = {}
    local hitThisFrame = false
    for _, fi in ipairs(flyItems) do
        fi.t = fi.t + dt * fi.speed
        if fi.t < 1.0 then
            table.insert(newFly, fi)
        else
            -- 抵达 Boss，触发受击
            hitThisFrame = true
        end
    end
    flyItems = newFly
    if hitThisFrame then
        bossHitTimer = 0.32
    end

    -- Boss 受击计时器
    if bossHitTimer > 0 then
        bossHitTimer = math.max(0, bossHitTimer - dt)
    end
end

local function MX(x) return x / dpr end
local function MY(y) return y / dpr end

-- ============================================================================
-- 结算界面点击处理（返回 true 表示已消费该点击）
-- ============================================================================
-- 结算领完金币后的后续逻辑（检查宝箱 or 进主界面）
local function ProceedAfterSettlement()
    showSettlement = false
    if chestProgress >= 5 then
        chestProgress = 0
        local coinOptions = {100, 200, 300}
        chestRewardCoins = coinOptions[math.random(1, 3)]
        local toolKeys = {}
        for _, td in ipairs(TOOL_DEFS) do table.insert(toolKeys, td.key) end
        chestRewardToolKey = toolKeys[math.random(1, #toolKeys)]
        showChestPopup = true
    else
        currentLevel = currentLevel + 1
        appPhase = "home"
    end
end

-- 宝箱领完后的后续逻辑（给道具 + 进主界面）
local function ProceedAfterChest()
    if chestRewardToolKey then
        toolCounts[chestRewardToolKey] = (toolCounts[chestRewardToolKey] or 0) + 1
    end
    SavePlayerData()
    showChestPopup = false
    currentLevel = currentLevel + 1
    appPhase = "home"
end

local function HandleSettlementTap(mx, my)
    -- 宝箱弹窗优先
    if showChestPopup then
        for _, r in ipairs(chestPopupBtnRect) do
            if mx >= r.x and mx <= r.x+r.w and my >= r.y and my <= r.y+r.h then
                if r.id == "direct" then
                    -- 直接领取
                    playerCoins = playerCoins + chestRewardCoins
                    ProceedAfterChest()
                elseif r.id == "ad" then
                    -- 看广告双倍领取
                    sdk:ShowRewardVideoAd(function(result)
                        if result.success then
                            playerCoins = playerCoins + chestRewardCoins * 2
                        else
                            playerCoins = playerCoins + chestRewardCoins  -- 广告失败仍给基础奖励
                        end
                        ProceedAfterChest()
                    end)
                end
                break
            end
        end
        return true  -- 弹窗期间吃掉所有点击
    end

    if not showSettlement then return false end

    for _, r in ipairs(settleBtnRects) do
        if mx >= r.x and mx <= r.x+r.w and my >= r.y and my <= r.y+r.h then
            local mult = SETTLE_MULTS[settleMultIdx]
            if r.id == "direct" then
                -- 直接领取基础金币，停止滚动
                settleAnimating = false
                playerCoins = playerCoins + settleBaseCoins
                SavePlayerData()
                ProceedAfterSettlement()
            elseif r.id == "ad" then
                -- 立即停止滚动，锁定当前倍率，再播广告
                settleAnimating = false
                sdk:ShowRewardVideoAd(function(result)
                    if result.success then
                        playerCoins = playerCoins + settleBaseCoins * mult
                    else
                        playerCoins = playerCoins + settleBaseCoins  -- 广告失败给基础金币
                    end
                    SavePlayerData()
                    ProceedAfterSettlement()
                end)
            end
            return true
        end
    end
    return true  -- 结算期间吃掉所有点击（防止穿透）
end

-- ============================================================================
-- 游戏阶段：工具按钮点击处理（返回 true 表示已消费该点击）
-- ============================================================================
local function HandleToolTap(mx, my)
    for _, btn in ipairs(toolBtnRects) do
        if mx >= btn.x and mx <= btn.x+btn.w and my >= btn.y and my <= btn.y+btn.h then
            if btn.key == "elim" then
                UseToolElim()
            elseif btn.key == "transform" then
                UseToolTransformActivate()
            elseif btn.key == "freeze" then
                UseToolFreeze()
            elseif btn.key == "reset" then
                UseToolReset()
            end
            return true
        end
    end
    return false
end

-- ============================================================================
-- 变化模式下：点击格子中物品选择目标类型
-- 返回 true 表示已消费该点击
-- ============================================================================
local function HandleTransformSelect(mx, my)
    if activeToolMode ~= "transform_select" then return false end
    local r, c = HitCell(mx, my)
    if r > 0 then
        local cell = grid[r][c]
        if #cell.layers > 0 then
            -- 找前层第一个非空物品作为选中类型
            for s = 1, SLOTS do
                local id = cell.layers[1][s]
                if id then
                    UseToolTransformExecute(id)
                    return true
                end
            end
        end
    end
    -- 点击空白处取消
    activeToolMode = nil
    return true
end

-- 检测点击是否落在 HUD 关卡表按钮上（新位置：居中右侧）
function HitLevelTableBtn(mx, my)
    local hudMidX  = screenW * 0.5
    local lvLabelW = math.floor(68 * uiScale)
    local btnX     = hudMidX + lvLabelW * 0.5 + math.floor(4 * uiScale)
    local btnY     = HEADER_H * 0.72
    local btnR     = math.floor(9 * uiScale)
    return mx >= btnX and mx <= btnX + btnR * 2
       and my >= btnY - btnR and my <= btnY + btnR
end

-- 计算右侧两个 HUD 按钮的位置（暂停/退出）
function GetHUDButtonRects()
    local hudBtnSize = math.floor(26 * uiScale)
    local hudBtnGap  = math.floor(6  * uiScale)
    local hudBtnY    = (HEADER_H - hudBtnSize) * 0.5
    local exitBtnX   = screenW - math.floor(10 * uiScale) - hudBtnSize
    local pauseBtnX  = exitBtnX - hudBtnGap - hudBtnSize
    return pauseBtnX, exitBtnX, hudBtnY, hudBtnSize
end

-- 检测是否点击暂停按钮
function HitPauseBtn(mx, my)
    local px, _, by, bs = GetHUDButtonRects()
    return mx >= px and mx <= px + bs and my >= by and my <= by + bs
end

-- 检测是否点击退出按钮
function HitExitBtn(mx, my)
    local _, ex, by, bs = GetHUDButtonRects()
    return mx >= ex and mx <= ex + bs and my >= by and my <= by + bs
end

-- 退出游戏：重置状态回主界面
function DoExitToHome()
    gamePaused      = false
    showExitConfirm = false
    showSettlement  = false
    showChestPopup  = false
    showLevelTable  = false
    drag.active     = false
    exitConfirmBtnRects = {}
    appPhase = "home"
end

-- 游戏内通用点击分发（鼠标/触摸共用）
-- 返回 true 表示点击已被消费
function HandleGameTap(mx, my)
    -- 退出确认对话框优先
    if showExitConfirm then
        local yr = exitConfirmBtnRects.yes
        local nr = exitConfirmBtnRects.no
        if yr and mx >= yr.x and mx <= yr.x+yr.w and my >= yr.y and my <= yr.y+yr.h then
            DoExitToHome()
        else
            -- 点取消或对话框外：关闭对话框，保持暂停状态
            showExitConfirm = false
        end
        return true
    end

    -- 暂停遮罩期间只响应暂停按钮（恢复游戏）
    if gamePaused then
        if HitPauseBtn(mx, my) then
            gamePaused = false
        end
        -- 其余点击全部吃掉，防穿透
        return true
    end

    -- HUD 暂停/退出按钮（正常游戏中）
    if HitPauseBtn(mx, my) then
        gamePaused = true
        return true
    end
    if HitExitBtn(mx, my) then
        gamePaused      = true
        showExitConfirm = true
        return true
    end

    return false
end

function HandleMouseDown(eventType, eventData)
    -- 金手指拦截
    do
        local mx, my = MX(eventData["X"]:GetInt()), MY(eventData["Y"]:GetInt())
        if HandleCheatTap(mx, my) then return end
    end
    -- logo：任意点击跳到加载条
    if appPhase == "logo" then
        logoTimer = LOGO_DUR; appPhase = "splash"; return
    end
    -- 加载条：任意点击跳到主界面
    if appPhase == "splash" then
        splashTimer = SPLASH_DUR; appPhase = "home"; return
    end
    -- 主界面：点击开始按钮 / 导航栏
    if appPhase == "home" then
        if eventData["Button"]:GetInt() ~= MOUSEB_LEFT then return end
        local mx, my = MX(eventData["X"]:GetInt()), MY(eventData["Y"]:GetInt())
        HandleHomeTap(mx, my)
        return
    end
    -- 游戏中
    if gameWin or gameOver then RestartGame(); return end
    if levelClearAnim then
        -- 点击可立即跳过过关动画，进入结算
        levelClearAnim  = false
        levelClearTimer = 0
        settleClearedLevel = currentLevel
        settleMultIdx   = math.random(1, 5)
        settleAnimating = true
        settleStepAccum = 0.0
        chestProgress = chestProgress + 1
        showSettlement  = true
        showChestPopup  = false
        settleBtnRects  = {}
        chestPopupBtnRect = {}
        return
    end
    if eventData["Button"]:GetInt() ~= MOUSEB_LEFT then return end
    local mx, my = MX(eventData["X"]:GetInt()), MY(eventData["Y"]:GetInt())
    -- 退出确认 / 暂停 / HUD 按钮
    if HandleGameTap(mx, my) then return end
    -- 结算界面
    if showSettlement or showChestPopup then
        HandleSettlementTap(mx, my); return
    end
    -- 关卡表打开时：任意点击关闭
    if showLevelTable then
        showLevelTable = false
        return
    end
    -- HUD 关卡表按钮
    if HitLevelTableBtn(mx, my) then
        showLevelTable = true
        return
    end
    -- 工具栏按钮
    if HandleToolTap(mx, my) then return end
    local r, c = HitCell(mx, my)
    if r > 0 then BeginDrag(r, c, mx, my) end
end

function HandleMouseMove(eventType, eventData)
    local mx, my = MX(eventData["X"]:GetInt()), MY(eventData["Y"]:GetInt())
    UpdateDrag(mx, my)
end

function HandleMouseUp(eventType, eventData)
    if eventData["Button"]:GetInt() ~= MOUSEB_LEFT then return end
    EndDrag(MX(eventData["X"]:GetInt()), MY(eventData["Y"]:GetInt()))
end

function HandleTouchBegin(eventType, eventData)
    -- 金手指拦截
    do
        local mx, my = MX(eventData["X"]:GetInt()), MY(eventData["Y"]:GetInt())
        if HandleCheatTap(mx, my) then return end
    end
    -- logo：任意触摸跳到加载条
    if appPhase == "logo" then
        logoTimer = LOGO_DUR; appPhase = "splash"; return
    end
    -- 加载条：任意触摸跳到主界面
    if appPhase == "splash" then
        splashTimer = SPLASH_DUR; appPhase = "home"; return
    end
    -- 主界面：触摸开始按钮 / 导航栏
    if appPhase == "home" then
        local mx, my = MX(eventData["X"]:GetInt()), MY(eventData["Y"]:GetInt())
        HandleHomeTap(mx, my)
        return
    end
    -- 游戏中
    if gameWin or gameOver then RestartGame(); return end
    if levelClearAnim then
        -- 触摸可立即跳过过关动画，进入结算
        levelClearAnim  = false
        levelClearTimer = 0
        settleClearedLevel = currentLevel
        settleMultIdx   = math.random(1, 5)
        settleAnimating = true
        settleStepAccum = 0.0
        chestProgress = chestProgress + 1
        showSettlement  = true
        showChestPopup  = false
        settleBtnRects  = {}
        chestPopupBtnRect = {}
        return
    end
    local tid = eventData["TouchID"]:GetInt()
    if activeTouchId ~= -1 then return end
    activeTouchId = tid
    local mx, my = MX(eventData["X"]:GetInt()), MY(eventData["Y"]:GetInt())
    -- 退出确认 / 暂停 / HUD 按钮
    if HandleGameTap(mx, my) then activeTouchId = -1; return end
    -- 结算界面
    if showSettlement or showChestPopup then
        HandleSettlementTap(mx, my); activeTouchId = -1; return
    end
    -- 关卡表打开时：任意触摸关闭
    if showLevelTable then
        showLevelTable = false
        activeTouchId = -1
        return
    end
    -- HUD 关卡表按钮
    if HitLevelTableBtn(mx, my) then
        showLevelTable = true
        activeTouchId = -1
        return
    end
    -- 工具栏按钮
    if HandleToolTap(mx, my) then activeTouchId = -1; return end
    -- 变化选择模式
    local r, c = HitCell(mx, my)
    if r > 0 then BeginDrag(r, c, mx, my) end
end

function HandleTouchMove(eventType, eventData)
    if eventData["TouchID"]:GetInt() ~= activeTouchId then return end
    UpdateDrag(MX(eventData["X"]:GetInt()), MY(eventData["Y"]:GetInt()))
end

function HandleTouchEnd(eventType, eventData)
    if eventData["TouchID"]:GetInt() ~= activeTouchId then return end
    activeTouchId = -1
    EndDrag(MX(eventData["X"]:GetInt()), MY(eventData["Y"]:GetInt()))
end

-- ============================================================================
-- 初始化
-- ============================================================================
function Start()
    dpr     = graphics:GetDPR()
    screenW = math.floor(graphics:GetWidth()  / dpr)
    screenH = math.floor(graphics:GetHeight() / dpr)

    -- UI 缩放系数（与 HandleNanoVGRender 保持一致）
    uiScale = math.min(screenW / DESIGN_W, screenH / DESIGN_H)
    uiScale = math.max(0.65, math.min(2.5, uiScale))
    HEADER_H = math.floor(62 * uiScale)

    toolsAreaH = math.max(math.floor(90 * uiScale), math.floor(screenH * 0.15))
    animAreaH  = math.max(math.floor(70 * uiScale), math.floor(screenH * 0.12))

    -- 游戏区可用范围
    local areaTop_s  = HEADER_H + animAreaH + 8
    local areaH_s    = (screenH - toolsAreaH - 8) - areaTop_s
    local areaW_s    = screenW
    local CELL_RATIO_s  = FIXED_CELL_W / FIXED_CELL_H
    local BOARD_MARGIN  = 10
    local maxCW = math.floor((areaW_s - BOARD_MARGIN*2 - SHELF_GAP*3) / 4)
    local maxCH = math.floor((areaH_s - BOARD_MARGIN*2 - SHELF_GAP*5) / 6)
    local cW2, cH2
    if maxCW * CELL_RATIO_s <= maxCH then
        cW2 = maxCW;  cH2 = math.floor(cW2 / CELL_RATIO_s)
    else
        cH2 = maxCH;  cW2 = math.floor(cH2 * CELL_RATIO_s)
    end
    cellW = cW2
    cellH = cH2

    local slotW = cellW / SLOTS
    itemSize = slotW * 0.92
    itemH    = cellH * 0.80

    print(string.format("[Layout] screen=%dx%d dpr=%.1f | areaW=%d areaH=%d | cellW=%d cellH=%d",
        screenW, screenH, dpr, areaW_s, areaH_s, cellW, cellH))

    vg        = nvgCreate(1)
    fontId    = nvgCreateFont(vg, "sans", "Fonts/MiSans-Regular.ttf")
    logoImage      = nvgCreateImage(vg, "image/game_logo_20260527091130.png", 0)
    splashBgImage  = nvgCreateImage(vg, "image/splash_bg_20260527091009.png", 0)
    homeBgImage    = nvgCreateImage(vg, "image/home_screen_full_20260526102040.png", 0)
    shopBgImage    = nvgCreateImage(vg, "image/shop_bg_office_20260527105256.png", 0)
    navTrophyActive   = nvgCreateImage(vg, "image/nav3_trophy_active_20260526104021.png",   0)
    navTrophyInactive = nvgCreateImage(vg, "image/nav3_trophy_inactive_20260526104314.png", 0)
    navHomeActive     = nvgCreateImage(vg, "image/nav3_home_active_20260526104028.png",     0)
    navHomeInactive   = nvgCreateImage(vg, "image/nav3_home_inactive_20260526104257.png",   0)
    navShopActive     = nvgCreateImage(vg, "image/nav3_shop_active_20260526104306.png",     0)
    navShopInactive   = nvgCreateImage(vg, "image/nav3_shop_inactive_20260526104314.png",   0)
    gameBossImage     = nvgCreateImage(vg, "image/game_boss_20260526105933.png",         0)
    gameToolHammer    = nvgCreateImage(vg, "image/game_tool_hammer_20260526110231.png",   0)
    gameToolLightning = nvgCreateImage(vg, "image/game_tool_lightning_20260526110217.png",0)
    gameToolRefresh   = nvgCreateImage(vg, "image/game_tool_refresh_20260526110214.png",  0)
    -- 新道具图标
    toolImgElim      = nvgCreateImage(vg, "image/tool_elim_20260527104540.png",      0)
    toolImgFreeze    = nvgCreateImage(vg, "image/tool_freeze_20260527104542.png",    0)
    toolImgAddtime   = nvgCreateImage(vg, "image/tool_addtime_20260527104543.png",   0)
    toolImgTransform = nvgCreateImage(vg, "image/tool_transform_20260527104541.png", 0)
    toolImgReset     = nvgCreateImage(vg, "image/tool_reset_20260527104540.png",     0)
    -- 弹窗状态重置
    showLevelStartPopup = false
    pendingElimAtStart  = 0
    gameCardBg        = nvgCreateImage(vg, "image/game_card_bg_20260526110044.png",       0)
    gameHudBg         = -1   -- 不使用图片，走代码渐变
    iconCoin          = nvgCreateImage(vg, "image/icon_coin_20260526103502.png",          0)
    iconGem       = nvgCreateImage(vg, "image/icon_gem_20260526103522.png",      0)
    imageGem      = iconGem   -- 结算宝石图标复用
    iconSettings  = nvgCreateImage(vg, "image/icon_settings_20260526103441.png", 0)
    -- 加载所有物品图片（仅正常版，暗化效果由 NanoVG 叠色实现）
    for _, def in ipairs(ITEM_DEFS) do
        itemImages[def.id] = nvgCreateImage(vg, def.img, 0)
    end

    SubscribeToEvent("NanoVGRender",    "HandleNanoVGRender")
    SubscribeToEvent("Update",          "HandleUpdate")
    SubscribeToEvent("MouseButtonDown", "HandleMouseDown")
    SubscribeToEvent("MouseMove",       "HandleMouseMove")
    SubscribeToEvent("MouseButtonUp",   "HandleMouseUp")
    SubscribeToEvent("TouchBegin",      "HandleTouchBegin")
    SubscribeToEvent("TouchMove",       "HandleTouchMove")
    SubscribeToEvent("TouchEnd",        "HandleTouchEnd")

    -- 加载玩家存档（金币 + 道具库存）
    LoadPlayerData()

    InitGame()
end
