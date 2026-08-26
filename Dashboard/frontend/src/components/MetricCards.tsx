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
    <div className="cyber-card p-4 flex flex-col items-center justify-between min-h-[185px] group hover:border-white/20 transition-all duration-300">
      {/* Top Header */}
      <div className="w-full flex items-center justify-between text-xs font-bold text-slate-400 uppercase tracking-wider">
        <span className="flex items-center gap-1.5">{icon} {label}</span>
        <span className="font-mono text-[11px] text-slate-500 bg-white/[0.03] px-1.5 py-0.5 rounded border border-white/[0.04]">{sublabel}</span>
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
  const gpuName = metrics?.gpu?.name || 'NVIDIA RTX 3050';

  const diskRead = metrics?.disk?.read_mb_s || 0;
  const diskWrite = metrics?.disk?.write_mb_s || 0;
  const diskTotalSpeed = (diskRead + diskWrite).toFixed(1);

  // Dynamic GPU Color & Glow
  let gpuColor = 'stroke-genesis-purple';
  let gpuGlow = 'filter drop-shadow(0 0 8px rgba(168,85,247,0.4))';
  let gpuIconColor = 'text-genesis-purple';
  if (gpuTemp >= 80) {
    gpuColor = 'stroke-red-500';
    gpuGlow = 'glow-accent';
    gpuIconColor = 'text-red-500';
  } else if (gpuTemp >= 70) {
    gpuColor = 'stroke-genesis-amber';
    gpuGlow = 'glow-amber';
    gpuIconColor = 'text-genesis-amber';
  }

  // Dynamic CPU Color
  const cpuColor = cpuPct > 85 ? 'stroke-red-500' : cpuPct > 65 ? 'stroke-genesis-amber' : 'stroke-genesis-accent';
  const cpuGlow = cpuPct > 85 ? 'glow-accent' : cpuPct > 65 ? 'glow-amber' : 'glow-accent';

  return (
    <div className="grid grid-cols-2 lg:grid-cols-4 gap-2.5 sm:gap-4">
      {/* 1. CPU Metric Card */}
      <MetricRing
        percent={cpuPct}
        label="CPU Load"
        sublabel={`${cpuCount} Cores`}
        valueDisplay={Math.round(cpuPct)}
        unit="%"
        colorClass={cpuColor}
        glowClass={cpuGlow}
        icon={<Cpu className="w-3.5 h-3.5 text-genesis-accent" />}
      >
        <div className="w-full text-center text-[11px] font-mono text-slate-300 font-semibold">
          {cpuGhz ? `${cpuGhz.toFixed(1)} GHz Frequency` : `${cpuCount} Cores Active`}
        </div>
      </MetricRing>

      {/* 2. RAM Metric Card */}
      <MetricRing
        percent={ramPct}
        label="RAM Capacity"
        sublabel={`${ramUsed.toFixed(1)} / ${ramTotal.toFixed(0)} GB`}
        valueDisplay={Math.round(ramPct)}
        unit="%"
        colorClass="stroke-genesis-blue"
        glowClass="filter drop-shadow(0 0 8px rgba(59,130,246,0.4))"
        icon={<MemoryStick className="w-3.5 h-3.5 text-genesis-blue" />}
      >
        <div className="w-full flex flex-col gap-1.5 mt-1">
          {/* Active vs Standby Segment Bar */}
          <div className="w-full h-2 bg-white/[0.08] rounded-full overflow-hidden flex border border-white/[0.06]">
            <div
              className="h-full bg-gradient-to-r from-red-500 to-genesis-accent transition-all duration-500"
              style={{ width: `${(ramActive / ramTotal) * 100}%` }}
              title={`Active Process RAM: ${ramActive.toFixed(1)} GB`}
            />
            <div
              className="h-full bg-genesis-amber transition-all duration-500"
              style={{ width: `${(ramStandby / ramTotal) * 100}%` }}
              title={`Standby Cache: ${ramStandby.toFixed(1)} GB`}
            />
          </div>
          <div className="flex items-center justify-between text-[9px] font-mono">
            <span>Act: <b className="text-genesis-accent font-bold">{ramActive.toFixed(1)}G</b></span>
            <span>Stb: <b className="text-genesis-amber font-bold">{ramStandby.toFixed(1)}G</b></span>
            <span>Free: <b className="text-genesis-green font-bold">{ramFree.toFixed(1)}G</b></span>
          </div>
        </div>
      </MetricRing>

      {/* 3. GPU Metric Card */}
      <MetricRing
        percent={gpuTemp > 0 ? (gpuTemp / 100) * 100 : gpuLoad}
        label="GPU Thermal"
        sublabel={gpuTemp > 0 ? `${gpuTemp}°C` : `${gpuLoad}%`}
        valueDisplay={gpuTemp > 0 ? gpuTemp : gpuLoad}
        unit={gpuTemp > 0 ? "°C" : "%"}
        colorClass={gpuColor}
        glowClass={gpuGlow}
        icon={<Flame className={`w-3.5 h-3.5 ${gpuIconColor}`} />}
      >
        <div className="w-full text-center text-[10px] font-mono text-slate-300 truncate font-semibold" title={gpuName}>
          {gpuName}
        </div>
      </MetricRing>

      {/* 4. DISK I/O Metric Card */}
      <MetricRing
        percent={Math.min((parseFloat(diskTotalSpeed) / 100) * 100, 100)}
        label="DISK I/O"
        sublabel="Throughput"
        valueDisplay={diskTotalSpeed}
        unit="MB/s"
        colorClass="stroke-genesis-green"
        glowClass="glow-green"
        icon={<HardDrive className="w-3.5 h-3.5 text-genesis-green" />}
      >
        <div className="w-full flex items-center justify-between text-[10px] font-mono text-slate-300 font-semibold">
          <span>Read: <b className="text-white">{diskRead.toFixed(1)}</b></span>
          <span>Write: <b className="text-white">{diskWrite.toFixed(1)}</b></span>
        </div>
      </MetricRing>
    </div>
  );
};
