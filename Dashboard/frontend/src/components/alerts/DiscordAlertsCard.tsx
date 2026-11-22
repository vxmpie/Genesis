import React, { useState } from 'react';
import {
  ChevronDown,
  ChevronRight,
  Eye,
  EyeOff,
  Loader2,
  RotateCcw,
  Save,
  Send,
  ShieldAlert,
  Trash2,
} from 'lucide-react';
import { useDashboardStore } from '../../store/useDashboard';
import type {
  AlertsConfigUpdatePayload,
  AlertsStatus,
  AlertToggleKey,
} from '../../types/dashboard';
import { OpsSwitch, StatusBadge } from '../ui';

interface DiscordAlertsCardProps {
  onSaveConfig: (payload: AlertsConfigUpdatePayload) => void;
  onSendTest: () => void;
  onPurgeMessages: (limit: number, botOnly: boolean) => void;
}

interface ToggleMeta {
  key: AlertToggleKey;
  label: string;
  desc: string;
}

interface FormDraft {
  minInterval?: number;
  heartbeatMinutes?: number;
  channelId?: string;
  autoPurgeEnabled?: boolean;
  autoPurgeOnStartup?: boolean;
  autoPurgeKeepLatest?: number;
  autoPurgeIntervalHours?: number;
  toggles?: Partial<Record<AlertToggleKey, boolean>>;
}

const CRITICAL_TOGGLES: readonly ToggleMeta[] = [
  {
    key: 'notify_on_mumu_crash',
    label: 'MuMu Crash',
    desc: 'Unexpected emulator exit after settle window',
  },
  {
    key: 'notify_on_ram_critical',
    label: 'RAM Critical (>=90%)',
    desc: 'Alerts in both auto and scheduled modes',
  },
  {
    key: 'notify_on_vm_disk_critical',
    label: 'VM Disk Critical (>=90%)',
    desc: 'Android /data filesystem capacity alert',
  },
  {
    key: 'notify_on_net_outage',
    label: 'Network Outage',
    desc: 'Watchdog disconnect and recovery reports',
  },
];

const OPS_TOGGLES: readonly ToggleMeta[] = [
  {
    key: 'notify_on_watchdog_recovery',
    label: 'Watchdog Recovery',
    desc: 'Roblox relaunch / disconnect recovery',
  },
  {
    key: 'notify_on_drift',
    label: 'Hardening Drift',
    desc: 'VBS, MPO, Hypervisor, or exclusion mismatch',
  },
  {
    key: 'notify_on_tunnel_change',
    label: 'Tunnel Change',
    desc: 'Public URL disconnect or reconnect assignment',
  },
  {
    key: 'notify_on_startup',
    label: 'Core Startup',
    desc: 'Dispatch online status & ingress URL at boot',
  },
  {
    key: 'notify_on_auto_clean',
    label: 'Auto Deep Clean',
    desc: 'Scheduled or threshold cleanup when >=50 MB reclaimed',
  },
];

const COOLDOWN_PRESETS = [15, 60, 180, 300] as const;
const KEEP_LATEST_PRESETS = [5, 15, 50] as const;
const INTERVAL_HOUR_PRESETS = [1, 6, 12, 24] as const;
const PURGE_LIMITS = [50, 100, 250, 500] as const;

function isValidHttpUrl(raw: string): boolean {
  try {
    const parsed = new URL(raw);
    return parsed.protocol === 'http:' || parsed.protocol === 'https:';
  } catch {
    return false;
  }
}

export const DiscordAlertsCard: React.FC<DiscordAlertsCardProps> = (props) => {
  const lastAlertsSavedAt = useDashboardStore((s) => s.lastAlertsSavedAt);
  return <DiscordAlertsForm key={lastAlertsSavedAt ?? 0} {...props} />;
};

const DiscordAlertsForm: React.FC<DiscordAlertsCardProps> = ({
  onSaveConfig,
  onSendTest,
  onPurgeMessages,
}) => {
  const alertsStatus: AlertsStatus | null = useDashboardStore((s) => s.alertsStatus);
  const isSaving = useDashboardStore((s) => s.isSavingAlerts);
  const isTesting = useDashboardStore((s) => s.isTestingAlert);
  const isPurging = useDashboardStore((s) => s.isPurgingAlerts);
  const lastTestResult = useDashboardStore((s) => s.lastAlertTestResult);
  const lastPurgeResult = useDashboardStore((s) => s.lastAlertPurgeResult);

  // --- Draft & Secret Input State ---
  const [draft, setDraft] = useState<FormDraft>({});
  const [webhookInput, setWebhookInput] = useState('');
  const [showWebhookInput, setShowWebhookInput] = useState(false);
  const [heartbeatInput, setHeartbeatInput] = useState('');
  const [showHeartbeatInput, setShowHeartbeatInput] = useState(false);
  const [botTokenInput, setBotTokenInput] = useState('');
  const [showBotTokenInput, setShowBotTokenInput] = useState(false);
  const [validationError, setValidationError] = useState('');

  // --- Disclosure & Confirmation State ---
  const [heartbeatOpen, setHeartbeatOpen] = useState(false);
  const [purgeOpen, setPurgeOpen] = useState(false);
  const [confirmClearWebhook, setConfirmClearWebhook] = useState(false);
  const [confirmClearHeartbeat, setConfirmClearHeartbeat] = useState(false);
  const [confirmClearBotToken, setConfirmClearBotToken] = useState(false);
  const [confirmPurge, setConfirmPurge] = useState(false);
  const [purgeLimit, setPurgeLimit] = useState<number>(100);
  const [purgeBotOnly, setPurgeBotOnly] = useState(true);

  const minInterval = draft.minInterval ?? alertsStatus?.min_alert_interval_seconds ?? 60;
  const heartbeatMinutes =
    draft.heartbeatMinutes ?? alertsStatus?.heartbeat_interval_minutes ?? 5;
  const channelIdInput = draft.channelId ?? alertsStatus?.discord_channel_id ?? '';
  const autoPurgeEnabled =
    draft.autoPurgeEnabled ?? alertsStatus?.auto_purge_enabled ?? true;
  const autoPurgeOnStartup =
    draft.autoPurgeOnStartup ?? alertsStatus?.auto_purge_on_startup ?? true;
  const autoPurgeKeepLatest =
    draft.autoPurgeKeepLatest ?? alertsStatus?.auto_purge_keep_latest ?? 15;
  const autoPurgeIntervalHours =
    draft.autoPurgeIntervalHours ?? alertsStatus?.auto_purge_interval_hours ?? 6;

  const getToggleValue = (key: AlertToggleKey): boolean =>
    draft.toggles?.[key] ?? alertsStatus?.[key] ?? true;

  const isDirty =
    draft.minInterval !== undefined ||
    draft.heartbeatMinutes !== undefined ||
    draft.channelId !== undefined ||
    draft.autoPurgeEnabled !== undefined ||
    draft.autoPurgeOnStartup !== undefined ||
    draft.autoPurgeKeepLatest !== undefined ||
    draft.autoPurgeIntervalHours !== undefined ||
    (draft.toggles !== undefined && Object.keys(draft.toggles).length > 0) ||
    webhookInput.length > 0 ||
    heartbeatInput.length > 0 ||
    botTokenInput.length > 0;

  const resetForm = () => {
    setDraft({});
    setWebhookInput('');
    setHeartbeatInput('');
    setBotTokenInput('');
    setValidationError('');
  };

  const handleToggleChange = (key: AlertToggleKey) => {
    const nextVal = !getToggleValue(key);
    setDraft((prev) => ({
      ...prev,
      toggles: { ...prev.toggles, [key]: nextVal },
    }));
    setValidationError('');
  };

  const handleSave = (e: React.FormEvent) => {
    e.preventDefault();
    setValidationError('');

    const trimmedWebhook = webhookInput.trim();
    if (trimmedWebhook && (trimmedWebhook.includes('****') || !isValidHttpUrl(trimmedWebhook))) {
      setValidationError('Discord Webhook URL must be a valid http(s) URL.');
      return;
    }

    const trimmedHeartbeat = heartbeatInput.trim();
    if (
      trimmedHeartbeat &&
      (trimmedHeartbeat.includes('****') || !isValidHttpUrl(trimmedHeartbeat))
    ) {
      setValidationError('Heartbeat URL must be a valid http(s) URL.');
      return;
    }

    const trimmedBotToken = botTokenInput.trim();
    if (trimmedBotToken && trimmedBotToken.includes('****')) {
      setValidationError('Bot token cannot contain masked placeholder characters.');
      return;
    }

    const trimmedChannelId = channelIdInput.trim();
    if (trimmedChannelId && !/^\d+$/.test(trimmedChannelId)) {
      setValidationError('Discord Channel ID must be numeric digits only.');
      return;
    }

    const clampedCooldown = Math.max(5, Math.min(3600, Math.round(Number(minInterval) || 60)));
    const clampedHbMinutes = Math.max(
      1,
      Math.min(1440, Math.round(Number(heartbeatMinutes) || 5))
    );
    const parsedKeep = Number(autoPurgeKeepLatest);
    const clampedKeepLatest = Math.max(
      0,
      Math.min(100, Number.isFinite(parsedKeep) ? Math.round(parsedKeep) : 15)
    );
    const parsedIntervalHours = Number(autoPurgeIntervalHours);
    const clampedIntervalHours = Math.max(
      1,
      Math.min(168, Number.isFinite(parsedIntervalHours) ? Math.round(parsedIntervalHours) : 6)
    );

    const payload: AlertsConfigUpdatePayload = {
      min_alert_interval_seconds: clampedCooldown,
      heartbeat_interval_minutes: clampedHbMinutes,
      discord_channel_id: trimmedChannelId,
      auto_purge_enabled: autoPurgeEnabled,
      auto_purge_on_startup: autoPurgeOnStartup,
      auto_purge_keep_latest: clampedKeepLatest,
      auto_purge_interval_hours: clampedIntervalHours,
      notify_on_startup: getToggleValue('notify_on_startup'),
      notify_on_mumu_crash: getToggleValue('notify_on_mumu_crash'),
      notify_on_watchdog_recovery: getToggleValue('notify_on_watchdog_recovery'),
      notify_on_ram_critical: getToggleValue('notify_on_ram_critical'),
      notify_on_vm_disk_critical: getToggleValue('notify_on_vm_disk_critical'),
      notify_on_drift: getToggleValue('notify_on_drift'),
      notify_on_tunnel_change: getToggleValue('notify_on_tunnel_change'),
      notify_on_net_outage: getToggleValue('notify_on_net_outage'),
      notify_on_auto_clean: getToggleValue('notify_on_auto_clean'),
    };

    if (trimmedWebhook) payload.discord_webhook_url = trimmedWebhook;
    if (trimmedHeartbeat) payload.heartbeat_url = trimmedHeartbeat;
    if (trimmedBotToken) payload.discord_bot_token = trimmedBotToken;

    onSaveConfig(payload);
  };

  const renderToggleRow = (meta: ToggleMeta) => {
    const checked = getToggleValue(meta.key);
    return (
      <div
        key={meta.key}
        className="flex items-center justify-between gap-3 py-2 px-2.5 rounded-md bg-ops-inset border border-ops-border"
      >
        <div className="min-w-0">
          <div className="text-xs font-medium text-ops-text">{meta.label}</div>
          <div className="text-[11px] text-ops-muted truncate">{meta.desc}</div>
        </div>
        <OpsSwitch
          ariaLabel={meta.label}
          checked={checked}
          onChange={() => handleToggleChange(meta.key)}
        />
      </div>
    );
  };

  const botPurgeReady = Boolean(
    alertsStatus?.discord_bot_configured && alertsStatus?.discord_channel_id
  );

  return (
    <form onSubmit={handleSave} className="ops-card p-4 flex flex-col gap-4">
      <div className="space-y-4">
        {/* Card Header */}
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div>
            <h2 className="text-xs font-semibold text-ops-text uppercase tracking-wider">
              Discord Notification Pipeline
            </h2>
            <p className="text-xs text-ops-secondary mt-0.5">
              Write-only secret storage. Existing tokens are masked and never returned in plaintext.
            </p>
          </div>
          {isDirty && <StatusBadge tone="warn">Unsaved changes</StatusBadge>}
        </div>

        {/* Webhook Input Section */}
        <div className="p-3 rounded-md bg-ops-inset border border-ops-border space-y-2.5">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <label htmlFor="discord-webhook-input" className="text-xs font-medium text-ops-text">
              Discord Webhook URL
            </label>
            <div className="flex items-center gap-2">
              <StatusBadge tone={alertsStatus?.discord_webhook_configured ? 'ok' : 'warn'}>
                {alertsStatus?.discord_webhook_configured ? 'Configured' : 'Not Configured'}
              </StatusBadge>
              {alertsStatus?.discord_webhook_configured &&
                (confirmClearWebhook ? (
                  <div className="inline-flex items-center gap-1">
                    <button
                      type="button"
                      onClick={() => {
                        setConfirmClearWebhook(false);
                        onSaveConfig({ clear_webhook: true });
                      }}
                      className="ops-btn px-2 py-0.5 bg-ops-danger text-white text-[11px]"
                    >
                      Confirm Clear
                    </button>
                    <button
                      type="button"
                      onClick={() => setConfirmClearWebhook(false)}
                      className="ops-btn px-2 py-0.5 bg-ops-elevated text-ops-secondary border border-ops-border text-[11px]"
                    >
                      Cancel
                    </button>
                  </div>
                ) : (
                  <button
                    type="button"
                    onClick={() => setConfirmClearWebhook(true)}
                    className="ops-btn px-2 py-0.5 text-[11px] text-ops-secondary hover:text-ops-danger border border-ops-border bg-ops-surface"
                  >
                    Clear
                  </button>
                ))}
            </div>
          </div>

          {alertsStatus?.discord_webhook_configured && alertsStatus.discord_webhook_masked && (
            <div className="font-mono text-[11px] text-ops-secondary bg-ops-surface border border-ops-border rounded px-2.5 py-1.5 truncate">
              Active: {alertsStatus.discord_webhook_masked}
            </div>
          )}

          <div className="relative">
            <input
              id="discord-webhook-input"
              type={showWebhookInput ? 'text' : 'password'}
              value={webhookInput}
              onChange={(e) => {
                setWebhookInput(e.target.value);
                setValidationError('');
              }}
              placeholder={
                alertsStatus?.discord_webhook_configured
                  ? 'Paste new webhook URL to replace existing secret...'
                  : 'https://discord.com/api/webhooks/...'
              }
              autoComplete="off"
              className="ops-input w-full h-9 pl-3 pr-9 text-xs font-mono"
            />
            <button
              type="button"
              onClick={() => setShowWebhookInput((v) => !v)}
              aria-label={showWebhookInput ? 'Hide webhook input' : 'Show webhook input'}
              className="absolute right-2 top-1/2 -translate-y-1/2 p-1 text-ops-muted hover:text-ops-text"
            >
              {showWebhookInput ? <EyeOff className="w-3.5 h-3.5" /> : <Eye className="w-3.5 h-3.5" />}
            </button>
          </div>
        </div>

        {/* Cooldown Control */}
        <div className="p-3 rounded-md bg-ops-inset border border-ops-border flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div>
            <label htmlFor="alert-cooldown-input" className="text-xs font-medium text-ops-text block">
              Per-Entity Alert Cooldown (seconds)
            </label>
            <span className="text-[11px] text-ops-muted">
              Suppresses identical repeated alerts within the configured window (5–3600s).
            </span>
          </div>
          <div className="flex items-center gap-1.5 shrink-0 flex-wrap">
            {COOLDOWN_PRESETS.map((sec) => (
              <button
                key={sec}
                type="button"
                onClick={() => setDraft((prev) => ({ ...prev, minInterval: sec }))}
                className={`num px-2 py-1 rounded text-[11px] font-mono border transition-colors ${
                  minInterval === sec
                    ? 'bg-ops-elevated text-ops-text border-ops-borderStrong'
                    : 'bg-ops-surface text-ops-muted border-ops-border hover:text-ops-text'
                }`}
              >
                {sec}s
              </button>
            ))}
            <input
              id="alert-cooldown-input"
              type="number"
              min={5}
              max={3600}
              value={minInterval}
              onChange={(e) => setDraft((prev) => ({ ...prev, minInterval: Number(e.target.value) }))}
              className="ops-input num w-20 h-8 px-2 text-xs font-mono text-right"
            />
          </div>
        </div>

        {/* Granular Event Toggles */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
          <div className="space-y-1.5">
            <div className="text-[10px] font-mono uppercase tracking-wider text-ops-muted px-0.5">
              Critical & Incidents
            </div>
            <div className="space-y-1.5">{CRITICAL_TOGGLES.map(renderToggleRow)}</div>
          </div>

          <div className="space-y-1.5">
            <div className="text-[10px] font-mono uppercase tracking-wider text-ops-muted px-0.5">
              Operations & Lifecycle
            </div>
            <div className="space-y-1.5">{OPS_TOGGLES.map(renderToggleRow)}</div>
          </div>
        </div>

        {/* Collapsible: External Heartbeat */}
        <div className="rounded-md border border-ops-border bg-ops-inset overflow-hidden">
          <button
            type="button"
            onClick={() => setHeartbeatOpen((v) => !v)}
            className="w-full px-3 py-2.5 flex items-center justify-between gap-2 text-left hover:bg-ops-elevated/40 transition-colors"
          >
            <div className="flex items-center gap-2 min-w-0">
              {heartbeatOpen ? (
                <ChevronDown className="w-3.5 h-3.5 text-ops-muted shrink-0" />
              ) : (
                <ChevronRight className="w-3.5 h-3.5 text-ops-muted shrink-0" />
              )}
              <span className="text-xs font-medium text-ops-text">External Heartbeat</span>
              <span className="text-[11px] text-ops-muted hidden sm:inline">
                (Dead-man switch ping)
              </span>
            </div>
            <StatusBadge tone={alertsStatus?.heartbeat_configured ? 'ok' : 'muted'}>
              {alertsStatus?.heartbeat_configured
                ? `Active (${alertsStatus.heartbeat_interval_minutes}m)`
                : 'Not Set'}
            </StatusBadge>
          </button>

          {heartbeatOpen && (
            <div className="px-3 pb-3 pt-2 border-t border-ops-border space-y-2.5">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <span className="font-mono text-[11px] text-ops-secondary truncate">
                  {alertsStatus?.heartbeat_configured
                    ? `Current: ${alertsStatus.heartbeat_masked}`
                    : 'No external heartbeat ping URL configured.'}
                </span>
                {alertsStatus?.heartbeat_configured &&
                  (confirmClearHeartbeat ? (
                    <div className="inline-flex items-center gap-1">
                      <button
                        type="button"
                        onClick={() => {
                          setConfirmClearHeartbeat(false);
                          onSaveConfig({ clear_heartbeat: true });
                        }}
                        className="ops-btn px-2 py-0.5 bg-ops-danger text-white text-[11px]"
                      >
                        Confirm Clear
                      </button>
                      <button
                        type="button"
                        onClick={() => setConfirmClearHeartbeat(false)}
                        className="ops-btn px-2 py-0.5 bg-ops-elevated text-ops-secondary border border-ops-border text-[11px]"
                      >
                        Cancel
                      </button>
                    </div>
                  ) : (
                    <button
                      type="button"
                      onClick={() => setConfirmClearHeartbeat(true)}
                      className="ops-btn px-2 py-0.5 text-[11px] text-ops-secondary hover:text-ops-danger border border-ops-border bg-ops-surface"
                    >
                      Clear
                    </button>
                  ))}
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
                <div className="sm:col-span-2 relative">
                  <input
                    type={showHeartbeatInput ? 'text' : 'password'}
                    value={heartbeatInput}
                    onChange={(e) => {
                      setHeartbeatInput(e.target.value);
                      setValidationError('');
                    }}
                    placeholder="https://hc-ping.com/..."
                    autoComplete="off"
                    className="ops-input w-full h-9 pl-3 pr-9 text-xs font-mono"
                  />
                  <button
                    type="button"
                    onClick={() => setShowHeartbeatInput((v) => !v)}
                    aria-label={showHeartbeatInput ? 'Hide heartbeat URL' : 'Show heartbeat URL'}
                    className="absolute right-2 top-1/2 -translate-y-1/2 p-1 text-ops-muted hover:text-ops-text"
                  >
                    {showHeartbeatInput ? (
                      <EyeOff className="w-3.5 h-3.5" />
                    ) : (
                      <Eye className="w-3.5 h-3.5" />
                    )}
                  </button>
                </div>
                <div className="flex items-center gap-2">
                  <label htmlFor="hb-interval-input" className="text-[11px] text-ops-muted shrink-0">
                    Interval (m)
                  </label>
                  <input
                    id="hb-interval-input"
                    type="number"
                    min={1}
                    max={1440}
                    value={heartbeatMinutes}
                    onChange={(e) =>
                      setDraft((prev) => ({ ...prev, heartbeatMinutes: Number(e.target.value) }))
                    }
                    className="ops-input num w-full h-9 px-2.5 text-xs font-mono text-right"
                  />
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Collapsible: Bot Auto-Purge & Channel Cleanup */}
        <div className="rounded-md border border-ops-border bg-ops-inset overflow-hidden">
          <button
            type="button"
            onClick={() => setPurgeOpen((v) => !v)}
            className="w-full px-3 py-2.5 flex items-center justify-between gap-2 text-left hover:bg-ops-elevated/40 transition-colors"
          >
            <div className="flex items-center gap-2 min-w-0">
              {purgeOpen ? (
                <ChevronDown className="w-3.5 h-3.5 text-ops-muted shrink-0" />
              ) : (
                <ChevronRight className="w-3.5 h-3.5 text-ops-muted shrink-0" />
              )}
              <span className="text-xs font-medium text-ops-text">
                Bot Auto-Purge & Channel Cleanup
              </span>
              <span className="text-[11px] text-ops-muted hidden sm:inline">
                (Scheduled & on-demand retention)
              </span>
            </div>
            <StatusBadge
              tone={!botPurgeReady ? 'muted' : autoPurgeEnabled ? 'ok' : 'info'}
            >
              {!botPurgeReady
                ? 'Not Configured'
                : autoPurgeEnabled
                ? `Auto (${autoPurgeIntervalHours}h / keep ${autoPurgeKeepLatest})`
                : 'Manual Only'}
            </StatusBadge>
          </button>

          {purgeOpen && (
            <div className="px-3 pb-3 pt-2 border-t border-ops-border space-y-3">
              {/* Bot Credentials */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
                <div className="space-y-1.5">
                  <div className="flex items-center justify-between gap-2">
                    <label htmlFor="discord-bot-token" className="text-[11px] text-ops-secondary">
                      Bot Token{' '}
                      {alertsStatus?.discord_bot_masked
                        ? `(${alertsStatus.discord_bot_masked})`
                        : ''}
                    </label>
                    {alertsStatus?.discord_bot_configured &&
                      (confirmClearBotToken ? (
                        <div className="inline-flex items-center gap-1">
                          <button
                            type="button"
                            onClick={() => {
                              setConfirmClearBotToken(false);
                              onSaveConfig({ clear_bot_token: true });
                            }}
                            className="ops-btn px-1.5 py-0.5 bg-ops-danger text-white text-[10px]"
                          >
                            Confirm
                          </button>
                          <button
                            type="button"
                            onClick={() => setConfirmClearBotToken(false)}
                            className="ops-btn px-1.5 py-0.5 bg-ops-elevated text-ops-secondary border border-ops-border text-[10px]"
                          >
                            Cancel
                          </button>
                        </div>
                      ) : (
                        <button
                          type="button"
                          onClick={() => setConfirmClearBotToken(true)}
                          className="text-[10px] font-mono text-ops-muted hover:text-ops-danger"
                        >
                          Clear Token
                        </button>
                      ))}
                  </div>
                  <div className="relative">
                    <input
                      id="discord-bot-token"
                      type={showBotTokenInput ? 'text' : 'password'}
                      value={botTokenInput}
                      onChange={(e) => {
                        setBotTokenInput(e.target.value);
                        setValidationError('');
                      }}
                      placeholder={
                        alertsStatus?.discord_bot_configured
                          ? 'Paste new Bot Token to replace...'
                          : 'Paste Discord Bot Token...'
                      }
                      autoComplete="off"
                      className="ops-input w-full h-9 pl-3 pr-9 text-xs font-mono"
                    />
                    <button
                      type="button"
                      onClick={() => setShowBotTokenInput((v) => !v)}
                      aria-label={showBotTokenInput ? 'Hide bot token' : 'Show bot token'}
                      className="absolute right-2 top-1/2 -translate-y-1/2 p-1 text-ops-muted hover:text-ops-text"
                    >
                      {showBotTokenInput ? (
                        <EyeOff className="w-3.5 h-3.5" />
                      ) : (
                        <Eye className="w-3.5 h-3.5" />
                      )}
                    </button>
                  </div>
                </div>

                <div className="space-y-1.5">
                  <label htmlFor="discord-channel-id" className="text-[11px] text-ops-secondary block">
                    Target Channel ID
                  </label>
                  <input
                    id="discord-channel-id"
                    type="text"
                    inputMode="numeric"
                    value={channelIdInput}
                    onChange={(e) => {
                      setDraft((prev) => ({ ...prev, channelId: e.target.value }));
                      setValidationError('');
                    }}
                    placeholder="e.g. 123456789012345678"
                    className="ops-input num w-full h-9 px-3 text-xs font-mono"
                  />
                </div>
              </div>

              {/* Auto-Purge Schedule */}
              <div className="p-2.5 rounded-md bg-ops-surface border border-ops-border space-y-2.5">
                <div className="flex items-center justify-between gap-2">
                  <span className="text-[10px] font-mono uppercase tracking-wider text-ops-muted">
                    Auto-Purge Schedule
                  </span>
                  {!botPurgeReady && (
                    <span className="text-[11px] text-ops-warn">
                      Configure Bot Token and Channel ID first, then save to enable scheduled auto-purge.
                    </span>
                  )}
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                  <div className="flex items-center justify-between gap-2 py-1.5 px-2.5 rounded bg-ops-inset border border-ops-border">
                    <div className="min-w-0">
                      <div className="text-xs font-medium text-ops-text">
                        Enable Periodic Auto-Purge
                      </div>
                      <div className="text-[10px] text-ops-muted">
                        Background retention cleanup
                      </div>
                    </div>
                    <OpsSwitch
                      ariaLabel="Enable Periodic Auto-Purge"
                      checked={autoPurgeEnabled}
                      disabled={!botPurgeReady}
                      onChange={(next) =>
                        setDraft((prev) => ({ ...prev, autoPurgeEnabled: next }))
                      }
                    />
                  </div>

                  <div className="flex items-center justify-between gap-2 py-1.5 px-2.5 rounded bg-ops-inset border border-ops-border">
                    <div className="min-w-0">
                      <div className="text-xs font-medium text-ops-text">
                        Purge on Core Startup
                      </div>
                      <div className="text-[10px] text-ops-muted">
                        Clean channel history at boot
                      </div>
                    </div>
                    <OpsSwitch
                      ariaLabel="Purge on Core Startup"
                      checked={autoPurgeOnStartup}
                      disabled={!botPurgeReady}
                      onChange={(next) =>
                        setDraft((prev) => ({ ...prev, autoPurgeOnStartup: next }))
                      }
                    />
                  </div>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
                  <div className="flex items-center justify-between gap-2 py-1.5 px-2.5 rounded bg-ops-inset border border-ops-border">
                    <label htmlFor="auto-purge-keep-input" className="text-xs text-ops-secondary shrink-0">
                      Keep Latest
                    </label>
                    <div className="flex items-center gap-1 flex-wrap justify-end">
                      {KEEP_LATEST_PRESETS.map((n) => (
                        <button
                          key={n}
                          type="button"
                          disabled={!botPurgeReady}
                          onClick={() =>
                            setDraft((prev) => ({ ...prev, autoPurgeKeepLatest: n }))
                          }
                          className={`num px-1.5 py-0.5 rounded text-[10px] font-mono border transition-colors disabled:opacity-45 ${
                            autoPurgeKeepLatest === n
                              ? 'bg-ops-elevated text-ops-text border-ops-borderStrong'
                              : 'bg-ops-surface text-ops-muted border-ops-border hover:text-ops-text'
                          }`}
                        >
                          {n}
                        </button>
                      ))}
                      <input
                        id="auto-purge-keep-input"
                        type="number"
                        min={0}
                        max={100}
                        disabled={!botPurgeReady}
                        value={autoPurgeKeepLatest}
                        onChange={(e) =>
                          setDraft((prev) => ({
                            ...prev,
                            autoPurgeKeepLatest: Number(e.target.value),
                          }))
                        }
                        className="ops-input num w-14 h-7 px-1.5 text-xs font-mono text-right disabled:opacity-45"
                      />
                    </div>
                  </div>

                  <div className="flex items-center justify-between gap-2 py-1.5 px-2.5 rounded bg-ops-inset border border-ops-border">
                    <label htmlFor="auto-purge-hours-input" className="text-xs text-ops-secondary shrink-0">
                      Interval (h)
                    </label>
                    <div className="flex items-center gap-1 flex-wrap justify-end">
                      {INTERVAL_HOUR_PRESETS.map((h) => (
                        <button
                          key={h}
                          type="button"
                          disabled={!botPurgeReady}
                          onClick={() =>
                            setDraft((prev) => ({ ...prev, autoPurgeIntervalHours: h }))
                          }
                          className={`num px-1.5 py-0.5 rounded text-[10px] font-mono border transition-colors disabled:opacity-45 ${
                            autoPurgeIntervalHours === h
                              ? 'bg-ops-elevated text-ops-text border-ops-borderStrong'
                              : 'bg-ops-surface text-ops-muted border-ops-border hover:text-ops-text'
                          }`}
                        >
                          {h}h
                        </button>
                      ))}
                      <input
                        id="auto-purge-hours-input"
                        type="number"
                        min={1}
                        max={168}
                        disabled={!botPurgeReady}
                        value={autoPurgeIntervalHours}
                        onChange={(e) =>
                          setDraft((prev) => ({
                            ...prev,
                            autoPurgeIntervalHours: Number(e.target.value),
                          }))
                        }
                        className="ops-input num w-14 h-7 px-1.5 text-xs font-mono text-right disabled:opacity-45"
                      />
                    </div>
                  </div>
                </div>
              </div>

              {/* Manual Purge Now Bar */}
              <div className="p-2.5 rounded-md bg-ops-surface border border-ops-border flex flex-col sm:flex-row sm:items-center justify-between gap-2.5">
                <div className="flex flex-wrap items-center gap-3">
                  <div className="flex items-center gap-1.5">
                    <label htmlFor="purge-limit-select" className="text-[11px] text-ops-secondary">
                      Scan Limit
                    </label>
                    <select
                      id="purge-limit-select"
                      value={purgeLimit}
                      onChange={(e) => setPurgeLimit(Number(e.target.value))}
                      className="ops-input num h-7 px-2 text-xs font-mono"
                    >
                      {PURGE_LIMITS.map((n) => (
                        <option key={n} value={n}>
                          {n}
                        </option>
                      ))}
                    </select>
                  </div>

                  <label className="inline-flex items-center gap-1.5 text-[11px] text-ops-secondary cursor-pointer select-none">
                    <input
                      type="checkbox"
                      checked={purgeBotOnly}
                      onChange={(e) => setPurgeBotOnly(e.target.checked)}
                      className="rounded border-ops-border bg-ops-inset accent-ops-accent"
                    />
                    <span>Bot & webhook messages only</span>
                  </label>
                </div>

                {confirmPurge ? (
                  <div className="inline-flex items-center gap-1.5 shrink-0">
                    <button
                      type="button"
                      disabled={isPurging}
                      onClick={() => {
                        setConfirmPurge(false);
                        onPurgeMessages(purgeLimit, purgeBotOnly);
                      }}
                      className="ops-btn h-8 px-3 bg-ops-danger hover:bg-red-500 text-white text-xs font-semibold"
                    >
                      <ShieldAlert className="w-3.5 h-3.5" />
                      <span>Confirm Purge ({purgeLimit})</span>
                    </button>
                    <button
                      type="button"
                      onClick={() => setConfirmPurge(false)}
                      className="ops-btn h-8 px-2.5 bg-ops-elevated text-ops-secondary border border-ops-border text-xs"
                    >
                      Cancel
                    </button>
                  </div>
                ) : (
                  <button
                    type="button"
                    disabled={!botPurgeReady || isPurging}
                    onClick={() => setConfirmPurge(true)}
                    className="ops-btn h-8 px-3 bg-ops-danger/10 hover:bg-ops-danger/20 text-ops-danger border border-ops-danger/30 text-xs shrink-0"
                  >
                    {isPurging ? (
                      <>
                        <Loader2 className="w-3.5 h-3.5 animate-spin" />
                        <span>Purging...</span>
                      </>
                    ) : (
                      <>
                        <Trash2 className="w-3.5 h-3.5" />
                        <span>Purge Now</span>
                      </>
                    )}
                  </button>
                )}
              </div>

              {lastPurgeResult && (
                <div
                  className={`num text-[11px] font-mono px-2.5 py-1.5 rounded border ${
                    lastPurgeResult.ok
                      ? 'bg-ops-ok/10 text-ops-ok border-ops-ok/30'
                      : 'bg-ops-danger/10 text-ops-danger border-ops-danger/30'
                  }`}
                >
                  {lastPurgeResult.ok
                    ? `Deleted ${lastPurgeResult.deleted_count} message(s) (scanned ${
                        lastPurgeResult.scanned ?? 0
                      }${
                        typeof lastPurgeResult.bulk_deleted === 'number' ||
                        typeof lastPurgeResult.single_deleted === 'number'
                          ? `, bulk ${lastPurgeResult.bulk_deleted ?? 0} / single ${
                              lastPurgeResult.single_deleted ?? 0
                            }`
                          : ''
                      }${
                        typeof lastPurgeResult.errors === 'number' && lastPurgeResult.errors > 0
                          ? `, errors ${lastPurgeResult.errors}`
                          : ''
                      })`
                    : lastPurgeResult.error || 'Purge failed'}
                </div>
              )}
            </div>
          )}
        </div>

        {validationError && (
          <div className="px-3 py-2 rounded-md bg-ops-danger/10 border border-ops-danger/30 text-xs text-ops-danger">
            {validationError}
          </div>
        )}
      </div>

      {/* Footer Actions */}
      <div className="pt-3 border-t border-ops-border flex flex-wrap items-center justify-between gap-2.5">
        <div className="flex items-center gap-2">
          <button
            type="button"
            disabled={!alertsStatus?.discord_webhook_configured || isTesting}
            onClick={onSendTest}
            className="ops-btn h-9 px-3 bg-ops-elevated hover:bg-ops-border border border-ops-borderStrong text-xs text-ops-text"
          >
            {isTesting ? (
              <>
                <Loader2 className="w-3.5 h-3.5 animate-spin" />
                <span>Sending...</span>
              </>
            ) : (
              <>
                <Send className="w-3.5 h-3.5 text-ops-accent" />
                <span>Send Test Alert</span>
              </>
            )}
          </button>

          {lastTestResult && (
            <span
              className={`num text-[11px] font-mono ${
                lastTestResult.ok ? 'text-ops-ok' : 'text-ops-danger'
              }`}
            >
              {lastTestResult.ok
                ? `Delivered (HTTP ${lastTestResult.http_status ?? 204})`
                : lastTestResult.error || 'Failed'}
            </span>
          )}
        </div>

        <div className="flex items-center gap-2 ml-auto">
          {isDirty && (
            <button
              type="button"
              onClick={resetForm}
              className="ops-btn h-9 px-3 bg-ops-inset hover:bg-ops-elevated border border-ops-border text-xs text-ops-secondary"
            >
              <RotateCcw className="w-3.5 h-3.5" />
              <span>Reset</span>
            </button>
          )}
          <button
            type="submit"
            disabled={isSaving}
            className="ops-btn h-9 px-4 bg-ops-accent hover:bg-blue-500 text-white text-xs font-semibold"
          >
            {isSaving ? (
              <>
                <Loader2 className="w-3.5 h-3.5 animate-spin" />
                <span>Saving...</span>
              </>
            ) : (
              <>
                <Save className="w-3.5 h-3.5" />
                <span>Save Configuration</span>
              </>
            )}
          </button>
        </div>
      </div>
    </form>
  );
};
