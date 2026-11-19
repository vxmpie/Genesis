import React, { useMemo } from 'react';
import { FolderTree, HardDrive, RefreshCw } from 'lucide-react';
import { useDashboardStore } from '../../store/useDashboard';
import { formatGb } from '../../lib/format';
import { CardHeader, EmptyState, OpsCard, StatusBadge } from '../ui';

interface DiskGrowthCardProps {
  onRefreshGrowth: () => void;
}

function buildSparklinePoints(values: number[], width: number, height: number): string {
  if (values.length === 0) return '';
  if (values.length === 1) {
    const y = height - (Math.min(100, Math.max(0, values[0])) / 100) * (height - 4) - 2;
    return `0,${y.toFixed(1)} ${width},${y.toFixed(1)}`;
  }
  const minVal = Math.min(...values);
  const maxVal = Math.max(...values);
  const span = Math.max(1, maxVal - minVal);
  return values
    .map((val, idx) => {
      const x = (idx / (values.length - 1)) * width;
      const normalized = (val - minVal) / span;
      const y = height - normalized * (height - 6) - 3;
      return `${x.toFixed(1)},${y.toFixed(1)}`;
    })
    .join(' ');
}

function formatDeltaGb(delta: number): string {
  const prefix = delta > 0 ? '+' : '';
  return `${prefix}${delta.toFixed(2)} GB`;
}

export const DiskGrowthCard: React.FC<DiskGrowthCardProps> = ({ onRefreshGrowth }) => {
  const growthData = useDashboardStore((s) => s.growthData);
  const snapshotHours = useDashboardStore(
    (s) => s.config?.maintenance.growth_snapshot_hours
  );
  const refreshing = useDashboardStore((s) => Boolean(s.pendingOps['growth:refresh']));

  const analysis = useMemo(() => {
    if (growthData.length === 0) {
      return null;
    }
    const first = growthData[0];
    const latest = growthData[growthData.length - 1];

    const drives = Object.entries(latest.disks || {}).map(([mount, info]) => {
      const firstDisk = first.disks?.[mount];
      const deltaGb = firstDisk ? info.used_gb - firstDisk.used_gb : 0;
      const series = growthData
        .map((snap) => snap.disks?.[mount]?.percent)
        .filter((v): v is number => typeof v === 'number' && Number.isFinite(v));
      return {
        mount,
        latest: info,
        deltaGb,
        series,
      };
    });

    const folders = Object.entries(latest.folders || {})
      .map(([name, sizeGb]) => {
        const firstSize = first.folders?.[name];
        const deltaGb = typeof firstSize === 'number' ? sizeGb - firstSize : 0;
        return { name, sizeGb, deltaGb };
      })
      .sort((a, b) => b.deltaGb - a.deltaGb || b.sizeGb - a.sizeGb)
      .slice(0, 5);

    return {
      drives,
      folders,
      firstTs: first.timestamp,
      latestTs: latest.timestamp,
      count: growthData.length,
    };
  }, [growthData]);

  const intervalLabel = typeof snapshotHours === 'number' ? `${snapshotHours}h` : '—';

  return (
    <OpsCard className="flex flex-col gap-3">
      <div className="space-y-3">
        <CardHeader
          icon={<FolderTree className="w-4 h-4 text-ops-warn" />}
          title="Disk & VM Folder Growth"
          subtitle={`Tracks host volume utilization and MuMu VM directory deltas (interval: ${intervalLabel}).`}
          badge={
            analysis ? (
              <StatusBadge tone="muted">{analysis.count} snapshots</StatusBadge>
            ) : undefined
          }
          actions={
            <button
              type="button"
              disabled={refreshing}
              onClick={onRefreshGrowth}
              className="ops-btn h-8 px-2.5 bg-ops-elevated hover:bg-ops-border border border-ops-border text-xs text-ops-text"
            >
              <RefreshCw className={`w-3.5 h-3.5 ${refreshing ? 'animate-spin' : ''}`} />
              <span>Refresh</span>
            </button>
          }
        />

        {!analysis ? (
          <EmptyState
            title={`No snapshot recorded yet (interval: ${intervalLabel})`}
            description="Disk growth trends and top VM folder deltas appear once the maintenance loop saves snapshots."
            icon={<HardDrive className="w-5 h-5" />}
          />
        ) : (
          <div className="space-y-3">
            {/* Drive Utilization Sparklines */}
            {analysis.drives.length > 0 && (
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
                {analysis.drives.map((drive) => {
                  const pts = buildSparklinePoints(drive.series, 120, 28);
                  const deltaTone =
                    drive.deltaGb > 1 ? 'warn' : drive.deltaGb < 0 ? 'ok' : 'muted';
                  return (
                    <div
                      key={drive.mount}
                      className="p-3 rounded-md bg-ops-inset border border-ops-border space-y-2"
                    >
                      <div className="flex items-center justify-between gap-2">
                        <span className="font-mono text-xs font-semibold text-ops-text">
                          Drive {drive.mount}
                        </span>
                        <StatusBadge tone={deltaTone}>
                          {formatDeltaGb(drive.deltaGb)}
                        </StatusBadge>
                      </div>

                      <div className="flex items-end justify-between gap-2">
                        <div className="text-[11px] font-mono text-ops-secondary">
                          <div className="num text-ops-text font-semibold">
                            {drive.latest.percent.toFixed(1)}% used
                          </div>
                          <div className="num text-ops-muted">
                            {formatGb(drive.latest.used_gb)} / {formatGb(drive.latest.total_gb)}
                          </div>
                        </div>

                        {pts && (
                          <svg
                            width={120}
                            height={28}
                            viewBox="0 0 120 28"
                            aria-label={`Usage trend for ${drive.mount}`}
                            className="shrink-0 overflow-visible"
                          >
                            <polyline
                              fill="none"
                              stroke="#06B6D4"
                              strokeWidth="1.75"
                              strokeLinejoin="round"
                              strokeLinecap="round"
                              points={pts}
                            />
                          </svg>
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            )}

            {/* Top Growing VM Folders */}
            <div className="rounded-md bg-ops-inset border border-ops-border overflow-hidden">
              <div className="px-3 py-2 bg-ops-chrome border-b border-ops-border flex items-center justify-between text-[10px] font-mono uppercase text-ops-muted">
                <span>Top VM Directories</span>
                <span>Size / Window Delta</span>
              </div>
              {analysis.folders.length === 0 ? (
                <div className="py-4 text-center text-xs font-mono text-ops-muted">
                  No MuMu VM folders found in snapshot.
                </div>
              ) : (
                <div className="divide-y divide-ops-border text-xs font-mono">
                  {analysis.folders.map((folder) => (
                    <div
                      key={folder.name}
                      className="px-3 py-2 flex items-center justify-between gap-2"
                    >
                      <span className="text-ops-text truncate" title={folder.name}>
                        {folder.name}
                      </span>
                      <div className="num flex items-center gap-2 shrink-0">
                        <span className="text-ops-secondary">{folder.sizeGb.toFixed(2)} GB</span>
                        <StatusBadge
                          tone={folder.deltaGb > 0.25 ? 'warn' : folder.deltaGb < 0 ? 'ok' : 'muted'}
                        >
                          {formatDeltaGb(folder.deltaGb)}
                        </StatusBadge>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        )}
      </div>

      <div className="pt-2 border-t border-ops-border flex items-center justify-between text-[11px] font-mono text-ops-muted">
        <span>Snapshot Window</span>
        <span className="num text-ops-secondary truncate">
          {analysis ? `${analysis.count} points recorded` : 'No history'}
        </span>
      </div>
    </OpsCard>
  );
};
