/**
 * Genesis Dashboard — Frontend Application
 * WebSocket client + real-time charts + gauge animations
 */

// ============================================================
// State
// ============================================================
const STATE = {
    ws: null,
    connected: false,
    config: null,
    cpuHistory: [],
    ramHistory: [],
    startTime: Date.now(),
    historyLength: 60,
};

const RING_CIRCUMFERENCE = 2 * Math.PI * 42; // ~263.9

// ============================================================
// DOM References
// ============================================================
const $ = (sel) => document.querySelector(sel);
const $$ = (sel) => document.querySelectorAll(sel);

const DOM = {
    connStatus: $('#connStatus'),
    connText: $('.conn-text'),
    uptime: $('#uptime'),
    cpuPercent: $('#cpuPercent'),
    cpuRing: $('#cpuRing'),
    cpuSub: $('#cpuSub'),
    cpuCard: $('#cpuCard'),
    ramPercent: $('#ramPercent'),
    ramRing: $('#ramRing'),
    ramSub: $('#ramSub'),
    ramCard: $('#ramCard'),
    gpuTemp: $('#gpuTemp'),
    gpuRing: $('#gpuRing'),
    gpuSub: $('#gpuSub'),
    diskSpeed: $('#diskSpeed'),
    diskRing: $('#diskRing'),
    diskSub: $('#diskSub'),
    coresChart: $('#coresChart'),
    boostStatus: $('#boostStatus'),
    boostToggle: $('#boostToggle'),
    threshValue: $('#threshValue'),
    threshDown: $('#threshDown'),
    threshUp: $('#threshUp'),
    boostMode: $('#boostMode'),
    boostInterval: $('#boostInterval'),
    intervalRow: $('#intervalRow'),
    boostLast: $('#boostLast'),
    boostNowBtn: $('#boostNowBtn'),
    mumuCount: $('#mumuCount'),
    mumuBody: $('#mumuBody'),
    historyChart: $('#historyChart'),
    logEntries: $('#logEntries'),
    clearLogBtn: $('#clearLogBtn'),
    procsBody: $('#procsBody'),
    netUpSpeed: $('#netUpSpeed'),
    netDownSpeed: $('#netDownSpeed'),
    netTotalUp: $('#netTotalUp'),
    netTotalDown: $('#netTotalDown'),
    toastContainer: $('#toastContainer'),
};

// ============================================================
// WebSocket Connection
// ============================================================
function connectWS() {
    const proto = location.protocol === 'https:' ? 'wss' : 'ws';
    const url = `${proto}://${location.host}/ws`;

    STATE.ws = new WebSocket(url);

    STATE.ws.onopen = () => {
        STATE.connected = true;
        DOM.connStatus.className = 'connection-status connected';
        DOM.connText.textContent = 'Connected';
    };

    STATE.ws.onclose = () => {
        STATE.connected = false;
        DOM.connStatus.className = 'connection-status disconnected';
        DOM.connText.textContent = 'Reconnecting...';
        setTimeout(connectWS, 2000);
    };

    STATE.ws.onerror = () => {
        STATE.ws.close();
    };

    STATE.ws.onmessage = (e) => {
        try {
            const data = JSON.parse(e.data);
            handleMessage(data);
        } catch (err) {
            console.error('WS parse error:', err);
        }
    };
}

function sendCommand(command, payload = {}) {
    if (STATE.ws && STATE.ws.readyState === WebSocket.OPEN) {
        STATE.ws.send(JSON.stringify({ command, ...payload }));
    }
}

// ============================================================
// Message Handler
// ============================================================
function handleMessage(data) {
    switch (data.type) {
        case 'init':
            STATE.config = data.config;
            applyConfig(data.config);
            if (data.history) renderHistory(data.history);
            break;
        case 'metrics':
            updateMetrics(data.metrics);
            updateMuMu(data.mumu);
            updateTopProcesses(data.top_processes);
            updateAutoBoostStatus(data.auto_boost);
            break;
        case 'boost_result':
            onBoostResult(data.result);
            break;
        case 'boost_triggered':
            onBoostResult(data.result);
            showToast('boost', `⚡ Auto-Boost — freed ${data.result.freed_mb} MB`);
            break;
        case 'config_updated':
            STATE.config = data.config;
            applyConfig(data.config);
            break;
    }
}

// ============================================================
// Config
// ============================================================
function applyConfig(cfg) {
    if (!cfg) return;
    const ab = cfg.auto_boost || {};

    // Toggle
    DOM.boostToggle.classList.toggle('active', ab.enabled);
    DOM.boostStatus.textContent = ab.enabled ? 'ARMED' : 'DISABLED';
    DOM.boostStatus.classList.toggle('disabled', !ab.enabled);

    // Threshold
    DOM.threshValue.textContent = ab.threshold_percent + '%';

    // Mode
    DOM.boostMode.value = ab.mode || 'auto';
    DOM.intervalRow.style.display = ab.mode === 'scheduled' ? 'flex' : 'none';

    // Interval
    DOM.boostInterval.value = String(ab.interval_minutes || 10);
}

// ============================================================
// Metrics Update
// ============================================================
function setRing(ringEl, percent, max = 100) {
    const ratio = Math.min(percent / max, 1);
    const offset = RING_CIRCUMFERENCE * (1 - ratio);
    ringEl.style.strokeDashoffset = offset;
}

function updateMetrics(m) {
    if (!m) return;

    // CPU
    const cpuTotal = Math.round(m.cpu.total_percent);
    DOM.cpuPercent.textContent = cpuTotal;
    setRing(DOM.cpuRing, cpuTotal);
    DOM.cpuSub.textContent = `${m.cpu.core_count} Threads`;

    // RAM
    const ramPct = Math.round(m.ram.percent);
    DOM.ramPercent.textContent = ramPct;
    setRing(DOM.ramRing, ramPct);
    DOM.ramSub.textContent = `${m.ram.used_gb} / ${m.ram.total_gb} GB`;

    // RAM warning state
    DOM.ramCard.classList.remove('warning', 'critical');
    if (ramPct >= 90) DOM.ramCard.classList.add('critical');
    else if (ramPct >= 80) DOM.ramCard.classList.add('warning');

    // GPU
    if (m.gpu && m.gpu.available) {
        DOM.gpuTemp.textContent = m.gpu.temperature_c;
        setRing(DOM.gpuRing, m.gpu.utilization_percent);
        DOM.gpuSub.textContent = m.gpu.name || 'RTX 3050';
    } else {
        DOM.gpuTemp.textContent = '--';
        setRing(DOM.gpuRing, 0);
        DOM.gpuSub.textContent = 'N/A';
    }

    // Disk
    const diskRead = m.disk.read_speed_mbs || 0;
    const diskWrite = m.disk.write_speed_mbs || 0;
    const diskTotal = Math.round((diskRead + diskWrite) * 10) / 10;
    DOM.diskSpeed.textContent = diskTotal;
    setRing(DOM.diskRing, Math.min(diskTotal, 100), 100);
    DOM.diskSub.textContent = `R: ${diskRead.toFixed(1)} / W: ${diskWrite.toFixed(1)}`;

    // Network
    DOM.netUpSpeed.textContent = `${(m.network.sent_speed_mbs || 0).toFixed(2)} MB/s`;
    DOM.netDownSpeed.textContent = `${(m.network.recv_speed_mbs || 0).toFixed(2)} MB/s`;
    DOM.netTotalUp.textContent = `${m.network.sent_mb} MB`;
    DOM.netTotalDown.textContent = `${m.network.recv_mb} MB`;

    // CPU Per-Core Bars
    updateCoreBars(m.cpu);

    // History
    STATE.cpuHistory.push(cpuTotal);
    STATE.ramHistory.push(ramPct);
    if (STATE.cpuHistory.length > STATE.historyLength) STATE.cpuHistory.shift();
    if (STATE.ramHistory.length > STATE.historyLength) STATE.ramHistory.shift();
    drawHistoryChart();
}

// ============================================================
// CPU Per-Core Bars
// ============================================================
let coresInitialized = false;

function updateCoreBars(cpu) {
    const allCores = cpu.per_core || [];
    const count = allCores.length;

    if (!coresInitialized || DOM.coresChart.children.length !== count) {
        DOM.coresChart.innerHTML = '';
        DOM.coresChart.style.gridTemplateColumns = `repeat(${count}, 1fr)`;
        for (let i = 0; i < count; i++) {
            const wrap = document.createElement('div');
            wrap.className = 'core-bar-wrap';

            const bar = document.createElement('div');
            bar.className = `core-bar ${i < 8 ? 'p-core' : 'e-core'}`;
            bar.style.height = '2px';

            const label = document.createElement('span');
            label.className = 'core-label';
            label.textContent = i;

            wrap.appendChild(bar);
            wrap.appendChild(label);
            DOM.coresChart.appendChild(wrap);
        }
        coresInitialized = true;
    }

    const wraps = DOM.coresChart.querySelectorAll('.core-bar');
    for (let i = 0; i < count; i++) {
        const pct = allCores[i] || 0;
        if (wraps[i]) {
            wraps[i].style.height = `${Math.max(pct, 2)}%`;
        }
    }
}

// ============================================================
// History Chart (Canvas)
// ============================================================
function drawHistoryChart() {
    const canvas = DOM.historyChart;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    const dpr = window.devicePixelRatio || 1;
    const rect = canvas.getBoundingClientRect();

    canvas.width = rect.width * dpr;
    canvas.height = rect.height * dpr;
    ctx.scale(dpr, dpr);

    const w = rect.width;
    const h = rect.height;
    const padTop = 10;
    const padBot = 20;
    const plotH = h - padTop - padBot;

    // Background
    ctx.fillStyle = '#0D0D14';
    ctx.fillRect(0, 0, w, h);

    // Grid lines
    ctx.strokeStyle = '#1A1A24';
    ctx.lineWidth = 1;
    for (let i = 0; i <= 4; i++) {
        const y = padTop + (plotH / 4) * i;
        ctx.beginPath();
        ctx.moveTo(0, y);
        ctx.lineTo(w, y);
        ctx.stroke();

        ctx.fillStyle = '#55556A';
        ctx.font = '10px "JetBrains Mono", monospace';
        ctx.fillText(`${100 - i * 25}%`, 4, y - 3);
    }

    // Draw line helper
    function drawLine(data, color, glowColor) {
        if (data.length < 2) return;
        const step = w / (STATE.historyLength - 1);

        // Glow
        ctx.beginPath();
        ctx.strokeStyle = glowColor;
        ctx.lineWidth = 6;
        ctx.lineJoin = 'round';
        for (let i = 0; i < data.length; i++) {
            const x = i * step;
            const y = padTop + plotH * (1 - data[i] / 100);
            if (i === 0) ctx.moveTo(x, y);
            else ctx.lineTo(x, y);
        }
        ctx.stroke();

        // Line
        ctx.beginPath();
        ctx.strokeStyle = color;
        ctx.lineWidth = 2;
        ctx.lineJoin = 'round';
        for (let i = 0; i < data.length; i++) {
            const x = i * step;
            const y = padTop + plotH * (1 - data[i] / 100);
            if (i === 0) ctx.moveTo(x, y);
            else ctx.lineTo(x, y);
        }
        ctx.stroke();

        // Fill gradient
        ctx.beginPath();
        for (let i = 0; i < data.length; i++) {
            const x = i * step;
            const y = padTop + plotH * (1 - data[i] / 100);
            if (i === 0) ctx.moveTo(x, y);
            else ctx.lineTo(x, y);
        }
        ctx.lineTo((data.length - 1) * step, padTop + plotH);
        ctx.lineTo(0, padTop + plotH);
        ctx.closePath();

        const grad = ctx.createLinearGradient(0, padTop, 0, padTop + plotH);
        grad.addColorStop(0, glowColor);
        grad.addColorStop(1, 'transparent');
        ctx.fillStyle = grad;
        ctx.fill();
    }

    drawLine(STATE.cpuHistory, '#FF3C3C', 'rgba(255,60,60,0.12)');
    drawLine(STATE.ramHistory, '#60A5FA', 'rgba(96,165,250,0.12)');

    // Legend
    const legendY = h - 6;
    ctx.font = '11px "Inter", sans-serif';
    ctx.fillStyle = '#FF3C3C';
    ctx.fillText('● CPU', w - 130, legendY);
    ctx.fillStyle = '#60A5FA';
    ctx.fillText('● RAM', w - 60, legendY);
}

// ============================================================
// MuMu Instances
// ============================================================
function updateMuMu(mumu) {
    if (!mumu) return;

    const devices = mumu.devices || [];
    const launchers = mumu.launchers || [];
    const all = [...devices, ...launchers];

    DOM.mumuCount.textContent = `${devices.length} instance${devices.length !== 1 ? 's' : ''} running`;

    if (all.length === 0) {
        DOM.mumuBody.innerHTML = '<tr class="mumu-empty"><td colspan="6">No instances detected</td></tr>';
        return;
    }

    DOM.mumuBody.innerHTML = all.map((inst, i) => {
        const isDevice = inst.name.toLowerCase().includes('device');
        const type = isDevice ? 'Emulator' : 'Launcher';
        return `
            <tr>
                <td>${i + 1}</td>
                <td>${type}</td>
                <td>${inst.cpu_percent}%</td>
                <td>${inst.ram_mb} MB</td>
                <td>${inst.uptime}</td>
                <td><span class="status-dot running"></span>OK</td>
            </tr>
        `;
    }).join('');
}

// ============================================================
// Top Processes
// ============================================================
function updateTopProcesses(procs) {
    if (!procs || !DOM.procsBody) return;

    DOM.procsBody.innerHTML = procs.map((p) => `
        <tr>
            <td>${escapeHtml(p.name)}</td>
            <td>${p.pid}</td>
            <td>${p.ram_mb} MB</td>
            <td>${p.cpu_percent}%</td>
        </tr>
    `).join('');
}

// ============================================================
// Auto-Boost Status
// ============================================================
function updateAutoBoostStatus(ab) {
    if (!ab) return;

    if (ab.last_boost_time) {
        const res = ab.last_boost_result;
        DOM.boostLast.textContent = `Last boost: ${ab.last_boost_time}${res ? ` — freed ${res.freed_mb} MB` : ''}`;
    }
}

// ============================================================
// Boost Result Handler
// ============================================================
function onBoostResult(result) {
    if (!result) return;
    DOM.boostNowBtn.classList.add('boosting');
    setTimeout(() => DOM.boostNowBtn.classList.remove('boosting'), 600);

    const msg = `Freed ${result.freed_mb} MB (${result.processes_trimmed} processes trimmed)`;
    DOM.boostLast.textContent = `Last boost: now — ${msg}`;
    addLogEntry({ time: new Date().toLocaleTimeString(), type: 'boost', message: msg });
}

// ============================================================
// Event Log
// ============================================================
const EVENT_ICONS = {
    boost: '⚡',
    warning: '⚠️',
    crash: '🔴',
    system: '🔵',
    kill: '💀',
    error: '❌',
};

function renderHistory(events) {
    DOM.logEntries.innerHTML = '';
    events.forEach(addLogEntry);
}

function addLogEntry(entry) {
    const empty = DOM.logEntries.querySelector('.log-empty');
    if (empty) empty.remove();

    const div = document.createElement('div');
    div.className = 'log-entry';
    div.innerHTML = `
        <span class="log-time">${entry.time}</span>
        <span class="log-icon">${EVENT_ICONS[entry.type] || '📋'}</span>
        <span class="log-message">${escapeHtml(entry.message)}</span>
    `;

    DOM.logEntries.prepend(div);

    // Limit DOM entries
    while (DOM.logEntries.children.length > 100) {
        DOM.logEntries.lastChild.remove();
    }
}

// ============================================================
// Toast Notifications
// ============================================================
function showToast(type, message) {
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.innerHTML = `
        <span class="toast-icon">${EVENT_ICONS[type] || '📋'}</span>
        <span class="toast-text">${escapeHtml(message)}</span>
    `;
    DOM.toastContainer.appendChild(toast);

    setTimeout(() => {
        toast.style.animation = 'toastOut 0.4s ease forwards';
        setTimeout(() => toast.remove(), 400);
    }, 4000);
}

// ============================================================
// Event Handlers
// ============================================================
function setupEventHandlers() {
    // Boost Now
    DOM.boostNowBtn.addEventListener('click', () => {
        sendCommand('boost');
        DOM.boostNowBtn.classList.add('boosting');
        setTimeout(() => DOM.boostNowBtn.classList.remove('boosting'), 600);
    });

    // Toggle
    DOM.boostToggle.addEventListener('click', () => {
        const isActive = DOM.boostToggle.classList.toggle('active');
        sendCommand('update_config', { config: { enabled: isActive } });
    });

    // Threshold
    DOM.threshDown.addEventListener('click', () => {
        let val = parseInt(DOM.threshValue.textContent) || 85;
        val = Math.max(val - 5, 50);
        DOM.threshValue.textContent = val + '%';
        sendCommand('update_config', { config: { threshold_percent: val } });
    });

    DOM.threshUp.addEventListener('click', () => {
        let val = parseInt(DOM.threshValue.textContent) || 85;
        val = Math.min(val + 5, 95);
        DOM.threshValue.textContent = val + '%';
        sendCommand('update_config', { config: { threshold_percent: val } });
    });

    // Mode
    DOM.boostMode.addEventListener('change', () => {
        const mode = DOM.boostMode.value;
        DOM.intervalRow.style.display = mode === 'scheduled' ? 'flex' : 'none';
        sendCommand('update_config', { config: { mode } });
    });

    // Interval
    DOM.boostInterval.addEventListener('change', () => {
        sendCommand('update_config', { config: { interval_minutes: parseInt(DOM.boostInterval.value) } });
    });

    // Clear Log
    DOM.clearLogBtn.addEventListener('click', () => {
        DOM.logEntries.innerHTML = '<div class="log-empty">No events yet</div>';
    });
}

// ============================================================
// Uptime Timer
// ============================================================
function updateUptime() {
    const elapsed = Math.floor((Date.now() - STATE.startTime) / 1000);
    const h = String(Math.floor(elapsed / 3600)).padStart(2, '0');
    const m = String(Math.floor((elapsed % 3600) / 60)).padStart(2, '0');
    const s = String(elapsed % 60).padStart(2, '0');
    DOM.uptime.textContent = `${h}:${m}:${s}`;
}

// ============================================================
// Utilities
// ============================================================
function escapeHtml(str) {
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
}

// ============================================================
// Init
// ============================================================
function init() {
    setupEventHandlers();
    connectWS();
    setInterval(updateUptime, 1000);

    // Resize chart on window resize
    window.addEventListener('resize', drawHistoryChart);
}

document.addEventListener('DOMContentLoaded', init);
