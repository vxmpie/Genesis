import React from 'react';
import {
  AlertTriangle,
  Cpu,
  HardDrive,
  MemoryStick,
  MonitorSmartphone,
  ShieldCheck,
} from 'lucide-react';
import { useDashboardStore } from '../../store/useDashboard';
import { formatGb, formatMb, formatPercent } from '../../lib/format';

export const OverviewKpiStrip: React.FC = () => {
  const metrics = useDashboardStore((s) => s.metrics);
  const mumu = useDashboardStore((s) => s.mumu);
  const hardening = useDashboardStore((s) => s.hardening);
  const setActiveView = useDashboardStore((s) => s.setActiveView);

  const cpu = metrics?.cpu;
  const cpuPct = cpu?.total_percent;
  const cpuTone =
    cpuPct === undefined
      ? 'bg-ops-muted'
      : cpuPct >= 90
      ? 'bg-ops-danger'
      : cpuPct >= 75
      ? 'bg-ops-warn'
      : 'bg-ops-telemetry';

  const ram = metrics?.ram;
  const ramPct = ram?.percent;
  const totalGb = ram?.total_gb ?? 0;
  const activeRatio = totalGb > 0 && ram ? Math.min(100, (ram.active_gb / totalGb) * 100) : 0;
  const standbyRatio =
    totalGb > 0 && ram ? Math.min(100 - activeRatio, (ram.standby_gb / totalGb) * 100) : 0;

  const emulatorCount = mumu?.count;
  const emulatorRamMb = mumu
    ? mumu.devices.reduce((sum, dev) => sum + (dev.ram_mb || 0), 0)
    : null;

  const fleetBadge = !mumu
    ? { label: 'Pending', cls: 'bg-ops-inset text-ops-muted border-ops-border' }
    : mumu.cleaner_active
    ? { label: 'Cleaner Active', cls: 'bg-ops-warn/10 text-ops-warn border-ops-warn/30' }
    : mumu.pending_settle
    ? { label: 'Settling', cls: 'bg-ops-warn/10 text-ops-warn border-ops-warn/30' }
    : mumu.count > 0
    ? { label: 'Running', cls: 'bg-ops-ok/10 text-ops-ok border-ops-ok/30' }
    : { label: 'Idle', cls: 'bg-ops-inset text-ops-secondary border-ops-border' };

  const cDrive = metrics?.storage?.c_drive;
  const gpu = metrics?.gpu;
  const robloxPing = metrics?.network.roblox_ping_ms;

  const secondaryHealthText = gpu?.available
    ? `GPU ${gpu.temperature_c} C (${gpu.utilization_percent}%)`
    : typeof robloxPing === 'number' && robloxPing > 0
    ? `Edge ${robloxPing.toFixed(1)} ms`
    : '—';

  return (
    <section aria-label="Key performance indicators" className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-3">
      {/* KPI 1: CPU Load */}
      <div className="ops-card p-4 flex flex-col justify-between gap-3">
        <div className="flex items-center justify-between gap-2">
          <span className="flex items-center gap-1.5 text-xs font-medium text-ops-secondary">
            <Cpu className="w-3.5 h-3.5 text-ops-telemetry shrink-0" />
            <span>CPU Load</span>
          </span>
          <span className="num font-mono text-[11px] text-ops-muted">
            {cpu ? `${cpu.core_count}T @ ${cpu.frequency_ghz.toFixed(2)} GHz` : '—'}
          </span>
        </div>

        <div>
          <div className="num font-mono text-2xl font-semibold text-ops-text tracking-tight">
            {formatPercent(cpuPct)}
          </div>
          <div className="w-full h-1.5 rounded-full bg-ops-inset border border-ops-border mt-2 overflow-hidden">
            <div
              className={`h-full transition-[width] duration-300 ${cpuTone}`}
              style={{ width: `${Math.min(100, Math.max(0, cpuPct ?? 0))}%` }}
            />
          </div>
        </div>

        <div
          className="text-[11px] font-mono text-ops-muted truncate"
          title={cpu?.model || undefined}
        >
          {cpu?.model || 'Waiting for telemetry...'}
        </div>
      </div>

      {/* KPI 2: Memory & Standby */}
      <div className="ops-card p-4 flex flex-col justify-between gap-3">
        <div className="flex items-center justify-between gap-2">
          <span className="flex items-center gap-1.5 text-xs font-medium text-ops-secondary">
            <MemoryStick className="w-3.5 h-3.5 text-ops-accent shrink-0" />
            <span>Memory</span>
          </span>
          <span className="num font-mono text-[11px] text-ops-muted">
            {ram ? `${ram.used_gb.toFixed(1)} / ${ram.total_gb.toFixed(0)} GB` : '—'}
          </span>
        </div>

        <div>
          <div className="num font-mono text-2xl font-semibold text-ops-text tracking-tight">
            {formatPercent(ramPct)}
          </div>
          <div className="w-full h-1.5 rounded-full bg-ops-inset border border-ops-border mt-2 overflow-hidden flex">
            <div
              className="h-full bg-ops-accent transition-[width] duration-300"
              style={{ width: `${activeRatio}%` }}
              title={ram ? `Active: ${ram.active_gb.toFixed(1)} GB` : undefined}
            />
            <div
              className="h-full bg-ops-warn transition-[width] duration-300"
              style={{ width: `${standbyRatio}%` }}
              title={ram ? `Standby: ${ram.standby_gb.toFixed(1)} GB` : undefined}
            />
          </div>
        </div>

        <div className="flex items-center justify-between text-[11px] font-mono text-ops-muted">
          <span className="num">
            Standby:{' '}
            <span className="text-ops-secondary">
              {ram ? formatGb(ram.standby_gb) : '—'}
            </span>
          </span>
          <span className="num">
            Free:{' '}
            <span className="text-ops-secondary">
              {ram ? formatGb(ram.free_gb) : '—'}
            </span>
          </span>
        </div>
      </div>

      {/* KPI 3: MuMu Fleet */}
      <button
        type="button"
        onClick={() => setActiveView('instances')}
        className="ops-card-interactive p-4 flex flex-col justify-between gap-3 text-left"
      >
        <div className="flex items-center justify-between gap-2 w-full">
          <span className="flex items-center gap-1.5 text-xs font-medium text-ops-secondary">
            <MonitorSmartphone className="w-3.5 h-3.5 text-ops-accent shrink-0" />
            <span>MuMu Fleet</span>
          </span>
          <span
            className={`text-[10px] font-mono px-1.5 py-0.5 rounded border ${fleetBadge.cls}`}
          >
            {fleetBadge.label}
          </span>
        </div>

        <div className="flex items-baseline gap-2">
          <span className="num font-mono text-2xl font-semibold text-ops-text tracking-tight">
            {emulatorCount !== undefined ? emulatorCount : '—'}
          </span>
          <span className="text-xs text-ops-muted font-mono">
            {emulatorCount === 1 ? 'instance' : 'instances'}
          </span>
        </div>

        <div className="flex items-center justify-between text-[11px] font-mono text-ops-muted w-full">
          <span className="num">
            Footprint:{' '}
            <span className="text-ops-secondary">
              {emulatorRamMb === null
                ? '—'
                : emulatorRamMb >= 1024
                ? formatGb(emulatorRamMb / 1024)
                : formatMb(emulatorRamMb)}
            </span>
          </span>
          <span className="text-ops-accent">Inspect</span>
        </div>
      </button>

      {/* KPI 4: Storage & System Health */}
      <div className="ops-card p-4 flex flex-col justify-between gap-3">
        <div className="flex items-center justify-between gap-2">
          <span className="flex items-center gap-1.5 text-xs font-medium text-ops-secondary">
            <HardDrive className="w-3.5 h-3.5 text-ops-ok shrink-0" />
            <span>System Disk (C:)</span>
          </span>
          <span className="num font-mono text-[11px] text-ops-muted">
            {cDrive ? `${cDrive.percent.toFixed(0)}% used` : '—'}
          </span>
        </div>

        <div className="flex items-baseline justify-between gap-2">
          <div className="num font-mono text-2xl font-semibold text-ops-text tracking-tight">
            {cDrive ? formatGb(cDrive.free_gb) : '—'}
          </div>
          <span className="text-[11px] font-mono text-ops-muted">free</span>
        </div>

        <div className="flex items-center justify-between gap-2 text-[11px] font-mono">
          <button
            type="button"
            onClick={() => setActiveView('system')}
            className={`inline-flex items-center gap-1 px-1.5 py-0.5 rounded border transition-colors ${
              !hardening
                ? 'bg-ops-inset text-ops-muted border-ops-border'
                : hardening.has_drift
                ? 'bg-ops-warn/10 text-ops-warn border-ops-warn/30'
                : 'bg-ops-ok/10 text-ops-ok border-ops-ok/30'
            }`}
          >
            {hardening?.has_drift ? (
              <AlertTriangle className="w-3 h-3 shrink-0" />
            ) : (
              <ShieldCheck className="w-3 h-3 shrink-0" />
            )}
            <span>
              {!hardening ? 'Pending' : hardening.has_drift ? 'Drift' : 'Hardened'}
            </span>
          </button>
          <span className="num text-ops-secondary truncate">{secondaryHealthText}</span>
        </div>
      </div>
    </section>
  );
};
