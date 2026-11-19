import React from 'react';
import { Loader2, Shield, Zap } from 'lucide-react';
import { useDashboardStore } from '../../store/useDashboard';
import {
  CardHeader,
  ConfirmButton,
  EmptyState,
  OpsCard,
  OpsSwitch,
  StatusBadge,
} from '../ui';

interface AutoBoostCardProps {
  onToggle: (enabled: boolean) => void;
  onSetThreshold: (val: number) => void;
  onSetMode: (mode: 'auto' | 'scheduled') => void;
  onSetInterval: (minutes: number) => void;
  onBoostNow: () => void;
  onResetSessionBoosts: () => void;
  onResetTotalBoosts: () => void;
}

export const AutoBoostCard: React.FC<AutoBoostCardProps> = ({
  onToggle,
  onSetThreshold,
  onSetMode,
  onSetInterval,
  onBoostNow,
  onResetSessionBoosts,
  onResetTotalBoosts,
}) => {
  const autoBoost = useDashboardStore((s) => s.autoBoost);
  const summary = useDashboardStore((s) => s.summary);
  const maintenance = useDashboardStore((s) => s.config?.maintenance);
  const isBoosting = useDashboardStore((s) => s.isBoosting);
  const pendingOps = useDashboardStore((s) => s.pendingOps);

  const boosting = isBoosting || Boolean(pendingOps['boost']);
  const togglePending = Boolean(pendingOps['autoboost:enabled']);
  const thresholdPending = Boolean(pendingOps['autoboost:threshold']);
  const modePending = Boolean(pendingOps['autoboost:mode']);
  const intervalPending = Boolean(pendingOps['autoboost:interval']);

  const standby = summary?.standby_guard;

  return (
    <OpsCard className="flex flex-col gap-4">
      <div className="space-y-3">
        <CardHeader
          icon={<Zap className="w-4 h-4 text-ops-accent" />}
          title="Auto-Boost & Standby Guard"
          subtitle="Server-authoritative memory reclamation and Standby List purge thresholds."
          badge={
            autoBoost ? (
              <StatusBadge tone={autoBoost.enabled ? 'ok' : 'muted'} dot>
                {autoBoost.enabled ? 'Armed' : 'Disarmed'}
              </StatusBadge>
            ) : (
              <StatusBadge tone="muted">Loading</StatusBadge>
            )
          }
        />

        {!autoBoost ? (
          <EmptyState
            title="Waiting for Auto-Boost configuration..."
            description="Controls activate automatically once WebSocket init payload arrives."
            icon={<Zap className="w-5 h-5" />}
          />
        ) : (
          <div className="rounded-md border border-ops-border bg-ops-inset divide-y divide-ops-border text-xs">
            {/* Autonomous Toggle */}
            <div className="px-3 py-2.5 flex items-center justify-between gap-2">
              <div>
                <div className="font-medium text-ops-text">Autonomous Sentinel</div>
                <div className="text-[11px] text-ops-muted">
                  Requires PIN auth; state syncs from server confirmation.
                </div>
              </div>
              <OpsSwitch
                ariaLabel="Toggle Autonomous Auto-Boost"
                checked={autoBoost.enabled}
                pending={togglePending}
                tone="ok"
                onChange={onToggle}
              />
            </div>

            {/* Threshold Stepper */}
            <div className="px-3 py-2.5 flex items-center justify-between gap-2">
              <div>
                <div className="font-medium text-ops-text">RAM Threshold</div>
                <div className="text-[11px] text-ops-muted">
                  Trigger ceiling in dynamic mode (10%–95%)
                </div>
              </div>
              <div className="flex items-center gap-1.5">
                <button
                  type="button"
                  disabled={thresholdPending || autoBoost.threshold <= 10}
                  onClick={() =>
                    onSetThreshold(Math.max(10, Math.floor((autoBoost.threshold - 1) / 5) * 5))
                  }
                  aria-label="Decrease RAM threshold"
                  className="ops-btn w-7 h-7 bg-ops-elevated hover:bg-ops-border border border-ops-border text-ops-text font-mono"
                >
                  -
                </button>
                <span className="num font-mono text-xs font-semibold text-ops-warn min-w-[40px] text-center">
                  {autoBoost.threshold}%
                </span>
                <button
                  type="button"
                  disabled={thresholdPending || autoBoost.threshold >= 95}
                  onClick={() =>
                    onSetThreshold(Math.min(95, Math.ceil((autoBoost.threshold + 1) / 5) * 5))
                  }
                  aria-label="Increase RAM threshold"
                  className="ops-btn w-7 h-7 bg-ops-elevated hover:bg-ops-border border border-ops-border text-ops-text font-mono"
                >
                  +
                </button>
              </div>
            </div>

            {/* Mode Selector */}
            <div className="px-3 py-2.5 flex items-center justify-between gap-2">
              <label htmlFor="autoboost-mode-select" className="font-medium text-ops-text">
                Operating Mode
              </label>
              <select
                id="autoboost-mode-select"
                disabled={modePending}
                value={autoBoost.mode}
                onChange={(e) => onSetMode(e.target.value as 'auto' | 'scheduled')}
                className="ops-input h-8 px-2.5 text-xs font-mono"
              >
                <option value="scheduled">Scheduled Clock</option>
                <option value="auto">Dynamic Threshold</option>
              </select>
            </div>

            {/* Interval Selector */}
            {autoBoost.mode === 'scheduled' && (
              <div className="px-3 py-2.5 flex items-center justify-between gap-2">
                <label htmlFor="autoboost-interval-select" className="font-medium text-ops-text">
                  Schedule Interval
                </label>
                <select
                  id="autoboost-interval-select"
                  disabled={intervalPending}
                  value={autoBoost.interval_minutes}
                  onChange={(e) => onSetInterval(Number(e.target.value))}
                  className="ops-input num h-8 px-2.5 text-xs font-mono"
                >
                  <option value={15}>15 min</option>
                  <option value={30}>30 min</option>
                  <option value={60}>60 min</option>
                  <option value={120}>120 min</option>
                </select>
              </div>
            )}
          </div>
        )}

        {/* Standby Guard & Boost Counters */}
        <div className="p-3 rounded-md bg-ops-inset border border-ops-border space-y-2.5">
          <div className="flex items-center justify-between gap-2">
            <span className="flex items-center gap-1.5 text-xs font-medium text-ops-text">
              <Shield className="w-3.5 h-3.5 text-ops-telemetry" />
              <span>Standby Guard</span>
            </span>
            <StatusBadge tone={standby?.enabled ? 'ok' : 'muted'} dot>
              {standby ? (standby.enabled ? 'Active' : 'Disabled') : '—'}
            </StatusBadge>
          </div>

          <div className="grid grid-cols-3 gap-2 text-xs font-mono">
            <div className="p-2 rounded bg-ops-surface border border-ops-border">
              <div className="text-[10px] text-ops-muted uppercase">Purges</div>
              <div className="num text-ops-text font-semibold mt-0.5">
                {standby ? standby.purges : '—'}
              </div>
            </div>
            <div className="p-2 rounded bg-ops-surface border border-ops-border">
              <div className="text-[10px] text-ops-muted uppercase">Reclaimed</div>
              <div className="num text-ops-telemetry font-semibold mt-0.5">
                {standby ? `${standby.reclaimed_gb.toFixed(2)} GB` : '—'}
              </div>
            </div>
            <div className="p-2 rounded bg-ops-surface border border-ops-border">
              <div className="text-[10px] text-ops-muted uppercase">Last Purge</div>
              <div className="num text-ops-secondary font-semibold mt-0.5 truncate">
                {standby?.last_purge || '—'}
              </div>
            </div>
          </div>

          {maintenance && (
            <div className="num text-[11px] font-mono text-ops-muted">
              Triggers: Avail &lt; {maintenance.standby_purge_min_available_gb} GB | Standby &gt;{' '}
              {maintenance.standby_purge_min_standby_gb} GB | Free &lt;{' '}
              {maintenance.standby_purge_min_free_gb} GB
            </div>
          )}

          <div className="pt-2 border-t border-ops-border flex flex-wrap items-center justify-between gap-2 text-xs font-mono">
            <div className="num text-ops-secondary">
              Boosts: <span className="text-ops-text font-semibold">{summary?.session_boosts ?? '—'}</span>{' '}
              session /{' '}
              <span className="text-ops-text font-semibold">{summary?.total_boosts ?? '—'}</span>{' '}
              total
            </div>
            <div className="flex items-center gap-1.5">
              <ConfirmButton
                compact
                tone="warn"
                label="Reset Session"
                confirmLabel="Confirm"
                onConfirm={onResetSessionBoosts}
              />
              <ConfirmButton
                compact
                tone="danger"
                label="Reset Total"
                confirmLabel="Purge"
                onConfirm={onResetTotalBoosts}
              />
            </div>
          </div>
        </div>
      </div>

      {/* Footer CTA */}
      <div className="space-y-2 pt-2 border-t border-ops-border">
        <div className="flex flex-wrap items-center justify-between gap-2 text-[11px] font-mono text-ops-muted">
          <span className="num">
            Last: <span className="text-ops-secondary">{autoBoost?.last_boost_time || '—'}</span>
          </span>
          <span className="num">
            Next: <span className="text-ops-secondary">{autoBoost?.next_boost?.text || '—'}</span>
          </span>
        </div>

        <button
          type="button"
          disabled={boosting}
          onClick={onBoostNow}
          className="ops-btn w-full h-10 px-4 bg-ops-accent hover:bg-blue-500 text-white text-xs font-semibold"
        >
          {boosting ? (
            <>
              <Loader2 className="w-4 h-4 animate-spin" />
              <span>Purging Standby & Working Sets...</span>
            </>
          ) : (
            <>
              <Zap className="w-4 h-4" />
              <span>Boost RAM Now</span>
            </>
          )}
        </button>
      </div>
    </OpsCard>
  );
};
