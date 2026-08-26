import React, { useRef, useEffect, useState } from 'react';
import { Activity, Clock } from 'lucide-react';
import { useDashboardStore } from '../store/useDashboard';

export const TelemetryChart: React.FC = () => {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const chartZoom = useDashboardStore((s) => s.chartZoom);
  const setChartZoom = useDashboardStore((s) => s.setChartZoom);
  const chartHistory = useDashboardStore((s) => s.chartHistory);
  const metrics = useDashboardStore((s) => s.metrics);

  const [hoverInfo, setHoverInfo] = useState<{
    x: number;
    y: number;
    time: string;
    cpu: number;
    ram: number;
  } | null>(null);

  const cpuHistory = chartHistory?.cpu || [];
  const ramHistory = chartHistory?.ram || [];
  const timestamps = chartHistory?.timestamps || [];

  // Summary Statistics
  const visibleCpu = cpuHistory.length > 0 ? cpuHistory.slice(-chartZoom * 2) : [metrics?.cpu?.total_percent || 0];
  const visibleRam = ramHistory.length > 0 ? ramHistory.slice(-chartZoom * 2) : [metrics?.ram?.percent || 0];

  const avgCpu = visibleCpu.length ? Math.round(visibleCpu.reduce((a, b) => a + b, 0) / visibleCpu.length) : 0;
  const maxCpu = visibleCpu.length ? Math.round(Math.max(...visibleCpu)) : 0;
  const avgRam = visibleRam.length ? Math.round(visibleRam.reduce((a, b) => a + b, 0) / visibleRam.length) : 0;
  const maxRam = visibleRam.length ? Math.round(Math.max(...visibleRam)) : 0;

  // 60 FPS Native Canvas Render Loop
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const dpr = window.devicePixelRatio || 1;
    const rect = canvas.getBoundingClientRect();

    canvas.width = rect.width * dpr;
    canvas.height = rect.height * dpr;
    ctx.scale(dpr, dpr);

    const w = rect.width;
    const h = rect.height;
    const padTop = 16;
    const padBot = 28;
    const padLeft = 36;
    const padRight = 16;
    const plotW = Math.max(w - padLeft - padRight, 10);
    const plotH = Math.max(h - padTop - padBot, 10);

    ctx.fillStyle = '#0B0C14';
    ctx.fillRect(0, 0, w, h);

    const zoomMinutes = chartZoom || 30;
    const windowMs = zoomMinutes * 60 * 1000;
    const now = Date.now();
    const windowStart = now - windowMs;

    // 1. Horizontal Percentage Grid Lines (0%, 25%, 50%, 75%, 100%)
    ctx.strokeStyle = '#181928';
    ctx.lineWidth = 1;
    for (let i = 0; i <= 4; i++) {
      const y = padTop + (plotH / 4) * i;
      ctx.beginPath();
      ctx.moveTo(padLeft, y);
      ctx.lineTo(padLeft + plotW, y);
      ctx.stroke();

      ctx.fillStyle = '#4E5168';
      ctx.font = '10px "JetBrains Mono", monospace';
      ctx.textAlign = 'right';
      ctx.fillText(`${100 - i * 25}%`, padLeft - 6, y + 3);
    }

    // 2. Vertical Time Grid Lines
    const numTicks = zoomMinutes === 5 ? 5 : 4;
    for (let t = 0; t < numTicks; t++) {
      const ratio = t / (numTicks - 1);
      const x = padLeft + plotW * ratio;
      const tickTimeMs = windowStart + ratio * windowMs;
      const dateObj = new Date(tickTimeMs);
      const hours = String(dateObj.getHours()).padStart(2, '0');
      const mins = String(dateObj.getMinutes()).padStart(2, '0');
      const timeStr = `${hours}:${mins}`;

      ctx.beginPath();
      ctx.setLineDash([2, 3]);
      ctx.strokeStyle = '#1A1C2C';
      ctx.moveTo(x, padTop);
      ctx.lineTo(x, padTop + plotH);
      ctx.stroke();
      ctx.setLineDash([]);

      ctx.fillStyle = '#646884';
      ctx.font = '10px "JetBrains Mono", monospace';
      ctx.textAlign = t === 0 ? 'left' : t === numTicks - 1 ? 'right' : 'center';
      ctx.fillText(timeStr, x, padTop + plotH + 16);
    }

    // 3. Prepare continuous plot points
    const currentCpu = metrics?.cpu?.total_percent || (cpuHistory[cpuHistory.length - 1] ?? 15);
    const currentRam = metrics?.ram?.percent || (ramHistory[ramHistory.length - 1] ?? 40);

    const rawPoints: Array<{ ts: number; cpu: number; ram: number }> = [];
    if (timestamps.length > 0) {
      for (let i = 0; i < timestamps.length; i++) {
        rawPoints.push({
          ts: timestamps[i],
          cpu: cpuHistory[i] !== undefined ? cpuHistory[i] : currentCpu,
          ram: ramHistory[i] !== undefined ? ramHistory[i] : currentRam,
        });
      }
    } else {
      rawPoints.push({ ts: now, cpu: currentCpu, ram: currentRam });
    }

    // Ensure latest point is current timestamp
    if (rawPoints.length === 0 || now - rawPoints[rawPoints.length - 1].ts > 1000) {
      rawPoints.push({ ts: now, cpu: currentCpu, ram: currentRam });
    }

    // Map to plot coordinates
    let plotPoints = rawPoints.map((p) => {
      const relX = Math.min(Math.max((p.ts - windowStart) / windowMs, 0), 1);
      const x = padLeft + relX * plotW;
      const cpuY = padTop + plotH * (1 - Math.min(Math.max(p.cpu, 0), 100) / 100);
      const ramY = padTop + plotH * (1 - Math.min(Math.max(p.ram, 0), 100) / 100);
      return { ts: p.ts, x, cpuVal: p.cpu, ramVal: p.ram, cpuY, ramY };
    });

    // Sort by X coordinate
    plotPoints.sort((a, b) => a.x - b.x);

    // If points are on the right half, extrapolate backwards to left boundary so the line is NEVER broken
    if (plotPoints.length > 0 && plotPoints[0].x > padLeft) {
      const first = plotPoints[0];
      plotPoints = [
        { ...first, x: padLeft, ts: windowStart },
        ...plotPoints,
      ];
    }

    // If only 1 point, clone to right edge
    if (plotPoints.length === 1) {
      plotPoints.push({ ...plotPoints[0], x: padLeft + plotW, ts: now });
    }

    // 4. Render Series Lines with Luminous Glow
    const drawSeries = (points: typeof plotPoints, yKey: 'ramY' | 'cpuY', color: string, glowColor: string) => {
      if (points.length < 2) return;

      // Glow pass
      ctx.beginPath();
      ctx.strokeStyle = glowColor;
      ctx.lineWidth = 5;
      ctx.lineJoin = 'round';
      points.forEach((p, idx) => {
        if (idx === 0) ctx.moveTo(p.x, p[yKey]);
        else ctx.lineTo(p.x, p[yKey]);
      });
      ctx.stroke();

      // Main line
      ctx.beginPath();
      ctx.strokeStyle = color;
      ctx.lineWidth = 2;
      ctx.lineJoin = 'round';
      points.forEach((p, idx) => {
        if (idx === 0) ctx.moveTo(p.x, p[yKey]);
        else ctx.lineTo(p.x, p[yKey]);
      });
      ctx.stroke();

      // Gradient under fill
      ctx.beginPath();
      points.forEach((p, idx) => {
        if (idx === 0) ctx.moveTo(p.x, p[yKey]);
        else ctx.lineTo(p.x, p[yKey]);
      });
      ctx.lineTo(points[points.length - 1].x, padTop + plotH);
      ctx.lineTo(points[0].x, padTop + plotH);
      ctx.closePath();

      const grad = ctx.createLinearGradient(0, padTop, 0, padTop + plotH);
      grad.addColorStop(0, glowColor);
      grad.addColorStop(1, 'transparent');
      ctx.fillStyle = grad;
      ctx.fill();

      // Current Value Pulsing Dot at rightmost end
      const last = points[points.length - 1];
      ctx.beginPath();
      ctx.arc(last.x, last[yKey], 3.5, 0, Math.PI * 2);
      ctx.fillStyle = color;
      ctx.fill();
    };

    drawSeries(plotPoints, 'ramY', '#3B82F6', 'rgba(59,130,246,0.22)');
    drawSeries(plotPoints, 'cpuY', '#FF3C3C', 'rgba(255,60,60,0.25)');

    // 5. Render Hover Crosshair & Points
    if (hoverInfo) {
      ctx.beginPath();
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.3)';
      ctx.setLineDash([3, 3]);
      ctx.moveTo(hoverInfo.x, padTop);
      ctx.lineTo(hoverInfo.x, padTop + plotH);
      ctx.stroke();
      ctx.setLineDash([]);

      const hoveredCpuY = padTop + plotH * (1 - Math.min(Math.max(hoverInfo.cpu, 0), 100) / 100);
      const hoveredRamY = padTop + plotH * (1 - Math.min(Math.max(hoverInfo.ram, 0), 100) / 100);

      // Dot for CPU
      ctx.beginPath();
      ctx.arc(hoverInfo.x, hoveredCpuY, 4, 0, Math.PI * 2);
      ctx.fillStyle = '#FF3C3C';
      ctx.fill();
      ctx.strokeStyle = '#FFFFFF';
      ctx.lineWidth = 1.5;
      ctx.stroke();

      // Dot for RAM
      ctx.beginPath();
      ctx.arc(hoverInfo.x, hoveredRamY, 4, 0, Math.PI * 2);
      ctx.fillStyle = '#3B82F6';
      ctx.fill();
      ctx.strokeStyle = '#FFFFFF';
      ctx.lineWidth = 1.5;
      ctx.stroke();
    }
  }, [chartHistory, chartZoom, hoverInfo, metrics]);

  const handleMouseMove = (e: React.MouseEvent<HTMLCanvasElement>) => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const rect = canvas.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;

    const padLeft = 36;
    const padRight = 16;
    const plotW = Math.max(rect.width - padLeft - padRight, 10);

    const relX = Math.min(Math.max((x - padLeft) / plotW, 0), 1);
    const zoomMinutes = chartZoom || 30;
    const windowMs = zoomMinutes * 60 * 1000;
    const now = Date.now();
    const targetTs = now - windowMs + relX * windowMs;

    // Find closest timestamp point
    let closestCpu = metrics?.cpu?.total_percent || 0;
    let closestRam = metrics?.ram?.percent || 0;

    if (timestamps.length > 0) {
      let minDiff = Infinity;
      for (let i = 0; i < timestamps.length; i++) {
        const diff = Math.abs(timestamps[i] - targetTs);
        if (diff < minDiff) {
          minDiff = diff;
          closestCpu = cpuHistory[i] !== undefined ? cpuHistory[i] : closestCpu;
          closestRam = ramHistory[i] !== undefined ? ramHistory[i] : closestRam;
        }
      }
    }

    const dateObj = new Date(targetTs);
    const hh = String(dateObj.getHours()).padStart(2, '0');
    const mm = String(dateObj.getMinutes()).padStart(2, '0');
    const ss = String(dateObj.getSeconds()).padStart(2, '0');

    setHoverInfo({
      x,
      y,
      time: `${hh}:${mm}:${ss}`,
      cpu: Math.round(closestCpu),
      ram: Math.round(closestRam),
    });
  };

  const handleMouseLeave = () => {
    setHoverInfo(null);
  };

  return (
    <div className="cyber-card p-4 flex flex-col justify-between relative">
      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-2 mb-3">
        <div className="flex items-center gap-2">
          <Activity className="w-4 h-4 text-genesis-cyan" />
          <span className="text-xs font-bold text-white uppercase tracking-wider">
            Autonomous Telemetry (Dual-Curve Stream)
          </span>
          <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-white/[0.04] text-slate-400 border border-white/[0.08]">
            60 FPS Canvas
          </span>
        </div>

        {/* Controls & Legend */}
        <div className="flex items-center gap-4">
          {/* Legend */}
          <div className="flex items-center gap-3 text-[11px] font-mono">
            <span className="flex items-center gap-1 text-genesis-accent font-bold">
              <span className="w-2.5 h-2.5 rounded-full bg-genesis-accent shadow-glow-accent" />
              CPU Load ({Math.round(metrics?.cpu?.total_percent || 0)}%)
            </span>
            <span className="flex items-center gap-1 text-genesis-blue font-bold">
              <span className="w-2.5 h-2.5 rounded-full bg-genesis-blue shadow-[0_0_8px_rgba(59,130,246,0.5)]" />
              RAM ({Math.round(metrics?.ram?.percent || 0)}%)
            </span>
          </div>

          {/* Timeframe Zoom Pills */}
          <div className="flex items-center bg-black/40 p-0.5 rounded-lg border border-white/[0.08] text-[10px] font-mono">
            {([5, 15, 30] as const).map((mins) => (
              <button
                key={mins}
                onClick={() => setChartZoom(mins)}
                className={`px-2.5 py-1 rounded transition-all font-bold ${
                  chartZoom === mins
                    ? 'bg-genesis-cyan/20 text-genesis-cyan border border-genesis-cyan/40 shadow-[0_0_8px_rgba(0,229,255,0.3)]'
                    : 'text-slate-400 hover:text-white'
                }`}
              >
                {mins}M
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Canvas Chart Area with Hover Crosshair Tooltip */}
      <div className="relative w-full h-56 bg-black/30 rounded-xl overflow-hidden border border-white/[0.06]">
        <canvas
          ref={canvasRef}
          onMouseMove={handleMouseMove}
          onMouseLeave={handleMouseLeave}
          className="w-full h-full cursor-crosshair block"
        />

        {/* Floating Tooltip during Hover */}
        {hoverInfo && (
          <div
            className="absolute pointer-events-none z-20 bg-slate-900/95 border border-white/20 backdrop-blur-md px-3 py-2 rounded-lg shadow-2xl flex flex-col gap-1 text-[11px] font-mono"
            style={{
              left: `${Math.min(Math.max(hoverInfo.x - 60, 10), (canvasRef.current?.getBoundingClientRect().width || 300) - 130)}px`,
              top: '12px',
            }}
          >
            <div className="flex items-center gap-1 text-slate-400 text-[10px] border-b border-white/10 pb-1">
              <Clock className="w-3 h-3 text-slate-400" />
              <span>{hoverInfo.time}</span>
            </div>
            <div className="flex items-center justify-between gap-3">
              <span className="text-genesis-accent font-bold">CPU:</span>
              <span className="text-white font-extrabold">{hoverInfo.cpu}%</span>
            </div>
            <div className="flex items-center justify-between gap-3">
              <span className="text-genesis-blue font-bold">RAM:</span>
              <span className="text-white font-extrabold">{hoverInfo.ram}%</span>
            </div>
          </div>
        )}
      </div>

      {/* Summary Analytics Footer Bar */}
      <div className="mt-3 pt-2 border-t border-white/[0.04] grid grid-cols-2 sm:grid-cols-4 gap-2 text-center text-xs font-mono">
        <div className="bg-white/[0.02] p-1.5 rounded border border-white/[0.04]">
          <span className="text-[10px] text-slate-500 uppercase block">CPU Window Avg</span>
          <span className="font-extrabold text-genesis-accent">{avgCpu}%</span>
        </div>
        <div className="bg-white/[0.02] p-1.5 rounded border border-white/[0.04]">
          <span className="text-[10px] text-slate-500 uppercase block">CPU Peak</span>
          <span className="font-extrabold text-red-400">{maxCpu}%</span>
        </div>
        <div className="bg-white/[0.02] p-1.5 rounded border border-white/[0.04]">
          <span className="text-[10px] text-slate-500 uppercase block">RAM Window Avg</span>
          <span className="font-extrabold text-genesis-blue">{avgRam}%</span>
        </div>
        <div className="bg-white/[0.02] p-1.5 rounded border border-white/[0.04]">
          <span className="text-[10px] text-slate-500 uppercase block">RAM Peak</span>
          <span className="font-extrabold text-blue-400">{maxRam}%</span>
        </div>
      </div>
    </div>
  );
};
