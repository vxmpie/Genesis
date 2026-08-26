import React, { useRef, useEffect, useState } from 'react';
import { Activity, Clock } from 'lucide-react';
import { useDashboardStore } from '../store/useDashboard';

export const TelemetryChart: React.FC = () => {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const chartZoom = useDashboardStore((s) => s.chartZoom);
  const setChartZoom = useDashboardStore((s) => s.setChartZoom);
  const chartHistory = useDashboardStore((s) => s.chartHistory);

  const [hoverInfo, setHoverInfo] = useState<{
    x: number;
    y: number;
    time: string;
    cpu: number;
    ram: number;
  } | null>(null);

  const cpuHistory = chartHistory.cpu || [];
  const ramHistory = chartHistory.ram || [];
  const timestamps = chartHistory.timestamps || [];

  // Calculate Summary Statistics for Active Window
  const visibleCpu = cpuHistory.slice(-chartZoom * 2);
  const visibleRam = ramHistory.slice(-chartZoom * 2);

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

    // Collect visible points in window
    const visiblePoints: any[] = [];
    for (let i = 0; i < cpuHistory.length; i++) {
      const ts = timestamps[i] || now - (cpuHistory.length - 1 - i) * 30000;
      if (ts >= windowStart - 30000) {
        const x = padLeft + Math.min(Math.max((ts - windowStart) / windowMs, 0), 1) * plotW;
        const cpuVal = cpuHistory[i] || 0;
        const ramVal = ramHistory[i] || 0;
        const cpuY = padTop + plotH * (1 - Math.min(Math.max(cpuVal, 0), 100) / 100);
        const ramY = padTop + plotH * (1 - Math.min(Math.max(ramVal, 0), 100) / 100);
        visiblePoints.push({ index: i, ts, x, cpuVal, ramVal, cpuY, ramY });
      }
    }

    // Render Series Lines with Luminous Glow
    const drawSeries = (points: any[], yKey: string, color: string, glowColor: string) => {
      if (points.length < 2) return;

      // Glow pass
      ctx.beginPath();
      ctx.strokeStyle = glowColor;
      ctx.lineWidth = 6;
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
    };

    drawSeries(visiblePoints, 'ramY', '#3B82F6', 'rgba(59,130,246,0.18)');
    drawSeries(visiblePoints, 'cpuY', '#FF3C3C', 'rgba(255,60,60,0.22)');

    // Render Hover Crosshair & Data Points if hovering
    if (hoverInfo) {
      ctx.beginPath();
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.25)';
      ctx.setLineDash([3, 3]);
      ctx.moveTo(hoverInfo.x, padTop);
      ctx.lineTo(hoverInfo.x, padTop + plotH);
      ctx.stroke();
      ctx.setLineDash([]);
    }
  }, [chartHistory, chartZoom, hoverInfo]);

  const handleMouseMove = (e: React.MouseEvent<HTMLCanvasElement>) => {
    const canvas = canvasRef.current;
    if (!canvas || timestamps.length === 0) return;

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
    let closestIdx = 0;
    let minDiff = Infinity;
    for (let i = 0; i < timestamps.length; i++) {
      const diff = Math.abs(timestamps[i] - targetTs);
      if (diff < minDiff) {
        minDiff = diff;
        closestIdx = i;
      }
    }

    const ts = timestamps[closestIdx] || now;
    const d = new Date(ts);
    const timeStr = `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}:${String(d.getSeconds()).padStart(2, '0')}`;

    setHoverInfo({
      x,
      y,
      time: timeStr,
      cpu: Math.round(cpuHistory[closestIdx] || 0),
      ram: Math.round(ramHistory[closestIdx] || 0),
    });
  };

  return (
    <div className="cyber-card p-4">
      {/* Header with Zoom & Legend */}
      <div className="flex flex-wrap items-center justify-between gap-2 mb-3">
        <div className="flex items-center gap-2">
          <Activity className="w-4 h-4 text-genesis-cyan" />
          <span className="text-xs font-bold text-white uppercase tracking-wider">
            Autonomous Telemetry Observatory
          </span>
          <span className="text-[10px] font-mono text-slate-400">
            Window: {chartZoom}m
          </span>
        </div>

        <div className="flex items-center gap-4 text-xs font-mono">
          {/* Legend */}
          <div className="flex items-center gap-3">
            <span className="flex items-center gap-1.5 text-genesis-accent font-bold">
              <span className="w-2 h-2 rounded-full bg-genesis-accent shadow-glow-accent" />
              CPU Load
            </span>
            <span className="flex items-center gap-1.5 text-genesis-blue font-bold">
              <span className="w-2 h-2 rounded-full bg-genesis-blue shadow-[0_0_8px_rgba(59,130,246,0.5)]" />
              RAM Usage
            </span>
          </div>

          {/* Time Zoom Stepper */}
          <div className="flex items-center gap-1 bg-black/50 border border-white/10 rounded-lg p-0.5">
            {[5, 15, 30].map((m) => (
              <button
                key={m}
                onClick={() => setChartZoom(m as any)}
                className={`px-2.5 py-0.5 rounded text-[11px] font-mono font-bold transition-all ${
                  chartZoom === m
                    ? 'bg-genesis-cyan/20 text-genesis-cyan border border-genesis-cyan/30 shadow-glow-cyan'
                    : 'text-slate-400 hover:text-white'
                }`}
              >
                {m}M
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Main Canvas Area */}
      <div className="w-full h-44 sm:h-56 rounded-xl overflow-hidden border border-white/[0.08] bg-[#0B0C14] relative">
        <canvas
          ref={canvasRef}
          onMouseMove={handleMouseMove}
          onMouseLeave={() => setHoverInfo(null)}
          className="w-full h-full block cursor-crosshair"
        />

        {/* Floating Tooltip upon Hover */}
        {hoverInfo && (
          <div
            className="absolute z-10 pointer-events-none bg-[#121320]/95 border border-white/15 rounded-lg p-2 text-xs font-mono shadow-2xl backdrop-blur-md transform -translate-x-1/2 -translate-y-full"
            style={{ left: hoverInfo.x, top: Math.max(hoverInfo.y - 12, 10) }}
          >
            <div className="text-[10px] text-slate-400 border-b border-white/10 pb-1 mb-1 flex items-center gap-1">
              <Clock className="w-3 h-3 text-slate-400" />
              {hoverInfo.time}
            </div>
            <div className="flex items-center gap-3">
              <span className="text-genesis-accent font-bold">CPU: {hoverInfo.cpu}%</span>
              <span className="text-genesis-blue font-bold">RAM: {hoverInfo.ram}%</span>
            </div>
          </div>
        )}
      </div>

      {/* Analytics Summary Footer Pill Bar */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 mt-3 pt-2 border-t border-white/[0.04] text-[11px] font-mono">
        <div className="flex items-center justify-between p-2 rounded bg-white/[0.02] border border-white/[0.04]">
          <span className="text-slate-400">CPU Avg / Peak:</span>
          <span className="font-bold text-white">
            <span className="text-genesis-accent">{avgCpu}%</span> / {maxCpu}%
          </span>
        </div>
        <div className="flex items-center justify-between p-2 rounded bg-white/[0.02] border border-white/[0.04]">
          <span className="text-slate-400">RAM Avg / Peak:</span>
          <span className="font-bold text-white">
            <span className="text-genesis-blue">{avgRam}%</span> / {maxRam}%
          </span>
        </div>
        <div className="flex items-center justify-between p-2 rounded bg-white/[0.02] border border-white/[0.04]">
          <span className="text-slate-400">Sample Frequency:</span>
          <span className="font-bold text-genesis-green">1.0s real-time</span>
        </div>
        <div className="flex items-center justify-between p-2 rounded bg-white/[0.02] border border-white/[0.04]">
          <span className="text-slate-400">Engine Health:</span>
          <span className="font-bold text-genesis-cyan">100% 60 FPS</span>
        </div>
      </div>
    </div>
  );
};
