-- ============================================================================
-- GameState - 全局共享状态容器
-- 所有模块 require "GameState" 获取同一份 table
-- ============================================================================

local G = {}

-- 战斗状态
G.battle = nil              -- Battle.New 返回的战斗数据
G.validMoves = {}            -- 当前可移动目标
G.validJumps = {}            -- 当前可跳跃目标
G.gridParams = nil           -- 渲染参数

-- 棋盘摄像机
G.BOARD_ZOOM = 1.15          -- 棋盘放大倍率（当前实际值，由动态缩放系统驱动）
G.cameraX = 0
G.cameraY = 0
G.cameraTargetX = 0
G.cameraTargetY = 0
G.CAMERA_LERP_SPEED = 5.0

-- 动态缩放系统
G.ZOOM_IN = 1.45             -- 拉近倍率（手机默认，更大更易操作）
G.ZOOM_OUT = 1.05            -- 拉远倍率
G.zoomTarget = 1.45          -- 目标缩放值
G.zoomCurrent = 1.45         -- 当前缩放值（平滑插值）
G.ZOOM_LERP_SPEED = 3.0      -- 缩放插值速度
G.zoomOutReason = nil         -- 当前拉远原因（调试用）
G.zoomOutCooldown = 0         -- 拉远后保持时间（防止频繁切换）

-- 计时器
G.enemyTurnTimer = 0
G.enemyAnimWait = false
G.enemyTurnMsg = ""
G.executeTimer = 0
G.executeIndex = 0

-- 动画计时
G.time = 0

-- 跳跃规划
G.plannedJumps = {}
G.planHeroCol = 0
G.planHeroRow = 0
G.jumpedEnemySet = {}

-- 威胁预览
G.threatPreview = {}
G.threatTargetCol = 0
G.threatTargetRow = 0

-- 游戏内 UI 引用
G.uiRoot = nil
G.hpLabel = nil
G.comboLabel = nil
G.turnLabel = nil
G.goldLabel = nil
G.logLabel = nil
G.levelLabel = nil
G.skillsLabel = nil
G.shieldIcon = nil
G.btnPanel = nil
G.confirmBtn = nil
G.resultPanel = nil
G.skillModal = nil

-- 技能选择
G.skillChoices = {}

-- 主菜单状态
G.gamePhase = "MENU"         -- "MENU" | "GAME"
G.menuRoot = nil
G.menuTab = "adventure"
G.highestLevel = 1
G.menuHeroBob = 0
G.selectedLevel = 1
G.selectedChapter = 1

-- 持久化数据
G.playerData = nil
G.menuPageContainer = nil
G.menuGoldLabel = nil
G.gachaPopup = nil

-- 装备弹窗 / 拖拽状态
G.itemDetailPopup = nil       -- 装备详情弹窗 overlay
G.dragOverlay = nil           -- 拖拽浮动图标 overlay
G.dragItemIdx = nil           -- 正在拖拽的背包索引
G.dragTargetSlot = nil        -- 拖拽目标槽位 id

-- 菜单 UI 引用（在 CreateMenuUI 中赋值）
G.menuTabButtons = {}
G.menuScrollView = nil
G.menuAdvBottomBar = nil
G.menuHeroArea = nil
G.menuContentSlot = nil

-- 模块间回调注册表（避免循环依赖）
G.callbacks = {}

return G
