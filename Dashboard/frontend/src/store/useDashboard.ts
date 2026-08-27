import { create } from 'zustand';
import type {
  WorkspaceView,
  SystemMetrics,
  MuMuHealth,
  TopProcess,
  SessionSummary,
  AutoBoostConfig,
  HardeningStatus,
  DefenderStatus,
  NetworkObservatory,
  EventLogEntry,
  DeepCleanPreviewItem,
  ToastMessage,
  MuMuDevice,
  TimerResolutionInfo,
  CoreAffinityInfo,
  ShaderCacheInfo,
} from '../types/dashboard';

interface DashboardState {
  activeView: WorkspaceView;
  connected: boolean;
  authenticated: boolean;
  authRequired: boolean;
  token: string;
  uptimeSeconds: number;

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
  eventHistory: EventLogEntry[];
  chartHistory: {
    ram: number[];
    cpu: number[];
    timestamps: number[];
  };
  chartZoom: 5 | 15 | 30;
  chartHoverIndex: number;
  deepCleanPreview: DeepCleanPreviewItem[];
  isDeepCleaning: boolean;
  isScanningClean: boolean;

  toasts: ToastMessage[];
  authModalOpen: boolean;
  cmdPaletteOpen: boolean;
  editGameModalOpen: boolean;
  editingDevice: MuMuDevice | null;

  // Actions
  setActiveView: (view: WorkspaceView) => void;
  setConnected: (connected: boolean) => void;
  setAuthenticated: (authed: boolean) => void;
  setAuthRequired: (required: boolean) => void;
  setToken: (token: string) => void;
  setUptimeSeconds: (sec: number) => void;
  setChartZoom: (zoom: 5 | 15 | 30) => void;
  setChartHoverIndex: (idx: number) => void;
  setDeepCleanPreview: (items: DeepCleanPreviewItem[]) => void;
  setIsDeepCleaning: (v: boolean) => void;
  setIsScanningClean: (v: boolean) => void;
  updateAutoBoost: (partial: Partial<NonNullable<DashboardState['autoBoost']>>) => void;
  setTimerResolution: (t: TimerResolutionInfo) => void;
  setPcoreAffinity: (a: CoreAffinityInfo) => void;
  setShaderCache: (s: ShaderCacheInfo) => void;

  setAuthModalOpen: (open: boolean) => void;
  setCmdPaletteOpen: (open: boolean) => void;
  openEditGameModal: (dev: MuMuDevice) => void;
  closeEditGameModal: () => void;

  addToast: (type: ToastMessage['type'], message: string) => void;
  removeToast: (id: string) => void;
  addEvent: (entry: EventLogEntry) => void;
  clearEvents: () => void;

  updateInitPayload: (data: any) => void;
  updateMetricsPayload: (data: any) => void;
}

export const useDashboardStore = create<DashboardState>((set, get) => ({
  activeView: 'overview',
  connected: false,
  authenticated: false,
  authRequired: false,
  token: localStorage.getItem('genesis_auth_token') || '',
  uptimeSeconds: 0,

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
  eventHistory: [],
  chartHistory: {
    ram: [],
    cpu: [],
    timestamps: [],
  },
  chartZoom: 30,
  chartHoverIndex: -1,
  deepCleanPreview: [],
  isDeepCleaning: false,
  isScanningClean: false,

  toasts: [],
  authModalOpen: false,
  cmdPaletteOpen: false,
  editGameModalOpen: false,
  editingDevice: null,

  setActiveView: (activeView) => set({ activeView }),
  setConnected: (connected) => set({ connected }),
  setAuthenticated: (authenticated) => set({ authenticated }),
  setAuthRequired: (authRequired) => set({ authRequired }),
  setToken: (token) => {
    localStorage.setItem('genesis_auth_token', token);
    set({ token, authenticated: !!token });
  },
  setUptimeSeconds: (uptimeSeconds) => set({ uptimeSeconds }),
  setChartZoom: (chartZoom) => set({ chartZoom }),
  setChartHoverIndex: (chartHoverIndex) => set({ chartHoverIndex }),
  setDeepCleanPreview: (deepCleanPreview) => set({ deepCleanPreview }),
  setIsDeepCleaning: (isDeepCleaning) => set({ isDeepCleaning }),
  setIsScanningClean: (isScanningClean) => set({ isScanningClean }),
  updateAutoBoost: (partial) =>
    set((s) => ({
      autoBoost: s.autoBoost ? { ...s.autoBoost, ...partial } : (partial as any),
    })),
  setTimerResolution: (timerResolution) => set({ timerResolution }),
  setPcoreAffinity: (pcoreAffinity) => set({ pcoreAffinity }),
  setShaderCache: (shaderCache) => set({ shaderCache }),

  setAuthModalOpen: (authModalOpen) => set({ authModalOpen }),
  setCmdPaletteOpen: (cmdPaletteOpen) => set({ cmdPaletteOpen }),
  openEditGameModal: (editingDevice) => set({ editGameModalOpen: true, editingDevice }),
  closeEditGameModal: () => set({ editGameModalOpen: false, editingDevice: null }),

  addToast: (type, message) => {
    // Suppress duplicate identical active toast
    const active = get().toasts;
    if (active.some((t) => t.message === message)) return;

    const id = `${Date.now()}_${Math.random()}`;
    set((s) => ({ toasts: [...s.toasts, { id, type, message }] }));
    setTimeout(() => {
      set((s) => ({ toasts: s.toasts.filter((t) => t.id !== id) }));
    }, 4000);
  },

  removeToast: (id) => set((s) => ({ toasts: s.toasts.filter((t) => t.id !== id) })),

  addEvent: (entry) =>
    set((s) => {
      const filtered = s.eventHistory.filter((e) => e.time !== entry.time || e.message !== entry.message);
      return {
        eventHistory: [entry, ...filtered].slice(0, 150),
      };
    }),

  clearEvents: () => set({ eventHistory: [] }),

  updateInitPayload: (data) =>
    set((s) => {
      let chartHist = data.chart_history || s.chartHistory;
      if (chartHist && (!chartHist.timestamps || chartHist.timestamps.length === 0)) {
        // Seed initial history point
        const now = Date.now();
        chartHist = {
          ram: [data.metrics?.ram?.percent || 40],
          cpu: [data.metrics?.cpu?.total_percent || 15],
          timestamps: [now],
        };
      }

      // Sort incoming history strictly descending (newest at index 0, oldest at bottom)
      const rawEvents = Array.isArray(data.history) ? data.history : s.eventHistory;
      const sortedEvents = [...rawEvents].sort((a: any, b: any) => {
        if (a.epoch && b.epoch) return b.epoch - a.epoch;
        return String(b.time || '').localeCompare(String(a.time || ''));
      });

      return {
        authRequired: data.auth_required ?? s.authRequired,
        authenticated: s.authenticated || (data.authenticated ?? false),
        hardening: data.hardening ?? s.hardening,
        defender: data.defender ?? s.defender,
        observatory: data.observatory ?? s.observatory,
        timerResolution: data.timer_resolution ?? s.timerResolution,
        pcoreAffinity: data.pcore_affinity ?? s.pcoreAffinity,
        shaderCache: data.shader_cache ?? s.shaderCache,
        summary: data.summary ?? s.summary,
        eventHistory: sortedEvents.slice(0, 150),
        chartHistory: chartHist,
      };
    }),

  updateMetricsPayload: (data) =>
    set((s) => {
      const newMetrics = data.metrics || s.metrics;
      if (newMetrics) {
        if (newMetrics.storage?.c_drive) {
          if (!newMetrics.disk) {
            newMetrics.disk = {
              read_mb_s: 0,
              write_mb_s: 0,
            };
          }
          newMetrics.disk.system_free_gb = newMetrics.storage.c_drive.free_gb;
          newMetrics.disk.system_total_gb = newMetrics.storage.c_drive.total_gb;
          newMetrics.disk.system_percent = newMetrics.storage.c_drive.percent;
        }
        if (newMetrics.ram?.breakdown) {
          newMetrics.ram.active_gb = newMetrics.ram.breakdown.active_gb;
          newMetrics.ram.standby_gb = newMetrics.ram.breakdown.standby_gb;
          newMetrics.ram.free_gb = newMetrics.ram.breakdown.free_gb;
        }
        if (newMetrics.disk) {
          newMetrics.disk.read_mb_s = newMetrics.disk.read_mb_s ?? newMetrics.disk.read_speed_mbs ?? 0;
          newMetrics.disk.write_mb_s = newMetrics.disk.write_mb_s ?? newMetrics.disk.write_speed_mbs ?? 0;
        }
        if (newMetrics.network) {
          const sentMbs = newMetrics.network.sent_speed_mbs ?? ((newMetrics.network.bytes_sent_sec || 0) / (1024 * 1024));
          const recvMbs = newMetrics.network.recv_speed_mbs ?? ((newMetrics.network.bytes_recv_sec || 0) / (1024 * 1024));
          newMetrics.network.sent_speed_mbs = sentMbs;
          newMetrics.network.recv_speed_mbs = recvMbs;
          newMetrics.network.bytes_sent_sec = newMetrics.network.bytes_sent_sec || Math.round(Number(sentMbs) * 1024 * 1024);
          newMetrics.network.bytes_recv_sec = newMetrics.network.bytes_recv_sec || Math.round(Number(recvMbs) * 1024 * 1024);
        }
      }

      // Normalize MuMu data
      let mumuData = data.mumu || s.mumu;
      if (mumuData && mumuData.devices) {
        mumuData = {
          ...mumuData,
          devices: mumuData.devices.map((d: any, idx: number) => ({
            ...d,
            index: d.index ?? d.instance_index ?? (idx + 1),
            type: d.type ?? (d.name?.toLowerCase().includes('device') ? 'Emulator' : 'Launcher'),
            target_game: d.target_game ?? d.target_game_name ?? 'Storage Hunters',
            place_id: d.place_id ?? d.target_place_id ?? 98800969324557,
          })),
        };
      }

      const ramPct = newMetrics?.ram?.percent;
      const cpuPct = newMetrics?.cpu?.total_percent;
      const now = Date.now();

      // Rolling chart buffer (records sample every ~1000-2000ms for continuous silky smooth canvas)
      let newChart = s.chartHistory;
      if (ramPct !== undefined && cpuPct !== undefined) {
        const lastTs = s.chartHistory.timestamps[s.chartHistory.timestamps.length - 1] || 0;
        if (now - lastTs >= 1000 || s.chartHistory.timestamps.length === 0) {
          newChart = {
            ram: [...s.chartHistory.ram.slice(-180), ramPct],
            cpu: [...s.chartHistory.cpu.slice(-180), cpuPct],
            timestamps: [...s.chartHistory.timestamps.slice(-180), now],
          };
        }
      }

      return {
        metrics: newMetrics,
        mumu: mumuData,
        topProcesses: data.top_processes || s.topProcesses,
        summary: data.summary || s.summary,
        autoBoost: data.auto_boost || s.autoBoost,
        observatory: data.observatory || s.observatory,
        timerResolution: data.timer_resolution ?? s.timerResolution,
        pcoreAffinity: data.pcore_affinity ?? s.pcoreAffinity,
        shaderCache: data.shader_cache ?? s.shaderCache,
        chartHistory: newChart,
      };
    }),
}));
