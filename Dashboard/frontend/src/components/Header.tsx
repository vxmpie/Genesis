import React from 'react';
import { Layers, Lock, Unlock, Zap } from 'lucide-react';
import { useDashboardStore } from '../store/useDashboard';
import { WorkspaceNav } from './WorkspaceNav';

interface HeaderProps {
  onOpenPalette: () => void;
  onOpenAuth: () => void;
}

export const Header: React.FC<HeaderProps> = ({ onOpenPalette, onOpenAuth }) => {
  const connected = useDashboardStore((s) => s.connected);
  const authenticated = useDashboardStore((s) => s.authenticated);
  const authRequired = useDashboardStore((s) => s.authRequired);
  const summary = useDashboardStore((s) => s.summary);

  const formatUptime = (sec: number) => {
    const d = Math.floor(sec / 86400);
    const h = Math.floor((sec % 86400) / 3600);
    const m = Math.floor((sec % 3600) / 60);
    const s = Math.floor(sec % 60);
    return `${d > 0 ? `${d}d ` : ''}${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  };

  const uptimeStr = formatUptime(summary?.uptime_seconds || 0);

  return (
    <header className="sticky top-0 z-40 bg-genesis-bg/95 border-b border-white/[0.08] backdrop-blur-xl px-4 py-2.5 sm:px-6 sm:py-3 transition-all duration-200">
      <div className="max-w-7xl mx-auto flex flex-wrap items-center justify-between gap-3 sm:gap-4">
        {/* Logo & Brand */}
        <div className="flex items-center gap-2.5 sm:gap-3.5 group cursor-pointer">
          <div className="w-8 h-8 sm:w-9 sm:h-9 rounded-lg bg-gradient-to-br from-genesis-accent to-orange-500 flex items-center justify-center text-white shadow-glow-accent ring-1 ring-white/20 animate-pulse-glow group-hover:scale-105 group-active:rotate-6 transition-transform">
            <Layers className="w-4 h-4 sm:w-5 sm:h-5 stroke-[2.5]" />
          </div>
          <div>
            <div className="flex items-center gap-1.5">
              <h1 className="font-extrabold text-sm sm:text-base tracking-wider text-white bg-gradient-to-r from-white via-slate-200 to-slate-400 bg-clip-text">
                GENESIS
              </h1>
            </div>
            <p className="hidden sm:block text-[11px] text-slate-400 font-medium tracking-tight">
              Autonomous Supervisor & Core Telemetry
            </p>
          </div>
        </div>

        {/* Workspace Navigation Tabs (Desktop Center / Mobile Full-Width Row) */}
        <div className="order-3 sm:order-2 w-full sm:w-auto">
          <WorkspaceNav />
        </div>

        {/* Status Indicators */}
        <div className="order-2 sm:order-3 flex items-center gap-2 sm:gap-3 ml-auto sm:ml-0">
          {/* Quick Hub Trigger */}
          <button
            onClick={onOpenPalette}
            className="btn-cyber hidden md:flex items-center gap-1.5 px-2.5 py-1 text-xs font-mono font-medium text-slate-300 bg-white/[0.04] hover:bg-white/[0.08] hover:text-white border border-white/[0.1] hover:border-genesis-cyan/40 rounded-md transition-all active:scale-90"
            title="Quick Command Palette (Ctrl+K)"
          >
            <Zap className="w-3.5 h-3.5 text-genesis-cyan animate-pulse" />
            <span>HUB</span>
            <kbd className="text-[10px] bg-black/40 px-1 py-0.5 rounded text-slate-400 border border-white/10">⌘K</kbd>
          </button>

          {/* Auth Status Badge */}
          {authRequired && (
            <button
              onClick={onOpenAuth}
              className={`btn-cyber flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold transition-all border active:scale-95 ${
                authenticated
                  ? 'bg-genesis-green/10 text-genesis-green border-genesis-green/30 shadow-glow-green hover:bg-genesis-green/20'
                  : 'bg-genesis-amber/10 text-genesis-amber border-genesis-amber/30 animate-pulse hover:bg-genesis-amber/20'
              }`}
            >
              {authenticated ? <Unlock className="w-3.5 h-3.5" /> : <Lock className="w-3.5 h-3.5" />}
              <span>{authenticated ? 'Unlocked' : 'Locked'}</span>
            </button>
          )}

          {/* Connection Status */}
          <div
            className={`flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium border bg-white/[0.02] ${
              connected
                ? 'text-genesis-green border-genesis-green/30'
                : 'text-genesis-accent border-genesis-accent/30'
            }`}
          >
            <span
              className={`w-2 h-2 rounded-full ${
                connected ? 'bg-genesis-green shadow-glow-green' : 'bg-genesis-accent animate-ping'
              }`}
            />
            <span className="font-mono text-[11px]">{connected ? 'Connected' : 'Offline'}</span>
          </div>

          {/* System Uptime */}
          <div className="font-mono text-xs text-slate-300 bg-white/[0.03] border border-white/[0.08] px-2.5 py-1 rounded-md hidden lg:block">
            {uptimeStr}
          </div>
        </div>
      </div>
    </header>
  );
};
