-- ============================================================================
-- IceMechanic.lua - Chapter 5 Ice Terrain & Slide Mechanic
-- Manages ice tile data, generation, and the core slide-on-landing rule.
-- ============================================================================

local HexGrid = require "HexGrid"
local AM = require "AudioManager"

local IceMechanic = {}

-- 6 cube directions (same as HexGrid internal CUBE_DIRS)
local CUBE_DIRS = {
    { 1, -1,  0},
    { 1,  0, -1},
    { 0,  1, -1},
    {-1,  1,  0},
    {-1,  0,  1},
    { 0, -1,  1},
}

-- ============================================================================
-- Data Management
-- ============================================================================

--- Initialize ice tile storage on battle state
function IceMechanic.Init(state)
    if not state._iceTiles then
        state._iceTiles = {}  -- hash map: "col,row" = true
    end
end

--- Check if a tile is ice
---@param state table
---@param col integer
---@param row integer
---@return boolean
function IceMechanic.IsIceTile(state, col, row)
    if not state._iceTiles then return false end
    return state._iceTiles[col .. "," .. row] == true
end

--- Add an ice tile
function IceMechanic.AddIceTile(state, col, row)
    if not state._iceTiles then state._iceTiles = {} end
    if HexGrid.InBounds(col, row) then
        state._iceTiles[col .. "," .. row] = true
    end
end

--- Remove an ice tile
function IceMechanic.RemoveIceTile(state, col, row)
    if state._iceTiles then
        state._iceTiles[col .. "," .. row] = nil
    end
end

--- Clear ice in radius around a point (for "ice breaker" items)
function IceMechanic.ClearIceRadius(state, col, row, radius)
    if not state._iceTiles then return end
    for r2 = 1, HexGrid.ROWS do
        for c2 = 1, HexGrid.COLS do
            if HexGrid.CubeDistance(c2, r2, col, row) <= radius then
                state._iceTiles[c2 .. "," .. r2] = nil
            end
        end
    end
end

--- Get count of ice tiles
function IceMechanic.GetIceCount(state)
    if not state._iceTiles then return 0 end
    local count = 0
    for _ in pairs(state._iceTiles) do count = count + 1 end
    return count
end

-- ============================================================================
-- Generation
-- ============================================================================

--- Generate initial ice tiles for chapter 5 levels
--- 第五章全棋盘都是冰面，所有格子都会触发滑行
---@param state table battle state
---@param stageInChapter integer 1-10
function IceMechanic.GenerateInitialIce(state, stageInChapter)
    IceMechanic.Init(state)
    state.iceWallCrashCount = state.iceWallCrashCount or 0

    -- 全棋盘铺冰
    for r = 1, HexGrid.ROWS do
        for c = 1, HexGrid.COLS do
            if HexGrid.InBounds(c, r) then
                IceMechanic.AddIceTile(state, c, r)
            end
        end
    end
end

local ICE_BLOCK_DROP_THRESHOLD = 3

local function FindIceBlockDropCell(state, originCol, originRow)
    local candidates = {}
    local hero = state.hero
    for r = 1, HexGrid.ROWS do
        for c = 1, HexGrid.COLS do
            if HexGrid.InBounds(c, r)
               and not HexGrid.IsBlocked(state.board, c, r)
               and not HexGrid.GetItemAt(state.board, c, r) then
                local heroDist = hero and HexGrid.CubeDistance(c, r, hero.col, hero.row) or 99
                local crashDist = HexGrid.CubeDistance(c, r, originCol, originRow)
                if heroDist >= 1 then
                    local score = math.abs(heroDist - 2) * 2 + crashDist + math.random() * 1.5
                    candidates[#candidates + 1] = { col = c, row = r, score = score }
                end
            end
        end
    end
    if #candidates == 0 then return nil end
    table.sort(candidates, function(a, b) return a.score < b.score end)
    return candidates[1]
end

--- Count wall crashes and drop a tactical ice block every few edge crashes.
---@param state table
---@param Battle table
---@param crashCol integer
---@param crashRow integer
---@return boolean dropped
function IceMechanic.RecordWallCrashAndMaybeDrop(state, Battle, crashCol, crashRow)
    state.iceWallCrashCount = (state.iceWallCrashCount or 0) + 1
    local remain = ICE_BLOCK_DROP_THRESHOLD - state.iceWallCrashCount
    if remain > 0 then
        Battle.AddLog(state, string.format("🧊 撞边让冰层松动了，再撞%d次会掉落大冰块。", remain))
        return false
    end

    state.iceWallCrashCount = 0
    local cell = FindIceBlockDropCell(state, crashCol, crashRow)
    if not cell then
        Battle.AddLog(state, "🧊 冰层松动了，但棋盘上没有可掉落冰块的位置。")
        return false
    end

    HexGrid.AddObstacle(state.board, cell.col, cell.row, "ice_block")
    Battle.AddVFX(state, "spawn_puff", { col = cell.col, row = cell.row, duration = 0.55 })
    Battle.AddVFX(state, "ice_crash", { col = cell.col, row = cell.row, duration = 0.45, power = 2 })
    Battle.AddFloatingText(state, cell.col, cell.row,
        "大冰块掉落!", {160, 230, 255, 255}, "combo", 1.0)
    Battle.AddLog(state, string.format("🧊 连续撞边震落大冰块！它落在(%d,%d)，可以推动成炮弹清线。", cell.col, cell.row))
    AM.PlaySFX("ice_crash", 0.75, 1.18)
    return true
end

-- ============================================================================
-- Slide Mechanic
-- ============================================================================

--- Calculate the cube direction from one hex to another.
--- If not on an exact hex line, finds the closest valid 6-direction.
---@return integer|nil, integer|nil, integer|nil
local function GetCubeDirection(fromCol, fromRow, toCol, toRow)
    local fx, fy, fz = HexGrid.OffsetToCube(fromCol, fromRow)
    local tx, ty, tz = HexGrid.OffsetToCube(toCol, toRow)
    local dx, dy, dz = tx - fx, ty - fy, tz - fz
    local dist = math.max(math.abs(dx), math.abs(dy), math.abs(dz))
    if dist == 0 then return nil end
    -- Normalize to unit direction
    local ux = math.floor(dx / dist + 0.5)
    local uy = math.floor(dy / dist + 0.5)
    local uz = math.floor(dz / dist + 0.5)
    -- Try exact match first
    for _, d in ipairs(CUBE_DIRS) do
        if d[1] == ux and d[2] == uy and d[3] == uz then
            return ux, uy, uz
        end
    end
    -- Fallback: find the closest valid direction by dot product
    local bestDot = -999
    local bestDir = nil
    for _, d in ipairs(CUBE_DIRS) do
        local dot = d[1] * dx + d[2] * dy + d[3] * dz
        if dot > bestDot then
            bestDot = dot
            bestDir = d
        end
    end
    if bestDir and bestDot > 0 then
        return bestDir[1], bestDir[2], bestDir[3]
    end
    return nil
end

--- Calculate slide result: given a landing position and jump direction,
--- determine where the hero ends up after sliding on ice.
---@param state table
---@param landCol integer landing position col
---@param landRow integer landing position row
---@param fromCol integer position before jump (to determine direction)
---@param fromRow integer position before jump
---@return table|nil {col, row, hitEnemy, slideDistance} or nil if no slide
function IceMechanic.CalcSlide(state, landCol, landRow, fromCol, fromRow)
    -- Only slide if landing on ice
    if not IceMechanic.IsIceTile(state, landCol, landRow) then
        return nil
    end

    -- Determine slide direction from jump trajectory
    local dx, dy, dz = GetCubeDirection(fromCol, fromRow, landCol, landRow)
    if not dx then return nil end

    -- Slide along direction until hitting non-ice / obstacle / enemy / boundary
    local board = state.board
    local cx, cy, cz = HexGrid.OffsetToCube(landCol, landRow)
    local slideDistance = 0
    local finalCol, finalRow = landCol, landRow
    local slidePath = {}
    local hitEnemy = nil
    local hitWall = false      -- 撞边界
    local hitObstacle = false  -- 撞障碍物
    local hitObstacleObj = nil
    local hitObstacleCol = nil
    local hitObstacleRow = nil

    for step = 1, 20 do  -- safety limit
        local nx, ny, nz = cx + dx, cy + dy, cz + dz
        local nc, nr = HexGrid.CubeToOffset(nx, ny, nz)

        -- Out of bounds → stop, hero takes damage
        if not HexGrid.InBounds(nc, nr) then
            hitWall = true
            break
        end

        -- Hit obstacle → stop. Ice block becomes a projectile; other obstacles damage hero.
        local obstacle = HexGrid.GetObstacleAt(board, nc, nr)
        if obstacle then
            hitObstacle = true
            hitObstacleObj = obstacle
            hitObstacleCol = nc
            hitObstacleRow = nr
            break
        end

        -- Hit enemy → stop here and秒杀小怪；Boss 仍作为撞击目标处理
        -- 注意：必须在 HexGrid.IsBlocked 前检查敌人，因为 IsBlocked 会把单位也视为阻挡。
        local piece = HexGrid.GetPieceAt(board, nc, nr)
        if piece and piece.team == "enemy" and piece.hp > 0 then
            hitEnemy = piece
            slidePath[#slidePath + 1] = { col = nc, row = nr }
            slideDistance = slideDistance + 1
            finalCol, finalRow = nc, nr
            break
        end

        if HexGrid.IsBlocked(board, nc, nr) then
            hitObstacle = true
            break
        end

        -- Move to this tile
        finalCol, finalRow = nc, nr
        slideDistance = slideDistance + 1
        slidePath[#slidePath + 1] = { col = nc, row = nr }
        cx, cy, cz = nx, ny, nz

        -- If next tile is NOT ice, stop here
        if not IceMechanic.IsIceTile(state, nc, nr) then
            break
        end
    end

    -- 必须实际滑动了至少1格才算触发滑行。
    -- 例外：落点正前方紧贴冰块时，也允许撞飞冰块炮弹。
    if slideDistance == 0 and not (hitObstacleObj and hitObstacleObj.type == "ice_block") then
        return nil
    end

    return {
        col = finalCol,
        row = finalRow,
        hitEnemy = hitEnemy,
        hitWall = hitWall,
        hitObstacle = hitObstacle,
        hitObstacleObj = hitObstacleObj,
        hitObstacleCol = hitObstacleCol,
        hitObstacleRow = hitObstacleRow,
        dirX = dx,
        dirY = dy,
        dirZ = dz,
        slideDistance = slideDistance,
        slidePath = slidePath,
    }
end

--- Launch an ice block as a projectile after the hero slides into or pushes it.
--- The projectile clears every non-boss enemy on the whole line; bosses only take chip damage.
---@param state table
---@param Battle table
---@param result table
---@return boolean handled
local function LaunchIceBlock(state, Battle, result)
    local obstacle = result.hitObstacleObj
    if not obstacle or obstacle.type ~= "ice_block" then return false end
    local col, row = result.hitObstacleCol, result.hitObstacleRow
    if not col or not row or not result.dirX then return false end

    HexGrid.RemoveObstacle(state.board, col, row)

    local cx, cy, cz = HexGrid.OffsetToCube(col, row)
    local victims = {}
    local bossHit = nil
    local lastCol, lastRow = col, row
    for step = 1, 20 do
        local nx = cx + result.dirX * step
        local ny = cy + result.dirY * step
        local nz = cz + result.dirZ * step
        local nc, nr = HexGrid.CubeToOffset(nx, ny, nz)
        if not HexGrid.InBounds(nc, nr) then break end
        if HexGrid.GetObstacleAt(state.board, nc, nr) then break end
        lastCol, lastRow = nc, nr
        local piece = HexGrid.GetPieceAt(state.board, nc, nr)
        if piece and piece.team == "enemy" and piece.hp > 0 then
            if piece.isBoss then
                bossHit = piece
                break
            else
                victims[#victims + 1] = piece
            end
        end
    end

    Battle.AddVFX(state, "ice_block_projectile", {
        fromCol = col, fromRow = row,
        toCol = lastCol, toRow = lastRow,
        duration = 0.42,
        power = math.max(1, HexGrid.CubeDistance(col, row, lastCol, lastRow)),
    })

    if #victims > 0 then
        for _, enemy in ipairs(victims) do
            if enemy.hp > 0 then
                -- 蓄怒冰熊：冰块击中不秒杀，而是+怒气+受伤
                if enemy.rageable then
                    enemy._bearRage = (enemy._bearRage or 0) + 1
                    local iceDmg = math.max(10, math.floor(enemy.maxHp * 0.2))
                    enemy.hp = enemy.hp - iceDmg
                    enemy.hitFlash = 0.25
                    state.totalDamage = (state.totalDamage or 0) + iceDmg
                    Battle.AddFloatingText(state, enemy.col, enemy.row,
                        "🧊-" .. iceDmg .. " 💢+" .. enemy._bearRage, {255, 180, 80, 255}, "hit", 0.9)
                    Battle.AddVFX(state, "ice_crash", { col = enemy.col, row = enemy.row, duration = 0.4, power = 2 })
                    if enemy.hp <= 0 then
                        Battle.HandleEnemyDeath(state, enemy, false)
                    end
                else
                    local killDmg = enemy.hp
                    enemy.hp = 0
                    enemy.hitFlash = 0.25
                    state.totalDamage = (state.totalDamage or 0) + killDmg
                    Battle.AddFloatingText(state, enemy.col, enemy.row,
                        "🧊击碎!", {160, 230, 255, 255}, "hit", 0.9)
                    Battle.AddVFX(state, "ice_crash", { col = enemy.col, row = enemy.row, duration = 0.45, power = 3 })
                    Battle.HandleEnemyDeath(state, enemy, false)
                end
            end
        end
        Battle.AddLog(state, string.format("🧊 大冰块像炮弹一样飞出，清掉一整线%d只小怪！", #victims))
        AM.PlaySFX("ice_crash", 1.0, 1.02)
        state.screenShake = (state.screenShake or 0) + math.min(0.45, 0.18 + #victims * 0.08)
    elseif bossHit then
        local hero = state.hero
        local dmg = math.max(18, math.floor((hero.atk or 0) * 0.8))
        Battle.ApplyBossDamage(state, bossHit, dmg)
        state.totalDamage = (state.totalDamage or 0) + dmg
        bossHit.hitFlash = 0.25
        Battle.AddFloatingText(state, bossHit.col, bossHit.row,
            "🧊-" .. dmg, {160, 230, 255, 255}, "hit")
        Battle.AddVFX(state, "ice_crash", { col = bossHit.col, row = bossHit.row, duration = 0.5, power = 4 })
        Battle.AddLog(state, string.format("🧊 冰块砸到%s，造成%d伤害！", bossHit.name or "Boss", dmg))
        AM.PlaySFX("ice_crash", 0.95, 0.95)
        state.screenShake = (state.screenShake or 0) + 0.28
    else
        Battle.AddFloatingText(state, col, row,
            "🧊飞出!", {160, 230, 255, 255}, "combo", 0.8)
        Battle.AddLog(state, "🧊 冰块被推出去，但这一线没有小怪。")
        AM.PlaySFX("ice_slide", 0.7, 1.15)
    end
    return true
end

--- Push an adjacent ice block as a line-clearing projectile.
---@param state table
---@param Battle table
---@param blockCol integer
---@param blockRow integer
---@param fromCol integer
---@param fromRow integer
---@return boolean
function IceMechanic.PushIceBlock(state, Battle, blockCol, blockRow, fromCol, fromRow)
    local obstacle = HexGrid.GetObstacleAt(state.board, blockCol, blockRow)
    if not obstacle or obstacle.type ~= "ice_block" then return false end
    local dx, dy, dz = GetCubeDirection(fromCol, fromRow, blockCol, blockRow)
    if not dx then return false end

    Battle.AddFloatingText(state, blockCol, blockRow,
        "推冰块!", {160, 230, 255, 255}, "combo", 0.8)
    Battle.AddLog(state, string.format("🐧 推动冰块，从(%d,%d)发射！", blockCol, blockRow))
    return LaunchIceBlock(state, Battle, {
        hitObstacleObj = obstacle,
        hitObstacleCol = blockCol,
        hitObstacleRow = blockRow,
        dirX = dx, dirY = dy, dirZ = dz,
        slideDistance = 0,
    })
end

-- 滑行撞墙/撞障碍伤害：滑得越远，撞击越重，但整体保持为可承受的风险。
-- 1格=轻微擦伤；长距离失控仍然危险，但不会过早打空血量。
local SLIDE_CRASH_BASE_DAMAGE = 1
local SLIDE_CRASH_DAMAGE_PER_TILE = 1

--- Calculate hero crash damage from slide distance.
---@param slideDistance integer
---@return integer
local function CalcCrashDamage(slideDistance)
    local dist = math.max(1, slideDistance or 1)
    return SLIDE_CRASH_BASE_DAMAGE + dist * SLIDE_CRASH_DAMAGE_PER_TILE
end

--- Execute the slide: move hero, deal collision damage, play effects.
--- Called from Battle.ExecuteJump after landing on ice.
---@param state table
---@param Battle table Battle module reference (for AddFloatingText etc.)
---@param landCol integer original landing col
---@param landRow integer original landing row
---@param fromCol integer pre-jump position col
---@param fromRow integer pre-jump position row
---@return boolean slid Whether a slide actually occurred
function IceMechanic.ApplySlide(state, Battle, landCol, landRow, fromCol, fromRow)
    local result = IceMechanic.CalcSlide(state, landCol, landRow, fromCol, fromRow)
    if not result then return false end

    local hero = state.hero

    -- Move hero to slide endpoint (with standard animation fields that BoardWidget reads)
    hero.animFromCol = landCol
    hero.animFromRow = landRow
    hero.animTimer = 0.35 + result.slideDistance * 0.12  -- 滑行慢一些，有过程感
    hero.animMaxTimer = hero.animTimer
    hero.animIsJump = false  -- 线性滑行，不要跳跃弧线
    hero.isSliding = true     -- 标记滑行状态（用于显示企鹅精灵）
    hero.col = result.col
    hero.row = result.row

    -- 滑行路径上的道具会被顺路拾取，不需要最终停在道具格上
    if result.slidePath then
        for _, cell in ipairs(result.slidePath) do
            Battle.CheckItemPickup(state, cell.col, cell.row)
        end
    end

    -- Collision damage: hit enemy → 延迟到滑行动画结束后执行秒杀/伤害
    -- （避免动画还没播到位就已经把怪杀了）
    if result.hitEnemy then
        state._pendingSlideKill = {
            enemy = result.hitEnemy,
            slideDistance = result.slideDistance,
            heroAtk = hero.atk,
        }
    end

    -- Ice block projectile: hit obstacle becomes a cannonball instead of hurting hero
    local launchedIceBlock = false
    if result.hitObstacle then
        launchedIceBlock = LaunchIceBlock(state, Battle, result)
    end

    -- Collision damage: hit wall/normal obstacle → hero takes damage (延迟到滑行结束后)
    if result.hitWall or (result.hitObstacle and not launchedIceBlock) then
        local crashDistance = math.max(1, result.slideDistance or 0)
        local crashDamage = CalcCrashDamage(crashDistance)
        state._pendingCrash = {
            damage = crashDamage,
            slideDistance = crashDistance,
            col = result.col, row = result.row,
            isWall = result.hitWall,
        }
    end

    -- Effects
    Battle.AddVFX(state, "ice_slide", {
        fromCol = landCol, fromRow = landRow,
        toCol = result.col, toRow = result.row,
        duration = hero.animTimer or 0.4,
    })
    if result.slideDistance > 0 then
        Battle.AddFloatingText(state, landCol, landRow,
            "🐧滑行!", {180, 230, 255, 255}, "combo", 0.6)
    end
    local slidePitch = 1.35 - math.min(result.slideDistance or 1, 7) * 0.08
    slidePitch = math.max(0.72, slidePitch)
    local slideGain = math.min(1.05, 0.55 + (result.slideDistance or 1) * 0.08)
    AM.PlaySFX("ice_slide", slideGain, slidePitch)

    return true
end

return IceMechanic
