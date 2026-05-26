-- =============================================================
-- 裂变海胆分裂逻辑 headless 单元测试
-- 把 Battle.lua 里的分裂条件完整复刻，脱离引擎独立验证
-- =============================================================

-- ---- Mock：简化版 HexGrid ----
local HexGrid = {}
function HexGrid.InBounds(col, row) return col >= 1 and col <= 9 and row >= 1 and row <= 7 end
function HexGrid.IsBlocked(board, col, row)
    for _, obs in ipairs(board.obstacles or {}) do
        if obs.col == col and obs.row == row then return true end
    end
    for _, p in ipairs(board.pieces or {}) do
        if p.col == col and p.row == row then return true end
    end
    return false
end
-- 六方向邻居（偏移坐标，奇偶行有差异，简化为固定6方向）
function HexGrid.GetNeighbors(board, col, row)
    local dirs = {{1,0},{-1,0},{0,1},{0,-1},{1,-1},{-1,1}}
    local result = {}
    for _, d in ipairs(dirs) do
        local nc, nr = col + d[1], row + d[2]
        if HexGrid.InBounds(nc, nr) then
            table.insert(result, {col=nc, row=nr})
        end
    end
    return result
end
function HexGrid.AddPiece(board, piece)
    table.insert(board.pieces, piece)
end

-- ---- Mock：敌人模板 ----
local ENEMY_TEMPLATES = {
    sea_urchin = {
        team = "enemy", enemyType = "sea_urchin",
        hp = 18, maxHp = 18,
        atk = 6, attackRange = 1,
        attackLabel = "尖刺", name = "海胆",
    }
}

-- ---- Mock：创建棋子（深拷贝模板） ----
local function CreatePiece(template, col, row)
    local p = {}
    for k, v in pairs(template) do p[k] = v end
    p.col = col
    p.row = row
    return p
end

-- ---- 核心分裂逻辑（与 Battle.lua 完全一致） ----
local function applySplitLogic(enemy, damage, board)
    local spawned = {}
    if enemy.enemyType == "splitting_urchin" and damage > 0
       and not enemy._hasSplit and enemy.hp > 0
       and enemy.hp < enemy.maxHp * 0.5 then

        enemy._hasSplit = true
        local neighbors = HexGrid.GetNeighbors(board, enemy.col, enemy.row)
        local freeSlots = {}
        for _, nb in ipairs(neighbors) do
            if HexGrid.InBounds(nb.col, nb.row)
               and not HexGrid.IsBlocked(board, nb.col, nb.row) then
                table.insert(freeSlots, nb)
            end
        end
        for i = #freeSlots, 2, -1 do
            local j = math.random(1, i)
            freeSlots[i], freeSlots[j] = freeSlots[j], freeSlots[i]
        end
        local spawnCount = math.min(2, #freeSlots)
        if spawnCount > 0 then
            local miniTemplate = ENEMY_TEMPLATES["sea_urchin"]
            for i = 1, spawnCount do
                local slot = freeSlots[i]
                local mini = CreatePiece(miniTemplate, slot.col, slot.row)
                local miniHp = math.max(1, math.ceil(enemy.hp / 2))
                mini.hp = miniHp
                mini.maxHp = miniHp
                mini.atk = math.max(1, math.floor(enemy.atk * 0.7))
                mini._hasSplit = true
                mini.name = "小裂变海胆"
                HexGrid.AddPiece(board, mini)
                table.insert(spawned, mini)
            end
        end
    end
    return spawned
end

-- ---- 测试工具 ----
local passed, failed = 0, 0
local function check(name, cond, detail)
    if cond then
        print(string.format("  ✅ PASS  %s", name))
        passed = passed + 1
    else
        print(string.format("  ❌ FAIL  %s  ← %s", name, tostring(detail or "")))
        failed = failed + 1
    end
end

local function makeEnemy(hp, maxHp, atk, col, row)
    return {
        enemyType = "splitting_urchin",
        hp = hp, maxHp = maxHp, atk = atk or 10,
        col = col or 5, row = row or 4,
        _hasSplit = false,
        name = "裂变海胆",
    }
end

local function makeBoard(extraPieces, obstacles)
    return { pieces = extraPieces or {}, obstacles = obstacles or {} }
end

-- =============================================================
-- 测试用例
-- =============================================================
function Start()
    local ok, err = pcall(function()

print("=== 裂变海胆分裂逻辑测试 ===")
print()

-- --------------------------------------------------------
print("[Case 1] 血量 > 50%，不应触发分裂")
-- maxHp=20, hp=12 (60%), damage=3 → hp=12 仍 >= 50%?
-- 注意：伤害已在外部扣除，传入的 hp 是扣后值
do
    local e = makeEnemy(12, 20, 10)  -- 12/20 = 60%, >= 50%
    local board = makeBoard()
    local spawned = applySplitLogic(e, 3, board)
    check("血量60%不触发分裂", #spawned == 0,
        "spawned=" .. #spawned)
    check("_hasSplit仍为false", e._hasSplit == false,
        "_hasSplit=" .. tostring(e._hasSplit))
end

-- --------------------------------------------------------
print()
print("[Case 2] 血量恰好 = 50%，不应触发（条件是 < 而非 <=）")
do
    local e = makeEnemy(10, 20, 10)  -- 10/20 = 50.0%, 不满足 < 0.5
    local board = makeBoard()
    local spawned = applySplitLogic(e, 5, board)
    check("血量50%边界不触发", #spawned == 0,
        "spawned=" .. #spawned)
end

-- --------------------------------------------------------
print()
print("[Case 3] 血量刚好 < 50%，首次应触发分裂（周围有空格）")
do
    local e = makeEnemy(9, 20, 10, 5, 4)   -- 9/20 = 45%, < 50%
    local board = makeBoard()
    local spawned = applySplitLogic(e, 6, board)
    check("血量45%触发分裂", #spawned == 2,
        "spawned=" .. #spawned)
    check("母体_hasSplit=true", e._hasSplit == true,
        tostring(e._hasSplit))
    if #spawned >= 1 then
        -- 小海胆 HP = ceil(9/2) = 5
        check("小海胆HP = ceil(9/2) = 5", spawned[1].hp == 5,
            "hp=" .. spawned[1].hp)
        -- 小海胆 ATK = floor(10*0.7) = 7
        check("小海胆ATK = floor(10*0.7) = 7", spawned[1].atk == 7,
            "atk=" .. spawned[1].atk)
        -- 小海胆不再分裂
        check("小海胆_hasSplit=true(不再分裂)", spawned[1]._hasSplit == true,
            tostring(spawned[1]._hasSplit))
        check("小海胆名称", spawned[1].name == "小裂变海胆",
            spawned[1].name)
    end
end

-- --------------------------------------------------------
print()
print("[Case 4] 再次攻击已分裂的母体，不应再次分裂")
do
    local e = makeEnemy(4, 20, 10, 5, 4)   -- 4/20 = 20%, << 50%
    e._hasSplit = true  -- 模拟已分裂
    local board = makeBoard()
    local spawned = applySplitLogic(e, 2, board)
    check("已分裂不再触发", #spawned == 0,
        "spawned=" .. #spawned)
end

-- --------------------------------------------------------
print()
print("[Case 5] damage=0，不触发分裂（免伤场景）")
do
    local e = makeEnemy(5, 20, 10)   -- 5/20 = 25%, < 50%
    local board = makeBoard()
    local spawned = applySplitLogic(e, 0, board)
    check("damage=0不触发", #spawned == 0,
        "spawned=" .. #spawned)
    check("_hasSplit仍false", e._hasSplit == false)
end

-- --------------------------------------------------------
print()
print("[Case 6] 敌人已死（hp=0），不触发分裂")
do
    local e = makeEnemy(0, 20, 10)
    local board = makeBoard()
    local spawned = applySplitLogic(e, 15, board)
    check("hp=0不触发", #spawned == 0,
        "spawned=" .. #spawned)
end

-- --------------------------------------------------------
print()
print("[Case 7] 周围只有1个空格，只生成1只小海胆")
do
    -- 把 (5,4) 的所有邻居用棋子塞满，只留一个
    local e = makeEnemy(7, 20, 10, 5, 4)
    local pieces = {}
    local neighbors = HexGrid.GetNeighbors({}, 5, 4)
    -- 占据前5个邻居，留最后一个
    for i = 1, math.min(5, #neighbors) do
        table.insert(pieces, {col=neighbors[i].col, row=neighbors[i].row, team="enemy", hp=1})
    end
    local board = makeBoard(pieces)
    local spawned = applySplitLogic(e, 5, board)
    check("周围1格空余时只生成1只", #spawned == 1,
        "spawned=" .. #spawned)
end

-- --------------------------------------------------------
print()
print("[Case 8] 周围全被占满，无法生成小海胆")
do
    local e = makeEnemy(7, 20, 10, 5, 4)
    local pieces = {}
    local neighbors = HexGrid.GetNeighbors({}, 5, 4)
    for _, nb in ipairs(neighbors) do
        table.insert(pieces, {col=nb.col, row=nb.row, team="enemy", hp=1})
    end
    local board = makeBoard(pieces)
    local spawned = applySplitLogic(e, 5, board)
    check("周围全满时生成0只", #spawned == 0,
        "spawned=" .. #spawned)
    -- 注意：_hasSplit 仍被置为 true（分裂条件满足，只是没位置）
    check("条件满足但无位置时_hasSplit=true", e._hasSplit == true,
        tostring(e._hasSplit))
end

-- --------------------------------------------------------
print()
print("[Case 9] HP 极小值 = 1，小海胆HP = ceil(1/2) = 1")
do
    local e = makeEnemy(1, 20, 10, 5, 4)
    local board = makeBoard()
    local spawned = applySplitLogic(e, 10, board)
    check("hp=1触发分裂", #spawned == 2, "spawned="..#spawned)
    if #spawned >= 1 then
        check("小海胆HP最小为1", spawned[1].hp == 1,
            "hp=" .. spawned[1].hp)
    end
end

-- --------------------------------------------------------
print()
print("[Case 10] ATK极小值，floor(1*0.7)=0，但 max(1,...) 保底为1")
do
    local e = makeEnemy(7, 20, 1, 5, 4)  -- atk=1
    local board = makeBoard()
    local spawned = applySplitLogic(e, 5, board)
    if #spawned >= 1 then
        check("小海胆ATK保底为1", spawned[1].atk == 1,
            "atk=" .. spawned[1].atk)
    else
        check("小海胆ATK保底为1", false, "没有生成小海胆")
    end
end

-- ============================================================
print()
print(string.rep("=", 40))
print(string.format("结果：%d 通过，%d 失败", passed, failed))
if failed == 0 then
    print("🎉 全部通过！分裂逻辑符合预期。")
else
    print("⚠️  存在失败用例，请检查逻辑。")
end
print(string.rep("=", 40))

    end)  -- pcall end
    if not ok then
        log:Write(LOG_ERROR, "[test] " .. tostring(err))
    end
    engine:Exit()
end
