import assert from 'node:assert/strict';

import { createAudioManager } from '../src/wechat/AudioManager.js';

const contexts = [];
const saves = [];
const wx = {
  createInnerAudioContext() {
    const context = {
      src: '', volume: 1, loop: false, played: 0, paused: 0, stopped: 0, destroyed: 0,
      play() { this.played += 1; }, pause() { this.paused += 1; }, stop() { this.stopped += 1; }, destroy() { this.destroyed += 1; },
      onEnded(callback) { this.ended = callback; }, onError(callback) { this.failed = callback; },
    };
    contexts.push(context);
    return context;
  },
  setStorageSync(key, value) { saves.push({ key, value: { ...value } }); },
};

const audio = createAudioManager(wx, { bgmVolume: 0.35, sfxVolume: 0.75, comboSoundStyle: 'classic' });
assert.equal(audio.state.bgmVolume, 0.35);
assert.equal(audio.state.sfxVolume, 0.75);
assert.equal(audio.state.comboSoundStyle, 'classic');

audio.playBgm('battle_calm');
assert.match(contexts[0].src, /bgm_battle_calm\.ogg$/);
assert.equal(contexts[0].loop, true);
assert.equal(contexts[0].played, 1);

audio.setBgmVolume(2);
assert.equal(audio.state.bgmVolume, 1);
assert.equal(contexts[0].volume, 0.5);
audio.setSfxVolume(-1);
assert.equal(audio.state.sfxVolume, 0);
audio.setSfxVolume(0.6);
audio.playSfx('ui_click');
assert.match(contexts[1].src, /ui_click\.ogg$/);
assert.equal(contexts[1].volume, 0.6);
assert.ok(saves.length >= 3);

console.log('audio manager tests passed');
