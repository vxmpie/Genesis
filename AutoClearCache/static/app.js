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
            break;
        case 'auth_success':
            setAuthState(true);
            showToast('system', '🔑 Dashboard control unlocked');
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

    updateCoreBars(m.cpu);

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

    ctx.fillStyle = '#0D0D14';
    ctx.fillRect(0, 0, w, h);

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

    function drawLine(data, color, glowColor) {
        if (data.length < 2) return;
        const step = w / (STATE.historyLength - 1);

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

    const legendY = h - 6;
    ctx.font = '11px "Inter", sans-serif';
    ctx.fillStyle = '#FF3C3C';
    ctx.fillText('● CPU', w - 130, legendY);
    ctx.fillStyle = '#60A5FA';
    ctx.fillText('● RAM', w - 60, legendY);
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
        DOM.mumuBody.innerHTML = '<tr class="mumu-empty"><td colspan="7">No instances detected</td></tr>';
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

        return `
            <tr>
                <td>${i + 1}</td>
                <td>${type}</td>
                <td>${inst.cpu_percent}%</td>
                <td>${inst.ram_mb} MB</td>
                <td>${inst.uptime}</td>
                <td>${vmDiskHtml}</td>
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
            statusEl.textContent = 'Disabled / Set';
            el.classList.add('ok');
        } else if (status === 'drift') {
            icon.textContent = '⚠️';
            statusEl.textContent = 'DRIFT!';
            el.classList.add('drift');
        } else {
            icon.textContent = '❓';
            statusEl.textContent = status || 'Unknown';
            el.classList.add('unknown');
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
