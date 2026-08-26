import React, { useRef, useEffect } from 'react';
import { Activity } from 'lucide-react';
import { useDashboardStore } from '../store/useDashboard';

export const TelemetryChart: React.FC = () => {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const chartZoom = useDashboardStore((s) => s.chartZoom);
  const setChartZoom = useDashboardStore((s) => s.setChartZoom);
  const chartHistory = useDashboardStore((s) => s.chartHistory);

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
    const padTop = 14;
    const padBot = 26;
    const padLeft = 32;
    const padRight = 14;
    const plotW = Math.max(w - padLeft - padRight, 10);
    const plotH = Math.max(h - padTop - padBot, 10);

    ctx.fillStyle = '#0D0D14';
    ctx.fillRect(0, 0, w, h);

    const zoomMinutes = chartZoom || 30;
    const windowMs = zoomMinutes * 60 * 1000;
    const now = Date.now();
    const windowStart = now - windowMs;

    // 1. Horizontal Percentage Grid Lines (0%, 25%, 50%, 75%, 100%)
    ctx.strokeStyle = '#181824';
    ctx.lineWidth = 1;
    for (let i = 0; i <= 4; i++) {
      const y = padTop + (plotH / 4) * i;
      ctx.beginPath();
      ctx.moveTo(padLeft, y);
      ctx.lineTo(padLeft + plotW, y);
      ctx.stroke();

      ctx.fillStyle = '#55556A';
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
      ctx.strokeStyle = '#1A1A28';
      ctx.moveTo(x, padTop);
      ctx.lineTo(x, padTop + plotH);
      ctx.stroke();
      ctx.setLineDash([]);

      ctx.fillStyle = '#66667C';
      ctx.font = '10px "JetBrains Mono", monospace';
      ctx.textAlign = t === 0 ? 'left' : t === numTicks - 1 ? 'right' : 'center';
      ctx.fillText(timeStr, x, padTop + plotH + 16);
    }

    // Collect visible points in window
    const visiblePoints: any[] = [];
    const timestamps = chartHistory.timestamps || [];
    const cpuHistory = chartHistory.cpu || [];
    const ramHistory = chartHistory.ram || [];

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

    // Render Series Lines
    const drawSeries = (points: any[], yKey: string, color: string, glowColor: string) => {
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
    };

    drawSeries(visiblePoints, 'ramY', '#60A5FA', 'rgba(96,165,250,0.12)');
    drawSeries(visiblePoints, 'cpuY', '#FF3C3C', 'rgba(255,60,60,0.14)');
  }, [chartHistory, chartZoom]);

  return (
    <div className="cyber-card p-4">
      {/* Header with Zoom Controls */}
      <div className="flex flex-wrap items-center justify-between gap-2 mb-3">
        <span className="flex items-center gap-2 text-xs font-bold text-white uppercase tracking-wider">
          <Activity className="w-4 h-4 text-genesis-cyan" />
          Real-Time Telemetry <span className="text-[11px] font-normal text-slate-400 font-mono">Last {chartZoom} mins</span>
        </span>
        <div className="flex items-center gap-3 text-[11px] font-bold">
          <div className="flex items-center gap-3 font-mono">
            <span className="flex items-center gap-1 text-genesis-accent">
              <span className="w-2 h-2 rounded-full bg-genesis-accent" />
              CPU
            </span>
            <span className="flex items-center gap-1 text-genesis-blue">
              <span className="w-2 h-2 rounded-full bg-genesis-blue" />
              RAM
            </span>
          </div>
          {/* Zoom Buttons */}
          <div className="flex items-center gap-1 bg-black/40 border border-white/10 rounded p-0.5">
            {[5, 15, 30].map((m) => (
              <button
                key={m}
                onClick={() => setChartZoom(m as any)}
                className={`px-2 py-0.5 rounded text-[10px] font-mono font-bold transition-all ${
                  chartZoom === m
                    ? 'bg-genesis-cyan/20 text-genesis-cyan border border-genesis-cyan/30'
                    : 'text-slate-400 hover:text-white'
                }`}
              >
                {m}M
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Canvas */}
      <div className="w-full h-44 sm:h-52 rounded-lg overflow-hidden border border-white/[0.06] bg-[#0D0D14] relative">
        <canvas ref={canvasRef} className="w-full h-full block" />
      </div>
    </div>
  );
};
