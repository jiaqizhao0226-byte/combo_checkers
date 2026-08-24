// Development defaults. The release builder replaces this module in the
// staged WeChat package, so production-only paths and flags never interfere
// with the local review workflow.
export const WECHAT_BUILD_PROFILE = Object.freeze({
  name: 'development',
  release: false,
  bgmPaths: Object.freeze({
    menu: 'assets/audio/bgm_menu.ogg',
    battle_calm: 'assets/audio/bgm_battle_calm.ogg',
    battle: 'assets/audio/bgm_battle.ogg',
    boss_abyss: 'assets/audio/bgm_boss_abyss.ogg',
  }),
  sfxPaths: Object.freeze({
    ui_click: 'assets/audio/sfx/ui_click.ogg',
    hero_jump: 'assets/audio/sfx/sfx_hero_jump.ogg',
    attack_hit: 'assets/audio/sfx/sfx_attack_hit.ogg',
    enemy_death: 'assets/audio/sfx/sfx_enemy_death.ogg',
    victory: 'assets/audio/sfx/sfx_victory.ogg',
    defeat: 'assets/audio/sfx/sfx_defeat.ogg',
  }),
  bgmPackages: Object.freeze({}),
  sfxPackages: Object.freeze({}),
});
