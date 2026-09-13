function xmlEscape(str) {
  return String(str).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

export function svgImg(label, c1, c2) {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="600" height="600">
    <defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="${c1}"/><stop offset="1" stop-color="${c2}"/>
    </linearGradient></defs>
    <rect width="600" height="600" fill="url(#g)"/>
    <text x="300" y="325" font-family="Arial, sans-serif" font-size="120" font-weight="700"
      fill="rgba(255,255,255,.92)" text-anchor="middle">${xmlEscape(label)}</text>
  </svg>`;
  return "data:image/svg+xml;utf8," + encodeURIComponent(svg);
}

const PALETTES = [
  ["#2b3a67", "#1b2440"], ["#3a2b58", "#241a3a"], ["#1e4b4b", "#123030"],
  ["#4b2b3a", "#2e1a24"], ["#2b4b2f", "#1a2e1c"], ["#4b3a1e", "#2e2412"],
  ["#2b3f4b", "#1a262e"], ["#3f2b4b", "#26192e"],
];

export function img(id, letters) {
  const p = PALETTES[id % PALETTES.length];
  return svgImg(letters, p[0], p[1]);
}
