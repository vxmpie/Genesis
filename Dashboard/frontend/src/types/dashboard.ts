export type WorkspaceView = 'overview' | 'bots' | 'system' | 'analytics';

export interface CpuMetrics {
  total_percent: number;
  per_core: number[];
  count: number;
  frequency_ghz?: number;
}

export interface RamMetrics {
  total_gb: number;
  used_gb: number;
  percent: number;
  free_gb: number;
  active_gb?: number;
  standby_gb?: number;
  swap_total_gb?: number;
  swap_used_gb?: number;
  swap_percent?: number;
}

export interface GpuMetrics {
  name?: string;
  load_percent: number;
  temperature_c?: number;
  memory_used_mb?: number;
  memory_total_mb?: number;
}

export interface DiskMetrics {
  read_mb_s: number;
  write_mb_s: number;
  system_percent?: number;
  system_free_gb?: number;
  system_total_gb?: number;
}

export interface NetworkMetrics {
  bytes_sent_sec: number;
  bytes_recv_sec: number;
  total_sent_mb: number;
  total_recv_mb: number;
  roblox_ping_ms?: number;
}

export interface SystemMetrics {
  cpu: CpuMetrics;
  ram: RamMetrics;
  gpu: GpuMetrics;
  disk: DiskMetrics;
  network: NetworkMetrics;
  uptime_seconds?: number;
  timestamp?: string;
}

export interface MuMuDevice {
  index: number;
  name: string;
  type: string;
  pid: number;
  cpu_percent: number;
  ram_mb: number;
  uptime: string;
  status: string;
  target_game?: string;
  place_id?: number;
}

export interface MuMuHealth {
  running: boolean;
  count: number;
  devices: MuMuDevice[];
}

export interface TopProcess {
  name: string;
  pid: number;
  ram_mb: number;
  cpu_percent: number;
}

export interface HardeningStatus {
  last_check: string;
  has_drift: boolean;
  checks: {
    vbs: 'ok' | 'drift' | 'disabled' | 'unknown';
    mpo: 'ok' | 'drift' | 'disabled' | 'unknown';
    hypervisor: 'ok' | 'drift' | 'disabled' | 'unknown';
    defender_exclusion: 'ok' | 'drift' | 'disabled' | 'unknown';
  };
  drift?: Record<string, string>;
}

export interface DefenderStatus {
  signature_age_days: number;
  signature_display?: string;
  signature_last_updated?: string;
  signature_stale: boolean;
  quick_scan_age_days: number;
  quick_scan_display?: string;
  quick_scan_time?: string;
  quick_scan_duration?: string;
  realtime_enabled: boolean;
}

export interface SessionSummary {
  uptime_seconds: number;
  session_boosts: number;
  total_boosts: number;
  net_recoveries: number;
  last_clean_time?: string;
  drift_detected: boolean;
  boost_mode?: string;
  next_scheduled_boost?: string;
  standby_guard?: {
    purges: number;
    reclaimed_gb: number;
  };
}

export interface NetworkObservatory {
  latency?: {
    current_ms: number;
    jitter_ms: number;
    loss_percent: number;
    quality: string;
  };
  wifi?: {
    ssid: string;
    band: string;
    signal_percent: number;
    rssi_dbm: number;
    rx_rate_mbps: number;
    tx_rate_mbps: number;
    quality_label: string;
    quality_score: number;
  };
  watchdog?: {
    state: string;
    status: string;
    recoveries_today: number;
    heartbeat_seconds: number;
    recent_logs: string[];
  };
}

export interface EventLogEntry {
  time: string;
  type: 'boost' | 'warning' | 'crash' | 'system' | 'kill' | 'error' | 'info';
  message: string;
}

export interface AutoBoostConfig {
  enabled: boolean;
  mode: 'auto' | 'scheduled';
  threshold: number;
  interval_minutes?: number;
  last_boost_time?: string | null;
  last_boost_result?: {
    freed_mb: number;
    processes_trimmed: number;
    standby_purged: boolean;
    freed_temp_mb: number;
    deleted_temp_files: number;
  } | null;
}

export interface DeepCleanPreviewItem {
  name: string;
  category: string;
  size_mb: number;
  file_count: number;
  description: string;
}

export interface ToastMessage {
  id: string;
  type: 'boost' | 'warning' | 'crash' | 'system' | 'info' | 'error';
  message: string;
}
