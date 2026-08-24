import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

async function run() {

// The WeChat preview packager parses every JavaScript file in this workspace,
// including tests. Avoid import.meta here because its classic-script sandbox
// rejects that syntax even though this test module is never executed in-game.
const root = new URL('../', pathToFileURL(process.argv[1]));
const game = await readFile(new URL('game.js', root), 'utf8');
const config = await readFile(new URL('src/vfx/VfxTestConfig.js', root), 'utf8');
const comboDirector = await readFile(new URL('src/vfx/ComboRewardDirector.js', root), 'utf8');
const candidate = await readFile(new URL('vfx-review/MeleeImpactCandidate.js', root), 'utf8');
const damageCandidate = await readFile(new URL('vfx-review/DamageNumberCandidate.js', root), 'utf8');
const hitCandidate = await readFile(new URL('vfx-review/HitReactionCandidate.js', root), 'utf8');
const dartRewardCandidate = await readFile(new URL('vfx-review/TrackingDartRewardCandidate.js', root), 'utf8');
const scarecrowModelCandidate = await readFile(new URL('src/game/ScarecrowModel.js', root), 'utf8');
const scarecrowRewardCandidate = await readFile(new URL('vfx-review/ScarecrowRewardCandidate.js', root), 'utf8');
const hexBlastCandidate = await readFile(new URL('src/vfx/combos/HexBlastEffect.js', root), 'utf8');
const lifeDrainCandidate = await readFile(new URL('src/vfx/combos/LifeDrainEffect.js', root), 'utf8');
const timeStopCandidate = await readFile(new URL('src/vfx/combos/TimeStopEffect.js', root), 'utf8');
const meteorCandidate = await readFile(new URL('src/vfx/combos/MeteorAoeEffect.js', root), 'utf8');
const reflectCandidate = await readFile(new URL('src/vfx/combos/AbsoluteReflectEffect.js', root), 'utf8');
const dartReviewMain = await readFile(new URL('vfx-review/main.js', root), 'utf8');
const reviewMain = await readFile(new URL('vfx-review/scarecrow-main.js', root), 'utf8');
const hexBlastMain = await readFile(new URL('vfx-review/hex-blast-main.js', root), 'utf8');
const lifeDrainMain = await readFile(new URL('vfx-review/life-drain-main.js', root), 'utf8');
const timeStopMain = await readFile(new URL('vfx-review/time-stop-main.js', root), 'utf8');
const meteorMain = await readFile(new URL('vfx-review/meteor-aoe-main.js', root), 'utf8');
const reflectMain = await readFile(new URL('vfx-review/absolute-reflect-main.js', root), 'utf8');
const feedbackMain = await readFile(new URL('vfx-review/feedback-main.js', root), 'utf8');
const reviewRouter = await readFile(new URL('vfx-review/review-router.js', root), 'utf8');
const reviewHtml = await readFile(new URL('vfx-review/index.html', root), 'utf8');
const reviewStyles = await readFile(new URL('vfx-review/styles.css', root), 'utf8');

assert.equal(reviewRouter.includes('await import(effect.module)'), false,
  '本地验收路由不得使用会阻断微信预览沙箱的顶层 await');
assert.equal(game.includes('MeleeImpactCandidate'), false, '候选特效不得被正式游戏直接引用');
assert.match(config, /'hero_melee_impact'[\s\S]*'enemy_damage_number'[\s\S]*'hero_hit_reaction'[\s\S]*'tracking_shuriken'/,
  '正式特效白名单必须包含全部已验收反馈与二连飞镖');
assert.match(comboDirector, /HexBlastEffect[\s\S]*LifeDrainEffect[\s\S]*TimeStopEffect[\s\S]*MeteorAoeEffect[\s\S]*AbsoluteReflectShieldEffect/,
  '正式战斗必须通过统一调度器复用已验收的四至八连特效');
assert.match(candidate, /ReviewOnly_MeleeImpactCandidateA/, '候选特效必须保留本地验收标记');
assert.equal(candidate.includes('RingGeometry'), false, '近战命中候选不得退化为圆环或半圆表现');
assert.equal(game.includes('DamageNumberCandidate'), false, '伤害数字候选不得在验收前被正式游戏引用');
assert.match(damageCandidate, /ReviewOnly_DamageNumberCandidateB/, '伤害数字候选必须保留本地验收标记');
assert.equal(damageCandidate.includes('strokeText'), false, '伤害数字候选不得使用黑色描边');
assert.match(damageCandidate, /sprite\.scale\.set\(1\.45 \* scale, 0\.725 \* scale, 1\)/,
  '伤害数字应使用验收后的放大尺寸');
assert.match(reviewMain, /new THREE\.Vector3\(0, 21\.85, 11\.25\)/, '验收台必须使用正式战斗镜头方向');
assert.match(reviewMain, /FORMAL_BATTLE_VIEW_WIDTH = 12\.3/, '验收台必须使用正式战斗镜头宽度');
assert.match(reviewMain, /FORMAL_BATTLE_ZOOM = 1\.45/, '验收台必须使用正式战斗默认缩放');
assert.match(reviewStyles, /aspect-ratio:\s*430\s*\/\s*932/, '验收台中央画面必须固定为 430×932 手机竖屏比例');
assert.match(reviewStyles, /width:\s*min\(100vw, calc\(100dvh \* 430 \/ 932\)\)/,
  '在手机屏幕上打开时，验收画面必须按真实竖屏比例铺满可用区域');
assert.equal(reviewMain.includes("canvas.addEventListener('pointerdown'"), false, '验收台不得允许旋转镜头');
assert.equal(reviewMain.includes("canvas.addEventListener('wheel'"), false, '验收台不得允许缩放镜头');
assert.match(dartReviewMain, /start: axialToWorld\(-2, 1\)[\s\S]*first: axialToWorld\(-1, 0\)[\s\S]*second: axialToWorld\(0, 0\)/,
  '二连奖励验收必须先完整演示两次跳跃，且三个落点都在棋盘格中心');
assert.match(dartReviewMain, /const enemyCell = axialToWorld\(2, -1\)/,
  '飞镖目标必须固定在棋盘格中心');
assert.equal(game.includes('HitReactionCandidate'), false, '受击反馈候选不得在验收前被正式游戏引用');
assert.match(hitCandidate, /ReviewOnly_HitReactionCandidateI/, '受击反馈候选必须保留本地验收标记');
assert.match(hitCandidate, /contactSnap[\s\S]*bodyStagger[\s\S]*recoveryStep[\s\S]*settle/,
  '受击反馈必须包含接触、踉跄、补步和回稳四个层次');
assert.match(hitCandidate, /headLag[\s\S]*freeArmFlail[\s\S]*rearFootSlip/,
  '主角受击的头、空闲鳍肢和脚必须错峰响应');
assert.match(hitCandidate, /sideDirection/, '受击位移不能只有直线后仰，必须有轻微侧向失衡');
assert.match(hitCandidate, /this\.mount\.position\.y = this\.basePosition\.y;/,
  '主角受击时整体高度必须锁定，不能跳起');
assert.match(hitCandidate, /this\.rig\.position\.y = 0;/,
  '主角受击时必须取消待机呼吸带来的竖直位移');
assert.equal(/Ankle\.position\.y\s*\+=/.test(hitCandidate), false,
  '主角受击时双脚不得抬离棋盘');
assert.equal(/rig\.scale\.y\s*\*=/.test(hitCandidate), false,
  '主角受击时不得通过纵向缩放制造腾空错觉');
assert.equal(/this\.rig\.rotation\.[xz]\s*\+=/.test(hitCandidate), false,
  '主角受击时不得旋转整套骨架导致脚底离地');
assert.equal(/tail\.rotation/.test(hitCandidate), false,
  '主角受击时尾巴不得主动摆动');
assert.match(hitCandidate, /ReviewOnly_GroundedUpperBodyPivot/,
  '主角受击倾倒必须使用独立的贴地上半身支点');
assert.match(hitCandidate, /bodyPivot\.rotation\.x = -contactSnap \* 0\.2 - bodyStagger \* 0\.14/,
  '上半身倾倒幅度必须清晰可读');
assert.equal(hitCandidate.includes('sword.rotation'), false, '主角受击时不得主动挥剑');
assert.equal(hitCandidate.includes("playAction?.('hit'"), false, '候选受击不得复用整只模型摇晃的旧动作');
assert.equal(game.includes('TrackingDartRewardCandidate'), false,
  '完整飞镖奖励候选不得在验收前被正式游戏引用');
assert.match(dartRewardCandidate, /ReviewOnly_TrackingDartRewardCandidateA/,
  '追踪飞镖奖励必须保留本地验收标记');
assert.match(dartRewardCandidate, /createTrackingDart/,
  '二连奖励必须使用金属手里剑模型，而不是通用能量弹');
assert.equal(dartRewardCandidate.includes('RingGeometry'), false,
  '追踪飞镖不得使用与投射意图无关的扩散圆环');
assert.equal(dartRewardCandidate.includes('impactCutGeometry'), false,
  '飞镖命中不得使用容易读成攻击刀光的交叉切痕');
assert.match(dartRewardCandidate, /BoxGeometry\(0\.025, 0\.18, 0\.025\)[\s\S]*TrackingDartDirectionalSparks/,
  '命中反馈必须使用从接触点反向散开的细长金属火星');
assert.match(dartRewardCandidate, /TrackingDartWarmContactLight/,
  '命中瞬间必须给目标一个短促暖色接触闪光');
assert.match(dartRewardCandidate, /effect\.dart\.visible = false;/,
  '飞镖命中后必须立即消失，不能停在敌人体内造成穿模');
assert.match(dartRewardCandidate, /TRACKING_DART_ENEMY_CONTACT_OFFSET = 0\.62/,
  '本地验收飞镖必须推进到敌人身体外壳，让刀刃明确进入身体轮廓');
assert.match(dartRewardCandidate, /addScaledVector\(incoming, -TRACKING_DART_ENEMY_CONTACT_OFFSET\)/,
  '本地验收飞镖必须沿飞行方向推进命中点，不能停在敌人眼前');
assert.match(game, /TRACKING_DART_ENEMY_CONTACT_OFFSET = 0\.62/,
  '正式游戏必须与本地验收使用同一个深入身体外壳的命中距离');
assert.match(game, /addScaledVector\(launchDirection, -TRACKING_DART_ENEMY_CONTACT_OFFSET\)/,
  '正式游戏飞镖必须在敌人身体外壳区域结算，不能停在模型前方');
assert.match(game, /label\.position\.copy\(labelPosition\)\.sub\(position\)/,
  '接触点外移后，伤害数字仍须锚定敌人中心上方');
assert.match(dartRewardCandidate, /mode === 'heal'/,
  '无敌人或道具时必须演示飞镖回旋回血兜底');
assert.match(dartRewardCandidate, /rotor\.rotation\.z \+= delta \* 8\.5/,
  '飞行旋转必须保持在能看清四刃轮廓的速度');
assert.match(dartRewardCandidate, /const flightStart = 0;[\s\S]*const travelEnd = 0\.48;[\s\S]*const flightEnd = 0\.6;/,
  '飞镖必须按原版节奏立即发射、0.48 秒到达并在 0.6 秒结算');
assert.match(game, /test\.effect === 'dart'[\s\S]*launchTrackingDart\(heroCenter, targetPoints\[0\], 0\.6,/,
  '游戏内特效测试入口必须与正式二连和原版统一为 0.6 秒');
assert.match(dartRewardCandidate, /easeOutQuad/,
  '飞镖必须按原版使用起步快、落点慢的 ease-out 运动曲线');
assert.equal(dartRewardCandidate.includes('const ready ='), false,
  '飞镖不得保留原版不存在的生成前摇');
assert.match(dartReviewMain, /addScaledVector\(launchDirection, 0\.86\)/,
  '飞镖必须在企鹅身前生成，不能从身体内部穿模飞出');
assert.equal(dartRewardCandidate.includes('TwoComboRewardAnnouncement'), false,
  '棋盘三维场景内不得显示连击文字或奖励名称');
assert.match(dartReviewMain, /data-scenario|querySelectorAll\('\[data-scenario\]'\)/,
  '验收台必须可切换敌人、道具和无目标三种基础机制场景');
assert.match(dartReviewMain, /const jumpWindows = \[/,
  '验收台必须在飞镖奖励前演示完整二连跳');
assert.equal(game.includes('ScarecrowRewardCandidate'), false,
  '三连稻草人候选不得在验收前被正式游戏直接引用');
assert.match(scarecrowModelCandidate, /ComboScarecrowApprovedModel/,
  '验收后的稻草人模型必须进入正式运行时资产');
assert.match(scarecrowModelCandidate, /ScarecrowCrossWood[\s\S]*ScarecrowStrawHandLeft[\s\S]*ScarecrowBurlapHead/,
  '稻草人必须具有远景可读的十字木架、草束手和麻布头轮廓');
assert.match(scarecrowModelCandidate, /ScarecrowExposedGroundStake/,
  '稻草人衣摆下必须露出插地木桩，不能读成普通人形单位');
assert.match(scarecrowModelCandidate, /ScarecrowButtonEyeLeft[\s\S]*ScarecrowStitchedMouth/,
  '稻草人脸部必须具备清晰的纽扣眼和缝线嘴');
assert.match(scarecrowModelCandidate, /\[1, 1, 0\.42\][\s\S]*ScarecrowFloppyHatBrim/,
  '帽檐前后宽度必须收窄，不能在高机位下遮住整张脸');
assert.match(scarecrowModelCandidate, /hatRig\.position\.set\(0, 0\.245, 0\.08\)/,
  '帽檐必须扣在麻布头顶并向镜头侧贴合，不能悬在脑袋后方');
assert.match(scarecrowModelCandidate, /visual\.rotation\.set\(-0\.34, 0, breeze\)/,
  '稻草人必须朝锁定的高位战斗镜头展示脸部，不能只留下俯视轮廓');
assert.match(scarecrowModelCandidate, /const coat = material\(0xc39a54[\s\S]*const patch = material\(0x9b7846[\s\S]*const hatBand = material\(0xb38b4d/,
  '稻草人的衣服、补丁和帽带必须统一为低饱和稻草与麻布色系');
assert.equal(scarecrowModelCandidate.includes('0xad5044'), false,
  '稻草人不得保留抢眼的红色外衣');
assert.equal(scarecrowModelCandidate.includes('0x31756e'), false,
  '稻草人不得保留与稻草主题无关的青色补丁');
assert.match(reviewMain, /createScarecrowModelCandidate/,
  '三连验收台必须使用新版独立稻草人模型，不能提前修改正式游戏模型');
assert.match(scarecrowRewardCandidate, /ReviewOnly_ScarecrowRewardCandidateA/,
  '三连稻草人必须保留本地验收标记');
assert.match(scarecrowRewardCandidate, /ScarecrowWorldLockedHealthBar/,
  '稻草人作为友军必须显示独立血条');
assert.match(scarecrowRewardCandidate, /healthRoot\.quaternion\.copy\(this\.camera\.quaternion\)/,
  '稻草人血条必须固定面向游戏镜头');
assert.match(scarecrowRewardCandidate, /this\.hp \/ this\.maxHp[\s\S]*fillPivot\.scale\.x/,
  '稻草人血条必须随实际剩余生命实时缩短');
assert.match(scarecrowRewardCandidate, /baseY \+ 2\.68/,
  '稻草人血条必须锁定棋盘锚点，不能跟随受击动作晃动');
assert.match(reviewRouter, /独立的友军绿色血条/,
  '三连验收说明必须明确稻草人是有可见生命值的友军');
assert.match(scarecrowRewardCandidate, /ScarecrowSolidTauntLine/,
  '所有敌人必须用清晰的实线指向稻草人');
assert.match(scarecrowRewardCandidate, /CylinderGeometry\(0\.019, 0\.019, length, 6\)[\s\S]*color: 0xff3f50/,
  '稻草人攻击指向线必须具备手机画面可读的亮红实线线芯');
assert.match(scarecrowRewardCandidate, /ScarecrowSolidTauntGlow/,
  '攻击指向线必须使用轻量外发光提高辨识度，不能只靠加粗线芯');
assert.match(scarecrowRewardCandidate, /depthWrite: false, depthTest: false/,
  '攻击指向线必须作为战斗提示显示在棋盘上方，不能被场景深度遮挡');
assert.match(scarecrowRewardCandidate, /scenario === 'endure'[\s\S]*scenario === 'break'/,
  '验收台必须覆盖持续承伤与生命耗尽两种生命状态');
assert.equal(scarecrowRewardCandidate.includes("finish('expire')"), false,
  '新版稻草人不得再按固定回合数自动消散');
assert.match(scarecrowRewardCandidate, /faceToward\(entry\.mount, target\)/,
  '敌人必须在自己的行动开始时才转向稻草人');
assert.match(reviewMain, /start: axialToWorld\(-3, 0\)[\s\S]*first: axialToWorld\(-1, 0\)[\s\S]*second: axialToWorld\(-1, 2\)[\s\S]*third: axialToWorld\(0, 0\)/,
  '三连奖励验收必须先完整演示三次跳跃');
assert.match(reviewRouter, /popupSmall: '3 连击奖励'[\s\S]*popupStrong: '稻草人'/,
  '三连奖励信息只能出现在棋盘上方的界面弹窗');
assert.equal(game.includes('HexBlastRewardCandidate'), false,
  '四连六芒冲击波候选不得在验收前被正式游戏直接引用');
assert.match(hexBlastCandidate, /ComboReward_HexBlastEffect/,
  '四连六芒冲击波必须进入正式运行时特效');
assert.equal(hexBlastCandidate.includes('RingGeometry'), false,
  '六芒冲击波不得退化成与六方向语义不符的普通圆环');
assert.match(hexBlastCandidate, /FourComboCenterHexagram[\s\S]*FourComboAxisBeam/,
  '四连效果必须同时具备中心六芒标记和六条轴向射线');
assert.match(hexBlastCandidate, /FourComboEdgeFeatherGlow[\s\S]*FourComboEdgeFeatherBody[\s\S]*FourComboEdgeFeatherCore/,
  '六条射线必须使用分层锥形余光柔化棋盘边缘的终点');
assert.match(hexBlastCandidate, /FourComboDirectionalFadeMaterial[\s\S]*vLongitudinalFade[\s\S]*uOpacity \* feather/,
  '边缘余光必须沿射出方向连续衰减透明度，不能只靠几何缩尖伪装渐隐');
assert.match(hexBlastCandidate, /featherStart:?[\s\S]*edgeFadeLength[\s\S]*visualLength: length \+ edgeFadeLength/,
  '视觉光束必须在棋盘边缘前开始收束并略微延伸到边缘之外');
assert.match(hexBlastCandidate, /terminalHeadFade[\s\S]*headMaterial\.opacity = fade \* 0\.92 \* terminalHeadFade/,
  '波头抵达余光末端时必须完全淡出，不能留下突兀的亮点');
assert.match(hexBlastCandidate, /FourComboPathCell_/,
  '六条射线经过的棋盘格必须逐格点亮，清楚表达实际判定路径');
assert.equal(hexBlastCandidate.includes('hitTime: 0.62'), false,
  '六芒冲击波不得使用与目标距离无关的固定伤害延时');
assert.match(hexBlastCandidate, /resolveImpactContact[\s\S]*contactDistance[\s\S]*impact\.beam\.currentLength >= impact\.contactDistance/,
  '伤害结算必须在对应方向的波头接触目标模型外缘时立即触发');
assert.match(hexBlastCandidate, /impact\.hitAt = this\.effect\.elapsed[\s\S]*elapsed - impact\.hitAt/,
  '每个目标的受击演出必须从自身实际接触帧独立计时');
assert.match(hexBlastCandidate, /target\.kind === 'boss' \? '-60' : '秒杀'/,
  '小怪秒杀与 Boss 固定 60 伤害必须使用不同结果反馈');
assert.match(hexBlastCandidate, /entry\.mount\.visible = false/,
  '路径上的普通小怪必须在命中反馈后明确被击毁');
assert.match(hexBlastMain, /start: axialToWorld\(-2, 0\)[\s\S]*first: axialToWorld\(0, -2\)[\s\S]*second: axialToWorld\(2, -2\)[\s\S]*third: axialToWorld\(2, 0\)[\s\S]*fourth: axialToWorld\(0, 0\)/,
  '四连奖励验收必须先完整演示四次合法长跳并落在棋盘中心');
assert.match(hexBlastMain, /rewardCastStart = rewardStart - rewardCastLead[\s\S]*playAction\?\.\('hex_blast_cast', rewardCastDuration \/ playbackSpeed\)/,
  '企鹅必须在六芒冲击波出现前先进入专用的落地蓄力动作');
assert.equal(hexBlastMain.includes('rewardCastFacingStart'), false,
  '四连施法必须保留最后一次跳跃的真实朝向，不能刻意转向观众');
assert.match(hexBlastMain, /const CUBE_DIRECTIONS = \[[\s\S]*\[1, 0\][\s\S]*\[1, -1\][\s\S]*\[0, -1\][\s\S]*\[-1, 0\][\s\S]*\[-1, 1\][\s\S]*\[0, 1\]/,
  '六芒冲击波必须严格使用六角棋盘的六个轴向');
assert.match(hexBlastMain, /scenario === 'boss'[\s\S]*scenario === 'path'/,
  '验收台必须覆盖 Boss 固伤和轴线外目标不受伤两种关键分支');
assert.match(hexBlastMain, /FORMAL_BATTLE_VIEW_WIDTH = 12\.3[\s\S]*FORMAL_BATTLE_ZOOM = 1\.45[\s\S]*new THREE\.Vector3\(0, 21\.85, 11\.25\)/,
  '四连验收必须使用锁定的正式战斗镜头');
assert.match(reviewRouter, /popupSmall: '4 连击奖励'[\s\S]*popupStrong: '六芒冲击波'/,
  '四连奖励信息只能出现在棋盘上方的界面弹窗');
assert.equal(game.includes('LifeDrainRewardCandidate'), false,
  '五连生命虹吸候选不得在验收前被正式游戏直接引用');
assert.match(lifeDrainCandidate, /ComboReward_LifeDrainEffect/,
  '五连生命虹吸必须进入正式运行时特效');
assert.match(lifeDrainCandidate, /CubicBezierCurve3[\s\S]*FiveComboLifeDrainTether[\s\S]*FiveComboLifeDroplet/,
  '生命能量必须沿可读弧线从敌人流向企鹅，并使用移动液滴强调方向');
assert.match(lifeDrainCandidate, /FiveComboLifeExtractionFlash[\s\S]*FiveComboAbsorptionSpark/,
  '敌人生命抽离与企鹅吸收必须具有不同的起点和终点反馈');
assert.match(lifeDrainCandidate, /FiveComboReceptionStreak[\s\S]*trailProgress[\s\S]*towardCenter/,
  '企鹅身边的生命能量必须以错峰细长碎片向身体收拢，不能组成规律旋转的太阳图案');
assert.equal(lifeDrainCandidate.includes('const orbit ='), false,
  '生命虹吸汇聚阶段不得保留中心大球加外围环绕粒子的太阳系结构');
assert.match(lifeDrainCandidate, /FiveComboHealingBloom[\s\S]*bloomProgress = clamp01\(shieldLocal \/ 0\.86\)[\s\S]*visible = shieldLocal < 0\.88[\s\S]*material\.opacity = bloomEnvelope \* 0\.78/,
  '治疗结算瞬间必须以柔和的纵向绿色光晕强化生命恢复，且不能退回太阳状结构');
assert.match(lifeDrainCandidate, /target\.kind === 'boss' \? 116 : 108[\s\S]*target\.kind === 'boss' \? 1\.58 : 1\.42/,
  '五连生命抽取的敌方伤害数字必须在手机战斗视角下保持足够醒目');
assert.match(lifeDrainCandidate, /FiveComboPersistentShieldFresnel[\s\S]*FiveComboPersistentShieldShell[\s\S]*uOpacity/,
  '溢出治疗必须生成贴合角色、具有柔和边缘光的持续护盾，而不是线框笼子');
assert.match(lifeDrainCandidate, /float alpha = \(0\.12 \+ fresnel \* 0\.46\) \* uOpacity \* formationMask[\s\S]*uOpacity\.value = formation \* \(0\.42/,
  '只要仍有护盾值，企鹅身上就必须保留清晰可见的半透明绿色护盾遮罩');
assert.equal(/shieldMaterial\.uniforms\.uOpacity\.value[^;]*fade/.test(lifeDrainCandidate), false,
  '持续护盾遮罩不得跟随生命虹吸的一次性粒子淡出');
assert.match(lifeDrainCandidate, /reception\.firstArrival != null[\s\S]*uFormation\.value = formation[\s\S]*uArrivalPulse\.value = pulse[\s\S]*reception\.finalArrival != null/,
  '护盾必须从第一股生命能量抵达时连续展开，并对每次能量汇入产生同源亮度反馈');
assert.match(lifeDrainCandidate, /\? 0\.14 \+ easeOutCubic[\s\S]*\? 0\.24 \* \(1 - formation \* 0\.78\)/,
  '第一股能量接触时必须立即点亮护盾中部，并压低独立实心吸收球的存在感');
assert.match(lifeDrainCandidate, /FiveComboShieldValueBadge[\s\S]*outcome\.shieldTotal[\s\S]*shieldBadge\.material\.opacity = badgePop/,
  '生命虹吸结束后必须在企鹅头顶持续显示当前护盾总值');
assert.equal(lifeDrainCandidate.includes('盾+${outcome.shieldAdded}'), false,
  '护盾反馈不得把本次增加值误当成持续护盾状态');
assert.equal(lifeDrainCandidate.includes('wireframe: true'), false,
  '持续护盾不得退回廉价的线框多面体表现');
assert.match(lifeDrainCandidate, /uInnerColor: \{ value: new THREE\.Color\(0x5debac\)[\s\S]*tetherGlowMaterial = additiveMaterial\(0x42d995[\s\S]*tetherMaterial = additiveMaterial\(0xa3ffd2/,
  '吸取线、生命液滴、吸收和护盾必须统一使用淡绿色治疗语义');
assert.match(lifeDrainMain, /definition\.kind === 'boss' \? 30 : Math\.max\(5, Math\.floor\(definition\.hp \* 0\.2\)\)/,
  '五连必须严格执行普通敌人当前生命20%且最低5、Boss固定30的原版规则');
assert.match(lifeDrainMain, /Math\.min\(totalDrain, missingHp\)[\s\S]*Math\.min\(overflow, Math\.max\(0, 60 - shieldBefore\)\)/,
  '总抽取量必须先治疗缺失生命，溢出部分再转为最多60点虹吸护盾');
assert.match(lifeDrainMain, /const shieldTotal = shieldBefore \+ shieldAdded[\s\S]*shieldTotal, shieldFull: shieldTotal >= 60/,
  '头顶护盾标记必须读取当前护盾总值，而不是只读取本次增加量');
assert.match(lifeDrainMain, /start: axialToWorld\(0, 0\)[\s\S]*first: axialToWorld\(2, 0\)[\s\S]*second: axialToWorld\(2, -2\)[\s\S]*third: axialToWorld\(0, -2\)[\s\S]*fourth: axialToWorld\(-2, 0\)[\s\S]*fifth: axialToWorld\(0, 0\)/,
  '五连奖励验收必须先完整演示五次合法长跳并回到棋盘中心');
assert.match(lifeDrainMain, /playAction\?\.\('life_drain_cast', rewardCastDuration \/ playbackSpeed\)/,
  '企鹅必须在生命虹吸出现前播放专用吸取施法动作');
assert.match(lifeDrainMain, /scenario === 'heal'[\s\S]*scenario === 'overflow'[\s\S]*scenario === 'cap'/,
  '验收台必须覆盖生命治疗、溢出护盾和护盾上限三种关键分支');
assert.match(lifeDrainMain, /FORMAL_BATTLE_VIEW_WIDTH = 12\.3[\s\S]*FORMAL_BATTLE_ZOOM = 1\.45[\s\S]*new THREE\.Vector3\(0, 21\.85, 11\.25\)/,
  '五连验收必须使用锁定的正式战斗镜头');
assert.equal(game.includes('TimeStopRewardCandidate'), false,
  '六连时间静止候选不得在验收前被正式游戏直接引用');
assert.match(timeStopCandidate, /ComboReward_TimeStopEffect/,
  '六连时间静止必须进入正式运行时特效');
assert.match(timeStopCandidate, /SixComboTemporalClockSigil[\s\S]*SixComboBoardWideTemporalField[\s\S]*SixComboExpandingTimeFrontCore/,
  '六连必须通过中央时钟与全场扩张时间前沿表达时间静止，而不是普通伤害爆炸');
assert.match(timeStopCandidate, /SixComboBoardPerimeterClock[\s\S]*romanNumerals = \['XII', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI'\][\s\S]*SixComboBoardRomanNumeral/,
  '冻结期间棋盘必须出现完整且可读的十二个罗马数字时标');
assert.match(timeStopCandidate, /SixComboBoardRomanRadialAnchor[\s\S]*radialAnchor\.rotation\.y = -angle/,
  '十二个罗马数字的顶部必须沿钟面径向朝向棋盘外缘');
assert.match(timeStopCandidate, /turnPulseTimes = \[1\.48, 2\.48\][\s\S]*perimeterPulse[\s\S]*marker\.scale\.setScalar/,
  '罗马数字必须与两次外环回合脉冲同步闪烁和呼吸放大');
assert.match(timeStopCandidate, /0\.22 \+ perimeterPulse \* 0\.74/,
  '罗马数字静止期与脉冲峰值必须保留足够明显的浓淡对比');
assert.equal(timeStopCandidate.includes('SixComboBoardClockTick'), false,
  '棋盘外围不得混用旧短刻度与罗马数字时标');
assert.equal(timeStopCandidate.includes('SixComboBoardMinuteHand'), false,
  '棋盘不得保留尴尬的大型分针');
assert.equal(timeStopCandidate.includes('SixComboBoardHourHand'), false,
  '棋盘不得保留尴尬的大型时针');
assert.match(timeStopCandidate, /clockSample = elapsed < 0\.82[\s\S]*elapsed < 3\.82 \? 0\.82/,
  '时间场持续期间时钟指针必须真正停止，不能只在敌人身上叠加蓝色罩子');
assert.match(timeStopCandidate, /SixComboBoardSuspendedTimeMote[\s\S]*SixComboEnemySuspendedTimeMote/,
  '棋盘和敌人周围必须具有被定格在空中的运动粒子');
assert.match(timeStopCandidate, /SixComboPersistentStasisShell[\s\S]*SixComboTwoTurnStatusMarker[\s\S]*const pips = \[-0\.12, 0\.12\]/,
  '每个被冻结敌人必须具有持续停滞罩和两个回合状态刻度');
assert.match(timeStopCandidate, /target\.entry\.frozen = true[\s\S]*elapsed >= 3\.82[\s\S]*target\.entry\.frozen = false/,
  '敌人必须在时间波接触后立即冻结，并在两个敌方阶段演出结束后统一恢复');
assert.match(timeStopCandidate, /const turnPulses = \[0, 1\][\s\S]*SixComboEnemyTurnLockPulse\$\{index \+ 1\}/,
  '全场时间场必须以两个明确脉冲反馈两个被跳过的敌方阶段');
assert.match(timeStopMain, /start: axialToWorld\(-2, 0\)[\s\S]*first: axialToWorld\(-2, 2\)[\s\S]*second: axialToWorld\(0, 2\)[\s\S]*third: axialToWorld\(2, 0\)[\s\S]*fourth: axialToWorld\(2, -2\)[\s\S]*fifth: axialToWorld\(0, -2\)[\s\S]*sixth: axialToWorld\(0, 0\)/,
  '六连奖励验收必须先完整演示六次合法长跳并回到棋盘中心');
assert.match(timeStopMain, /applyTimeStopCastPose[\s\S]*leftShoulder\.rotation[\s\S]*rightShoulder\.rotation[\s\S]*sword\.rotation/,
  '企鹅时间静止施法必须真实驱动双臂和剑，不能仅缩放整个模型');
assert.match(timeStopMain, /closedPose[\s\S]*stopPose[\s\S]*leftShoulder\.rotation\.z = closedPose \* 1\.24 - stopPose \* 1\.45[\s\S]*rightShoulder\.rotation\.z = -closedPose \* 0\.9 \+ stopPose \* 1\.12/,
  '六连动作必须使用交叉收紧后双臂展开的停止姿势，不能复用前几连的施法动作');
assert.match(timeStopMain, /entry\.active && !entry\.frozen/,
  '冻结期间必须停止敌人模型动画，而不是只叠加蓝色外壳');
assert.match(timeStopMain, /activeTargets\.forEach[\s\S]*playAction\?\.\('attack'/,
  '时间波必须将敌人截停在行动姿势中，不能只冻结普通待机状态');
assert.match(timeStopMain, /scenario === 'boss'[\s\S]*actors\.boss/,
  '验收台必须包含 Boss 同样被冻结的场景');
assert.match(timeStopMain, /FORMAL_BATTLE_VIEW_WIDTH = 12\.3[\s\S]*FORMAL_BATTLE_ZOOM = 1\.45[\s\S]*new THREE\.Vector3\(0, 21\.85, 11\.25\)/,
  '六连验收必须使用锁定的正式战斗镜头');

assert.equal(game.includes('MeteorAoeRewardCandidate'), false,
  '七连流星候选不得在验收前被正式游戏引用');
assert.match(meteorCandidate, /ComboReward_MeteorAoeEffect/,
  '七连流星火雨必须进入正式运行时特效');
assert.match(meteorCandidate, /SevenComboMeteorShower[\s\S]*SevenComboSmallMeteor/,
  '七连必须使用多颗小型流星组成近乎同时坠落的火雨');
assert.match(meteorCandidate, /SevenComboMeteorRockWithMoltenCracks[\s\S]*SevenComboSmallMeteorRockCore/,
  '每颗小流星必须保留暗色岩芯与熔岩裂纹，不能读成纯白光滴');
assert.match(meteorCandidate, /SevenComboSmallMeteorOuterFlameTail[\s\S]*SevenComboSmallMeteorInnerFlameTail/,
  '每颗小流星必须使用外焰和内焰组成的分层短火尾');
assert.match(meteorCandidate, /const boardMeteorOffsets = \[[\s\S]*const meteors = boardMeteorOffsets\.map/,
  '七连必须使用固定棋盘落点生成十二颗流星，不能按敌人位置生成追踪流星');
assert.equal(meteorCandidate.includes('target.entry.mount.position.clone().setY'), false,
  '流星视觉落点不得绑定到小怪头顶');
assert.match(meteorCandidate, /const hitTime = 0\.58 \+ \(index % 8\) \* 0\.016/,
  '十二颗小流星的落点必须压缩在极短窗口内，形成同屏火雨而不是零散单发');
assert.equal(meteorCandidate.includes('SevenComboFallingMeteor'), false,
  '七连不得退回占据大半屏幕的单颗巨型流星');
assert.match(meteorCandidate, /SevenComboMeteorShowerAoeFlash/,
  '七连流星火雨必须保留一次全场 AOE 结算提示');
assert.equal(meteorCandidate.includes('SevenComboMeteorShowerAoeWave'), false,
  '七连不得使用抢夺流星雨视觉重点的巨大中央圆环');
assert.match(meteorCandidate, /SevenComboMeteorShowerDamageNumber/,
  '七连每个目标必须只显示一次清晰的伤害数字');
assert.match(meteorCandidate, /SevenComboSmallMeteorImpactFlame/,
  '每颗小型流星的落点必须具有短促火焰爆发，不能只留下锁定圈');
assert.match(meteorCandidate, /SevenComboMeteorShowerBoardGlow[\s\S]*SevenComboMeteorShowerImpactLight/,
  '七连落地必须同时具备柔和全盘暖光和短促动态光照');
assert.match(meteorCandidate, /SevenComboMeteorShowerBatchedRadialEmbers[\s\S]*length: 32/,
  '七连落地后必须有足够的径向余烬延续冲击，不能只闪一下就结束');
assert.match(meteorCandidate, /THREE\.PointsMaterial[\s\S]*SevenComboSmallMeteorBatchedImpactFragments/,
  '每个落点的火星碎屑必须使用批量点粒子渲染，不能在命中帧激活大量独立绘制对象');
assert.match(meteorCandidate, /createTargetDamageFeedback[\s\S]*damageFeedbacks = targets\.map[\s\S]*damageFired = true[\s\S]*effect\.damageFeedbacks\.forEach/,
  '所有小怪必须在独立的统一 AOE 层结算一次伤害，不能依赖流星是否砸中模型');
assert.match(meteorCandidate, /rumbleStart[\s\S]*this\.camera\.position\.x[\s\S]*this\.camera\.position\.copy\(this\.effect\.cameraPosition\)/,
  '七连触地必须产生短促镜头震动并在清理时恢复锁定镜头');
assert.match(meteorCandidate, /slamShakeDuration = 0\.36[\s\S]*slamEnvelope = attack \* decay[\s\S]*Math\.PI \* 9/,
  '企鹅拍地的命中帧必须触发独立的短促屏幕冲击，并使用平滑起止避免镜头抽动');
assert.match(meteorCandidate, /core\.castShadow = false/,
  '全盘视觉流星不得开启实时阴影，避免屏幕震动期间重复增加阴影渲染压力');
assert.match(meteorCandidate, /prepare\(payload\)[\s\S]*warmup\(renderer\)[\s\S]*renderer\.compile[\s\S]*activate\(\)/,
  '七连资源必须在演出开始前创建并预编译，触发帧只能激活现成对象');
assert.match(meteorCandidate, /new THREE\.WebGLRenderTarget\(4, 4[\s\S]*renderer\.render\(this\.scene, this\.camera\)/,
  '七连资源必须先离屏预渲染一次，确保纹理和几何数据在正式触发前已上传显卡');
assert.equal(/burnDuration|damageOverTime|SevenComboBurning/.test(meteorCandidate), false,
  '七连必须保持纯粹的一次 AOE 伤害，不附加燃烧或持续伤害');
assert.match(meteorMain, /start: axialToWorld\(-2, 0\)[\s\S]*first: axialToWorld\(-2, 2\)[\s\S]*second: axialToWorld\(0, 2\)[\s\S]*third: axialToWorld\(2, 0\)[\s\S]*fourth: axialToWorld\(2, -2\)[\s\S]*fifth: axialToWorld\(0, -2\)[\s\S]*sixth: axialToWorld\(-2, 0\)[\s\S]*seventh: axialToWorld\(0, 0\)/,
  '七连奖励验收必须完整演示七次合法长跳并落在棋盘中心');
assert.match(meteorMain, /applyMeteorCastPose\(model, castMount, progress\)[\s\S]*jumpLift[\s\S]*castMount\.position\.y = 0\.15 \+ jumpLift/,
  '七连奖励必须让企鹅真实离开棋盘起跳，不能只摆动四肢伪装腾空');
assert.match(meteorMain, /const dive[\s\S]*const slamPose[\s\S]*const strikePose[\s\S]*rightShoulder\.rotation\.z[\s\S]*strikePose \* 1\.22/,
  '企鹅必须在滞空后明确向棋盘拍下，不能只做普通举剑动作');
assert.match(meteorMain, /slamPose = dive \* \(1 - THREE\.MathUtils\.smoothstep\(progress, 0\.66, 0\.71\)\)/,
  '企鹅身体必须在接触棋盘时快速回正，不能保持俯冲姿势趴在地上');
assert.match(meteorMain, /jumpLocal = clamp01\(\(progress - 0\.08\) \/ 0\.62\)/,
  '企鹅落地时点必须与七连流星集中命中保持同步');
assert.match(meteorMain, /rewardCastStart = 2\.72[\s\S]*rewardStart = 3\.3[\s\S]*rewardCastDuration = 1\.78/,
  '七连流星火雨必须保留约 0.58 秒的大招起跳前摇，并让完整腾空动作有足够重量感');
assert.match(meteorMain, /reward\.prepare\([\s\S]*reward\.warmup\(renderer\)[\s\S]*reward\.activate\(\)/,
  '七连验收台必须在整段演出开始前预热资源，不能在举剑与火雨之间临时创建');
assert.match(meteorMain, /meteorTransitionMaxFrameGap[\s\S]*sequenceElapsed >= 2\.55[\s\S]*transitionFrameGapMax/,
  '七连本地验收台必须记录举剑到落地阶段的最大帧间隔，便于验证中段卡顿是否消失');
assert.match(meteorMain, /FORMAL_BATTLE_VIEW_WIDTH = 12\.3[\s\S]*FORMAL_BATTLE_ZOOM = 1\.45[\s\S]*new THREE\.Vector3\(0, 21\.85, 11\.25\)/,
  '七连验收必须使用锁定的正式战斗镜头');
assert.match(reviewRouter, /meteor:[\s\S]*COMBO-07[\s\S]*meteor-aoe-main\.js/,
  '本地验收路由必须提供七连天降火球入口');
assert.match(reviewHtml, /data-effect="meteor"[\s\S]*option value="meteor"/,
  '桌面队列与手机下拉框必须都能打开七连验收页');
assert.equal(game.includes('AbsoluteReflectRewardCandidate'), false,
  '八连绝对反射候选不得在验收前被正式游戏引用');
assert.match(reflectCandidate, /ComboReward_PersistentAbsoluteReflectShield/,
  '八连绝对反射必须进入正式运行时并由持续护盾承载');
assert.match(reflectCandidate, /EightComboAbsoluteReflectFresnel[\s\S]*EightComboReflectiveFresnelShell[\s\S]*EightComboAssembledMirrorPlate/,
  '八连必须使用贴身菲涅尔护罩和组装镜片，不能退化为普通圆形光波');
assert.match(reflectCandidate, /const sparkleCount = 28[\s\S]*THREE\.PointsMaterial[\s\S]*EightComboBatchedGoldenShieldSparkles/,
  '八连金色闪光必须合并为一批粒子渲染，不能生成大量独立物件拖慢微信小游戏');
assert.match(reflectCandidate, /sparkles\.items\.forEach[\s\S]*contactEnergy[\s\S]*phaseDone[\s\S]*positionAttribute\.needsUpdate = true/,
  '金色粒子必须在攻击接触时增亮外扩，并在第四回合结束时随护罩散开');
assert.match(reflectCandidate, /launchEnemyAttack[\s\S]*playAction\?\.\('attack'/,
  '绝对反射期间敌人必须照常执行攻击，不能与六连时间静止重复');
assert.match(reflectCandidate, /reflectAttack[\s\S]*color\.setHex\(0xfff3bd\)[\s\S]*returnEnd/,
  '敌方攻击接触护罩后必须变为金白色并原路折返');
assert.match(reflectCandidate, /hitAttacker[\s\S]*playAction\?\.\('hit'/,
  '反射攻击返回攻击者时必须立即触发敌方受击动作');
assert.match(reflectCandidate, /createDamageSprite\(`-\$\{target\.damage\}`\)/,
  '反射伤害数字必须与该次敌方攻击的原伤害完全相同');
assert.equal(reflectCandidate.includes("effect.hero.model.userData.playAction?.('hit'"), false,
  '绝对反射期间企鹅伤害必须归零，不得播放主角受击动作');
assert.match(reflectCandidate, /enemyPhaseIndex \* 1\.25[\s\S]*const enemyPhaseCount = 4[\s\S]*Array\.from\(\{ length: enemyPhaseCount \}/,
  '八连必须实际生成四个完整敌方回合的反射演示，不能只修改说明文字');
assert.match(reflectCandidate, /reflectedEnemyPhases[\s\S]*expired_after_four_enemy_phases/,
  '镜面护罩必须在第四个完整敌方回合处理完毕后才消失');
assert.match(reflectMain, /start: axialToWorld\(-2, 0\)[\s\S]*first: axialToWorld\(-2, 2\)[\s\S]*second: axialToWorld\(0, 2\)[\s\S]*third: axialToWorld\(2, 0\)[\s\S]*fourth: axialToWorld\(2, -2\)[\s\S]*fifth: axialToWorld\(0, -2\)[\s\S]*sixth: axialToWorld\(-2, 0\)[\s\S]*seventh: axialToWorld\(0, -2\)[\s\S]*eighth: axialToWorld\(0, 0\)/,
  '八连奖励验收必须完整演示八次合法长跳并落在棋盘中心');
assert.match(reflectMain, /applyAbsoluteReflectGuardPose[\s\S]*both arms stay outside the torso silhouette[\s\S]*leftShoulder\.position\.x -=[\s\S]*rightShoulder\.position\.x \+=[\s\S]*sword\.rotation/,
  '企鹅开盾时双臂必须位于身体外轮廓，不能藏进躯干或护罩后方');
assert.match(reflectMain, /FORMAL_BATTLE_VIEW_WIDTH = 12\.3[\s\S]*FORMAL_BATTLE_ZOOM = 1\.45[\s\S]*new THREE\.Vector3\(0, 21\.85, 11\.25\)/,
  '八连验收必须使用锁定的正式战斗镜头');
assert.match(reviewRouter, /reflect:[\s\S]*COMBO-08[\s\S]*absolute-reflect-main\.js/,
  '本地验收路由必须提供八连绝对反射入口');
assert.match(reviewHtml, /data-effect="reflect"[\s\S]*option value="reflect"/,
  '桌面队列与手机下拉框必须都能打开八连验收页');
assert.match(reviewRouter, /popupSmall: '6 连击奖励'[\s\S]*popupStrong: '时间静止'/,
  '六连奖励信息只能出现在棋盘上方的界面弹窗');
assert.match(reviewHtml, /class="combo-popup"[\s\S]*5 连击奖励[\s\S]*生命虹吸/,
  '五连奖励信息只能出现在棋盘上方的界面弹窗');
assert.match(reviewHtml, /id="effect-select"[\s\S]*攻击命中[\s\S]*伤害数字[\s\S]*主角受击[\s\S]*二连·追踪飞镖[\s\S]*三连·稻草人[\s\S]*四连·六芒冲击波[\s\S]*五连·生命虹吸[\s\S]*六连·时间静止/,
  '手机验收台必须提供八项已制作特效的统一选择入口');
assert.match(reviewHtml, /data-effect="impact"[\s\S]*data-effect="damage"[\s\S]*data-effect="hit"[\s\S]*data-effect="dart"[\s\S]*data-effect="scarecrow"[\s\S]*data-effect="hexblast"[\s\S]*data-effect="lifedrain"[\s\S]*data-effect="timestop"/,
  '桌面验收队列中的八项已制作特效必须可以点击切换');
assert.match(reviewRouter, /import\(effect\.module\)/,
  '统一验收入口必须按选择加载对应演示，不能把全部场景叠在同一个画布');
assert.match(feedbackMain, /MeleeImpactCandidate[\s\S]*DamageNumberCandidate[\s\S]*HitReactionCandidate/,
  '基础反馈入口必须能分别播放攻击命中、伤害数字和主角受击');

console.log('vfx local approval gate tests passed');
}

run();
