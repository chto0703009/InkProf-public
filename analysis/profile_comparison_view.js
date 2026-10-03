// Embedded in the standalone comparison HTML; no external assets are required.
const c = document.getElementById('view'), ctx = c.getContext('2d');
const slice = document.getElementById('slice');
const light = document.getElementById('lightness'), width = document.getElementById('width');
const words = Object.assign({previous:'previous',current:'current',visible:'Visible samples',sparse:'Samples within the L* band; a sparse slice does not imply missing printable colours.',all:'All lightness levels shown.',rotate:'3D Lab - drag to rotate; L* increases upwards'}, typeof viewLabels === 'undefined' ? {} : viewLabels);
let angle = .6, drag = false, last = 0;
// Fixed scale across both profiles and all L* slices, with equal a*/b* units.
const extent = Math.max(20, ...groups.flatMap(g => g.flatMap(p => [Math.abs(p[1]), Math.abs(p[2])])));
const limit = Math.ceil(extent / 20) * 20;
const scale = 180 / limit;
function projectPoint(p) {
    if (slice.checked) return [450 + p[1] * scale, 230 - p[2] * scale];
    const x = p[1] * Math.cos(angle) - p[2] * Math.sin(angle);
    const z = p[1] * Math.sin(angle) + p[2] * Math.cos(angle);
    return [450 + x * 2, 380 - p[0] * 3 - z * .35];
}
function drawAxes() {
    ctx.font = '13px system-ui'; ctx.lineWidth = 1;
    for (let value = -limit; value <= limit; value += limit / 4) {
        const x = 450 + value * scale, y = 230 - value * scale;
        ctx.strokeStyle = value === 0 ? '#627785' : '#dce3e8';
        ctx.beginPath();ctx.moveTo(x, 50);ctx.lineTo(x, 410);ctx.stroke();
        ctx.beginPath();ctx.moveTo(270, y);ctx.lineTo(630, y);ctx.stroke();
        ctx.fillStyle = '#183343';ctx.fillText(String(value), x - 10, 430);
        ctx.fillText(String(value), 235, y + 4);
    }
    ctx.fillText('a*', 650, 235);ctx.fillText('b*', 444, 38);
}
function draw() {
    drag = false;
    ctx.clearRect(0, 0, 900, 460);ctx.globalAlpha = 1;
    const level = Number(light.value), half = Math.min(50, Math.max(1, Number(width.value) || 5));
    light.disabled = width.disabled = !slice.checked;
    c.style.cursor = slice.checked ? 'default' : 'grab';
    document.getElementById('level').textContent = light.value;
    if (slice.checked) drawAxes();
    const counts = [];
    groups.forEach((g, k) => {
        ctx.fillStyle = k ? '#d67520' : '#216bb0';ctx.globalAlpha = .5;
        const selected = g.filter(p => !slice.checked || Math.abs(p[0] - level) <= half);
        counts.push(selected.length);
        selected.forEach(p => {
            const [x, y] = projectPoint(p);
            ctx.beginPath();ctx.arc(x, y, 2.5, 0, 2 * Math.PI);ctx.fill();
        });
    });
    ctx.globalAlpha = 1;ctx.fillStyle = '#183343';ctx.font = '14px system-ui';
    ctx.fillText(slice.checked ? '2D a*/b* - L* ' + level + ' ± ' + half : words.rotate, 20, 20);
    document.getElementById('counts').textContent = words.visible + ': ' + words.previous + ' ' + counts[0] + ', ' + words.current + ' ' + counts[1] +
        '. ' + (slice.checked ? words.sparse : words.all);
}
[slice, light, width].forEach(e => e.oninput = draw);
c.onpointerdown = e => { if (slice.checked) return;drag = true;last = e.clientX;c.setPointerCapture(e.pointerId); };
c.onpointerup = c.onpointercancel = () => drag = false;
c.onpointermove = e => {
    if (!drag || slice.checked) return;
    angle += (e.clientX - last) * .01;last = e.clientX;draw();drag = true;
};
draw();
