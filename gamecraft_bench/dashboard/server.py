"""FastAPI server: trial listing, session management, WS↔TCP VNC bridge."""

from __future__ import annotations

import asyncio
import os
from pathlib import Path

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles

from .manager import SessionManager

NOVNC_DIR = Path("/usr/share/novnc")
_REPO_ROOT = Path(__file__).resolve().parents[2]
JOBS_ROOT = Path(
    os.environ.get("GAMECRAFT_BENCH_JOBS_ROOT")
    or (_REPO_ROOT.parent / "gamecraft-bench-jobs")
)

app = FastAPI()
mgr = SessionManager()

# Serve noVNC static files at /novnc/
app.mount("/novnc", StaticFiles(directory=str(NOVNC_DIR)), name="novnc")


# ---------------------------------------------------------------------------
# REST
# ---------------------------------------------------------------------------

@app.get("/api/trials")
def list_trials():
    return mgr.list_trials(JOBS_ROOT)


@app.post("/api/sessions")
async def start_session(body: dict):
    trial_id: str = body["trial_id"]
    game_src = Path(body["game_dir"])
    sess = await mgr.start(trial_id, game_src)
    return {"sid": sess.sid, "vnc_port": sess.vnc_port, "trial_id": sess.trial_id}


@app.post("/api/sessions/{sid}/refresh")
async def refresh_session(sid: str, body: dict):
    await mgr.refresh(sid, Path(body["game_dir"]))
    return {"ok": True}


@app.delete("/api/sessions/{sid}")
async def stop_session(sid: str):
    await mgr.stop(sid)
    return {"ok": True}
  
# 加在 /api/sessions/{sid} DELETE 旁边
@app.post("/api/sessions/{sid}")
async def stop_session_post(sid: str):
    await mgr.stop(sid)
    return {"ok": True}



# ---------------------------------------------------------------------------
# WebSocket VNC proxy  (browser ↔ this WS ↔ x11vnc TCP)
# ---------------------------------------------------------------------------

@app.websocket("/ws/{sid}")
async def vnc_ws(websocket: WebSocket, sid: str):
    sess = mgr.get(sid)
    if sess is None:
        await websocket.close(code=4404)
        return
    await websocket.accept(subprotocol="binary")

    try:
        reader, writer = await asyncio.open_connection("127.0.0.1", sess.vnc_port)
    except OSError:
        await websocket.close(code=4503)
        return

    mgr.ping(sid)

    async def tcp_to_ws():
        try:
            while True:
                data = await reader.read(65536)
                if not data:
                    break
                await websocket.send_bytes(data)
        except Exception:
            pass

    async def ws_to_tcp():
        try:
            while True:
                data = await websocket.receive_bytes()
                mgr.ping(sid)
                writer.write(data)
                await writer.drain()
        except (WebSocketDisconnect, Exception):
            pass

    tasks = [asyncio.create_task(tcp_to_ws()), asyncio.create_task(ws_to_tcp())]
    done, pending = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
    for t in pending:
        t.cancel()
    writer.close()


# ---------------------------------------------------------------------------
# Per-session VNC page (WS URL hardcoded — avoids noVNC path-param issues)
# ---------------------------------------------------------------------------


@app.get("/vnc/{sid}", response_class=HTMLResponse)
def vnc_page(sid: str):
    return f"""<!DOCTYPE html>
<html><head><meta charset="utf-8">
<style>
*{{margin:0;padding:0;box-sizing:border-box}}
html,body{{width:100%;height:100%;background:#000;overflow:hidden}}
#screen{{position:fixed;top:0;left:0;width:100vw;height:100vh}}
</style></head>
<body><div id="screen"></div>
<script type="module">
import RFB from '/novnc/core/rfb.js';
const screen = document.getElementById('screen');
const rfb = new RFB(screen, `ws://${{location.host}}/ws/{sid}`, {{credentials:{{}}}});
rfb.scaleViewport = true;

function forceRescale() {{
  // Trigger noVNC's internal _updateScale by faking a resize event
  rfb._updateScale();
  rfb._fixScrollbars && rfb._fixScrollbars();
}}

rfb.addEventListener('desktopname', () => {{
  setTimeout(forceRescale, 50);
  new ResizeObserver(forceRescale).observe(screen);
}});
rfb.addEventListener('disconnect', () => {{
  screen.innerHTML = '<p style="color:#f66;font-family:monospace;padding:20px">Disconnected</p>';
}});
</script></body></html>"""


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

_INDEX_HTML = """\
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>GameCraft-Bench Analysis</title>
<style>
*{box-sizing:border-box}
body{font-family:Inter,Arial,sans-serif;background:#101214;color:#d9dee5;margin:0;font-size:13px}
header{height:54px;display:flex;align-items:center;justify-content:space-between;padding:0 20px;border-bottom:1px solid #2a3036;background:#15191d}
h1{font-size:18px;margin:0;font-weight:650;letter-spacing:0}
main{padding:16px 20px 24px}
.toolbar{display:grid;grid-template-columns:repeat(7,minmax(120px,1fr));gap:10px;margin-bottom:14px}
label{display:flex;flex-direction:column;gap:4px;color:#9aa6b2;font-size:11px;text-transform:uppercase}
select,input{background:#171c21;color:#e5e9ef;border:1px solid #343c45;border-radius:6px;padding:7px 9px;font:inherit;min-width:0}
button{background:#244b68;color:#fff;border:1px solid #31627f;padding:7px 10px;cursor:pointer;border-radius:6px;font:inherit}
button:hover{background:#2d5d80}
button.secondary{background:#1a2026;border-color:#3a424c;color:#d9dee5}
button.danger{background:#5a2730;border-color:#7c3641}
.actions{display:flex;gap:8px;align-items:end;flex-wrap:wrap}
.stats{display:grid;grid-template-columns:repeat(8,minmax(90px,1fr));gap:10px;margin-bottom:14px}
.stat{border:1px solid #293039;background:#151a1f;border-radius:8px;padding:10px 12px;min-height:64px}
.stat .k{color:#91a0ad;font-size:11px;text-transform:uppercase}
.stat .v{font-size:22px;font-weight:700;margin-top:5px}
.layout{display:grid;grid-template-columns:1.15fr .85fr;gap:14px;margin-bottom:14px}
.panel{border:1px solid #293039;background:#151a1f;border-radius:8px;overflow:hidden}
.panel h2{font-size:13px;margin:0;padding:10px 12px;border-bottom:1px solid #293039;background:#171d22}
.panel-body{padding:10px 12px;overflow:auto;max-height:330px}
canvas{width:100%;height:260px;display:block}
table{border-collapse:collapse;width:100%}
th,td{padding:7px 8px;border-bottom:1px solid #262d35;text-align:left;white-space:nowrap}
th{background:#171d22;color:#aeb9c5;font-size:11px;text-transform:uppercase;position:sticky;top:0;z-index:1}
tbody tr:hover{background:#1b2229}
.table-wrap{max-height:56vh;overflow:auto;border:1px solid #293039;border-radius:8px;background:#151a1f}
.num{text-align:right;font-variant-numeric:tabular-nums}
.reward{font-weight:700}
.good{color:#62c77b}
.mid{color:#d7b45d}
.bad{color:#e06d6d}
.muted{color:#8995a1}
.tag{display:inline-flex;align-items:center;height:20px;border:1px solid #3a424c;background:#1b2229;border-radius:999px;padding:0 7px}
.row-actions{display:flex;gap:6px}
.mdbox{width:100%;height:180px;background:#0d1013;color:#dfe6ee;border:1px solid #293039;border-radius:8px;padding:10px;font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:12px;resize:vertical}
.tiny{font-size:11px}
@media(max-width:1100px){.toolbar{grid-template-columns:repeat(2,1fr)}.stats{grid-template-columns:repeat(2,1fr)}.layout{grid-template-columns:1fr}}
</style>
</head>
<body>
<header>
  <h1>GameCraft-Bench Analysis</h1>
  <div class="actions">
    <button class="secondary" onclick="load()">Refresh</button>
    <button onclick="compare()">Compare selected</button>
    <button onclick="copyMarkdown()">Copy Markdown</button>
  </div>
</header>
<main>
  <section class="toolbar">
    <label>Run<select id="run-filter" onchange="render()"></select></label>
    <label>Family<select id="family-filter" onchange="render()"></select></label>
    <label>Task<select id="task-filter" onchange="render()"></select></label>
    <label>Agent<select id="agent-filter" onchange="render()"></select></label>
    <label>Model<select id="model-filter" onchange="render()"></select></label>
    <label>Status<select id="status-filter" onchange="render()"></select></label>
    <label>Search<input id="search" placeholder="trial id" oninput="render()"></label>
  </section>

  <section class="stats">
    <div class="stat"><div class="k">Trials</div><div class="v" id="stat-count">0</div></div>
    <div class="stat"><div class="k">Tasks</div><div class="v" id="stat-tasks">0</div></div>
    <div class="stat"><div class="k">Families</div><div class="v" id="stat-families">0</div></div>
    <div class="stat"><div class="k">Overall</div><div class="v" id="stat-mean">n/a</div></div>
    <div class="stat"><div class="k">M / D / V / A</div><div class="v tiny" id="stat-mdva">n/a</div></div>
    <div class="stat"><div class="k">Build OK</div><div class="v" id="stat-build">0%</div></div>
    <div class="stat"><div class="k">Scored</div><div class="v" id="stat-scored">0%</div></div>
    <div class="stat"><div class="k">Cost</div><div class="v" id="stat-cost">$0</div></div>
  </section>

  <section class="layout">
    <div class="panel"><h2>Family Scores</h2><canvas id="task-chart" width="900" height="260"></canvas></div>
    <div class="panel"><h2>Paper Matrix</h2><div id="paper-matrix" class="panel-body"></div></div>
  </section>

  <section class="layout">
    <div class="panel"><h2>Failure Decomposition</h2><div id="failure-summary" class="panel-body"></div></div>
    <div class="panel"><h2>Lowest Requirement Scores</h2><div id="requirement-summary" class="panel-body"></div></div>
  </section>

  <section class="table-wrap">
    <table id="tbl">
      <thead>
        <tr>
          <th><input type="checkbox" id="select-all" onchange="toggleAll()"></th>
          <th>Run</th><th>Family</th><th>Task</th><th>Agent</th><th>Model</th><th>Status</th><th>Stage</th>
          <th class="num">Reward</th><th class="num">Core</th><th class="num">Depth</th>
          <th class="num">Visual</th><th class="num">Art</th><th class="num">Low Req.</th>
          <th class="num">Demos</th><th class="num">Frames</th><th class="num">Cost</th><th>Action</th>
        </tr>
      </thead>
      <tbody></tbody>
    </table>
  </section>

  <section style="margin-top:14px" class="panel">
    <h2>Paper Export</h2>
    <textarea id="markdown" class="mdbox" readonly></textarea>
  </section>
</main>
<script>
let trials = [];
let filtered = [];
const METRICS = [
  {key:'M', label:'M', name:'Core Mechanics'},
  {key:'D', label:'D', name:'Content Depth'},
  {key:'V', label:'V', name:'Functional Visuals'},
  {key:'A', label:'A', name:'Presentation & Art'},
  {key:'Overall', label:'Overall', name:'Overall'},
];
const FAMILIES = ['Overall','Platformer','Strategy','Tycoon','Open-world','Roguelike','Visual novel','Puzzle','Shooter','Simulation','Card game','Horror','Rhythm','Idle','Racing','Sports'];

async function load() {
  const r = await fetch('/api/trials');
  trials = await r.json();
  populateFilters();
  render();
}

function populateFilters() {
  setOptions('run-filter', trials.map(t => t.run));
  setOptions('family-filter', trials.map(t => t.family));
  setOptions('task-filter', trials.map(t => t.task));
  setOptions('agent-filter', trials.map(t => t.agent));
  setOptions('model-filter', trials.map(t => t.model));
  setOptions('status-filter', trials.map(t => t.status));
}

function setOptions(id, values) {
  const el = document.getElementById(id);
  const prev = el.value;
  const unique = [...new Set(values.filter(Boolean))].sort();
  el.innerHTML = '<option value="">All</option>' + unique.map(v => `<option>${escapeHtml(v)}</option>`).join('');
  if (unique.includes(prev)) el.value = prev;
}

function render() {
  const f = {
    run: val('run-filter'), task: val('task-filter'), agent: val('agent-filter'),
    family: val('family-filter'), model: val('model-filter'), status: val('status-filter'),
    search: val('search').toLowerCase(),
  };
  filtered = trials.filter(t =>
    (!f.run || t.run === f.run) &&
    (!f.family || t.family === f.family) &&
    (!f.task || t.task === f.task) &&
    (!f.agent || t.agent === f.agent) &&
    (!f.model || t.model === f.model) &&
    (!f.status || t.status === f.status) &&
    (!f.search || t.trial_id.toLowerCase().includes(f.search))
  );
  renderStats();
  renderTable();
  renderPaperMatrix();
  renderFailureSummary();
  renderRequirementSummary();
  drawTaskChart();
  updateMarkdown();
}

function val(id) { return document.getElementById(id).value || ''; }
function nums(rows, key) { return rows.map(r => r[key]).filter(v => typeof v === 'number' && Number.isFinite(v)); }
function avg(values) { return values.length ? values.reduce((a,b)=>a+b,0)/values.length : null; }
function median(values) {
  if (!values.length) return null;
  const a = [...values].sort((x,y)=>x-y);
  const m = Math.floor(a.length / 2);
  return a.length % 2 ? a[m] : (a[m - 1] + a[m]) / 2;
}
function fmt(v, digits=3) { return typeof v === 'number' && Number.isFinite(v) ? v.toFixed(digits) : 'n/a'; }
function money(v) { return typeof v === 'number' && Number.isFinite(v) ? '$' + v.toFixed(2) : '$0'; }
function rewardClass(v) { return v >= 0.6 ? 'good' : v >= 0.3 ? 'mid' : 'bad'; }
function cat(t, name) { return (t.category_scores || {})[name]; }
function metric(t, key) {
  if (key === 'Overall') return t.reward;
  return (t.metric_scores || {})[key];
}
function pct(n, d) { return d ? Math.round(1000 * n / d) / 10 + '%' : 'n/a'; }
function sum(values) { return values.reduce((a,b)=>a+b,0); }
function std(values) {
  if (values.length < 2) return 0;
  const m = avg(values);
  return Math.sqrt(values.reduce((a,b)=>a + Math.pow(b - m, 2), 0) / (values.length - 1));
}

function renderStats() {
  const rewards = nums(filtered, 'reward');
  const buildKnown = filtered.filter(t => t.build_ok !== null && t.build_ok !== undefined);
  const buildOk = buildKnown.filter(t => t.build_ok === true).length;
  const scored = filtered.filter(t => typeof t.reward === 'number' && Number.isFinite(t.reward)).length;
  document.getElementById('stat-count').textContent = filtered.length;
  document.getElementById('stat-tasks').textContent = new Set(filtered.map(t => t.task).filter(Boolean)).size;
  document.getElementById('stat-families').textContent = new Set(filtered.map(t => t.family).filter(Boolean)).size;
  document.getElementById('stat-mean').textContent = fmt(avg(rewards));
  document.getElementById('stat-mdva').textContent = ['M','D','V','A'].map(k => `${k} ${fmt(avg(filtered.map(t => metric(t, k)).filter(Number.isFinite)), 2)}`).join(' / ');
  document.getElementById('stat-build').textContent = pct(buildOk, buildKnown.length);
  document.getElementById('stat-scored').textContent = pct(scored, filtered.length);
  document.getElementById('stat-cost').textContent = money(nums(filtered, 'cost_usd').reduce((a,b)=>a+b,0));
}

function renderTable() {
  const tbody = document.querySelector('#tbl tbody');
  tbody.innerHTML = '';
  filtered.forEach((t, i) => {
    const reward = fmt(t.reward);
    const cls = rewardClass(t.reward);
    const disabled = t.has_game ? '' : 'disabled';
    tbody.innerHTML += `<tr>
      <td><input type="checkbox" data-i="${i}"></td>
      <td title="${escapeHtml(t.trial_id)}">${escapeHtml(t.run)}</td>
      <td>${escapeHtml(t.family)}</td>
      <td>${escapeHtml(t.task)}</td>
      <td><span class="tag">${escapeHtml(t.agent)}</span></td>
      <td>${escapeHtml(t.model)}</td>
      <td>${statusCell(t)}</td>
      <td>${escapeHtml(t.failure_stage || '')}</td>
      <td class="reward ${cls}">${reward}</td>
      <td class="num">${fmt(cat(t, 'Core Mechanics'))}</td>
      <td class="num">${fmt(cat(t, 'Content Depth'))}</td>
      <td class="num">${fmt(cat(t, 'Functional Visuals'))}</td>
      <td class="num">${fmt(cat(t, 'Presentation & Art'))}</td>
      <td class="num">${(t.requirement_summary || {}).low ?? 0}</td>
      <td class="num">${t.demo_count || 0}</td>
      <td class="num">${t.frame_count || 0}</td>
      <td class="num">${t.cost_usd != null ? '$' + t.cost_usd.toFixed(2) : 'n/a'}</td>
      <td><div class="row-actions"><button ${disabled} onclick="play(${i})">Play</button></div></td>
    </tr>`;
  });
  document.getElementById('select-all').checked = false;
}

function statusCell(t) {
  if (t.status === 'errored') return `<span class="bad" title="${escapeHtml(t.exception || '')}">errored</span>`;
  if (t.status === 'no-game') return '<span class="mid">no-game</span>';
  if (t.status === 'build-failed') return '<span class="bad">build-failed</span>';
  if (t.status === 'verified') return '<span class="good">verified</span>';
  return '<span class="mid">generated</span>';
}

function modelLabel(t) {
  return `${t.agent || 'unknown'} / ${t.model || 'unknown'}`;
}

function aggregate(rows, family, metricKey) {
  const scoped = family === 'Overall' ? rows : rows.filter(t => t.family === family);
  return avg(scoped.map(t => metric(t, metricKey)).filter(Number.isFinite));
}

function renderPaperMatrix() {
  const groups = [...groupBy(filtered, modelLabel).entries()]
    .sort((a,b) => a[0].localeCompare(b[0]));
  if (!groups.length) {
    document.getElementById('paper-matrix').innerHTML = '<span class="muted">No rows.</span>';
    return;
  }
  const header = `<thead><tr><th>Model</th><th>Metric</th>${FAMILIES.map(f => `<th class="num">${escapeHtml(f)}</th>`).join('')}</tr></thead>`;
  const body = groups.map(([name, rows]) => {
    return METRICS.map((m, i) => `<tr>
      ${i === 0 ? `<td rowspan="${METRICS.length}">${escapeHtml(name)}</td>` : ''}
      <td>${m.label}</td>
      ${FAMILIES.map(f => `<td class="num">${fmt(aggregate(rows, f, m.key), 2)}</td>`).join('')}
    </tr>`).join('');
  }).join('');
  document.getElementById('paper-matrix').innerHTML = `<table>${header}<tbody>${body}</tbody></table>`;
}

function renderFailureSummary() {
  const stages = [...groupBy(filtered, t => t.failure_stage || 'unknown').entries()]
    .map(([stage, rows]) => ({stage, n: rows.length, pct: pct(rows.length, filtered.length)}))
    .sort((a,b) => b.n - a.n);
  const byFamily = [...groupBy(filtered, t => t.family || 'unknown').entries()]
    .map(([family, rows]) => ({
      family, n: rows.length,
      build: pct(rows.filter(t => t.build_ok === true).length, rows.filter(t => t.build_ok !== null && t.build_ok !== undefined).length),
      scored: pct(rows.filter(t => Number.isFinite(t.reward)).length, rows.length),
      reward: avg(nums(rows, 'reward')),
    }))
    .sort((a,b) => (a.reward ?? 9) - (b.reward ?? 9));
  document.getElementById('failure-summary').innerHTML = `
    <table><thead><tr><th>Stage</th><th class="num">N</th><th class="num">Share</th></tr></thead>
    <tbody>${stages.map(r => `<tr><td>${escapeHtml(r.stage)}</td><td class="num">${r.n}</td><td class="num">${r.pct}</td></tr>`).join('')}</tbody></table>
    <table style="margin-top:10px"><thead><tr><th>Family</th><th class="num">N</th><th class="num">Build</th><th class="num">Scored</th><th class="num">Overall</th></tr></thead>
    <tbody>${byFamily.map(r => `<tr><td>${escapeHtml(r.family)}</td><td class="num">${r.n}</td><td class="num">${r.build}</td><td class="num">${r.scored}</td><td class="num">${fmt(r.reward)}</td></tr>`).join('')}</tbody></table>`;
}

function renderRequirementSummary() {
  const reqRows = [];
  filtered.forEach(t => (t.requirements || []).forEach(r => {
    if (Number.isFinite(r.score)) reqRows.push({...r, task:t.task, family:t.family, model:modelLabel(t)});
  }));
  const low = reqRows.sort((a,b) => a.score - b.score).slice(0, 30);
  const byCategory = [...groupBy(reqRows, r => r.category || 'unknown').entries()]
    .map(([category, rows]) => ({
      category, n: rows.length, mean: avg(rows.map(r => r.score)), std: std(rows.map(r => r.score)),
      fail: rows.filter(r => r.score <= 0).length,
      low: rows.filter(r => r.score < 0.5).length,
    }))
    .sort((a,b) => (a.mean ?? 9) - (b.mean ?? 9));
  document.getElementById('requirement-summary').innerHTML = `
    <table><thead><tr><th>Category</th><th class="num">N</th><th class="num">Mean</th><th class="num">Std</th><th class="num">Fail</th><th class="num">Low</th></tr></thead>
    <tbody>${byCategory.map(r => `<tr><td>${escapeHtml(r.category)}</td><td class="num">${r.n}</td><td class="num">${fmt(r.mean)}</td><td class="num">${fmt(r.std)}</td><td class="num">${r.fail}</td><td class="num">${r.low}</td></tr>`).join('')}</tbody></table>
    <table style="margin-top:10px"><thead><tr><th>Task</th><th>Req.</th><th>Cat.</th><th class="num">Score</th><th>Model</th></tr></thead>
    <tbody>${low.map(r => `<tr><td>${escapeHtml(r.task)}</td><td title="${escapeHtml(r.description || '')}">${escapeHtml(r.id)}</td><td>${escapeHtml(r.category)}</td><td class="num">${fmt(r.score)}</td><td>${escapeHtml(r.model)}</td></tr>`).join('')}</tbody></table>`;
}

function groupBy(rows, keyFn) {
  const m = new Map();
  rows.forEach(r => {
    const k = keyFn(r);
    if (!m.has(k)) m.set(k, []);
    m.get(k).push(r);
  });
  return m;
}

function drawTaskChart() {
  const canvas = document.getElementById('task-chart');
  const ctx = canvas.getContext('2d');
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  const groups = [...groupBy(filtered, t => t.family || 'unknown').entries()]
    .map(([family, rows]) => ({family, value: avg(nums(rows, 'reward')), n: rows.length}))
    .filter(d => d.value != null)
    .sort((a,b) => b.value - a.value);
  const pad = {l: 150, r: 24, t: 22, b: 30};
  ctx.fillStyle = '#d9dee5';
  ctx.font = '12px Arial';
  ctx.strokeStyle = '#35404a';
  ctx.beginPath();
  ctx.moveTo(pad.l, pad.t);
  ctx.lineTo(pad.l, canvas.height - pad.b);
  ctx.lineTo(canvas.width - pad.r, canvas.height - pad.b);
  ctx.stroke();
  if (!groups.length) {
    ctx.fillStyle = '#8995a1';
    ctx.fillText('No scored trials', pad.l + 12, 60);
    return;
  }
  const barH = Math.min(28, (canvas.height - pad.t - pad.b - 10) / groups.length - 6);
  groups.forEach((d, i) => {
    const y = pad.t + 8 + i * (barH + 8);
    const w = (canvas.width - pad.l - pad.r) * Math.max(0, Math.min(1, d.value));
    ctx.fillStyle = '#8995a1';
    ctx.fillText(d.family, 12, y + barH * .7);
    ctx.fillStyle = d.value >= 0.6 ? '#62c77b' : d.value >= 0.3 ? '#d7b45d' : '#e06d6d';
    ctx.fillRect(pad.l, y, w, barH);
    ctx.fillStyle = '#d9dee5';
    ctx.fillText(`${fmt(d.value)} (${d.n})`, pad.l + w + 8, y + barH * .7);
  });
}

function play(i) {
  const t = filtered[i];
  if (!t || !t.has_game) return;
  window.open(`/play?trial_id=${encodeURIComponent(t.trial_id)}&game_dir=${encodeURIComponent(t.game_dir)}`, '_blank');
}

function compare() {
  const checked = selectedRows().filter(t => t.has_game);
  if (!checked.length) return;
  const params = checked.map(t => `trial_id=${encodeURIComponent(t.trial_id)}&game_dir=${encodeURIComponent(t.game_dir)}`).join('&');
  window.open(`/compare?${params}`, '_blank');
}

function toggleAll() {
  const checked = document.getElementById('select-all').checked;
  document.querySelectorAll('#tbl tbody input[type=checkbox]').forEach(el => el.checked = checked);
  updateMarkdown();
}

function selectedRows() {
  const checked = [...document.querySelectorAll('#tbl tbody input[type=checkbox]:checked')].map(el => parseInt(el.dataset.i));
  return checked.map(i => filtered[i]).filter(Boolean);
}

document.addEventListener('change', e => {
  if (e.target.matches('#tbl tbody input[type=checkbox]')) updateMarkdown();
});

function markdownRows() {
  const rows = selectedRows().length ? selectedRows() : filtered;
  const header = ['Family','Task','Agent','Model','Run','Overall','M','D','V','A','Build','Stage','LowReq','Demos'];
  const lines = [
    `Selected trials: ${rows.length}`,
    `Mean Overall: ${fmt(avg(nums(rows, 'reward')))}`,
    `Mean M/D/V/A: ${['M','D','V','A'].map(k => fmt(avg(rows.map(t => metric(t, k)).filter(Number.isFinite)))).join(' / ')}`,
    '',
    latexRows(rows),
    '',
    '| ' + header.join(' | ') + ' |',
    '| ' + header.map(() => '---').join(' | ') + ' |',
  ];
  rows.forEach(t => {
    lines.push('| ' + [
      t.family, t.task, t.agent, t.model, t.run, fmt(t.reward),
      fmt(metric(t, 'M')), fmt(metric(t, 'D')), fmt(metric(t, 'V')), fmt(metric(t, 'A')),
      t.build_ok, t.failure_stage, (t.requirement_summary || {}).low ?? 0, t.demo_count || 0,
    ].map(mdEscape).join(' | ') + ' |');
  });
  return lines.join('\\n');
}

function latexRows(rows) {
  const groups = [...groupBy(rows, modelLabel).entries()].sort((a,b) => a[0].localeCompare(b[0]));
  const lines = ['% LaTeX rows: Model, Metric, Overall + 15 families'];
  groups.forEach(([name, groupRows]) => {
    METRICS.forEach((m, i) => {
      const vals = FAMILIES.map(f => fmt(aggregate(groupRows, f, m.key), 2));
      const model = i === 0 ? latexEscape(name) : '';
      lines.push(`${model} & ${m.label} & ${vals.join(' & ')} \\\\`);
    });
    lines.push('\\\\midrule');
  });
  return lines.join('\\n');
}

function updateMarkdown() {
  document.getElementById('markdown').value = markdownRows();
}

async function copyMarkdown() {
  const text = markdownRows();
  document.getElementById('markdown').value = text;
  await navigator.clipboard.writeText(text);
}

function mdEscape(v) { return String(v ?? '').replaceAll('|', '\\\\|'); }
function latexEscape(v) {
  return String(v ?? '').replace(/[&%$#_{}]/g, c => '\\\\' + c).replaceAll('~', '\\\\textasciitilde{}').replaceAll('^', '\\\\textasciicircum{}');
}
function escapeHtml(v) {
  return String(v ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
}

load();
</script>
</body>
</html>
"""

_PLAY_HTML = """\
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Play</title>
<style>
body{margin:0;background:#000;display:flex;flex-direction:column;height:100vh}
#bar{background:#111;color:#ccc;font-family:monospace;padding:4px 10px;display:flex;gap:12px;align-items:center}
#bar button{background:#2a4a7f;color:#fff;border:none;padding:3px 8px;cursor:pointer;border-radius:3px}
iframe{flex:1;border:none;width:100%}
</style>
</head>
<body>
<div id="bar">
  <span id="label">Loading…</span>
  <button onclick="refresh()">Refresh</button>
  <button onclick="stop()">Stop</button>
</div>
<iframe id="vnc"></iframe>
<script>
const params = new URLSearchParams(location.search);
const trialId = params.get('trial_id');
const gameDir = params.get('game_dir');
let sid = null;

document.getElementById('label').textContent = trialId;

async function init() {
  const r = await fetch('/api/sessions', {method:'POST', headers:{'Content-Type':'application/json'},
    body: JSON.stringify({trial_id: trialId, game_dir: gameDir})});
  const d = await r.json();
  sid = d.sid;
  const wsUrl = `ws://${location.host}/ws/${sid}`;
  const vncUrl = `/vnc/${sid}`;
  document.getElementById('vnc').src = vncUrl;
}

async function refresh() {
  if (!sid) return;
  await fetch(`/api/sessions/${sid}/refresh`, {method:'POST', headers:{'Content-Type':'application/json'},
    body: JSON.stringify({game_dir: gameDir})});
}

async function stop() {
  if (!sid) return;
  await fetch(`/api/sessions/${sid}`, {method:'DELETE'});
  sid = null;
  document.getElementById('vnc').src = '';
}

window.addEventListener('beforeunload', () => {
  if (sid) navigator.sendBeacon(`/api/sessions/${sid}`, '');
});

init();
</script>
</body>
</html>
"""

_COMPARE_HTML = """\
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Compare</title>
<style>
body{margin:0;background:#000;display:flex;flex-direction:column;height:100vh}
#grid{display:grid;flex:1;gap:2px;background:#222}
.cell{display:flex;flex-direction:column;background:#000;overflow:hidden}
.cell-bar{background:#111;color:#ccc;font-family:monospace;font-size:11px;padding:2px 6px;display:flex;gap:8px;align-items:center;flex-shrink:0}
.cell-bar button{background:#2a4a7f;color:#fff;border:none;padding:1px 6px;cursor:pointer;border-radius:2px;font-size:10px}
iframe{flex:1;border:none;width:100%}
</style>
</head>
<body>
<div id="grid"></div>
<script>
const params = new URLSearchParams(location.search);
const trialIds = params.getAll('trial_id');
const gameDirs = params.getAll('game_dir');
const n = trialIds.length;
const cols = Math.ceil(Math.sqrt(n));
const rows = Math.ceil(n / cols);
const grid = document.getElementById('grid');
grid.style.gridTemplateColumns = `repeat(${cols}, 1fr)`;
grid.style.gridTemplateRows = `repeat(${rows}, 1fr)`;

const sids = {};

async function startOne(i) {
  const r = await fetch('/api/sessions', {method:'POST', headers:{'Content-Type':'application/json'},
    body: JSON.stringify({trial_id: trialIds[i], game_dir: gameDirs[i]})});
  const d = await r.json();
  sids[i] = d.sid;
  const vncUrl = `/vnc/${d.sid}`;
  document.getElementById(`vnc-${i}`).src = vncUrl;
}

async function refreshOne(i) {
  const sid = sids[i];
  if (!sid) return;
  await fetch(`/api/sessions/${sid}/refresh`, {method:'POST', headers:{'Content-Type':'application/json'},
    body: JSON.stringify({game_dir: gameDirs[i]})});
}

async function stopOne(i) {
  const sid = sids[i];
  if (!sid) return;
  await fetch(`/api/sessions/${sid}`, {method:'DELETE'});
  delete sids[i];
  document.getElementById(`vnc-${i}`).src = '';
}

for (let i = 0; i < n; i++) {
  const cell = document.createElement('div');
  cell.className = 'cell';
  cell.innerHTML = `
    <div class="cell-bar">
      <span>${trialIds[i]}</span>
      <button onclick="refreshOne(${i})">Refresh</button>
      <button onclick="stopOne(${i})">Stop</button>
    </div>
    <iframe id="vnc-${i}"></iframe>`;
  grid.appendChild(cell);
  startOne(i);
}

window.addEventListener('beforeunload', () => {
  Object.values(sids).forEach(sid => navigator.sendBeacon(`/api/sessions/${sid}`, ''));
});
</script>
</body>
</html>
"""


@app.get("/", response_class=HTMLResponse)
def index():
    return _INDEX_HTML


@app.get("/play", response_class=HTMLResponse)
def play_page():
    return _PLAY_HTML


@app.get("/compare", response_class=HTMLResponse)
def compare_page():
    return _COMPARE_HTML
