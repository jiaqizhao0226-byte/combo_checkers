const EFFECTS = {
  impact: {
    name: '攻击命中', code: 'VFX-01', status: '已验收并接入', module: './feedback-main.js?v=20260821a',
    popupSmall: '基础战斗反馈', popupStrong: '攻击命中',
    hint: '企鹅挥剑接触敌人的瞬间，方向刀痕、接触闪光和碎片同时出现',
    scenarios: [['normal', '普通命中'], ['heavy', '重击命中']],
    title: '攻击命中<br>接触方向',
    summary: '命中特效只负责强化武器与目标发生接触的瞬间，形状必须跟随攻击方向，不能读成无意义的圆环。',
    criteria: [
      ['方向', '刀痕沿挥砍方向出现，而不是围绕角色扩散'],
      ['接触', '闪光严格落在敌人身体表面'],
      ['层次', '亮芯、暖色外沿和短促碎片同时出现'],
      ['时长', '整体快速结束，不遮挡下一步操作'],
    ],
    timeline: ['挥剑', '命中', '消散'],
    gate: '这一项已经验收并接入正式战斗；本页用于后续复查和对比。',
  },
  damage: {
    name: '伤害数字', code: 'VFX-02', status: '已验收并接入', module: './feedback-main.js?v=20260821a',
    popupSmall: '基础战斗反馈', popupStrong: '伤害数字',
    hint: '数字从目标头顶弹出并上浮，保持高对比但不使用笨重黑色描边',
    scenarios: [['24', '-24'], ['62', '-62'], ['120', '-120']],
    title: '伤害数字<br>远景可读',
    summary: '伤害数字需要在手机画面中一眼可读，同时不能遮住敌人动作，也不能依赖厚重黑边制造对比。',
    criteria: [
      ['位置', '固定从受击目标头顶生成'],
      ['大小', '普通手机距离下仍然清楚'],
      ['层次', '暖色渐变和柔和投影取代黑色描边'],
      ['节奏', '快速弹出、短暂停留、向上淡出'],
    ],
    timeline: ['受击', '弹出', '上浮'],
    gate: '这一项已经验收并接入正式战斗；可在这里切换不同伤害数值复查。',
  },
  hit: {
    name: '主角受击', code: 'VFX-03', status: '已验收并接入', module: './feedback-main.js?v=20260821a',
    popupSmall: '基础战斗反馈', popupStrong: '主角受击',
    hint: '企鹅保持双脚贴地，通过上半身倾倒、侧向失衡和补步表现受击',
    scenarios: [['front', '正面受击'], ['side', '侧面受击']],
    title: '主角受击<br>贴地踉跄',
    summary: '受击动作不是整只模型跳起或缩放，而是接触、倾倒、侧向失衡、补步和回稳组成的短动作。',
    criteria: [
      ['贴地', '企鹅中心和双脚不离开棋盘'],
      ['倾倒', '上半身围绕脚底支点明显后仰'],
      ['四肢', '头、空闲鳍肢和双脚错峰响应'],
      ['武器', '受击时不主动挥剑'],
    ],
    timeline: ['接触', '踉跄', '回稳'],
    gate: '这一项已经验收并接入正式战斗；可分别复查正面和侧面受击。',
  },
  dart: {
    name: '二连·追踪飞镖', code: 'COMBO-02', status: '已验收并接入', module: './main.js?v=20260821u',
    popupSmall: '2 连击奖励', popupStrong: '追踪飞镖',
    hint: '二连完整落地后发射；飞镖从企鹅身前生成并明确切入目标身体轮廓',
    scenarios: [['enemy', '攻击敌人'], ['item', '自动拾取'], ['heal', '无目标回血']],
    title: '二连完成<br>追踪飞镖',
    summary: '二连奖励包含完整跳跃前置、金属手里剑飞行、表面接触、命中反馈，以及没有敌人时的回旋回血兜底。',
    criteria: [
      ['触发', '整条二连跳全部落地后才发射'],
      ['起点', '飞镖从企鹅身体前方生成，不能穿过主角'],
      ['终点', '刀刃明确进入敌人身体轮廓，接触帧后立即消失'],
      ['兜底', '没有敌人和道具时回旋并为企鹅回血'],
    ],
    timeline: ['二连落地', '飞镖飞行', '命中结算'],
    gate: '二连飞镖已经验收并接入正式战斗；本页保留三种基础机制场景。',
  },
  scarecrow: {
    name: '三连·稻草人', code: 'COMBO-03', status: '本轮验收', module: './scarecrow-main.js?v=20260822k',
    popupSmall: '3 连击奖励', popupStrong: '稻草人',
    hint: '三连完成后召唤；敌人只在各自行动时转向稻草人',
    scenarios: [['guard', '嘲讽承伤'], ['endure', '持续承伤'], ['break', '生命耗尽']],
    title: '三连完成<br>全场嘲讽',
    summary: '三连奖励会召唤一个有独立生命值的友军。稻草人出现在企鹅附近空格，承受全场敌人的攻击，生命归零后才消失。',
    criteria: [
      ['触发', '整条三连跳全部落地后才生成稻草人'],
      ['位置', '从企鹅附近空格中选择，不覆盖角色和敌人'],
      ['属性', '复制企鹅最大生命与防御，并显示独立的友军绿色血条'],
      ['嘲讽', '所有敌人的移动和攻击目标都改为稻草人'],
      ['朝向', '敌人只在自己的行动开始时转向'],
      ['结束', '不按回合自动消散，生命耗尽时立即击毁'],
    ],
    timeline: ['三连落地', '召唤嘲讽', '持续承伤'],
    gate: '三连稻草人仍只在本地验收页；确认完整机制后才会开放正式战斗白名单。',
  },
  hexblast: {
    name: '四连·六芒冲击波', code: 'COMBO-04', status: '本轮验收', module: './hex-blast-main.js?v=20260821a',
    popupSmall: '4 连击奖励', popupStrong: '六芒冲击波',
    hint: '四连完整落地后，从企鹅所在格沿六个六角轴向同时扫到棋盘边缘',
    scenarios: [['minions', '小怪秒杀'], ['boss', 'Boss 固伤'], ['path', '路径判定']],
    title: '四连完成<br>六轴贯穿',
    summary: '六芒冲击波不是圆形爆炸。能量从企鹅最终落点沿六条棋盘轴线扫到边缘，只处理射线路径上的敌人。',
    criteria: [
      ['触发', '整条四连跳全部落地后才释放，不在第四跳执行中提前出现'],
      ['方向', '六条射线严格贴合六角棋盘的六个轴向'],
      ['范围', '每条射线一直延伸到当前棋盘边缘，轴线外目标不受影响'],
      ['小怪', '路径上的普通敌人在射线到达后立即秒杀'],
      ['Boss', 'Boss 不被秒杀，只在接触帧承受固定 60 伤害'],
      ['结算', '伤害数字与死亡反馈必须等射线到达，不能先于演出发生'],
    ],
    timeline: ['四连落地', '六轴展开', '路径结算'],
    gate: '四连六芒冲击波当前只在本地验收页；确认六轴方向、路径判定和命中节奏后才会接入正式战斗。',
  },
  lifedrain: {
    name: '五连·生命虹吸', code: 'COMBO-05', status: '本轮验收', module: './life-drain-main.js?v=20260822i',
    popupSmall: '5 连击奖励', popupStrong: '生命虹吸',
    hint: '五连完整落地后，抽取全场所有敌人的生命能量并汇聚到企鹅身上',
    scenarios: [['heal', '生命治疗'], ['overflow', '溢出护盾'], ['cap', '护盾上限']],
    title: '五连完成<br>全场虹吸',
    summary: '生命虹吸不是从企鹅向外扩散。每个敌人都应成为生命能量的起点，红粉色生命流沿弧线加速汇入企鹅，再结算绿色治疗或紫色虹吸护盾。',
    criteria: [
      ['触发', '整条五连跳全部落地后才开始抽取，不在第五跳途中提前出现'],
      ['范围', '无视距离抽取全场所有存活敌人，不能只处理邻近目标'],
      ['小怪', '普通敌人损失当前生命的 20%，不足 5 时按 5 点计算'],
      ['Boss', 'Boss 不按百分比计算，固定损失 30 点生命'],
      ['治疗', '全部抽取量先补足企鹅缺失生命'],
      ['护盾', '溢出治疗转为虹吸护盾，累计上限为 60'],
      ['方向', '能量必须从敌人流向企鹅，不能视觉反向'],
    ],
    timeline: ['五连落地', '全场抽取', '治疗/护盾'],
    gate: '五连生命虹吸当前只在本地验收页；确认全场方向、数字规则和溢出护盾反馈后才会接入正式战斗。',
  },
  timestop: {
    name: '六连·时间静止', code: 'COMBO-06', status: '本轮验收', module: './time-stop-main.js?v=20260822l',
    popupSmall: '6 连击奖励', popupStrong: '时间静止',
    hint: '六连完整落地后展开全场时间场；所有敌人无视类型冻结两个敌方回合',
    scenarios: [['all', '全场冻结'], ['boss', 'Boss 同样冻结'], ['turns', '两回合解除']],
    title: '六连完成<br>全场停滞',
    summary: '六连不再造成普通 AOE 伤害，而是展开覆盖整个棋盘的时间场。棋盘时钟、指针、敌人动作与周围运动粒子会在波接触时同时停住，并跳过接下来两个完整敌方回合。',
    criteria: [
      ['触发', '整条六连跳全部落地后才开始施法'],
      ['动作', '企鹅先将剑和鳍肢交叉收紧，再向两侧猛然展开并定格'],
      ['范围', '时间场覆盖棋盘上的全部存活敌人，不受距离限制'],
      ['对象', '普通敌人与 Boss 都会冻结，不设置免疫'],
      ['时长', '完整跳过两个敌方行动阶段，第三回合开始前解除'],
      ['状态', '大型时钟、静止粒子与两枚持续刻度共同表达时间暂停'],
      ['叠加', '重复触发只刷新持续时间，不累加成四回合'],
    ],
    timeline: ['六连落地', '全场冻结', '两回合后解除'],
    gate: '六连时间静止当前只在本地验收页；确认施法动作、冻结可读性和解除节奏后才会接入正式战斗。',
  },
  meteor: {
    name: '七连·流星火雨', code: 'COMBO-07', status: '本轮验收', module: './meteor-aoe-main.js?v=20260823f',
    popupSmall: '7 连击奖励', popupStrong: '流星火雨',
    hint: '七连完整落地后召唤一批小型流星高速砸向棋盘；全场敌人只结算一次伤害',
    scenarios: [['all', '全场伤害'], ['crowd', '密集敌群'], ['boss', 'Boss 受击']],
    title: '七连完成<br>流星火雨',
    summary: '七连只触发一次纯粹的全场伤害。一批结构简单的小型流星近乎同时高速砸向棋盘，通过密集落点、火焰碎片和连续短震让所有敌人受到一次高额伤害。',
    criteria: [
      ['触发', '整条七连跳全部落地后才召唤流星火雨'],
      ['形式', '多颗小型流星近乎同时落下，每颗只保留亮核、短尾焰与小型落点爆炸'],
      ['范围', '无视敌人位置，对棋盘上的全部存活敌人造成伤害'],
      ['结算', '流星数量不代表伤害段数，每个敌人只受击一次并只出现一个伤害数字'],
      ['冲击', '密集落点期间连续短震，统一伤害结算时震感稍强'],
      ['纯粹', '不附加燃烧、控制、斩杀或其他持续状态'],
    ],
    timeline: ['七连落地', '流星火雨', '全场受击'],
    gate: '七连流星火雨当前只在本地验收页；确认流星密度、坠落速度和震动强度后才会接入正式战斗。',
  },
  reflect: {
    name: '八连·绝对反射', code: 'COMBO-08', status: '本轮验收', module: './absolute-reflect-main.js?v=20260824i',
    popupSmall: '8 连击奖励', popupStrong: '绝对反射',
    hint: '八连完整落地后展开金色镜面护罩；连续四个敌方回合的全部攻击归零并原路反射',
    scenarios: [['volley', '多敌齐射'], ['boss', 'Boss 重击'], ['pressure', '高压连击']],
    title: '八连完成<br>绝对反射',
    summary: '绝对反射不是时间静止或普通护盾。敌人仍会连续执行四个完整回合，但这四个敌方回合里所有打向企鹅的攻击都会在镜面护罩上归零，并把相同数值的伤害原路反射给攻击者。',
    criteria: [
      ['触发', '整条八连跳全部落地后才展开金色镜面护罩'],
      ['动作', '企鹅双脚站稳，空闲鳍肢向左前撑开、持剑手向右外展，双臂轮廓都清晰可见'],
      ['时长', '效果覆盖连续四个完整敌方回合，不因单个敌人行动结束而消失'],
      ['敌人', '敌人照常转向并发动攻击，不会像六连时间静止一样跳过行动'],
      ['免伤', '所有打向企鹅的伤害在接触镜面护罩时归零'],
      ['反射', '同一枚攻击变色并原路折返，对攻击者造成等额伤害'],
      ['粒子', '金色微光沿护罩持续闪烁，攻击接触时增亮外扩，解除时随护罩散开'],
      ['结束', '第四个敌方回合的全部攻击处理完毕后，护罩才自然解体并消失'],
    ],
    timeline: ['八连落地', '四回合反射', '第四回合后解除'],
    gate: '八连绝对反射当前只在本地验收页；确认四回合持续时间、护罩质感和折返可读性后才会接入正式战斗。',
  },
};

const params = new URLSearchParams(location.search);
const legacyCandidate = params.get('candidate') || '';
const legacyEffect = legacyCandidate.includes('tracking-dart') ? 'dart'
  : legacyCandidate.includes('damage') ? 'damage'
    : legacyCandidate.includes('hit') ? 'hit'
      : legacyCandidate.includes('impact') ? 'impact'
        : legacyCandidate.includes('scarecrow') ? 'scarecrow'
            : legacyCandidate.includes('hex') ? 'hexblast'
              : legacyCandidate.includes('time') ? 'timestop'
                : legacyCandidate.includes('meteor') ? 'meteor'
                  : legacyCandidate.includes('reflect') ? 'reflect'
                    : 'lifedrain';
const effectId = EFFECTS[params.get('effect')] ? params.get('effect') : legacyEffect;
const effect = EFFECTS[effectId];

document.documentElement.dataset.effect = effectId;
document.title = `Combo Checkers · ${effect.name}验收`;
document.querySelector('.approval-state').innerHTML = `<span></span>${effect.code} · ${effect.status}`;

document.querySelectorAll('[data-effect]').forEach(item => {
  item.classList.toggle('active', item.dataset.effect === effectId);
  const button = item.querySelector('button');
  if (!button || button.disabled) return;
  button.addEventListener('click', () => navigateTo(item.dataset.effect));
});

const picker = document.getElementById('effect-select');
picker.value = effectId;
picker.addEventListener('change', () => navigateTo(picker.value));

function navigateTo(nextEffect) {
  if (!EFFECTS[nextEffect] || nextEffect === effectId) return;
  location.search = new URLSearchParams({ effect: nextEffect }).toString();
}

const popup = document.getElementById('combo-popup');
popup.querySelector('small').textContent = effect.popupSmall;
popup.querySelector('strong').textContent = effect.popupStrong;
document.querySelector('.stage-hint').innerHTML = `<span>GAME CAMERA LOCKED</span>${effect.hint}`;

const scenarioRoot = document.querySelector('.scenario-controls');
scenarioRoot.innerHTML = effect.scenarios.map(([id, label], index) => (
  `<button type="button" data-scenario="${id}" class="${index === 0 ? 'active' : ''}">${label}</button>`
)).join('');

document.getElementById('criteria-code').textContent = effect.code;
document.getElementById('criteria-title').innerHTML = effect.title;
document.getElementById('criteria-summary').textContent = effect.summary;
document.getElementById('criteria-list').innerHTML = effect.criteria.map(([label, text]) => (
  `<li><i></i><span><strong>${label}</strong>${text}</span></li>`
)).join('');
document.getElementById('timeline-labels').innerHTML = effect.timeline.map(label => `<span>${label}</span>`).join('');
document.getElementById('gate-note').textContent = effect.gate;

import(effect.module).catch(error => {
  console.error('[vfx-review] failed to load selected effect', error);
});
