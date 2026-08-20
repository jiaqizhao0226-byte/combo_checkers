import * as THREE from 'three';

export class PixelCamera {
  constructor(camera, worldUnitsPerPixel = 0.055) {
    this.camera = camera;
    this.worldUnitsPerPixel = worldUnitsPerPixel;
    // Face the board along its row axis so the near edge stays horizontal.
    // A 62-degree elevation keeps the board readable without feeling fully top-down.
    this.theta = 0;
    this.phi = 1.08;
    this.distance = 23;
    this.target = new THREE.Vector3();
    this.snappedTarget = new THREE.Vector3();
    this.right = new THREE.Vector3();
    this.up = new THREE.Vector3();
    this.delta = new THREE.Vector3();
    this.snappedActors = [];
  }

  update(target, lowWidth, lowHeight) {
    const camera = this.camera;
    const unitsPerPixel = this.worldUnitsPerPixel;
    const halfWidth = lowWidth * unitsPerPixel / 2;
    const halfHeight = lowHeight * unitsPerPixel / 2;

    camera.left = -halfWidth;
    camera.right = halfWidth;
    camera.top = halfHeight;
    camera.bottom = -halfHeight;

    this.target.copy(target);
    camera.position.set(
      target.x + this.distance * Math.cos(this.phi) * Math.sin(this.theta),
      target.y + this.distance * Math.sin(this.phi),
      target.z + this.distance * Math.cos(this.phi) * Math.cos(this.theta)
    );
    camera.lookAt(target);
    camera.updateProjectionMatrix();
    camera.updateMatrixWorld();

    // Quantise translation in camera space. Updating camera.position is
    // deliberate: directly editing matrixWorld is overwritten by Three.js.
    const inverse = camera.matrixWorldInverse.elements;
    const snapX = Math.round(inverse[12] / unitsPerPixel) * unitsPerPixel - inverse[12];
    const snapY = Math.round(inverse[13] / unitsPerPixel) * unitsPerPixel - inverse[13];
    const snapZ = Math.round(inverse[14] / unitsPerPixel) * unitsPerPixel - inverse[14];

    this.snappedTarget.copy(target);
    if (snapX || snapY || snapZ) {
      const world = camera.matrixWorld.elements;
      const dx = world[0] * snapX + world[4] * snapY + world[8] * snapZ;
      const dy = world[1] * snapX + world[5] * snapY + world[9] * snapZ;
      const dz = world[2] * snapX + world[6] * snapY + world[10] * snapZ;
      camera.position.x -= dx;
      camera.position.y -= dy;
      camera.position.z -= dz;
      this.snappedTarget.x -= dx;
      this.snappedTarget.y -= dy;
      this.snappedTarget.z -= dz;
      camera.updateMatrixWorld();
    }

    const world = camera.matrixWorld.elements;
    this.right.set(world[0], world[1], world[2]);
    this.up.set(world[4], world[5], world[6]);
    return this.snappedTarget;
  }

  snapActors(objects) {
    this.snappedActors.length = 0;
    const unitsPerPixel = this.worldUnitsPerPixel;

    for (const object of objects) {
      this.delta.copy(object.position).sub(this.camera.position);
      const screenX = this.delta.dot(this.right);
      const screenY = this.delta.dot(this.up);
      const dx = Math.round(screenX / unitsPerPixel) * unitsPerPixel - screenX;
      const dy = Math.round(screenY / unitsPerPixel) * unitsPerPixel - screenY;
      if (!dx && !dy) continue;

      object.position.addScaledVector(this.right, dx).addScaledVector(this.up, dy);
      this.snappedActors.push({ object, dx, dy });
    }
  }

  restoreActors() {
    for (const snap of this.snappedActors) {
      snap.object.position
        .addScaledVector(this.right, -snap.dx)
        .addScaledVector(this.up, -snap.dy);
    }
    this.snappedActors.length = 0;
  }
}
