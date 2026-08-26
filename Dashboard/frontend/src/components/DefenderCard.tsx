import React, { useState } from 'react';
import { Shield, Search } from 'lucide-react';
import { useDashboardStore } from '../store/useDashboard';

interface DefenderCardProps {
  onQuickScan: () => void;
}

export const DefenderCard: React.FC<DefenderCardProps> = ({ onQuickScan }) => {
  const defender = useDashboardStore((s) => s.defender);
  const [scanning, setScanning] = useState(false);

  const handleScan = () => {
    setScanning(true);
    onQuickScan();
    setTimeout(() => setScanning(false), 2000);
  };

  const sigAge = defender?.signature_age_days ?? 0;
  const qScanAge = defender?.quick_scan_age_days ?? 0;
  const isRealtime = defender?.realtime_enabled ?? true;

  return (
    <div className="cyber-card p-4">
      {/* Header */}
      <div className="flex items-center justify-between mb-3">
        <span className="flex items-center gap-2 text-xs font-bold text-white uppercase tracking-wider">
          <Shield className="w-4 h-4 text-genesis-green" />
          Windows Defender Sentinel
        </span>
        <button
          onClick={handleScan}
          disabled={scanning}
          className="px-3 py-1 text-xs font-medium text-slate-300 bg-white/[0.04] hover:bg-white/[0.08] border border-white/10 rounded-md transition-all flex items-center gap-1.5"
        >
          <Search className={`w-3.5 h-3.5 ${scanning ? 'animate-spin text-genesis-green' : ''}`} />
          <span>{scanning ? 'Scanning...' : 'Quick Scan'}</span>
        </button>
      </div>

      {/* Grid: 2 cols on mobile, 4 cols on desktop */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-2 sm:gap-3">
        {/* 1. Signatures */}
        <div className="p-3 rounded-lg bg-white/[0.02] border border-white/[0.06] flex flex-col justify-between">
          <span className="text-[10px] uppercase font-bold text-slate-400">Signatures</span>
          <div className="mt-1">
            <span
              className={`font-mono text-sm font-bold ${
                sigAge > 3 ? 'text-genesis-amber' : 'text-genesis-green'
              }`}
            >
              {defender?.signature_display || (sigAge >= 0 ? `${sigAge}d ago` : '—')}
            </span>
          </div>
        </div>

        {/* 2. Last Quick Scan */}
        <div className="p-3 rounded-lg bg-white/[0.02] border border-white/[0.06] flex flex-col justify-between">
          <span className="text-[10px] uppercase font-bold text-slate-400">Last Quick Scan</span>
          <div className="mt-1">
            <span
              className={`font-mono text-sm font-bold ${
                qScanAge > 7 ? 'text-genesis-amber' : 'text-slate-200'
              }`}
            >
              {defender?.quick_scan_display || (qScanAge >= 0 ? `${qScanAge}d ago` : 'Never')}
            </span>
          </div>
        </div>

        {/* 3. Real-Time Protection */}
        <div className="p-3 rounded-lg bg-white/[0.02] border border-white/[0.06] flex flex-col justify-between">
          <span className="text-[10px] uppercase font-bold text-slate-400">Real-Time</span>
          <div className="mt-1">
            <span
              className={`font-mono text-sm font-bold ${
                isRealtime ? 'text-genesis-green' : 'text-genesis-accent'
              }`}
            >
              {isRealtime ? 'ON' : 'OFF'}
            </span>
          </div>
        </div>

        {/* 4. Downloads Sweep */}
        <div className="p-3 rounded-lg bg-white/[0.02] border border-white/[0.06] flex flex-col justify-between">
          <span className="text-[10px] uppercase font-bold text-slate-400">Downloads Sweep</span>
          <div className="mt-1">
            <span className="font-mono text-sm font-bold text-genesis-cyan">
              Auto (30m)
            </span>
          </div>
        </div>
      </div>
    </div>
  );
};
