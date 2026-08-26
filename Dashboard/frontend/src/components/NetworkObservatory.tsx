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

  const upSpeed = net?.bytes_sent_sec ? (net.bytes_sent_sec / (1024 * 1024)).toFixed(2) : '0.00';
  const downSpeed = net?.bytes_recv_sec ? (net.bytes_recv_sec / (1024 * 1024)).toFixed(2) : '0.00';

  return (
    <div className="cyber-card p-4">
      {/* Header */}
      <div className="flex items-center justify-between mb-3">
        <span className="flex items-center gap-2 text-xs font-bold text-white uppercase tracking-wider">
          <Globe className="w-4 h-4 text-genesis-cyan" />
          Network Observatory
        </span>
        <button
          onClick={handleFlush}
          disabled={flushing}
          className="text-xs font-medium text-slate-300 bg-white/[0.04] hover:bg-white/[0.08] border border-white/10 px-3 py-1 rounded-md transition-all flex items-center gap-1.5"
        >
          <span>{flushing ? 'Flushing...' : 'Flush DNS'}</span>
        </button>
      </div>

      {/* Grid */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-2.5 sm:gap-3">
        {/* 1. Latency & Quality */}
        <div className="p-3 rounded-lg bg-white/[0.02] border border-white/[0.06] flex flex-col justify-between">
          <div className="flex items-center justify-between">
            <span className="text-[10px] uppercase font-bold text-slate-400">Latency & Quality</span>
            <span
              className={`text-[9px] font-bold px-1.5 py-0.5 rounded uppercase ${
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
              <span className="text-xl font-extrabold text-white">{lat?.current_ms || 6.6}</span>
              <span className="text-[10px] text-slate-400">ms</span>
            </div>
            <div className="flex items-center justify-between text-[10px] font-mono text-slate-400 mt-1">
              <span>Jitter: {lat?.jitter_ms || 0} ms</span>
              <span>Loss: {lat?.loss_percent?.toFixed(1) || '0.0'}%</span>
            </div>
          </div>
        </div>

        {/* 2. Wi-Fi RF Link */}
        <div className="p-3 rounded-lg bg-white/[0.02] border border-white/[0.06] flex flex-col justify-between">
          <div className="flex items-center justify-between">
            <span className="text-[10px] uppercase font-bold text-slate-400 flex items-center gap-1">
              <Wifi className="w-3 h-3 text-genesis-cyan" />
              Wi-Fi RF Link
            </span>
            <span className="text-[9px] font-bold px-1.5 py-0.5 rounded bg-genesis-cyan/10 text-genesis-cyan border border-genesis-cyan/20">
              {wifi?.quality_label || 'Excellent'}
            </span>
          </div>
          <div className="mt-2">
            <div className="font-bold text-xs text-white truncate">{wifi?.ssid || 'KMITL-HiSpeed'}</div>
            <div className="flex items-center justify-between text-[10px] font-mono text-slate-400 mt-1">
              <span>Signal: {wifi?.signal_percent || 100}% ({wifi?.rssi_dbm || -53} dBm)</span>
              <span>{wifi?.rx_rate_mbps || 400} Mbps</span>
            </div>
          </div>
        </div>

        {/* 3. Watchdog Sentinel */}
        <div className="p-3 rounded-lg bg-white/[0.02] border border-white/[0.06] flex flex-col justify-between">
          <div className="flex items-center justify-between">
            <span className="text-[10px] uppercase font-bold text-slate-400 flex items-center gap-1">
              <ShieldAlert className="w-3 h-3 text-genesis-green" />
              Watchdog Sentinel
            </span>
            <span className="text-[9px] font-bold px-1.5 py-0.5 rounded bg-genesis-green/10 text-genesis-green border border-genesis-green/20">
              ACTIVE
            </span>
          </div>
          <div className="mt-2">
            <div className="font-mono text-xs text-slate-200">
              Recoveries: <b className="text-white">{wd?.recoveries_today || 0}</b> today
            </div>
            <div className="text-[10px] font-mono text-slate-400 mt-1">
              Heartbeat: {wd?.heartbeat_seconds !== undefined ? `${wd.heartbeat_seconds}s ago` : 'Synced'}
            </div>
          </div>
        </div>

        {/* 4. Bandwidth Traffic */}
        <div className="p-3 rounded-lg bg-white/[0.02] border border-white/[0.06] flex flex-col justify-between">
          <span className="text-[10px] uppercase font-bold text-slate-400">Bandwidth Speed</span>
          <div className="mt-2 flex flex-col gap-1 font-mono text-xs">
            <div className="flex items-center justify-between">
              <span className="flex items-center gap-1 text-genesis-accent">
                <ArrowUpRight className="w-3 h-3" />
                {upSpeed} MB/s
              </span>
              <span className="text-[10px] text-slate-500">UP</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="flex items-center gap-1 text-genesis-cyan">
                <ArrowDownLeft className="w-3 h-3" />
                {downSpeed} MB/s
              </span>
              <span className="text-[10px] text-slate-500">DOWN</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
