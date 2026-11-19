import { useCallback, useEffect } from 'react';
import { getViewFromHash, useDashboardStore } from './store/useDashboard';
import { useWebSocket } from './hooks/useWebSocket';
import { postRestartServer } from './lib/api';
import type { AlertsConfigUpdatePayload, WorkspaceView } from './types/dashboard';

import { AppShell } from './components/layout/AppShell';
import { OverviewView } from './components/overview/OverviewView';
import { PrecisionTelemetryChart } from './components/overview/PrecisionTelemetryChart';
import { AlertsTunnelView } from './components/alerts/AlertsTunnelView';

import { MuMuCard } from './components/MuMuCard';
import { AutoBoostCard } from './components/AutoBoostCard';
import { HardeningCard } from './components/HardeningCard';
import { DeepCleanCard } from './components/DeepCleanCard';
import { DefenderCard } from './components/DefenderCard';
import { TopProcsCard } from './components/TopProcsCard';
import { CpuCoresCard } from './components/CpuCoresCard';
import { NetworkObservatory } from './components/NetworkObservatory';
import { EventLogCard } from './components/EventLogCard';

import { CommandPalette, type PaletteActionId } from './components/CommandPalette';
import { AuthModal } from './components/AuthModal';
import { EditGameModal } from './components/EditGameModal';
import { ToastContainer } from './components/ToastContainer';

const VIEW_SHORTCUTS: Record<string, WorkspaceView> = {
  '1': 'overview',
  '2': 'instances',
  '3': 'system',
  '4': 'telemetry',
  '5': 'alerts',
};

export function App() {
  const activeView = useDashboardStore((s) => s.activeView);
  const setActiveView = useDashboardStore((s) => s.setActiveView);
  const { sendCommand } = useWebSocket();

  const requireAuthGuard = useCallback((action: () => void) => {
    const { authRequired, authenticated, openAuthModalWithAction } =
      useDashboardStore.getState();
    if (authRequired && !authenticated) {
      openAuthModalWithAction(action);
      return;
    }
    action();
  }, []);

  // --- Hash Sync & Numeric Room Shortcuts ---
  useEffect(() => {
    const handleHashChange = () => {
      setActiveView(getViewFromHash(), false);
    };
    window.addEventListener('hashchange', handleHashChange);
    return () => window.removeEventListener('hashchange', handleHashChange);
  }, [setActiveView]);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.ctrlKey || e.metaKey || e.altKey) return;
      const target = e.target as HTMLElement | null;
      if (
        target &&
        (target.tagName === 'INPUT' ||
          target.tagName === 'TEXTAREA' ||
          target.tagName === 'SELECT' ||
          target.isContentEditable)
      ) {
        return;
      }
      const { authModalOpen, cmdPaletteOpen, editGameModalOpen } =
        useDashboardStore.getState();
      if (authModalOpen || cmdPaletteOpen || editGameModalOpen) return;

      const view = VIEW_SHORTCUTS[e.key];
      if (view) {
        setActiveView(view);
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [setActiveView]);

  // --- Command Dispatchers ---
  const handleBoostNow = useCallback(() => {
    requireAuthGuard(() => {
      useDashboardStore.getState().setIsBoosting(true);
      sendCommand('boost');
    });
  }, [requireAuthGuard, sendCommand]);

  const handleTestAlert = useCallback(() => {
    requireAuthGuard(() => {
      useDashboardStore.getState().setIsTestingAlert(true);
      sendCommand('test_discord_alert');
    });
  }, [requireAuthGuard, sendCommand]);

  const handlePurgeAlerts = useCallback(
    (limit: number, botOnly: boolean) => {
      requireAuthGuard(() => {
        useDashboardStore.getState().setIsPurgingAlerts(true);
        sendCommand('purge_discord_alerts', { limit, bot_only: botOnly });
      });
    },
    [requireAuthGuard, sendCommand]
  );

  const handleSaveAlertsConfig = useCallback(
    (payload: AlertsConfigUpdatePayload) => {
      requireAuthGuard(() => {
        useDashboardStore.getState().setIsSavingAlerts(true);
        sendCommand('update_alerts_config', { alerts: payload });
      });
    },
    [requireAuthGuard, sendCommand]
  );

  const handleRestartTunnel = useCallback(() => {
    requireAuthGuard(() => {
      useDashboardStore.getState().setIsRestartingTunnel(true);
      sendCommand('restart_tunnel');
    });
  }, [requireAuthGuard, sendCommand]);

  const handleRestartServer = useCallback(() => {
    requireAuthGuard(async () => {
      const { token, addToast } = useDashboardStore.getState();
      const res = await postRestartServer(token);
      if (res.ok) {
        addToast('warning', 'Core server restarting...');
      } else {
        addToast('error', res.error || 'Failed to restart server');
      }
    });
  }, [requireAuthGuard]);

  const handleCommandPaletteAction = useCallback(
    (cmdId: PaletteActionId) => {
      switch (cmdId) {
        case 'boost':
          handleBoostNow();
          break;
        case 'scan_deep_clean':
          useDashboardStore.getState().setIsScanningClean(true);
          sendCommand('deep_clean_preview');
          break;
        case 'refresh_hardening':
          sendCommand('check_hardening');
          break;
        case 'flush_dns':
          requireAuthGuard(() => sendCommand('flush_dns'));
          break;
        case 'quick_scan':
          requireAuthGuard(() => sendCommand('quick_scan'));
          break;
        case 'test_discord_alert':
          handleTestAlert();
          break;
        case 'restart_tunnel':
          handleRestartTunnel();
          break;
        case 'reset_session':
          requireAuthGuard(() => sendCommand('reset_session_boosts'));
          break;
        case 'reset_total':
          requireAuthGuard(() => sendCommand('reset_total_boosts'));
          break;
        case 'toggle_timer':
          requireAuthGuard(() =>
            sendCommand('toggle_timer_resolution', {
              enabled: !useDashboardStore.getState().timerResolution?.active,
            })
          );
          break;
        case 'toggle_affinity':
          requireAuthGuard(() =>
            sendCommand('toggle_pcore_affinity', {
              enabled: !useDashboardStore.getState().pcoreAffinity?.enabled,
            })
          );
          break;
        case 'flush_shader':
          requireAuthGuard(() => sendCommand('flush_shader_cache'));
          break;
      }
    },
    [handleBoostNow, handleRestartTunnel, handleTestAlert, requireAuthGuard, sendCommand]
  );

  const handleSaveGameTarget = useCallback(
    (instance: number, placeId: number, username?: string) => {
      requireAuthGuard(() => {
        sendCommand('set_mumu_game', { instance, place_id: placeId });
        if (username !== undefined) {
          sendCommand('set_mumu_username', { instance, username });
        }
      });
    },
    [requireAuthGuard, sendCommand]
  );

  return (
    <>
      <AppShell>
        {activeView === 'overview' && (
          <OverviewView
            onBoostNow={handleBoostNow}
            onCheckHardening={() => sendCommand('check_hardening')}
            onFlushDns={() => requireAuthGuard(() => sendCommand('flush_dns'))}
            onTestAlert={handleTestAlert}
          />
        )}

        {activeView === 'instances' && (
          <div className="space-y-4">
            <MuMuCard
              onTrimMemory={(pid, index) =>
                requireAuthGuard(() =>
                  sendCommand('trim_mumu_instance', { pid, instance: index })
                )
              }
              onGovernorAction={(instance, action) =>
                requireAuthGuard(() =>
                  sendCommand('governor_action', { instance, action })
                )
              }
            />
          </div>
        )}

        {activeView === 'system' && (
          <div className="space-y-4">
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
              <AutoBoostCard
                onToggle={(enabled) =>
                  requireAuthGuard(() => {
                    useDashboardStore.getState().updateAutoBoost({ enabled });
                    sendCommand('set_auto_boost', { enabled });
                  })
                }
                onSetThreshold={(threshold) =>
                  requireAuthGuard(() => {
                    useDashboardStore.getState().updateAutoBoost({ threshold });
                    sendCommand('set_threshold', { threshold });
                  })
                }
                onSetMode={(mode) =>
                  requireAuthGuard(() => {
                    useDashboardStore.getState().updateAutoBoost({ mode });
                    sendCommand('set_boost_mode', { mode });
                  })
                }
                onSetInterval={(interval_minutes) =>
                  requireAuthGuard(() => {
                    useDashboardStore.getState().updateAutoBoost({ interval_minutes });
                    sendCommand('set_boost_interval', { interval_minutes });
                  })
                }
                onBoostNow={handleBoostNow}
              />
              <HardeningCard onRefresh={() => sendCommand('check_hardening')} />
            </div>

            <DeepCleanCard
              onScan={() => {
                useDashboardStore.getState().setIsScanningClean(true);
                sendCommand('deep_clean_preview');
              }}
              onExecuteClean={() =>
                requireAuthGuard(() => {
                  useDashboardStore.getState().setIsDeepCleaning(true);
                  sendCommand('deep_clean_execute');
                })
              }
            />

            <DefenderCard
              onQuickScan={() => requireAuthGuard(() => sendCommand('quick_scan'))}
            />

            <TopProcsCard />
          </div>
        )}

        {activeView === 'telemetry' && (
          <div className="space-y-4">
            <PrecisionTelemetryChart />
            <CpuCoresCard />
            <NetworkObservatory
              onFlushDns={() => requireAuthGuard(() => sendCommand('flush_dns'))}
            />
            <EventLogCard />
          </div>
        )}

        {activeView === 'alerts' && (
          <AlertsTunnelView
            onSaveAlertsConfig={handleSaveAlertsConfig}
            onSendTestAlert={handleTestAlert}
            onPurgeAlerts={handlePurgeAlerts}
            onRefreshAlertsHistory={() => sendCommand('alerts_history')}
            onRestartTunnel={handleRestartTunnel}
            onRestartServer={handleRestartServer}
          />
        )}
      </AppShell>

      <CommandPalette onExecute={handleCommandPaletteAction} />
      <AuthModal />
      <EditGameModal onSave={handleSaveGameTarget} />
      <ToastContainer />
    </>
  );
}

export default App;
