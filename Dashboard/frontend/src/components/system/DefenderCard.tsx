import React from 'react';
import { RefreshCw, Search, Shield } from 'lucide-react';
import { useDashboardStore } from '../../store/useDashboard';
import { CardHeader, EmptyState, MetricCell, OpsCard, StatusBadge } from '../ui';

interface DefenderCardProps {
  onRefresh: () => void;
  onQuickScan: () => void;
}

export const DefenderCard: React.FC<DefenderCardProps> = ({ onRefresh, onQuickScan }) => {
  const defender = useDashboardStore((s) => s.defender);
  const maintenance = useDashboardStore((s) => s.config?.maintenance);
  const pendingOps = useDashboardStore((s) => s.pendingOps);

  const refreshing = Boolean(pendingOps['defender:refresh']);
  const scanning = Boolean(pendingOps['defender:scan']);

  const info = defender?.available ? defender : null;
  const sigTone = !info
    ? 'muted'
    : info.signature_stale || info.signature_age_days > 3
    ? 'warn'
    : 'ok';
  const scanTone = !info
    ? 'muted'
    : info.quick_scan_age_days > 7
    ? 'warn'
    : 'muted';
  const rtTone = !info ? 'muted' : info.realtime_enabled ? 'ok' : 'danger';

  const sweepMinutes = maintenance?.downloads_sweep_minutes;
  const sweepText = typeof sweepMinutes === 'number' ? `Auto (${sweepMinutes}m)` : '—';

  return (
    <OpsCard className="flex flex-col gap-3">
      <div className="space-y-3">
        <CardHeader
          icon={<Shield className="w-4 h-4 text-ops-ok" />}
          title="Windows Defender Sentinel"
          subtitle="Antivirus signatures, scan recency, real-time engine, and Downloads sweep cadence."
          badge={
            info ? (
              <StatusBadge tone={info.realtime_enabled && !info.signature_stale ? 'ok' : 'warn'} dot>
                {info.realtime_enabled ? 'Protected' : 'Realtime Off'}
              </StatusBadge>
            ) : defender && !defender.available ? (
              <StatusBadge tone="muted">Unavailable</StatusBadge>
            ) : (
              <StatusBadge tone="muted">Pending</StatusBadge>
            )
          }
          actions={
            <div className="flex items-center gap-1.5">
              <button
                type="button"
                disabled={refreshing}
                onClick={onRefresh}
                className="ops-btn h-8 px-2.5 bg-ops-elevated hover:bg-ops-border border border-ops-border text-xs text-ops-text"
                title="Refresh Defender status"
              >
                <RefreshCw className={`w-3.5 h-3.5 ${refreshing ? 'animate-spin' : ''}`} />
                <span>Refresh</span>
              </button>
              <button
                type="button"
                disabled={scanning || (defender !== null && !defender.available)}
                onClick={onQuickScan}
                className="ops-btn h-8 px-2.5 bg-ops-elevated hover:bg-ops-border border border-ops-borderStrong text-xs text-ops-text"
              >
                <Search className={`w-3.5 h-3.5 ${scanning ? 'animate-spin text-ops-ok' : ''}`} />
                <span>{scanning ? 'Starting...' : 'Quick Scan'}</span>
              </button>
            </div>
          }
        />

        {!defender ? (
          <EmptyState
            title="Waiting for Windows Defender status..."
            description="Host maintenance telemetry has not populated Defender state yet."
            icon={<Shield className="w-5 h-5" />}
          />
        ) : !info ? (
          <EmptyState
            title="Windows Defender telemetry unavailable"
            description="Get-MpComputerStatus returned no data or Defender service is disabled."
            icon={<Shield className="w-5 h-5" />}
          />
        ) : (
          <div className="grid grid-cols-2 gap-2.5">
            <MetricCell
              label="Signatures"
              tone={sigTone}
              value={
                info.signature_display ||
                (info.signature_age_days >= 0 ? `${info.signature_age_days}d ago` : '—')
              }
              subValue={
                info.signature_age_days >= 0
                  ? `${info.signature_age_days}d age`
                  : undefined
              }
            />
            <MetricCell
              label="Last Quick Scan"
              tone={scanTone}
              value={
                info.quick_scan_display ||
                (info.quick_scan_age_days >= 0 ? `${info.quick_scan_age_days}d ago` : '—')
              }
              subValue={info.quick_scan_duration || undefined}
            />
            <MetricCell
              label="Real-Time"
              tone={rtTone}
              value={info.realtime_enabled ? 'ON' : 'OFF'}
              subValue={`AV Engine: ${info.antivirus_enabled ? 'Active' : 'Off'}`}
            />
            <MetricCell
              label="Downloads Sweep"
              tone={typeof sweepMinutes === 'number' ? 'info' : 'muted'}
              value={sweepText}
              subValue={
                maintenance ? `Full scan @ ${maintenance.defender_scan_hour}:00` : undefined
              }
            />
          </div>
        )}
      </div>

      <div className="pt-2 border-t border-ops-border flex items-center justify-between text-[11px] font-mono text-ops-muted">
        <span>Defender Poll</span>
        <span className="num text-ops-secondary">Last check: {defender?.last_check || '—'}</span>
      </div>
    </OpsCard>
  );
};
