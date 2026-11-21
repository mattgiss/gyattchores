// The player characters, drawn once here and written out for both apps by build.mjs.
//
// Each character is a stack of layers on a 40 × 40 square, painted in order. A layer is either
// "body" (the dark silhouette) or "detail" (the light parts: eyes, teeth, a headband). A body
// layer on top of a detail layer makes a pupil. Paths use only absolute M, L, C, Q and Z, so the
// apps can read them with a few lines of code and draw them the same way on both.

const n = (v) => String(Math.round(v * 100) / 100);
const K = 0.5523; // how far a curve's handle sits from its corner to make a quarter circle

export const ellipse = (cx, cy, rx, ry) => {
  const kx = rx * K, ky = ry * K;
  return `M ${n(cx - rx)} ${n(cy)} C ${n(cx - rx)} ${n(cy - ky)} ${n(cx - kx)} ${n(cy - ry)} ${n(cx)} ${n(cy - ry)} ` +
    `C ${n(cx + kx)} ${n(cy - ry)} ${n(cx + rx)} ${n(cy - ky)} ${n(cx + rx)} ${n(cy)} ` +
    `C ${n(cx + rx)} ${n(cy + ky)} ${n(cx + kx)} ${n(cy + ry)} ${n(cx)} ${n(cy + ry)} ` +
    `C ${n(cx - kx)} ${n(cy + ry)} ${n(cx - rx)} ${n(cy + ky)} ${n(cx - rx)} ${n(cy)} Z`;
};
export const circle = (cx, cy, r) => ellipse(cx, cy, r, r);
export const rrect = (x, y, w, h, r = 0) => {
  if (!r) return `M ${n(x)} ${n(y)} L ${n(x + w)} ${n(y)} L ${n(x + w)} ${n(y + h)} L ${n(x)} ${n(y + h)} Z`;
  const X = x + w, Y = y + h;
  return `M ${n(x + r)} ${n(y)} L ${n(X - r)} ${n(y)} Q ${n(X)} ${n(y)} ${n(X)} ${n(y + r)} L ${n(X)} ${n(Y - r)} Q ${n(X)} ${n(Y)} ${n(X - r)} ${n(Y)} ` +
    `L ${n(x + r)} ${n(Y)} Q ${n(x)} ${n(Y)} ${n(x)} ${n(Y - r)} L ${n(x)} ${n(y + r)} Q ${n(x)} ${n(y)} ${n(x + r)} ${n(y)} Z`;
};
export const poly = (...p) => 'M ' + p.map(([x, y]) => `${n(x)} ${n(y)}`).join(' L ') + ' Z';
const star = (cx, cy, R, r) => poly(...Array.from({ length: 10 }, (_, i) => {
  const a = -Math.PI / 2 + i * Math.PI / 5, q = i % 2 ? r : R;
  return [cx + q * Math.cos(a), cy + q * Math.sin(a)];
}));
const smile = (x1, x2, y, deep, thick) => { const a = x1 + (x2 - x1) * 0.25, b = x1 + (x2 - x1) * 0.75;
  return `M ${n(x1)} ${n(y)} C ${n(a)} ${n(y + deep)} ${n(b)} ${n(y + deep)} ${n(x2)} ${n(y)} C ${n(b)} ${n(y + deep - thick)} ${n(a)} ${n(y + deep - thick)} ${n(x1)} ${n(y)} Z`; };

// One layer per shape: shapes that overlap inside a single path can cancel each other out.
const body = (...d) => d.map((d) => ({ detail: false, d }));
const detail = (...d) => d.map((d) => ({ detail: true, d }));
const c = (id, name, ...layers) => ({ id, name, layers: layers.flat() });

export const characters = [
  c('ninja', 'Ninja',
    body('M 6 36 L 6 19 C 6 11.27 12.27 5 20 5 C 27.73 5 34 11.27 34 19 L 34 36 L 29.33 32 L 24.67 36 L 20 32 L 15.33 36 L 10.67 32 Z'),
    detail(rrect(4, 15, 32, 5.4), poly([35, 16.4], [39.6, 13.2], [39.6, 21])),
    body(circle(14.5, 17.7, 1.9), circle(25.5, 17.7, 1.9)),
  ),
  c('cat', 'Cat',
    body('M 8.5 7 L 15 14.2 L 25 14.2 L 31.5 7 L 31.5 17 C 33.2 19.3 34 22 34 25 C 34 32 28 36.5 20 36.5 C 12 36.5 6 32 6 25 C 6 22 6.8 19.3 8.5 17 Z'),
    detail(circle(14.3, 23, 4.1), circle(25.7, 23, 4.1), poly([18.4, 29], [21.6, 29], [20, 31.2])),
    body(circle(15.3, 23.6, 1.9), circle(24.7, 23.6, 1.9)),
  ),
  c('wizard', 'Wizard',
    body(poly([20, 1.5], [29, 16], [11, 16]), ellipse(20, 16.4, 15, 2.8), circle(20, 25, 9.6)),
    detail('M 11.6 26.6 C 15 29.4 25 29.4 28.4 26.6 L 20 39 Z', circle(16.4, 22.6, 1.9), circle(23.6, 22.6, 1.9), star(21.4, 9.4, 2.6, 1.1)),
  ),
  c('robot', 'Robot',
    body(rrect(19, 4.5, 2, 6), circle(20, 4.6, 2.4), rrect(6, 10, 28, 25, 5), rrect(2.6, 18, 3.4, 9, 1.2), rrect(34, 18, 3.4, 9, 1.2)),
    detail(rrect(10.6, 15.6, 7.6, 6.6, 1.6), rrect(21.8, 15.6, 7.6, 6.6, 1.6), rrect(12, 27, 16, 3.6, 1.2)),
    body(rrect(15.6, 27, 1.2, 3.6), rrect(19.4, 27, 1.2, 3.6), rrect(23.2, 27, 1.2, 3.6)),
  ),
  c('bear', 'Bear',
    body(circle(9.6, 10.6, 5.8), circle(30.4, 10.6, 5.8), circle(20, 22.5, 14)),
    detail(circle(9.6, 10.6, 2.4), circle(30.4, 10.6, 2.4), ellipse(20, 27.4, 6.2, 4.8), circle(14, 19.4, 2), circle(26, 19.4, 2)),
    body(ellipse(20, 25.6, 2.3, 1.7)),
  ),
  c('bunny', 'Bunny',
    body(ellipse(13, 11.5, 4.3, 10), ellipse(27, 11.5, 4.3, 10), ellipse(20, 27, 13.4, 10.4)),
    detail(ellipse(13, 11.5, 1.7, 6.4), ellipse(27, 11.5, 1.7, 6.4), circle(14.4, 25, 2.2), circle(25.6, 25, 2.2), rrect(17.9, 30.4, 4.2, 4.4, 0.9)),
    body(rrect(19.7, 30.4, 0.6, 4.4)),
  ),
  c('alien', 'Alien',
    body(poly([11.6, 4], [13.6, 3.4], [16.6, 11], [14.6, 11.8]), poly([28.4, 4], [26.4, 3.4], [23.4, 11], [25.4, 11.8]), circle(12.4, 3.8, 2.3), circle(27.6, 3.8, 2.3),
      'M 20 8 C 30 8 35.4 13.6 35.4 20.6 C 35.4 29 27 37.4 20 37.4 C 13 37.4 4.6 29 4.6 20.6 C 4.6 13.6 10 8 20 8 Z'),
    detail('M 8.6 19.4 C 12 16.4 17.4 19 18.2 25.4 C 13.6 27.4 9.6 24.8 8.6 19.4 Z', 'M 31.4 19.4 C 28 16.4 22.6 19 21.8 25.4 C 26.4 27.4 30.4 24.8 31.4 19.4 Z', rrect(17.6, 31, 4.8, 1.5, 0.75)),
  ),
  c('monster', 'Monster',
    body(poly([6.4, 4.6], [14, 12], [6.4, 17]), poly([33.6, 4.6], [26, 12], [33.6, 17]), rrect(5.6, 10.6, 28.8, 26, 10.5)),
    detail(circle(20, 20.6, 6.6), poly([11.6, 29.6], [28.4, 29.6], [26.3, 33.4], [24.2, 30.2], [22.1, 33.4], [20, 30.2], [17.9, 33.4], [15.8, 30.2], [13.7, 33.4])),
    body(circle(20, 20.9, 3)),
  ),
  c('frog', 'Frog',
    body(circle(11.4, 12.6, 6.8), circle(28.6, 12.6, 6.8), ellipse(20, 24.4, 16.4, 11.8)),
    detail(circle(11.4, 12.6, 4), circle(28.6, 12.6, 4), smile(10, 30, 26.4, 5.4, 2.4)),
    body(circle(11.4, 12.9, 1.8), circle(28.6, 12.9, 1.8)),
  ),
  c('owl', 'Owl',
    body(poly([6.6, 4.6], [16, 10.6], [7.6, 17]), poly([33.4, 4.6], [24, 10.6], [32.4, 17]), ellipse(20, 23, 13.4, 14.4)),
    detail(circle(13.8, 19, 5.4), circle(26.2, 19, 5.4), poly([17.4, 25], [22.6, 25], [20, 29.6])),
    body(circle(13.8, 19, 2.4), circle(26.2, 19, 2.4)),
  ),
  c('octopus', 'Octopus',
    body('M 5.6 25 L 5.6 19 C 5.6 11.05 12.05 4.6 20 4.6 C 27.95 4.6 34.4 11.05 34.4 19 L 34.4 25 Z',
      rrect(5.6, 20, 5.9, 16.6, 2.95), rrect(13.23, 20, 5.9, 16.6, 2.95), rrect(20.87, 20, 5.9, 16.6, 2.95), rrect(28.5, 20, 5.9, 16.6, 2.95)),
    detail(circle(14.6, 16.6, 3.3), circle(25.4, 16.6, 3.3)),
    body(circle(14.6, 17.2, 1.5), circle(25.4, 17.2, 1.5)),
  ),
  c('star', 'Star',
    body(star(20, 21.4, 18.6, 9.2)),
    detail(circle(16.6, 19.6, 2), circle(23.4, 19.6, 2), smile(16, 24, 24, 3.4, 1.5)),
  ),
  c('king', 'King',
    body(poly([8, 16], [8, 4.4], [14, 10], [20, 3.4], [26, 10], [32, 4.4], [32, 16]), rrect(6.4, 14, 27.2, 23, 9.5)),
    detail(rrect(8, 12.2, 24, 2.4), circle(14.6, 23, 3.4), circle(25.4, 23, 3.4), smile(15.4, 24.6, 29.4, 3.6, 1.6)),
    body(circle(14.6, 23.5, 1.6), circle(25.4, 23.5, 1.6)),
  ),
  c('astronaut', 'Astronaut',
    body(circle(20, 17.6, 14.6), rrect(8, 30, 24, 7.6, 3.4), rrect(2.4, 14.6, 4, 7, 1.6), rrect(33.6, 14.6, 4, 7, 1.6)),
    detail(rrect(9.4, 10.6, 21.2, 13.6, 6.6), rrect(17.4, 32.4, 5.2, 2.6, 1)),
    body(circle(15.8, 17.8, 1.8), circle(24.2, 17.8, 1.8)),
  ),
  c('mushroom', 'Mushroom',
    body('M 2.6 20 C 2.6 10 10 3.6 20 3.6 C 30 3.6 37.4 10 37.4 20 C 37.4 22.2 35.6 23.4 33.4 23.4 L 6.6 23.4 C 4.4 23.4 2.6 22.2 2.6 20 Z', rrect(11.6, 20, 16.8, 17.4, 5.4)),
    detail(circle(11.6, 14, 3.1), circle(21.4, 9.6, 2.5), circle(29.4, 15.6, 2.8), circle(16.6, 29.4, 1.9), circle(23.4, 29.4, 1.9)),
  ),
  c('flame', 'Flame',
    body('M 20 2.6 C 22 10 32.4 14 32.4 25 C 32.4 32.2 26.8 37.4 20 37.4 C 13.2 37.4 7.6 32.2 7.6 25 C 7.6 20 10.6 17 12.2 12.6 C 14.2 15.8 15.4 17 17 17.6 C 16 12 17.4 7 20 2.6 Z'),
    detail(circle(15.4, 26, 2.3), circle(24.6, 26, 2.3), smile(16.2, 23.8, 30.4, 3.2, 1.4)),
  ),
  c('dragon', 'Dragon',
    body(poly([10.4, 12], [5.6, 1.8], [15.4, 9.4]), poly([29.6, 12], [34.4, 1.8], [24.6, 9.4]), poly([16.6, 10.4], [20, 3.6], [23.4, 10.4]),
      poly([6.6, 17], [0.8, 10.4], [2.4, 18.4], [0.6, 21.4], [3.2, 24.4], [6.6, 27]), poly([33.4, 17], [39.2, 10.4], [37.6, 18.4], [39.4, 21.4], [36.8, 24.4], [33.4, 27]),
      rrect(6, 9, 28, 26.4, 10)),
    detail(circle(14, 19.4, 3.3), circle(26, 19.4, 3.3), ellipse(17.2, 28.4, 1.3, 1), ellipse(22.8, 28.4, 1.3, 1),
      poly([12.4, 32.6], [15.2, 32.6], [13.8, 36.2]), poly([24.8, 32.6], [27.6, 32.6], [26.2, 36.2])),
    body(rrect(13.4, 16.4, 1.3, 6, 0.65), rrect(25.3, 16.4, 1.3, 6, 0.65)),
  ),
  c('dinosaur', 'Dinosaur',
    body(poly([10.6, 14], [13, 5.6], [16.4, 12]), poly([16.4, 11.4], [20, 2.8], [23.6, 11.4]), poly([23.6, 12], [27, 5.6], [29.4, 14]), ellipse(20, 23.4, 15.4, 13.2)),
    detail(circle(14, 19.6, 3.2), circle(26, 19.6, 3.2), circle(18, 24.6, 0.9), circle(22, 24.6, 0.9), smile(9, 31, 27.4, 6.6, 3)),
    body(circle(14.6, 20, 1.6), circle(25.4, 20, 1.6), poly([13, 29.4], [15, 29.4], [14, 31.4]), poly([19, 30.6], [21, 30.6], [20, 32.6]), poly([25, 29.4], [27, 29.4], [26, 31.4])),
  ),
  c('moose', 'Moose',
    body(poly([14.6, 15], [4.6, 13.4], [1.4, 6.4], [4.6, 8.6], [4.8, 3], [8, 7.4], [9.6, 2], [11.8, 6.8], [13.8, 3.2], [15.6, 11]),
      poly([25.4, 15], [35.4, 13.4], [38.6, 6.4], [35.4, 8.6], [35.2, 3], [32, 7.4], [30.4, 2], [28.2, 6.8], [26.2, 3.2], [24.4, 11]),
      ellipse(9.6, 18.4, 3.6, 2), ellipse(30.4, 18.4, 3.6, 2), ellipse(20, 22.6, 9, 9.6), rrect(11.4, 26, 17.2, 11.4, 5.6)),
    detail(circle(15.8, 21.4, 2.1), circle(24.2, 21.4, 2.1), ellipse(16.8, 33, 1.6, 1.2), ellipse(23.2, 33, 1.6, 1.2)),
    body(circle(16, 21.7, 1.1), circle(24, 21.7, 1.1)),
  ),
  c('otter', 'Otter',
    body(circle(8.6, 12.4, 3.4), circle(31.4, 12.4, 3.4), circle(20, 21.6, 14)),
    detail(ellipse(20, 27.6, 9.4, 6.4), circle(14, 19, 2.3), circle(26, 19, 2.3)),
    body(circle(14.3, 19.3, 1.2), circle(25.7, 19.3, 1.2), ellipse(20, 24.6, 2.8, 1.9), rrect(19.6, 25.6, 0.8, 3, 0.4),
      poly([11.6, 26.4], [17, 27.4], [17, 28], [11.6, 27.2]), poly([28.4, 26.4], [23, 27.4], [23, 28], [28.4, 27.2]),
      poly([11.8, 29.6], [17, 29], [17, 29.6], [11.8, 30.4]), poly([28.2, 29.6], [23, 29], [23, 29.6], [28.2, 30.4])),
  ),
  c('beaver', 'Beaver',
    body(circle(9.2, 9.6, 3.6), circle(30.8, 9.6, 3.6), circle(20, 20, 13.8)),
    detail(circle(9.2, 9.6, 1.5), circle(30.8, 9.6, 1.5), circle(14.6, 16.6, 2.3), circle(25.4, 16.6, 2.3), ellipse(20, 24.4, 6.6, 3.8), rrect(16.4, 26, 7.2, 9.6, 1.4)),
    body(circle(14.9, 17, 1.2), circle(25.1, 17, 1.2), ellipse(20, 23, 2.6, 1.7), rrect(19.6, 27.4, 0.8, 8.2)),
  ),
  c('sloth', 'Sloth',
    body(poly([15.4, 8.6], [17, 3.6], [19.4, 7.4]), poly([20.6, 7.4], [23, 3.6], [24.6, 8.6]), ellipse(20, 21.4, 15.2, 14.2)),
    detail(ellipse(20, 23, 11.6, 10.2)),
    body('M 9.4 21.6 C 10 17.6 15.6 16.2 18 18.6 C 19 20.2 17.6 22.4 15 23.4 C 12.4 24.4 9.2 24 9.4 21.6 Z',
      'M 30.6 21.6 C 30 17.6 24.4 16.2 22 18.6 C 21 20.2 22.4 22.4 25 23.4 C 27.6 24.4 30.8 24 30.6 21.6 Z',
      ellipse(20, 25.4, 2.6, 1.7), smile(16, 24, 28.6, 3, 1.3)),
    detail(circle(15.2, 20.2, 1.3), circle(24.8, 20.2, 1.3)),
  ),
  c('panda', 'Panda',
    body(circle(9.4, 10.4, 5.6), circle(30.6, 10.4, 5.6), circle(20, 22, 15)),
    detail(ellipse(20, 23, 13, 12.2)),
    body('M 9.6 22.4 C 9.4 18.2 13.4 15.6 16.6 17.4 C 18.8 18.8 18.4 22.6 16 25 C 13.4 27.4 9.8 26.2 9.6 22.4 Z',
      'M 30.4 22.4 C 30.6 18.2 26.6 15.6 23.4 17.4 C 21.2 18.8 21.6 22.6 24 25 C 26.6 27.4 30.2 26.2 30.4 22.4 Z',
      ellipse(20, 27.6, 2.6, 1.8), smile(16.6, 23.4, 30.6, 2.6, 1.2)),
    detail(circle(14.6, 21, 1.6), circle(25.4, 21, 1.6)),
    body(circle(14.8, 21.2, 0.8), circle(25.2, 21.2, 0.8)),
  ),
  c('fox', 'Fox',
    body(poly([5.4, 3.6], [16.4, 12.4], [7.4, 19]), poly([34.6, 3.6], [23.6, 12.4], [32.6, 19]),
      'M 4.6 16 C 8 11.4 13.6 10 20 10 C 26.4 10 32 11.4 35.4 16 C 35.4 22.6 30.4 27.6 24.6 32.4 L 20 37 L 15.4 32.4 C 9.6 27.6 4.6 22.6 4.6 16 Z'),
    detail(poly([7.6, 7.6], [13.4, 12.4], [8.6, 15.6]), poly([32.4, 7.6], [26.6, 12.4], [31.4, 15.6]),
      'M 5.4 18.4 C 9.4 21.4 14.6 22.6 17.4 25 L 20 33.6 L 22.6 25 C 25.4 22.6 30.6 21.4 34.6 18.4 C 33.6 23.4 29.4 27.4 24.6 31.4 L 20 36 L 15.4 31.4 C 10.6 27.4 6.4 23.4 5.4 18.4 Z'),
    detail(ellipse(14, 17.2, 2.8, 2.2), ellipse(26, 17.2, 2.8, 2.2)),
    body(circle(14.6, 17.4, 1.3), circle(25.4, 17.4, 1.3), ellipse(20, 33.8, 2.4, 1.8)),
  ),
  c('penguin', 'Penguin',
    body(ellipse(6.4, 26, 3, 7.4), ellipse(33.6, 26, 3, 7.4), ellipse(20, 21.6, 13.4, 16)),
    detail('M 20 14.6 C 21.6 10.6 30.6 10 30.6 18.4 C 30.6 22 28 23.4 28 26.4 C 28 32.4 24.6 36.4 20 36.4 C 15.4 36.4 12 32.4 12 26.4 C 12 23.4 9.4 22 9.4 18.4 C 9.4 10 18.4 10.6 20 14.6 Z'),
    body(circle(15.4, 18, 1.9), circle(24.6, 18, 1.9), poly([17, 21.4], [23, 21.4], [20, 25.6])),
  ),
];
