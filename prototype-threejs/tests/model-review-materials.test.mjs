import assert from 'node:assert/strict';
import * as THREE from '../vendor/three.module.js';
import { createSlimeCandidate } from '../model-review/SlimeCandidate.js';
import { createEnemyCandidate } from '../model-review/EnemyCandidates.js';

function materialFor(model, meshName) {
  const mesh = model.getObjectByName(meshName);
  assert.ok(mesh?.isMesh, `missing review mesh: ${meshName}`);
  return mesh.material;
}

const slime = materialFor(createSlimeCandidate(), 'SlimeCandidateBody');
assert.ok(slime.roughness >= 0.35);
assert.ok(slime.clearcoat <= 0.4);

const turtle = createEnemyCandidate('iron_turtle');
const turtleShellMesh = turtle.getObjectByName('IronTurtleCandidateShell');
const turtleShell = materialFor(turtle, 'IronTurtleCandidateShell');
const turtleSkin = materialFor(turtle, 'IronTurtleCandidateBody');
assert.ok(turtleShell.metalness >= 0.4);
assert.ok(turtleShell.roughness >= 0.55);
assert.ok(turtleShellMesh.scale.y / turtleShellMesh.scale.x < 0.5,
  'iron turtle shell must stay low instead of forming a tall smooth dome');
assert.equal(turtleSkin.isMeshStandardMaterial, true);
assert.ok(turtleSkin.roughness >= 0.8);
assert.ok(turtle.getObjectByName('IronTurtleCandidateShellRim'));
assert.ok(turtle.getObjectByName('IronTurtleCandidateNeck'));
assert.ok(turtle.getObjectByName('IronTurtleCandidateMouth'));
const turtleNames = [];
turtle.traverse(child => turtleNames.push(child.name));
assert.equal(turtleNames.filter(name => /^IronTurtleCandidatePlate\d+$/.test(name)).length, 7);
assert.equal(turtleNames.filter(name => /^IronTurtleCandidatePlateGroove\d+$/.test(name)).length, 7);
assert.equal(turtleNames.filter(name => /^IronTurtleCandidateRimGuard\d+$/.test(name)).length, 8);
assert.equal(turtleNames.filter(name => /^IronTurtleCandidateRivet\d+$/.test(name)).length, 8);
assert.equal(turtleNames.filter(name => /^IronTurtleClaw\d+_\d+$/.test(name)).length, 0,
  'abyss sea turtle must not retain land-tortoise claws');
assert.equal(turtleNames.filter(name => /^IronTurtleFootMesh\d+$/.test(name)).length, 0,
  'abyss sea turtle must not retain walking feet');
assert.equal(turtleNames.filter(name => /^IronTurtleCandidateFrontFlipperMesh[LR]$/.test(name)).length, 2);
assert.equal(turtleNames.filter(name => /^IronTurtleCandidateRearFlipperMesh[LR]$/.test(name)).length, 2);
const turtleFrontFlipper = turtle.getObjectByName('IronTurtleCandidateFrontFlipperMeshL');
assert.equal(turtleFrontFlipper.geometry.type, 'ExtrudeGeometry');
assert.ok(turtle.getObjectByName('IronTurtleHead').position.y < 0.5,
  'sea turtle head must stay low in the swimming silhouette');
const turtleFootprint = new THREE.Box3().setFromObject(turtle).getSize(new THREE.Vector3());
assert.ok(turtleFootprint.x < 1.55,
  'complete sea turtle flipper span must fit inside one review hex after shared page scaling');
assert.ok(turtleNames.includes('IronTurtleCandidateScratch1'));
assert.ok(turtleNames.includes('IronTurtleCandidateRustPatch'));
assert.ok(turtle.getObjectByName('IronTurtleCandidateShell').geometry.getAttribute('color'));

const archerfish = createEnemyCandidate('archerfish');
const archerfishSkin = materialFor(archerfish, 'ArcherfishCandidateBody');
const archerfishBodyMesh = archerfish.getObjectByName('ArcherfishCandidateBody');
assert.equal(archerfishSkin.isMeshStandardMaterial, true);
assert.ok(archerfishSkin.roughness >= 0.6);
assert.equal(archerfishSkin.vertexColors, true);
assert.equal(archerfishBodyMesh.geometry.type, 'BufferGeometry',
  'archerfish needs a continuous multi-section body instead of a stretched sphere');
const archerfishBodySize = new THREE.Box3().setFromObject(archerfishBodyMesh).getSize(new THREE.Vector3());
assert.ok(archerfishBodySize.z > archerfishBodySize.y * 1.5,
  'archerfish body must read as elongated rather than round');
assert.ok(archerfishBodySize.x < archerfishBodySize.y * 0.95,
  'archerfish must remain laterally compressed without collapsing in the front game view');
assert.ok(archerfish.getObjectByName('ArcherfishCandidateMouthRing'));
assert.equal(archerfish.getObjectByName('ArcherfishCandidateNozzle'), undefined,
  'shooting behavior must not be represented by a toy-like external pipe');
assert.ok(archerfish.getObjectByName('ArcherfishCandidateGillLeft'));
assert.equal(archerfish.getObjectByName('ArcherfishCandidateBelly'), undefined,
  'archerfish silver belly must be integrated into the shared body surface');
assert.equal(archerfish.getObjectByName('ArcherfishStripe1L'), undefined,
  'archerfish color bands must be integrated into the body instead of pasted blobs');
const archerfishNames = [];
archerfish.traverse(child => archerfishNames.push(child.name));
assert.equal(archerfishNames.filter(name => /^ArcherfishCandidateScale\d+$/.test(name)).length, 0,
  'archerfish must not use raised decorative scale buttons');
const archerColors = archerfish.getObjectByName('ArcherfishCandidateBody').geometry.getAttribute('color');
let darkestArcherVertex = 1;
let brightestArcherVertex = 0;
for (let index = 0; index < archerColors.count; index += 1) {
  const luminance = (archerColors.getX(index) + archerColors.getY(index) + archerColors.getZ(index)) / 3;
  darkestArcherVertex = Math.min(darkestArcherVertex, luminance);
  brightestArcherVertex = Math.max(brightestArcherVertex, luminance);
}
assert.ok(brightestArcherVertex - darkestArcherVertex > 0.35,
  'silver body and dark dorsal bands must remain visibly distinct at game scale');
const archerDorsal = archerfish.getObjectByName('ArcherfishCandidateDorsalFin');
const archerAnal = archerfish.getObjectByName('ArcherfishCandidateAnalFin');
assert.ok(archerDorsal && archerAnal,
  'archerfish silhouette needs paired rear dorsal and anal fins');
assert.ok(archerDorsal.position.z < 0 && archerAnal.position.z < 0,
  'archerfish dorsal and anal fins must sit toward the rear half of the body');
const archerTailFin = archerfish.getObjectByName('ArcherfishCandidateTailFin');
const archerTailSize = new THREE.Box3().setFromObject(archerTailFin).getSize(new THREE.Vector3());
assert.ok(archerTailSize.y > archerTailSize.x * 3,
  'archerfish tail fin must stand vertically instead of spreading sideways');
const archerFootprint = new THREE.Box3().setFromObject(archerfish).getSize(new THREE.Vector3());
assert.ok(archerFootprint.z < 1.8,
  'complete archerfish silhouette must stay close to one review tile');

const eel = createEnemyCandidate('vortex_eel');
assert.ok(eel.getObjectByName('VortexEelCandidateMouth'));
const eelBody = eel.getObjectByName('VortexEelCandidateBodyMesh');
assert.equal(eelBody.material.vertexColors, true);
assert.ok(eelBody.geometry.getAttribute('color'));
assert.equal(eel.getObjectByName('VortexEelCandidateDorsalGlow'), undefined,
  'eel dorsal color must belong to the body surface instead of a separate glowing tube');
const eelNames = [];
eel.traverse(child => eelNames.push(child.name));
assert.equal(eelNames.filter(name => /^VortexEelCandidateDorsalSpine\d+$/.test(name)).length, 5);
assert.equal(eelNames.filter(name => /^VortexEelCandidateVortexRing\d+$/.test(name)).length, 2);

const ray = createEnemyCandidate('electric_ray');
const raySkin = materialFor(ray, 'ElectricRayCandidateBody');
assert.equal(raySkin.clearcoat, 0);
assert.ok(raySkin.roughness >= 0.7);
const rayWing = ray.getObjectByName('ElectricRayCandidateLeftWingMesh');
assert.equal(rayWing.geometry.type, 'ExtrudeGeometry');
assert.ok(rayWing.material.roughness >= 0.8);
const rayBody = ray.getObjectByName('ElectricRayCandidateBody');
const rayTail = ray.getObjectByName('ElectricRayCandidateTailStem');
ray.updateMatrixWorld(true);
assert.ok(new THREE.Box3().setFromObject(rayBody).intersectsBox(new THREE.Box3().setFromObject(rayTail)),
  'electric ray tail root must remain embedded in the body instead of floating behind it');
assert.equal(rayTail.material, rayBody.material,
  'electric ray tail root must continue the body material rather than look pasted on');
const rayNames = [];
ray.traverse(child => rayNames.push(child.name));
assert.equal(rayNames.filter(name => /^ElectricRayCandidateElectricVein[LR]\d+$/.test(name)).length, 6);
assert.equal(rayNames.filter(name => /^ElectricRayGlowSpot\d+$/.test(name)).length, 0,
  'electric patterns must use surface lines instead of raised glowing balls');

const crab = createEnemyCandidate('hermit_crab');
const crabShell = materialFor(crab, 'HermitCrabCandidateShell');
assert.equal(crabShell.isMeshStandardMaterial, true);
assert.ok(crabShell.roughness >= 0.85);
assert.equal(crabShell.vertexColors, true);
assert.ok(crab.getObjectByName('HermitCrabCandidateShellOpening'));
const crabSpiral = crab.getObjectByName('HermitCrabCandidateShellSpiral');
crab.updateMatrixWorld(true);
const crabSpiralCenter = new THREE.Box3().setFromObject(crabSpiral).getCenter(new THREE.Vector3());
assert.ok(crabSpiralCenter.x > 0.18 && crabSpiralCenter.z < 0.18,
  'hermit crab spiral must sit on the side shell instead of directly behind its eyes');
const crabNames = [];
crab.traverse(child => crabNames.push(child.name));
assert.equal(crabNames.filter(name => /^HermitCrabCandidateBarnacle\d+$/.test(name)).length, 5);
assert.ok(crab.getObjectByName('HermitCrabClawRight').scale.x
  > crab.getObjectByName('HermitCrabClawLeft').scale.x * 1.4,
  'hermit crab must have an asymmetrical crusher claw silhouette');

const jellyfish = createEnemyCandidate('jellyfish');
const jellyBell = materialFor(jellyfish, 'JellyfishCandidateDome');
assert.equal(jellyBell.transparent, false,
  'jellyfish must use controlled material transmission instead of fading the entire mesh');
assert.equal(jellyBell.depthWrite, true,
  'jellyfish outer shell must preserve stable front/back depth ordering');
assert.equal(jellyBell.opacity, 1);
assert.ok(jellyBell.transmission >= 0.25 && jellyBell.transmission <= 0.4);
assert.ok(jellyBell.clearcoat <= 0.15);
assert.ok(jellyfish.getObjectByName('JellyfishCandidateInnerBell'));
const jellyNames = [];
jellyfish.traverse(child => jellyNames.push(child.name));
assert.equal(jellyNames.filter(name => /^JellyfishCandidateInnerVein\d+$/.test(name)).length, 6);
assert.equal(jellyNames.filter(name => /^JellyfishCandidateElectricFork\d+$/.test(name)).length, 6);
assert.equal(jellyNames.filter(name => /^JellyfishCandidateOralArm\d+$/.test(name)).length, 2);
assert.equal(jellyNames.filter(name => /^JellyfishCandidateTentacleMesh\d+$/.test(name)).length, 6,
  'jellyfish must expose six readable primary tentacles at game scale');
jellyfish.updateMatrixWorld(true);
const jellyBellBox = new THREE.Box3().setFromObject(jellyfish.getObjectByName('JellyfishCandidateDome'));
const jellyTentacleBox = new THREE.Box3();
for (let index = 1; index <= 6; index += 1) {
  jellyTentacleBox.union(new THREE.Box3().setFromObject(
    jellyfish.getObjectByName(`JellyfishCandidateTentacleMesh${index}`)
  ));
}
assert.ok(jellyTentacleBox.min.x < jellyBellBox.min.x - 0.08
  && jellyTentacleBox.max.x > jellyBellBox.max.x + 0.08,
  'jellyfish tentacles must spread beyond both sides of the bell in game view');
assert.ok(jellyTentacleBox.max.z > jellyBellBox.max.z + 0.12,
  'front tentacles must extend beyond the bell silhouette in the elevated game camera');

const ghost = createEnemyCandidate('ghost_shark');
const ghostBody = materialFor(ghost, 'GhostSharkCandidateBody');
assert.equal(ghostBody.clearcoat, 0);
assert.equal(ghostBody.transparent, false,
  'ghost shark body must remain a stable readable silhouette');
assert.equal(ghostBody.depthWrite, true);
assert.ok(ghostBody.emissiveIntensity >= 0.4);
assert.equal(ghostBody.opacity, 1);
assert.equal(ghostBody.vertexColors, true,
  'ghost shark body must carry its spectral color gradient on the shared surface');
const ghostBodyMesh = ghost.getObjectByName('GhostSharkCandidateBody');
assert.ok(ghostBodyMesh.geometry.getAttribute('color'));
assert.equal(ghostBodyMesh.geometry.type, 'BufferGeometry',
  'ghost shark needs a continuous fusiform body instead of a stretched sphere');
const ghostBodySize = new THREE.Box3().setFromObject(ghostBodyMesh).getSize(new THREE.Vector3());
assert.ok(ghostBodySize.z > ghostBodySize.x * 1.6,
  'ghost shark body must read as an elongated shark instead of a round submarine');
assert.ok(ghostBodySize.x > ghostBodySize.y * 1.25,
  'ghost shark torso must be wider than tall like a swimming shark');
assert.equal(ghost.getObjectByName('GhostSharkCandidateInnerCore'), undefined,
  'ghost shark must not stack a translucent inner sphere inside its body');
assert.equal(ghost.getObjectByName('GhostSharkCandidateBelly'), undefined,
  'ghost shark must not stack a separate translucent belly volume');
assert.equal(ghost.getObjectByName('GhostSharkCandidateSnout'), undefined,
  'the pointed shark snout must belong to the continuous body surface');
assert.ok(ghost.getObjectByName('GhostSharkCandidateMouth'));
assert.ok(ghost.getObjectByName('GhostSharkCandidateDorsalFinMesh'));
assert.ok(ghost.getObjectByName('GhostSharkCandidateTailFinMesh'));
const ghostDorsalSize = new THREE.Box3()
  .setFromObject(ghost.getObjectByName('GhostSharkCandidateDorsalFinMesh'))
  .getSize(new THREE.Vector3());
assert.ok(ghostDorsalSize.z > ghostDorsalSize.x * 2,
  'ghost shark dorsal fin must lie in the side silhouette instead of facing the camera');
const ghostAura = ghost.getObjectByName('GhostSharkCandidateAura');
assert.equal(ghostAura.material.side, THREE.BackSide);
assert.equal(ghostAura.material.depthWrite, false);
assert.ok(ghostAura.material.opacity <= 0.2,
  'ghost aura must remain a thin silhouette rim rather than another transparent body');
const ghostLeftFin = ghost.getObjectByName('GhostSharkCandidateLeftFinMesh');
const ghostRightFin = ghost.getObjectByName('GhostSharkCandidateRightFinMesh');
assert.equal(ghostLeftFin.material.transparent, false,
  'ghost shark pectoral fins must remain solid enough to read in the game camera');
assert.equal(ghostRightFin.material, ghostLeftFin.material);
assert.ok(ghostLeftFin.material.roughness >= 0.7);
assert.equal(ghostLeftFin.geometry.type, 'ExtrudeGeometry');
assert.equal(ghost.getObjectByName('GhostSharkCandidateDorsalSpine'), undefined,
  'ghost shark must not carry a periscope-like dorsal spine');
const ghostTailVeil = ghost.getObjectByName('GhostSharkCandidateTailFinMesh');
assert.equal(ghostTailVeil.material.transparent, true);
assert.equal(ghostTailVeil.material.depthWrite, false,
  'only the dissolving tail veil should use additive transparency');
const ghostNames = [];
ghost.traverse(child => ghostNames.push(child.name));
assert.equal(ghostNames.filter(name => /^GhostSharkCandidateGill[LR]\d+$/.test(name)).length, 6,
  'the shark silhouette needs three readable gill slits on each side');
assert.equal(ghostNames.filter(name => /^GhostSharkCandidateSensoryCanal[LR]\d+$/.test(name)).length, 0,
  'submarine-like facial canal decorations must stay removed');
assert.equal(ghostNames.filter(name => /^GhostSharkCandidateVertebra\d+$/.test(name)).length, 0);
assert.equal(ghostNames.filter(name => /^GhostSharkCandidateWisp\d+$/.test(name)).length, 3);
const ghostFootprint = new THREE.Box3().setFromObject(ghost).getSize(new THREE.Vector3());
assert.ok(ghostFootprint.z < 2,
  'ghost shark body plus spectral tail must stay close to one review tile');

console.log('model review material tests passed');
