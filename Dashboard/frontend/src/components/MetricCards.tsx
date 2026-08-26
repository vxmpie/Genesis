import React from 'react';
import { Cpu, MemoryStick, Flame, HardDrive } from 'lucide-react';
import { useDashboardStore } from '../store/useDashboard';

interface MetricRingProps {
  percent: number;
  label: string;
  sublabel?: string;
  valueDisplay: string | number;
  unit: string;
  colorClass: string;
  glowClass: string;
  icon: React.ReactNode;
  children?: React.ReactNode;
}

const MetricRing: React.FC<MetricRingProps> = ({
  percent,
  label,
  sublabel,
  valueDisplay,
  unit,
  colorClass,
  glowClass,
  icon,
  children,
}) => {
  const radius = 38;
  const circumference = 2 * Math.PI * radius; // ~238.76
  const offset = circumference - (Math.min(Math.max(percent, 0), 100) / 100) * circumference;

  return (
    <div className="cyber-card p-4 flex flex-col items-center justify-between min-h-[170px] group">
      {/* Top Header */}
      <div className="w-full flex items-center justify-between text-xs font-bold text-slate-400 uppercase tracking-wider">
        <span className="flex items-center gap-1.5">{icon} {label}</span>
        <span className="font-mono text-[11px] text-slate-500">{sublabel}</span>
      </div>

      {/* Center SVG Ring */}
      <div className="relative w-24 h-24 my-2">
        <svg className="w-full h-full -rotate-90" viewBox="0 0 96 96">
          {/* Background Ring */}
          <circle
            cx="48"
            cy="48"
            r={radius}
            className="fill-none stroke-white/[0.06]"
            strokeWidth="7"
          />
          {/* Active Fill Ring */}
          <circle
            cx="48"
            cy="48"
            r={radius}
            className={`fill-none ${colorClass} ${glowClass} transition-all duration-700 ease-out`}
            strokeWidth="7"
            strokeDasharray={circumference}
            strokeDashoffset={offset}
            strokeLinecap="round"
          />
        </svg>

        {/* Center Text Value */}
        <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
          <div className="flex items-baseline gap-0.5">
            <span className="font-mono text-xl sm:text-2xl font-extrabold text-white tracking-tight">
              {valueDisplay}
            </span>
            <span className="text-[10px] font-mono text-slate-400 font-bold">{unit}</span>
          </div>
        </div>
      </div>

      {/* Bottom Sub-stats or Breakdown */}
      {children}
    </div>
  );
};

export const MetricCards: React.FC = () => {
  const metrics = useDashboardStore((s) => s.metrics);

  const cpuPct = metrics?.cpu?.total_percent || 0;
  const cpuGhz = metrics?.cpu?.frequency_ghz;
  const cpuCount = metrics?.cpu?.count || 16;

  const ramPct = metrics?.ram?.percent || 0;
  const ramUsed = metrics?.ram?.used_gb || 0;
  const ramTotal = metrics?.ram?.total_gb || 32;
  const ramActive = metrics?.ram?.active_gb || 0;
  const ramStandby = metrics?.ram?.standby_gb || 0;
  const ramFree = metrics?.ram?.free_gb || 0;

  const gpuLoad = metrics?.gpu?.load_percent || 0;
  const gpuTemp = metrics?.gpu?.temperature_c || 0;
  const gpuName = metrics?.gpu?.name || 'NVIDIA GeForce RTX 3050';

  const diskRead = metrics?.disk?.read_mb_s || 0;
  const diskWrite = metrics?.disk?.write_mb_s || 0;
  const diskTotalSpeed = (diskRead + diskWrite).toFixed(1);

  return (
    <div className="grid grid-cols-2 lg:grid-cols-4 gap-2.5 sm:gap-4">
      {/* 1. CPU Metric Card */}
      <MetricRing
        percent={cpuPct}
        label="CPU"
        sublabel={`${cpuCount} Cores`}
        valueDisplay={Math.round(cpuPct)}
        unit="%"
        colorClass="stroke-genesis-accent"
        glowClass="glow-accent"
        icon={<Cpu className="w-3.5 h-3.5 text-genesis-accent" />}
      >
        <div className="w-full text-center text-[11px] font-mono text-slate-400">
          {cpuGhz ? `${cpuGhz.toFixed(1)} GHz` : `${cpuCount} Cores Active`}
        </div>
      </MetricRing>

      {/* 2. RAM Metric Card */}
      <MetricRing
        percent={ramPct}
        label="RAM"
        sublabel={`${ramUsed.toFixed(1)} / ${ramTotal.toFixed(0)} GB`}
        valueDisplay={Math.round(ramPct)}
        unit="%"
        colorClass="stroke-genesis-blue"
        glowClass="filter drop-shadow(0 0 8px rgba(59,130,246,0.4))"
        icon={<MemoryStick className="w-3.5 h-3.5 text-genesis-blue" />}
      >
        <div className="w-full flex flex-col gap-1 mt-1">
          {/* Active vs Standby Bar */}
          <div className="w-full h-1.5 bg-white/[0.08] rounded-full overflow-hidden flex">
            <div
              className="h-full bg-gradient-to-r from-genesis-accent to-orange-500 transition-all duration-500"
              style={{ width: `${(ramActive / ramTotal) * 100}%` }}
              title={`Active RAM: ${ramActive.toFixed(1)} GB`}
            />
            <div
              className="h-full bg-genesis-amber transition-all duration-500"
              style={{ width: `${(ramStandby / ramTotal) * 100}%` }}
              title={`Standby Cache: ${ramStandby.toFixed(1)} GB`}
            />
          </div>
          <div className="flex items-center justify-between text-[9px] font-mono text-slate-400">
            <span>Act: <b className="text-genesis-accent">{ramActive.toFixed(1)}G</b></span>
            <span>Stb: <b className="text-genesis-amber">{ramStandby.toFixed(1)}G</b></span>
            <span>Free: <b className="text-genesis-green">{ramFree.toFixed(1)}G</b></span>
          </div>
        </div>
      </MetricRing>

      {/* 3. GPU Metric Card */}
      <MetricRing
        percent={gpuTemp > 0 ? (gpuTemp / 100) * 100 : gpuLoad}
        label="GPU"
        sublabel={gpuTemp > 0 ? `${gpuTemp}°C` : `${gpuLoad}%`}
        valueDisplay={gpuTemp > 0 ? gpuTemp : gpuLoad}
        unit={gpuTemp > 0 ? "°C" : "%"}
        colorClass="stroke-genesis-purple"
        glowClass="filter drop-shadow(0 0 8px rgba(168,85,247,0.4))"
        icon={<Flame className="w-3.5 h-3.5 text-genesis-purple" />}
      >
        <div className="w-full text-center text-[10px] font-mono text-slate-400 truncate" title={gpuName}>
          {gpuName}
        </div>
      </MetricRing>

      {/* 4. DISK I/O Metric Card */}
      <MetricRing
        percent={Math.min((parseFloat(diskTotalSpeed) / 100) * 100, 100)}
        label="DISK I/O"
        sublabel="Real-time"
        valueDisplay={diskTotalSpeed}
        unit="MB/s"
        colorClass="stroke-genesis-green"
        glowClass="glow-green"
        icon={<HardDrive className="w-3.5 h-3.5 text-genesis-green" />}
      >
        <div className="w-full flex items-center justify-between text-[10px] font-mono text-slate-400">
          <span>R: <b className="text-slate-200">{diskRead.toFixed(1)}</b></span>
          <span>W: <b className="text-slate-200">{diskWrite.toFixed(1)}</b></span>
        </div>
      </MetricRing>
    </div>
  );
};
