import React from 'react';
import { ArrowRight, MonitorSmartphone, Wrench } from 'lucide-react';
import { useDashboardStore } from '../../store/useDashboard';

export const OverviewInstancesSummary: React.FC = () => {
  const mumu = useDashboardStore((s) => s.mumu);
  const setActiveView = useDashboardStore((s) => s.setActiveView);

  const devices = mumu?.devices ?? [];

  const getPresenceDot = (status: string) => {
    switch (status) {
      case 'InGame':
        return 'bg-ops-ok';
      case 'Online':
        return 'bg-ops-warn';
      case 'InStudio':
        return 'bg-ops-accent';
      default:
        return 'bg-ops-muted';
    }
  };

  return (
    <div className="ops-card p-4 flex flex-col gap-3 h-full">
      {/* Header */}
      <div className="flex items-center justify-between gap-2">
        <div className="flex items-center gap-2 min-w-0">
          <MonitorSmartphone className="w-4 h-4 text-ops-accent shrink-0" />
          <h2 className="text-xs font-semibold text-ops-text uppercase tracking-wider truncate">
            Active Instances
          </h2>
          {mumu && (
            <span className="num font-mono text-[10px] px-1.5 py-0.5 rounded bg-ops-inset border border-ops-border text-ops-secondary">
              {devices.length}
            </span>
          )}
        </div>

        <button
          type="button"
          onClick={() => setActiveView('instances')}
          className="text-xs text-ops-accent hover:text-blue-400 font-medium inline-flex items-center gap-1 shrink-0"
        >
          <span>Manage All</span>
          <ArrowRight className="w-3.5 h-3.5" />
        </button>
      </div>

      {/* Truthful Maintenance Banners */}
      {mumu?.cleaner_active && (
        <div className="px-3 py-2 rounded-md bg-ops-warn/10 border border-ops-warn/30 text-xs text-ops-warn flex items-center gap-2">
          <Wrench className="w-3.5 h-3.5 shrink-0" />
          <span>MuMu Disk Cleaner active. Intentional instance teardown is suppressed from crash alerts.</span>
        </div>
      )}

      {!mumu?.cleaner_active && mumu?.pending_settle && (
        <div className="px-3 py-2 rounded-md bg-ops-elevated border border-ops-borderStrong text-xs text-ops-secondary">
          Settle window active. Confirming final emulator instance state before dispatching alerts.
        </div>
      )}

      {/* Table / Empty States */}
      {!mumu ? (
        <div className="flex-1 min-h-[180px] flex items-center justify-center rounded-md border border-ops-border bg-ops-inset text-xs font-mono text-ops-muted">
          Waiting for host telemetry...
        </div>
      ) : devices.length === 0 ? (
        <div className="flex-1 min-h-[180px] flex flex-col items-center justify-center gap-1 rounded-md border border-ops-border bg-ops-inset px-4 text-center">
          <span className="text-xs font-medium text-ops-secondary">
            {mumu.launcher_running
              ? 'MuMu Launcher open, 0 emulator instances running'
              : 'No active MuMu emulator instances'}
          </span>
          <span className="text-[11px] font-mono text-ops-muted">
            {mumu.cleaner_active
              ? 'Disk cleanup in progress'
              : 'Launch an instance to begin live presence tracking'}
          </span>
        </div>
      ) : (
        <div className="overflow-x-auto rounded-md border border-ops-border bg-ops-inset">
          <table className="w-full text-left text-xs font-mono">
            <thead className="bg-ops-chrome text-[10px] uppercase text-ops-muted border-b border-ops-border">
              <tr>
                <th className="py-2 px-2.5">Slot</th>
                <th className="py-2 px-2.5">Game / Presence</th>
                <th className="py-2 px-2.5">Account</th>
                <th className="py-2 px-2.5 text-right">CPU</th>
                <th className="py-2 px-2.5 text-right">RAM</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-ops-border text-ops-text">
              {devices.map((dev) => (
                <tr key={dev.pid} className="hover:bg-ops-elevated/60 transition-colors">
                  <td className="num py-2 px-2.5 font-semibold">#{dev.index}</td>
                  <td className="py-2 px-2.5 max-w-[180px]">
                    <div className="flex items-center gap-1.5 min-w-0">
                      <span
                        className={`w-1.5 h-1.5 rounded-full shrink-0 ${getPresenceDot(
                          dev.presence_status
                        )}`}
                        title={dev.presence_status}
                      />
                      <span className="truncate font-sans font-medium" title={dev.active_game}>
                        {dev.active_game}
                      </span>
                    </div>
                  </td>
                  <td className="py-2 px-2.5 text-ops-secondary truncate max-w-[110px]">
                    {dev.username ? `@${dev.username}` : '—'}
                  </td>
                  <td className="num py-2 px-2.5 text-right text-ops-secondary">
                    {dev.cpu_percent.toFixed(0)}%
                  </td>
                  <td className="num py-2 px-2.5 text-right">
                    <span className={dev.is_bloated ? 'text-ops-warn font-semibold' : 'text-ops-text'}>
                      {dev.ram_mb.toFixed(0)} MB
                    </span>
                    {dev.is_bloated && (
                      <span className="ml-1.5 text-[9px] px-1 py-0.5 rounded bg-ops-warn/10 text-ops-warn border border-ops-warn/30">
                        HIGH
                      </span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
};
