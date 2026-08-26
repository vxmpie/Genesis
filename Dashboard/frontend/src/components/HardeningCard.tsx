import React, { useState } from 'react';
import { ShieldCheck, RefreshCw, CheckCircle2, AlertTriangle, XCircle, HelpCircle } from 'lucide-react';
import { useDashboardStore } from '../store/useDashboard';

interface HardeningCardProps {
  onRefresh: () => void;
}

export const HardeningCard: React.FC<HardeningCardProps> = ({ onRefresh }) => {
  const hardening = useDashboardStore((s) => s.hardening);
  const [spinning, setSpinning] = useState(false);

  const handleRefresh = () => {
    setSpinning(true);
    onRefresh();
    setTimeout(() => setSpinning(false), 800);
  };

  const items = [
    { key: 'vbs', name: 'VBS', label: 'Virtualization-Based Security', status: hardening?.checks?.vbs || 'ok' },
    { key: 'mpo', name: 'MPO', label: 'Multiplane Overlay', status: hardening?.checks?.mpo || 'ok' },
    { key: 'hypervisor', name: 'Hypervisor', label: 'Hyper-V Host Guard', status: hardening?.checks?.hypervisor || 'ok' },
    { key: 'defender_exclusion', name: 'Defender Excl.', label: 'Process Exclusion', status: hardening?.checks?.defender_exclusion || 'ok' },
  ];

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'ok':
        return {
          icon: <CheckCircle2 className="w-5 h-5 text-genesis-green" />,
          text: 'Protected',
          borderClass: 'border-genesis-green/20 bg-genesis-green/[0.03]',
          textColor: 'text-genesis-green',
        };
      case 'drift':
        return {
          icon: <AlertTriangle className="w-5 h-5 text-genesis-amber animate-pulse" />,
          text: 'Drift Detected',
          borderClass: 'border-genesis-amber/40 bg-genesis-amber/[0.05]',
          textColor: 'text-genesis-amber font-bold',
        };
      case 'disabled':
        return {
          icon: <XCircle className="w-5 h-5 text-genesis-accent" />,
          text: 'Disabled',
          borderClass: 'border-genesis-accent/40 bg-genesis-accent/[0.05]',
          textColor: 'text-genesis-accent',
        };
      default:
        return {
          icon: <HelpCircle className="w-5 h-5 text-slate-500" />,
          text: 'Unknown',
          borderClass: 'border-white/[0.06] bg-white/[0.02]',
          textColor: 'text-slate-500',
        };
    }
  };

  return (
    <div className="cyber-card p-4">
      {/* Header */}
      <div className="flex items-center justify-between mb-3">
        <span className="flex items-center gap-2 text-xs font-bold text-white uppercase tracking-wider">
          <ShieldCheck className="w-4 h-4 text-genesis-green" />
          System Hardening
        </span>
        <button
          onClick={handleRefresh}
          className="p-1.5 rounded-full bg-white/[0.04] hover:bg-white/[0.1] text-slate-400 hover:text-white transition-all border border-white/10"
          title="Audit System Hardening"
        >
          <RefreshCw className={`w-3.5 h-3.5 ${spinning ? 'animate-spin text-genesis-cyan' : ''}`} />
        </button>
      </div>

      {/* Grid: 2 cols on mobile, 4 cols on desktop */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-2 sm:gap-3">
        {items.map((item) => {
          const badge = getStatusBadge(item.status);
          return (
            <div
              key={item.key}
              className={`p-3 rounded-lg border flex flex-col items-center justify-center text-center gap-1.5 transition-all hover:scale-[1.02] ${badge.borderClass}`}
            >
              {badge.icon}
              <span className="font-bold text-xs text-white">{item.name}</span>
              <span className={`font-mono text-[10px] ${badge.textColor}`}>{badge.text}</span>
            </div>
          );
        })}
      </div>

      {/* Last check footer */}
      <div className="mt-2.5 text-right font-mono text-[10px] text-slate-500">
        Last check: {hardening?.last_check || '2026-08-26 16:00:00'}
      </div>
    </div>
  );
};
