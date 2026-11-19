import React from 'react';
import { Cpu } from 'lucide-react';
import { useDashboardStore } from '../../store/useDashboard';
import { CardHeader, EmptyState, OpsCard, StatusBadge } from '../ui';

function getBarColorClass(load: number): string {
  if (load >= 90) return 'bg-ops-danger';
  if (load >= 70) return 'bg-ops-warn';
  return 'bg-ops-telemetry';
}

function getTextColorClass(load: number): string {
  if (load >= 90) return 'text-ops-danger';
  if (load >= 70) return 'text-ops-warn';
  return 'text-ops-secondary';
}

function computeAvg(values: number[]): number | null {
  if (values.length === 0) return null;
  const total = values.reduce((acc, v) => acc + v, 0);
  return Math.round(total / values.length);
}

export const CpuCoresCard: React.FC = () => {
  const cpu = useDashboardStore((s) => s.metrics?.cpu);

  const perCore = cpu?.per_core ?? [];
  const pCores = cpu?.p_cores && cpu.p_cores.length > 0 ? cpu.p_cores : perCore;
  const eCores = cpu?.e_cores ?? [];
  const threadCount = cpu?.core_count || cpu?.count || perCore.length || 0;
  const cpuModel = cpu?.model || '—';
  const freqGhz = cpu?.frequency_ghz;

  const hasSplit = eCores.length > 0;
  const primaryAvg = computeAvg(pCores);
  const secondaryAvg = computeAvg(eCores);

  const renderBarGroup = (values: number[], offsetIndex: number) => (
    <div
      className="grid gap-1.5 items-end h-28 pt-2"
      style={{
        gridTemplateColumns: `repeat(${Math.max(1, values.length)}, minmax(22px, 1fr))`,
      }}
    >
      {values.map((rawVal, idx) => {
        const threadIdx = offsetIndex + idx;
        const load = Math.min(100, Math.max(0, Math.round(rawVal)));
        const heightPct = Math.max(4, load);

        return (
          <div
            key={threadIdx}
            className="flex flex-col items-center justify-end h-full gap-1 min-w-0"
            title={`Thread #${threadIdx}: ${load}%`}
          >
            <span className={`num font-mono text-[10px] font-medium ${getTextColorClass(load)}`}>
              {load}%
            </span>
            <div className="w-full h-16 bg-ops-surface rounded-sm border border-ops-border overflow-hidden flex items-end">
              <div
                className={`w-full transition-[height] duration-300 ${getBarColorClass(load)}`}
                style={{ height: `${heightPct}%` }}
              />
            </div>
            <span className="num font-mono text-[9px] text-ops-muted">#{threadIdx}</span>
          </div>
        );
      })}
    </div>
  );

  return (
    <OpsCard className="space-y-3">
      <CardHeader
        icon={<Cpu className="w-4 h-4 text-ops-telemetry" />}
        title="CPU Logical Thread Matrix"
        subtitle={
          hasSplit
            ? `${cpuModel} — Logical group split by host thread count`
            : cpuModel
        }
        badge={
          <StatusBadge tone="muted">
            {threadCount > 0 ? `${threadCount} Threads` : '—'}
            {typeof freqGhz === 'number' && freqGhz > 0 ? ` @ ${freqGhz.toFixed(2)} GHz` : ''}
          </StatusBadge>
        }
        actions={
          pCores.length > 0 ? (
            <div className="flex items-center gap-2 text-xs font-mono">
              {hasSplit ? (
                <>
                  <StatusBadge tone="accent" dot>
                    Primary Avg {primaryAvg !== null ? `${primaryAvg}%` : '—'}
                  </StatusBadge>
                  <StatusBadge tone="info" dot>
                    Secondary Avg {secondaryAvg !== null ? `${secondaryAvg}%` : '—'}
                  </StatusBadge>
                </>
              ) : (
                <StatusBadge tone="info" dot>
                  Avg {primaryAvg !== null ? `${primaryAvg}%` : '—'}
                </StatusBadge>
              )}
            </div>
          ) : undefined
        }
      />

      {pCores.length === 0 ? (
        <EmptyState
          title="Waiting for per-core CPU telemetry..."
          description="Thread utilization bars populate once host CPU sampler reports per-thread percentages."
          icon={<Cpu className="w-5 h-5" />}
        />
      ) : hasSplit ? (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-3">
          <div className="p-3 rounded-md bg-ops-inset border border-ops-border space-y-2 overflow-x-auto">
            <div className="flex items-center justify-between gap-2 text-xs">
              <span className="num font-medium text-ops-text">
                Primary Threads (0–{pCores.length - 1})
              </span>
              <span className="num font-mono text-[11px] text-ops-muted">
                {pCores.length} threads
              </span>
            </div>
            {renderBarGroup(pCores, 0)}
          </div>

          <div className="p-3 rounded-md bg-ops-inset border border-ops-border space-y-2 overflow-x-auto">
            <div className="flex items-center justify-between gap-2 text-xs">
              <span className="num font-medium text-ops-text">
                Secondary Threads ({pCores.length}–{pCores.length + eCores.length - 1})
              </span>
              <span className="num font-mono text-[11px] text-ops-muted">
                {eCores.length} threads
              </span>
            </div>
            {renderBarGroup(eCores, pCores.length)}
          </div>
        </div>
      ) : (
        <div className="p-3 rounded-md bg-ops-inset border border-ops-border space-y-2 overflow-x-auto">
          <div className="flex items-center justify-between gap-2 text-xs">
            <span className="num font-medium text-ops-text">
              Logical Threads (0–{pCores.length - 1})
            </span>
            <span className="num font-mono text-[11px] text-ops-muted">
              {pCores.length} threads
            </span>
          </div>
          {renderBarGroup(pCores, 0)}
        </div>
      )}
    </OpsCard>
  );
};
