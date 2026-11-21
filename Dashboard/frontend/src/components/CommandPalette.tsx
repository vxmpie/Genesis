import React, { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Activity,
  BellRing,
  Cpu,
  Globe,
  Layers,
  LayoutDashboard,
  MonitorSmartphone,
  RefreshCw,
  RotateCw,
  Search,
  Send,
  ShieldCheck,
  Sparkles,
  Timer,
  Trash2,
  X,
  Zap,
} from 'lucide-react';
import { useDashboardStore } from '../store/useDashboard';
import type { WorkspaceView } from '../types/dashboard';

export type PaletteActionId =
  | 'nav_overview'
  | 'nav_instances'
  | 'nav_system'
  | 'nav_telemetry'
  | 'nav_alerts'
  | 'boost'
  | 'toggle_timer'
  | 'toggle_affinity'
  | 'flush_shader'
  | 'scan_deep_clean'
  | 'refresh_hardening'
  | 'flush_dns'
  | 'quick_scan'
  | 'test_discord_alert'
  | 'restart_tunnel'
  | 'reset_session'
  | 'reset_total';

interface CommandItem {
  id: PaletteActionId;
  group: 'Navigate' | 'Operations';
  title: string;
  desc: string;
  shortcut?: string;
  icon: React.ReactNode;
}

interface CommandPaletteProps {
  onExecute: (cmdId: PaletteActionId) => void;
}

export const CommandPalette: React.FC<CommandPaletteProps> = ({ onExecute }) => {
  const isOpen = useDashboardStore((s) => s.cmdPaletteOpen);
  const setOpen = useDashboardStore((s) => s.setCmdPaletteOpen);
  const setActiveView = useDashboardStore((s) => s.setActiveView);
  const timerRes = useDashboardStore((s) => s.timerResolution);
  const pcore = useDashboardStore((s) => s.pcoreAffinity);

  const [search, setSearch] = useState('');
  const [selectedIdx, setSelectedIdx] = useState(0);

  const closePalette = useCallback(() => {
    setOpen(false);
    setSearch('');
    setSelectedIdx(0);
  }, [setOpen]);

  const commands: CommandItem[] = useMemo(
    () => [
      {
        id: 'nav_overview',
        group: 'Navigate',
        title: 'Go to Overview',
        desc: 'Executive summary, telemetry graph, and quick actions',
        shortcut: '1',
        icon: <LayoutDashboard className="w-4 h-4 text-ops-accent" />,
      },
      {
        id: 'nav_instances',
        group: 'Navigate',
        title: 'Go to Instances',
        desc: 'MuMu fleet table, Roblox presence, and VM disk status',
        shortcut: '2',
        icon: <MonitorSmartphone className="w-4 h-4 text-ops-telemetry" />,
      },
      {
        id: 'nav_system',
        group: 'Navigate',
        title: 'Go to System',
        desc: 'Auto-Boost, kernel tuning, hardening, and deep clean',
        shortcut: '3',
        icon: <Cpu className="w-4 h-4 text-ops-ok" />,
      },
      {
        id: 'nav_telemetry',
        group: 'Navigate',
        title: 'Go to Telemetry & Net',
        desc: 'Core matrix, network observatory, and event console',
        shortcut: '4',
        icon: <Activity className="w-4 h-4 text-ops-telemetry" />,
      },
      {
        id: 'nav_alerts',
        group: 'Navigate',
        title: 'Go to Alerts & Tunnel',
        desc: 'Discord alert rules, delivery log, and tunnel control',
        shortcut: '5',
        icon: <BellRing className="w-4 h-4 text-ops-warn" />,
      },
      {
        id: 'boost',
        group: 'Operations',
        title: 'Boost RAM Now',
        desc: 'Trim working sets, purge Standby List, and clear temp files (PIN)',
        icon: <Zap className="w-4 h-4 text-ops-accent" />,
      },
      {
        id: 'refresh_hardening',
        group: 'Operations',
        title: 'Run Hardening Audit',
        desc: 'Verify VBS, MPO, Hypervisor, and Defender exclusion state',
        icon: <ShieldCheck className="w-4 h-4 text-ops-ok" />,
      },
      {
        id: 'flush_dns',
        group: 'Operations',
        title: 'Flush DNS Resolver Cache',
        desc: 'Run ipconfig /flushdns on the host (PIN)',
        icon: <Globe className="w-4 h-4 text-ops-telemetry" />,
      },
      {
        id: 'test_discord_alert',
        group: 'Operations',
        title: 'Send Test Discord Alert',
        desc: 'Dispatch direct test embed bypassing cooldown (PIN)',
        icon: <Send className="w-4 h-4 text-ops-ok" />,
      },
      {
        id: 'restart_tunnel',
        group: 'Operations',
        title: 'Restart Public Tunnel',
        desc: 'Reconnect ngrok or cloudflared ingress process (PIN)',
        icon: <RotateCw className="w-4 h-4 text-ops-warn" />,
      },
      {
        id: 'scan_deep_clean',
        group: 'Operations',
        title: 'Scan Deep Clean Targets',
        desc: 'Preview cleanable temp caches and crash dumps',
        icon: <Sparkles className="w-4 h-4 text-ops-warn" />,
      },
      {
        id: 'toggle_timer',
        group: 'Operations',
        title: `Toggle Kernel Timer (${timerRes?.active ? '0.5ms Active' : 'Default'})`,
        desc: 'Switch high-precision NtSetTimerResolution state (PIN)',
        icon: <Timer className="w-4 h-4 text-ops-ok" />,
      },
      {
        id: 'toggle_affinity',
        group: 'Operations',
        title: `Toggle P-Core Affinity (${pcore?.enabled ? 'P-Cores Locked' : 'Balanced'})`,
        desc: 'Bind MuMu and Roblox processes to Performance Cores (PIN)',
        icon: <Cpu className="w-4 h-4 text-ops-telemetry" />,
      },
      {
        id: 'flush_shader',
        group: 'Operations',
        title: 'Flush GPU Shader Cache',
        desc: 'Clear NVIDIA/AMD/D3D shader caches (PIN)',
        icon: <Layers className="w-4 h-4 text-ops-secondary" />,
      },
      {
        id: 'quick_scan',
        group: 'Operations',
        title: 'Defender Quick Scan',
        desc: 'Start Windows Defender background quick scan (PIN)',
        icon: <Search className="w-4 h-4 text-ops-ok" />,
      },
      {
        id: 'reset_session',
        group: 'Operations',
        title: 'Reset Session Boost Counter',
        desc: 'Reset session counter to 0 while keeping lifetime total (PIN)',
        icon: <RefreshCw className="w-4 h-4 text-ops-secondary" />,
      },
      {
        id: 'reset_total',
        group: 'Operations',
        title: 'Reset Lifetime Boost Counter',
        desc: 'Purge lifetime boost history (PIN)',
        icon: <Trash2 className="w-4 h-4 text-ops-danger" />,
      },
    ],
    [timerRes?.active, pcore?.enabled]
  );

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return commands;
    return commands.filter(
      (c) =>
        c.title.toLowerCase().includes(q) ||
        c.desc.toLowerCase().includes(q) ||
        c.group.toLowerCase().includes(q)
    );
  }, [commands, search]);

  const executeItem = useCallback(
    (item: CommandItem) => {
      setOpen(false);
      setSearch('');
      const navMap: Partial<Record<PaletteActionId, WorkspaceView>> = {
        nav_overview: 'overview',
        nav_instances: 'instances',
        nav_system: 'system',
        nav_telemetry: 'telemetry',
        nav_alerts: 'alerts',
      };
      const targetView = navMap[item.id];
      if (targetView) {
        setActiveView(targetView);
        return;
      }
      onExecute(item.id);
    },
    [onExecute, setActiveView, setOpen]
  );

  const clampedIdx = filtered.length > 0 ? Math.min(selectedIdx, filtered.length - 1) : 0;

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        if (isOpen) {
          closePalette();
        } else {
          setSearch('');
          setSelectedIdx(0);
          setOpen(true);
        }
        return;
      }
      if (!isOpen) return;

      if (e.key === 'Escape') {
        e.preventDefault();
        closePalette();
      } else if (e.key === 'ArrowDown') {
        e.preventDefault();
        setSelectedIdx((idx) => (filtered.length > 0 ? (idx + 1) % filtered.length : 0));
      } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        setSelectedIdx((idx) =>
          filtered.length > 0 ? (idx - 1 + filtered.length) % filtered.length : 0
        );
      } else if (e.key === 'Enter' && filtered[clampedIdx]) {
        e.preventDefault();
        executeItem(filtered[clampedIdx]);
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, filtered, clampedIdx, closePalette, executeItem, setOpen]);

  if (!isOpen) return null;

  const grouped: Array<{ group: 'Navigate' | 'Operations'; items: Array<{ item: CommandItem; flatIdx: number }> }> = [];
  (['Navigate', 'Operations'] as const).forEach((groupName) => {
    const matches = filtered
      .map((item, flatIdx) => ({ item, flatIdx }))
      .filter(({ item }) => item.group === groupName);
    if (matches.length > 0) {
      grouped.push({ group: groupName, items: matches });
    }
  });

  return (
    <div
      className="fixed inset-0 z-50 flex items-start justify-center pt-16 sm:pt-24 p-4 bg-black/75 backdrop-blur-sm"
      role="dialog"
      aria-modal="true"
      aria-label="Command palette"
      onClick={(e) => {
        if (e.target === e.currentTarget) closePalette();
      }}
    >
      <div className="w-full max-w-lg bg-ops-surface border border-ops-borderStrong rounded-lg shadow-xl overflow-hidden">
        <div className="flex items-center gap-2.5 px-3.5 py-3 border-b border-ops-border bg-ops-chrome">
          <Search className="w-4 h-4 text-ops-muted shrink-0" />
          <input
            type="text"
            value={search}
            onChange={(e) => {
              setSearch(e.target.value);
              setSelectedIdx(0);
            }}
            placeholder="Navigate or run command..."
            autoFocus
            className="w-full bg-transparent text-sm text-ops-text placeholder-ops-muted outline-none"
          />
          <button
            type="button"
            onClick={closePalette}
            aria-label="Close command palette"
            className="p-1 rounded text-ops-muted hover:text-ops-text hover:bg-ops-elevated transition-colors"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        <div className="max-h-80 overflow-y-auto p-2 space-y-3">
          {grouped.length === 0 ? (
            <div className="py-8 text-center text-xs text-ops-muted font-mono">
              No matching commands found
            </div>
          ) : (
            grouped.map((section) => (
              <div key={section.group}>
                <div className="px-2 pb-1 text-[10px] font-mono uppercase tracking-wider text-ops-muted">
                  {section.group}
                </div>
                <div className="space-y-0.5">
                  {section.items.map(({ item, flatIdx }) => {
                    const active = flatIdx === clampedIdx;
                    return (
                      <button
                        key={item.id}
                        type="button"
                        onMouseEnter={() => setSelectedIdx(flatIdx)}
                        onClick={() => executeItem(item)}
                        className={`w-full flex items-center gap-3 px-2.5 py-2 rounded-md text-left transition-colors ${
                          active
                            ? 'bg-ops-elevated border border-ops-borderStrong'
                            : 'border border-transparent hover:bg-ops-elevated/50'
                        }`}
                      >
                        <div className="p-1.5 rounded bg-ops-inset border border-ops-border shrink-0">
                          {item.icon}
                        </div>
                        <div className="min-w-0 flex-1">
                          <div className="text-xs font-medium text-ops-text truncate">
                            {item.title}
                          </div>
                          <div className="text-[11px] text-ops-secondary truncate">
                            {item.desc}
                          </div>
                        </div>
                        {item.shortcut && (
                          <kbd className="font-mono text-[10px] px-1.5 py-0.5 rounded bg-ops-inset border border-ops-border text-ops-muted shrink-0">
                            {item.shortcut}
                          </kbd>
                        )}
                      </button>
                    );
                  })}
                </div>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
};
