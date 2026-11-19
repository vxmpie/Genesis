import React from 'react';
import {
  Activity,
  ArrowDownLeft,
  ArrowUpRight,
  Globe,
  RefreshCw,
  ShieldAlert,
  Wifi,
} from 'lucide-react';
import { useDashboardStore } from '../../store/useDashboard';
import { formatMb, formatMs } from '../../lib/format';
import { CardHeader, OpsCard, StatusBadge, type SemanticTone } from '../ui';

interface NetworkObservatoryCardProps {
  onRefreshObservatory: () => void;
  onFlushDns: () => void;
}

function getLatencyTone(quality: string | undefined): SemanticTone {
  switch (quality) {
    case 'excellent':
      return 'ok';
    case 'fair':
      return 'warn';
    case 'poor':
      return 'danger';
    default:
      return 'muted';
  }
}

function getWatchdogTone(state: string | undefined, installed: boolean | undefined): SemanticTone {
  if (!installed) return 'muted';
  switch (state) {
    case 'active':
      return 'ok';
    case 'grace':
    case 'recovering':
      return 'warn';
    case 'stale':
    case 'offline':
      return 'danger';
    default:
      return 'muted';
  }
}

export const NetworkObservatoryCard: React.FC<NetworkObservatoryCardProps> = ({
  onRefreshObservatory,
  onFlushDns,
}) => {
  const observatory = useDashboardStore((s) => s.observatory);
  const net = useDashboardStore((s) => s.metrics?.network);
  const pendingOps = useDashboardStore((s) => s.pendingOps);

  const refreshing = Boolean(pendingOps['observatory:refresh']);
  const flushing = Boolean(pendingOps['dns']);

  const lat = observatory?.latency;
  const wifi = observatory?.wifi;
  const wd = observatory?.watchdog;

  const upSpeedText =
    net && typeof net.sent_speed_mbs === 'number'
      ? `${net.sent_speed_mbs.toFixed(2)} MB/s`
      : '—';
  const downSpeedText =
    net && typeof net.recv_speed_mbs === 'number'
      ? `${net.recv_speed_mbs.toFixed(2)} MB/s`
      : '—';

  return (
    <OpsCard className="flex flex-col gap-3">
      <div className="space-y-3">
        <CardHeader
          icon={<Globe className="w-4 h-4 text-ops-telemetry" />}
          title="Network Observatory"
          subtitle="Live ICMP latency, Wi-Fi RF link telemetry, net watchdog state, and host throughput."
          actions={
            <div className="flex items-center gap-1.5">
              <button
                type="button"
                disabled={refreshing}
                onClick={onRefreshObservatory}
                className="ops-btn h-8 px-2.5 bg-ops-elevated hover:bg-ops-border border border-ops-border text-xs text-ops-text"
              >
                <RefreshCw className={`w-3.5 h-3.5 ${refreshing ? 'animate-spin' : ''}`} />
                <span>Refresh</span>
              </button>
              <button
                type="button"
                disabled={flushing}
                onClick={onFlushDns}
                className="ops-btn h-8 px-2.5 bg-ops-elevated hover:bg-ops-border border border-ops-borderStrong text-xs text-ops-text"
              >
                <span>{flushing ? 'Flushing...' : 'Flush DNS'}</span>
              </button>
            </div>
          }
        />

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
          {/* 1. Latency & Packet Loss */}
          <div className="p-3 rounded-md bg-ops-inset border border-ops-border flex flex-col justify-between gap-2">
            <div className="flex items-center justify-between gap-2">
              <span className="text-[10px] font-mono uppercase tracking-wider text-ops-muted">
                Latency {lat?.target ? `(${lat.target})` : ''}
              </span>
              <StatusBadge tone={getLatencyTone(lat?.quality)}>
                {lat?.quality ? lat.quality.toUpperCase() : '—'}
              </StatusBadge>
            </div>

            <div className="num font-mono text-xl font-semibold text-ops-text">
              {lat ? formatMs(lat.current_ms, 1) : '—'}
            </div>

            <div className="num flex items-center justify-between text-[11px] font-mono text-ops-secondary">
              <span>Avg: {lat ? formatMs(lat.avg_ms, 1) : '—'}</span>
              <span>Jitter: {lat ? `${lat.jitter_ms.toFixed(1)} ms` : '—'}</span>
              <span>Loss: {lat ? `${lat.loss_percent.toFixed(1)}%` : '—'}</span>
            </div>
          </div>

          {/* 2. Wi-Fi RF Link */}
          <div className="p-3 rounded-md bg-ops-inset border border-ops-border flex flex-col justify-between gap-2">
            <div className="flex items-center justify-between gap-2">
              <span className="text-[10px] font-mono uppercase tracking-wider text-ops-muted flex items-center gap-1">
                <Wifi className="w-3 h-3 text-ops-telemetry" />
                <span>Wi-Fi Link</span>
              </span>
              <StatusBadge tone={wifi?.connected ? 'info' : 'muted'}>
                {!wifi ? '—' : wifi.connected ? wifi.quality_label || 'Connected' : 'Offline'}
              </StatusBadge>
            </div>

            <div
              className="font-mono text-sm font-semibold text-ops-text truncate"
              title={wifi?.ssid || undefined}
            >
              {!wifi ? '—' : wifi.connected ? wifi.ssid || 'Connected' : 'Not connected'}
            </div>

            <div className="num flex items-center justify-between text-[11px] font-mono text-ops-secondary">
              {!wifi ? (
                <span>Awaiting adapter telemetry...</span>
              ) : !wifi.connected ? (
                <span>Wired or offline</span>
              ) : (
                <>
                  <span>Sig: {wifi.signal_percent}%</span>
                  <span>
                    {wifi.rx_rate_mbps}/{wifi.tx_rate_mbps} Mbps
                  </span>
                  <span>{wifi.band || '—'}</span>
                </>
              )}
            </div>
          </div>

          {/* 3. Net Watchdog */}
          <div className="p-3 rounded-md bg-ops-inset border border-ops-border flex flex-col justify-between gap-2">
            <div className="flex items-center justify-between gap-2">
              <span className="text-[10px] font-mono uppercase tracking-wider text-ops-muted flex items-center gap-1">
                <ShieldAlert className="w-3 h-3 text-ops-ok" />
                <span>Net Watchdog</span>
              </span>
              <StatusBadge tone={getWatchdogTone(wd?.state, wd?.installed)} dot>
                {!wd ? '—' : !wd.installed ? 'Not Installed' : wd.state.toUpperCase()}
              </StatusBadge>
            </div>

            <div className="num font-mono text-sm font-semibold text-ops-text">
              {wd && wd.installed ? `${wd.recoveries_today} recoveries today` : !wd ? '—' : 'Inactive'}
            </div>

            <div className="num flex items-center justify-between text-[11px] font-mono text-ops-secondary">
              <span>
                {wd && wd.installed ? `L1:${wd.level1_today} / L2:${wd.level2_today}` : '—'}
              </span>
              <span>
                HB:{' '}
                {wd && wd.installed && wd.heartbeat_seconds >= 0
                  ? `${wd.heartbeat_seconds}s ago`
                  : '—'}
              </span>
            </div>
          </div>

          {/* 4. Host Throughput & Roblox Edge Ping */}
          <div className="p-3 rounded-md bg-ops-inset border border-ops-border flex flex-col justify-between gap-2">
            <div className="flex items-center justify-between gap-2">
              <span className="text-[10px] font-mono uppercase tracking-wider text-ops-muted flex items-center gap-1">
                <Activity className="w-3 h-3 text-ops-accent" />
                <span>Throughput & Edge</span>
              </span>
              <span className="num font-mono text-[11px] text-ops-secondary">
                Roblox: {formatMs(net?.roblox_ping_ms, 1)}
              </span>
            </div>

            <div className="space-y-1 text-xs font-mono">
              <div className="flex items-center justify-between">
                <span className="inline-flex items-center gap-1 text-ops-accent font-semibold">
                  <ArrowUpRight className="w-3.5 h-3.5" />
                  <span className="num">{upSpeedText}</span>
                </span>
                <span className="num text-[11px] text-ops-muted">
                  {net ? `Tot ${formatMb(net.total_sent_mb, 0)}` : '—'}
                </span>
              </div>
              <div className="flex items-center justify-between">
                <span className="inline-flex items-center gap-1 text-ops-telemetry font-semibold">
                  <ArrowDownLeft className="w-3.5 h-3.5" />
                  <span className="num">{downSpeedText}</span>
                </span>
                <span className="num text-[11px] text-ops-muted">
                  {net ? `Tot ${formatMb(net.total_recv_mb, 0)}` : '—'}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="pt-2 border-t border-ops-border flex items-center justify-between text-[11px] font-mono text-ops-muted">
        <span>Latest Watchdog Note</span>
        <span className="text-ops-secondary truncate max-w-[260px]" title={wd?.latest_recovered_line || undefined}>
          {wd?.latest_recovered_line || '—'}
        </span>
      </div>
    </OpsCard>
  );
};
