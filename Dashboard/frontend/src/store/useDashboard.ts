import { create } from 'zustand';
import type {
  AlertDeliveryEntry,
  AlertsPurgeResult,
  AlertsStatus,
  AlertTestResult,
  AutoBoostConfig,
  ChartHistory,
  ClientConfig,
  ConnectionState,
  CoreAffinityInfo,
  DeepCleanPreviewItem,
  DefenderStatus,
  EventLogEntry,
  GrowthSnapshot,
  HardeningStatus,
  MuMuDevice,
  MuMuHealth,
  NetworkObservatory,
  SessionSummary,
  ShaderCacheInfo,
  SystemMetrics,
  TimerResolutionInfo,
  ToastMessage,
  TopProcess,
  TunnelStatus,
  VmDiskItem,
  WorkspaceView,
} from '../types/dashboard';
import {
  isDefenderPopulated,
  isHardeningPopulated,
  type WsInitMessage,
  type WsMetricsMessage,
} from '../types/ws';

const VALID_VIEWS: ReadonlySet<WorkspaceView> = new Set([
  'overview',
  'instances',
  'system',
  'telemetry',
  'alerts',
]);

const MAX_CHART_POINTS = 1800;

export function getViewFromHash(): WorkspaceView {
  if (typeof window === 'undefined') return 'overview';
  const raw = window.location.hash.replace(/^#/, '').trim() as WorkspaceView;
  return VALID_VIEWS.has(raw) ? raw : 'overview';
}

function getInitialSidebarCollapsed(): boolean {
  if (typeof window === 'undefined') return false;
  return localStorage.getItem('genesis_sidebar_collapsed') === '1';
}

// --- Immutable Payload Normalizers ---
function normalizeMetrics(incoming: SystemMetrics): SystemMetrics {
  const cDrive = incoming.storage?.c_drive;
  const breakdown = incoming.ram.breakdown;
  const sentSpeed =
    typeof incoming.network.sent_speed_mbs === 'number'
      ? incoming.network.sent_speed_mbs
      : (incoming.network.bytes_sent_sec || 0) / (1024 * 1024);
  const recvSpeed =
    typeof incoming.network.recv_speed_mbs === 'number'
      ? incoming.network.recv_speed_mbs
      : (incoming.network.bytes_recv_sec || 0) / (1024 * 1024);

  const readSpeed = incoming.disk.read_mb_s ?? incoming.disk.read_speed_mbs ?? 0;
  const writeSpeed = incoming.disk.write_mb_s ?? incoming.disk.write_speed_mbs ?? 0;

  return {
    ...incoming,
    ram: {
      ...incoming.ram,
      active_gb: incoming.ram.active_gb ?? breakdown.active_gb,
      standby_gb: incoming.ram.standby_gb ?? breakdown.standby_gb,
      free_gb: incoming.ram.free_gb ?? breakdown.free_gb,
    },
    disk: {
      ...incoming.disk,
      read_mb_s: readSpeed,
      write_mb_s: writeSpeed,
      read_speed_mbs: incoming.disk.read_speed_mbs ?? readSpeed,
      write_speed_mbs: incoming.disk.write_speed_mbs ?? writeSpeed,
      system_free_gb: cDrive?.free_gb ?? incoming.disk.system_free_gb,
      system_total_gb: cDrive?.total_gb ?? incoming.disk.system_total_gb,
      system_percent: cDrive?.percent ?? incoming.disk.system_percent,
    },
    network: {
      ...incoming.network,
      sent_speed_mbs: sentSpeed,
      recv_speed_mbs: recvSpeed,
      bytes_sent_sec: incoming.network.bytes_sent_sec || Math.round(sentSpeed * 1024 * 1024),
      bytes_recv_sec: incoming.network.bytes_recv_sec || Math.round(recvSpeed * 1024 * 1024),
    },
  };
}

function normalizeDevice(dev: MuMuDevice, fallbackIdx: number): MuMuDevice {
  const index = dev.index ?? dev.instance_index ?? fallbackIdx;
  const targetGame = dev.active_game || dev.target_game || dev.target_game_name || 'Unassigned';
  return {
    ...dev,
    index,
    instance_index: dev.instance_index ?? index,
    type: dev.type || 'Emulator',
    active_game: targetGame,
    target_game: dev.target_game || targetGame,
    target_game_name: dev.target_game_name || targetGame,
  };
}

function normalizeMuMu(incoming: MuMuHealth): MuMuHealth {
  return {
    ...incoming,
    devices: Array.isArray(incoming.devices)
      ? incoming.devices.map((d, idx) => normalizeDevice(d, idx + 1))
      : [],
    launchers: Array.isArray(incoming.launchers)
      ? incoming.launchers.map((d) => normalizeDevice(d, 0))
      : [],
    vm_disk: Array.isArray(incoming.vm_disk) ? incoming.vm_disk : [],
    game_presets: Array.isArray(incoming.game_presets) ? incoming.game_presets : [],
  };
}

function sortEventsNewestFirst(events: EventLogEntry[]): EventLogEntry[] {
  return [...events]
    .sort((a, b) => {
      if (typeof a.epoch === 'number' && typeof b.epoch === 'number') {
        return b.epoch - a.epoch;
      }
      return String(b.time || '').localeCompare(String(a.time || ''));
    })
    .slice(0, 150);
}

function appendChartPoint(
  current: ChartHistory,
  ramPct: number,
  cpuPct: number,
  now: number
): ChartHistory {
  const lastTs = current.timestamps[current.timestamps.length - 1] ?? 0;
  if (current.timestamps.length > 0 && now - lastTs < 900) {
    return current;
  }
  const startIdx = Math.max(0, current.timestamps.length - (MAX_CHART_POINTS - 1));
  return {
    ram: [...current.ram.slice(startIdx), ramPct],
    cpu: [...current.cpu.slice(startIdx), cpuPct],
    timestamps: [...current.timestamps.slice(startIdx), now],
  };
}

// --- Store Interface ---
interface DashboardState {
  activeView: WorkspaceView;
  sidebarCollapsed: boolean;
  connected: boolean;
  connectionState: ConnectionState;
  lastMessageAt: number | null;
  authenticated: boolean;
  authRequired: boolean;
  token: string;

  config: ClientConfig | null;
  metrics: SystemMetrics | null;
  mumu: MuMuHealth | null;
  topProcesses: TopProcess[];
  summary: SessionSummary | null;
  autoBoost: AutoBoostConfig | null;
  hardening: HardeningStatus | null;
  defender: DefenderStatus | null;
  observatory: NetworkObservatory | null;
  timerResolution: TimerResolutionInfo | null;
  pcoreAffinity: CoreAffinityInfo | null;
  shaderCache: ShaderCacheInfo | null;
  vmDisk: VmDiskItem[];
  growthData: GrowthSnapshot[];
  alertsStatus: AlertsStatus | null;
  alertsHistory: AlertDeliveryEntry[];
  tunnel: TunnelStatus | null;
  eventHistory: EventLogEntry[];
  chartHistory: ChartHistory;
  chartZoom: 5 | 15 | 30;
  deepCleanPreview: DeepCleanPreviewItem[];

  isDeepCleaning: boolean;
  isScanningClean: boolean;
  isBoosting: boolean;
  isTestingAlert: boolean;
  isSavingAlerts: boolean;
  isPurgingAlerts: boolean;
  isRestartingTunnel: boolean;
  lastAlertTestResult: AlertTestResult | null;
  lastAlertPurgeResult: AlertsPurgeResult | null;
  lastAlertsSavedAt: number | null;

  toasts: ToastMessage[];
  authModalOpen: boolean;
  pendingAuthAction: (() => void) | null;
  cmdPaletteOpen: boolean;
  editGameModalOpen: boolean;
  editingDevice: MuMuDevice | null;

  // Navigation & UI Actions
  setActiveView: (view: WorkspaceView, syncHash?: boolean) => void;
  toggleSidebarCollapsed: () => void;
  setConnectionState: (state: ConnectionState) => void;
  setAuthenticated: (authed: boolean) => void;
  setAuthRequired: (required: boolean) => void;
  setToken: (token: string) => void;
  clearSession: () => void;

  // Domain Setters
  setConfig: (config: ClientConfig) => void;
  setSummary: (summary: SessionSummary) => void;
  setHardening: (hardening: HardeningStatus | Record<string, never>) => void;
  setDefender: (defender: DefenderStatus | Record<string, never>) => void;
  setObservatory: (observatory: NetworkObservatory) => void;
  setVmDisk: (items: VmDiskItem[]) => void;
  setGrowthData: (items: GrowthSnapshot[]) => void;
  setAlertsStatus: (status: AlertsStatus) => void;
  setAlertsHistory: (entries: AlertDeliveryEntry[]) => void;
  pushAlertDelivery: (entry: AlertDeliveryEntry) => void;
  setTunnel: (tunnel: TunnelStatus) => void;
  setChartZoom: (zoom: 5 | 15 | 30) => void;
  setDeepCleanPreview: (items: DeepCleanPreviewItem[]) => void;
  updateAutoBoost: (partial: Partial<AutoBoostConfig>) => void;
  setTimerResolution: (t: TimerResolutionInfo) => void;
  setPcoreAffinity: (a: CoreAffinityInfo) => void;
  setShaderCache: (s: ShaderCacheInfo) => void;

  // Loading Flags
  setIsDeepCleaning: (v: boolean) => void;
  setIsScanningClean: (v: boolean) => void;
  setIsBoosting: (v: boolean) => void;
  setIsTestingAlert: (v: boolean) => void;
  setIsSavingAlerts: (v: boolean) => void;
  setIsPurgingAlerts: (v: boolean) => void;
  setIsRestartingTunnel: (v: boolean) => void;
  setLastAlertTestResult: (res: AlertTestResult | null) => void;
  setLastAlertPurgeResult: (res: AlertsPurgeResult | null) => void;
  markAlertsSaved: () => void;
  clearPendingOperations: () => void;

  // Modals & Toasts
  setAuthModalOpen: (open: boolean) => void;
  openAuthModalWithAction: (action?: () => void) => void;
  closeAuthModal: () => void;
  consumePendingAuthAction: () => (() => void) | null;
  setCmdPaletteOpen: (open: boolean) => void;
  openEditGameModal: (dev: MuMuDevice) => void;
  closeEditGameModal: () => void;
  addToast: (type: ToastMessage['type'], message: string) => void;
  removeToast: (id: string) => void;
  addEvent: (entry: EventLogEntry) => void;
  clearEvents: () => void;

  // WS Payload Reducers
  applyInitPayload: (data: WsInitMessage) => void;
  applyMetricsPayload: (data: WsMetricsMessage) => void;
}

export const useDashboardStore = create<DashboardState>((set, get) => ({
  activeView: getViewFromHash(),
  sidebarCollapsed: getInitialSidebarCollapsed(),
  connected: false,
  connectionState: 'connecting',
  lastMessageAt: null,
  authenticated: false,
  authRequired: false,
  token: typeof window !== 'undefined' ? localStorage.getItem('genesis_auth_token') || '' : '',

  config: null,
  metrics: null,
  mumu: null,
  topProcesses: [],
  summary: null,
  autoBoost: null,
  hardening: null,
  defender: null,
  observatory: null,
  timerResolution: null,
  pcoreAffinity: null,
  shaderCache: null,
  vmDisk: [],
  growthData: [],
  alertsStatus: null,
  alertsHistory: [],
  tunnel: null,
  eventHistory: [],
  chartHistory: {
    ram: [],
    cpu: [],
    timestamps: [],
  },
  chartZoom: 30,
  deepCleanPreview: [],

  isDeepCleaning: false,
  isScanningClean: false,
  isBoosting: false,
  isTestingAlert: false,
  isSavingAlerts: false,
  isPurgingAlerts: false,
  isRestartingTunnel: false,
  lastAlertTestResult: null,
  lastAlertPurgeResult: null,
  lastAlertsSavedAt: null,

  toasts: [],
  authModalOpen: false,
  pendingAuthAction: null,
  cmdPaletteOpen: false,
  editGameModalOpen: false,
  editingDevice: null,

  setActiveView: (activeView, syncHash = true) => {
    if (syncHash && typeof window !== 'undefined') {
      const targetHash = `#${activeView}`;
      if (window.location.hash !== targetHash) {
        window.location.hash = targetHash;
      }
    }
    set({ activeView });
  },

  toggleSidebarCollapsed: () =>
    set((s) => {
      const next = !s.sidebarCollapsed;
      if (typeof window !== 'undefined') {
        localStorage.setItem('genesis_sidebar_collapsed', next ? '1' : '0');
      }
      return { sidebarCollapsed: next };
    }),

  setConnectionState: (connectionState) =>
    set({
      connectionState,
      connected: connectionState === 'connected',
    }),

  setAuthenticated: (authenticated) => set({ authenticated }),
  setAuthRequired: (authRequired) => set({ authRequired }),

  setToken: (token) => {
    if (typeof window !== 'undefined') {
      if (token) {
        localStorage.setItem('genesis_auth_token', token);
      } else {
        localStorage.removeItem('genesis_auth_token');
      }
    }
    set({ token, authenticated: Boolean(token) });
  },

  clearSession: () => {
    if (typeof window !== 'undefined') {
      localStorage.removeItem('genesis_auth_token');
    }
    set({ token: '', authenticated: false, pendingAuthAction: null });
  },

  setConfig: (config) => set({ config }),
  setSummary: (summary) => set({ summary }),
  setHardening: (hardening) =>
    set({ hardening: isHardeningPopulated(hardening) ? hardening : null }),
  setDefender: (defender) =>
    set({ defender: isDefenderPopulated(defender) ? defender : null }),
  setObservatory: (observatory) => set({ observatory }),
  setVmDisk: (vmDisk) => set({ vmDisk }),
  setGrowthData: (growthData) => set({ growthData }),
  setAlertsStatus: (alertsStatus) => set({ alertsStatus }),
  setAlertsHistory: (alertsHistory) => set({ alertsHistory }),

  pushAlertDelivery: (entry) =>
    set((s) => {
      const exists = s.alertsHistory.some((item) => item.id === entry.id);
      const nextHistory = exists
        ? s.alertsHistory.map((item) => (item.id === entry.id ? entry : item))
        : [entry, ...s.alertsHistory].slice(0, 50);

      let nextStatus = s.alertsStatus;
      if (!exists && s.alertsStatus) {
        nextStatus = {
          ...s.alertsStatus,
          delivered_count:
            entry.status === 'delivered'
              ? s.alertsStatus.delivered_count + 1
              : s.alertsStatus.delivered_count,
          failed_count:
            entry.status === 'failed'
              ? s.alertsStatus.failed_count + 1
              : s.alertsStatus.failed_count,
          suppressed_count:
            entry.status === 'suppressed'
              ? s.alertsStatus.suppressed_count + 1
              : s.alertsStatus.suppressed_count,
        };
      }

      return { alertsHistory: nextHistory, alertsStatus: nextStatus };
    }),

  setTunnel: (tunnel) => set({ tunnel }),
  setChartZoom: (chartZoom) => set({ chartZoom }),
  setDeepCleanPreview: (deepCleanPreview) => set({ deepCleanPreview }),

  updateAutoBoost: (partial) =>
    set((s) => {
      const base: AutoBoostConfig = s.autoBoost ?? {
        enabled: true,
        mode: 'auto',
        threshold: 85,
        interval_minutes: 10,
        last_boost_time: null,
        last_boost_result: null,
        next_boost: null,
      };
      return { autoBoost: { ...base, ...partial } };
    }),

  setTimerResolution: (timerResolution) => set({ timerResolution }),
  setPcoreAffinity: (pcoreAffinity) => set({ pcoreAffinity }),
  setShaderCache: (shaderCache) => set({ shaderCache }),

  setIsDeepCleaning: (isDeepCleaning) => set({ isDeepCleaning }),
  setIsScanningClean: (isScanningClean) => set({ isScanningClean }),
  setIsBoosting: (isBoosting) => set({ isBoosting }),
  setIsTestingAlert: (isTestingAlert) => set({ isTestingAlert }),
  setIsSavingAlerts: (isSavingAlerts) => set({ isSavingAlerts }),
  setIsPurgingAlerts: (isPurgingAlerts) => set({ isPurgingAlerts }),
  setIsRestartingTunnel: (isRestartingTunnel) => set({ isRestartingTunnel }),
  setLastAlertTestResult: (lastAlertTestResult) => set({ lastAlertTestResult }),
  setLastAlertPurgeResult: (lastAlertPurgeResult) => set({ lastAlertPurgeResult }),
  markAlertsSaved: () => set({ lastAlertsSavedAt: Date.now() }),

  clearPendingOperations: () =>
    set({
      isDeepCleaning: false,
      isScanningClean: false,
      isBoosting: false,
      isTestingAlert: false,
      isSavingAlerts: false,
      isPurgingAlerts: false,
      isRestartingTunnel: false,
    }),

  setAuthModalOpen: (authModalOpen) =>
    set((s) => ({
      authModalOpen,
      pendingAuthAction: authModalOpen ? s.pendingAuthAction : null,
    })),

  openAuthModalWithAction: (action) =>
    set({
      authModalOpen: true,
      pendingAuthAction: action ?? null,
    }),

  closeAuthModal: () => set({ authModalOpen: false, pendingAuthAction: null }),

  consumePendingAuthAction: () => {
    const fn = get().pendingAuthAction;
    if (fn) {
      set({ pendingAuthAction: null });
    }
    return fn;
  },

  setCmdPaletteOpen: (cmdPaletteOpen) => set({ cmdPaletteOpen }),
  openEditGameModal: (editingDevice) => set({ editGameModalOpen: true, editingDevice }),
  closeEditGameModal: () => set({ editGameModalOpen: false, editingDevice: null }),

  addToast: (type, message) => {
    if (!message) return;
    const active = get().toasts;
    if (active.some((t) => t.message === message)) return;

    const id = `${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
    set((s) => ({ toasts: [...s.toasts, { id, type, message }].slice(-4) }));
    setTimeout(() => {
      set((s) => ({ toasts: s.toasts.filter((t) => t.id !== id) }));
    }, 4500);
  },

  removeToast: (id) => set((s) => ({ toasts: s.toasts.filter((t) => t.id !== id) })),

  addEvent: (entry) =>
    set((s) => {
      const filtered = s.eventHistory.filter(
        (e) => e.time !== entry.time || e.message !== entry.message
      );
      return {
        eventHistory: [entry, ...filtered].slice(0, 150),
      };
    }),

  clearEvents: () => set({ eventHistory: [] }),

  applyInitPayload: (data) =>
    set((s) => {
      const incomingChart = data.chart_history;
      const hasIncomingChart =
        incomingChart &&
        Array.isArray(incomingChart.timestamps) &&
        incomingChart.timestamps.length > 0;

      const chartHistory: ChartHistory = hasIncomingChart
        ? {
            ram: incomingChart.ram.slice(-MAX_CHART_POINTS),
            cpu: incomingChart.cpu.slice(-MAX_CHART_POINTS),
            timestamps: incomingChart.timestamps.slice(-MAX_CHART_POINTS),
          }
        : s.chartHistory;

      const autoBoostInit: AutoBoostConfig | null = data.config?.auto_boost
        ? {
            enabled: data.config.auto_boost.enabled,
            mode: data.config.auto_boost.mode,
            threshold: data.config.auto_boost.threshold_percent,
            interval_minutes: data.config.auto_boost.interval_minutes,
            last_boost_time: s.autoBoost?.last_boost_time ?? null,
            last_boost_result: s.autoBoost?.last_boost_result ?? null,
            next_boost: s.autoBoost?.next_boost ?? null,
          }
        : s.autoBoost;

      return {
        lastMessageAt: Date.now(),
        authRequired: data.auth_required,
        authenticated: data.auth_required ? data.authenticated : true,
        config: data.config,
        autoBoost: autoBoostInit,
        hardening: isHardeningPopulated(data.hardening) ? data.hardening : null,
        defender: isDefenderPopulated(data.defender) ? data.defender : null,
        vmDisk: Array.isArray(data.vm_disk) ? data.vm_disk : s.vmDisk,
        growthData: Array.isArray(data.growth) ? data.growth : s.growthData,
        observatory: data.observatory ?? s.observatory,
        summary: data.summary ?? s.summary,
        timerResolution: data.timer_resolution ?? s.timerResolution,
        pcoreAffinity: data.pcore_affinity ?? s.pcoreAffinity,
        shaderCache: data.shader_cache ?? s.shaderCache,
        alertsStatus: data.alerts_status ?? s.alertsStatus,
        alertsHistory: Array.isArray(data.alerts_history) ? data.alerts_history : s.alertsHistory,
        tunnel: data.tunnel ?? s.tunnel,
        eventHistory: Array.isArray(data.history)
          ? sortEventsNewestFirst(data.history)
          : s.eventHistory,
        chartHistory,
      };
    }),

  applyMetricsPayload: (data) =>
    set((s) => {
      const normalizedMetrics = normalizeMetrics(data.metrics);
      const nextChart = appendChartPoint(
        s.chartHistory,
        normalizedMetrics.ram.percent,
        normalizedMetrics.cpu.total_percent,
        Date.now()
      );

      const tunnelSettled =
        data.tunnel &&
        (data.tunnel.status === 'online' ||
          data.tunnel.status === 'offline' ||
          data.tunnel.status === 'local_only');

      return {
        lastMessageAt: Date.now(),
        metrics: normalizedMetrics,
        summary: data.summary ?? s.summary,
        autoBoost: data.auto_boost ?? s.autoBoost,
        mumu: data.mumu ? normalizeMuMu(data.mumu) : s.mumu,
        topProcesses: Array.isArray(data.top_processes) ? data.top_processes : s.topProcesses,
        timerResolution: data.timer_resolution ?? s.timerResolution,
        pcoreAffinity: data.pcore_affinity ?? s.pcoreAffinity,
        tunnel: data.tunnel ?? s.tunnel,
        isRestartingTunnel: tunnelSettled ? false : s.isRestartingTunnel,
        observatory: data.observatory ?? s.observatory,
        vmDisk: data.mumu && Array.isArray(data.mumu.vm_disk) ? data.mumu.vm_disk : s.vmDisk,
        chartHistory: nextChart,
      };
    }),
}));
