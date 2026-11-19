import React from 'react';
import { Globe, Loader2, Send, ShieldCheck, Zap } from 'lucide-react';
import { useDashboardStore } from '../../store/useDashboard';

interface OverviewQuickActionsProps {
  onBoostNow: () => void;
  onCheckHardening: () => void;
  onFlushDns: () => void;
  onTestAlert: () => void;
}

export const OverviewQuickActions: React.FC<OverviewQuickActionsProps> = ({
  onBoostNow,
  onCheckHardening,
  onFlushDns,
  onTestAlert,
}) => {
  const autoBoost = useDashboardStore((s) => s.autoBoost);
  const summary = useDashboardStore((s) => s.summary);
  const timerRes = useDashboardStore((s) => s.timerResolution);
  const pcore = useDashboardStore((s) => s.pcoreAffinity);
  const tunnel = useDashboardStore((s) => s.tunnel);
  const isBoosting = useDashboardStore((s) => s.isBoosting);
  const isTestingAlert = useDashboardStore((s) => s.isTestingAlert);
  const setActiveView = useDashboardStore((s) => s.setActiveView);

  const standby = summary?.standby_guard;

  const tunnelBadge = !tunnel
    ? { label: '—', cls: 'text-ops-muted' }
    : tunnel.status === 'online'
    ? { label: `${tunnel.provider} online`, cls: 'text-ops-ok' }
    : tunnel.status === 'local_only'
    ? { label: 'local only', cls: 'text-ops-secondary' }
    : tunnel.status === 'offline'
    ? { label: 'offline', cls: 'text-ops-danger' }
    : { label: tunnel.status, cls: 'text-ops-warn' };

  return (
    <div className="ops-card p-4 flex flex-col justify-between gap-4 h-full">
      <div className="space-y-3">
        <div className="flex items-center justify-between gap-2">
          <h2 className="text-xs font-semibold text-ops-text uppercase tracking-wider whitespace-nowrap">
            Quick Operations
          </h2>
          <span className="num text-[11px] font-mono text-ops-muted whitespace-nowrap">
            {summary ? `${summary.session_boosts} sess / ${summary.total_boosts} tot` : '—'}
          </span>
        </div>

        {/* Primary CTA (Fitts's Law) */}
        <button
          type="button"
          onClick={onBoostNow}
          disabled={isBoosting}
          className="ops-btn w-full h-11 px-4 bg-ops-accent hover:bg-blue-500 text-white text-xs font-semibold"
        >
          {isBoosting ? (
            <>
              <Loader2 className="w-4 h-4 animate-spin" />
              <span>Trimming Processes & Standby...</span>
            </>
          ) : (
            <>
              <Zap className="w-4 h-4" />
              <span>Boost RAM Now</span>
            </>
          )}
        </button>

        <div className="flex items-center justify-between text-[11px] font-mono text-ops-muted px-0.5">
          <span className="num truncate">
            Last: <span className="text-ops-secondary">{autoBoost?.last_boost_time || '—'}</span>
          </span>
          <span className="num truncate">
            Next:{' '}
            <span className="text-ops-secondary">
              {autoBoost?.next_boost?.text || '—'}
            </span>
          </span>
        </div>

        {/* Secondary Actions */}
        <div className="grid grid-cols-3 gap-2">
          <button
            type="button"
            onClick={onCheckHardening}
            className="ops-btn h-9 px-1.5 gap-1 bg-ops-elevated hover:bg-ops-border border border-ops-border text-[11px] text-ops-text whitespace-nowrap"
            title="Run Windows Hardening Audit"
          >
            <ShieldCheck className="w-3.5 h-3.5 text-ops-ok shrink-0" />
            <span>Hardening</span>
          </button>

          <button
            type="button"
            onClick={onFlushDns}
            className="ops-btn h-9 px-1.5 gap-1 bg-ops-elevated hover:bg-ops-border border border-ops-border text-[11px] text-ops-text whitespace-nowrap"
            title="Flush Windows DNS Resolver Cache"
          >
            <Globe className="w-3.5 h-3.5 text-ops-telemetry shrink-0" />
            <span>Flush DNS</span>
          </button>

          <button
            type="button"
            onClick={onTestAlert}
            disabled={isTestingAlert}
            className="ops-btn h-9 px-1.5 gap-1 bg-ops-elevated hover:bg-ops-border border border-ops-border text-[11px] text-ops-text whitespace-nowrap"
            title="Send Test Discord Alert"
          >
            {isTestingAlert ? (
              <Loader2 className="w-3.5 h-3.5 animate-spin shrink-0" />
            ) : (
              <Send className="w-3.5 h-3.5 text-ops-accent shrink-0" />
            )}
            <span>Test Alert</span>
          </button>
        </div>
      </div>

      {/* Core Runtime Strip */}
      <div className="border-t border-ops-border pt-3 divide-y divide-ops-border text-xs">
        <div className="py-1.5 flex items-center justify-between gap-2">
          <span className="text-ops-secondary">Auto-Boost</span>
          <span className="num font-mono text-ops-text">
            {autoBoost
              ? autoBoost.enabled
                ? `Armed (${autoBoost.mode})`
                : 'Disarmed'
              : '—'}
          </span>
        </div>

        <div className="py-1.5 flex items-center justify-between gap-2">
          <span className="text-ops-secondary">Standby Guard</span>
          <span className="num font-mono text-ops-text">
            {standby
              ? `${standby.purges} purges / ${standby.reclaimed_gb.toFixed(2)} GB`
              : '—'}
          </span>
        </div>

        <div className="py-1.5 flex items-center justify-between gap-2">
          <span className="text-ops-secondary">Kernel Timer</span>
          <span className="num font-mono text-ops-text">
            {timerRes ? `${timerRes.resolution_ms} ms` : '—'}
          </span>
        </div>

        <div className="py-1.5 flex items-center justify-between gap-2">
          <span className="text-ops-secondary">P-Core Affinity</span>
          <span className="font-mono text-ops-text truncate max-w-[170px]" title={pcore?.mode}>
            {pcore?.mode || '—'}
          </span>
        </div>

        <div className="pt-1.5 flex items-center justify-between gap-2">
          <span className="text-ops-secondary">Public Tunnel</span>
          <button
            type="button"
            onClick={() => setActiveView('alerts')}
            className={`font-mono capitalize hover:underline ${tunnelBadge.cls}`}
          >
            {tunnelBadge.label}
          </button>
        </div>
      </div>
    </div>
  );
};
