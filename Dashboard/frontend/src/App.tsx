import { useCallback, useEffect } from 'react';
import { getViewFromHash, useDashboardStore } from './store/useDashboard';
import { useWebSocket } from './hooks/useWebSocket';
import { postPurgeDiscordAlerts, postRestartServer } from './lib/api';
import type { AlertsConfigUpdatePayload, WorkspaceView } from './types/dashboard';

import { AppShell } from './components/layout/AppShell';
import { OverviewView } from './components/overview/OverviewView';
import { InstancesView } from './components/instances/InstancesView';
import { SystemView } from './components/system/SystemView';
import { TelemetryView } from './components/telemetry/TelemetryView';
import { AlertsTunnelView } from './components/alerts/AlertsTunnelView';

import { CommandPalette, type PaletteActionId } from './components/CommandPalette';
import { AuthModal } from './components/AuthModal';
import { EditGameModal, type GameTargetUpdates } from './components/EditGameModal';
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

  // --- Shared Command Dispatchers ---
  const handleBoostNow = useCallback(() => {
    requireAuthGuard(() => {
      const store = useDashboardStore.getState();
      store.setIsBoosting(true);
      store.setPendingOp('boost');
      sendCommand('boost');
    });
  }, [requireAuthGuard, sendCommand]);

  const handleCheckHardening = useCallback(() => {
    useDashboardStore.getState().setPendingOp('hardening');
    sendCommand('check_hardening');
  }, [sendCommand]);

  const handleFlushDns = useCallback(() => {
    requireAuthGuard(() => {
      useDashboardStore.getState().setPendingOp('dns');
      sendCommand('flush_dns');
    });
  }, [requireAuthGuard, sendCommand]);

  const handleScanDeepClean = useCallback(() => {
    const store = useDashboardStore.getState();
    store.setIsScanningClean(true);
    store.setPendingOp('deepclean:scan');
    sendCommand('deep_clean_preview');
  }, [sendCommand]);

  const handleQuickScanDefender = useCallback(() => {
    requireAuthGuard(() => {
      useDashboardStore.getState().setPendingOp('defender:scan');
      sendCommand('quick_scan');
    });
  }, [requireAuthGuard, sendCommand]);

  const handleToggleTimer = useCallback(
    (enabled: boolean) => {
      requireAuthGuard(() => {
        useDashboardStore.getState().setPendingOp('timer');
        sendCommand('toggle_timer_resolution', { enabled });
      });
    },
    [requireAuthGuard, sendCommand]
  );

  const handleToggleAffinity = useCallback(
    (enabled: boolean) => {
      requireAuthGuard(() => {
        useDashboardStore.getState().setPendingOp('affinity');
        sendCommand('toggle_pcore_affinity', { enabled });
      });
    },
    [requireAuthGuard, sendCommand]
  );

  const handleFlushShader = useCallback(() => {
    requireAuthGuard(() => {
      useDashboardStore.getState().setPendingOp('shader:flush');
      sendCommand('flush_shader_cache');
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
      const executePurge = async () => {
        const store = useDashboardStore.getState();
        store.setIsPurgingAlerts(true);
        const res = await postPurgeDiscordAlerts(
          { limit, bot_only: botOnly },
          store.token
        );
        const current = useDashboardStore.getState();
        current.setIsPurgingAlerts(false);

        if (res.status === 401) {
          current.clearSession();
          current.openAuthModalWithAction(() => {
            void executePurge();
          });
          return;
        }

        if (res.data) {
          current.setLastAlertPurgeResult(res.data);
          if (res.ok && res.data.ok) {
            current.addToast(
              'success',
              `Purged ${res.data.deleted_count} Discord message(s)`
            );
          } else {
            current.addToast(
              'error',
              `Purge failed: ${res.data.error || res.error || 'Unknown error'}`
            );
          }
        } else {
          const errMsg = res.error || 'Purge request failed';
          current.setLastAlertPurgeResult({
            ok: false,
            deleted_count: 0,
            error: errMsg,
          });
          current.addToast('error', `Purge failed: ${errMsg}`);
        }
      };

      requireAuthGuard(() => {
        void executePurge();
      });
    },
    [requireAuthGuard]
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
    const executeRestart = async () => {
      const { token, addToast, clearSession, openAuthModalWithAction } =
        useDashboardStore.getState();
      const res = await postRestartServer(token);
      if (res.status === 401) {
        clearSession();
        openAuthModalWithAction(() => {
          void executeRestart();
        });
        return;
      }
      if (res.ok) {
        addToast('warning', 'Core server restarting...');
      } else {
        addToast('error', res.error || 'Failed to restart server');
      }
    };

    requireAuthGuard(() => {
      void executeRestart();
    });
  }, [requireAuthGuard]);

  const handleCommandPaletteAction = useCallback(
    (cmdId: PaletteActionId) => {
      switch (cmdId) {
        case 'boost':
          handleBoostNow();
          break;
        case 'scan_deep_clean':
          handleScanDeepClean();
          break;
        case 'refresh_hardening':
          handleCheckHardening();
          break;
        case 'flush_dns':
          handleFlushDns();
          break;
        case 'quick_scan':
          handleQuickScanDefender();
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
          handleToggleTimer(!useDashboardStore.getState().timerResolution?.active);
          break;
        case 'toggle_affinity':
          handleToggleAffinity(!useDashboardStore.getState().pcoreAffinity?.enabled);
          break;
        case 'flush_shader':
          handleFlushShader();
          break;
      }
    },
    [
      handleBoostNow,
      handleCheckHardening,
      handleFlushDns,
      handleFlushShader,
      handleQuickScanDefender,
      handleRestartTunnel,
      handleScanDeepClean,
      handleTestAlert,
      handleToggleAffinity,
      handleToggleTimer,
      requireAuthGuard,
      sendCommand,
    ]
  );

  const handleSaveGameTarget = useCallback(
    (instance: number, updates: GameTargetUpdates) => {
      requireAuthGuard(() => {
        if (typeof updates.placeId === 'number') {
          useDashboardStore.getState().setPendingOp(`mumuGame:${instance}`);
          sendCommand('set_mumu_game', {
            instance,
            place_id: updates.placeId,
            save_as_preset: updates.saveAsPreset,
            preset_name: updates.presetName,
          });
        }
        if (updates.username !== undefined) {
          sendCommand('set_mumu_username', { instance, username: updates.username });
        }
        if (typeof updates.autoRejoin === 'boolean') {
          useDashboardStore.getState().setPendingOp(`rejoin:${instance}`);
          sendCommand('set_auto_rejoin', { instance, enabled: updates.autoRejoin });
        }
      });
    },
    [requireAuthGuard, sendCommand]
  );

  const handleAddPreset = useCallback(
    (placeId: number, name: string) => {
      requireAuthGuard(() => {
        useDashboardStore.getState().setPendingOp('preset:add');
        sendCommand('add_game_preset', { place_id: placeId, name });
      });
    },
    [requireAuthGuard, sendCommand]
  );

  const handleUpdatePreset = useCallback(
    (originalPlaceId: number, placeId: number, name: string) => {
      requireAuthGuard(() => {
        useDashboardStore.getState().setPendingOp(`preset:edit:${originalPlaceId}`);
        sendCommand('update_game_preset', {
          original_place_id: originalPlaceId,
          place_id: placeId,
          name,
        });
      });
    },
    [requireAuthGuard, sendCommand]
  );

  const handleDeletePreset = useCallback(
    (placeId: number) => {
      requireAuthGuard(() => {
        useDashboardStore.getState().setPendingOp(`preset:delete:${placeId}`);
        sendCommand('delete_game_preset', { place_id: placeId });
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
            onCheckHardening={handleCheckHardening}
            onFlushDns={handleFlushDns}
            onTestAlert={handleTestAlert}
          />
        )}

        {activeView === 'instances' && (
          <InstancesView
            onGovernorAction={(instance, action) =>
              requireAuthGuard(() => {
                useDashboardStore
                  .getState()
                  .setPendingOp(`governor:${instance}:${action}`);
                sendCommand('governor_action', { instance, action });
              })
            }
            onToggleAutoRejoin={(instance, enabled) =>
              requireAuthGuard(() => {
                useDashboardStore
                  .getState()
                  .setPendingOp(instance === null ? 'rejoin:global' : `rejoin:${instance}`);
                sendCommand('set_auto_rejoin', { instance, enabled });
              })
            }
            onAddPreset={handleAddPreset}
            onUpdatePreset={handleUpdatePreset}
            onDeletePreset={handleDeletePreset}
            onRefreshVmDisk={() => {
              useDashboardStore.getState().setPendingOp('vmdisk:refresh');
              sendCommand('vm_disk_refresh');
            }}
            onTrimVmCache={(port) =>
              requireAuthGuard(() => {
                useDashboardStore.getState().setPendingOp(`vmTrim:${port}`);
                sendCommand('vm_trim_cache', { port });
              })
            }
          />
        )}

        {activeView === 'system' && (
          <SystemView
            onToggleAutoBoost={(enabled) =>
              requireAuthGuard(() => {
                useDashboardStore.getState().setPendingOp('autoboost:enabled');
                sendCommand('set_auto_boost', { enabled });
              })
            }
            onSetThreshold={(threshold) =>
              requireAuthGuard(() => {
                useDashboardStore.getState().setPendingOp('autoboost:threshold');
                sendCommand('set_threshold', { threshold });
              })
            }
            onSetMode={(mode) =>
              requireAuthGuard(() => {
                useDashboardStore.getState().setPendingOp('autoboost:mode');
                sendCommand('set_boost_mode', { mode });
              })
            }
            onSetInterval={(interval_minutes) =>
              requireAuthGuard(() => {
                useDashboardStore.getState().setPendingOp('autoboost:interval');
                sendCommand('set_boost_interval', { interval_minutes });
              })
            }
            onBoostNow={handleBoostNow}
            onResetSessionBoosts={() =>
              requireAuthGuard(() => sendCommand('reset_session_boosts'))
            }
            onResetTotalBoosts={() =>
              requireAuthGuard(() => sendCommand('reset_total_boosts'))
            }
            onToggleTimerResolution={handleToggleTimer}
            onTogglePcoreAffinity={handleToggleAffinity}
            onScanShaderCache={() => {
              useDashboardStore.getState().setPendingOp('shader:scan');
              sendCommand('scan_shader_cache');
            }}
            onFlushShaderCache={handleFlushShader}
            onRefreshHardening={handleCheckHardening}
            onScanDeepClean={handleScanDeepClean}
            onExecuteDeepClean={() =>
              requireAuthGuard(() => {
                const store = useDashboardStore.getState();
                store.setIsDeepCleaning(true);
                store.setPendingOp('deepclean:execute');
                sendCommand('deep_clean_execute');
              })
            }
            onRefreshDefender={() => {
              useDashboardStore.getState().setPendingOp('defender:refresh');
              sendCommand('defender_status');
            }}
            onQuickScanDefender={handleQuickScanDefender}
            onTrimProcess={(pid) =>
              requireAuthGuard(() => {
                useDashboardStore.getState().setPendingOp(`procTrim:${pid}`);
                sendCommand('trim_process', { pid });
              })
            }
            onKillProcess={(pid) =>
              requireAuthGuard(() => {
                useDashboardStore.getState().setPendingOp(`procKill:${pid}`);
                sendCommand('kill_process', { pid });
              })
            }
          />
        )}

        {activeView === 'telemetry' && (
          <TelemetryView
            onRefreshObservatory={() => {
              useDashboardStore.getState().setPendingOp('observatory:refresh');
              sendCommand('observatory_refresh');
            }}
            onFlushDns={handleFlushDns}
            onRefreshGrowth={() => {
              useDashboardStore.getState().setPendingOp('growth:refresh');
              sendCommand('growth_data');
            }}
          />
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
      <EditGameModal
        onSave={handleSaveGameTarget}
        onAddPreset={handleAddPreset}
        onUpdatePreset={handleUpdatePreset}
        onDeletePreset={handleDeletePreset}
      />
      <ToastContainer />
    </>
  );
}

export default App;
