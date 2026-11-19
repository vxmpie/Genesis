import React from 'react';
import { AlertTriangle, CheckCircle2, HelpCircle, RefreshCw, ShieldCheck, XCircle } from 'lucide-react';
import { useDashboardStore } from '../../store/useDashboard';
import { CardHeader, OpsCard, StatusBadge, type SemanticTone } from '../ui';

interface HardeningCardProps {
  onRefresh: () => void;
}

function getCheckMeta(status: string): {
  label: string;
  tone: SemanticTone;
  boxClass: string;
  icon: React.ReactNode;
} {
  switch (status) {
    case 'ok':
      return {
        label: 'Protected',
        tone: 'ok',
        boxClass: 'border-ops-ok/25 bg-ops-ok/[0.04]',
        icon: <CheckCircle2 className="w-4 h-4 text-ops-ok shrink-0" />,
      };
    case 'drift':
      return {
        label: 'Drift Detected',
        tone: 'warn',
        boxClass: 'border-ops-warn/35 bg-ops-warn/[0.06]',
        icon: <AlertTriangle className="w-4 h-4 text-ops-warn shrink-0" />,
      };
    case 'disabled':
      return {
        label: 'Disabled',
        tone: 'danger',
        boxClass: 'border-ops-danger/35 bg-ops-danger/[0.06]',
        icon: <XCircle className="w-4 h-4 text-ops-danger shrink-0" />,
      };
    default:
      return {
        label: 'Unknown',
        tone: 'muted',
        boxClass: 'border-ops-border bg-ops-inset',
        icon: <HelpCircle className="w-4 h-4 text-ops-muted shrink-0" />,
      };
  }
}

export const HardeningCard: React.FC<HardeningCardProps> = ({ onRefresh }) => {
  const hardening = useDashboardStore((s) => s.hardening);
  const refreshing = useDashboardStore((s) => Boolean(s.pendingOps['hardening']));

  const checks = [
    { key: 'vbs', name: 'VBS', desc: 'Virtualization Security', status: hardening?.checks?.vbs ?? 'unknown' },
    { key: 'mpo', name: 'MPO', desc: 'Multiplane Overlay', status: hardening?.checks?.mpo ?? 'unknown' },
    { key: 'hypervisor', name: 'Hypervisor', desc: 'Hyper-V Host Guard', status: hardening?.checks?.hypervisor ?? 'unknown' },
    {
      key: 'defender_exclusion',
      name: 'Defender Excl.',
      desc: 'MuMu Path Exclusion',
      status: hardening?.checks?.defender_exclusion ?? 'unknown',
    },
  ];

  const driftEntries = hardening?.drift ? Object.entries(hardening.drift) : [];

  return (
    <OpsCard className="flex flex-col gap-3">
      <div className="space-y-3">
        <CardHeader
          icon={<ShieldCheck className="w-4 h-4 text-ops-ok" />}
          title="Windows Hardening Drift"
          subtitle="Verifies VBS, MPO, Hypervisor, and Defender exclusion baseline."
          badge={
            hardening ? (
              <StatusBadge tone={hardening.has_drift ? 'warn' : 'ok'} dot>
                {hardening.has_drift ? 'Drift' : 'Compliant'}
              </StatusBadge>
            ) : (
              <StatusBadge tone="muted">Pending</StatusBadge>
            )
          }
          actions={
            <button
              type="button"
              disabled={refreshing}
              onClick={onRefresh}
              className="ops-btn h-8 px-2.5 bg-ops-elevated hover:bg-ops-border border border-ops-border text-xs text-ops-text"
            >
              <RefreshCw className={`w-3.5 h-3.5 ${refreshing ? 'animate-spin' : ''}`} />
              <span>{refreshing ? 'Checking...' : 'Refresh'}</span>
            </button>
          }
        />

        <div className="grid grid-cols-2 gap-2.5">
          {checks.map((item) => {
            const meta = getCheckMeta(item.status);
            return (
              <div
                key={item.key}
                className={`p-3 rounded-md border flex flex-col justify-between gap-2 ${meta.boxClass}`}
              >
                <div className="flex items-center justify-between gap-2">
                  <span className="text-xs font-semibold text-ops-text">{item.name}</span>
                  {meta.icon}
                </div>
                <div className="flex items-center justify-between gap-2">
                  <span className="text-[11px] text-ops-secondary truncate">{item.desc}</span>
                  <StatusBadge tone={meta.tone}>{meta.label}</StatusBadge>
                </div>
              </div>
            );
          })}
        </div>

        {hardening?.has_drift && driftEntries.length > 0 && (
          <div className="p-2.5 rounded-md bg-ops-warn/10 border border-ops-warn/30 space-y-1">
            <div className="text-[10px] font-mono uppercase tracking-wider text-ops-warn font-semibold">
              Detected Drift Items
            </div>
            <div className="space-y-1 text-xs">
              {driftEntries.map(([name, reason]) => (
                <div key={name} className="flex items-start justify-between gap-2 font-mono text-[11px]">
                  <span className="text-ops-text font-semibold shrink-0">{name}:</span>
                  <span className="text-ops-secondary text-right">{reason}</span>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>

      <div className="pt-2 border-t border-ops-border flex items-center justify-between text-[11px] font-mono text-ops-muted">
        <span>Baseline Audit</span>
        <span className="num text-ops-secondary">Last check: {hardening?.last_check || '—'}</span>
      </div>
    </OpsCard>
  );
};
