---@diagnostic disable: return-type-mismatch
-- ============================================================================
-- HexGrid.lua - 六角格核心模块
-- 坐标系: pointy-top, odd-r offset (1-based)
-- Row 1,3,5,7 不偏移; Row 2,4,6 向右偏移半格
-- ============================================================================

local HexGrid = {}

-- 正六边形棋盘: 外接矩形 9×9, 中心 (5,5), 半径 4 → 61 格
HexGrid.COLS = 9
HexGrid.ROWS = 9
HexGrid.RADIUS = 4
HexGrid.CENTER_COL = 5
HexGrid.CENTER_ROW = 5

-- 棋盘形状: "hexagon"(默认正六边形) 或 "hexagram"(六芒星/中国跳棋)
HexGrid.boardShape = "hexagon"
HexGrid.hexagramCells = nil   -- lookup: "col,row" -> true
HexGrid.hexagramArm = nil     -- lookup: "col,row" -> arm index (0=中心, 1-6=臂)

--- 设置六芒星(中国跳棋)棋盘
--- 六芒星 = 中心正六边形(半径N) + 6个三角形臂(深度N)
--- 数学定义: 所有 cube 坐标 (dx,dy,dz) 中 |dx|≤N, |dy|≤N, |dz|≤N 三个条件满足至少2个
--- @param N number 六芒星参数(默认4), 总格数 = 6N²+6N+1 (N=4→121格)
function HexGrid.SetupHexagram(N)
    N = N or 4
    HexGrid.boardShape = "hexagram"
    HexGrid.hexagramCells = {}
    HexGrid.hexagramArm = {}

    -- 临时中心行（用于计算）
    local centerRow = 2 * N + 1
    local centerCol = 2 * N + 1  -- 先用大值，之后会修正
    local centerFloor = math.floor((centerRow - 1) / 2)

    -- 第一遍: 枚举所有有效格子，计算 min/max col
    local minCol, maxCol = 9999, -9999
    local cells = {}
    for dz = -2 * N, 2 * N do
        for dx = -2 * N, 2 * N do
            local dy = -dx - dz
            -- 六芒星条件: 三个绝对值中至少2个 ≤ N
            local cnt = 0
            if math.abs(dx) <= N then cnt = cnt + 1 end
            if math.abs(dy) <= N then cnt = cnt + 1 end
            if math.abs(dz) <= N then cnt = cnt + 1 end
            if cnt >= 2 then
                local row = centerRow + dz
                local rowFloor = math.floor((row - 1) / 2)
                local col = centerCol + dx + (rowFloor - centerFloor)
                cells[#cells + 1] = { col = col, row = row, dx = dx, dy = dy, dz = dz }
                if col < minCol then minCol = col end
                if col > maxCol then maxCol = col end
            end
        end
    end

    -- 修正 centerCol 使 minCol = 1
    local shift = 1 - minCol
    centerCol = centerCol + shift

    HexGrid.COLS = maxCol + shift
    HexGrid.ROWS = 4 * N + 1
    HexGrid.CENTER_COL = centerCol
    HexGrid.CENTER_ROW = centerRow
    HexGrid.RADIUS = N

    -- 第二遍: 用修正后的 centerCol 重建 lookup table
    local centerFloor2 = math.floor((centerRow - 1) / 2)
    for dz = -2 * N, 2 * N do
        for dx = -2 * N, 2 * N do
            local dy = -dx - dz
            local cnt = 0
            if math.abs(dx) <= N then cnt = cnt + 1 end
            if math.abs(dy) <= N then cnt = cnt + 1 end
            if math.abs(dz) <= N then cnt = cnt + 1 end
            if cnt >= 2 then
                local row = centerRow + dz
                local rowFloor = math.floor((row - 1) / 2)
                local col = centerCol + dx + (rowFloor - centerFloor2)
                local key = col .. "," .. row
                HexGrid.hexagramCells[key] = true

                -- 判断所属区域: 0=中心六边形, 1-6=六个臂
                local arm = 0
                if math.max(math.abs(dx), math.abs(dy), math.abs(dz)) > N then
                    -- 在中心六边形外 → 属于某个臂
                    if math.abs(dz) > N then
                        arm = dz < 0 and 1 or 4      -- 1=顶(上), 4=底(下)
                    elseif math.abs(dx) > N then
                        arm = dx > 0 and 2 or 5       -- 2=右上, 5=左下
                    elseif math.abs(dy) > N then
                        arm = dy < 0 and 3 or 6        -- 3=右下, 6=左上
                    end
                end
                HexGrid.hexagramArm[key] = arm
            end
        end
    end
end

--- 重置为标准正六边形棋盘
function HexGrid.ResetToHexagon()
    HexGrid.boardShape = "hexagon"
    HexGrid.COLS = 9
    HexGrid.ROWS = 9
    HexGrid.RADIUS = 4
    HexGrid.CENTER_COL = 5
    HexGrid.CENTER_ROW = 5
    HexGrid.hexagramCells = nil
    HexGrid.hexagramArm = nil
end

--- 获取格子所属的臂索引(仅六芒星模式)
--- @return number 0=中心, 1=顶, 2=右上, 3=右下, 4=底, 5=左下, 6=左上
function HexGrid.GetArmIndex(col, row)
    if HexGrid.hexagramArm then
        return HexGrid.hexagramArm[col .. "," .. row] or 0
    end
    return 0
end

--- 获取臂对应的玩家编号(3人模式: 对面的臂属于同一玩家)
--- @return number 0=中心, 1=玩家1(红, 臂1+4), 2=玩家2(绿, 臂2+5), 3=玩家3(黄, 臂3+6)
function HexGrid.GetArmPlayer(col, row)
    local arm = HexGrid.GetArmIndex(col, row)
    if arm == 1 or arm == 4 then return 1 end      -- 红: 上/下
    if arm == 2 or arm == 5 then return 2 end      -- 绿: 右上/左下
    if arm == 3 or arm == 6 then return 3 end      -- 黄: 右下/左上
    return 0  -- 中心
end

--- 检查坐标是否在正六边形棋盘范围内
function HexGrid.InBounds(col, row)
    if HexGrid.boardShape == "hexagram" and HexGrid.hexagramCells then
        return HexGrid.hexagramCells[col .. "," .. row] == true
    end
    if col < 1 or col > HexGrid.COLS or row < 1 or row > HexGrid.ROWS then
        return false
    end
    return HexGrid.CubeDistance(col, row, HexGrid.CENTER_COL, HexGrid.CENTER_ROW) <= HexGrid.RADIUS
end

-- ============================================================================
-- 邻居偏移 (1-based odd-r offset)
-- ============================================================================

-- 非偏移行 (row%2==1: 行1,3,5,7)
local DIR_NORMAL = {
    { 1, 0},   -- E
    { 0,-1},   -- NE
    {-1,-1},   -- NW
    {-1, 0},   -- W
    {-1, 1},   -- SW
    { 0, 1},   -- SE
}

-- 偏移行 (row%2==0: 行2,4,6)
local DIR_SHIFTED = {
    { 1, 0},   -- E
    { 1,-1},   -- NE
    { 0,-1},   -- NW
    {-1, 0},   -- W
    { 0, 1},   -- SW
    { 1, 1},   -- SE
}

--- 获取指定格子的6个邻居 (过滤越界)
---@param col number
---@param row number
---@return table[] 邻居列表 {{col=, row=}, ...}
function HexGrid.GetNeighbors(col, row)
    local dirs = (row % 2 == 1) and DIR_NORMAL or DIR_SHIFTED
    local result = {}
    for _, d in ipairs(dirs) do
        local nc, nr = col + d[1], row + d[2]
        if HexGrid.InBounds(nc, nr) then
            result[#result + 1] = { col = nc, row = nr }
        end
    end
    return result
end

-- ============================================================================
-- 坐标转换 (offset ↔ cube)
-- ============================================================================

function HexGrid.OffsetToCube(col, row)
    local c0 = col - 1
    local r0 = row - 1
    local x = c0 - math.floor(r0 / 2)
    local z = r0
    local y = -x - z
    return x, y, z
end

function HexGrid.CubeToOffset(x, y, z)
    local c0 = x + math.floor((z - (z & 1)) / 2)
    local r0 = z
    return c0 + 1, r0 + 1
end

--- 跳跃落点: 从 (col,row) 跳过 (eCol,eRow) 的对称着陆点
--- 支持任意距离：主角距敌人 N 格，落点在敌人另一侧 N 格
function HexGrid.GetJumpTarget(col, row, eCol, eRow)
    local hx, hy, hz = HexGrid.OffsetToCube(col, row)
    local ex, ey, ez = HexGrid.OffsetToCube(eCol, eRow)
    local lx = 2 * ex - hx
    local ly = 2 * ey - hy
    local lz = 2 * ez - hz
    local lc, lr = HexGrid.CubeToOffset(lx, ly, lz)
    if HexGrid.InBounds(lc, lr) then
        return lc, lr
    end
    return nil, nil
end

-- 六个 cube 方向单位向量
local CUBE_DIRS = {
    { 1, -1,  0},
    { 1,  0, -1},
    { 0,  1, -1},
    {-1,  1,  0},
    {-1,  0,  1},
    { 0, -1,  1},
}

--- 检查 hero→enemy 是否在 hex 直线上，返回方向和距离
--- @return table|nil dir  cube 方向单位向量 {dx,dy,dz}
--- @return number|nil dist  步数距离
function HexGrid.GetLineDirection(col1, row1, col2, row2)
    local x1, y1, z1 = HexGrid.OffsetToCube(col1, row1)
    local x2, y2, z2 = HexGrid.OffsetToCube(col2, row2)
    local dx = x2 - x1
    local dy = y2 - y1
    local dz = z2 - z1
    -- cube 坐标约束: dx+dy+dz==0
    -- 在同一直线上意味着向量是某个方向的整数倍
    local dist = HexGrid.CubeDistance(col1, row1, col2, row2)
    if dist == 0 then return nil, nil end
    -- 检查每个分量是否是 dist 的整数倍
    if dx % dist == 0 and dy % dist == 0 and dz % dist == 0 then
        local ux = dx // dist
        local uy = dy // dist
        local uz = dz // dist
        -- 验证是合法方向 (单位向量之一)
        for _, d in ipairs(CUBE_DIRS) do
            if d[1] == ux and d[2] == uy and d[3] == uz then
                return d, dist
            end
        end
    end
    return nil, nil
end

--- 检查从 (col1,row1) 到 (col2,row2) 之间的路径是否畅通（无阻挡棋子）
--- 不检查起点和终点，只检查中间格子
function HexGrid.IsPathClear(board, col1, row1, col2, row2)
    local dir, dist = HexGrid.GetLineDirection(col1, row1, col2, row2)
    if not dir or dist <= 1 then return true end  -- 相邻无需检查中间
    local x1, y1, z1 = HexGrid.OffsetToCube(col1, row1)
    for step = 1, dist - 1 do
        local mx = x1 + dir[1] * step
        local my = y1 + dir[2] * step
        local mz = z1 + dir[3] * step
        local mc, mr = HexGrid.CubeToOffset(mx, my, mz)
        if HexGrid.GetPieceAt(board, mc, mr) then
            return false  -- 中间有棋子挡路
        end
    end
    return true
end

--- Cube 距离
function HexGrid.CubeDistance(c1, r1, c2, r2)
    local x1, y1, z1 = HexGrid.OffsetToCube(c1, r1)
    local x2, y2, z2 = HexGrid.OffsetToCube(c2, r2)
    return math.max(math.abs(x1 - x2), math.abs(y1 - y2), math.abs(z1 - z2))
end

-- ============================================================================
-- 棋盘状态
-- ============================================================================

--- 创建棋盘
function HexGrid.CreateBoard()
    local board = {
        cols = HexGrid.COLS,
        rows = HexGrid.ROWS,
        pieces = {},
        obstacles = {},     -- {col, row} 岩石障碍物
        items = {},         -- {col, row, type, ...} 地面道具
        poisonTiles = {},   -- {col, row, turns} 毒雾格子
        wards = {},         -- {col, row, turns, damage} 结界
        altars = {},        -- {col, row, active} 炎魔祭坛（第二章）
        frostTiles = {},    -- {col, row, turns} 霜冻格
    }
    return board
end

--- 添加棋子
function HexGrid.AddPiece(board, piece)
    board.pieces[#board.pieces + 1] = piece
end

-- ============================================================================
-- 障碍物 / 道具 / 毒雾
-- ============================================================================

--- 添加障碍物（岩石/冰块等）
function HexGrid.AddObstacle(board, col, row, obstacleType)
    local obstacle = { col = col, row = row, type = obstacleType }
    if obstacleType == "ice_block" then
        obstacle.turns = 10
    end
    board.obstacles[#board.obstacles + 1] = obstacle
end

--- 获取指定位置的障碍物
function HexGrid.GetObstacleAt(board, col, row)
    for _, o in ipairs(board.obstacles) do
        if o.col == col and o.row == row then return o end
    end
    return nil
end

--- 获取指定位置的"可跳跃支点"（障碍物 OR 活跃祭坛），用于飞跃先锋
function HexGrid.GetJumpSupportAt(board, col, row)
    -- 只检查障碍物（岩石等）作为跳跃支点
    -- 祭坛是特殊格子，不能被当做跳板
    local obs = HexGrid.GetObstacleAt(board, col, row)
    if obs then return obs end
    return nil
end

--- 移除指定位置的障碍物
function HexGrid.RemoveObstacle(board, col, row)
    for i = #board.obstacles, 1, -1 do
        if board.obstacles[i].col == col and board.obstacles[i].row == row then
            table.remove(board.obstacles, i)
            return true
        end
    end
    return false
end

--- 检查位置是否被阻挡（棋子 OR 障碍物）
function HexGrid.IsBlocked(board, col, row)
    if HexGrid.GetPieceAt(board, col, row) then return true end
    if HexGrid.GetObstacleAt(board, col, row) then return true end
    -- 第三章: 寄居蟹和贝壳占据格子，不可通行
    if board.crabs then
        for _, crab in ipairs(board.crabs) do
            if not crab.rescued and crab.col == col and crab.row == row then return true end
        end
    end
    if board.shells then
        for _, shell in ipairs(board.shells) do
            if shell.col == col and shell.row == row then return true end
        end
    end
    -- 第四章: 流沙区不可通行
    if HexGrid.IsInQuicksandZone(board, col, row) then return true end
    return false
end

--- 检查位置是否被阻挡（忽略石头/障碍物）
--- 用于第三章先锋飞跃落点检查：石头可被突破，不视为阻挡
function HexGrid.IsBlockedIgnoreRocks(board, col, row)
    if HexGrid.GetPieceAt(board, col, row) then return true end
    -- 不检查 obstacles（石头），先锋飞跃可突破
    if board.crabs then
        for _, crab in ipairs(board.crabs) do
            if not crab.rescued and crab.col == col and crab.row == row then return true end
        end
    end
    if board.shells then
        for _, shell in ipairs(board.shells) do
            if shell.col == col and shell.row == row then return true end
        end
    end
    return false
end

--- 添加地面道具
function HexGrid.AddItem(board, item)
    board.items[#board.items + 1] = item
end

--- 获取指定位置的道具
function HexGrid.GetItemAt(board, col, row)
    for _, it in ipairs(board.items) do
        if it.col == col and it.row == row then return it end
    end
    return nil
end

--- 移除指定位置的道具
function HexGrid.RemoveItemAt(board, col, row)
    for i = #board.items, 1, -1 do
        if board.items[i].col == col and board.items[i].row == row then
            table.remove(board.items, i)
            return true
        end
    end
    return false
end

--- 添加毒雾格子
function HexGrid.AddPoison(board, col, row, turns)
    -- 如果已有毒雾则刷新回合
    for _, p in ipairs(board.poisonTiles) do
        if p.col == col and p.row == row then
            p.turns = math.max(p.turns, turns)
            return
        end
    end
    board.poisonTiles[#board.poisonTiles + 1] = { col = col, row = row, turns = turns }
end

--- 获取指定位置的毒雾
function HexGrid.GetPoisonAt(board, col, row)
    for _, p in ipairs(board.poisonTiles) do
        if p.col == col and p.row == row then return p end
    end
    return nil
end

--- 移除指定位置的毒雾
function HexGrid.RemovePoisonAt(board, col, row)
    for i = #board.poisonTiles, 1, -1 do
        if board.poisonTiles[i].col == col and board.poisonTiles[i].row == row then
            table.remove(board.poisonTiles, i)
            return true
        end
    end
    return false
end

-- ============================================================================
-- 结界 (ward)
-- ============================================================================

--- 添加结界
function HexGrid.AddWard(board, col, row, turns, damage)
    -- 如果已有结界则刷新
    for _, w in ipairs(board.wards) do
        if w.col == col and w.row == row then
            w.turns = math.max(w.turns, turns)
            w.damage = damage or w.damage
            return
        end
    end
    board.wards[#board.wards + 1] = { col = col, row = row, turns = turns, damage = damage or 20 }
end

--- 获取指定位置的结界
function HexGrid.GetWardAt(board, col, row)
    for _, w in ipairs(board.wards) do
        if w.col == col and w.row == row then return w end
    end
    return nil
end

--- 移除指定位置的结界
function HexGrid.RemoveWardAt(board, col, row)
    for i = #board.wards, 1, -1 do
        if board.wards[i].col == col and board.wards[i].row == row then
            table.remove(board.wards, i)
            return true
        end
    end
    return false
end

--- 结界数量
function HexGrid.WardCount(board)
    return #board.wards
end

-- ============================================================================
-- 战争迷雾 (fog of war) - 第三章
-- ============================================================================

--- 初始化迷雾: 覆盖所有格子
function HexGrid.InitFog(board)
    board.hasFog = true
    board.fogRevealed = {}
end

--- 判断某格是否被迷雾遮盖
function HexGrid.IsFogged(board, col, row)
    if not board.hasFog then return false end
    local key = col .. "," .. row
    return not board.fogRevealed[key]
end

--- 揭示单个格子
function HexGrid.RevealCell(board, col, row)
    if not board.hasFog then return end
    local key = col .. "," .. row
    board.fogRevealed[key] = true
end

--- 揭示某格及其周围 radius 圈
---@return table 新揭示的格子列表 {{col, row}, ...}
function HexGrid.RevealFog(board, col, row, radius)
    if not board.hasFog then return {} end
    radius = radius or 1
    local newlyRevealed = {}
    -- 揭示中心
    local centerKey = col .. "," .. row
    if not board.fogRevealed[centerKey] and HexGrid.InBounds(col, row) then
        board.fogRevealed[centerKey] = true
        newlyRevealed[#newlyRevealed + 1] = { col = col, row = row }
    end
    -- BFS 揭示周围
    if radius >= 1 then
        for r = 1, HexGrid.ROWS do
            for c = 1, HexGrid.COLS do
                if HexGrid.InBounds(c, r) then
                    local dist = HexGrid.CubeDistance(col, row, c, r)
                    if dist <= radius then
                        local key = c .. "," .. r
                        if not board.fogRevealed[key] then
                            board.fogRevealed[key] = true
                            newlyRevealed[#newlyRevealed + 1] = { col = c, row = r }
                        end
                    end
                end
            end
        end
    end
    return newlyRevealed
end

--- 重新覆盖某格的迷雾（烟雾大师死亡效果）
function HexGrid.AddFogAt(board, col, row)
    if not board.hasFog then return end
    local key = col .. "," .. row
    board.fogRevealed[key] = nil
end

--- 清除所有迷雾
function HexGrid.ClearAllFog(board)
    board.hasFog = false
    board.fogRevealed = {}
end

--- 获取所有空位（无棋子、无障碍物，且在正六边形范围内）
--- 获取所有有效（棋盘内）的格子
function HexGrid.GetAllValidCells(board)
    local cells = {}
    for r = 1, board.rows do
        for c = 1, board.cols do
            if HexGrid.InBounds(c, r) then
                cells[#cells + 1] = { col = c, row = r }
            end
        end
    end
    return cells
end

function HexGrid.GetEmptyPositions(board)
    local empty = {}
    for r = 1, board.rows do
        for c = 1, board.cols do
            if HexGrid.InBounds(c, r) and
               not HexGrid.IsBlocked(board, c, r) and
               not HexGrid.GetItemAt(board, c, r) then
                empty[#empty + 1] = { col = c, row = r }
            end
        end
    end
    return empty
end

--- 获取指定位置的棋子 (仅活着的)
function HexGrid.GetPieceAt(board, col, row)
    for _, p in ipairs(board.pieces) do
        if p.col == col and p.row == row and p.hp > 0 and not p.hidden then
            return p
        end
    end
    return nil
end

--- 移除死亡棋子
function HexGrid.RemoveDead(board)
    for i = #board.pieces, 1, -1 do
        local p = board.pieces[i]
        -- 英雄的死亡由 CheckEndCondition 单独处理（含黎明使者复活等逻辑），
        -- 这里不得移除英雄，否则复活后英雄不在 pieces 中导致无法渲染
        if p.hp <= 0 and p.team ~= "hero" then
            table.remove(board.pieces, i)
        end
    end
end

--- 获取所有指定队伍的活棋子
function HexGrid.GetTeamPieces(board, team)
    local result = {}
    for _, p in ipairs(board.pieces) do
        if p.team == team and p.hp > 0 then
            result[#result + 1] = p
        end
    end
    return result
end

--- 找有效移动目标 (相邻空格, 检查障碍物)
function HexGrid.FindValidMoves(board, col, row)
    local moves = {}
    for _, n in ipairs(HexGrid.GetNeighbors(col, row)) do
        if not HexGrid.IsBlocked(board, n.col, n.row) then
            moves[#moves + 1] = n
        end
    end
    return moves
end

--- 找有效跳跃目标 (跳过敌人到对称位置)
--- 支持隔多格跳跃: 主角和敌人在同一直线上(距离N), 中间无阻挡,
--- 跳到敌人对称另一侧N格, 落点为空且在棋盘内
--- 障碍物会阻断路径（和棋子一样）
--- 迷雾中的敌人不可见，扫描遇到迷雾格时视为阻断（看不见对面）
--- @param maxJumpOver number|nil 可跳过的最大连续敌人数(默认1, 飞跃先锋=2)
--- @param opts {ch3Rocks: boolean}|nil  ch3Rocks=true时，先锋飞跃落点/路径的石头不视为阻挡
function HexGrid.FindValidJumps(board, col, row, maxJumpOver, opts)
    maxJumpOver = maxJumpOver or 1
    local ch3Rocks = opts and opts.ch3Rocks  -- 第三章：先锋飞跃落点石头可被突破
    local scarecrow = opts and opts.scarecrow  -- 稻草人可作为跳跃支撑点（友方目标）
    local jumps = {}
    local hx, hy, hz = HexGrid.OffsetToCube(col, row)

    -- 扫描六个方向
    for _, dir in ipairs(CUBE_DIRS) do
        -- 沿方向逐步搜索，找到第一个棋子或障碍物
        local maxDist = math.max(HexGrid.COLS, HexGrid.ROWS)
        for dist = 1, maxDist do
            local ex = hx + dir[1] * dist
            local ey = hy + dir[2] * dist
            local ez = hz + dir[3] * dist
            local ec, er = HexGrid.CubeToOffset(ex, ey, ez)

            -- 越界则此方向不再搜索
            if not HexGrid.InBounds(ec, er) then
                break
            end

            -- 检查障碍物/祭坛: 可以跳过（无伤害跳跃）
            local obstacle = HexGrid.GetJumpSupportAt(board, ec, er)
            if obstacle then
                -- 岩石也可作为跳跃支点，计算对称落点
                local lx = ex + dir[1] * dist
                local ly = ey + dir[2] * dist
                local lz = ez + dir[3] * dist
                local lc, lr = HexGrid.CubeToOffset(lx, ly, lz)

                if HexGrid.InBounds(lc, lr) then
                    if not HexGrid.IsBlocked(board, lc, lr) then
                        local landingClear = true
                        for step = 1, dist - 1 do
                            local mx = ex + dir[1] * step
                            local my = ey + dir[2] * step
                            local mz = ez + dir[3] * step
                            local mc, mr = HexGrid.CubeToOffset(mx, my, mz)
                            if HexGrid.IsBlocked(board, mc, mr) or HexGrid.GetItemAt(board, mc, mr) then
                                landingClear = false
                                break
                            end
                        end
                        if landingClear then
                            jumps[#jumps + 1] = {
                                col = lc, row = lr,
                                enemy = nil,
                                jumpedCol = ec, jumpedRow = er,
                                isRockJump = true,
                                obstacle = obstacle,
                                dist = dist,
                            }
                        end
                    end
                end

                -- 飞跃先锋: 石头在前的情况（ROCK → E/ROCK → ...）
                if ch3Rocks and maxJumpOver >= 2 then
                    -- 检查石头正后方1格（位置2）是否有敌人或石头
                    local adj_x = ex + dir[1]
                    local adj_y = ey + dir[2]
                    local adj_z = ez + dir[3]
                    local adj_c, adj_r = HexGrid.CubeToOffset(adj_x, adj_y, adj_z)
                    if HexGrid.InBounds(adj_c, adj_r) then
                        local piece2 = HexGrid.GetPieceAt(board, adj_c, adj_r)
                        local isEnemy2 = piece2 and piece2.team == "enemy"
                        local obs2 = (not isEnemy2) and HexGrid.GetJumpSupportAt(board, adj_c, adj_r) or nil
                        if isEnemy2 or obs2 then
                            -- 飞跃先锋6/6: 石头在前 → 检查位置3
                            if maxJumpOver >= 3 then
                                local adj2_x = adj_x + dir[1]
                                local adj2_y = adj_y + dir[2]
                                local adj2_z = adj_z + dir[3]
                                local adj2_c, adj2_r = HexGrid.CubeToOffset(adj2_x, adj2_y, adj2_z)
                                if HexGrid.InBounds(adj2_c, adj2_r) then
                                    local piece3 = HexGrid.GetPieceAt(board, adj2_c, adj2_r)
                                    local isEnemy3 = piece3 and piece3.team == "enemy"
                                    local obs3 = (not isEnemy3) and HexGrid.GetJumpSupportAt(board, adj2_c, adj2_r) or nil
                                    if isEnemy3 or obs3 then
                                        -- 三连跳落点: 位置3后方 dist 步
                                        local l3x = adj2_x + dir[1] * dist
                                        local l3y = adj2_y + dir[2] * dist
                                        local l3z = adj2_z + dir[3] * dist
                                        local l3c, l3r = HexGrid.CubeToOffset(l3x, l3y, l3z)
                                        if HexGrid.InBounds(l3c, l3r) and not HexGrid.IsBlocked(board, l3c, l3r) then
                                            local path3Clear = true
                                            for step = 1, dist - 1 do
                                                local mx = adj2_x + dir[1] * step
                                                local my = adj2_y + dir[2] * step
                                                local mz = adj2_z + dir[3] * step
                                                local mc, mr = HexGrid.CubeToOffset(mx, my, mz)
                                                if HexGrid.IsBlocked(board, mc, mr) or HexGrid.GetItemAt(board, mc, mr) then
                                                    path3Clear = false
                                                    break
                                                end
                                            end
                                            if path3Clear then
                                                jumps[#jumps + 1] = {
                                                    col = l3c, row = l3r,
                                                    enemy = isEnemy2 and piece2 or (isEnemy3 and piece3 or nil),
                                                    enemy2 = isEnemy2 and piece2 or nil,
                                                    enemy3 = isEnemy3 and piece3 or nil,
                                                    jumpedCol = ec, jumpedRow = er,
                                                    jumpedCol2 = adj_c, jumpedRow2 = adj_r,
                                                    jumpedCol3 = adj2_c, jumpedRow3 = adj2_r,
                                                    jumpedObstacle = obstacle,
                                                    jumpedObstacle2 = obs2,
                                                    jumpedObstacle3 = obs3,
                                                    isRockJump = true,
                                                    dist = dist,
                                                    isDoubleJump = true,
                                                    isTripleJump = true,
                                                }
                                            end
                                        end
                                    end
                                end
                            end

                            -- 双跳落点: 位置2后方 dist 步
                            local l2x = adj_x + dir[1] * dist
                            local l2y = adj_y + dir[2] * dist
                            local l2z = adj_z + dir[3] * dist
                            local l2c, l2r = HexGrid.CubeToOffset(l2x, l2y, l2z)
                            if HexGrid.InBounds(l2c, l2r) and not HexGrid.IsBlocked(board, l2c, l2r) then
                                local pathClear = true
                                for step = 1, dist - 1 do
                                    local mx = adj_x + dir[1] * step
                                    local my = adj_y + dir[2] * step
                                    local mz = adj_z + dir[3] * step
                                    local mc, mr = HexGrid.CubeToOffset(mx, my, mz)
                                    if HexGrid.IsBlocked(board, mc, mr) or HexGrid.GetItemAt(board, mc, mr) then
                                        pathClear = false
                                        break
                                    end
                                end
                                if pathClear then
                                    jumps[#jumps + 1] = {
                                        col = l2c, row = l2r,
                                        enemy = isEnemy2 and piece2 or nil,
                                        jumpedCol = ec, jumpedRow = er,
                                        jumpedCol2 = adj_c, jumpedRow2 = adj_r,
                                        jumpedObstacle = obstacle,
                                        jumpedObstacle2 = obs2,
                                        isRockJump = true,
                                        dist = dist,
                                        isDoubleJump = true,
                                    }
                                end
                            end
                        end
                    end
                end

                break  -- 此方向被岩石阻断
            end

            -- 第三章: 寄居蟹（不可跳过，此方向完全阻断）
            local crabBlocked = false
            if board.crabs then
                for _, crab in ipairs(board.crabs) do
                    if not crab.rescued and crab.col == ec and crab.row == er then
                        crabBlocked = true
                        break
                    end
                end
            end
            if crabBlocked then break end

            -- 第三章: 贝壳可作为跳跃支点（同岩石逻辑，处理后此方向完全阻断）
            local shellBlocked = false
            if board.shells then
                for _, shell in ipairs(board.shells) do
                    if shell.col == ec and shell.row == er then
                        local lx = ex + dir[1] * dist
                        local ly = ey + dir[2] * dist
                        local lz = ez + dir[3] * dist
                        local lc, lr = HexGrid.CubeToOffset(lx, ly, lz)
                        if HexGrid.InBounds(lc, lr) then
                            if not HexGrid.IsBlocked(board, lc, lr) then
                                local landingClear = true
                                for step = 1, dist - 1 do
                                    local mx = ex + dir[1] * step
                                    local my = ey + dir[2] * step
                                    local mz = ez + dir[3] * step
                                    local mc, mr = HexGrid.CubeToOffset(mx, my, mz)
                                    if HexGrid.IsBlocked(board, mc, mr) or HexGrid.GetItemAt(board, mc, mr) then
                                        landingClear = false
                                        break
                                    end
                                end
                                if landingClear then
                                    jumps[#jumps + 1] = {
                                        col = lc, row = lr,
                                        enemy = nil,
                                        jumpedCol = ec, jumpedRow = er,
                                        isRockJump = true,
                                        dist = dist,
                                    }
                                end
                            end
                        end
                        shellBlocked = true
                        break
                    end
                end
            end
            if shellBlocked then break end

            -- 第四章: 流沙区阻断方向扫描（不可飞越）
            if HexGrid.IsInQuicksandZone(board, ec, er) then break end

            -- 稻草人: 友方目标，可作为跳跃支撑点（同岩石逻辑，不造成伤害）
            if scarecrow and scarecrow.col == ec and scarecrow.row == er then
                local lx = ex + dir[1] * dist
                local ly = ey + dir[2] * dist
                local lz = ez + dir[3] * dist
                local lc, lr = HexGrid.CubeToOffset(lx, ly, lz)
                if HexGrid.InBounds(lc, lr) and not HexGrid.IsBlocked(board, lc, lr) then
                    local landingClear = true
                    for step = 1, dist - 1 do
                        local mx = ex + dir[1] * step
                        local my = ey + dir[2] * step
                        local mz = ez + dir[3] * step
                        local mc, mr = HexGrid.CubeToOffset(mx, my, mz)
                        if HexGrid.IsBlocked(board, mc, mr) or HexGrid.GetItemAt(board, mc, mr) then
                            landingClear = false
                            break
                        end
                    end
                    if landingClear then
                        jumps[#jumps + 1] = {
                            col = lc, row = lr,
                            enemy = nil,
                            jumpedCol = ec, jumpedRow = er,
                            isRockJump = true,
                            isScarecrowJump = true,
                            dist = dist,
                        }
                    end
                end
                break  -- 稻草人阻断此方向继续扫描
            end

            -- 棋子/怪物检查（优先于道具，防止道具覆盖怪物判断）
            local piece = HexGrid.GetPieceAt(board, ec, er)
            if piece and piece.hidden then break end  -- 遁地/隐藏的棋子不可跳跃，阻断方向

            -- 道具阻断方向扫描（仅在该格无棋子时生效；有怪物时走下方跳跃逻辑）
            if not piece and HexGrid.GetItemAt(board, ec, er) then break end
            if piece then
                -- 找到了一个棋子（已揭示区域，所以可以看到）
                if piece.team == "enemy" then
                    -- 是敌人：计算对称落点 (再走 dist 步)
                    local lx = ex + dir[1] * dist
                    local ly = ey + dir[2] * dist
                    local lz = ez + dir[3] * dist
                    local lc, lr = HexGrid.CubeToOffset(lx, ly, lz)

                    if HexGrid.InBounds(lc, lr) then
                        if not HexGrid.IsBlocked(board, lc, lr) then
                            local landingClear = true
                            for step = 1, dist - 1 do
                                local mx = ex + dir[1] * step
                                local my = ey + dir[2] * step
                                local mz = ez + dir[3] * step
                                local mc, mr = HexGrid.CubeToOffset(mx, my, mz)
                                if HexGrid.IsBlocked(board, mc, mr) or HexGrid.GetItemAt(board, mc, mr) then
                                    landingClear = false
                                    break
                                end
                            end
                            if landingClear then
                                jumps[#jumps + 1] = {
                                    col = lc, row = lr,
                                    enemy = piece,
                                    jumpedCol = ec, jumpedRow = er,
                                    dist = dist,
                                }
                            end
                        end

                        -- 飞跃先锋: 检查第一个敌人正后方1格是否有第二个可跳目标（敌人或石头）
                        if maxJumpOver >= 2 then
                            local adj_x = ex + dir[1]
                            local adj_y = ey + dir[2]
                            local adj_z = ez + dir[3]
                            local adj_c, adj_r = HexGrid.CubeToOffset(adj_x, adj_y, adj_z)
                            if HexGrid.InBounds(adj_c, adj_r) then
                                -- 检查位置2是敌人还是石头
                                local piece2 = HexGrid.GetPieceAt(board, adj_c, adj_r)
                                local isEnemy2 = piece2 and piece2.team == "enemy"
                                local obs2 = (not isEnemy2) and ch3Rocks and HexGrid.GetJumpSupportAt(board, adj_c, adj_r) or nil
                                if isEnemy2 or obs2 then
                                    -- 位置2有可跳目标！计算其后方 dist 步的对称落点
                                    local l2x = adj_x + dir[1] * dist
                                    local l2y = adj_y + dir[2] * dist
                                    local l2z = adj_z + dir[3] * dist
                                    local l2c, l2r = HexGrid.CubeToOffset(l2x, l2y, l2z)

                                    -- 飞跃先锋6/6: 优先检查第三个相邻目标（敌人或石头）
                                    if maxJumpOver >= 3 then
                                        local adj2_x = adj_x + dir[1]
                                        local adj2_y = adj_y + dir[2]
                                        local adj2_z = adj_z + dir[3]
                                        local adj2_c, adj2_r = HexGrid.CubeToOffset(adj2_x, adj2_y, adj2_z)
                                        if HexGrid.InBounds(adj2_c, adj2_r) then
                                            local piece3 = HexGrid.GetPieceAt(board, adj2_c, adj2_r)
                                            local isEnemy3 = piece3 and piece3.team == "enemy"
                                            local obs3 = (not isEnemy3) and ch3Rocks and HexGrid.GetJumpSupportAt(board, adj2_c, adj2_r) or nil
                                            if isEnemy3 or obs3 then
                                                -- 三个目标相邻！计算第三个后方 dist 步的落点
                                                local l3x = adj2_x + dir[1] * dist
                                                local l3y = adj2_y + dir[2] * dist
                                                local l3z = adj2_z + dir[3] * dist
                                                local l3c, l3r = HexGrid.CubeToOffset(l3x, l3y, l3z)
                                                if HexGrid.InBounds(l3c, l3r) and not HexGrid.IsBlocked(board, l3c, l3r) then
                                                    local path3Clear = true
                                                    for step = 1, dist - 1 do
                                                        local mx = adj2_x + dir[1] * step
                                                        local my = adj2_y + dir[2] * step
                                                        local mz = adj2_z + dir[3] * step
                                                        local mc, mr = HexGrid.CubeToOffset(mx, my, mz)
                                                        if HexGrid.IsBlocked(board, mc, mr) or HexGrid.GetItemAt(board, mc, mr) then
                                                            path3Clear = false
                                                            break
                                                        end
                                                    end
                                                    if path3Clear then
                                                        jumps[#jumps + 1] = {
                                                            col = l3c, row = l3r,
                                                            enemy = piece,
                                                            enemy2 = isEnemy2 and piece2 or nil,
                                                            enemy3 = isEnemy3 and piece3 or nil,
                                                            jumpedCol = ec, jumpedRow = er,
                                                            jumpedCol2 = adj_c, jumpedRow2 = adj_r,
                                                            jumpedCol3 = adj2_c, jumpedRow3 = adj2_r,
                                                            jumpedObstacle2 = obs2,
                                                            jumpedObstacle3 = obs3,
                                                            dist = dist,
                                                            isDoubleJump = true,
                                                            isTripleJump = true,
                                                        }
                                                    end
                                                end
                                            end
                                        end
                                    end

                                    -- 双跳落点检查
                                    if HexGrid.InBounds(l2c, l2r) and not HexGrid.IsBlocked(board, l2c, l2r) then
                                        local pathClear = true
                                        for step = 1, dist - 1 do
                                            local mx = adj_x + dir[1] * step
                                            local my = adj_y + dir[2] * step
                                            local mz = adj_z + dir[3] * step
                                            local mc, mr = HexGrid.CubeToOffset(mx, my, mz)
                                            if HexGrid.IsBlocked(board, mc, mr) or HexGrid.GetItemAt(board, mc, mr) then
                                                pathClear = false
                                                break
                                            end
                                        end
                                        if pathClear then
                                            jumps[#jumps + 1] = {
                                                col = l2c, row = l2r,
                                                enemy = piece,
                                                enemy2 = isEnemy2 and piece2 or nil,
                                                jumpedCol = ec, jumpedRow = er,
                                                jumpedCol2 = adj_c, jumpedRow2 = adj_r,
                                                jumpedObstacle2 = obs2,
                                                dist = dist,
                                                isDoubleJump = true,
                                            }
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                -- 无论是敌人还是友方，此方向被阻断，不继续
                break
            end
        end
    end
    return jumps
end

-- ============================================================================
-- 像素坐标 ↔ 六角格坐标
-- ============================================================================

--- 计算六角格中心像素坐标 (pointy-top)
function HexGrid.HexToPixel(col, row, hexSize, ox, oy)
    local w = math.sqrt(3) * hexSize
    local x = ox + (col - 1) * w + ((row + 1) % 2) * w / 2 + w / 2
    local y = oy + (row - 1) * 1.5 * hexSize + hexSize
    return x, y
end

--- 根据布局尺寸计算绘制参数
--- 确保所有六角格（含描边、HP条）完整显示在区域内
--- @param zoom number|nil 缩放倍率，默认1.0（适配全屏），>1放大棋盘
function HexGrid.CalcGridParams(layoutW, layoutH, cols, rows, zoom)
    zoom = zoom or 1.0
    local padTop = 5
    local padBottom = 140  -- 底部大幅留空，整体棋盘偏上
    local padLR = 30

    local availW = layoutW - padLR * 2
    local availH = layoutH - padTop - padBottom

    -- 垂直: 视觉顶缘 = oy, 视觉底缘 = oy + (rows-1)*1.5*s + 2.5*s
    -- 2.5 = 1(中心到底) + 0.5(HP条+描边额外)
    local sizeByW = availW / ((cols + 0.5) * math.sqrt(3))
    local sizeByH = availH / ((rows - 1) * 1.5 + 2.5)
    local hexSize = math.min(sizeByW, sizeByH) * zoom

    local w = math.sqrt(3) * hexSize
    local totalW = (cols + 0.5) * w
    local totalH = (rows - 1) * 1.5 * hexSize + 2.5 * hexSize

    return {
        hexSize = hexSize,
        offsetX = (layoutW - totalW) / 2,
        offsetY = padTop + (availH - totalH) / 2,
        cols = cols,
        rows = rows,
        zoom = zoom,
        totalW = totalW,
        totalH = totalH,
    }
end

--- 像素坐标转六角格坐标（精确六边形几何判定）
--- 使用 axial → cube round 算法，O(1) 且严格匹配六边形形状
function HexGrid.PixelToHex(px, py, params)
    local s = params.hexSize
    local ox = params.offsetX
    local oy = params.offsetY

    -- 反算 fractional axial 坐标 (pointy-top)
    -- HexToPixel 公式:
    --   x = ox + (col-1)*w + ((row+1)%2)*(w/2) + w/2     (w = √3*s)
    --   y = oy + (row-1)*1.5*s + s
    -- 先从 y 反解 fractional row (0-based)
    local fRow0 = (py - oy - s) / (1.5 * s)  -- 0-based fractional row
    local fRow = fRow0 + 1                     -- 1-based

    -- 用临近整数 row 试探两个候选行，选最近格
    local bestDist = math.huge
    local bestC, bestR = nil, nil
    local w = math.sqrt(3) * s

    -- 试探 fRow 附近的 2~3 行
    local rMin = math.max(1, math.floor(fRow) - 1)
    local rMax = math.min(params.rows, math.ceil(fRow) + 1)

    for r = rMin, rMax do
        -- 该行的 x 偏移
        local rowShift = ((r + 1) % 2) * w / 2
        -- 反算 fractional col (1-based)
        local fCol = (px - ox - rowShift - w / 2) / w + 1
        -- 候选列: fCol 附近的 2 列
        local cMin = math.max(1, math.floor(fCol))
        local cMax = math.min(params.cols, cMin + 1)
        for c = cMin, cMax do
            if HexGrid.InBounds(c, r) then
                local hx, hy = HexGrid.HexToPixel(c, r, s, ox, oy)
                local dx = px - hx
                local dy = py - hy
                local d2 = dx * dx + dy * dy
                if d2 < bestDist then
                    bestDist = d2
                    bestC, bestR = c, r
                end
            end
        end
    end

    -- 验证点击确实在六边形内部（使用六边形几何判定，而非圆形）
    if bestC and bestR then
        local hx, hy = HexGrid.HexToPixel(bestC, bestR, s, ox, oy)
        local dx = math.abs(px - hx)
        local dy = math.abs(py - hy)
        -- pointy-top 六边形内部判定:
        -- 六边形宽 = √3*s, 高 = 2*s
        -- 条件: dy <= s AND dx + dy/√3 <= √3*s/2
        local sqrt3 = math.sqrt(3)
        if dy <= s and dx + dy / sqrt3 <= sqrt3 * s / 2 then
            return bestC, bestR
        end
    end
    return nil, nil
end

-- ============================================================================
-- NanoVG 绘制辅助
-- ============================================================================

--- 绘制一个六角形路径 (pointy-top)
function HexGrid.DrawHex(nvg, cx, cy, size, fillColor, strokeColor)
    nvgBeginPath(nvg)
    for i = 0, 5 do
        local angle = math.rad(60 * i - 90)
        local vx = cx + size * math.cos(angle)
        local vy = cy + size * math.sin(angle)
        if i == 0 then
            nvgMoveTo(nvg, vx, vy)
        else
            nvgLineTo(nvg, vx, vy)
        end
    end
    nvgClosePath(nvg)
    if fillColor then
        nvgFillColor(nvg, fillColor)
        nvgFill(nvg)
    end
    if strokeColor then
        nvgStrokeColor(nvg, strokeColor)
        nvgStrokeWidth(nvg, 2.0)
        nvgStroke(nvg)
    end
end

-- ============================================================================
-- 精灵图系统 (企鹅主角 + 敌人 + Boss)
-- ============================================================================

--- 企鹅动画帧资源路径
local PENGUIN_FRAMES = {
    idle_1   = "image/penguin_idle_1_20260423093815.png",
    idle_2   = "image/penguin_idle_2_20260423093819.png",
    attack_1 = "image/penguin_attack_1_20260423093827.png",
    attack_2 = "image/penguin_attack_2_20260423093826.png",
    hurt     = "image/penguin_hurt_20260423093817.png",
    jump     = "image/penguin_jump_20260423093816.png",
    slide    = "image/penguin_slide_d_20260622090408.png",
}

--- 敌人精灵图资源路径 (enemyType → idle图)
local ENEMY_FRAMES = {
    slime            = "image/enemy_slime_idle_20260424093313.png",
    skeleton         = "image/enemy_skeleton_idle_20260424093320.png",
    mushroom         = "image/enemy_mushroom_idle_20260424093320.png",
    jellyfish        = "image/enemy_jellyfish_idle_20260424093310.png",
    iron_turtle       = "image/enemy_iron_turtle_idle_20260424093321.png",
    vortex_eel       = "image/enemy_vortex_eel_idle_20260424093309.png",
    hermit_crab      = "image/enemy_hermit_crab_idle_20260424093310.png",
    hermit_crab_hurt = "image/enemy_hermit_crab_hurt_20260424093330.png",
    fire_sprite      = "image/enemy_fire_sprite_idle_20260424093336.png",
    lava_giant       = "image/enemy_lava_giant_idle_20260424093324.png",
    shadow_ambusher  = "image/enemy_shadow_ambusher_idle_20260424093432.png",
    smoke_master     = "image/enemy_smoke_master_idle_20260424093431.png",
    ghost_shark      = "image/enemy_ghost_shark_idle_20260509063933.png",
    archerfish       = "image/enemy_archerfish_idle_20260512041629.png",
    electric_ray     = "image/enemy_electric_ray_idle_20260512041628.png",
    spine_anemone    = "image/enemy_spine_anemone_idle_20260509064134.png",
    coral_priest     = "image/enemy_coral_priest_idle_20260509064003.png",
    fission_flame    = "image/enemy_fission_flame_idle_20260509063931.png",
    flame_shard      = "image/enemy_flame_shard_idle_20260509063946.png",
    -- 第四章: 流沙荒漠
    sand_scorpion    = "image/enemy_sand_scorpion_idle_20260528082515.png",
    quicksand_worm   = "image/enemy_quicksand_worm_idle_20260528082519.png",
    sand_hawk        = "image/enemy_sand_hawk_idle_20260528082518.png",
    sand_strider     = "image/enemy_sand_strider_idle_20260604061442.png",
    sand_rattler     = "image/enemy_sand_rattler_idle_20260604061452.png",
    venom_lizard     = "image/enemy_venom_lizard_idle_20260604061425.png",
    -- 第五章: 永冻绝境
    frost_grunt      = "image/enemy_frost_grunt_idle_20260622114714.png",
    frost_barracuda  = "image/enemy_frost_barracuda_idle_20260622123652.png",
    aurora_jelly     = "image/enemy_frost_wisp_idle_v2_20260624025908.png",
    ice_crystal      = "image/enemy_ice_crystal_idle_20260624025347.png",
    blizzard_hawk    = "image/enemy_blizzard_hawk_idle_20260624025342.png",
    frost_bear       = "image/enemy_frost_bear_idle_20260624025350.png",
}

--- Boss 精灵图资源路径 (bossType → {normal, enraged})
local BOSS_FRAMES = {
    abyss_kraken = {
        normal  = "image/boss_abyss_kraken_normal_20260424093442.png",
        enraged = "image/boss_abyss_kraken_enraged_20260424093438.png",
    },
    lava_lord = {
        normal  = "image/boss_lava_lord_normal_20260424093454.png",
        enraged = "image/boss_lava_lord_enraged_20260424093439.png",
    },
    coral_guardian = {
        normal  = "image/edited_boss_coral_guardian_normal_transparent_20260523133331.png",
        enraged = "image/edited_boss_coral_guardian_enraged_transparent_20260523133406.png",
    },
    sand_worm = {
        normal  = "image/sandworm_head_new_20260601072952.png",
        enraged = "image/boss_sand_worm_enraged_20260604061426.png",
        body    = "image/sandworm_body_20260529063642.png",
    },
}

--- 通用图片句柄缓存 (路径 → NanoVG handle)
local spriteCache = {}

--- 加载单张精灵图并缓存
local function EnsureSpriteImage(nvg, path)
    if not path then return nil end
    if spriteCache[path] then return spriteCache[path] end
    local handle = nvgCreateImage(nvg, path, 0)
    if handle and handle > 0 then
        spriteCache[path] = handle
        return handle
    end
    return nil
end

--- 确保企鹅帧全部加载（兼容旧逻辑）
local penguinImagesLoaded = false
local function EnsurePenguinImages(nvg)
    if penguinImagesLoaded then return true end
    local allOk = true
    for key, path in pairs(PENGUIN_FRAMES) do
        if not EnsureSpriteImage(nvg, path) then
            allOk = false
        end
    end
    if allOk then penguinImagesLoaded = true end
    return allOk
end

--- 根据英雄状态选择当前显示的帧 key
--- @param piece table 英雄棋子数据
--- @return string 帧 key (如 "idle_1", "attack_1", "hurt", "jump")
local function GetPenguinFrameKey(piece)
    -- 优先级: dead > hurt > slide > jump > attack > idle
    if piece._dead then
        return "hurt"  -- 死亡时使用受伤帧
    end
    if piece._hitFlash and piece._hitFlash > 0 then
        return "hurt"
    end
    if piece.isSliding and piece.animTimer and piece.animTimer > 0 then
        return "slide"
    end
    if piece.animIsJump and piece.animTimer and piece.animTimer > 0 then
        return "jump"
    end
    if piece._attackAnim and piece._attackAnim > 0 then
        local half = (piece._attackAnimMax or 0.3) / 2
        if piece._attackAnim > half then
            return "attack_1"
        else
            return "attack_2"
        end
    end
    local t = piece._gameTime or 0
    local idx = math.floor(t / 0.6) % 2
    return idx == 0 and "idle_1" or "idle_2"
end

--- 获取敌人精灵图路径
--- @param piece table 敌人棋子数据
--- @return string|nil 精灵图资源路径
local function GetEnemySpritePath(piece)
    local et = piece.enemyType
    if not et then return nil end
    -- 寄居蟹特殊: 无壳时显示受伤形态
    if et == "hermit_crab" and not piece.hasShell then
        return ENEMY_FRAMES["hermit_crab_hurt"]
    end

    return ENEMY_FRAMES[et]
end

--- 获取Boss精灵图路径
--- @param piece table Boss棋子数据
--- @return string|nil 精灵图资源路径
local function GetBossSpritePath(piece)
    local bt = piece.bossType or "abyss_kraken"
    local frames = BOSS_FRAMES[bt]
    if not frames then return nil end
    if piece.enraged then
        return frames.enraged
    end
    return frames.normal
end

--- 无贴图时的 NanoVG 矢量绘制 fallback（替代 emoji）
local function DrawEnemyNVG(nvg, cx, cy, r, enemyType, gameTime)
    local t = gameTime or 0

    if enemyType == "coral_snapper" then
        -- 珊瑚捕手：橙红蟹体 + 双侧蟹钳
        -- 身体
        nvgBeginPath(nvg)
        nvgEllipse(nvg, cx, cy + r * 0.05, r * 0.52, r * 0.42)
        nvgFillColor(nvg, nvgRGBA(220, 95, 45, 255))
        nvgFill(nvg)
        -- 身体横纹
        for i = -1, 1 do
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, cx - r * 0.38, cy + i * r * 0.14)
            nvgLineTo(nvg, cx + r * 0.38, cy + i * r * 0.14)
            nvgStrokeColor(nvg, nvgRGBA(170, 60, 20, 130))
            nvgStrokeWidth(nvg, 1.2)
            nvgStroke(nvg)
        end
        -- 双钳（左右对称，轻微开合动画）
        local clawOpen = math.sin(t * 1.8) * 0.08
        for side = -1, 1, 2 do
            local bx = cx + side * r * 0.52
            local by = cy - r * 0.05
            -- 钳臂
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, bx, by)
            nvgLineTo(nvg, bx + side * r * 0.3, by - r * 0.28)
            nvgStrokeColor(nvg, nvgRGBA(200, 75, 35, 255))
            nvgStrokeWidth(nvg, 3.5)
            nvgStroke(nvg)
            -- 上钳
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, bx + side * r * 0.3, by - r * 0.28)
            nvgLineTo(nvg, bx + side * r * (0.55 + clawOpen), by - r * (0.48 + clawOpen))
            nvgStrokeColor(nvg, nvgRGBA(240, 110, 50, 255))
            nvgStrokeWidth(nvg, 3)
            nvgStroke(nvg)
            -- 下钳
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, bx + side * r * 0.3, by - r * 0.28)
            nvgLineTo(nvg, bx + side * r * (0.55 - clawOpen), by - r * (0.1 - clawOpen))
            nvgStrokeColor(nvg, nvgRGBA(240, 110, 50, 255))
            nvgStrokeWidth(nvg, 3)
            nvgStroke(nvg)
        end
        -- 眼睛
        for side = -1, 1, 2 do
            nvgBeginPath(nvg)
            nvgCircle(nvg, cx + side * r * 0.22, cy - r * 0.28, r * 0.1)
            nvgFillColor(nvg, nvgRGBA(15, 15, 15, 255))
            nvgFill(nvg)
            nvgBeginPath(nvg)
            nvgCircle(nvg, cx + side * r * 0.19, cy - r * 0.3, r * 0.04)
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, 180))
            nvgFill(nvg)
        end

    elseif enemyType == "sea_urchin" then
        -- 海胆：深绿圆体 + 8根放射刺
        local spikeCount = 8
        local innerR  = r * 0.42
        local outerR  = r * 0.82
        for i = 1, spikeCount do
            local angle = (i / spikeCount) * math.pi * 2
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, cx + math.cos(angle) * innerR, cy + math.sin(angle) * innerR)
            nvgLineTo(nvg, cx + math.cos(angle) * outerR, cy + math.sin(angle) * outerR)
            nvgStrokeColor(nvg, nvgRGBA(90, 155, 75, 255))
            nvgStrokeWidth(nvg, 3)
            nvgStroke(nvg)
        end
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, innerR)
        nvgFillColor(nvg, nvgRGBA(45, 105, 55, 255))
        nvgFill(nvg)
        -- 高光
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx - innerR * 0.28, cy - innerR * 0.32, innerR * 0.28)
        nvgFillColor(nvg, nvgRGBA(110, 195, 120, 70))
        nvgFill(nvg)

    elseif enemyType == "reef_starfish" then
        -- 礁石海星：5角星，橙金配色
        local outerR2 = r * 0.75
        local innerR2 = r * 0.32
        nvgBeginPath(nvg)
        for i = 0, 9 do
            local angle = (i / 10) * math.pi * 2 - math.pi / 2
            local rad = (i % 2 == 0) and outerR2 or innerR2
            local px = cx + math.cos(angle) * rad
            local py = cy + math.sin(angle) * rad
            if i == 0 then nvgMoveTo(nvg, px, py) else nvgLineTo(nvg, px, py) end
        end
        nvgClosePath(nvg)
        nvgFillColor(nvg, nvgRGBA(225, 125, 45, 255))
        nvgFill(nvg)
        nvgStrokeColor(nvg, nvgRGBA(175, 85, 20, 200))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, innerR2 * 0.75)
        nvgFillColor(nvg, nvgRGBA(255, 185, 80, 255))
        nvgFill(nvg)

    elseif enemyType == "splitting_urchin" then
        -- 裂变海胆：橙褐色 + 10根刺 + 发光裂缝
        local spikeCount = 10
        local innerR  = r * 0.40
        local outerR  = r * 0.80
        for i = 1, spikeCount do
            local angle = (i / spikeCount) * math.pi * 2
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, cx + math.cos(angle) * innerR, cy + math.sin(angle) * innerR)
            nvgLineTo(nvg, cx + math.cos(angle) * outerR, cy + math.sin(angle) * outerR)
            nvgStrokeColor(nvg, nvgRGBA(215, 135, 45, 255))
            nvgStrokeWidth(nvg, 2.8)
            nvgStroke(nvg)
        end
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, innerR)
        nvgFillColor(nvg, nvgRGBA(175, 95, 25, 255))
        nvgFill(nvg)
        -- 裂缝（黄色发光）
        local crackPulse = 0.6 + math.sin(t * 3.0) * 0.4
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx - innerR * 0.75, cy - innerR * 0.15)
        nvgLineTo(nvg, cx + innerR * 0.1, cy + innerR * 0.05)
        nvgLineTo(nvg, cx + innerR * 0.65, cy + innerR * 0.75)
        nvgStrokeColor(nvg, nvgRGBA(255, 220, 50, math.floor(220 * crackPulse)))
        nvgStrokeWidth(nvg, 2.2)
        nvgStroke(nvg)

    elseif enemyType == "swift_barracuda" then
        -- 疾梭鱼：流线鱼体，蓝银配色，尾鳍摆动
        local wave = math.sin(t * 4.5) * r * 0.05
        -- 尾鳍
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx + r * 0.52, cy + wave)
        nvgLineTo(nvg, cx + r * 0.88, cy - r * 0.32 + wave)
        nvgLineTo(nvg, cx + r * 0.88, cy + r * 0.32 + wave)
        nvgClosePath(nvg)
        nvgFillColor(nvg, nvgRGBA(55, 135, 195, 210))
        nvgFill(nvg)
        -- 鱼身
        nvgBeginPath(nvg)
        nvgEllipse(nvg, cx - r * 0.08, cy + wave * 0.5, r * 0.62, r * 0.27)
        nvgFillColor(nvg, nvgRGBA(75, 165, 215, 255))
        nvgFill(nvg)
        -- 腹部亮面
        nvgBeginPath(nvg)
        nvgEllipse(nvg, cx - r * 0.08, cy + r * 0.07 + wave * 0.5, r * 0.48, r * 0.12)
        nvgFillColor(nvg, nvgRGBA(195, 232, 255, 190))
        nvgFill(nvg)
        -- 背鳍
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx - r * 0.22, cy - r * 0.27 + wave * 0.5)
        nvgLineTo(nvg, cx, cy - r * 0.48 + wave * 0.5)
        nvgLineTo(nvg, cx + r * 0.22, cy - r * 0.27 + wave * 0.5)
        nvgFillColor(nvg, nvgRGBA(45, 115, 175, 195))
        nvgFill(nvg)
        -- 眼睛
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx - r * 0.34, cy - r * 0.05 + wave * 0.5, r * 0.1)
        nvgFillColor(nvg, nvgRGBA(10, 10, 10, 255))
        nvgFill(nvg)
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx - r * 0.31, cy - r * 0.08 + wave * 0.5, r * 0.04)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 190))
        nvgFill(nvg)

    elseif enemyType == "charm_jelly" then
        -- 魅惑水母：紫色钟形 + 触手波动 + 心形眼睛
        -- 触手（5根，波浪动画）
        for i = 1, 5 do
            local tx = cx - r * 0.38 + (i - 1) * r * 0.19
            local wo = math.sin(t * 2.5 + i * 1.3) * r * 0.14
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, tx, cy + r * 0.32)
            nvgBezierTo(nvg, tx + wo, cy + r * 0.52, tx - wo, cy + r * 0.72, tx + wo * 0.4, cy + r * 0.88)
            nvgStrokeColor(nvg, nvgRGBA(175, 75, 215, 155))
            nvgStrokeWidth(nvg, 1.8)
            nvgStroke(nvg)
        end
        -- 钟形主体（径向渐变）
        local jellyGrad = nvgRadialGradient(nvg, cx, cy - r * 0.08, r * 0.08, r * 0.68,
            nvgRGBA(225, 125, 255, 210), nvgRGBA(135, 45, 195, 165))
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx - r * 0.55, cy + r * 0.32)
        nvgBezierTo(nvg, cx - r * 0.55, cy - r * 0.55, cx + r * 0.55, cy - r * 0.55, cx + r * 0.55, cy + r * 0.32)
        nvgBezierTo(nvg, cx + r * 0.3, cy + r * 0.48, cx - r * 0.3, cy + r * 0.48, cx - r * 0.55, cy + r * 0.32)
        nvgClosePath(nvg)
        nvgFillPaint(nvg, jellyGrad)
        nvgFill(nvg)
        -- 内层透明高光
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx - r * 0.3, cy + r * 0.22)
        nvgBezierTo(nvg, cx - r * 0.3, cy - r * 0.38, cx + r * 0.3, cy - r * 0.38, cx + r * 0.3, cy + r * 0.22)
        nvgBezierTo(nvg, cx + r * 0.15, cy + r * 0.3, cx - r * 0.15, cy + r * 0.3, cx - r * 0.3, cy + r * 0.22)
        nvgClosePath(nvg)
        nvgFillColor(nvg, nvgRGBA(245, 165, 255, 65))
        nvgFill(nvg)
        -- 心形眼（两个圆拼接）
        local heartPulse = 0.85 + math.sin(t * 3.5) * 0.15
        for side = -1, 1, 2 do
            local hx = cx + side * r * 0.18
            local hy = cy - r * 0.06
            nvgBeginPath(nvg)
            nvgCircle(nvg, hx - r * 0.045 * heartPulse, hy - r * 0.04 * heartPulse, r * 0.08 * heartPulse)
            nvgFillColor(nvg, nvgRGBA(255, 55, 105, 230))
            nvgFill(nvg)
            nvgBeginPath(nvg)
            nvgCircle(nvg, hx + r * 0.045 * heartPulse, hy - r * 0.04 * heartPulse, r * 0.08 * heartPulse)
            nvgFill(nvg)
        end

    elseif enemyType == "sand_scorpion" then
        -- 沙蝎：深金色椭圆体 + 双钳 + 尾刺
        nvgBeginPath(nvg)
        nvgEllipse(nvg, cx, cy, r * 0.45, r * 0.35)
        nvgFillColor(nvg, nvgRGBA(180, 130, 40, 255))
        nvgFill(nvg)
        -- 双钳
        for side = -1, 1, 2 do
            local px = cx + side * r * 0.5
            local py = cy - r * 0.1
            nvgBeginPath(nvg)
            nvgCircle(nvg, px, py, r * 0.15)
            nvgFillColor(nvg, nvgRGBA(200, 150, 50, 255))
            nvgFill(nvg)
        end
        -- 尾刺（向上弧线）
        local tailTip = cy - r * 0.55 + math.sin(t * 3.0) * r * 0.05
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx, cy + r * 0.2)
        nvgBezierTo(nvg, cx + r * 0.15, cy - r * 0.1, cx + r * 0.05, cy - r * 0.4, cx, tailTip)
        nvgStrokeColor(nvg, nvgRGBA(160, 100, 30, 255))
        nvgStrokeWidth(nvg, 2.5)
        nvgStroke(nvg)
        -- 尾尖发光
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, tailTip, r * 0.08)
        nvgFillColor(nvg, nvgRGBA(255, 200, 60, 220))
        nvgFill(nvg)

    elseif enemyType == "quicksand_worm" then
        -- 流沙蠕虫：分段浅黄蠕虫体 + 波动
        local segCount = 4
        for i = 1, segCount do
            local segY = cy + (i - 2.5) * r * 0.22
            local wave = math.sin(t * 2.5 + i * 1.2) * r * 0.08
            local segSize = r * (0.28 - (math.abs(i - 2.5) * 0.04))
            nvgBeginPath(nvg)
            nvgEllipse(nvg, cx + wave, segY, segSize, segSize * 0.7)
            nvgFillColor(nvg, nvgRGBA(180, 150, 80, 240 - i * 15))
            nvgFill(nvg)
        end
        -- 头部圆环（顶部）
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy - r * 0.35, r * 0.18)
        nvgFillColor(nvg, nvgRGBA(200, 170, 90, 255))
        nvgFill(nvg)
        nvgStrokeColor(nvg, nvgRGBA(140, 100, 50, 200))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)

    elseif enemyType == "sand_hawk" then
        -- 沙鹰：展翅三角形 + 头部圆
        -- 翅膀
        local wingFlap = math.sin(t * 4.0) * r * 0.08
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx, cy)
        nvgLineTo(nvg, cx - r * 0.6, cy + r * 0.15 + wingFlap)
        nvgLineTo(nvg, cx - r * 0.3, cy - r * 0.1)
        nvgClosePath(nvg)
        nvgFillColor(nvg, nvgRGBA(200, 160, 80, 240))
        nvgFill(nvg)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx, cy)
        nvgLineTo(nvg, cx + r * 0.6, cy + r * 0.15 + wingFlap)
        nvgLineTo(nvg, cx + r * 0.3, cy - r * 0.1)
        nvgClosePath(nvg)
        nvgFillColor(nvg, nvgRGBA(200, 160, 80, 240))
        nvgFill(nvg)
        -- 身体
        nvgBeginPath(nvg)
        nvgEllipse(nvg, cx, cy, r * 0.2, r * 0.3)
        nvgFillColor(nvg, nvgRGBA(160, 120, 50, 255))
        nvgFill(nvg)
        -- 头
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy - r * 0.35, r * 0.13)
        nvgFillColor(nvg, nvgRGBA(220, 180, 100, 255))
        nvgFill(nvg)
        -- 眼
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy - r * 0.36, r * 0.04)
        nvgFillColor(nvg, nvgRGBA(40, 20, 10, 255))
        nvgFill(nvg)

    elseif enemyType == "frost_grunt" or enemyType == "frost_barracuda" then
        -- 第五章冰系敌人 fallback（贴图加载失败时的矢量占位）
        local isBarra = (enemyType == "frost_barracuda")
        nvgBeginPath(nvg)
        if isBarra then
            -- 梭鱼形状：水平椭圆
            nvgEllipse(nvg, cx, cy, r * 0.6, r * 0.3)
        else
            -- 冰锥兵：六边形
            local sides = 6
            for i = 0, sides - 1 do
                local angle = math.pi * 2 * i / sides - math.pi / 2
                local px = cx + math.cos(angle) * r * 0.5
                local py = cy + math.sin(angle) * r * 0.5
                if i == 0 then nvgMoveTo(nvg, px, py) else nvgLineTo(nvg, px, py) end
            end
            nvgClosePath(nvg)
        end
        nvgFillColor(nvg, nvgRGBA(100, 180, 240, 230))
        nvgFill(nvg)
        nvgStrokeColor(nvg, nvgRGBA(180, 220, 255, 255))
        nvgStrokeWidth(nvg, 2)
        nvgStroke(nvg)
        -- 冰晶标记
        nvgFontSize(nvg, r * 0.6)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 240))
        nvgText(nvg, cx, cy, isBarra and "🐟" or "🧊")
    else
        -- 未知类型：画一个简单的带问号圆形
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, r * 0.55)
        nvgFillColor(nvg, nvgRGBA(80, 80, 100, 220))
        nvgFill(nvg)
        nvgStrokeColor(nvg, nvgRGBA(150, 150, 180, 200))
        nvgStrokeWidth(nvg, 2)
        nvgStroke(nvg)
        nvgFontSize(nvg, r * 0.75)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(200, 200, 220, 255))
        nvgText(nvg, cx, cy, "?")
    end
end

local function DrawSpriteImage(nvg, cx, cy, drawRadius, imgHandle, scale, yOffset, alpha)
    local spriteSize = drawRadius * scale
    local sx = cx - spriteSize / 2
    local sy = cy - spriteSize / 2 + yOffset
    local imgPaint = nvgImagePattern(nvg, sx, sy, spriteSize, spriteSize, 0, imgHandle, alpha or 1.0)
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, spriteSize, spriteSize)
    nvgFillPaint(nvg, imgPaint)
    nvgFill(nvg)
end

--- 绘制棋子 (精灵图 + HP条)
function HexGrid.DrawPiece(nvg, cx, cy, radius, piece)
    local isEnemy = piece.team == "enemy"
    local isBoss = piece.isBoss

    -- Boss 比普通敌人大一些
    local drawRadius = isBoss and (radius * 1.25) or radius

    -- 呼吸动画偏移 (所有角色共享)
    local gameTime = piece._gameTime or 0
    local breathOffset = math.sin(gameTime * 2.5) * drawRadius * 0.04

    if isBoss then
        local bt = piece.bossType or "abyss_kraken"
        local isEnraged = piece.enraged

        -- ─── Boss 主题色 ───
        local themeR, themeG, themeB = 80, 50, 180   -- 深渊海妖: 紫色
        if bt == "lava_lord" then themeR, themeG, themeB = 220, 60, 20       -- 熔岩领主: 橙红
        elseif bt == "coral_guardian" then themeR, themeG, themeB = 30, 160, 140 -- 珊瑚守卫: 青色
        elseif bt == "sand_worm" or bt == "sand_worm_body" then themeR, themeG, themeB = 190, 150, 50 end -- 沙虫: 金沙

        -- ─── 沙虫身体段渲染（NanoVG 程序化，与头部风格统一）───
        if piece.isSegment then
            local segIdx = piece.segmentIndex or 2
            local segScale = math.max(0.6, 1.0 - (segIdx - 1) * 0.05)
            local segR = drawRadius * segScale
            local segCy = cy + breathOffset

            -- 投影
            nvgBeginPath(nvg)
            nvgEllipse(nvg, cx + 1, segCy + segR * 0.7, segR * 0.65, segR * 0.18)
            nvgFillColor(nvg, nvgRGBA(0, 0, 0, 45))
            nvgFill(nvg)

            -- 身体主体（沙金色渐变球体，与头部色调一致）
            local dimFactor = math.max(0.6, 1.0 - (segIdx - 1) * 0.06)
            nvgBeginPath(nvg)
            nvgCircle(nvg, cx, segCy, segR)
            local bodyGrad = nvgRadialGradient(nvg, cx - segR * 0.2, segCy - segR * 0.25,
                segR * 0.1, segR,
                nvgRGBA(math.floor(240 * dimFactor), math.floor(200 * dimFactor), math.floor(100 * dimFactor), 255),
                nvgRGBA(math.floor(160 * dimFactor), math.floor(110 * dimFactor), math.floor(40 * dimFactor), 255))
            nvgFillPaint(nvg, bodyGrad)
            nvgFill(nvg)

            -- 环状鳞片纹理（2-3道弧线）
            local ringCount = segIdx <= 2 and 3 or 2
            for ri = 1, ringCount do
                local rFrac = ri / (ringCount + 1)
                local rY = segCy - segR + segR * 2 * rFrac
                local halfW = segR * math.sin(math.acos(math.abs(rFrac - 0.5) * 2)) * 0.8
                if halfW > 2 then
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, cx - halfW, rY)
                    nvgQuadTo(nvg, cx, rY + segR * 0.05, cx + halfW, rY)
                    nvgStrokeColor(nvg, nvgRGBA(math.floor(130 * dimFactor), math.floor(85 * dimFactor), 30, 110))
                    nvgStrokeWidth(nvg, 1.5)
                    nvgStroke(nvg)
                end
            end

            -- 外描边（与头部风格一致）
            nvgBeginPath(nvg)
            nvgCircle(nvg, cx, segCy, segR)
            nvgStrokeColor(nvg, nvgRGBA(120, 80, 25, math.floor(160 * dimFactor)))
            nvgStrokeWidth(nvg, 2.0)
            nvgStroke(nvg)

            -- segment 完成，跳过后续 Boss 特效
            goto boss_render_done
        end

        -- ─── 1. 暗能量扩散波纹 (双层) ───
        for ri = 0, 1 do
            local ripple = (gameTime * 0.6 + ri * 0.5) % 1.0
            local rippleR = drawRadius * 0.5 + ripple * drawRadius * 1.2
            local rippleA = math.floor((isEnraged and 120 or 70) * (1.0 - ripple))
            nvgBeginPath(nvg)
            nvgCircle(nvg, cx, cy + breathOffset, rippleR)
            nvgStrokeColor(nvg, nvgRGBA(themeR, themeG, themeB, rippleA))
            nvgStrokeWidth(nvg, isEnraged and 2.5 or 1.5)
            nvgStroke(nvg)
        end

        -- ─── 2. 外层辐射光环 (径向渐变) ───
        local glowPulse = math.sin(gameTime * 3.0) * 0.3 + 0.7
        local outerGlowR = drawRadius * 1.6
        local gAlpha = isEnraged and math.floor(100 * glowPulse) or math.floor(55 * glowPulse)
        local outerGlow = nvgRadialGradient(nvg, cx, cy + breathOffset, drawRadius * 0.3, outerGlowR,
            nvgRGBA(themeR, themeG, themeB, gAlpha),
            nvgRGBA(themeR, themeG, themeB, 0))
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy + breathOffset, outerGlowR)
        nvgFillPaint(nvg, outerGlow)
        nvgFill(nvg)

        -- ─── 3. 暗能量粒子环绕 ───
        local particleCount = isEnraged and 8 or 5
        for i = 1, particleCount do
            local angle = (gameTime * 1.2 + i * (6.2832 / particleCount)) % 6.2832
            local pDist = drawRadius * (0.9 + math.sin(gameTime * 2.0 + i) * 0.2)
            local px = cx + math.cos(angle) * pDist
            local py = cy + breathOffset + math.sin(angle) * pDist * 0.5  -- 椭圆轨道
            local pSize = 2.5 + math.sin(gameTime * 3.0 + i * 1.5) * 1.5
            local pAlpha = math.floor(120 + math.sin(gameTime * 4.0 + i) * 60)
            nvgBeginPath(nvg)
            nvgCircle(nvg, px, py, pSize)
            nvgFillColor(nvg, nvgRGBA(themeR + 60, themeG + 40, themeB + 30, pAlpha))
            nvgFill(nvg)
        end

        -- ─── 3.5 深渊漩涡 (脚底旋转暗能量) ───
        local vortexCy = cy + drawRadius * 0.55
        -- 旋转暗能量弧线（3条，120度间隔）
        for vi = 0, 2 do
            local vAngle0 = gameTime * 1.5 + vi * 2.094
            -- 每条弧线由多段组成，形成螺旋感
            for seg = 0, 5 do
                local segT = seg / 5
                local vAngle = vAngle0 + segT * 1.8
                local vDist = drawRadius * (0.15 + segT * 0.7)
                local vx = cx + math.cos(vAngle) * vDist
                local vy = vortexCy + math.sin(vAngle) * vDist * 0.3  -- 压扁成椭圆
                local vSize = (2.0 + segT * 2.5) * (1.0 - segT * 0.3)
                local vAlpha = math.floor((isEnraged and 130 or 80) * (1.0 - segT * 0.6))
                nvgBeginPath(nvg)
                nvgCircle(nvg, vx, vy, vSize)
                nvgFillColor(nvg, nvgRGBA(themeR, themeG, themeB, vAlpha))
                nvgFill(nvg)
            end
        end
        -- 漩涡中心暗点
        local vortexGlow = nvgRadialGradient(nvg, cx, vortexCy, 0, drawRadius * 0.45,
            nvgRGBA(0, 0, 0, isEnraged and 100 or 60),
            nvgRGBA(themeR, themeG, themeB, 0))
        nvgBeginPath(nvg)
        nvgEllipse(nvg, cx, vortexCy, drawRadius * 0.5, drawRadius * 0.18)
        nvgFillPaint(nvg, vortexGlow)
        nvgFill(nvg)

        -- ─── 3.6 深渊雾气粒子 (大范围漂浮) ───
        local mistCount = isEnraged and 12 or 7
        for mi = 1, mistCount do
            local mSeed = mi * 3.7
            local mSpeed = 0.3 + (mi % 3) * 0.15
            local mAngle = (gameTime * mSpeed + mSeed) % 6.2832
            local mDist = drawRadius * (0.6 + math.sin(gameTime * 0.5 + mSeed) * 0.5)
            local mx = cx + math.cos(mAngle) * mDist
            local my = cy + breathOffset + math.sin(mAngle) * mDist * 0.4
            -- 上下漂浮
            my = my + math.sin(gameTime * 1.5 + mSeed) * drawRadius * 0.15
            local mSize = 3 + math.sin(gameTime * 2.0 + mSeed) * 2
            local mAlpha = math.floor(40 + math.sin(gameTime * 1.8 + mSeed) * 25)
            local mistGlow = nvgRadialGradient(nvg, mx, my, 0, mSize * 2,
                nvgRGBA(themeR, themeG, themeB, mAlpha),
                nvgRGBA(themeR, themeG, themeB, 0))
            nvgBeginPath(nvg)
            nvgCircle(nvg, mx, my, mSize * 2)
            nvgFillPaint(nvg, mistGlow)
            nvgFill(nvg)
        end

        -- ─── 4. 脚底投影 (加大) ───
        nvgBeginPath(nvg)
        nvgEllipse(nvg, cx + 1, cy + drawRadius * 0.7, drawRadius * 0.85, drawRadius * 0.28)
        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 60))
        nvgFill(nvg)

        -- ─── 5. Boss 精灵图 (呼吸缩放 + 放大 + 技能攻击动画) ───
        local breathScale = 1.0 + math.sin(gameTime * 2.0) * 0.04
        local bossScale = 4.8 * breathScale
        local bossYOff = -drawRadius * 0.2

        -- 技能攻击动画：_skillAnim = 0→1 进度，_skillAnimType 区分技能类型
        local skillAnim  = piece._skillAnim or 0       -- 0=无动画, >0 = 进行中(0→1)
        local skillType  = piece._skillAnimType or ""
        local skillOffX, skillOffY = 0, 0              -- 精灵位移（冲刺/后坐）
        local skillScaleBonus = 0                       -- 额外缩放
        local skillFlashR, skillFlashG, skillFlashB = 255, 255, 255
        local skillFlashA = 0                           -- 叠加闪光 Alpha

        if skillAnim > 0 then
            -- 动画曲线: 0→0.3 冲出, 0.3→0.6 顶点, 0.6→1.0 回弹
            local t = skillAnim  -- 0→1 进度
            local attackCurve
            if t < 0.3 then
                attackCurve = t / 0.3                       -- 0→1 前冲
            elseif t < 0.6 then
                attackCurve = 1.0 - (t - 0.3) / 0.3        -- 1→0 回拉
            else
                attackCurve = -(t - 0.6) / 0.4 * 0.25      -- 轻微后坐
            end

            -- 各技能独特动作
            if skillType == "claw" then
                -- 触手重击：向前下方猛冲，紫色闪光，放大
                skillOffX = attackCurve * drawRadius * 0.35
                skillOffY = attackCurve * drawRadius * 0.25
                skillScaleBonus = attackCurve * 0.3
                skillFlashR, skillFlashG, skillFlashB = 180, 60, 255
                skillFlashA = math.floor(attackCurve * 200)
            elseif skillType == "venom" then
                -- 深渊喷毒：前仰后仰晃动，深紫色污染光
                local wobble = math.sin(skillAnim * math.pi * 4) * 0.3
                skillOffX = wobble * drawRadius * 0.2
                skillOffY = -math.abs(attackCurve) * drawRadius * 0.1
                skillScaleBonus = math.abs(wobble) * 0.15
                skillFlashR, skillFlashG, skillFlashB = 100, 20, 180
                skillFlashA = math.floor(math.abs(wobble) * 180)
            elseif skillType == "fist" then
                -- 熔岩重拳：猛力下砸，橙红炽热闪光，显著放大
                skillOffX = attackCurve * drawRadius * 0.1
                skillOffY = attackCurve * drawRadius * 0.5   -- 向下砸
                skillScaleBonus = attackCurve * 0.4
                skillFlashR, skillFlashG, skillFlashB = 255, 120, 20
                skillFlashA = math.floor(attackCurve * 230)
            elseif skillType == "bolt" then
                -- 火焰弹射：向前快速弹出后快速回位（后坐力），黄橙闪光
                skillOffX = attackCurve * drawRadius * 0.45
                skillOffY = attackCurve * drawRadius * 0.1
                skillScaleBonus = attackCurve * 0.2
                skillFlashR, skillFlashG, skillFlashB = 255, 200, 50
                skillFlashA = math.floor(attackCurve * 210)
            elseif skillType == "spike" then
                -- 珊瑚刺击：急速前冲刺，青绿色电光闪烁
                local spikeCurve = t < 0.25 and (t / 0.25) or math.max(0, 1.0 - (t - 0.25) / 0.75)
                skillOffX = spikeCurve * drawRadius * 0.5
                skillOffY = spikeCurve * drawRadius * 0.2
                skillScaleBonus = spikeCurve * 0.25
                skillFlashR, skillFlashG, skillFlashB = 80, 255, 200
                skillFlashA = math.floor(spikeCurve * 190)
            end
        end

        local finalBossScale = bossScale * (1.0 + skillScaleBonus)
        local finalOffX = skillOffX
        local finalOffY = breathOffset + skillOffY

        -- 技能发动时的冲击光圈（在精灵图下方）
        if skillFlashA > 10 then
            local glowR = drawRadius * (1.2 + skillScaleBonus * 1.5)
            nvgBeginPath(nvg)
            nvgCircle(nvg, cx + finalOffX, cy + finalOffY, glowR)
            nvgFillPaint(nvg, nvgRadialGradient(nvg,
                cx + finalOffX, cy + finalOffY, 0, glowR,
                nvgRGBA(skillFlashR, skillFlashG, skillFlashB, math.floor(skillFlashA * 0.5)),
                nvgRGBA(skillFlashR, skillFlashG, skillFlashB, 0)))
            nvgFill(nvg)
        end

        -- ─── 沙虫头部：NanoVG 程序化绘制（与身体统一风格） ───
        if bt == "sand_worm" and not piece.isSegment then
            local hx = cx + finalOffX
            local hy = cy + finalOffY + bossYOff
            local hr = drawRadius * 0.88 * (1.0 + skillScaleBonus)

            -- 头部主体（与身体段相同的沙金色渐变球体，但更亮更大）
            nvgBeginPath(nvg)
            nvgCircle(nvg, hx, hy, hr)
            local headGrad = nvgRadialGradient(nvg, hx - hr * 0.2, hy - hr * 0.25,
                hr * 0.05, hr * 1.0,
                nvgRGBA(255, 215, 110, 255),
                nvgRGBA(180, 120, 45, 255))
            nvgFillPaint(nvg, headGrad)
            nvgFill(nvg)

            -- 环状鳞甲纹理（与身体段统一，但更密集，4道弧线）
            for ri = 1, 4 do
                local rFrac = ri / 5
                local rY = hy - hr + hr * 2 * rFrac
                local halfW = hr * math.sin(math.acos(math.abs(rFrac - 0.5) * 2)) * 0.85
                if halfW > 2 then
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, hx - halfW, rY)
                    nvgQuadTo(nvg, hx, rY + hr * 0.04, hx + halfW, rY)
                    nvgStrokeColor(nvg, nvgRGBA(140, 90, 30, 80))
                    nvgStrokeWidth(nvg, 1.2)
                    nvgStroke(nvg)
                end
            end

            -- 大嘴（环形嘴，像沙虫经典造型 - 三瓣裂口）
            local mouthCy = hy + hr * 0.15
            local mouthR = hr * 0.42
            local mouthOpen = 1.0 + math.sin(gameTime * 2.0) * 0.08
            -- 嘴内深色底
            nvgBeginPath(nvg)
            nvgCircle(nvg, hx, mouthCy, mouthR * mouthOpen)
            nvgFillColor(nvg, nvgRGBA(40, 12, 8, 250))
            nvgFill(nvg)
            -- 嘴内渐变深渊
            nvgBeginPath(nvg)
            nvgCircle(nvg, hx, mouthCy, mouthR * 0.6 * mouthOpen)
            nvgFillPaint(nvg, nvgRadialGradient(nvg, hx, mouthCy, 0, mouthR * 0.6,
                nvgRGBA(80, 20, 10, 255), nvgRGBA(20, 5, 2, 255)))
            nvgFill(nvg)
            -- 三瓣牙齿（均匀分布在嘴边缘，像沙虫的经典三瓣口器）
            for ti = 0, 2 do
                local tAngle = (ti / 3) * math.pi * 2 - math.pi / 2
                local tBaseX = hx + math.cos(tAngle) * mouthR * 0.85
                local tBaseY = mouthCy + math.sin(tAngle) * mouthR * 0.85
                local tTipX = hx + math.cos(tAngle) * mouthR * 0.3
                local tTipY = mouthCy + math.sin(tAngle) * mouthR * 0.3
                local tSize = hr * 0.12
                local perpAngle = tAngle + math.pi / 2
                nvgBeginPath(nvg)
                nvgMoveTo(nvg, tBaseX + math.cos(perpAngle) * tSize, tBaseY + math.sin(perpAngle) * tSize)
                nvgLineTo(nvg, tTipX, tTipY)
                nvgLineTo(nvg, tBaseX - math.cos(perpAngle) * tSize, tBaseY - math.sin(perpAngle) * tSize)
                nvgClosePath(nvg)
                nvgFillColor(nvg, nvgRGBA(250, 240, 210, 255))
                nvgFill(nvg)
            end
            -- 嘴边缘环
            nvgBeginPath(nvg)
            nvgCircle(nvg, hx, mouthCy, mouthR * mouthOpen)
            nvgStrokeColor(nvg, nvgRGBA(100, 60, 20, 200))
            nvgStrokeWidth(nvg, 2.0)
            nvgStroke(nvg)

            -- 眼睛（两颗发光圆眼，和身体的沙金色协调）
            local eyeY = hy - hr * 0.35
            local eyeSpacing = hr * 0.38
            local eyeR = hr * 0.13
            for ei = -1, 1, 2 do
                local ex = hx + ei * eyeSpacing
                -- 眼底光晕
                nvgBeginPath(nvg)
                nvgCircle(nvg, ex, eyeY, eyeR * 1.6)
                nvgFillPaint(nvg, nvgRadialGradient(nvg, ex, eyeY, 0, eyeR * 1.6,
                    nvgRGBA(255, 160, 30, 80), nvgRGBA(255, 160, 30, 0)))
                nvgFill(nvg)
                -- 眼球（橙色发光）
                nvgBeginPath(nvg)
                nvgCircle(nvg, ex, eyeY, eyeR)
                nvgFillColor(nvg, nvgRGBA(255, 180, 40, 255))
                nvgFill(nvg)
                -- 竖瞳（垂直椭圆）
                nvgBeginPath(nvg)
                nvgEllipse(nvg, ex, eyeY, eyeR * 0.3, eyeR * 0.7)
                nvgFillColor(nvg, nvgRGBA(30, 10, 5, 255))
                nvgFill(nvg)
                -- 高光点
                nvgBeginPath(nvg)
                nvgCircle(nvg, ex - eyeR * 0.25, eyeY - eyeR * 0.3, eyeR * 0.2)
                nvgFillColor(nvg, nvgRGBA(255, 255, 255, 200))
                nvgFill(nvg)
            end

            -- 头顶甲壳尖刺（2个，比触角更凶猛）
            for ai = -1, 1, 2 do
                local spX = hx + ai * hr * 0.35
                local spBaseY = hy - hr * 0.6
                local spTipY = hy - hr * 1.05
                local sway = math.sin(gameTime * 1.5 + ai * 2.0) * hr * 0.02
                nvgBeginPath(nvg)
                nvgMoveTo(nvg, spX - hr * 0.08, spBaseY)
                nvgLineTo(nvg, spX + sway, spTipY)
                nvgLineTo(nvg, spX + hr * 0.08, spBaseY)
                nvgClosePath(nvg)
                nvgFillColor(nvg, nvgRGBA(200, 140, 40, 240))
                nvgFill(nvg)
                nvgStrokeColor(nvg, nvgRGBA(140, 90, 25, 180))
                nvgStrokeWidth(nvg, 1.0)
                nvgStroke(nvg)
            end

            -- 外描边（与身体统一，稍粗）
            nvgBeginPath(nvg)
            nvgCircle(nvg, hx, hy, hr)
            nvgStrokeColor(nvg, nvgRGBA(120, 80, 25, 200))
            nvgStrokeWidth(nvg, 2.5)
            nvgStroke(nvg)

            -- 受击闪白
            if piece._hitFlash and piece._hitFlash > 0 then
                nvgBeginPath(nvg)
                nvgCircle(nvg, hx, hy, hr)
                nvgFillColor(nvg, nvgRGBA(255, 255, 255, math.floor(piece._hitFlash * 180)))
                nvgFill(nvg)
            end

            -- 技能闪光
            if skillFlashA > 10 then
                nvgBeginPath(nvg)
                nvgCircle(nvg, hx, hy, hr * 1.05)
                nvgFillColor(nvg, nvgRGBA(skillFlashR, skillFlashG, skillFlashB, math.floor(skillFlashA * 0.4)))
                nvgFill(nvg)
            end
        else
        -- ─── 非沙虫Boss：精灵图渲染 ───
        local spritePath = GetBossSpritePath(piece)
        local imgHandle = EnsureSpriteImage(nvg, spritePath)
        if imgHandle then
            -- 受击闪白效果
            if piece._hitFlash and piece._hitFlash > 0 then
                nvgGlobalAlpha(nvg, 0.6)
                DrawSpriteImage(nvg, cx + finalOffX, cy + finalOffY, drawRadius, imgHandle, finalBossScale, bossYOff, 1.0)
                nvgGlobalAlpha(nvg, 1.0)
            end
            DrawSpriteImage(nvg, cx + finalOffX, cy + finalOffY, drawRadius, imgHandle, finalBossScale, bossYOff, 1.0)
            -- 技能闪光叠加层（精灵图上方，Screen混合近似：半透明亮色）
            if skillFlashA > 10 then
                nvgGlobalAlpha(nvg, skillFlashA / 255.0 * 0.45)
                DrawSpriteImage(nvg, cx + finalOffX, cy + finalOffY, drawRadius, imgHandle, finalBossScale, bossYOff, 1.0)
                nvgGlobalAlpha(nvg, 1.0)
            end
        else
            -- fallback: 彩色圆 + emoji
            nvgBeginPath(nvg)
            nvgCircle(nvg, cx + finalOffX, cy + finalOffY, drawRadius * (1.0 + skillScaleBonus))
            nvgFillColor(nvg, nvgRGBA(themeR, themeG, themeB, 255))
            nvgFill(nvg)
            local label = bt == "lava_lord" and "🌋" or (bt == "abyss_kraken" and "🐙" or (bt == "coral_guardian" and "🪸" or "🗡️"))
            nvgFontSize(nvg, drawRadius * 1.3 * (1.0 + skillScaleBonus))
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
            nvgText(nvg, cx + finalOffX, cy + finalOffY - 1, label)
        end
        end

        -- ─── 6. 内层能量光芒 ───
        local innerGlow = nvgRadialGradient(nvg, cx, cy + breathOffset, 0, drawRadius * 0.6,
            nvgRGBA(themeR + 80, themeG + 60, themeB + 40, math.floor(40 * glowPulse)),
            nvgRGBA(themeR, themeG, themeB, 0))
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy + breathOffset, drawRadius * 0.6)
        nvgFillPaint(nvg, innerGlow)
        nvgFill(nvg)

        -- ─── 6.5 Boss 常驻主题色描边（区分小怪） ───
        local strokePulse = math.sin(gameTime * 2.5) * 0.15 + 0.85
        -- 外发光（柔和光晕衬底）
        local strokeGlowR = drawRadius * 1.15
        local strokeGlow = nvgRadialGradient(nvg, cx, cy + breathOffset,
            drawRadius * 0.85, strokeGlowR,
            nvgRGBA(themeR, themeG, themeB, math.floor(90 * strokePulse)),
            nvgRGBA(themeR, themeG, themeB, 0))
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy + breathOffset, strokeGlowR)
        nvgFillPaint(nvg, strokeGlow)
        nvgFill(nvg)
        -- 主描边（粗亮边框）
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy + breathOffset, drawRadius * 0.95)
        nvgStrokeColor(nvg, nvgRGBA(
            math.min(255, themeR + 80),
            math.min(255, themeG + 60),
            math.min(255, themeB + 40),
            math.floor(200 * strokePulse)))
        nvgStrokeWidth(nvg, 3.5)
        nvgStroke(nvg)
        -- 内描边（亮色细线，增加层次）
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy + breathOffset, drawRadius * 0.88)
        nvgStrokeColor(nvg, nvgRGBA(255, 255, 255, math.floor(50 * strokePulse)))
        nvgStrokeWidth(nvg, 1.0)
        nvgStroke(nvg)

        -- ─── 7. 狂暴增强特效 ───
        if isEnraged then
            -- 脉动红色描边
            local pulseR = drawRadius + 6 + math.sin(gameTime * 5.0) * 4
            nvgBeginPath(nvg)
            nvgCircle(nvg, cx, cy + breathOffset, pulseR)
            nvgStrokeColor(nvg, nvgRGBA(255, 50, 50, math.floor(140 + math.sin(gameTime * 4.0) * 80)))
            nvgStrokeWidth(nvg, 3.0)
            nvgStroke(nvg)

            -- 狂暴外层火焰粒子
            for i = 1, 6 do
                local fAngle = (gameTime * 2.5 + i * 1.047) % 6.2832
                local fDist = drawRadius * 1.1 + math.sin(gameTime * 3.0 + i * 2.0) * 4
                local fx = cx + math.cos(fAngle) * fDist
                local fy = cy + breathOffset + math.sin(fAngle) * fDist * 0.4
                local fSize = 3 + math.sin(gameTime * 5.0 + i) * 2
                nvgBeginPath(nvg)
                nvgCircle(nvg, fx, fy, fSize)
                nvgFillColor(nvg, nvgRGBA(255, 100, 30, math.floor(160 + math.sin(gameTime * 6.0 + i) * 60)))
                nvgFill(nvg)
            end
        end

        -- ─── 8. 暗能量触须 (从Boss向外延伸的能量丝线) ───
        local tendrilCount = isEnraged and 6 or 4
        for ti = 1, tendrilCount do
            local tSeed = ti * 2.37
            local tBaseAngle = (ti / tendrilCount) * 6.2832 + gameTime * 0.4
            -- 触须用贝塞尔感的多段线绘制
            local tLen = drawRadius * (1.3 + math.sin(gameTime * 1.5 + tSeed) * 0.4)
            local tAlpha = math.floor((isEnraged and 120 or 70) * (0.7 + math.sin(gameTime * 2.0 + tSeed) * 0.3))
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, cx, cy + breathOffset)
            -- 3段弧线模拟蠕动触须
            for seg = 1, 3 do
                local segT = seg / 3
                local wave = math.sin(gameTime * 3.0 + tSeed + seg * 1.2) * drawRadius * 0.25
                local segAngle = tBaseAngle + wave * 0.02
                local segDist = tLen * segT
                local tx = cx + math.cos(segAngle) * segDist + math.sin(gameTime * 2.5 + seg + tSeed) * wave * 0.3
                local ty = cy + breathOffset + math.sin(segAngle) * segDist * 0.35 - segT * drawRadius * 0.2
                if seg == 3 then
                    nvgLineTo(nvg, tx, ty)
                else
                    -- 中间段加一点弯曲
                    local cpx = tx + math.cos(gameTime * 2.0 + tSeed) * wave * 0.5
                    local cpy = ty + math.sin(gameTime * 2.0 + tSeed) * wave * 0.3
                    nvgLineTo(nvg, cpx, cpy)
                    nvgLineTo(nvg, tx, ty)
                end
            end
            nvgStrokeColor(nvg, nvgRGBA(themeR + 30, themeG + 20, themeB + 20, tAlpha))
            nvgStrokeWidth(nvg, 2.5 - 0.5 * (ti % 2))
            nvgStroke(nvg)
            -- 触须末端发光点
            local tipAngle = tBaseAngle + math.sin(gameTime * 3.0 + tSeed + 3.6) * 0.02
            local tipDist = tLen
            local tipX = cx + math.cos(tipAngle) * tipDist + math.sin(gameTime * 2.5 + 3 + tSeed) * drawRadius * 0.08
            local tipY = cy + breathOffset + math.sin(tipAngle) * tipDist * 0.35 - drawRadius * 0.2
            local tipGlow = nvgRadialGradient(nvg, tipX, tipY, 0, 6,
                nvgRGBA(themeR + 80, themeG + 60, themeB + 60, tAlpha),
                nvgRGBA(themeR, themeG, themeB, 0))
            nvgBeginPath(nvg)
            nvgCircle(nvg, tipX, tipY, 6)
            nvgFillPaint(nvg, tipGlow)
            nvgFill(nvg)
        end

        -- ─── 9. 周期压迫冲击波 (每隔几秒一次沉重的扩散波) ───
        local wavePeriod = isEnraged and 2.5 or 4.0
        local waveProgress = (gameTime % wavePeriod) / wavePeriod
        if waveProgress < 0.6 then
            local wt = waveProgress / 0.6
            local waveR = drawRadius * (0.5 + wt * 2.5)
            local waveAlpha = math.floor((isEnraged and 100 or 55) * (1.0 - wt))
            local waveWidth = (isEnraged and 4.0 or 2.5) * (1.0 - wt * 0.7)
            nvgBeginPath(nvg)
            nvgCircle(nvg, cx, cy + breathOffset, waveR)
            nvgStrokeColor(nvg, nvgRGBA(themeR, themeG, themeB, waveAlpha))
            nvgStrokeWidth(nvg, waveWidth)
            nvgStroke(nvg)
            -- 第二层内圈波纹（延迟）
            if waveProgress > 0.15 then
                local wt2 = (waveProgress - 0.15) / 0.45
                local waveR2 = drawRadius * (0.5 + wt2 * 2.0)
                local waveAlpha2 = math.floor((isEnraged and 60 or 35) * (1.0 - wt2))
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy + breathOffset, waveR2)
                nvgStrokeColor(nvg, nvgRGBA(themeR, themeG, themeB, waveAlpha2))
                nvgStrokeWidth(nvg, waveWidth * 0.6)
                nvgStroke(nvg)
            end
        end

        -- ─── 10. 技能蓄力预警 (下回合意图) ───
        if piece.nextSkillKey and piece.nextSkillColor then
            local nc = piece.nextSkillColor
            local nr, ng, nb2 = nc[1], nc[2], nc[3]
            -- 快速脉动（比常规呼吸快3倍，营造紧张感）
            local chargePulse = math.abs(math.sin(gameTime * 5.0))
            local chargeAlpha = math.floor(80 + chargePulse * 120)

            -- 外层警示光环（快速扩张收缩）
            local chargeRingR = drawRadius * (1.4 + chargePulse * 0.5)
            nvgBeginPath(nvg)
            nvgCircle(nvg, cx, cy + breathOffset, chargeRingR)
            nvgStrokeColor(nvg, nvgRGBA(nr, ng, nb2, chargeAlpha))
            nvgStrokeWidth(nvg, 3.0 + chargePulse * 2.0)
            nvgStroke(nvg)

            -- 内层填充光晕（蓄力颜色覆盖主题色）
            local chargeGlow = nvgRadialGradient(nvg,
                cx, cy + breathOffset,
                drawRadius * 0.2, drawRadius * 1.3,
                nvgRGBA(nr, ng, nb2, math.floor(chargeAlpha * 0.45)),
                nvgRGBA(nr, ng, nb2, 0))
            nvgBeginPath(nvg)
            nvgCircle(nvg, cx, cy + breathOffset, drawRadius * 1.3)
            nvgFillPaint(nvg, chargeGlow)
            nvgFill(nvg)

            -- 蓄力粒子：从Boss四周向中心汇聚
            for ci = 1, 8 do
                local cAngle = (ci / 8) * math.pi * 2 + gameTime * 3.0
                -- 汇聚：粒子从外向内飞（用 1-frac 控制距离）
                local frac = (gameTime * 1.5) % 1.0
                local cDist = drawRadius * (0.5 + (1.0 - frac) * 1.2)
                local cpx = cx + math.cos(cAngle) * cDist
                local cpy = cy + breathOffset + math.sin(cAngle) * cDist * 0.5
                local cSize = 2.5 * (0.3 + frac * 0.7)
                local cAlpha = math.floor(180 * frac)
                nvgBeginPath(nvg)
                nvgCircle(nvg, cpx, cpy, cSize)
                nvgFillColor(nvg, nvgRGBA(nr, ng, nb2, cAlpha))
                nvgFill(nvg)
            end

            -- 震颤偏移（用于上层图标，在 BoardWidget 中用同一字段读取）
            -- DrawPiece 本身不移位精灵，震颤由BoardWidget的图标偏移体现
        end

        ::boss_render_done::

    elseif isEnemy then
        -- 脚底投影
        nvgBeginPath(nvg)
        nvgEllipse(nvg, cx + 1, cy + drawRadius * 0.6, drawRadius * 0.65, drawRadius * 0.22)
        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 45))
        nvgFill(nvg)

        -- 幽灵鲨半透明幽灵效果
        local isGhostShark = piece.enemyType == "ghost_shark"
        if isGhostShark then
            local ghostAlpha = 0.55 + math.sin(gameTime * 2.0) * 0.15
            nvgGlobalAlpha(nvg, ghostAlpha)
        end

        -- 敌人精灵图
        local spritePath = GetEnemySpritePath(piece)
        local imgHandle = EnsureSpriteImage(nvg, spritePath)
        if imgHandle then
            -- 受击闪白
            if piece._hitFlash and piece._hitFlash > 0 then
                nvgGlobalAlpha(nvg, isGhostShark and 0.35 or 0.5)
                DrawSpriteImage(nvg, cx, cy + breathOffset, drawRadius, imgHandle, 3.0, -drawRadius * 0.12, 1.0)
                nvgGlobalAlpha(nvg, isGhostShark and 0.55 or 1.0)
            end
            DrawSpriteImage(nvg, cx, cy + breathOffset, drawRadius, imgHandle, 3.0, -drawRadius * 0.12, 1.0)
        else
            -- fallback: NanoVG 矢量图标
            DrawEnemyNVG(nvg, cx, cy + breathOffset, drawRadius, piece.enemyType, gameTime)
        end

        -- 恢复幽灵鲨半透明
        if isGhostShark then
            nvgGlobalAlpha(nvg, 1.0)
        end

        -- 珊瑚祭司支援光环（柔和金色脉动）
        if piece.enemyType == "coral_priest" then
            local auraPulse = math.sin(gameTime * 3.0) * 0.3 + 0.7
            nvgBeginPath(nvg)
            nvgCircle(nvg, cx, cy + breathOffset, drawRadius + 6 + auraPulse * 2)
            nvgStrokeColor(nvg, nvgRGBA(255, 200, 100, math.floor(100 * auraPulse)))
            nvgStrokeWidth(nvg, 1.5)
            nvgStroke(nvg)
            -- 十字标记
            nvgFontSize(nvg, drawRadius * 0.45)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(nvg, nvgRGBA(255, 220, 100, math.floor(200 * auraPulse)))
            nvgText(nvg, cx + drawRadius * 0.65, cy + breathOffset - drawRadius * 0.55, "✚")
        end

        -- 棘刺海葵远程标记（棘刺环）
        if piece.enemyType == "spine_anemone" then
            for i = 1, 5 do
                local sAngle = (i / 5) * math.pi * 2 + gameTime * 1.5
                local sx = cx + math.cos(sAngle) * (drawRadius + 4)
                local sy = cy + breathOffset + math.sin(sAngle) * (drawRadius + 4)
                nvgBeginPath(nvg)
                nvgCircle(nvg, sx, sy, 2)
                nvgFillColor(nvg, nvgRGBA(220, 80, 160, 150))
                nvgFill(nvg)
            end
        end

        -- 寄居蟹缩壳防御光环
        if piece.enemyType == "hermit_crab" and piece.hasShell then
            nvgBeginPath(nvg)
            nvgCircle(nvg, cx, cy + breathOffset, drawRadius + 4)
            nvgStrokeColor(nvg, nvgRGBA(190, 160, 100, 180))
            nvgStrokeWidth(nvg, 2.5)
            nvgStroke(nvg)
        end

        -- 祭坛减伤光环（多层火焰护盾笼罩 + 减伤百分比）
        if piece.altarShield then
            local shPulse = math.sin(gameTime * 4.0 + (piece.col or 0)) * 0.3 + 0.7
            local shFast  = math.sin(gameTime * 6.0 + (piece.col or 0) * 1.5) * 0.5 + 0.5
            local shSlow  = math.sin(gameTime * 2.0 + (piece.col or 0) * 0.8) * 0.5 + 0.5
            local bcx, bcy = cx, cy + breathOffset

            -- 层1: 最外层大范围火焰扩散光晕
            local outerGlowR = drawRadius + 18 + shSlow * 6
            nvgBeginPath(nvg)
            nvgCircle(nvg, bcx, bcy, outerGlowR)
            nvgFillPaint(nvg, nvgRadialGradient(nvg,
                bcx, bcy, drawRadius * 0.2, outerGlowR,
                nvgRGBA(255, 120, 10, math.floor(45 * shPulse)),
                nvgRGBA(255, 80, 0, 0)))
            nvgFill(nvg)

            -- 层2: 中层火焰光晕（橙红色）
            local midGlowR = drawRadius + 12 + shPulse * 4
            nvgBeginPath(nvg)
            nvgCircle(nvg, bcx, bcy, midGlowR)
            nvgFillPaint(nvg, nvgRadialGradient(nvg,
                bcx, bcy, drawRadius * 0.4, midGlowR,
                nvgRGBA(255, 160, 30, math.floor(70 * shPulse)),
                nvgRGBA(255, 100, 0, 0)))
            nvgFill(nvg)

            -- 层3: 外圈主火焰环（厚实亮圈，呼吸脉动）
            nvgBeginPath(nvg)
            nvgCircle(nvg, bcx, bcy, drawRadius + 6 + shPulse * 3)
            nvgStrokeColor(nvg, nvgRGBA(255, 170, 40, math.floor(240 * shPulse)))
            nvgStrokeWidth(nvg, 4.0)
            nvgStroke(nvg)

            -- 层4: 内圈高亮火焰环（快速闪烁）
            nvgBeginPath(nvg)
            nvgCircle(nvg, bcx, bcy, drawRadius + 2)
            nvgStrokeColor(nvg, nvgRGBA(255, 220, 100, math.floor(180 * shFast)))
            nvgStrokeWidth(nvg, 2.0)
            nvgStroke(nvg)

            -- 层5: 内部半透明火焰填充（笼罩感）
            nvgBeginPath(nvg)
            nvgCircle(nvg, bcx, bcy, drawRadius + 1)
            nvgFillPaint(nvg, nvgRadialGradient(nvg,
                bcx, bcy, 0, drawRadius + 1,
                nvgRGBA(255, 200, 80, math.floor(50 * shPulse)),
                nvgRGBA(255, 140, 30, math.floor(25 * shPulse))))
            nvgFill(nvg)

            -- 层6: 顶部火焰图标
            nvgFontSize(nvg, drawRadius * 0.55)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(nvg, nvgRGBA(255, 200, 80, math.floor(230 * shPulse)))
            nvgText(nvg, bcx, bcy - drawRadius - 8, "🔥")

            -- "减伤"文字提示（头顶悬浮，呼吸缩放）
            local tagX = bcx
            local tagY = bcy - drawRadius - 10 - drawRadius * 0.5
            local breathScale = 0.9 + shPulse * 0.15
            local breathAlpha = math.floor(180 + shPulse * 75)
            local fontSize = drawRadius * 0.7 * breathScale
            nvgSave(nvg)
            nvgFontSize(nvg, fontSize)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            -- 背景胶囊
            local padX = fontSize * 0.5
            local padY = fontSize * 0.25
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, tagX - padX - fontSize * 0.9, tagY - padY - fontSize * 0.15,
                (padX + fontSize * 0.9) * 2, (padY + fontSize * 0.15) * 2 + fontSize * 0.1, fontSize * 0.35)
            nvgFillColor(nvg, nvgRGBA(140, 30, 0, math.floor(breathAlpha * 0.75)))
            nvgFill(nvg)
            nvgStrokeColor(nvg, nvgRGBA(255, 160, 50, math.floor(breathAlpha * 0.6)))
            nvgStrokeWidth(nvg, 1.5)
            nvgStroke(nvg)
            nvgFillColor(nvg, nvgRGBA(255, 230, 130, breathAlpha))
            nvgText(nvg, tagX, tagY, "减伤")
            nvgRestore(nvg)
        end

    else
        -- 英雄: 企鹅精灵图渲染

        -- 脚底投影
        nvgBeginPath(nvg)
        nvgEllipse(nvg, cx + 1, cy + drawRadius * 0.6, drawRadius * 0.7, drawRadius * 0.25)
        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 40))
        nvgFill(nvg)

        -- 企鹅精灵图
        local spriteOk = EnsurePenguinImages(nvg)
        -- 死亡动画参数
        local isDying = piece._dead
        local deathProgress = 0  -- 0~1
        if isDying then
            local elapsed = (piece._gameTime or 0) - (piece._deadStartTime or 0)
            deathProgress = math.min(1.0, elapsed / (piece._deadDuration or 1.0))
        end

        if spriteOk then
            local frameKey = GetPenguinFrameKey(piece)
            local imgPath = PENGUIN_FRAMES[frameKey]
            local imgHandle = spriteCache[imgPath]
            if imgHandle then
                if isDying then
                    -- 死亡倒地：旋转 + 下沉 + 渐隐
                    nvgSave(nvg)
                    local rot = deathProgress * math.pi * 0.5
                    local sinkY = deathProgress * drawRadius * 0.4
                    local alpha = math.max(0.15, 1.0 - deathProgress * 0.7)
                    nvgTranslate(nvg, cx, cy + breathOffset + sinkY)
                    nvgRotate(nvg, rot)
                    nvgGlobalAlpha(nvg, alpha)
                    DrawSpriteImage(nvg, 0, 0, drawRadius, imgHandle, 3.2, -drawRadius * 0.15, 1.0)
                    nvgGlobalAlpha(nvg, 1.0)
                    nvgRestore(nvg)
                elseif frameKey == "slide" and piece.animFromCol and piece.animFromRow then
                    -- 滑行：朝滑行方向旋转，尺寸保持接近普通状态
                    -- 用cube坐标差算方向角度（不依赖hexSize/ox/oy）
                    local fx, fy, fz = HexGrid.OffsetToCube(piece.animFromCol, piece.animFromRow)
                    local tx, ty, tz = HexGrid.OffsetToCube(piece.col, piece.row)
                    local ddx, ddy = (tx - fx) + (tz - fz) * 0.5, (tz - fz) * 0.866
                    local slideAngle = math.atan(ddy, ddx) - math.pi / 2  -- 图片头朝上
                    nvgSave(nvg)
                    nvgTranslate(nvg, cx, cy + breathOffset)
                    nvgRotate(nvg, slideAngle)
                    DrawSpriteImage(nvg, 0, 0, drawRadius, imgHandle, 3.25, -drawRadius * 0.12, 1.0)
                    nvgRestore(nvg)
                else
                    DrawSpriteImage(nvg, cx, cy + breathOffset, drawRadius, imgHandle, 3.2, -drawRadius * 0.15, 1.0)
                end
            end
        else
            -- fallback: 蓝色圆 + emoji
            nvgBeginPath(nvg)
            nvgCircle(nvg, cx, cy, drawRadius)
            nvgFillColor(nvg, nvgRGBA(35, 90, 190, 255))
            nvgFill(nvg)

            nvgFontSize(nvg, drawRadius * 1.3)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
            nvgText(nvg, cx, cy - 1, "🐧")
        end
    end

    -- HP条（沙虫身体段不显示独立血条）
    if piece.isSegment then return end
    local barW = drawRadius * 1.8
    local barH = isBoss and 6 or 4
    local barX = cx - barW / 2
    local barY = cy + drawRadius + 3
    local hpRatio = math.max(0, piece.hp / piece.maxHp)

    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, barX, barY, barW, barH, 2)
    nvgFillColor(nvg, nvgRGBA(60, 60, 60, 200))
    nvgFill(nvg)

    if hpRatio > 0 then
        local r = hpRatio > 0.5 and 80 or (hpRatio > 0.25 and 220 or 220)
        local g = hpRatio > 0.5 and 200 or (hpRatio > 0.25 and 160 or 60)
        local b = hpRatio > 0.5 and 80 or 40
        -- Boss用紫色HP条
        if isBoss then r, g, b = 180, 80, 220 end
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, barX, barY, barW * hpRatio, barH, 2)
        nvgFillColor(nvg, nvgRGBA(r, g, b, 255))
        nvgFill(nvg)
    end

    -- Boss 护盾条（在HP条下方）
    if isBoss and piece.shieldHp and piece.shieldMax and piece.shieldMax > 0 then
        local shieldRatio = math.max(0, piece.shieldHp / piece.shieldMax)
        if shieldRatio > 0 then
            local sBarY = barY + barH + 2
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, barX, sBarY, barW, 3, 1.5)
            nvgFillColor(nvg, nvgRGBA(40, 40, 60, 200))
            nvgFill(nvg)
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, barX, sBarY, barW * shieldRatio, 3, 1.5)
            nvgFillColor(nvg, nvgRGBA(80, 160, 255, 255))
            nvgFill(nvg)
        end
    end
end

-- ============================================================================
-- 流沙系统 (quicksand zones) - 第四章
-- ============================================================================
-- 简化版：敌人死亡有概率产生大流沙区（中心+6邻居=7格），
-- 流沙区不可通行、不可飞越，5回合后自动消失。

--- 检查某格是否在任何流沙区内（中心1格+周围6格）
function HexGrid.IsInQuicksandZone(board, col, row)
    if not board.quicksandZones then return false end
    for _, zone in ipairs(board.quicksandZones) do
        if HexGrid.CubeDistance(col, row, zone.col, zone.row) <= 1 then
            return true
        end
    end
    return false
end

--- 添加流沙区（以 col,row 为中心的7格区域）
function HexGrid.AddQuicksandZone(board, col, row)
    if not board.quicksandZones then board.quicksandZones = {} end
    -- 避免中心点重复
    for _, zone in ipairs(board.quicksandZones) do
        if zone.col == col and zone.row == row then return zone end
    end
    local zone = { col = col, row = row, timer = 5, spawnTime = -1 }
    board.quicksandZones[#board.quicksandZones + 1] = zone
    return zone
end

--- 流沙区回合推进：timer-1，归零则移除
function HexGrid.TickQuicksandZones(board)
    if not board.quicksandZones then return end
    for i = #board.quicksandZones, 1, -1 do
        local zone = board.quicksandZones[i]
        zone.timer = zone.timer - 1
        if zone.timer <= 0 then
            table.remove(board.quicksandZones, i)
        end
    end
end

--- 寻找距离 (col,row) 最近的、不在流沙区内且无阻挡的空格子
--- 用于流沙区生成时将角色推到安全位置
---@param board table
---@param col integer 起始列
---@param row integer 起始行
---@return integer|nil, integer|nil 安全格的 col, row；找不到则返回 nil
function HexGrid.FindNearestSafeCell(board, col, row)
    -- BFS 向外扩展寻找
    local visited = {}
    local key = function(c, r) return c * 100 + r end
    local queue = {}
    -- 从当前位置的邻居开始（当前位置本身在流沙区内）
    local neighbors = HexGrid.GetNeighbors(col, row)
    for _, n in ipairs(neighbors) do
        queue[#queue + 1] = n
        visited[key(n.col, n.row)] = true
    end
    visited[key(col, row)] = true
    local idx = 1
    while idx <= #queue do
        local cell = queue[idx]
        idx = idx + 1
        local c, r = cell.col, cell.row
        -- 检查是否安全：不在流沙区、没有棋子、没有障碍物
        if not HexGrid.IsInQuicksandZone(board, c, r)
           and not HexGrid.GetPieceAt(board, c, r)
           and not HexGrid.GetObstacleAt(board, c, r) then
            return c, r
        end
        -- 继续扩展
        local nextN = HexGrid.GetNeighbors(c, r)
        for _, nn in ipairs(nextN) do
            local k = key(nn.col, nn.row)
            if not visited[k] then
                visited[k] = true
                queue[#queue + 1] = nn
            end
        end
    end
    return nil, nil
end

return HexGrid
