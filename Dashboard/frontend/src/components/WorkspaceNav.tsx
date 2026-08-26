import React from 'react';
import { LayoutGrid, Gamepad2, Shield, Activity } from 'lucide-react';
import { useDashboardStore } from '../store/useDashboard';
import type { WorkspaceView } from '../types/dashboard';

export const WorkspaceNav: React.FC = () => {
  const activeView = useDashboardStore((s) => s.activeView);
  const setActiveView = useDashboardStore((s) => s.setActiveView);

  const tabs: { id: WorkspaceView; label: string; shortLabel: string; icon: React.ReactNode }[] = [
    {
      id: 'overview',
      label: 'Overview',
      shortLabel: 'Overview',
      icon: <LayoutGrid className="w-3.5 h-3.5 sm:w-4 sm:h-4 shrink-0" />,
    },
    {
      id: 'bots',
      label: 'MuMu & Bots',
      shortLabel: 'MuMu',
      icon: <Gamepad2 className="w-3.5 h-3.5 sm:w-4 sm:h-4 shrink-0" />,
    },
    {
      id: 'system',
      label: 'System & Security',
      shortLabel: 'Security',
      icon: <Shield className="w-3.5 h-3.5 sm:w-4 sm:h-4 shrink-0" />,
    },
    {
      id: 'analytics',
      label: 'Analytics & Logs',
      shortLabel: 'Analytics',
      icon: <Activity className="w-3.5 h-3.5 sm:w-4 sm:h-4 shrink-0" />,
    },
  ];

  return (
    <nav className="w-full sm:w-auto grid grid-cols-4 sm:flex items-center gap-1 sm:gap-1.5 p-1 bg-black/40 border border-white/[0.08] rounded-lg sm:rounded-xl backdrop-blur-md">
      {tabs.map((tab) => {
        const isActive = activeView === tab.id;
        return (
          <button
            key={tab.id}
            onClick={() => setActiveView(tab.id)}
            className={`btn-cyber flex items-center justify-center gap-1.5 px-2 py-1.5 sm:px-3 sm:py-1.5 rounded-md sm:rounded-lg text-xs font-semibold select-none ${
              isActive
                ? 'bg-gradient-to-r from-genesis-accent/25 to-orange-500/15 text-white border border-genesis-accent/40 shadow-glow-accent scale-[1.02]'
                : 'text-slate-400 hover:text-slate-200 hover:bg-white/[0.05] border border-transparent'
            }`}
          >
            <span className={isActive ? 'text-genesis-accent animate-pulse' : 'text-slate-400'}>{tab.icon}</span>
            <span className="hidden md:inline">{tab.label}</span>
            <span className="inline md:hidden text-[11px] truncate">{tab.shortLabel}</span>
          </button>
        );
      })}
    </nav>
  );
};
