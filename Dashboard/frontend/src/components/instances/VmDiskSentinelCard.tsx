import React from 'react';
import { HardDrive, Loader2, RefreshCw, Scissors } from 'lucide-react';
import { useDashboardStore } from '../../store/useDashboard';
import { CardHeader, EmptyState, OpsCard, StatusBadge, type SemanticTone } from '../ui';

interface VmDiskSentinelCardProps {
  onRefreshVmDisk: () => void;
  onTrimVmCache: (port: number) => void;
}

function getStatusTone(status: 'ok' | 'warning' | 'critical'): SemanticTone {
  switch (status) {
    case 'critical':
      return 'danger';
    case 'warning':
      return 'warn';
    default:
      return 'ok';
  }
}

function getBarColor(status: 'ok' | 'warning' | 'critical'): string {
  switch (status) {
    case 'critical':
      return 'bg-ops-danger';
    case 'warning':
      return 'bg-ops-warn';
    default:
      return 'bg-ops-ok';
  }
}

export const VmDiskSentinelCard: React.FC<VmDiskSentinelCardProps> = ({
  onRefreshVmDisk,
  onTrimVmCache,
}) => {
  const vmDisk = useDashboardStore((s) => s.vmDisk);
  const lastCheck = useDashboardStore((s) => s.mumu?.vm_disk_last_check);
  const maintenance = useDashboardStore((s) => s.config?.maintenance);
  const pendingOps = useDashboardStore((s) => s.pendingOps);

  const refreshing = Boolean(pendingOps['vmdisk:refresh']);

  const thresholdText = maintenance
    ? `Thresholds: warn ${maintenance.vm_disk_warn_pct}% / critical ${maintenance.vm_disk_critical_pct}% | Auto-trim ${
        maintenance.vm_auto_trim ? 'on' : 'off'
      }`
    : 'Awaiting maintenance configuration...';

  return (
    <OpsCard className="space-y-3">
      <CardHeader
        icon={<HardDrive className="w-4 h-4 text-ops-warn" />}
        title="In-VM Disk Sentinel (/data)"
        subtitle={thresholdText}
        badge={
          lastCheck ? (
            <StatusBadge tone="muted">Checked {lastCheck}</StatusBadge>
          ) : undefined
        }
        actions={
          <button
            type="button"
            disabled={refreshing}
            onClick={onRefreshVmDisk}
            className="ops-btn h-8 px-2.5 bg-ops-elevated hover:bg-ops-border border border-ops-border text-xs text-ops-text"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${refreshing ? 'animate-spin' : ''}`} />
            <span>{refreshing ? 'Scanning...' : 'Refresh'}</span>
          </button>
        }
      />

      {vmDisk.length === 0 ? (
        <EmptyState
          title="No Android /data partitions detected"
          description="Ensure MuMu instances are running with ADB reachable, then click Refresh to inspect /data disk usage."
          icon={<HardDrive className="w-5 h-5" />}
        />
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
          {vmDisk.map((item) => {
            const trimPending = Boolean(pendingOps[`vmTrim:${item.port}`]);
            const pct = Math.min(100, Math.max(0, item.used_pct));

            return (
              <div
                key={item.port}
                className="p-3 rounded-md bg-ops-inset border border-ops-border space-y-2.5"
              >
                <div className="flex items-center justify-between gap-2">
                  <div className="min-w-0">
                    <div className="flex items-center gap-2">
                      <span className="num font-mono text-xs font-semibold text-ops-text">
                        Instance #{item.instance}
                      </span>
                      <StatusBadge tone={getStatusTone(item.status)} dot>
                        {item.status.toUpperCase()}
                      </StatusBadge>
                    </div>
                    <div className="num font-mono text-[11px] text-ops-muted mt-0.5">
                      ADB 127.0.0.1:{item.port}
                    </div>
                  </div>

                  <button
                    type="button"
                    disabled={trimPending}
                    onClick={() => onTrimVmCache(item.port)}
                    title="Run fstrim -v /data and clear /data/local/tmp"
                    className="ops-btn h-8 px-2.5 bg-ops-elevated hover:bg-ops-border border border-ops-border text-xs text-ops-text shrink-0"
                  >
                    {trimPending ? (
                      <>
                        <Loader2 className="w-3.5 h-3.5 animate-spin" />
                        <span>Trimming...</span>
                      </>
                    ) : (
                      <>
                        <Scissors className="w-3.5 h-3.5 text-ops-telemetry" />
                        <span>Trim VM Cache</span>
                      </>
                    )}
                  </button>
                </div>

                <div>
                  <div className="flex items-center justify-between text-[11px] font-mono mb-1">
                    <span className="num text-ops-secondary">
                      {item.used_gb.toFixed(2)} / {item.total_gb.toFixed(2)} GB used
                    </span>
                    <span className="num text-ops-text font-semibold">{item.used_pct}%</span>
                  </div>
                  <div className="w-full h-1.5 rounded-full bg-ops-surface border border-ops-border overflow-hidden">
                    <div
                      className={`h-full transition-[width] duration-300 ${getBarColor(item.status)}`}
                      style={{ width: `${pct}%` }}
                    />
                  </div>
                  <div className="num font-mono text-[10px] text-ops-muted mt-1 text-right">
                    {item.avail_gb.toFixed(2)} GB available
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </OpsCard>
  );
};
