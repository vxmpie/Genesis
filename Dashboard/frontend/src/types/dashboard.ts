// --- Navigation & Connection ---
export type WorkspaceView = 'overview' | 'instances' | 'system' | 'telemetry' | 'alerts';

export type ConnectionState = 'connecting' | 'connected' | 'reconnecting' | 'offline';

// --- System Telemetry ---
export interface RamBreakdown {
  total_gb: number;
  active_gb: number;
  standby_gb: number;
  free_gb: number;
  available_gb: number;
}

export interface PagefileMetrics {
  used_gb: number;
  total_gb: number;
  percent: number;
}

export interface CpuMetrics {
  model: string;
  total_percent: number;
  per_core: number[];
  core_count: number;
  count: number;
  p_cores: number[];
  e_cores: number[];
  frequency_ghz: number;
}

export interface RamMetrics {
  total_gb: number;
  used_gb: number;
  available_gb: number;
  percent: number;
  breakdown: RamBreakdown;
  active_gb: number;
  standby_gb: number;
  free_gb: number;
  pagefile: PagefileMetrics;
}

export type GpuMetrics =
  | {
      available: false;
    }
  | {
      available: true;
      name: string;
      temperature_c: number;
      utilization_percent: number;
      load_percent: number;
      memory_used_mb: number;
      memory_total_mb: number;
      memory_percent: number;
    };

export interface DiskMetrics {
  read_mb: number;
  write_mb: number;
  read_mb_s: number;
  write_mb_s: number;
  read_speed_mbs: number;
  write_speed_mbs: number;
  system_percent?: number;
  system_free_gb?: number;
  system_total_gb?: number;
}

export interface NetworkMetrics {
  sent_mb: number;
  recv_mb: number;
  total_sent_mb: number;
  total_recv_mb: number;
  bytes_sent_sec: number;
  bytes_recv_sec: number;
  sent_speed_mbs: number;
  recv_speed_mbs: number;
  roblox_ping_ms: number;
}

export interface StorageDriveInfo {
  total_gb: number;
  free_gb: number;
  used_gb: number;
  percent: number;
  is_low: boolean;
}

export interface SystemMetrics {
  timestamp: string;
  system?: {
    uptime: string;
    uptime_seconds: number;
  };
  cpu: CpuMetrics;
  ram: RamMetrics;
  gpu: GpuMetrics;
  disk: DiskMetrics;
  network: NetworkMetrics;
  storage?: {
    c_drive?: StorageDriveInfo;
  };
}

// --- MuMu Fleet & Roblox Presence ---
export interface GamePreset {
  place_id: number;
  name: string;
}

export interface MuMuDevice {
  pid: number;
  name: string;
  cpu_percent: number;
  ram_mb: number;
  uptime: string;
  uptime_seconds?: number;
  status: string;
  is_bloated: boolean;
  index: number;
  instance_index: number;
  adb_port?: number;
  auto_rejoin?: boolean;
  type: 'Emulator' | 'Launcher' | string;
  username: string;
  active_game: string;
  active_place_id: number | null;
  presence_status: 'Offline' | 'Online' | 'InGame' | 'InStudio' | 'Manual' | 'Unknown' | string;
  place_id: number;
  target_place_id: number;
  configured_place_id?: number;
  live_game_name?: string | null;
  target_game: string;
  target_game_name: string;
}

export interface VmDiskItem {
  port: number;
  instance: number;
  total_gb: number;
  used_gb: number;
  avail_gb: number;
  used_pct: number;
  status: 'ok' | 'warning' | 'critical';
}

export interface MuMuHealth {
  devices: MuMuDevice[];
  launchers: MuMuDevice[];
  total_instances: number;
  running: boolean;
  count: number;
  launcher_running: boolean;
  cleaner_active: boolean;
  pending_settle: boolean;
  vm_disk: VmDiskItem[];
  vm_disk_last_check: string | null;
  instance_places: Record<string, number>;
  game_presets: GamePreset[];
  auto_rejoin_global?: boolean;
  instance_auto_rejoin?: Record<string, boolean>;
}

export interface RobloxLivePresence {
  username?: string;
  presence_type?: number;
  presence_status?: string;
  place_id?: number | null;
  game_name?: string;
  last_updated?: number;
}

export type GovernorAction = 'restart_game' | 'trim_ram' | 'kill_game';

export type GovernorResult =
  | { success: true; instance: number; action: GovernorAction }
  | { success: false; error: string };

export type TrimSingleProcessResult =
  | { success: true; pid: number; name: string; freed_mb: number; note?: string }
  | { success: false; error: string };

export type ProcessTrimResult =
  | { success: true; pid: number; name: string; freed_mb: number; note?: string }
  | { success: false; pid?: number; error: string };

export type ProcessKillResult =
  | { success: true; pid: number; name: string }
  | { success: false; pid?: number; name?: string; error: string };

export interface AutoRejoinUpdateResult {
  instance: number | null;
  enabled: boolean;
  global: boolean;
  instance_auto_rejoin: Record<string, boolean>;
}

// --- Processes, Hardening & Maintenance ---
export interface TopProcess {
  pid: number;
  name: string;
  ram_mb: number;
  cpu_percent: number;
  protected?: boolean;
}

export type HardeningCheckValue = 'ok' | 'drift' | 'disabled' | 'unknown' | string;

export interface HardeningStatus {
  last_check: string;
  has_drift: boolean;
  checks: {
    vbs: HardeningCheckValue;
    mpo: HardeningCheckValue;
    hypervisor: HardeningCheckValue;
    defender_exclusion: HardeningCheckValue;
  };
  drift?: Record<string, string>;
}

export type DefenderStatus =
  | {
      available: false;
      last_check: string;
    }
  | {
      available: true;
      signature_age_days: number;
      signature_stale: boolean;
      signature_last_updated: string;
      signature_display: string;
      quick_scan_age_days: number;
      quick_scan_time: string;
      quick_scan_display: string;
      quick_scan_duration: string | null;
      full_scan_age_days: number;
      realtime_enabled: boolean;
      antivirus_enabled: boolean;
      last_check: string;
    };

export interface GrowthSnapshot {
  timestamp: string;
  folders: Record<string, number>;
  disks: Record<string, { total_gb: number; used_gb: number; free_gb: number; percent: number }>;
}

export interface SessionSummary {
  uptime_seconds: number;
  session_boosts: number;
  total_boosts: number;
  net_recoveries: number;
  last_clean_time: string;
  total_events: number;
  drift_detected: boolean;
  boost_mode: 'auto' | 'scheduled' | string;
  next_scheduled_boost: string;
  standby_guard: {
    enabled: boolean;
    purges: number;
    reclaimed_gb: number;
    last_purge: string;
  };
}

export interface RamBoostResult {
  freed_mb: number;
  freed_temp_mb: number;
  deleted_temp_files: number;
  processes_trimmed: number;
  skipped: number;
  errors: number;
  standby_purged: boolean;
  ram_before_percent: number;
  ram_after_percent: number;
  breakdown_before: RamBreakdown;
  breakdown_after: RamBreakdown;
  duration_ms: number;
}

export type NextBoostInfo =
  | { status: 'disabled'; text: string }
  | { status: 'threshold'; threshold: number; current: number; text: string }
  | { status: 'scheduled'; next_time: string; in_minutes: number; text: string };

export interface AutoBoostConfig {
  enabled: boolean;
  mode: 'auto' | 'scheduled' | string;
  threshold: number;
  interval_minutes: number;
  last_boost_time: string | null;
  last_boost_result: RamBoostResult | null;
  next_boost: NextBoostInfo | null;
}

export type DeepCleanSource = 'builtin' | 'discovered' | 'custom';

export interface DeepCleanPreviewItem {
  name: string;
  category: string;
  description: string;
  path: string;
  file_count: number;
  size_mb: number;
  requires_service_stop: string | null;
  source?: DeepCleanSource;
  enabled?: boolean;
  max_age_days?: number | null;
}

export interface DeepCleanExecuteResult {
  total_freed_mb: number;
  total_deleted: number;
  trigger?: string;
  timestamp?: string;
  details: Array<{
    name: string;
    deleted: number;
    freed_mb: number;
    source?: DeepCleanSource;
  }>;
}

export interface CustomCleanTarget {
  name: string;
  category: string;
  path: string;
  file_pattern?: string | null;
  max_age_days?: number | null;
  enabled: boolean;
}

export interface VdiCompactVmResult {
  vm_name: string;
  status: 'compacted' | 'skipped_running' | 'error' | string;
  before_mb: number;
  after_mb: number;
  freed_mb: number;
  error?: string;
}

export interface VdiCompactResult {
  ok: boolean;
  trigger?: string;
  timestamp?: string;
  total_freed_mb: number;
  compacted_count: number;
  skipped_count: number;
  error_count: number;
  vms: VdiCompactVmResult[];
  error?: string;
}

export interface AutoCleanStatus {
  auto_deep_clean_enabled: boolean;
  auto_deep_clean_hour: number;
  auto_deep_clean_threshold_mb: number;
  auto_deep_clean_min_free_gb: number;
  auto_deep_clean_cooldown_hours: number;
  auto_deep_clean_notify_min_mb: number;
  auto_discovery_enabled: boolean;
  auto_discovery_min_mb: number;
  auto_discovery_excludes: string[];
  disabled_clean_targets: string[];
  custom_clean_targets: CustomCleanTarget[];
  vdi_auto_compact_enabled: boolean;
  last_auto_clean_at: string | null;
  last_auto_clean_freed_mb: number;
  last_trigger: string | null;
  next_scheduled_run: string | null;
  last_vdi_compact_at: string | null;
  last_vdi_compact_result: VdiCompactResult | null;
  is_cleaning?: boolean;
  is_compacting_vdi?: boolean;
}

export interface AutoCleanConfigUpdatePayload {
  auto_deep_clean_enabled?: boolean;
  auto_deep_clean_hour?: number;
  auto_deep_clean_threshold_mb?: number;
  auto_deep_clean_min_free_gb?: number;
  auto_deep_clean_cooldown_hours?: number;
  auto_deep_clean_notify_min_mb?: number;
  auto_discovery_enabled?: boolean;
  auto_discovery_min_mb?: number;
  auto_discovery_excludes?: string[];
  disabled_clean_targets?: string[];
  vdi_auto_compact_enabled?: boolean;
}

export interface NetworkObservatory {
  watchdog: {
    installed: boolean;
    status: string;
    state: 'offline' | 'unknown' | 'active' | 'grace' | 'stale' | 'suspended' | 'recovering' | string;
    heartbeat_seconds: number;
    recoveries_today: number;
    level1_today: number;
    level2_today: number;
    recent_logs: string[];
    latest_recovered_line: string | null;
  };
  wifi: {
    connected: boolean;
    ssid: string;
    signal_percent: number;
    rssi_dbm: number;
    band: string;
    channel: string;
    radio_type: string;
    rx_rate_mbps: number;
    tx_rate_mbps: number;
    quality_score: number;
    quality_label: 'Excellent' | 'Good' | 'Fair' | 'Poor' | 'Offline' | string;
  };
  latency: {
    current_ms: number;
    avg_ms: number;
    jitter_ms: number;
    loss_percent: number;
    quality: 'excellent' | 'fair' | 'poor' | string;
    target: string;
  };
}

export interface TimerResolutionInfo {
  active: boolean;
  resolution_ms: number;
  min_ms?: number;
  max_ms?: number;
  error?: string;
}

export interface CoreAffinityInfo {
  enabled: boolean;
  mode: string;
  total_cores: number;
  p_cores_count: number;
  applied_count?: number;
  success?: boolean;
}

export type ShaderCacheInfo =
  | {
      success: false;
      error: string;
    }
  | {
      success?: true;
      total_files: number;
      total_size_mb: number;
      cleaned_files: number;
      cleaned_mb: number;
    };

export interface ChartHistory {
  ram: number[];
  cpu: number[];
  timestamps: number[];
}

export type EventLogType =
  | 'system'
  | 'warning'
  | 'error'
  | 'boost'
  | 'clean'
  | 'kill'
  | 'crash'
  | 'mumu'
  | 'info'
  | 'standby'
  | string;

export interface EventLogEntry {
  time: string;
  epoch?: number;
  type: EventLogType;
  message: string;
}

// --- Alerts, Bot Purge & Tunnel ---
export type AlertSeverity = 'critical' | 'warning' | 'recovery' | 'info';

export type AlertDeliveryStatus = 'delivered' | 'failed' | 'suppressed';

export type AlertToggleKey =
  | 'notify_on_startup'
  | 'notify_on_mumu_crash'
  | 'notify_on_watchdog_recovery'
  | 'notify_on_ram_critical'
  | 'notify_on_vm_disk_critical'
  | 'notify_on_drift'
  | 'notify_on_tunnel_change'
  | 'notify_on_net_outage'
  | 'notify_on_auto_clean';

export interface AlertsStatus {
  discord_webhook_configured: boolean;
  discord_webhook_masked: string;
  discord_bot_configured: boolean;
  discord_bot_masked: string;
  discord_channel_id: string;
  auto_purge_enabled: boolean;
  auto_purge_on_startup: boolean;
  auto_purge_keep_latest: number;
  auto_purge_interval_hours: number;
  heartbeat_configured: boolean;
  heartbeat_masked: string;
  heartbeat_interval_minutes: number;
  min_alert_interval_seconds: number;
  notify_on_startup: boolean;
  notify_on_mumu_crash: boolean;
  notify_on_watchdog_recovery: boolean;
  notify_on_ram_critical: boolean;
  notify_on_vm_disk_critical: boolean;
  notify_on_drift: boolean;
  notify_on_tunnel_change: boolean;
  notify_on_net_outage: boolean;
  notify_on_auto_clean: boolean;
  queue_size: number;
  delivered_count: number;
  failed_count: number;
  suppressed_count: number;
}

export interface AlertDeliveryEntry {
  id: number;
  event_type: string;
  severity: AlertSeverity;
  title: string;
  dedupe_key: string;
  status: AlertDeliveryStatus;
  http_status: number | null;
  attempts: number;
  error: string;
  timestamp: string;
}

export interface AlertTestResult {
  ok: boolean;
  http_status?: number | null;
  error: string;
  entry: AlertDeliveryEntry;
}

export interface AlertsPurgeResult {
  ok: boolean;
  deleted_count: number;
  bulk_deleted?: number;
  single_deleted?: number;
  errors?: number;
  scanned?: number;
  http_status?: number;
  error?: string;
}

export interface AlertsConfigUpdatePayload {
  clear_webhook?: boolean;
  discord_webhook_url?: string;
  clear_bot_token?: boolean;
  discord_bot_token?: string;
  discord_channel_id?: string;
  auto_purge_enabled?: boolean;
  auto_purge_on_startup?: boolean;
  auto_purge_keep_latest?: number;
  auto_purge_interval_hours?: number;
  clear_heartbeat?: boolean;
  heartbeat_url?: string;
  min_alert_interval_seconds?: number;
  heartbeat_interval_minutes?: number;
  notify_on_startup?: boolean;
  notify_on_mumu_crash?: boolean;
  notify_on_watchdog_recovery?: boolean;
  notify_on_ram_critical?: boolean;
  notify_on_vm_disk_critical?: boolean;
  notify_on_drift?: boolean;
  notify_on_tunnel_change?: boolean;
  notify_on_net_outage?: boolean;
  notify_on_auto_clean?: boolean;
}

export type TunnelStatusCode =
  | 'initializing'
  | 'connecting'
  | 'restarting'
  | 'online'
  | 'offline'
  | 'local_only';

export interface TunnelStatus {
  provider: 'none' | 'ngrok' | 'cloudflared' | 'tailscale' | 'local_only' | string;
  status: TunnelStatusCode;
  tunnel_url: string | null;
  local_url: string;
  started_at: string | null;
  last_error: string | null;
}

export interface TunnelRestartResult {
  ok: boolean;
  error?: string;
  tunnel: TunnelStatus;
}

// --- Masked Client Config ---
export interface ClientConfig {
  server: {
    host: string;
    port: number;
  };
  auth: {
    enabled: boolean;
    session_timeout_hours: number;
  };
  auto_boost: {
    enabled: boolean;
    threshold_percent: number;
    mode: 'auto' | 'scheduled' | string;
    interval_minutes: number;
    protected_processes: string[];
  };
  mumu: {
    install_path: string;
    process_names: string[];
    adb_base_port: number;
    adb_port_step: number;
    max_instances: number;
    instance_places?: Record<string, number>;
    instance_usernames?: Record<string, string>;
    instance_auto_rejoin?: Record<string, boolean>;
    game_presets?: GamePreset[];
    default_place_id?: number;
    auto_reconnect?: boolean;
    check_interval_seconds?: number;
  };
  metrics: {
    update_interval_ms: number;
    history_length: number;
  };
  maintenance: {
    deep_clean_on_boost: boolean;
    vm_disk_warn_pct: number;
    vm_disk_critical_pct: number;
    vm_auto_trim: boolean;
    defender_scan_hour: number;
    downloads_sweep_minutes: number;
    growth_snapshot_hours: number;
    drift_check_hours: number;
    standby_purge_min_available_gb: number;
    standby_purge_min_standby_gb: number;
    standby_purge_min_free_gb: number;
    auto_deep_clean_enabled?: boolean;
    auto_deep_clean_hour?: number;
    auto_deep_clean_threshold_mb?: number;
    auto_deep_clean_min_free_gb?: number;
    auto_deep_clean_cooldown_hours?: number;
    auto_deep_clean_notify_min_mb?: number;
    auto_discovery_enabled?: boolean;
    auto_discovery_min_mb?: number;
    auto_discovery_excludes?: string[];
    disabled_clean_targets?: string[];
    custom_clean_targets?: CustomCleanTarget[];
    vdi_auto_compact_enabled?: boolean;
  };
  alerts: {
    discord_webhook_url: string;
    discord_webhook_configured: boolean;
    discord_webhook_masked: string;
    discord_bot_token: string;
    discord_bot_configured: boolean;
    discord_bot_masked: string;
    discord_channel_id: string;
    auto_purge_enabled: boolean;
    auto_purge_on_startup: boolean;
    auto_purge_keep_latest: number;
    auto_purge_interval_hours: number;
    heartbeat_url: string;
    heartbeat_configured: boolean;
    heartbeat_masked: string;
    heartbeat_interval_minutes: number;
    min_alert_interval_seconds: number;
    notify_on_startup: boolean;
    notify_on_mumu_crash: boolean;
    notify_on_watchdog_recovery: boolean;
    notify_on_ram_critical: boolean;
    notify_on_vm_disk_critical: boolean;
    notify_on_drift: boolean;
    notify_on_tunnel_change: boolean;
    notify_on_net_outage: boolean;
    notify_on_auto_clean: boolean;
  };
  tunnel: {
    provider: string;
    ngrok_authtoken: string;
    ngrok_authtoken_configured: boolean;
    ngrok_domain: string;
    tailscale_url?: string;
  };
}

// --- UI Notifications ---
export interface ToastMessage {
  id: string;
  type: 'info' | 'success' | 'warning' | 'error' | 'boost' | 'crash' | 'system';
  message: string;
}
