import type {
  AlertDeliveryEntry,
  AlertsConfigUpdatePayload,
  AlertsPurgeResult,
  AlertsStatus,
  AlertTestResult,
  AutoBoostConfig,
  AutoRejoinUpdateResult,
  ChartHistory,
  ClientConfig,
  CoreAffinityInfo,
  DeepCleanExecuteResult,
  DeepCleanPreviewItem,
  DefenderStatus,
  EventLogEntry,
  GamePreset,
  GovernorAction,
  GovernorResult,
  GrowthSnapshot,
  HardeningStatus,
  MuMuHealth,
  NetworkObservatory,
  ProcessKillResult,
  ProcessTrimResult,
  RamBoostResult,
  RobloxLivePresence,
  SessionSummary,
  ShaderCacheInfo,
  SystemMetrics,
  TimerResolutionInfo,
  TopProcess,
  TrimSingleProcessResult,
  TunnelRestartResult,
  TunnelStatus,
  VmDiskItem,
} from './dashboard';

// --- Incoming Server Messages ---
export interface WsInitMessage {
  type: 'init';
  auth_required: boolean;
  authenticated: boolean;
  config: ClientConfig;
  history: EventLogEntry[];
  hardening: HardeningStatus | Record<string, never>;
  defender: DefenderStatus | Record<string, never>;
  vm_disk: VmDiskItem[];
  growth: GrowthSnapshot[];
  observatory: NetworkObservatory;
  summary: SessionSummary;
  timer_resolution: TimerResolutionInfo;
  pcore_affinity: CoreAffinityInfo;
  shader_cache: ShaderCacheInfo;
  chart_history: ChartHistory;
  alerts_status: AlertsStatus;
  alerts_history: AlertDeliveryEntry[];
  tunnel: TunnelStatus;
}

export interface WsMetricsMessage {
  type: 'metrics';
  metrics: SystemMetrics;
  summary: SessionSummary;
  auto_boost: AutoBoostConfig;
  mumu?: MuMuHealth;
  top_processes?: TopProcess[];
  timer_resolution?: TimerResolutionInfo;
  pcore_affinity?: CoreAffinityInfo;
  tunnel?: TunnelStatus;
  observatory?: NetworkObservatory;
}

export type WsServerMessage =
  | WsInitMessage
  | WsMetricsMessage
  | { type: 'event'; event: EventLogEntry }
  | { type: 'alerts_delivery'; entry: AlertDeliveryEntry }
  | { type: 'alerts_status'; data: AlertsStatus }
  | { type: 'alerts_history'; data: AlertDeliveryEntry[] }
  | { type: 'alerts_config_updated'; alerts: AlertsStatus; config: ClientConfig }
  | ({ type: 'alerts_test_result' } & AlertTestResult)
  | ({ type: 'alerts_purge_result' } & AlertsPurgeResult)
  | { type: 'tunnel_status'; data: TunnelStatus }
  | ({ type: 'tunnel_restart_result' } & TunnelRestartResult)
  | { type: 'auth_success'; authenticated: true }
  | { type: 'auth_failed'; authenticated: false }
  | { type: 'auth_result'; authenticated: boolean }
  | { type: 'auth_required'; command: string | null; error: string }
  | { type: 'error'; error: string }
  | { type: 'boost_result'; result: RamBoostResult; summary: SessionSummary }
  | { type: 'boost_triggered'; result: RamBoostResult }
  | { type: 'session_summary'; data: SessionSummary }
  | { type: 'session_boost_reset'; data: SessionSummary }
  | { type: 'total_boost_reset'; data: SessionSummary }
  | {
      type: 'config_updated';
      config: ClientConfig;
      auto_boost: {
        enabled: boolean;
        mode: string;
        threshold: number;
        interval_minutes: number;
      };
    }
  | {
      type: 'deep_clean_preview';
      data: DeepCleanPreviewItem[];
      items: DeepCleanPreviewItem[];
      total_files: number;
      total_size_mb: number;
    }
  | {
      type: 'deep_clean_result';
      data: DeepCleanExecuteResult;
      result: DeepCleanExecuteResult;
    }
  | { type: 'vm_disk_status'; data: VmDiskItem[] }
  | { type: 'vm_trim_result'; port: number; success: boolean }
  | { type: 'hardening_status'; data: HardeningStatus | Record<string, never> }
  | {
      type: 'instance_game_updated';
      instance: number | string;
      place_id: number;
      game_name: string;
      ok: boolean;
      instance_places?: Record<string, number>;
    }
  | {
      type: 'game_presets_updated';
      action?: 'added' | 'updated' | 'deleted';
      preset?: GamePreset;
      deleted_place_id?: number;
      presets: GamePreset[];
      config?: ClientConfig;
    }
  | {
      type: 'mumu_username_set';
      instance: string;
      username: string;
      presence: RobloxLivePresence;
    }
  | { type: 'defender_status'; data: DefenderStatus | Record<string, never> }
  | { type: 'quick_scan_result'; success: boolean }
  | { type: 'growth_data'; data: GrowthSnapshot[] }
  | { type: 'flush_dns_result'; success: boolean }
  | { type: 'observatory_update'; data: NetworkObservatory }
  | { type: 'mumu_trim_result'; data: TrimSingleProcessResult }
  | { type: 'process_trim_result'; data: ProcessTrimResult }
  | { type: 'process_kill_result'; data: ProcessKillResult }
  | ({ type: 'auto_rejoin_updated' } & AutoRejoinUpdateResult)
  | { type: 'timer_resolution_result'; data: TimerResolutionInfo }
  | { type: 'pcore_affinity_result'; data: CoreAffinityInfo }
  | { type: 'shader_cache_result'; data: ShaderCacheInfo }
  | { type: 'shader_cache_status'; data: ShaderCacheInfo }
  | { type: 'governor_result'; data: GovernorResult };

// --- Outgoing Client Commands ---
export interface WsCommandMap {
  auth: { token: string };
  boost: Record<string, never>;
  set_auto_boost: { enabled: boolean };
  set_threshold: { threshold: number };
  set_boost_mode: { mode: 'auto' | 'scheduled' };
  set_boost_interval: { interval_minutes: number };
  update_config: { config: Record<string, unknown> };
  deep_clean_preview: Record<string, never>;
  deep_clean_execute: { targets?: string[] };
  vm_disk_refresh: Record<string, never>;
  vm_trim_cache: { port: number };
  check_hardening: Record<string, never>;
  refresh_hardening: Record<string, never>;
  set_mumu_game: {
    instance: number | string;
    place_id: number;
    save_as_preset?: boolean;
    preset_name?: string;
  };
  add_game_preset: { place_id: number; name?: string };
  update_game_preset: { original_place_id: number; place_id: number; name: string };
  delete_game_preset: { place_id: number };
  set_mumu_username: { instance: number | string; username: string };
  set_auto_rejoin: { instance: number | null; enabled: boolean };
  defender_status: Record<string, never>;
  quick_scan: Record<string, never>;
  growth_data: Record<string, never>;
  flush_dns: Record<string, never>;
  observatory_refresh: Record<string, never>;
  reset_session_boosts: Record<string, never>;
  reset_total_boosts: Record<string, never>;
  trim_mumu_instance: { pid?: number; instance?: number };
  trim_process: { pid: number };
  kill_process: { pid: number };
  toggle_timer_resolution: { enabled: boolean };
  toggle_pcore_affinity: { enabled: boolean };
  flush_shader_cache: Record<string, never>;
  scan_shader_cache: Record<string, never>;
  governor_action: { instance: number; action: GovernorAction };
  alerts_status: Record<string, never>;
  alerts_history: Record<string, never>;
  update_alerts_config: { alerts: AlertsConfigUpdatePayload };
  test_discord_alert: Record<string, never>;
  purge_discord_alerts: { limit?: number; bot_only?: boolean };
  restart_tunnel: Record<string, never>;
}

export type WsCommandName = keyof WsCommandMap;

// --- Runtime Type Guards ---
const KNOWN_WS_TYPES: ReadonlySet<string> = new Set([
  'init',
  'metrics',
  'event',
  'alerts_delivery',
  'alerts_status',
  'alerts_history',
  'alerts_config_updated',
  'alerts_test_result',
  'alerts_purge_result',
  'tunnel_status',
  'tunnel_restart_result',
  'auth_success',
  'auth_failed',
  'auth_result',
  'auth_required',
  'error',
  'boost_result',
  'boost_triggered',
  'session_summary',
  'session_boost_reset',
  'total_boost_reset',
  'config_updated',
  'deep_clean_preview',
  'deep_clean_result',
  'vm_disk_status',
  'vm_trim_result',
  'hardening_status',
  'instance_game_updated',
  'game_presets_updated',
  'mumu_username_set',
  'auto_rejoin_updated',
  'defender_status',
  'quick_scan_result',
  'growth_data',
  'flush_dns_result',
  'observatory_update',
  'mumu_trim_result',
  'process_trim_result',
  'process_kill_result',
  'timer_resolution_result',
  'pcore_affinity_result',
  'shader_cache_result',
  'shader_cache_status',
  'governor_result',
]);

export function isRecord(val: unknown): val is Record<string, unknown> {
  return typeof val === 'object' && val !== null && !Array.isArray(val);
}

export function isHardeningPopulated(val: unknown): val is HardeningStatus {
  return isRecord(val) && isRecord(val.checks) && typeof val.last_check === 'string';
}

export function isDefenderPopulated(val: unknown): val is DefenderStatus {
  return isRecord(val) && typeof val.available === 'boolean';
}

export function parseWsServerMessage(raw: string): WsServerMessage | null {
  try {
    const parsed: unknown = JSON.parse(raw);
    if (!isRecord(parsed) || typeof parsed.type !== 'string') {
      return null;
    }
    if (!KNOWN_WS_TYPES.has(parsed.type)) {
      return null;
    }
    if (parsed.type === 'init' && !isRecord(parsed.config)) {
      return null;
    }
    if (parsed.type === 'metrics' && !isRecord(parsed.metrics)) {
      return null;
    }
    return parsed as unknown as WsServerMessage;
  } catch {
    return null;
  }
}
