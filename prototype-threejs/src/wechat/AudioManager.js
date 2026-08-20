const BGM_PATHS = {
  menu: 'assets/audio/bgm_menu.ogg',
  battle_calm: 'assets/audio/bgm_battle_calm.ogg',
  battle: 'assets/audio/bgm_battle.ogg',
  boss_abyss: 'assets/audio/bgm_boss_abyss.ogg',
};

const SFX_PATHS = {
  ui_click: 'assets/audio/sfx/ui_click.ogg',
  hero_jump: 'assets/audio/sfx/sfx_hero_jump.ogg',
  attack_hit: 'assets/audio/sfx/sfx_attack_hit.ogg',
  enemy_death: 'assets/audio/sfx/sfx_enemy_death.ogg',
  victory: 'assets/audio/sfx/sfx_victory.ogg',
  defeat: 'assets/audio/sfx/sfx_defeat.ogg',
};

const clampVolume = value => Math.max(0, Math.min(1, Math.round((Number(value) || 0) * 20) / 20));

export function createAudioManager(wxApi, stored = {}) {
  const state = {
    bgmVolume: clampVolume(stored.bgmVolume ?? 0.5),
    sfxVolume: clampVolume(stored.sfxVolume ?? 0.8),
    comboSoundStyle: stored.comboSoundStyle === 'classic' ? 'classic' : 'scale',
    currentBgm: stored.currentBgm && BGM_PATHS[stored.currentBgm] ? stored.currentBgm : 'menu',
  };
  let bgm = null;
  let started = false;

  function persist() {
    if (typeof wxApi.setStorageSync === 'function') wxApi.setStorageSync('combo-checkers-audio-settings', { ...state });
  }

  function ensureBgm() {
    if (bgm || typeof wxApi.createInnerAudioContext !== 'function') return bgm;
    bgm = wxApi.createInnerAudioContext();
    bgm.loop = true;
    bgm.obeyMuteSwitch = true;
    bgm.volume = state.bgmVolume * 0.5;
    bgm.src = BGM_PATHS[state.currentBgm];
    if (typeof bgm.onError === 'function') bgm.onError(error => console.warn('[combo-checkers] BGM error', error?.errMsg || error));
    return bgm;
  }

  function playBgm(key = state.currentBgm) {
    if (!BGM_PATHS[key]) return;
    const context = ensureBgm();
    state.currentBgm = key;
    if (!context) { persist(); return; }
    const nextSrc = BGM_PATHS[key];
    if (context.src !== nextSrc) {
      try { context.stop(); } catch {}
      context.src = nextSrc;
    }
    context.volume = state.bgmVolume * 0.5;
    if (state.bgmVolume > 0) {
      try { context.play(); started = true; } catch (error) { console.warn('[combo-checkers] BGM play deferred', error?.message || error); }
    } else {
      try { context.pause(); } catch {}
    }
    persist();
  }

  function unlock() {
    if (!started) playBgm(state.currentBgm);
  }

  function playSfx(key) {
    if (!SFX_PATHS[key] || state.sfxVolume <= 0 || typeof wxApi.createInnerAudioContext !== 'function') return;
    const context = wxApi.createInnerAudioContext();
    context.obeyMuteSwitch = true;
    context.volume = state.sfxVolume;
    context.src = SFX_PATHS[key];
    const destroy = () => { try { context.destroy(); } catch {} };
    if (typeof context.onEnded === 'function') context.onEnded(destroy);
    if (typeof context.onError === 'function') context.onError(destroy);
    try { context.play(); } catch { destroy(); }
  }

  function setBgmVolume(value) {
    state.bgmVolume = clampVolume(value);
    if (bgm) bgm.volume = state.bgmVolume * 0.5;
    if (state.bgmVolume <= 0 && bgm) { try { bgm.pause(); } catch {} }
    else if (started) playBgm(state.currentBgm);
    persist();
  }

  function setSfxVolume(value) { state.sfxVolume = clampVolume(value); persist(); }
  function setComboSoundStyle(value) { state.comboSoundStyle = value === 'classic' ? 'classic' : 'scale'; persist(); }

  return { state, unlock, playBgm, playSfx, setBgmVolume, setSfxVolume, setComboSoundStyle };
}
