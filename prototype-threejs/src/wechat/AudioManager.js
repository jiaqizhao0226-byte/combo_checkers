import { WECHAT_BUILD_PROFILE } from './BuildProfile.js';

const clampVolume = value => Math.max(0, Math.min(1, Math.round((Number(value) || 0) * 20) / 20));

export function createAudioManager(wxApi, stored = {}, buildProfile = WECHAT_BUILD_PROFILE) {
  const bgmPaths = buildProfile?.bgmPaths || WECHAT_BUILD_PROFILE.bgmPaths;
  const sfxPaths = buildProfile?.sfxPaths || WECHAT_BUILD_PROFILE.sfxPaths;
  const bgmPackages = buildProfile?.bgmPackages || {};
  const sfxPackages = buildProfile?.sfxPackages || {};
  const state = {
    bgmVolume: clampVolume(stored.bgmVolume ?? 0.5),
    sfxVolume: clampVolume(stored.sfxVolume ?? 0.8),
    comboSoundStyle: stored.comboSoundStyle === 'classic' ? 'classic' : 'scale',
    currentBgm: stored.currentBgm && bgmPaths[stored.currentBgm] ? stored.currentBgm : 'menu',
  };
  let bgm = null;
  let started = false;
  const packageLoads = new Map();

  function persist() {
    if (typeof wxApi.setStorageSync === 'function') wxApi.setStorageSync('combo-checkers-audio-settings', { ...state });
  }

  function ensureBgm() {
    if (bgm || typeof wxApi.createInnerAudioContext !== 'function') return bgm;
    bgm = wxApi.createInnerAudioContext();
    bgm.loop = true;
    bgm.obeyMuteSwitch = true;
    bgm.volume = state.bgmVolume * 0.5;
    bgm.src = bgmPaths[state.currentBgm];
    if (typeof bgm.onError === 'function') bgm.onError(error => console.warn('[combo-checkers] BGM error', error?.errMsg || error));
    return bgm;
  }

  function ensurePackage(name) {
    if (!name || typeof wxApi.loadSubpackage !== 'function') return null;
    if (packageLoads.has(name)) return packageLoads.get(name);
    const load = new Promise((resolve, reject) => {
      wxApi.loadSubpackage({
        name,
        success: resolve,
        fail: reject,
      });
    });
    packageLoads.set(name, load);
    return load;
  }

  function afterPackage(name, onReady) {
    const load = ensurePackage(name);
    if (!load) {
      onReady();
      return null;
    }
    load.then(onReady).catch(error => {
      console.warn('[combo-checkers] audio package unavailable', name, error?.errMsg || error?.message || error);
    });
    return load;
  }

  function startBgm(key) {
    // A slower package request must not restart an obsolete track after the
    // player has already entered another screen.
    if (state.currentBgm !== key) return;
    const context = ensureBgm();
    if (!context) { persist(); return; }
    const nextSrc = bgmPaths[key];
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

  function playBgm(key = state.currentBgm) {
    if (!bgmPaths[key]) return;
    state.currentBgm = key;
    persist();
    return afterPackage(bgmPackages[key], () => startBgm(key));
  }

  function unlock() {
    if (!started) playBgm(state.currentBgm);
  }

  function playSfx(key) {
    if (!sfxPaths[key] || state.sfxVolume <= 0 || typeof wxApi.createInnerAudioContext !== 'function') return null;
    return afterPackage(sfxPackages[key], () => {
      const context = wxApi.createInnerAudioContext();
      context.obeyMuteSwitch = true;
      context.volume = state.sfxVolume;
      context.src = sfxPaths[key];
      const destroy = () => { try { context.destroy(); } catch {} };
      if (typeof context.onEnded === 'function') context.onEnded(destroy);
      if (typeof context.onError === 'function') context.onError(destroy);
      try { context.play(); } catch { destroy(); }
    });
  }

  function preloadBattleAudio() {
    return ensurePackage(bgmPackages.battle_calm || bgmPackages.battle || bgmPackages.boss_abyss);
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

  return {
    state, unlock, playBgm, playSfx, preloadBattleAudio,
    setBgmVolume, setSfxVolume, setComboSoundStyle,
  };
}
