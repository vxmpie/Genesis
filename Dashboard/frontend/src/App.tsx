import { Zap } from 'lucide-react';
import { useDashboardStore } from './store/useDashboard';
import { useWebSocket } from './hooks/useWebSocket';

import { Header } from './components/Header';
import { HudSummary } from './components/HudSummary';
import { MetricCards } from './components/MetricCards';
import { CpuCoresCard } from './components/CpuCoresCard';
import { HardeningCard } from './components/HardeningCard';
import { AutoBoostCard } from './components/AutoBoostCard';
import { MuMuCard } from './components/MuMuCard';
import { DeepCleanCard } from './components/DeepCleanCard';
import { DefenderCard } from './components/DefenderCard';
import { TelemetryChart } from './components/TelemetryChart';
import { EventLogCard } from './components/EventLogCard';
import { TopProcsCard } from './components/TopProcsCard';
import { NetworkObservatory } from './components/NetworkObservatory';
import { CommandPalette } from './components/CommandPalette';
import { AuthModal } from './components/AuthModal';
import { EditGameModal } from './components/EditGameModal';
import { ToastContainer } from './components/ToastContainer';

export function App() {
  const activeView = useDashboardStore((s) => s.activeView);
  const setAuthModalOpen = useDashboardStore((s) => s.setAuthModalOpen);
  const setCmdPaletteOpen = useDashboardStore((s) => s.setCmdPaletteOpen);

  const { sendCommand } = useWebSocket();

  const requireAuthGuard = (callback: () => void) => {
    const currentAuthed = useDashboardStore.getState().authenticated;
    const currentToken = useDashboardStore.getState().token;
    const req = useDashboardStore.getState().authRequired;

    if (req && !currentAuthed && !currentToken) {
      setAuthModalOpen(true);
      return;
    }
    callback();
  };

  const handleCommandPaletteAction = (cmdId: string) => {
    switch (cmdId) {
      case 'boost':
        requireAuthGuard(() => sendCommand('boost'));
        break;
      case 'scan_deep_clean':
        sendCommand('deep_clean_preview');
        break;
      case 'refresh_hardening':
        sendCommand('check_hardening');
        break;
      case 'flush_dns':
        sendCommand('flush_dns');
        break;
      case 'quick_scan':
        sendCommand('quick_scan');
        break;
      case 'reset_session':
        sendCommand('reset_session_boosts');
        break;
      case 'reset_total':
        requireAuthGuard(() => sendCommand('reset_total_boosts'));
        break;
      case 'toggle_timer':
        sendCommand('toggle_timer_resolution', {
          enabled: !useDashboardStore.getState().timerResolution?.active,
        });
        break;
      case 'toggle_affinity':
        sendCommand('toggle_pcore_affinity', {
          enabled: !useDashboardStore.getState().pcoreAffinity?.enabled,
        });
        break;
      case 'flush_shader':
        requireAuthGuard(() => sendCommand('flush_shader_cache'));
        break;
    }
  };

  const handleSaveGameTarget = (instance: number, placeId: number) => {
    requireAuthGuard(() => sendCommand('set_mumu_game', { instance, place_id: placeId }));
  };

  return (
    <div className="min-h-screen bg-genesis-bg text-slate-100 flex flex-col font-sans selection:bg-genesis-accent/30 selection:text-white">
      {/* Top Header */}
      <Header
        onOpenPalette={() => setCmdPaletteOpen(true)}
        onOpenAuth={() => setAuthModalOpen(true)}
      />

      {/* Main Container */}
      <main className="flex-1 max-w-7xl w-full mx-auto p-3 sm:p-5 flex flex-col gap-4 sm:gap-5">
        {/* HUD Summary (Visible across Overview & System) */}
        {(activeView === 'overview' || activeView === 'system') && (
          <HudSummary
            onResetSession={() => sendCommand('reset_session_boosts')}
            onResetTotal={() => requireAuthGuard(() => sendCommand('reset_total_boosts'))}
          />
        )}

        {/* Top Priority Grid: MuMu Instances & Auto-Boost Core (Overview & Bots) */}
        {(activeView === 'overview' || activeView === 'bots') && (
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
            <MuMuCard
              onTrimMemory={(pid, index) => requireAuthGuard(() => sendCommand('trim_mumu_instance', { pid, instance: index }))}
              onGovernorAction={(instance, action) => requireAuthGuard(() => sendCommand('governor_action', { instance, action }))}
            />
            <AutoBoostCard
              onToggle={(enabled) => {
                useDashboardStore.getState().updateAutoBoost({ enabled });
                sendCommand('set_auto_boost', { enabled });
              }}
              onSetThreshold={(threshold) => {
                useDashboardStore.getState().updateAutoBoost({ threshold });
                sendCommand('set_threshold', { threshold });
              }}
              onSetMode={(mode) => {
                useDashboardStore.getState().updateAutoBoost({ mode });
                sendCommand('set_boost_mode', { mode });
              }}
              onSetInterval={(interval_minutes) => {
                useDashboardStore.getState().updateAutoBoost({ interval_minutes });
                sendCommand('set_boost_interval', { interval_minutes });
              }}
              onBoostNow={() => requireAuthGuard(() => sendCommand('boost'))}
            />
          </div>
        )}

        {/* 4 Hardware Metric Rings (Overview, Analytics) */}
        {(activeView === 'overview' || activeView === 'analytics') && <MetricCards />}

        {/* CPU 16-Core Matrix (Overview, Analytics) */}
        {(activeView === 'overview' || activeView === 'analytics') && <CpuCoresCard />}

        {/* Hardening Status (Overview, System) */}
        {(activeView === 'overview' || activeView === 'system') && (
          <HardeningCard onRefresh={() => sendCommand('check_hardening')} />
        )}

        {/* Deep Clean Engine (Overview, System) */}
        {(activeView === 'overview' || activeView === 'system') && (
          <DeepCleanCard
            onScan={() => {
              useDashboardStore.getState().setIsScanningClean(true);
              sendCommand('deep_clean_preview');
            }}
            onExecuteClean={() => {
              useDashboardStore.getState().setIsDeepCleaning(true);
              requireAuthGuard(() => sendCommand('deep_clean_execute'));
            }}
          />
        )}

        {/* Windows Defender Sentinel (Overview, System) */}
        {(activeView === 'overview' || activeView === 'system') && (
          <DefenderCard onQuickScan={() => sendCommand('quick_scan')} />
        )}

        {/* 30-Minute Real-Time Telemetry Graph (Overview, Analytics) */}
        {(activeView === 'overview' || activeView === 'analytics') && <TelemetryChart />}

        {/* Bottom Grid: Event Log + Top Processes */}
        {(activeView === 'overview' || activeView === 'analytics') && (
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
            <EventLogCard />
            <TopProcsCard />
          </div>
        )}

        {/* Network Observatory (Overview, Bots, Analytics) */}
        {(activeView === 'overview' || activeView === 'bots' || activeView === 'analytics') && (
          <NetworkObservatory onFlushDns={() => sendCommand('flush_dns')} />
        )}
      </main>

      {/* Floating Action Hub Button */}
      <button
        onClick={() => setCmdPaletteOpen(true)}
        className="fixed bottom-4 right-4 z-40 w-11 h-11 sm:w-12 sm:h-12 rounded-full bg-gradient-to-br from-genesis-cyan to-blue-600 text-black font-extrabold flex items-center justify-center shadow-glow-cyan hover:scale-105 active:scale-95 transition-all"
        title="Open Command Hub (Ctrl+K)"
      >
        <Zap className="w-5 h-5 fill-current" />
      </button>

      {/* Modals & Toasts */}
      <CommandPalette onExecute={handleCommandPaletteAction} />
      <AuthModal />
      <EditGameModal onSave={handleSaveGameTarget} />
      <ToastContainer />
    </div>
  );
}

export default App;
