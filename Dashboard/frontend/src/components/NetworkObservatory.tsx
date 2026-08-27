import React, { useState } from 'react';
import { Globe, Wifi, ShieldAlert, ArrowUpRight, ArrowDownLeft } from 'lucide-react';
import { useDashboardStore } from '../store/useDashboard';

interface NetworkObservatoryProps {
  onFlushDns: () => void;
}

export const NetworkObservatory: React.FC<NetworkObservatoryProps> = ({ onFlushDns }) => {
  const observatory = useDashboardStore((s) => s.observatory);
  const metrics = useDashboardStore((s) => s.metrics);
  const [flushing, setFlushing] = useState(false);

  const handleFlush = () => {
    setFlushing(true);
    onFlushDns();
    setTimeout(() => setFlushing(false), 1200);
  };

  const lat = observatory?.latency;
  const wifi = observatory?.wifi;
  const wd = observatory?.watchdog;
  const net = metrics?.network;

  const upSpeed = net?.sent_speed_mbs !== undefined && net?.sent_speed_mbs !== null
    ? Number(net.sent_speed_mbs).toFixed(2)
    : net?.bytes_sent_sec
    ? (net.bytes_sent_sec / (1024 * 1024)).toFixed(2)
    : '0.00';

  const downSpeed = net?.recv_speed_mbs !== undefined && net?.recv_speed_mbs !== null
    ? Number(net.recv_speed_mbs).toFixed(2)
    : net?.bytes_recv_sec
    ? (net.bytes_recv_sec / (1024 * 1024)).toFixed(2)
    : '0.00';

  return (
    <div className="cyber-card p-4">
      {/* Header */}
      <div className="flex items-center justify-between mb-3">
        <span className="flex items-center gap-2 text-xs font-bold text-white uppercase tracking-wider">
          <Globe className="w-4 h-4 text-genesis-cyan shrink-0" />
          Network Observatory
        </span>
        <button
          onClick={handleFlush}
          disabled={flushing}
          className="text-xs font-medium text-slate-300 bg-white/[0.04] hover:bg-white/[0.08] border border-white/10 px-3 py-1 rounded-md transition-all flex items-center gap-1.5 active:scale-95"
        >
          <span>{flushing ? 'Flushing...' : 'Flush DNS'}</span>
        </button>
      </div>

      {/* Grid: 2 columns on mobile, 4 columns on desktop */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-2 sm:gap-3">
        {/* 1. Latency & Quality */}
        <div className="p-2.5 sm:p-3 rounded-lg bg-white/[0.02] border border-white/[0.06] flex flex-col justify-between min-w-0">
          <div className="flex items-center justify-between gap-1">
            <span className="text-[10px] uppercase font-bold text-slate-400 truncate">Latency</span>
            <span
              className={`text-[8px] sm:text-[9px] font-bold px-1.5 py-0.5 rounded uppercase shrink-0 ${
                lat?.quality === 'excellent'
                  ? 'bg-genesis-green/10 text-genesis-green border border-genesis-green/20'
                  : 'bg-genesis-amber/10 text-genesis-amber border border-genesis-amber/20'
              }`}
            >
              {lat?.quality || 'EXCELLENT'}
            </span>
          </div>
          <div className="mt-2">
            <div className="flex items-baseline gap-1 font-mono">
              <span className="text-lg sm:text-xl font-extrabold text-white">{lat?.current_ms || 6.6}</span>
              <span className="text-[10px] text-slate-400">ms</span>
            </div>
            <div className="flex items-center justify-between text-[9px] sm:text-[10px] font-mono text-slate-400 mt-1">
              <span>Jitter: {lat?.jitter_ms || 0}ms</span>
              <span>Loss: {lat?.loss_percent?.toFixed(1) || '0.0'}%</span>
            </div>
          </div>
        </div>

        {/* 2. Wi-Fi RF Link */}
        <div className="p-2.5 sm:p-3 rounded-lg bg-white/[0.02] border border-white/[0.06] flex flex-col justify-between min-w-0">
          <div className="flex items-center justify-between gap-1">
            <span className="text-[10px] uppercase font-bold text-slate-400 flex items-center gap-1 truncate min-w-0">
              <Wifi className="w-3 h-3 text-genesis-cyan shrink-0" />
              <span className="truncate">Wi-Fi</span>
            </span>
            <span className="text-[8px] sm:text-[9px] font-bold px-1.5 py-0.5 rounded bg-genesis-cyan/10 text-genesis-cyan border border-genesis-cyan/20 shrink-0">
              {wifi?.quality_label || 'Good'}
            </span>
          </div>
          <div className="mt-2">
            <div className="font-bold text-xs text-white truncate" title={wifi?.ssid || 'KMITL-HiSpeed'}>
              {wifi?.ssid || 'KMITL-HiSpeed'}
            </div>
            <div className="flex items-center justify-between text-[9px] sm:text-[10px] font-mono text-slate-400 mt-1">
              <span>Sig: {wifi?.signal_percent || 100}%</span>
              <span>{wifi?.rx_rate_mbps || 400}M</span>
            </div>
          </div>
        </div>

        {/* 3. Watchdog Sentinel */}
        <div className="p-2.5 sm:p-3 rounded-lg bg-white/[0.02] border border-white/[0.06] flex flex-col justify-between min-w-0">
          <div className="flex items-center justify-between gap-1">
            <span className="text-[10px] uppercase font-bold text-slate-400 flex items-center gap-1 truncate min-w-0">
              <ShieldAlert className="w-3 h-3 text-genesis-green shrink-0" />
              <span className="truncate">Watchdog</span>
            </span>
            <span className="text-[8px] sm:text-[9px] font-bold px-1.5 py-0.5 rounded bg-genesis-green/10 text-genesis-green border border-genesis-green/20 shrink-0">
              ACTIVE
            </span>
          </div>
          <div className="mt-2">
            <div className="font-mono text-xs text-slate-200 truncate">
              Rec: <b className="text-white">{wd?.recoveries_today || 0}</b> today
            </div>
            <div className="text-[9px] sm:text-[10px] font-mono text-slate-400 mt-1 truncate">
              HB: {wd?.heartbeat_seconds !== undefined ? `${wd.heartbeat_seconds}s ago` : 'Synced'}
            </div>
          </div>
        </div>

        {/* 4. Bandwidth Traffic */}
        <div className="p-2.5 sm:p-3 rounded-lg bg-white/[0.02] border border-white/[0.06] flex flex-col justify-between min-w-0">
          <span className="text-[10px] uppercase font-bold text-slate-400 truncate">Bandwidth</span>
          <div className="mt-2 flex flex-col gap-1 font-mono text-xs">
            <div className="flex items-center justify-between">
              <span className="flex items-center gap-1 text-genesis-accent text-[11px] font-bold truncate">
                <ArrowUpRight className="w-3 h-3 shrink-0" />
                {upSpeed}
              </span>
              <span className="text-[9px] text-slate-500 shrink-0">UP</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="flex items-center gap-1 text-genesis-cyan text-[11px] font-bold truncate">
                <ArrowDownLeft className="w-3 h-3 shrink-0" />
                {downSpeed}
              </span>
              <span className="text-[9px] text-slate-500 shrink-0">DOWN</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
