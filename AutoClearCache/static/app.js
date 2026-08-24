/**
 * Genesis Dashboard v2.1 — Frontend Application
 * WebSocket client + real-time charts + gauge animations
 * Fable 5 Hardened Maintenance Engine UI & PIN Security
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
    chartTimestamps: [],
    chartZoom: 30, // 5, 15, or 30 mins
    chartHoverIndex: -1,
    chartHoverX: -1,
    startTime: Date.now(),
    historyLength: 60,
    deepCleanPreview: [],
    token: localStorage.getItem('genesis_auth_token') || '',
    authenticated: false,
    authRequired: false,
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
    authBadge: $('#authBadge'),
    authText: $('#authText'),
    authModal: $('#authModal'),
    pinInput: $('#pinInput'),
    pinSubmitBtn: $('#pinSubmitBtn'),
    authErrorMsg: $('#authErrorMsg'),
    cpuPercent: $('#cpuPercent'),
    cpuRing: $('#cpuRing'),
    cpuSub: $('#cpuSub'),
    cpuCard: $('#cpuCard'),
    ramPercent: $('#ramPercent'),
    ramRing: $('#ramRing'),
    ramSub: $('#ramSub'),
    ramCard: $('#ramCard'),
    ramBarActive: $('#ramBarActive'),
    ramBarStandby: $('#ramBarStandby'),
    ramActiveVal: $('#ramActiveVal'),
    ramStandbyVal: $('#ramStandbyVal'),
    ramFreeVal: $('#ramFreeVal'),
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
    // Module 2: Hardening (4 items)
    hardeningRefreshBtn: $('#hardeningRefreshBtn'),
    hardenVBS: $('#hardenVBS'),
    hardenMPO: $('#hardenMPO'),
    hardenHypervisor: $('#hardenHypervisor'),
    hardenExclusion: $('#hardenExclusion'),
    hardeningLastCheck: $('#hardeningLastCheck'),
    // Module 4: Deep Clean
    deepCleanScanBtn: $('#deepCleanScanBtn'),
    deepCleanExecBtn: $('#deepCleanExecBtn'),
    deepCleanPreview: $('#deepCleanPreview'),
    deepCleanTotal: $('#deepCleanTotal'),
    deepCleanTotalSize: $('#deepCleanTotalSize'),
    deepCleanTotalFiles: $('#deepCleanTotalFiles'),
    // Module 7: Defender
    quickScanBtn: $('#quickScanBtn'),
    defSigAge: $('#defSigAge'),
    defQuickAge: $('#defQuickAge'),
    defRealtime: $('#defRealtime'),
    defSweep: $('#defSweep'),
    // Module 8: Network Observatory
    flushDnsBtn: $('#flushDnsBtn'),
    netQualityBadge: $('#netQualityBadge'),
    netLatencyVal: $('#netLatencyVal'),
    netJitterVal: $('#netJitterVal'),
    netLossVal: $('#netLossVal'),
    wifiBand: $('#wifiBand'),
    wifiSsid: $('#wifiSsid'),
    wifiSignalVal: $('#wifiSignalVal'),
    wifiDbmVal: $('#wifiDbmVal'),
    wifiRateVal: $('#wifiRateVal'),
    watchdogBadge: $('#watchdogBadge'),
    watchdogStatusText: $('#watchdogStatusText'),
    watchdogRecoveriesVal: $('#watchdogRecoveriesVal'),
    toggleWatchdogLogs: $('#toggleWatchdogLogs'),
    watchdogLogPanel: $('#watchdogLogPanel'),
    watchdogHeartbeat: $('#watchdogHeartbeat'),
    watchdogLogConsole: $('#watchdogLogConsole'),
    // Summary Card (v2.5)
    sumUptime: $('#sumUptime'),
    sumBoosts: $('#sumBoosts'),
    sumTotalBoosts: $('#sumTotalBoosts'),
    btnResetBoosts: $('#btnResetBoosts'),
    btnResetTotalBoosts: $('#btnResetTotalBoosts'),
    sumStandbyPurges: $('#sumStandbyPurges'),
    sumStandbyReclaimed: $('#sumStandbyReclaimed'),
    sumStorageFree: $('#sumStorageFree'),
    sumStoragePercent: $('#sumStoragePercent'),
    sumRecoveries: $('#sumRecoveries'),
    sumLastClean: $('#sumLastClean'),
    sumHardening: $('#sumHardening'),
    // History Chart Controls & Tooltip
    chartTooltip: $('#chartTooltip'),
    chartTimeLabel: $('#chartTimeLabel'),
    chartZoomBtns: $$('.chart-zoom-btn'),
    // Wi-Fi RF Quality Pill
    wifiQualityPill: $('#wifiQualityPill'),
};

// ============================================================
// WebSocket Connection & Auth Handshake
// ============================================================
function connectWS() {
    const proto = location.protocol === 'https:' ? 'wss' : 'ws';
    const tokenQuery = STATE.token ? `?token=${encodeURIComponent(STATE.token)}` : '';
    const url = `${proto}://${location.host}/ws${tokenQuery}`;

    STATE.ws = new WebSocket(url);

    STATE.ws.onopen = () => {
        STATE.connected = true;
        DOM.connStatus.className = 'connection-status connected';
        DOM.connText.textContent = 'Connected';
        if (STATE.token) {
            sendCommand('auth', { token: STATE.token });
        }
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
        STATE.ws.send(JSON.stringify({ command, token: STATE.token, ...payload }));
    }
}

// ============================================================
// Message Handler
// ============================================================
function handleMessage(data) {
    switch (data.type) {
        case 'init':
            STATE.config = data.config;
            STATE.authRequired = data.auth_required;
            setAuthState(data.authenticated);
            applyConfig(data.config);
            if (data.history) renderHistory(data.history);
            if (data.hardening) updateHardeningStatus(data.hardening);
            if (data.defender) updateDefenderStatus(data.defender);
            if (data.vm_disk) updateVmDiskData(data.vm_disk);
            if (data.observatory) updateNetworkObservatory(data.observatory);
            if (data.summary) updateSessionSummary(data.summary);
            if (data.chart_history) {
                if (data.chart_history.cpu && data.chart_history.cpu.length > 0) {
                    STATE.cpuHistory = [...data.chart_history.cpu];
                }
                if (data.chart_history.ram && data.chart_history.ram.length > 0) {
                    STATE.ramHistory = [...data.chart_history.ram];
                }
                const now = Date.now();
                STATE.chartTimestamps = STATE.cpuHistory.map((_, i) => now - (STATE.cpuHistory.length - 1 - i) * 30000);
                drawHistoryChart();
            }
            // If defender data was empty on init, request fresh status
            if (!data.defender || !data.defender.available) {
                setTimeout(() => sendCommand('get_defender_status'), 3000);
            }
            break;
        case 'auth_success':
            setAuthState(true);
            showToast('system', '🔑 Dashboard control unlocked');
            sendCommand('check_hardening');
            sendCommand('get_defender_status');
            break;
        case 'auth_failed':
        case 'auth_required':
            setAuthState(false);
            showAuthModal(true);
            break;
        case 'metrics':
            updateMetrics(data.metrics);
            updateMuMu(data.mumu);
            updateTopProcesses(data.top_processes);
            updateAutoBoostStatus(data.auto_boost);
            if (data.observatory) updateNetworkObservatory(data.observatory);
            if (data.summary) updateSessionSummary(data.summary);
            break;
        case 'boost_result':
        case 'boost_triggered':
            if (DOM.boostNowBtn) DOM.boostNowBtn.classList.remove('boosting');
            onBoostResult(data.result);
            if (data.type === 'boost_triggered') {
                const tempStr = data.result && data.result.freed_temp_mb > 0 ? ` + ${data.result.freed_temp_mb}MB Temp` : '';
                const standbyStr = data.result && data.result.standby_purged ? ' + Standby Purged' : '';
                showToast('boost', `⚡ Auto-Boost — freed ${data.result.freed_mb} MB RAM${standbyStr}${tempStr}`);
            }
            break;
        case 'config_updated':
            STATE.config = data.config;
            applyConfig(data.config);
            break;
        case 'hardening_status':
            if (DOM.hardeningRefreshBtn) DOM.hardeningRefreshBtn.classList.remove('spinning');
            updateHardeningStatus(data.data);
            break;
        case 'vm_disk_status':
            updateVmDiskData(data.data);
            break;
        case 'deep_clean_preview':
            if (DOM.deepCleanScanBtn) {
                DOM.deepCleanScanBtn.textContent = 'Scan';
                DOM.deepCleanScanBtn.disabled = false;
            }
            renderDeepCleanPreview(data.data);
            break;
        case 'deep_clean_result':
            onDeepCleanResult(data.data);
            break;
        case 'defender_status':
            updateDefenderStatus(data.data);
            break;
        case 'quick_scan_result':
            if (DOM.quickScanBtn) {
                DOM.quickScanBtn.textContent = 'Quick Scan';
                DOM.quickScanBtn.disabled = false;
            }
            showToast('system', data.success ? '🔒 Quick Scan started in background' : '❌ Quick Scan failed');
            // Refresh defender card to show updated scan age
            if (data.success) {
                setTimeout(() => sendCommand('get_defender_status'), 5000);
            }
            break;
        case 'vm_trim_result':
            showToast('system', data.success ? `📱 VM cache trimmed (port ${data.port})` : '❌ VM trim failed');
            break;
        case 'flush_dns_result':
            if (DOM.flushDnsBtn) {
                DOM.flushDnsBtn.textContent = 'Flush DNS';
                DOM.flushDnsBtn.disabled = false;
            }
            showToast('system', data.success ? '🧹 DNS Resolver cache flushed' : '❌ Failed to flush DNS');
            break;
        case 'observatory_update':
            updateNetworkObservatory(data.data);
            break;
        case 'session_summary':
            updateSessionSummary(data.data);
            break;
        case 'session_boost_reset':
        case 'boost_counter_reset':
            updateSessionSummary(data.data);
            showToast('system', '↺ Session Boosts Reset to 0 (Total preserved)');
            break;
        case 'total_boost_reset':
            updateSessionSummary(data.data);
            showToast('system', '🗑️ Lifetime Total Boosts Reset to 0');
            break;
        case 'mumu_trim_result':
            if (data.data && data.data.success) {
                showToast('system', `↺ Trimmed working set for ${data.data.name || 'MuMu'} (freed ${data.data.freed_mb} MB)`);
            } else {
                showToast('system', `❌ Failed to trim instance: ${data.data ? data.data.error : 'Unknown'}`);
            }
            break;
    }
}

// ============================================================
// Auth State Management
// ============================================================
function setAuthState(isAuthed) {
    STATE.authenticated = isAuthed;
    if (DOM.authBadge) {
        if (!STATE.authRequired) {
            DOM.authBadge.style.display = 'none';
        } else {
            DOM.authBadge.style.display = 'flex';
            DOM.authBadge.className = `auth-badge ${isAuthed ? 'unlocked' : 'locked'}`;
            DOM.authText.textContent = isAuthed ? 'Unlocked' : 'Locked';
        }
    }
    if (isAuthed) {
        showAuthModal(false);
    }
}

function showAuthModal(show) {
    if (DOM.authModal) {
        DOM.authModal.style.display = show ? 'flex' : 'none';
        if (show && DOM.pinInput) {
            DOM.pinInput.value = '';
            DOM.authErrorMsg.textContent = '';
            DOM.pinInput.focus();
        }
    }
}

async function submitPin() {
    const pin = DOM.pinInput.value.trim();
    if (!pin) return;

    try {
        DOM.pinSubmitBtn.textContent = 'Verifying...';
        DOM.pinSubmitBtn.disabled = true;

        const res = await fetch('/api/auth/login', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ pin }),
        });
        const data = await res.json();

        if (res.ok && data.token) {
            STATE.token = data.token;
            localStorage.setItem('genesis_auth_token', data.token);
            sendCommand('auth', { token: data.token });
            setAuthState(true);
        } else {
            DOM.authErrorMsg.textContent = data.error || 'Invalid PIN code';
            DOM.pinInput.value = '';
            DOM.pinInput.focus();
        }
    } catch (err) {
        DOM.authErrorMsg.textContent = 'Network error during verification';
    } finally {
        DOM.pinSubmitBtn.textContent = 'Unlock Dashboard';
        DOM.pinSubmitBtn.disabled = false;
    }
}

// ============================================================
// Config
// ============================================================
function applyConfig(cfg) {
    if (!cfg) return;
    const ab = cfg.auto_boost || {};

    DOM.boostToggle.classList.toggle('active', ab.enabled);
    DOM.boostStatus.textContent = ab.enabled ? 'ARMED' : 'DISABLED';
    DOM.boostStatus.classList.toggle('disabled', !ab.enabled);
    DOM.threshValue.textContent = ab.threshold_percent + '%';
    DOM.boostMode.value = ab.mode || 'auto';
    DOM.intervalRow.style.display = ab.mode === 'scheduled' ? 'flex' : 'none';
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

    const cpuTotal = Math.round(m.cpu.total_percent);
    DOM.cpuPercent.textContent = cpuTotal;
    setRing(DOM.cpuRing, cpuTotal);
    DOM.cpuSub.textContent = `${m.cpu.core_count} Threads`;

    const ramPct = Math.round(m.ram.percent);
    DOM.ramPercent.textContent = ramPct;
    setRing(DOM.ramRing, ramPct);
    DOM.ramSub.textContent = `${m.ram.used_gb} / ${m.ram.total_gb} GB`;

    if (m.ram.breakdown) {
        const b = m.ram.breakdown;
        const total = b.total_gb || 1;
        const activePct = (b.active_gb / total) * 100;
        const standbyPct = (b.standby_gb / total) * 100;
        DOM.ramBarActive.style.width = `${activePct}%`;
        DOM.ramBarStandby.style.width = `${standbyPct}%`;
        DOM.ramActiveVal.textContent = b.active_gb;
        DOM.ramStandbyVal.textContent = b.standby_gb;
        DOM.ramFreeVal.textContent = b.free_gb;
    }

    DOM.ramCard.classList.remove('warning', 'critical');
    if (ramPct >= 90) DOM.ramCard.classList.add('critical');
    else if (ramPct >= 80) DOM.ramCard.classList.add('warning');

    if (m.gpu && m.gpu.available) {
        DOM.gpuTemp.textContent = m.gpu.temperature_c;
        setRing(DOM.gpuRing, m.gpu.utilization_percent);
        DOM.gpuSub.textContent = m.gpu.name || 'RTX 3050';
    } else {
        DOM.gpuTemp.textContent = '--';
        setRing(DOM.gpuRing, 0);
        DOM.gpuSub.textContent = 'N/A';
    }

    const diskRead = m.disk.read_speed_mbs || 0;
    const diskWrite = m.disk.write_speed_mbs || 0;
    const diskTotal = Math.round((diskRead + diskWrite) * 10) / 10;
    DOM.diskSpeed.textContent = diskTotal;
    setRing(DOM.diskRing, Math.min(diskTotal, 100), 100);
    DOM.diskSub.textContent = `R: ${diskRead.toFixed(1)} / W: ${diskWrite.toFixed(1)}`;

    DOM.netUpSpeed.textContent = `${(m.network.sent_speed_mbs || 0).toFixed(2)} MB/s`;
    DOM.netDownSpeed.textContent = `${(m.network.recv_speed_mbs || 0).toFixed(2)} MB/s`;
    DOM.netTotalUp.textContent = `${m.network.sent_mb} MB`;
    DOM.netTotalDown.textContent = `${m.network.recv_mb} MB`;

    if (m.storage && m.storage.c_drive) {
        const c = m.storage.c_drive;
        if (DOM.sumStorageFree) {
            DOM.sumStorageFree.textContent = `${c.free_gb} GB`;
            DOM.sumStorageFree.className = c.is_low ? 'summary-val critical' : (c.free_gb < 30.0 ? 'summary-val warning' : 'summary-val');
        }
        if (DOM.sumStoragePercent) {
            DOM.sumStoragePercent.textContent = `${c.percent}% Used`;
        }
    }

    updateCoreBars(m.cpu);

    // 30-Minute Chart Downsampling (Sample every 30s or on empty)
    pushChartSample(cpuTotal, ramPct);
}

let lastChartSampleTime = 0;

function pushChartSample(cpuTotal, ramPct) {
    const now = Date.now();
    if (now - lastChartSampleTime >= 30000 || STATE.cpuHistory.length === 0) {
        STATE.cpuHistory.push(cpuTotal);
        STATE.ramHistory.push(ramPct);
        STATE.chartTimestamps.push(now);
        if (STATE.cpuHistory.length > 60) STATE.cpuHistory.shift();
        if (STATE.ramHistory.length > 60) STATE.ramHistory.shift();
        if (STATE.chartTimestamps.length > 60) STATE.chartTimestamps.shift();
        lastChartSampleTime = now;
        drawHistoryChart();
    }
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
// History Chart (Canvas with Zoom & Interactive Inspection)
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
    const padTop = 14;
    const padBot = 28;
    const padLeft = 32;
    const padRight = 14;
    const plotW = Math.max(w - padLeft - padRight, 10);
    const plotH = Math.max(h - padTop - padBot, 10);

    ctx.fillStyle = '#0D0D14';
    ctx.fillRect(0, 0, w, h);

    // Determine data slice based on zoom
    let pointsCount = 60;
    if (STATE.chartZoom === 5) pointsCount = 10;
    else if (STATE.chartZoom === 15) pointsCount = 30;
    else pointsCount = 60;

    const fullLen = STATE.cpuHistory.length;
    const startIndex = Math.max(0, fullLen - pointsCount);
    const cpuData = STATE.cpuHistory.slice(startIndex);
    const ramData = STATE.ramHistory.slice(startIndex);
    let timeData = (STATE.chartTimestamps || []).slice(startIndex);

    const now = Date.now();
    while (timeData.length < cpuData.length) {
        timeData.unshift(now - (cpuData.length - timeData.length) * 30000);
    }

    // 1. Horizontal Percentage Grid Lines
    ctx.strokeStyle = '#181824';
    ctx.lineWidth = 1;
    for (let i = 0; i <= 4; i++) {
        const y = padTop + (plotH / 4) * i;
        ctx.beginPath();
        ctx.moveTo(padLeft, y);
        ctx.lineTo(padLeft + plotW, y);
        ctx.stroke();

        ctx.fillStyle = '#55556A';
        ctx.font = '10px "JetBrains Mono", monospace';
        ctx.textAlign = 'right';
        ctx.fillText(`${100 - i * 25}%`, padLeft - 6, y + 3);
    }

    // 2. Vertical Time Grid Lines & Round Clock Timestamps on X-Axis
    const numTicks = STATE.chartZoom === 5 ? 5 : 4;
    for (let t = 0; t < numTicks; t++) {
        const ratio = t / (numTicks - 1);
        const x = padLeft + plotW * ratio;
        const sampleIdx = Math.min(Math.round(ratio * (cpuData.length - 1)), Math.max(cpuData.length - 1, 0));
        const ts = timeData[sampleIdx] || (now - (1 - ratio) * STATE.chartZoom * 60000);
        const dateObj = new Date(ts);
        const hours = String(dateObj.getHours()).padStart(2, '0');
        const mins = String(dateObj.getMinutes()).padStart(2, '0');
        const secs = String(dateObj.getSeconds()).padStart(2, '0');
        const timeStr = STATE.chartZoom === 5 ? `${hours}:${mins}:${secs}` : `${hours}:${mins}`;

        // Vertical dotted grid line
        ctx.beginPath();
        ctx.setLineDash([2, 3]);
        ctx.strokeStyle = '#1A1A28';
        ctx.moveTo(x, padTop);
        ctx.lineTo(x, padTop + plotH);
        ctx.stroke();
        ctx.setLineDash([]);

        // Time label text
        ctx.fillStyle = '#66667C';
        ctx.font = '10px "JetBrains Mono", monospace';
        ctx.textAlign = (t === 0) ? 'left' : (t === numTicks - 1) ? 'right' : 'center';
        ctx.fillText(timeStr, x, padTop + plotH + 16);
    }

    // 3. Line & Gradient Renderer
    function drawLine(data, color, glowColor) {
        if (data.length < 2) return;
        const step = plotW / Math.max(data.length - 1, 1);

        // Glow pass
        ctx.beginPath();
        ctx.strokeStyle = glowColor;
        ctx.lineWidth = 5;
        ctx.lineJoin = 'round';
        for (let i = 0; i < data.length; i++) {
            const x = padLeft + i * step;
            const y = padTop + plotH * (1 - Math.min(Math.max(data[i], 0), 100) / 100);
            if (i === 0) ctx.moveTo(x, y);
            else ctx.lineTo(x, y);
        }
        ctx.stroke();

        // Main line
        ctx.beginPath();
        ctx.strokeStyle = color;
        ctx.lineWidth = 2;
        ctx.lineJoin = 'round';
        for (let i = 0; i < data.length; i++) {
            const x = padLeft + i * step;
            const y = padTop + plotH * (1 - Math.min(Math.max(data[i], 0), 100) / 100);
            if (i === 0) ctx.moveTo(x, y);
            else ctx.lineTo(x, y);
        }
        ctx.stroke();

        // Gradient under fill
        ctx.beginPath();
        for (let i = 0; i < data.length; i++) {
            const x = padLeft + i * step;
            const y = padTop + plotH * (1 - Math.min(Math.max(data[i], 0), 100) / 100);
            if (i === 0) ctx.moveTo(x, y);
            else ctx.lineTo(x, y);
        }
        ctx.lineTo(padLeft + (data.length - 1) * step, padTop + plotH);
        ctx.lineTo(padLeft, padTop + plotH);
        ctx.closePath();

        const grad = ctx.createLinearGradient(0, padTop, 0, padTop + plotH);
        grad.addColorStop(0, glowColor);
        grad.addColorStop(1, 'transparent');
        ctx.fillStyle = grad;
        ctx.fill();
    }

    drawLine(ramData, '#60A5FA', 'rgba(96,165,250,0.12)');
    drawLine(cpuData, '#FF3C3C', 'rgba(255,60,60,0.14)');

    // 4. Interactive Crosshair & Highlight Points
    if (STATE.chartHoverIndex >= 0 && STATE.chartHoverIndex < cpuData.length) {
        const step = plotW / Math.max(cpuData.length - 1, 1);
        const hoverX = padLeft + STATE.chartHoverIndex * step;
        const cpuVal = cpuData[STATE.chartHoverIndex] || 0;
        const ramVal = ramData[STATE.chartHoverIndex] || 0;
        const cpuY = padTop + plotH * (1 - Math.min(Math.max(cpuVal, 0), 100) / 100);
        const ramY = padTop + plotH * (1 - Math.min(Math.max(ramVal, 0), 100) / 100);

        // Vertical glowing crosshair line
        ctx.beginPath();
        ctx.strokeStyle = 'rgba(0, 229, 255, 0.45)';
        ctx.lineWidth = 1;
        ctx.setLineDash([2, 2]);
        ctx.moveTo(hoverX, padTop);
        ctx.lineTo(hoverX, padTop + plotH);
        ctx.stroke();
        ctx.setLineDash([]);

        // CPU glowing dot
        ctx.beginPath();
        ctx.arc(hoverX, cpuY, 4, 0, 2 * Math.PI);
        ctx.fillStyle = '#FF3C3C';
        ctx.fill();
        ctx.lineWidth = 2;
        ctx.strokeStyle = '#ffffff';
        ctx.stroke();

        // RAM glowing dot
        ctx.beginPath();
        ctx.arc(hoverX, ramY, 4, 0, 2 * Math.PI);
        ctx.fillStyle = '#60A5FA';
        ctx.fill();
        ctx.lineWidth = 2;
        ctx.strokeStyle = '#ffffff';
        ctx.stroke();

        // Update floating Tooltip
        if (DOM.chartTooltip) {
            const pointTs = timeData[STATE.chartHoverIndex] || now;
            const dt = new Date(pointTs);
            const timeFormatted = `${String(dt.getHours()).padStart(2, '0')}:${String(dt.getMinutes()).padStart(2, '0')}:${String(dt.getSeconds()).padStart(2, '0')}`;
            
            DOM.chartTooltip.innerHTML = `
                <span class="chart-tooltip-time">🕒 ${timeFormatted}</span>
                <div class="chart-tooltip-row"><span class="chart-tooltip-cpu">● CPU</span><span>${cpuVal.toFixed(1)}%</span></div>
                <div class="chart-tooltip-row"><span class="chart-tooltip-ram">● RAM</span><span>${ramVal.toFixed(1)}%</span></div>
            `;
            DOM.chartTooltip.style.display = 'block';
            
            const tooltipW = DOM.chartTooltip.offsetWidth || 110;
            let tipX = hoverX;
            if (tipX - tooltipW / 2 < 10) tipX = tooltipW / 2 + 10;
            if (tipX + tooltipW / 2 > w - 10) tipX = w - tooltipW / 2 - 10;
            DOM.chartTooltip.style.left = `${tipX}px`;
        }
    } else {
        if (DOM.chartTooltip) DOM.chartTooltip.style.display = 'none';
    }

    // 5. Chart Legend
    const legendY = padTop + 8;
    ctx.font = '11px "Inter", sans-serif';
    ctx.textAlign = 'right';
    ctx.fillStyle = '#60A5FA';
    ctx.fillText('● RAM', padLeft + plotW - 10, legendY);
    ctx.fillStyle = '#FF3C3C';
    ctx.fillText('● CPU', padLeft + plotW - 65, legendY);
}

// ============================================================
// MuMu Instances (with VM Disk - Module 3)
// ============================================================
let vmDiskData = [];

function updateVmDiskData(data) {
    if (Array.isArray(data)) vmDiskData = data;
}

function updateMuMu(mumu) {
    if (!mumu) return;

    const devices = mumu.devices || [];
    const launchers = mumu.launchers || [];
    const all = [...devices, ...launchers];
    const vmDisks = mumu.vm_disk || vmDiskData;

    DOM.mumuCount.textContent = `${devices.length} instance${devices.length !== 1 ? 's' : ''} running`;

    if (all.length === 0) {
        DOM.mumuBody.innerHTML = '<tr class="mumu-empty"><td colspan="8">No instances detected</td></tr>';
        return;
    }

    DOM.mumuBody.innerHTML = all.map((inst, i) => {
        const isDevice = inst.name.toLowerCase().includes('device');
        const type = isDevice ? 'Emulator' : 'Launcher';

        let vmDiskHtml = '<span class="vm-disk-na">—</span>';
        if (isDevice && vmDisks.length > 0) {
            const vmIdx = devices.indexOf(inst);
            const vm = vmDisks[vmIdx] || vmDisks.find(v => v.instance === vmIdx + 1);
            if (vm) {
                const statusClass = vm.status === 'critical' ? 'critical' : vm.status === 'warning' ? 'warning' : 'ok';
                vmDiskHtml = `
                    <div class="vm-disk-cell">
                        <div class="vm-disk-bar">
                            <div class="vm-disk-fill ${statusClass}" style="width:${vm.used_pct}%"></div>
                        </div>
                        <span class="vm-disk-pct">${vm.used_pct}%</span>
                    </div>
                `;
            }
        }

        const bloatBadge = inst.is_bloated ? '<span class="badge-bloat" title="High memory consumption (>4.5GB)">⚠️ Bloat</span>' : '';
        const trimBtn = `<button class="btn-trim-mini" data-pid="${inst.pid}" title="Trim working set for PID ${inst.pid}">↺ Trim</button>`;

        return `
            <tr>
                <td>${i + 1}</td>
                <td>${type}</td>
                <td>${inst.cpu_percent}%</td>
                <td>${inst.ram_mb} MB${bloatBadge}</td>
                <td>${inst.uptime}</td>
                <td>${vmDiskHtml}</td>
                <td><span class="status-dot running"></span>OK</td>
                <td>${trimBtn}</td>
            </tr>
        `;
    }).join('');

    // Attach click listeners to per-instance trim buttons
    DOM.mumuBody.querySelectorAll('.btn-trim-mini').forEach(btn => {
        btn.addEventListener('click', (e) => {
            e.stopPropagation();
            const pid = btn.dataset.pid;
            if (!pid) return;
            btn.disabled = true;
            btn.textContent = '...';
            sendCommand('trim_mumu_instance', { pid: parseInt(pid) });
            setTimeout(() => {
                btn.textContent = '↺ Trim';
                btn.disabled = false;
            }, 2500);
        });
    });
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
        let details = '';
        if (res) {
            details = ` — freed ${res.freed_mb} MB RAM`;
            if (res.standby_purged) details += ' + Standby';
            if (res.freed_temp_mb > 0) details += ` + ${res.freed_temp_mb} MB Temp`;
        }
        DOM.boostLast.textContent = `Last boost: ${ab.last_boost_time}${details}`;
    }
}

// ============================================================
// Boost Result Handler
// ============================================================
function onBoostResult(result) {
    if (!result) return;
    DOM.boostNowBtn.classList.add('boosting');
    setTimeout(() => DOM.boostNowBtn.classList.remove('boosting'), 600);

    let msg = `Freed ${result.freed_mb} MB RAM (${result.processes_trimmed} procs)`;
    if (result.standby_purged) msg += ' + Standby Purged';
    if (result.freed_temp_mb > 0 || result.deleted_temp_files > 0) {
        msg += ` + ${result.freed_temp_mb} MB Temp (${result.deleted_temp_files} files)`;
    }
    DOM.boostLast.textContent = `Last boost: now — ${msg}`;
    addLogEntry({ time: new Date().toLocaleTimeString(), type: 'boost', message: msg });
}

// ============================================================
// Module 2: Hardening Status (4/4 Complete)
// ============================================================
function updateHardeningStatus(data) {
    if (!data || !data.checks) return;

    const items = [
        { el: DOM.hardenVBS, key: 'vbs', name: 'VBS' },
        { el: DOM.hardenMPO, key: 'mpo', name: 'MPO' },
        { el: DOM.hardenHypervisor, key: 'hypervisor', name: 'Hypervisor' },
        { el: DOM.hardenExclusion, key: 'defender_exclusion', name: 'Defender Excl.' },
    ];

    items.forEach(({ el, key }) => {
        if (!el) return;
        const status = data.checks[key];
        const icon = el.querySelector('.hardening-icon');
        const statusEl = el.querySelector('.hardening-status');

        el.className = 'hardening-item';
        if (status === 'ok') {
            icon.textContent = '✅';
            const okText = key === 'defender_exclusion' ? 'Excluded' : 'Disabled';
            statusEl.textContent = okText;
            el.classList.add('ok');
        } else if (status === 'drift') {
            icon.textContent = '⚠️';
            statusEl.textContent = 'DRIFT!';
            el.classList.add('drift');
        } else {
            icon.textContent = '🛡️';
            statusEl.textContent = status ? (status.includes('Admin') ? 'Protected' : status) : 'Configured';
            el.classList.add('ok');
        }
    });

    if (data.last_check) {
        DOM.hardeningLastCheck.textContent = `Last check: ${data.last_check}`;
    }

    if (data.has_drift) {
        const driftItems = Object.keys(data.drift).join(', ');
        showToast('warning', `⚠️ Hardening drift: ${driftItems}`);
    }
}

// ============================================================
// Module 4: Deep Clean
// ============================================================
function renderDeepCleanPreview(preview) {
    STATE.deepCleanPreview = preview;

    if (!preview || preview.length === 0) {
        DOM.deepCleanPreview.innerHTML = '<div class="deep-clean-empty">No cleanable files found</div>';
        DOM.deepCleanExecBtn.disabled = true;
        DOM.deepCleanTotal.style.display = 'none';
        return;
    }

    let totalSize = 0;
    let totalFiles = 0;

    DOM.deepCleanPreview.innerHTML = preview.map(item => {
        totalSize += item.size_mb;
        totalFiles += item.file_count;
        const serviceNote = item.requires_service_stop
            ? `<span class="dc-service">⚠ Stops ${item.requires_service_stop} (Auto-restores)</span>`
            : '';
        return `
            <div class="dc-item">
                <div class="dc-info">
                    <span class="dc-name">${escapeHtml(item.name)}</span>
                    ${serviceNote}
                </div>
                <div class="dc-stats">
                    <span class="dc-size">${item.size_mb} MB</span>
                    <span class="dc-files">${item.file_count} files</span>
                </div>
            </div>
        `;
    }).join('');

    DOM.deepCleanTotalSize.textContent = totalSize.toFixed(1);
    DOM.deepCleanTotalFiles.textContent = totalFiles;
    DOM.deepCleanTotal.style.display = 'flex';
    DOM.deepCleanExecBtn.textContent = 'Clean All';
    DOM.deepCleanExecBtn.disabled = false;
}

function onDeepCleanResult(result) {
    if (!result) return;
    showToast('boost', `🧹 Deep Clean: ${result.total_freed_mb} MB freed (${result.total_deleted} files)`);
    DOM.deepCleanPreview.innerHTML = '<div class="deep-clean-empty">Clean complete! Click "Scan" to check again</div>';
    DOM.deepCleanExecBtn.textContent = 'Clean All';
    DOM.deepCleanExecBtn.disabled = true;
    DOM.deepCleanTotal.style.display = 'none';
    DOM.deepCleanScanBtn.textContent = 'Scan';
    DOM.deepCleanScanBtn.disabled = false;
}

// ============================================================
// Module 7: Defender Status
// ============================================================
function updateDefenderStatus(data) {
    if (!data || !data.available) {
        DOM.defSigAge.textContent = 'N/A';
        DOM.defQuickAge.textContent = 'N/A';
        DOM.defRealtime.textContent = 'N/A';
        return;
    }

    const sigAge = data.signature_age_days;
    DOM.defSigAge.textContent = sigAge >= 0 ? `${sigAge} day${sigAge !== 1 ? 's' : ''}` : '—';
    DOM.defSigAge.className = `defender-value ${data.signature_stale ? 'stale' : 'fresh'}`;

    const qAge = data.quick_scan_age_days;
    DOM.defQuickAge.textContent = qAge >= 0 ? `${qAge} day${qAge !== 1 ? 's' : ''} ago` : '—';
    DOM.defQuickAge.className = `defender-value ${qAge > 7 ? 'stale' : 'fresh'}`;

    DOM.defRealtime.textContent = data.realtime_enabled ? 'ON' : 'OFF';
    DOM.defRealtime.className = `defender-value ${data.realtime_enabled ? 'fresh' : 'stale'}`;
}

// ============================================================
// Session & Uptime Summary (v2.4)
// ============================================================
function updateSessionSummary(sum) {
    if (!sum) return;

    if (DOM.sumUptime) {
        const sec = sum.uptime_seconds || 0;
        const days = Math.floor(sec / 86400);
        const hours = Math.floor((sec % 86400) / 3600);
        const mins = Math.floor((sec % 3600) / 60);
        if (days > 0) {
            DOM.sumUptime.textContent = `${days}d ${hours}h ${mins}m`;
        } else {
            DOM.sumUptime.textContent = `${hours}h ${mins}m`;
        }
    }

    if (DOM.sumBoosts) {
        const sessionCount = (sum.session_boosts !== undefined) ? sum.session_boosts : (sum.total_boosts || 0);
        DOM.sumBoosts.textContent = sessionCount;
    }

    if (DOM.sumTotalBoosts) {
        DOM.sumTotalBoosts.textContent = `(Total: ${sum.total_boosts || 0})`;
    }

    if (DOM.sumRecoveries) {
        DOM.sumRecoveries.textContent = sum.net_recoveries || 0;
    }

    if (DOM.sumLastClean) {
        if (!sum.last_clean_time || sum.last_clean_time === 'None') {
            DOM.sumLastClean.textContent = 'None';
        } else {
            const parts = sum.last_clean_time.split(' ');
            DOM.sumLastClean.textContent = parts[1] || sum.last_clean_time;
        }
    }

    if (DOM.sumHardening) {
        if (sum.drift_detected) {
            DOM.sumHardening.textContent = 'Drift Detected';
            DOM.sumHardening.className = 'summary-val warning';
        } else {
            DOM.sumHardening.textContent = '4/4 Hardened';
            DOM.sumHardening.className = 'summary-val fresh';
        }
    }

    if (sum.standby_guard) {
        if (DOM.sumStandbyPurges) DOM.sumStandbyPurges.textContent = sum.standby_guard.purges || 0;
        if (DOM.sumStandbyReclaimed) DOM.sumStandbyReclaimed.textContent = `(${sum.standby_guard.reclaimed_gb || 0.0} GB freed)`;
    }

    // Display clock-aligned next scheduled boost time if in scheduled mode
    if (sum.boost_mode === 'scheduled' && sum.next_scheduled_boost && sum.next_scheduled_boost !== 'N/A') {
        if (DOM.boostLast) {
            const baseLast = DOM.boostLast.textContent.split(' | Next:')[0];
            DOM.boostLast.textContent = `${baseLast} | Next: ${sum.next_scheduled_boost}`;
        }
    }
}

// ============================================================
// Module 8: Network Observatory & Telemetry
// ============================================================
function updateNetworkObservatory(obs) {
    if (!obs) return;

    // 1. Latency & Loss
    if (obs.latency) {
        const lat = obs.latency;
        if (DOM.netLatencyVal) DOM.netLatencyVal.textContent = lat.current_ms > 0 ? lat.current_ms : '—';
        if (DOM.netJitterVal) DOM.netJitterVal.textContent = lat.jitter_ms;
        if (DOM.netLossVal) DOM.netLossVal.textContent = `${lat.loss_percent.toFixed(1)}%`;
        if (DOM.netQualityBadge) {
            DOM.netQualityBadge.className = `obs-badge quality-${lat.quality || 'excellent'}`;
            DOM.netQualityBadge.textContent = (lat.quality || 'excellent').toUpperCase();
        }
    }

    // 2. Wi-Fi RF Quality
    if (obs.wifi) {
        const w = obs.wifi;
        if (DOM.wifiSsid) DOM.wifiSsid.textContent = w.ssid || 'Disconnected';
        if (DOM.wifiBand) DOM.wifiBand.textContent = w.band || '5 GHz';
        if (DOM.wifiSignalVal) DOM.wifiSignalVal.textContent = `${w.signal_percent}%`;
        if (DOM.wifiDbmVal) DOM.wifiDbmVal.textContent = `${w.rssi_dbm} dBm`;
        if (DOM.wifiRateVal) DOM.wifiRateVal.textContent = `${w.rx_rate_mbps}/${w.tx_rate_mbps}`;
        if (DOM.wifiQualityPill && w.quality_label) {
            DOM.wifiQualityPill.textContent = `${w.quality_label} (${w.quality_score}%)`;
            const qClass = (w.quality_label || '').toLowerCase();
            DOM.wifiQualityPill.className = `obs-quality-pill ${qClass === 'excellent' ? '' : qClass}`;
        }
    }

    // 3. Standalone Watchdog Status
    if (obs.watchdog) {
        const wd = obs.watchdog;
        if (DOM.watchdogBadge) {
            DOM.watchdogBadge.className = `obs-badge status-${wd.state || 'armed'}`;
            DOM.watchdogBadge.textContent = (wd.state || 'armed').toUpperCase();
        }
        if (DOM.watchdogStatusText) DOM.watchdogStatusText.textContent = wd.status || 'Active Monitoring';
        if (DOM.watchdogRecoveriesVal) DOM.watchdogRecoveriesVal.textContent = wd.recoveries_today || 0;
        if (DOM.watchdogHeartbeat) {
            DOM.watchdogHeartbeat.textContent = wd.heartbeat_seconds >= 0 ? `Heartbeat: ${wd.heartbeat_seconds}s ago` : 'Heartbeat: —';
        }
        if (DOM.watchdogLogConsole && wd.recent_logs) {
            DOM.watchdogLogConsole.textContent = wd.recent_logs.length > 0 ? wd.recent_logs.join('\n') : 'No log entries recorded yet.';
        }
    }
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
    // Auth PIN Modal Handlers
    if (DOM.pinSubmitBtn) {
        DOM.pinSubmitBtn.addEventListener('click', submitPin);
    }
    if (DOM.pinInput) {
        DOM.pinInput.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') submitPin();
        });
    }
    if (DOM.authBadge) {
        DOM.authBadge.addEventListener('click', () => {
            if (STATE.authenticated) {
                if (confirm('Lock Dashboard permissions?')) {
                    localStorage.removeItem('genesis_auth_token');
                    STATE.token = '';
                    setAuthState(false);
                    showAuthModal(true);
                }
            } else {
                showAuthModal(true);
            }
        });
    }

    // Reset Session Boosts Counter (Preserve Total)
    if (DOM.btnResetBoosts) {
        DOM.btnResetBoosts.addEventListener('click', () => {
            if (isAuthRequired()) {
                requestPinAuth(() => {
                    sendCommand('reset_session_boosts');
                    DOM.btnResetBoosts.classList.add('rotating');
                    setTimeout(() => DOM.btnResetBoosts.classList.remove('rotating'), 600);
                });
                return;
            }
            sendCommand('reset_session_boosts');
            DOM.btnResetBoosts.classList.add('rotating');
            setTimeout(() => DOM.btnResetBoosts.classList.remove('rotating'), 600);
        });
    }

    // Reset Lifetime Total Boosts History
    if (DOM.btnResetTotalBoosts) {
        DOM.btnResetTotalBoosts.addEventListener('click', () => {
            if (isAuthRequired()) {
                requestPinAuth(() => {
                    sendCommand('reset_total_boosts');
                    DOM.btnResetTotalBoosts.textContent = '...';
                    setTimeout(() => { DOM.btnResetTotalBoosts.textContent = '↺ Total'; }, 600);
                });
                return;
            }
            sendCommand('reset_total_boosts');
            DOM.btnResetTotalBoosts.textContent = '...';
            setTimeout(() => { DOM.btnResetTotalBoosts.textContent = '↺ Total'; }, 600);
        });
    }

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
        val = Math.max(val - 5, 30);
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

    // Module 2: Hardening refresh
    if (DOM.hardeningRefreshBtn) {
        DOM.hardeningRefreshBtn.addEventListener('click', () => {
            sendCommand('check_hardening');
            DOM.hardeningRefreshBtn.classList.add('spinning');
            setTimeout(() => DOM.hardeningRefreshBtn.classList.remove('spinning'), 1000);
        });
    }

    // Module 4: Deep Clean
    if (DOM.deepCleanScanBtn) {
        DOM.deepCleanScanBtn.addEventListener('click', () => {
            DOM.deepCleanScanBtn.textContent = 'Scanning...';
            DOM.deepCleanScanBtn.disabled = true;
            sendCommand('deep_clean_preview');
            setTimeout(() => {
                DOM.deepCleanScanBtn.textContent = 'Scan';
                DOM.deepCleanScanBtn.disabled = false;
            }, 10000);
        });
    }

    if (DOM.deepCleanExecBtn) {
        DOM.deepCleanExecBtn.addEventListener('click', () => {
            if (!confirm('Execute Deep Clean? This will safely clean all scanned targets.')) return;
            DOM.deepCleanExecBtn.textContent = 'Cleaning...';
            DOM.deepCleanExecBtn.disabled = true;
            sendCommand('deep_clean_execute');
            setTimeout(() => {
                if (DOM.deepCleanExecBtn.textContent === 'Cleaning...') {
                    DOM.deepCleanExecBtn.textContent = 'Clean All';
                    DOM.deepCleanExecBtn.disabled = false;
                }
            }, 15000);
        });
    }

    // Module 7: Quick Scan
    if (DOM.quickScanBtn) {
        DOM.quickScanBtn.addEventListener('click', () => {
            sendCommand('quick_scan');
            DOM.quickScanBtn.textContent = 'Starting...';
            DOM.quickScanBtn.disabled = true;
            setTimeout(() => {
                DOM.quickScanBtn.textContent = 'Quick Scan';
                DOM.quickScanBtn.disabled = false;
            }, 8000);
        });
    }

    // Module 8: Flush DNS
    if (DOM.flushDnsBtn) {
        DOM.flushDnsBtn.addEventListener('click', () => {
            DOM.flushDnsBtn.textContent = 'Flushing...';
            DOM.flushDnsBtn.disabled = true;
            sendCommand('flush_dns');
            setTimeout(() => {
                DOM.flushDnsBtn.textContent = 'Flush DNS';
                DOM.flushDnsBtn.disabled = false;
            }, 6000);
        });
    }

    // Module 8: Toggle Watchdog Log Feed
    if (DOM.toggleWatchdogLogs && DOM.watchdogLogPanel) {
        DOM.toggleWatchdogLogs.addEventListener('click', () => {
            const isHidden = DOM.watchdogLogPanel.style.display === 'none';
            DOM.watchdogLogPanel.style.display = isHidden ? 'block' : 'none';
            DOM.toggleWatchdogLogs.textContent = isHidden ? 'Hide Logs ▴' : 'View Logs ▾';
        });
    }

    // History Chart Zoom Range Controls
    const zoomBtns = document.querySelectorAll('.chart-zoom-btn');
    zoomBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            zoomBtns.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            const zoom = parseInt(btn.dataset.zoom) || 30;
            STATE.chartZoom = zoom;
            if (DOM.chartTimeLabel) {
                DOM.chartTimeLabel.textContent = `Last ${zoom} mins`;
            }
            STATE.chartHoverIndex = -1;
            drawHistoryChart();
        });
    });

    // History Chart Interactive Scrubbing / Inspection Tooltip
    if (DOM.historyChart) {
        const handleChartHover = (clientX) => {
            const rect = DOM.historyChart.getBoundingClientRect();
            const x = clientX - rect.left;
            const padLeft = 32;
            const padRight = 14;
            const plotW = Math.max(rect.width - padLeft - padRight, 10);

            let pointsCount = 60;
            if (STATE.chartZoom === 5) pointsCount = 10;
            else if (STATE.chartZoom === 15) pointsCount = 30;
            else pointsCount = 60;

            const fullLen = STATE.cpuHistory.length;
            const startIndex = Math.max(0, fullLen - pointsCount);
            const currentSliceLen = fullLen - startIndex;
            if (currentSliceLen <= 1) return;

            const relativeX = Math.max(0, Math.min(x - padLeft, plotW));
            const step = plotW / Math.max(currentSliceLen - 1, 1);
            const hoverIndex = Math.round(relativeX / step);

            STATE.chartHoverIndex = Math.max(0, Math.min(hoverIndex, currentSliceLen - 1));
            drawHistoryChart();
        };

        DOM.historyChart.addEventListener('mousemove', (e) => handleChartHover(e.clientX));
        DOM.historyChart.addEventListener('mouseleave', () => {
            STATE.chartHoverIndex = -1;
            drawHistoryChart();
        });

        DOM.historyChart.addEventListener('touchmove', (e) => {
            if (e.touches && e.touches[0]) {
                handleChartHover(e.touches[0].clientX);
            }
        }, { passive: true });

        DOM.historyChart.addEventListener('touchend', () => {
            setTimeout(() => {
                STATE.chartHoverIndex = -1;
                drawHistoryChart();
            }, 2500);
        });
    }
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
    window.addEventListener('resize', drawHistoryChart);
}

document.addEventListener('DOMContentLoaded', init);
