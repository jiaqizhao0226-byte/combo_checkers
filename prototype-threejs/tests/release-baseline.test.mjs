import assert from 'node:assert/strict';
import { readFile, rm } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

import {
  buildRelease, RELEASE_LIMITS, verifyRelease,
} from '../tools/build-wechat-release.mjs';

async function run() {

const projectRoot = new URL('../../', pathToFileURL(process.argv[1]));
const outputRoot = resolve(new URL('.', projectRoot).pathname, 'dist', `wechat-release-test-${process.pid}`);

try {
  const result = await buildRelease({ outputRoot, version: '0.0.0-test' });
  const verified = await verifyRelease(outputRoot);
  assert.equal(result.packageBytes.main, verified.packageBytes.main);
  assert(result.packageBytes.main < RELEASE_LIMITS.mainPackageBytes, '微信主包必须保持在 4 MiB 以内');
  assert(result.totalBytes < RELEASE_LIMITS.totalPackageBytes, '微信总包必须保持在 20 MiB 以内');
  assert(result.mainHeadroomBytes > 1024 * 1024, '发布基线至少保留 1 MiB 主包余量');

  const gameConfig = JSON.parse(await readFile(resolve(outputRoot, 'game.json'), 'utf8'));
  assert.deepEqual(gameConfig.subpackages.map(item => item.name), ['audio-menu', 'audio-battle']);
  const vfxConfig = await readFile(resolve(outputRoot, 'src/vfx/VfxTestConfig.js'), 'utf8');
  assert.match(vfxConfig, /VFX_TEST_MODE = false/, '正式发布包必须强制关闭局内特效测试入口');
  const buildProfile = await readFile(resolve(outputRoot, 'src/wechat/BuildProfile.js'), 'utf8');
  assert.match(buildProfile, /name: 'release'/);
  assert.match(buildProfile, /packages\/audio-menu\/bgm_menu\.ogg/);
  assert.match(buildProfile, /packages\/audio-battle\/bgm_battle_calm\.ogg/);
  assert.equal(result.files.some(file => file.path.startsWith('vfx-review/')), false);
  assert.equal(result.files.some(file => file.path.startsWith('tests/')), false);
  assert.equal(result.files.some(file => file.path.endsWith('.html')), false);
  console.log('wechat release baseline tests passed');
} finally {
  await rm(outputRoot, { recursive: true, force: true });
  await rm(`${outputRoot}.manifest.json`, { force: true });
}
}

run();
