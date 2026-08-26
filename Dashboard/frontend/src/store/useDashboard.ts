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

export const useDashboardStore = create<DashboardState>((set) => ({
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
    set({ token });
  },
  setUptimeSeconds: (uptimeSeconds) => set({ uptimeSeconds }),
  setChartZoom: (chartZoom) => set({ chartZoom }),
  setChartHoverIndex: (chartHoverIndex) => set({ chartHoverIndex }),
  setDeepCleanPreview: (deepCleanPreview) => set({ deepCleanPreview }),
  setIsDeepCleaning: (isDeepCleaning) => set({ isDeepCleaning }),
  setIsScanningClean: (isScanningClean) => set({ isScanningClean }),

  setAuthModalOpen: (authModalOpen) => set({ authModalOpen }),
  setCmdPaletteOpen: (cmdPaletteOpen) => set({ cmdPaletteOpen }),
  openEditGameModal: (editingDevice) => set({ editGameModalOpen: true, editingDevice }),
  closeEditGameModal: () => set({ editGameModalOpen: false, editingDevice: null }),

  addToast: (type, message) => {
    const id = `${Date.now()}_${Math.random()}`;
    set((s) => ({ toasts: [...s.toasts, { id, type, message }] }));
    setTimeout(() => {
      set((s) => ({ toasts: s.toasts.filter((t) => t.id !== id) }));
    }, 4000);
  },

  removeToast: (id) => set((s) => ({ toasts: s.toasts.filter((t) => t.id !== id) })),

  addEvent: (entry) =>
    set((s) => ({
      eventHistory: [entry, ...s.eventHistory.slice(0, 150)],
    })),

  clearEvents: () => set({ eventHistory: [] }),

  updateInitPayload: (data) =>
    set((s) => ({
      authRequired: data.auth_required ?? s.authRequired,
      authenticated: data.authenticated ?? s.authenticated,
      hardening: data.hardening ?? s.hardening,
      defender: data.defender ?? s.defender,
      observatory: data.observatory ?? s.observatory,
      summary: data.summary ?? s.summary,
      eventHistory: data.history ?? s.eventHistory,
      chartHistory: data.chart_history ?? s.chartHistory,
    })),

  updateMetricsPayload: (data) =>
    set((s) => {
      const newMetrics = data.metrics || s.metrics;
      if (newMetrics) {
        if (newMetrics.storage?.c_drive) {
          if (!newMetrics.disk) newMetrics.disk = {} as any;
          newMetrics.disk.system_free_gb = newMetrics.storage.c_drive.free_gb;
          newMetrics.disk.system_total_gb = newMetrics.storage.c_drive.total_gb;
          newMetrics.disk.system_percent = newMetrics.storage.c_drive.percent;
        }
        if (newMetrics.ram?.breakdown) {
          newMetrics.ram.active_gb = newMetrics.ram.breakdown.active_gb;
          newMetrics.ram.standby_gb = newMetrics.ram.breakdown.standby_gb;
          newMetrics.ram.free_gb = newMetrics.ram.breakdown.free_gb;
        }
      }

      const ramPct = newMetrics?.ram?.percent;
      const cpuPct = newMetrics?.cpu?.total_percent;
      const now = Date.now();

      // Update 30-min chart buffer on ~30s interval
      let newChart = s.chartHistory;
      if (ramPct !== undefined && cpuPct !== undefined) {
        const lastTs = s.chartHistory.timestamps[s.chartHistory.timestamps.length - 1] || 0;
        if (now - lastTs >= 28000 || s.chartHistory.timestamps.length === 0) {
          newChart = {
            ram: [...s.chartHistory.ram.slice(-59), ramPct],
            cpu: [...s.chartHistory.cpu.slice(-59), cpuPct],
            timestamps: [...s.chartHistory.timestamps.slice(-59), now],
          };
        }
      }

      return {
        metrics: newMetrics,
        mumu: data.mumu || s.mumu,
        topProcesses: data.top_processes || s.topProcesses,
        summary: data.summary || s.summary,
        autoBoost: data.auto_boost || s.autoBoost,
        observatory: data.observatory || s.observatory,
        chartHistory: newChart,
      };
    }),
}));
