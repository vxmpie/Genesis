import React, { useState } from 'react';
import {
  ChevronDown,
  ChevronRight,
  Edit3,
  Gamepad2,
  Loader2,
  MonitorSmartphone,
  RotateCcw,
  Scissors,
  Square,
  Wrench,
} from 'lucide-react';
import { useDashboardStore } from '../../store/useDashboard';
import { formatPercent } from '../../lib/format';
import type { GovernorAction, MuMuDevice } from '../../types/dashboard';
import {
  CardHeader,
  ConfirmButton,
  EmptyState,
  OpsCard,
  OpsSwitch,
  StatusBadge,
  type SemanticTone,
} from '../ui';

interface MuMuFleetTableProps {
  onGovernorAction: (instance: number, action: GovernorAction) => void;
  onToggleAutoRejoin: (instance: number | null, enabled: boolean) => void;
}

function getPresenceTone(status: string): SemanticTone {
  switch (status) {
    case 'InGame':
      return 'ok';
    case 'Online':
      return 'info';
    case 'InStudio':
      return 'accent';
    default:
      return 'muted';
  }
}

export const MuMuFleetTable: React.FC<MuMuFleetTableProps> = ({
  onGovernorAction,
  onToggleAutoRejoin,
}) => {
  const mumu = useDashboardStore((s) => s.mumu);
  const pendingOps = useDashboardStore((s) => s.pendingOps);
  const openEditGameModal = useDashboardStore((s) => s.openEditGameModal);
  const [launchersOpen, setLaunchersOpen] = useState(false);

  const devices = mumu?.devices ?? [];
  const launchers = mumu?.launchers ?? [];
  const backendReady = mumu !== null && mumu.auto_rejoin_global !== undefined;
  const globalRejoinEnabled = Boolean(mumu?.auto_rejoin_global ?? true);
  const globalPending = Boolean(pendingOps['rejoin:global']);

  const renderTargetCell = (dev: MuMuDevice, rejoinOff: boolean) => {
    const tone = getPresenceTone(dev.presence_status);
    const liveName =
      dev.presence_status === 'InGame' && dev.live_game_name ? dev.live_game_name : null;
    const targetName = liveName || dev.target_game || dev.active_game || 'Unassigned';
    const configuredId = dev.configured_place_id ?? 0;
    const displayTargetId = configuredId > 0 ? configuredId : dev.target_place_id;
    const hasLiveDifferentFromTarget =
      typeof dev.active_place_id === 'number' &&
      dev.active_place_id > 0 &&
      dev.active_place_id !== displayTargetId;

    return (
      <div className="flex flex-col items-start gap-1 min-w-0">
        <button
          type="button"
          onClick={() => openEditGameModal(dev)}
          title="Configure target Place ID, Roblox username, and Auto-Rejoin"
          className={`group inline-flex items-center gap-2 px-2.5 py-1.5 rounded-md border text-left transition-colors max-w-full ${
            rejoinOff
              ? 'bg-ops-inset border-ops-border text-ops-secondary hover:border-ops-borderStrong'
              : 'bg-ops-elevated border-ops-border hover:border-ops-borderStrong text-ops-text'
          }`}
        >
          <Gamepad2
            className={`w-3.5 h-3.5 shrink-0 ${
              rejoinOff ? 'text-ops-muted' : 'text-ops-telemetry'
            }`}
          />
          <div className="min-w-0">
            <div className="flex items-center gap-1.5 min-w-0">
              <span
                className={`text-xs font-sans font-medium truncate ${
                  rejoinOff ? 'opacity-70' : ''
                }`}
              >
                {targetName}
              </span>
              <StatusBadge tone={tone} dot>
                {dev.presence_status || 'Unknown'}
              </StatusBadge>
              {rejoinOff && <StatusBadge tone="muted">Rejoin off</StatusBadge>}
            </div>
            <div className="flex items-center flex-wrap gap-2 text-[10px] font-mono text-ops-muted mt-0.5">
              {rejoinOff && <span>Target (inactive)</span>}
              {dev.username ? (
                <span className="truncate">@{dev.username}</span>
              ) : (
                <span>No user bound</span>
              )}
              {configuredId > 0 ? (
                <span className="num">Target:{configuredId}</span>
              ) : dev.target_place_id > 0 ? (
                <span className="num">ID:{dev.target_place_id}</span>
              ) : null}
              {hasLiveDifferentFromTarget && (
                <span className="num text-ops-telemetry">Live:{dev.active_place_id}</span>
              )}
            </div>
          </div>
          <Edit3 className="w-3 h-3 text-ops-muted group-hover:text-ops-text shrink-0 ml-1" />
        </button>
      </div>
    );
  };

  const renderActions = (dev: MuMuDevice) => {
    const restartPending = Boolean(pendingOps[`governor:${dev.index}:restart_game`]);
    const trimPending = Boolean(pendingOps[`governor:${dev.index}:trim_ram`]);
    const killPending = Boolean(pendingOps[`governor:${dev.index}:kill_game`]);

    return (
      <div className="inline-flex items-center gap-1.5 justify-end flex-wrap">
        <button
          type="button"
          disabled={restartPending}
          onClick={() => onGovernorAction(dev.index, 'restart_game')}
          title="Manual soft restart Roblox on this instance"
          className="ops-btn h-7 px-2 bg-ops-elevated hover:bg-ops-border border border-ops-border text-[11px] text-ops-text"
        >
          {restartPending ? (
            <Loader2 className="w-3 h-3 animate-spin" />
          ) : (
            <RotateCcw className="w-3 h-3 text-ops-ok" />
          )}
          <span>Restart</span>
        </button>

        <button
          type="button"
          disabled={trimPending}
          onClick={() => onGovernorAction(dev.index, 'trim_ram')}
          title="Drop Android caches and trim /data on this instance"
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
          confirmLabel="Stop"
          pendingLabel="Stopping..."
          icon={<Square className="w-3 h-3" />}
          pending={killPending}
          title="Force stop Roblox on this instance"
          onConfirm={() => onGovernorAction(dev.index, 'kill_game')}
        />
      </div>
    );
  };

  return (
    <OpsCard className="space-y-3">
      <CardHeader
        icon={<MonitorSmartphone className="w-4 h-4 text-ops-accent" />}
        title="MuMu Emulator Fleet & Governor"
        subtitle="Manage live emulator slots, Roblox game targets, per-instance Auto-Rejoin, and ADB governor controls."
        badge={
          <StatusBadge tone={devices.length > 0 ? 'ok' : 'muted'} dot>
            {mumu ? `${devices.length} active` : 'Pending'}
          </StatusBadge>
        }
        actions={
          <div className="flex items-center gap-2.5 px-2.5 py-1.5 rounded-md bg-ops-inset border border-ops-border">
            <span className="text-xs text-ops-secondary font-medium">Auto-Rejoin (All)</span>
            {mumu && mumu.auto_rejoin_global === undefined ? (
              <StatusBadge tone="warn">Backend update required</StatusBadge>
            ) : (
              <OpsSwitch
                ariaLabel="Toggle Auto-Rejoin for all instances"
                checked={globalRejoinEnabled}
                pending={globalPending}
                disabled={!backendReady}
                tone="ok"
                title={
                  globalRejoinEnabled
                    ? 'Master switch active; individual rows can still be disabled'
                    : 'Master switch off; all automated rejoin paused'
                }
                onChange={(next) => onToggleAutoRejoin(null, next)}
              />
            )}
          </div>
        }
      />

      {mumu?.cleaner_active && (
        <div className="px-3 py-2 rounded-md bg-ops-warn/10 border border-ops-warn/30 text-xs text-ops-warn flex items-center gap-2">
          <Wrench className="w-3.5 h-3.5 shrink-0" />
          <span>
            MuMu Disk Cleaner process active. Intentional shutdowns during cleanup are suppressed from crash alerts.
          </span>
        </div>
      )}

      {!mumu?.cleaner_active && mumu?.pending_settle && (
        <div className="px-3 py-2 rounded-md bg-ops-elevated border border-ops-borderStrong text-xs text-ops-secondary">
          Settle window active. Confirming final emulator count before evaluating crash rules.
        </div>
      )}

      {!mumu ? (
        <EmptyState
          title="Waiting for MuMu telemetry..."
          description="Host process sampler has not emitted fleet data yet."
          icon={<MonitorSmartphone className="w-5 h-5" />}
        />
      ) : devices.length === 0 ? (
        <EmptyState
          title={
            mumu.launcher_running
              ? 'MuMu Launcher open with 0 running emulator instances'
              : 'No active MuMu emulator instances detected'
          }
          description="Launch an instance to configure Auto-Rejoin, Roblox presence, and governor controls."
          icon={<MonitorSmartphone className="w-5 h-5" />}
        />
      ) : (
        <>
          {/* Desktop Fleet Table */}
          <div className="hidden md:block overflow-x-auto rounded-md border border-ops-border bg-ops-inset">
            <table className="w-full text-left text-xs font-mono min-w-[760px]">
              <thead className="bg-ops-chrome text-[10px] uppercase text-ops-muted border-b border-ops-border">
                <tr>
                  <th className="py-2.5 px-3">Slot / PID</th>
                  <th className="py-2.5 px-3">Game & Presence</th>
                  <th className="py-2.5 px-3">Auto-Rejoin</th>
                  <th className="py-2.5 px-3 text-right">CPU</th>
                  <th className="py-2.5 px-3 text-right">RAM</th>
                  <th className="py-2.5 px-3">Uptime</th>
                  <th className="py-2.5 px-3 text-right">Governor Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-ops-border text-ops-text">
                {devices.map((dev) => {
                  const rowSupported = dev.auto_rejoin !== undefined;
                  const rowRejoinEnabled = rowSupported ? Boolean(dev.auto_rejoin) : true;
                  const rejoinOff = !globalRejoinEnabled || (rowSupported && !rowRejoinEnabled);
                  const rowPending = Boolean(pendingOps[`rejoin:${dev.index}`]);

                  return (
                    <tr key={dev.pid} className="hover:bg-ops-elevated/40 transition-colors">
                      <td className="py-2.5 px-3 align-top">
                        <div className="num font-semibold text-ops-text">#{dev.index}</div>
                        <div className="num text-[10px] text-ops-muted">
                          PID {dev.pid}
                          {dev.adb_port ? ` | :${dev.adb_port}` : ''}
                        </div>
                      </td>

                      <td className="py-2.5 px-3 align-top">{renderTargetCell(dev, rejoinOff)}</td>

                      <td className="py-2.5 px-3 align-middle">
                        <div className="flex items-center gap-2">
                          <OpsSwitch
                            ariaLabel={`Toggle Auto-Rejoin for Instance #${dev.index}`}
                            checked={rowRejoinEnabled && globalRejoinEnabled}
                            pending={rowPending}
                            disabled={!globalRejoinEnabled || !rowSupported}
                            tone="ok"
                            title={
                              !rowSupported
                                ? 'Requires elevated backend restart'
                                : !globalRejoinEnabled
                                ? 'Disabled while Auto-Rejoin (All) is off'
                                : rowRejoinEnabled
                                ? 'Auto-Rejoin enabled for this instance'
                                : 'Auto-Rejoin paused; safe to play any game manually'
                            }
                            onChange={(next) => onToggleAutoRejoin(dev.index, next)}
                          />
                          <span className="text-[11px] font-mono text-ops-secondary">
                            {!rowSupported
                              ? 'N/A'
                              : !globalRejoinEnabled
                              ? 'Master Off'
                              : rowRejoinEnabled
                              ? 'On'
                              : 'Off'}
                          </span>
                        </div>
                      </td>

                      <td className="num py-2.5 px-3 text-right text-ops-secondary align-middle">
                        {formatPercent(dev.cpu_percent, 0)}
                      </td>

                      <td className="num py-2.5 px-3 text-right align-middle">
                        <span className={dev.is_bloated ? 'text-ops-warn font-semibold' : 'text-ops-text'}>
                          {typeof dev.ram_mb === 'number' ? `${dev.ram_mb.toFixed(0)} MB` : '—'}
                        </span>
                        {dev.is_bloated && (
                          <div className="text-[10px] text-ops-warn">High RSS</div>
                        )}
                      </td>

                      <td className="num py-2.5 px-3 text-ops-secondary align-middle">
                        {dev.uptime || '—'}
                      </td>

                      <td className="py-2.5 px-3 text-right align-middle">
                        {renderActions(dev)}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>

          {/* Mobile Stacked Cards */}
          <div className="md:hidden space-y-2.5">
            {devices.map((dev) => {
              const rowSupported = dev.auto_rejoin !== undefined;
              const rowRejoinEnabled = rowSupported ? Boolean(dev.auto_rejoin) : true;
              const rejoinOff = !globalRejoinEnabled || (rowSupported && !rowRejoinEnabled);
              const rowPending = Boolean(pendingOps[`rejoin:${dev.index}`]);

              return (
                <div
                  key={dev.pid}
                  className="p-3 rounded-md bg-ops-inset border border-ops-border space-y-2.5"
                >
                  <div className="flex items-center justify-between gap-2">
                    <div className="num font-mono text-xs font-semibold text-ops-text">
                      Slot #{dev.index}{' '}
                      <span className="text-ops-muted font-normal">
                        (PID {dev.pid}{dev.adb_port ? ` | :${dev.adb_port}` : ''})
                      </span>
                    </div>
                    <div className="flex items-center gap-2">
                      <span className="text-[10px] font-mono text-ops-secondary">Rejoin</span>
                      <OpsSwitch
                        ariaLabel={`Toggle Auto-Rejoin for Instance #${dev.index}`}
                        checked={rowRejoinEnabled && globalRejoinEnabled}
                        pending={rowPending}
                        disabled={!globalRejoinEnabled || !rowSupported}
                        tone="ok"
                        onChange={(next) => onToggleAutoRejoin(dev.index, next)}
                      />
                    </div>
                  </div>

                  {renderTargetCell(dev, rejoinOff)}

                  <div className="grid grid-cols-3 gap-2 text-[11px] font-mono pt-1 border-t border-ops-border">
                    <div>
                      <span className="text-ops-muted block text-[10px]">CPU</span>
                      <span className="num text-ops-text">{formatPercent(dev.cpu_percent, 0)}</span>
                    </div>
                    <div>
                      <span className="text-ops-muted block text-[10px]">RAM</span>
                      <span className={`num ${dev.is_bloated ? 'text-ops-warn font-semibold' : 'text-ops-text'}`}>
                        {typeof dev.ram_mb === 'number' ? `${dev.ram_mb.toFixed(0)} MB` : '—'}
                      </span>
                    </div>
                    <div>
                      <span className="text-ops-muted block text-[10px]">Uptime</span>
                      <span className="num text-ops-secondary">{dev.uptime || '—'}</span>
                    </div>
                  </div>

                  <div className="pt-2 border-t border-ops-border flex justify-end">
                    {renderActions(dev)}
                  </div>
                </div>
              );
            })}
          </div>
        </>
      )}

      {/* Collapsible Launcher Processes */}
      {launchers.length > 0 && (
        <div className="rounded-md border border-ops-border bg-ops-inset overflow-hidden">
          <button
            type="button"
            onClick={() => setLaunchersOpen((v) => !v)}
            className="w-full px-3 py-2 flex items-center justify-between text-xs text-ops-secondary hover:bg-ops-elevated/40 transition-colors"
          >
            <span className="inline-flex items-center gap-1.5 font-medium">
              {launchersOpen ? (
                <ChevronDown className="w-3.5 h-3.5 text-ops-muted" />
              ) : (
                <ChevronRight className="w-3.5 h-3.5 text-ops-muted" />
              )}
              <span>Launcher Host Processes ({launchers.length})</span>
            </span>
            <span className="font-mono text-[10px] text-ops-muted">Separated from emulator slots</span>
          </button>

          {launchersOpen && (
            <div className="border-t border-ops-border divide-y divide-ops-border px-3 py-1.5 text-xs font-mono">
              {launchers.map((l) => (
                <div key={l.pid} className="py-1.5 flex items-center justify-between gap-2">
                  <div className="truncate text-ops-text">
                    {l.name} <span className="text-ops-muted">(PID {l.pid})</span>
                  </div>
                  <div className="num flex items-center gap-3 text-ops-secondary shrink-0">
                    <span>{typeof l.ram_mb === 'number' ? `${l.ram_mb.toFixed(0)} MB` : '—'}</span>
                    <span>{l.uptime || '—'}</span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </OpsCard>
  );
};
