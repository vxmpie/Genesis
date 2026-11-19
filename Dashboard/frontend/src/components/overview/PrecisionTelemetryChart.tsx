import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Activity, Clock } from 'lucide-react';
import { useDashboardStore } from '../../store/useDashboard';
import { formatPercent } from '../../lib/format';

interface HoverPoint {
  x: number;
  tooltipLeft: number;
  time: string;
  cpu: number;
  ram: number;
}

interface PrecisionTelemetryChartProps {
  tall?: boolean;
}

export const PrecisionTelemetryChart: React.FC<PrecisionTelemetryChartProps> = ({
  tall = false,
}) => {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const containerRef = useRef<HTMLDivElement | null>(null);

  const chartZoom = useDashboardStore((s) => s.chartZoom);
  const setChartZoom = useDashboardStore((s) => s.setChartZoom);
  const chartHistory = useDashboardStore((s) => s.chartHistory);
  const metrics = useDashboardStore((s) => s.metrics);
  const connectionState = useDashboardStore((s) => s.connectionState);
  const lastMessageAt = useDashboardStore((s) => s.lastMessageAt);

  const [hoverInfo, setHoverInfo] = useState<HoverPoint | null>(null);

  // --- Window-Filtered Series Stats ---
  const windowStats = useMemo(() => {
    const timestamps = chartHistory.timestamps;
    const cpu = chartHistory.cpu;
    const ram = chartHistory.ram;

    if (timestamps.length === 0) {
      return {
        points: [] as Array<{ ts: number; cpu: number; ram: number }>,
        anchor: null as number | null,
        avgCpu: null as number | null,
        maxCpu: null as number | null,
        avgRam: null as number | null,
        maxRam: null as number | null,
      };
    }

    const latestTs = timestamps[timestamps.length - 1];
    const anchor = lastMessageAt ? Math.max(latestTs, lastMessageAt) : latestTs;
    const cutoff = anchor - chartZoom * 60_000;

    const points: Array<{ ts: number; cpu: number; ram: number }> = [];
    for (let i = 0; i < timestamps.length; i += 1) {
      const ts = timestamps[i];
      if (ts >= cutoff) {
        points.push({
          ts,
          cpu: cpu[i] ?? 0,
          ram: ram[i] ?? 0,
        });
      }
    }

    if (points.length === 0) {
      return {
        points,
        anchor,
        avgCpu: null as number | null,
        maxCpu: null as number | null,
        avgRam: null as number | null,
        maxRam: null as number | null,
      };
    }

    let sumCpu = 0;
    let peakCpu = 0;
    let sumRam = 0;
    let peakRam = 0;

    for (const pt of points) {
      sumCpu += pt.cpu;
      sumRam += pt.ram;
      if (pt.cpu > peakCpu) peakCpu = pt.cpu;
      if (pt.ram > peakRam) peakRam = pt.ram;
    }

    return {
      points,
      anchor,
      avgCpu: Math.round(sumCpu / points.length),
      maxCpu: Math.round(peakCpu),
      avgRam: Math.round(sumRam / points.length),
      maxRam: Math.round(peakRam),
    };
  }, [chartHistory, chartZoom, lastMessageAt]);

  // --- High-DPI Resize Observer ---
  useEffect(() => {
    const container = containerRef.current;
    const canvas = canvasRef.current;
    if (!container || !canvas) return;

    const observer = new ResizeObserver((entries) => {
      for (const entry of entries) {
        const { width, height } = entry.contentRect;
        if (width > 0 && height > 0) {
          const dpr = window.devicePixelRatio || 1;
          canvas.width = Math.round(width * dpr);
          canvas.height = Math.round(height * dpr);
        }
      }
    });

    observer.observe(container);
    return () => observer.disconnect();
  }, []);

  // --- Canvas Render ---
  useEffect(() => {
    const canvas = canvasRef.current;
    const container = containerRef.current;
    if (!canvas || !container) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const dpr = window.devicePixelRatio || 1;
    const rect = container.getBoundingClientRect();
    const w = rect.width;
    const h = rect.height;
    if (w === 0 || h === 0) return;

    if (canvas.width !== Math.round(w * dpr) || canvas.height !== Math.round(h * dpr)) {
      canvas.width = Math.round(w * dpr);
      canvas.height = Math.round(h * dpr);
    }

    ctx.save();
    ctx.scale(dpr, dpr);

    const padTop = 14;
    const padBot = 26;
    const padLeft = 36;
    const padRight = 12;
    const plotW = Math.max(w - padLeft - padRight, 10);
    const plotH = Math.max(h - padTop - padBot, 10);

    ctx.fillStyle = '#0B0B0E';
    ctx.fillRect(0, 0, w, h);

    const windowMs = chartZoom * 60_000;
    const windowEnd = windowStats.anchor ?? Date.now();
    const windowStart = windowEnd - windowMs;

    ctx.strokeStyle = '#1C1C24';
    ctx.lineWidth = 1;
    for (let i = 0; i <= 4; i += 1) {
      const y = Math.round(padTop + (plotH / 4) * i) + 0.5;
      ctx.beginPath();
      ctx.moveTo(padLeft, y);
      ctx.lineTo(padLeft + plotW, y);
      ctx.stroke();

      ctx.fillStyle = '#71717A';
      ctx.font = '10px "JetBrains Mono", monospace';
      ctx.textAlign = 'right';
      ctx.fillText(`${100 - i * 25}%`, padLeft - 6, y + 3);
    }

    const numTicks = chartZoom === 5 ? 5 : 4;
    for (let t = 0; t < numTicks; t += 1) {
      const ratio = t / (numTicks - 1);
      const x = padLeft + plotW * ratio;
      const tickDate = new Date(windowStart + ratio * windowMs);
      const timeLabel = `${String(tickDate.getHours()).padStart(2, '0')}:${String(
        tickDate.getMinutes()
      ).padStart(2, '0')}`;

      ctx.beginPath();
      ctx.setLineDash([2, 3]);
      ctx.strokeStyle = '#1C1C24';
      ctx.moveTo(x, padTop);
      ctx.lineTo(x, padTop + plotH);
      ctx.stroke();
      ctx.setLineDash([]);

      ctx.fillStyle = '#71717A';
      ctx.font = '10px "JetBrains Mono", monospace';
      ctx.textAlign = t === 0 ? 'left' : t === numTicks - 1 ? 'right' : 'center';
      ctx.fillText(timeLabel, x, padTop + plotH + 16);
    }

    const plotPoints = windowStats.points.map((pt) => {
      const relX = Math.min(Math.max((pt.ts - windowStart) / windowMs, 0), 1);
      const x = padLeft + relX * plotW;
      const cpuY = padTop + plotH * (1 - Math.min(Math.max(pt.cpu, 0), 100) / 100);
      const ramY = padTop + plotH * (1 - Math.min(Math.max(pt.ram, 0), 100) / 100);
      return { x, cpuY, ramY };
    });

    const drawSeries = (yKey: 'ramY' | 'cpuY', lineColor: string, fillTop: string) => {
      if (plotPoints.length === 0) return;

      if (plotPoints.length === 1) {
        const pt = plotPoints[0];
        ctx.beginPath();
        ctx.arc(pt.x, pt[yKey], 3, 0, Math.PI * 2);
        ctx.fillStyle = lineColor;
        ctx.fill();
        return;
      }

      ctx.beginPath();
      plotPoints.forEach((pt, idx) => {
        if (idx === 0) ctx.moveTo(pt.x, pt[yKey]);
        else ctx.lineTo(pt.x, pt[yKey]);
      });
      ctx.lineTo(plotPoints[plotPoints.length - 1].x, padTop + plotH);
      ctx.lineTo(plotPoints[0].x, padTop + plotH);
      ctx.closePath();

      const grad = ctx.createLinearGradient(0, padTop, 0, padTop + plotH);
      grad.addColorStop(0, fillTop);
      grad.addColorStop(1, 'rgba(0, 0, 0, 0)');
      ctx.fillStyle = grad;
      ctx.fill();

      ctx.beginPath();
      ctx.strokeStyle = lineColor;
      ctx.lineWidth = 2;
      ctx.lineJoin = 'round';
      plotPoints.forEach((pt, idx) => {
        if (idx === 0) ctx.moveTo(pt.x, pt[yKey]);
        else ctx.lineTo(pt.x, pt[yKey]);
      });
      ctx.stroke();

      const last = plotPoints[plotPoints.length - 1];
      ctx.beginPath();
      ctx.arc(last.x, last[yKey], 3, 0, Math.PI * 2);
      ctx.fillStyle = lineColor;
      ctx.fill();
    };

    drawSeries('ramY', '#3B82F6', 'rgba(59, 130, 246, 0.14)');
    drawSeries('cpuY', '#06B6D4', 'rgba(6, 182, 212, 0.14)');

    if (hoverInfo && plotPoints.length > 0) {
      ctx.beginPath();
      ctx.strokeStyle = 'rgba(244, 244, 245, 0.25)';
      ctx.setLineDash([3, 3]);
      ctx.moveTo(hoverInfo.x, padTop);
      ctx.lineTo(hoverInfo.x, padTop + plotH);
      ctx.stroke();
      ctx.setLineDash([]);

      const cpuY = padTop + plotH * (1 - Math.min(Math.max(hoverInfo.cpu, 0), 100) / 100);
      const ramY = padTop + plotH * (1 - Math.min(Math.max(hoverInfo.ram, 0), 100) / 100);

      [
        { y: cpuY, color: '#06B6D4' },
        { y: ramY, color: '#3B82F6' },
      ].forEach(({ y, color }) => {
        ctx.beginPath();
        ctx.arc(hoverInfo.x, y, 3.5, 0, Math.PI * 2);
        ctx.fillStyle = color;
        ctx.fill();
        ctx.strokeStyle = '#F4F4F5';
        ctx.lineWidth = 1.5;
        ctx.stroke();
      });
    }

    ctx.restore();
  }, [chartZoom, hoverInfo, windowStats]);

  // --- Hover Interaction ---
  const calculateHover = useCallback(
    (clientX: number) => {
      const container = containerRef.current;
      if (!container || windowStats.points.length === 0) return;

      const rect = container.getBoundingClientRect();
      const x = clientX - rect.left;
      const padLeft = 36;
      const padRight = 12;
      const plotW = Math.max(rect.width - padLeft - padRight, 10);

      const relX = Math.min(Math.max((x - padLeft) / plotW, 0), 1);
      const windowMs = chartZoom * 60_000;
      const windowEnd = windowStats.anchor ?? windowStats.points[windowStats.points.length - 1].ts;
      const targetTs = windowEnd - windowMs + relX * windowMs;

      let closest = windowStats.points[0];
      let minDiff = Math.abs(closest.ts - targetTs);
      for (let i = 1; i < windowStats.points.length; i += 1) {
        const pt = windowStats.points[i];
        const diff = Math.abs(pt.ts - targetTs);
        if (diff < minDiff) {
          minDiff = diff;
          closest = pt;
        }
      }

      const d = new Date(closest.ts);
      const timeStr = `${String(d.getHours()).padStart(2, '0')}:${String(
        d.getMinutes()
      ).padStart(2, '0')}:${String(d.getSeconds()).padStart(2, '0')}`;

      setHoverInfo({
        x: Math.min(Math.max(x, padLeft), padLeft + plotW),
        tooltipLeft: Math.min(Math.max(x - 64, 8), Math.max(8, rect.width - 140)),
        time: timeStr,
        cpu: Math.round(closest.cpu),
        ram: Math.round(closest.ram),
      });
    },
    [chartZoom, windowStats.anchor, windowStats.points]
  );

  const liveBadge =
    connectionState === 'connected'
      ? { dot: 'bg-ops-ok', label: '1s live', cls: 'text-ops-ok border-ops-ok/30 bg-ops-ok/10' }
      : connectionState === 'reconnecting' || connectionState === 'connecting'
      ? { dot: 'bg-ops-warn', label: 'Reconnecting', cls: 'text-ops-warn border-ops-warn/30 bg-ops-warn/10' }
      : { dot: 'bg-ops-muted', label: 'Offline', cls: 'text-ops-muted border-ops-border bg-ops-inset' };

  return (
    <div className="ops-card p-4 flex flex-col justify-between gap-3 h-full">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2.5">
        <div className="flex items-center gap-2 min-w-0">
          <Activity className="w-4 h-4 text-ops-telemetry shrink-0" />
          <h2 className="text-xs font-semibold text-ops-text uppercase tracking-wider truncate">
            System Telemetry
          </h2>
          <span
            className={`inline-flex items-center gap-1.5 text-[10px] font-mono px-1.5 py-0.5 rounded border shrink-0 ${liveBadge.cls}`}
          >
            <span className={`w-1.5 h-1.5 rounded-full ${liveBadge.dot}`} />
            <span>{liveBadge.label}</span>
          </span>
        </div>

        <div className="flex items-center justify-between sm:justify-end gap-3 flex-wrap">
          <div className="flex items-center gap-3 text-[11px] font-mono">
            <span className="num flex items-center gap-1.5 text-ops-text">
              <span className="w-2 h-2 rounded-full bg-ops-telemetry" />
              CPU {formatPercent(metrics?.cpu.total_percent)}
            </span>
            <span className="num flex items-center gap-1.5 text-ops-text">
              <span className="w-2 h-2 rounded-full bg-ops-accent" />
              RAM {formatPercent(metrics?.ram.percent)}
            </span>
          </div>

          <div className="flex items-center bg-ops-inset p-0.5 rounded-md border border-ops-border text-[11px] font-mono">
            {([5, 15, 30] as const).map((mins) => (
              <button
                key={mins}
                type="button"
                onClick={() => setChartZoom(mins)}
                className={`px-2 py-0.5 rounded transition-colors ${
                  chartZoom === mins
                    ? 'bg-ops-elevated text-ops-text border border-ops-borderStrong'
                    : 'text-ops-muted hover:text-ops-text border border-transparent'
                }`}
              >
                {mins}M
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Canvas Container */}
      <div
        ref={containerRef}
        className={`relative w-full ${
          tall ? 'h-72 sm:h-80' : 'h-56 sm:h-60'
        } bg-ops-inset rounded-md overflow-hidden border border-ops-border touch-none`}
      >
        <canvas
          ref={canvasRef}
          onMouseMove={(e) => calculateHover(e.clientX)}
          onMouseLeave={() => setHoverInfo(null)}
          onTouchStart={(e) => {
            if (e.touches[0]) calculateHover(e.touches[0].clientX);
          }}
          onTouchMove={(e) => {
            if (e.touches[0]) calculateHover(e.touches[0].clientX);
          }}
          onTouchEnd={() => setHoverInfo(null)}
          className="w-full h-full cursor-crosshair block"
        />

        {windowStats.points.length === 0 && (
          <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
            <span className="text-xs font-mono text-ops-muted bg-ops-surface/90 border border-ops-border px-3 py-1.5 rounded-md">
              Waiting for telemetry samples...
            </span>
          </div>
        )}

        {hoverInfo && (
          <div
            className="absolute pointer-events-none z-10 bg-ops-surface border border-ops-borderStrong px-2.5 py-1.5 rounded-md shadow-lg flex flex-col gap-1 text-[11px] font-mono"
            style={{ left: `${hoverInfo.tooltipLeft}px`, top: '10px' }}
          >
            <div className="flex items-center gap-1 text-ops-muted text-[10px] border-b border-ops-border pb-1">
              <Clock className="w-3 h-3 shrink-0" />
              <span className="num">{hoverInfo.time}</span>
            </div>
            <div className="flex items-center justify-between gap-3">
              <span className="text-ops-telemetry">CPU</span>
              <span className="num text-ops-text font-semibold">{hoverInfo.cpu}%</span>
            </div>
            <div className="flex items-center justify-between gap-3">
              <span className="text-ops-accent">RAM</span>
              <span className="num text-ops-text font-semibold">{hoverInfo.ram}%</span>
            </div>
          </div>
        )}
      </div>

      {/* Footer Window Stats */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 text-xs font-mono">
        <div className="bg-ops-inset border border-ops-border rounded-md px-2.5 py-1.5 flex items-center justify-between">
          <span className="text-[10px] text-ops-muted uppercase">CPU Avg</span>
          <span className="num text-ops-telemetry font-semibold">
            {formatPercent(windowStats.avgCpu)}
          </span>
        </div>
        <div className="bg-ops-inset border border-ops-border rounded-md px-2.5 py-1.5 flex items-center justify-between">
          <span className="text-[10px] text-ops-muted uppercase">CPU Peak</span>
          <span className="num text-ops-text font-semibold">
            {formatPercent(windowStats.maxCpu)}
          </span>
        </div>
        <div className="bg-ops-inset border border-ops-border rounded-md px-2.5 py-1.5 flex items-center justify-between">
          <span className="text-[10px] text-ops-muted uppercase">RAM Avg</span>
          <span className="num text-ops-accent font-semibold">
            {formatPercent(windowStats.avgRam)}
          </span>
        </div>
        <div className="bg-ops-inset border border-ops-border rounded-md px-2.5 py-1.5 flex items-center justify-between">
          <span className="text-[10px] text-ops-muted uppercase">RAM Peak</span>
          <span className="num text-ops-text font-semibold">
            {formatPercent(windowStats.maxRam)}
          </span>
        </div>
      </div>
    </div>
  );
};
