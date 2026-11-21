import React from 'react';
import { HardDrive, Layers, MemoryStick, MonitorSmartphone } from 'lucide-react';
import { useDashboardStore } from '../../store/useDashboard';
import { formatGb, formatMb } from '../../lib/format';
import type { GovernorAction } from '../../types/dashboard';
import { StatusBadge } from '../ui';
import { GamePresetsCard } from './GamePresetsCard';
import { MuMuFleetTable } from './MuMuFleetTable';
import { VmDiskSentinelCard } from './VmDiskSentinelCard';

export interface InstancesViewProps {
  onGovernorAction: (instance: number, action: GovernorAction) => void;
  onToggleAutoRejoin: (instance: number | null, enabled: boolean) => void;
  onAddPreset: (placeId: number, name: string) => void;
  onUpdatePreset: (originalPlaceId: number, placeId: number, name: string) => void;
  onDeletePreset: (placeId: number) => void;
  onRefreshVmDisk: () => void;
  onTrimVmCache: (port: number) => void;
}

export const InstancesView: React.FC<InstancesViewProps> = ({
  onGovernorAction,
  onToggleAutoRejoin,
  onAddPreset,
  onUpdatePreset,
  onDeletePreset,
  onRefreshVmDisk,
  onTrimVmCache,
}) => {
  const mumu = useDashboardStore((s) => s.mumu);
  const vmDisk = useDashboardStore((s) => s.vmDisk);

  const devices = mumu?.devices ?? [];
  const totalRamMb = mumu
    ? devices.reduce((sum, dev) => sum + (dev.ram_mb || 0), 0)
    : null;

  const rejoinSummary = (() => {
    if (!mumu) {
      return { label: '—', tone: 'muted' as const, detail: 'Waiting for telemetry...' };
    }
    if (mumu.auto_rejoin_global === undefined) {
      return {
        label: 'Update Needed',
        tone: 'warn' as const,
        detail: 'Restart elevated server for toggle support',
      };
    }
    if (!mumu.auto_rejoin_global) {
      return {
        label: 'Global Off',
        tone: 'muted' as const,
        detail: 'All automated rejoin paused',
      };
    }
    const disabledCount = devices.filter((d) => d.auto_rejoin === false).length;
    if (devices.length === 0) {
      return { label: 'Armed', tone: 'ok' as const, detail: 'No active instances' };
    }
    if (disabledCount === 0) {
      return {
        label: 'All Armed',
        tone: 'ok' as const,
        detail: `${devices.length} of ${devices.length} active`,
      };
    }
    const enabledCount = devices.length - disabledCount;
    return {
      label: 'Partial',
      tone: 'warn' as const,
      detail: `${enabledCount} of ${devices.length} armed`,
    };
  })();

  const vmAlertSummary = (() => {
    if (!mumu) {
      return { value: '—', tone: 'muted' as const, detail: 'Waiting for telemetry...' };
    }
    if (vmDisk.length === 0) {
      return { value: '0', tone: 'muted' as const, detail: 'No /data scan yet' };
    }
    const criticals = vmDisk.filter((v) => v.status === 'critical').length;
    const warnings = vmDisk.filter((v) => v.status === 'warning').length;
    const totalAlerts = criticals + warnings;
    if (criticals > 0) {
      return {
        value: String(totalAlerts),
        tone: 'danger' as const,
        detail: `${criticals} critical, ${warnings} warning`,
      };
    }
    if (warnings > 0) {
      return {
        value: String(totalAlerts),
        tone: 'warn' as const,
        detail: `${warnings} warning threshold`,
      };
    }
    return {
      value: '0',
      tone: 'ok' as const,
      detail: `${vmDisk.length} partition(s) healthy`,
    };
  })();

  return (
    <div className="space-y-4">
      {/* Fleet KPI Summary */}
      <section aria-label="Instances overview metrics" className="grid grid-cols-2 lg:grid-cols-4 gap-3">
        <div className="ops-card p-4 flex flex-col justify-between gap-2">
          <div className="flex items-center justify-between text-xs text-ops-secondary">
            <span>Active Emulators</span>
            <MonitorSmartphone className="w-3.5 h-3.5 text-ops-accent" />
          </div>
          <div className="num font-mono text-2xl font-semibold text-ops-text">
            {mumu ? devices.length : '—'}
          </div>
          <div className="flex items-center justify-between gap-2">
            <span className="num font-mono text-[11px] text-ops-muted">
              {mumu
                ? `${mumu.launchers.length} launcher${mumu.launchers.length === 1 ? '' : 's'}`
                : 'Waiting...'}
            </span>
            {mumu?.cleaner_active && <StatusBadge tone="warn">Cleaner</StatusBadge>}
          </div>
        </div>

        <div className="ops-card p-4 flex flex-col justify-between gap-2">
          <div className="flex items-center justify-between text-xs text-ops-secondary">
            <span>Emulator Footprint</span>
            <MemoryStick className="w-3.5 h-3.5 text-ops-telemetry" />
          </div>
          <div className="num font-mono text-2xl font-semibold text-ops-text">
            {totalRamMb === null
              ? '—'
              : totalRamMb >= 1024
              ? formatGb(totalRamMb / 1024)
              : formatMb(totalRamMb)}
          </div>
          <div className="num font-mono text-[11px] text-ops-muted">
            {totalRamMb !== null ? `${totalRamMb.toFixed(0)} MB RSS total` : 'Waiting...'}
          </div>
        </div>

        <div className="ops-card p-4 flex flex-col justify-between gap-2">
          <div className="flex items-center justify-between text-xs text-ops-secondary">
            <span>Auto-Rejoin Policy</span>
            <Layers className="w-3.5 h-3.5 text-ops-ok" />
          </div>
          <div>
            <StatusBadge tone={rejoinSummary.tone} dot>
              {rejoinSummary.label}
            </StatusBadge>
          </div>
          <div className="num font-mono text-[11px] text-ops-muted truncate">
            {rejoinSummary.detail}
          </div>
        </div>

        <div className="ops-card p-4 flex flex-col justify-between gap-2">
          <div className="flex items-center justify-between text-xs text-ops-secondary">
            <span>VM Disk Alerts</span>
            <HardDrive className="w-3.5 h-3.5 text-ops-warn" />
          </div>
          <div className="flex items-baseline gap-2">
            <span className="num font-mono text-2xl font-semibold text-ops-text">
              {vmAlertSummary.value}
            </span>
            <StatusBadge tone={vmAlertSummary.tone}>
              {vmDisk.length > 0 ? 'Checked' : 'Idle'}
            </StatusBadge>
          </div>
          <div className="num font-mono text-[11px] text-ops-muted truncate">
            {vmAlertSummary.detail}
          </div>
        </div>
      </section>

      <MuMuFleetTable
        onGovernorAction={onGovernorAction}
        onToggleAutoRejoin={onToggleAutoRejoin}
      />

      <GamePresetsCard
        onAddPreset={onAddPreset}
        onUpdatePreset={onUpdatePreset}
        onDeletePreset={onDeletePreset}
      />

      <VmDiskSentinelCard
        onRefreshVmDisk={onRefreshVmDisk}
        onTrimVmCache={onTrimVmCache}
      />
    </div>
  );
};
