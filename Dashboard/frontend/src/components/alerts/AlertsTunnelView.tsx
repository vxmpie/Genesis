import React from 'react';
import { BellRing, CheckCircle2, ShieldAlert, XCircle } from 'lucide-react';
import { useDashboardStore } from '../../store/useDashboard';
import type { AlertsConfigUpdatePayload } from '../../types/dashboard';
import { DiscordAlertsCard } from './DiscordAlertsCard';
import { TunnelControlCard } from './TunnelControlCard';
import { AlertDeliveryLogCard } from './AlertDeliveryLogCard';

interface AlertsTunnelViewProps {
  onSaveAlertsConfig: (payload: AlertsConfigUpdatePayload) => void;
  onSendTestAlert: () => void;
  onPurgeAlerts: (limit: number, botOnly: boolean) => void;
  onRefreshAlertsHistory: () => void;
  onRestartTunnel: () => void;
  onRestartServer: () => void;
}

export const AlertsTunnelView: React.FC<AlertsTunnelViewProps> = ({
  onSaveAlertsConfig,
  onSendTestAlert,
  onPurgeAlerts,
  onRefreshAlertsHistory,
  onRestartTunnel,
  onRestartServer,
}) => {
  const alertsStatus = useDashboardStore((s) => s.alertsStatus);

  const failedCount = alertsStatus?.failed_count ?? 0;

  return (
    <div className="space-y-4">
      {/* Top 4 Pipeline KPI Cards */}
      <section aria-label="Alert pipeline statistics" className="grid grid-cols-2 lg:grid-cols-4 gap-3">
        <div className="ops-card p-4 flex flex-col justify-between gap-2">
          <div className="flex items-center justify-between text-xs text-ops-secondary">
            <span>Webhook Pipeline</span>
            <BellRing className="w-3.5 h-3.5 text-ops-accent" />
          </div>
          <div
            className={`text-lg font-semibold ${
              alertsStatus?.discord_webhook_configured ? 'text-ops-ok' : 'text-ops-warn'
            }`}
          >
            {alertsStatus
              ? alertsStatus.discord_webhook_configured
                ? 'Configured'
                : 'Not Set'
              : '—'}
          </div>
          <div className="font-mono text-[11px] text-ops-muted truncate">
            {alertsStatus?.discord_webhook_masked || 'No webhook URL saved'}
          </div>
        </div>

        <div className="ops-card p-4 flex flex-col justify-between gap-2">
          <div className="flex items-center justify-between text-xs text-ops-secondary">
            <span>Delivered</span>
            <CheckCircle2 className="w-3.5 h-3.5 text-ops-ok" />
          </div>
          <div className="num font-mono text-2xl font-semibold text-ops-text">
            {alertsStatus ? alertsStatus.delivered_count : '—'}
          </div>
          <div className="num font-mono text-[11px] text-ops-muted">
            Queue depth: {alertsStatus ? alertsStatus.queue_size : '—'}
          </div>
        </div>

        <div className="ops-card p-4 flex flex-col justify-between gap-2">
          <div className="flex items-center justify-between text-xs text-ops-secondary">
            <span>Failed</span>
            <XCircle
              className={`w-3.5 h-3.5 ${failedCount > 0 ? 'text-ops-danger' : 'text-ops-muted'}`}
            />
          </div>
          <div
            className={`num font-mono text-2xl font-semibold ${
              failedCount > 0 ? 'text-ops-danger' : 'text-ops-text'
            }`}
          >
            {alertsStatus ? failedCount : '—'}
          </div>
          <div className="font-mono text-[11px] text-ops-muted">
            {failedCount > 0 ? 'Inspect delivery log below' : 'Zero delivery errors'}
          </div>
        </div>

        <div className="ops-card p-4 flex flex-col justify-between gap-2">
          <div className="flex items-center justify-between text-xs text-ops-secondary">
            <span>Suppressed</span>
            <ShieldAlert className="w-3.5 h-3.5 text-ops-warn" />
          </div>
          <div className="num font-mono text-2xl font-semibold text-ops-text">
            {alertsStatus ? alertsStatus.suppressed_count : '—'}
          </div>
          <div className="num font-mono text-[11px] text-ops-muted">
            Cooldown:{' '}
            {alertsStatus ? `${alertsStatus.min_alert_interval_seconds}s` : '—'}
          </div>
        </div>
      </section>

      {/* Control Plane Split */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-4 items-start">
        <div className="lg:col-span-7">
          <DiscordAlertsCard
            onSaveConfig={onSaveAlertsConfig}
            onSendTest={onSendTestAlert}
            onPurgeMessages={onPurgeAlerts}
          />
        </div>
        <div className="lg:col-span-5 lg:sticky lg:top-[calc(env(safe-area-inset-top)+7rem)]">
          <TunnelControlCard
            onRestartTunnel={onRestartTunnel}
            onRestartServer={onRestartServer}
          />
        </div>
      </div>

      {/* Delivery Log */}
      <AlertDeliveryLogCard onRefresh={onRefreshAlertsHistory} />
    </div>
  );
};
