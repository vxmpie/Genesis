import React, { useState, useEffect } from 'react';
import { Zap, Sparkles, ShieldCheck, Globe, Search, RefreshCw, Trash2, X } from 'lucide-react';
import { useDashboardStore } from '../store/useDashboard';

interface CommandPaletteProps {
  onExecute: (cmdId: string) => void;
}

export const CommandPalette: React.FC<CommandPaletteProps> = ({ onExecute }) => {
  const isOpen = useDashboardStore((s) => s.cmdPaletteOpen);
  const setOpen = useDashboardStore((s) => s.setCmdPaletteOpen);
  const [search, setSearch] = useState('');

  const commands = [
    { id: 'boost', title: 'RAM Boost (NtSetSystemInfo)', desc: 'Trim processes & purge Standby Cache', icon: <Zap className="w-4 h-4 text-genesis-accent" /> },
    { id: 'scan_deep_clean', title: 'Deep Clean Scan', desc: 'Scan temp caches & dump files', icon: <Sparkles className="w-4 h-4 text-genesis-amber" /> },
    { id: 'refresh_hardening', title: 'Hardening Audit', desc: 'Verify 4/4 CIM security configuration', icon: <ShieldCheck className="w-4 h-4 text-genesis-green" /> },
    { id: 'flush_dns', title: 'Flush DNS Resolver', desc: 'Clear local DNS cache & ARP sockets', icon: <Globe className="w-4 h-4 text-genesis-cyan" /> },
    { id: 'quick_scan', title: 'Defender Quick Scan', desc: 'Trigger Windows Defender background scan', icon: <Search className="w-4 h-4 text-genesis-green" /> },
    { id: 'reset_session', title: 'Reset Session Boosts', desc: 'Reset session counter to 0 (preserve total)', icon: <RefreshCw className="w-4 h-4 text-slate-400" /> },
    { id: 'reset_total', title: 'Reset Lifetime Boosts', desc: 'Reset lifetime boost history (requires PIN)', icon: <Trash2 className="w-4 h-4 text-red-400" /> },
  ];

  const filtered = commands.filter(
    (c) =>
      (c?.title || '').toLowerCase().includes((search || '').toLowerCase()) ||
      (c?.desc || '').toLowerCase().includes((search || '').toLowerCase())
  );

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
        e.preventDefault();
        setOpen(!isOpen);
      }
      if (e.key === 'Escape' && isOpen) {
        setOpen(false);
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, setOpen]);

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md animate-fadeIn">
      <div className="w-full max-w-lg bg-genesis-card border border-white/10 rounded-xl shadow-2xl overflow-hidden animate-scaleUp">
        {/* Search Bar */}
        <div className="flex items-center gap-2.5 px-4 py-3 border-b border-white/[0.08] bg-white/[0.02]">
          <Search className="w-4 h-4 text-slate-400" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Type a command or action..."
            autoFocus
            className="w-full bg-transparent text-sm text-white placeholder-slate-500 outline-none font-medium"
          />
          <button
            onClick={() => setOpen(false)}
            className="btn-cyber p-1 rounded-md text-slate-400 hover:text-white hover:bg-white/[0.05] active:scale-90"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Command List */}
        <div className="max-h-72 overflow-y-auto p-2 space-y-1">
          {filtered.length === 0 ? (
            <div className="py-8 text-center text-xs text-slate-500 font-mono">No matching commands found</div>
          ) : (
            filtered.map((cmd) => (
              <button
                key={cmd.id}
                onClick={() => {
                  setOpen(false);
                  onExecute(cmd.id);
                }}
                className="btn-cyber w-full flex items-center gap-3 p-2.5 rounded-lg hover:bg-white/[0.06] text-left transition-all group active:scale-[0.98]"
              >
                <div className="p-2 rounded-md bg-white/[0.03] border border-white/[0.06] group-hover:border-genesis-cyan/40 group-hover:scale-110 transition-transform">
                  {cmd.icon}
                </div>
                <div>
                  <div className="font-bold text-xs text-white group-hover:text-genesis-cyan transition-colors">
                    {cmd.title}
                  </div>
                  <div className="text-[11px] text-slate-400">{cmd.desc}</div>
                </div>
              </button>
            ))
          )}
        </div>
      </div>
    </div>
  );
};
