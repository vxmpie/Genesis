import React from 'react';
import { BarChart3, Loader2, Scissors, Shield, Square } from 'lucide-react';
import { useDashboardStore } from '../../store/useDashboard';
import { formatPercent } from '../../lib/format';
import type { TopProcess } from '../../types/dashboard';
import { CardHeader, ConfirmButton, EmptyState, OpsCard, StatusBadge } from '../ui';

interface TopProcsCardProps {
  onTrimProcess: (pid: number) => void;
  onKillProcess: (pid: number) => void;
}

export const TopProcsCard: React.FC<TopProcsCardProps> = ({
  onTrimProcess,
  onKillProcess,
}) => {
  const topProcesses = useDashboardStore((s) => s.topProcesses);
  const config = useDashboardStore((s) => s.config);
  const pendingOps = useDashboardStore((s) => s.pendingOps);

  const protectedSet = new Set(
    (config?.auto_boost.protected_processes ?? []).map((n) => n.toLowerCase())
  );

  const isProcProtected = (proc: TopProcess): boolean =>
    Boolean(proc.protected) || protectedSet.has(proc.name.toLowerCase());

  return (
    <OpsCard className="space-y-3">
      <CardHeader
        icon={<BarChart3 className="w-4 h-4 text-ops-warn" />}
        title="Top Processes (By Memory)"
        subtitle="Inspect highest-RSS host processes. Trim or terminate non-protected processes after PIN auth."
        badge={
          <StatusBadge tone="muted">{topProcesses.length} sampled</StatusBadge>
        }
      />

      {topProcesses.length === 0 ? (
        <EmptyState
          title="Sampling host processes..."
          description="Process list updates every telemetry tick."
          icon={<BarChart3 className="w-5 h-5" />}
        />
      ) : (
        <>
          {/* Desktop Table */}
          <div className="hidden md:block overflow-x-auto rounded-md border border-ops-border bg-ops-inset">
            <table className="w-full text-left text-xs font-mono">
              <thead className="bg-ops-chrome text-[10px] uppercase text-ops-muted border-b border-ops-border">
                <tr>
                  <th className="py-2.5 px-3">Process Name</th>
                  <th className="py-2.5 px-3">PID</th>
                  <th className="py-2.5 px-3 text-right">RAM</th>
                  <th className="py-2.5 px-3 text-right">CPU</th>
                  <th className="py-2.5 px-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-ops-border text-ops-text">
                {topProcesses.map((proc) => {
                  const protectedFlag = isProcProtected(proc);
                  const trimPending = Boolean(pendingOps[`procTrim:${proc.pid}`]);
                  const killPending = Boolean(pendingOps[`procKill:${proc.pid}`]);

                  return (
                    <tr key={proc.pid} className="hover:bg-ops-elevated/40 transition-colors">
                      <td className="py-2 px-3">
                        <div className="flex items-center gap-2 min-w-0">
                          <span
                            className="font-sans font-medium text-ops-text truncate max-w-[240px]"
                            title={proc.name}
                          >
                            {proc.name}
                          </span>
                          {protectedFlag && (
                            <StatusBadge tone="muted" title="Protected system or emulator process">
                              <span className="inline-flex items-center gap-1">
                                <Shield className="w-2.5 h-2.5" />
                                <span>Protected</span>
                              </span>
                            </StatusBadge>
                          )}
                        </div>
                      </td>
                      <td className="num py-2 px-3 text-ops-secondary">{proc.pid}</td>
                      <td className="num py-2 px-3 text-right font-semibold text-ops-accent">
                        {proc.ram_mb.toFixed(1)} MB
                      </td>
                      <td className="num py-2 px-3 text-right text-ops-secondary">
                        {formatPercent(proc.cpu_percent, 1)}
                      </td>
                      <td className="py-2 px-3 text-right">
                        <div className="inline-flex items-center gap-1.5 justify-end">
                          <button
                            type="button"
                            disabled={trimPending || proc.pid <= 4}
                            onClick={() => onTrimProcess(proc.pid)}
                            title="Empty working set for this PID (PIN required)"
                            className="ops-btn h-7 px-2 bg-ops-elevated hover:bg-ops-border border border-ops-border text-[11px] text-ops-text"
                          >
                            {trimPending ? (
                              <Loader2 className="w-3 h-3 animate-spin" />
                            ) : (
                              <Scissors className="w-3 h-3 text-ops-telemetry" />
                            )}
                            <span>Trim</span>
                          </button>

                          <ConfirmButton
                            compact
                            tone="danger"
                            label="Kill"
                            confirmLabel="Terminate"
                            pendingLabel="Killing..."
                            icon={<Square className="w-3 h-3" />}
                            pending={killPending}
                            disabled={protectedFlag || proc.pid <= 4}
                            title={
                              protectedFlag
                                ? 'Protected system or emulator process'
                                : 'Terminate process (PIN required)'
                            }
                            onConfirm={() => onKillProcess(proc.pid)}
                          />
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>

          {/* Mobile Cards */}
          <div className="md:hidden space-y-2">
            {topProcesses.map((proc) => {
              const protectedFlag = isProcProtected(proc);
              const trimPending = Boolean(pendingOps[`procTrim:${proc.pid}`]);
              const killPending = Boolean(pendingOps[`procKill:${proc.pid}`]);

              return (
                <div
                  key={proc.pid}
                  className="p-3 rounded-md bg-ops-inset border border-ops-border space-y-2"
                >
                  <div className="flex items-center justify-between gap-2">
                    <div className="min-w-0">
                      <div className="text-xs font-medium text-ops-text truncate">{proc.name}</div>
                      <div className="num text-[11px] font-mono text-ops-muted">
                        PID {proc.pid} | {proc.ram_mb.toFixed(1)} MB |{' '}
                        {formatPercent(proc.cpu_percent, 1)} CPU
                      </div>
                    </div>
                    {protectedFlag && <StatusBadge tone="muted">Protected</StatusBadge>}
                  </div>

                  <div className="flex items-center justify-end gap-1.5 pt-1.5 border-t border-ops-border">
                    <button
                      type="button"
                      disabled={trimPending || proc.pid <= 4}
                      onClick={() => onTrimProcess(proc.pid)}
                      className="ops-btn h-7 px-2.5 bg-ops-elevated hover:bg-ops-border border border-ops-border text-[11px] text-ops-text"
                    >
                      {trimPending ? (
                        <Loader2 className="w-3 h-3 animate-spin" />
                      ) : (
                        <Scissors className="w-3 h-3 text-ops-telemetry" />
                      )}
                      <span>Trim</span>
                    </button>

                    <ConfirmButton
                      compact
                      tone="danger"
                      label="Kill"
                      confirmLabel="Terminate"
                      pendingLabel="Killing..."
                      icon={<Square className="w-3 h-3" />}
                      pending={killPending}
                      disabled={protectedFlag || proc.pid <= 4}
                      title={
                        protectedFlag
                          ? 'Protected system or emulator process'
                          : 'Terminate process (PIN required)'
                      }
                      onConfirm={() => onKillProcess(proc.pid)}
                    />
                  </div>
                </div>
              );
            })}
          </div>
        </>
      )}
    </OpsCard>
  );
};
