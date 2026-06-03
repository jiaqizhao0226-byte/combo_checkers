-- ============================================================================
-- GuildPage.lua - 公会排行榜页面
-- 展示所有玩家的进度排名（到达关卡、章节、冒险次数）
-- 数据来源：clientCloud  key=highest_level(排序) + total_runs(附加)
-- ============================================================================

local UI = require("urhox-libs/UI")
local Battle = require "Battle"
local AM = require "AudioManager"

local GuildPage = {}

-- ============================================================================
-- 内部工具
-- ============================================================================

--- 关卡号 → "第N章 第M关" 文本
local MAX_CHAPTER = 3  -- 当前游戏最大章节数（第4章为无尽模式），防止旧测试数据显示超出范围的章节

local function LevelToText(level)
    if type(level) ~= "number" then level = tonumber(level) or 1 end
    -- 截断到最大有效关卡，避免旧数据显示"第7章"、"第9章"等不存在的章节
    local maxLevel = MAX_CHAPTER * Battle.LEVELS_PER_CHAPTER
    if level > maxLevel then level = maxLevel end
    -- GetChapterInfo 已保证返回整数，这里 levelInChapter 也用同一来源确保类型安全
    local chapter, levelInChapter = Battle.GetChapterInfo(level)
    if Battle.IsBossLevel(level) then
        return string.format("第%d章 Boss关", chapter)
    end
    return string.format("第%d章 第%d关", chapter, levelInChapter)
end

--- 排名数字 → 特殊徽章或数字
local function RankBadge(rank)
    if rank == 1 then return "🥇" end
    if rank == 2 then return "🥈" end
    if rank == 3 then return "🥉" end
    return tostring(rank)
end

--- 排名颜色
local function RankColor(rank)
    if rank == 1 then return {255, 215, 60,  255} end
    if rank == 2 then return {200, 215, 230, 255} end
    if rank == 3 then return {210, 140, 80,  255} end
    return {160, 165, 190, 220}
end

-- ============================================================================
-- 单行排行榜条目
-- ============================================================================

local function BuildRankRow(rank, nickname, level, runs, isMe)
    local rankColor = RankColor(rank)
    local rowBg = isMe
        and { type = "linear", direction = "to-right",
              from = {80, 60, 140, 80}, to = {50, 35, 100, 60} }
        or  nil
    local rowBorderColor = isMe and {150, 120, 255, 120} or {255, 255, 255, 12}

    return UI.Panel {
        width = "100%", flexDirection = "row",
        alignItems = "center", gap = 8,
        paddingTop = 9, paddingBottom = 9,
        paddingLeft = 12, paddingRight = 12,
        borderRadius = 0,
        backgroundGradient = rowBg,
        borderWidth = isMe and 1 or 0,
        borderColor = rowBorderColor,
        marginBottom = 4,
        children = {
            -- 排名徽章
            UI.Panel {
                width = 32, alignItems = "center",
                children = {
                    UI.Label {
                        text = RankBadge(rank),
                        fontSize = rank <= 3 and 20 or 16,
                        fontWeight = "bold",
                        fontColor = rankColor,
                        textAlign = "center",
                    },
                },
            },
            -- 玩家名
            UI.Panel {
                flexGrow = 1, flexShrink = 1,
                children = {
                    UI.Label {
                        text = (isMe and "▶ " or "") .. (nickname or "玩家"),
                        fontSize = 16,
                        fontWeight = isMe and "bold" or "normal",
                        fontColor = isMe and {200, 180, 255, 255} or {210, 215, 230, 230},
                        numberOfLines = 1, width = "100%",
                    },
                },
            },
            -- 关卡进度
            UI.Panel {
                width = 118, alignItems = "flex-end",
                children = {
                    UI.Label {
                        text = LevelToText(level),
                        fontSize = 14,
                        fontColor = rankColor,
                        textAlign = "right",
                        numberOfLines = 1,
                        width = "100%",
                    },
                },
            },
            -- 把数
            UI.Panel {
                width = 48, alignItems = "flex-end",
                children = {
                    UI.Label {
                        text = tostring(runs or 0) .. "把",
                        fontSize = 14,
                        fontColor = {130, 140, 165, 200},
                        textAlign = "right",
                    },
                },
            },
        },
    }
end

-- ============================================================================
-- 表头
-- ============================================================================

local function BuildHeader()
    return UI.Panel {
        width = "100%", flexDirection = "row",
        alignItems = "center", gap = 8,
        paddingLeft = 12, paddingRight = 12,
        paddingBottom = 6,
        borderBottomWidth = 1, borderColor = {255, 255, 255, 20},
        marginBottom = 4,
        children = {
            UI.Label { text = "名次", fontSize = 13, fontColor = {120, 125, 150, 180}, width = 32, textAlign = "center" },
            UI.Panel { flexGrow = 1, children = {
                UI.Label { text = "玩家", fontSize = 13, fontColor = {120, 125, 150, 180} },
            }},
            UI.Label { text = "最高进度", fontSize = 13, fontColor = {120, 125, 150, 180}, width = 118, textAlign = "right" },
            UI.Label { text = "把数",    fontSize = 13, fontColor = {120, 125, 150, 180}, width = 48, textAlign = "right" },
        },
    }
end

-- ============================================================================
-- 加载状态占位
-- ============================================================================

local function BuildLoadingState(text)
    return UI.Panel {
        width = "100%", alignItems = "center",
        paddingTop = 40, paddingBottom = 40,
        children = {
            UI.Label {
                text = text or "⏳ 加载中...",
                fontSize = 15, fontColor = {140, 145, 170, 200},
            },
        },
    }
end

-- ============================================================================
-- 主构建函数
-- ============================================================================

--- 构建公会排行榜页面
--- @param playerData table 当前玩家存档（用于高亮自己）
--- @param onRefresh function? 刷新回调（重新拉取数据）
function GuildPage.Build(playerData, onRefresh)
    ---@diagnostic disable-next-line: undefined-global
    local myUserId = clientCloud and lobby and lobby:GetMyUserId() or nil
    local myLevel  = playerData and (playerData.highestLevel or 1) or 1
    local myRuns   = playerData and (playerData.totalRuns or 0) or 0

    -- 外层容器（paddingBottom 留底栏空间）
    local children = {}

    -- ---- 页面标题 ----
    children[#children + 1] = UI.Panel {
        width = "100%", flexDirection = "row",
        alignItems = "center", justifyContent = "space-between",
        paddingTop = 8, paddingBottom = 10,
        paddingLeft = 4, paddingRight = 4,
        children = {
            UI.Panel {
                flexDirection = "row", alignItems = "center", gap = 8,
                children = {
                    UI.Panel {
                        width = 4, height = 22, borderRadius = 0,
                        backgroundColor = {140, 100, 255, 255},
                    },
                    UI.Label {
                        text = "公会排行榜",
                        fontSize = 20, fontWeight = "bold",
                        fontColor = {220, 215, 245, 255},
                    },
                },
            },
            -- 刷新按钮
            UI.Panel {
                paddingTop = 5, paddingBottom = 5,
                paddingLeft = 12, paddingRight = 12,
                borderRadius = 0,
                backgroundColor = {255, 255, 255, 12},
                borderWidth = 1, borderColor = {255, 255, 255, 30},
                onClick = function(self)
                    AM.PlaySFX("ui_click")
                    if onRefresh then onRefresh() end
                end,
                children = {
                    UI.Label { text = "🔄 刷新", fontSize = 13, fontColor = {180, 185, 210, 220} },
                },
            },
        },
    }

    -- ---- 我的进度小卡片 ----
    children[#children + 1] = UI.Panel {
        width = "100%",
        backgroundGradient = {
            type = "linear", direction = "to-right",
            from = {60, 45, 110, 200}, to = {40, 28, 80, 200},
        },
        borderRadius = 0,
        borderWidth = 1, borderColor = {130, 100, 220, 100},
        paddingTop = 10, paddingBottom = 10,
        paddingLeft = 14, paddingRight = 14,
        flexDirection = "row", alignItems = "center",
        marginBottom = 12,
        boxShadow = { { x = 0, y = 2, blur = 10, spread = 0, color = {0, 0, 0, 60} } },
        children = {
            UI.Label { text = "👤", fontSize = 20 },
            UI.Panel {
                flexGrow = 1, paddingLeft = 10, gap = 2,
                children = {
                    UI.Label {
                        text = "我的进度",
                        fontSize = 13, fontColor = {170, 160, 210, 200},
                    },
                    UI.Label {
                        text = LevelToText(myLevel),
                        fontSize = 17, fontWeight = "bold",
                        fontColor = {210, 190, 255, 255},
                    },
                },
            },
            UI.Panel {
                alignItems = "flex-end", gap = 2,
                children = {
                    UI.Label {
                        text = "冒险次数",
                        fontSize = 13, fontColor = {160, 160, 185, 180},
                    },
                    UI.Label {
                        text = tostring(myRuns) .. " 把",
                        fontSize = 17, fontWeight = "bold",
                        fontColor = {180, 175, 220, 240},
                    },
                },
            },
        },
    }

    return children
end

--- 构建排行榜列表内容（异步拉取后调用）
--- @param rankData table[{rank,nickname,level,runs,isMe}]
function GuildPage.BuildRankList(rankData)
    local rows = {}
    rows[#rows + 1] = BuildHeader()
    if not rankData or #rankData == 0 then
        rows[#rows + 1] = BuildLoadingState("暂无排行数据，通关关卡后上榜！")
        return rows
    end
    for _, entry in ipairs(rankData) do
        rows[#rows + 1] = BuildRankRow(
            entry.rank, entry.nickname, entry.level, entry.runs, entry.isMe)
    end
    return rows
end

--- 构建加载中占位
function GuildPage.BuildLoading()
    return { BuildLoadingState("⏳ 加载排行榜...") }
end

--- 构建失败占位
--- @param msg string 可选提示文本
function GuildPage.BuildError(msg)
    return { BuildLoadingState(msg or "⚠️ 加载失败，请刷新重试") }
end

-- ============================================================================
-- 无尽模式排行榜
-- ============================================================================

--- 无尽模式单行
local function BuildEndlessRankRow(rank, nickname, wave, isMe)
    local rankColor = RankColor(rank)
    local rowBg = isMe
        and { type = "linear", direction = "to-right",
              from = {80, 40, 140, 80}, to = {50, 20, 110, 60} }
        or  nil
    local rowBorderColor = isMe and {180, 100, 255, 120} or {255, 255, 255, 12}

    return UI.Panel {
        width = "100%", flexDirection = "row",
        alignItems = "center", gap = 8,
        paddingTop = 9, paddingBottom = 9,
        paddingLeft = 12, paddingRight = 12,
        borderRadius = 0,
        backgroundGradient = rowBg,
        borderWidth = isMe and 1 or 0,
        borderColor = rowBorderColor,
        marginBottom = 4,
        children = {
            -- 排名徽章
            UI.Panel {
                width = 32, alignItems = "center",
                children = {
                    UI.Label {
                        text = RankBadge(rank),
                        fontSize = rank <= 3 and 20 or 16,
                        fontWeight = "bold",
                        fontColor = rankColor,
                        textAlign = "center",
                    },
                },
            },
            -- 玩家名
            UI.Panel {
                flexGrow = 1, flexShrink = 1,
                children = {
                    UI.Label {
                        text = (isMe and "▶ " or "") .. (nickname or "玩家"),
                        fontSize = 16,
                        fontWeight = isMe and "bold" or "normal",
                        fontColor = isMe and {210, 170, 255, 255} or {210, 215, 230, 230},
                        numberOfLines = 1, width = "100%",
                    },
                },
            },
            -- 最高波次
            UI.Panel {
                width = 90, alignItems = "flex-end",
                children = {
                    UI.Label {
                        text = wave > 0 and ("第 " .. wave .. " 波") or "未挑战",
                        fontSize = 15, fontWeight = "bold",
                        fontColor = wave > 0 and rankColor or {100, 100, 120, 160},
                        textAlign = "right",
                    },
                },
            },
        },
    }
end

--- 无尽排行表头
local function BuildEndlessHeader()
    return UI.Panel {
        width = "100%", flexDirection = "row",
        alignItems = "center", gap = 8,
        paddingLeft = 12, paddingRight = 12,
        paddingBottom = 6,
        borderBottomWidth = 1, borderColor = {255, 255, 255, 20},
        marginBottom = 4,
        children = {
            UI.Label { text = "名次", fontSize = 13, fontColor = {120, 125, 150, 180}, width = 32, textAlign = "center" },
            UI.Panel { flexGrow = 1, children = {
                UI.Label { text = "玩家", fontSize = 13, fontColor = {120, 125, 150, 180} },
            }},
            UI.Label { text = "最高波次", fontSize = 13, fontColor = {180, 130, 255, 200}, width = 90, textAlign = "right" },
        },
    }
end

--- 我的无尽记录小卡片
--- @param playerData table
function GuildPage.BuildEndlessMyCard(playerData)
    local bestWave = playerData and (playerData.highestEndlessWave or 0) or 0
    local bestText = bestWave > 0 and ("第 " .. bestWave .. " 波") or "尚未挑战"

    return UI.Panel {
        width = "100%",
        backgroundGradient = {
            type = "linear", direction = "to-right",
            from = {60, 25, 110, 200}, to = {35, 15, 80, 200},
        },
        borderRadius = 0,
        borderWidth = 1, borderColor = {160, 80, 255, 100},
        paddingTop = 10, paddingBottom = 10,
        paddingLeft = 14, paddingRight = 14,
        flexDirection = "row", alignItems = "center",
        marginBottom = 12,
        boxShadow = { { x = 0, y = 2, blur = 10, spread = 0, color = {0, 0, 0, 60} } },
        children = {
            UI.Label { text = "🌀", fontSize = 20 },
            UI.Panel {
                flexGrow = 1, paddingLeft = 10, gap = 2,
                children = {
                    UI.Label {
                        text = "我的无尽记录",
                        fontSize = 13, fontColor = {170, 130, 220, 200},
                    },
                    UI.Label {
                        text = bestText,
                        fontSize = 17, fontWeight = "bold",
                        fontColor = bestWave > 0 and {220, 170, 255, 255} or {120, 120, 150, 200},
                    },
                },
            },
        },
    }
end

--- 构建无尽排行榜列表内容（异步拉取后调用）
--- @param rankData table[{rank, nickname, wave, isMe}]
function GuildPage.BuildEndlessRankList(rankData)
    local rows = {}
    rows[#rows + 1] = BuildEndlessHeader()
    if not rankData or #rankData == 0 then
        rows[#rows + 1] = BuildLoadingState("暂无记录，挑战无尽模式后上榜！")
        return rows
    end
    for _, entry in ipairs(rankData) do
        rows[#rows + 1] = BuildEndlessRankRow(
            entry.rank, entry.nickname, entry.wave or 0, entry.isMe)
    end
    return rows
end

return GuildPage
