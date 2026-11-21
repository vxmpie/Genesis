import React, { useState } from 'react';
import {
  AlertTriangle,
  Check,
  Copy,
  ExternalLink,
  Globe,
  Loader2,
  Power,
  RotateCw,
} from 'lucide-react';
import { useDashboardStore } from '../../store/useDashboard';
import { copyTextToClipboard } from '../../lib/format';

interface TunnelControlCardProps {
  onRestartTunnel: () => void;
  onRestartServer: () => void;
}

export const TunnelControlCard: React.FC<TunnelControlCardProps> = ({
  onRestartTunnel,
  onRestartServer,
}) => {
  const tunnel = useDashboardStore((s) => s.tunnel);
  const config = useDashboardStore((s) => s.config);
  const isRestartingTunnel = useDashboardStore((s) => s.isRestartingTunnel);
  const addToast = useDashboardStore((s) => s.addToast);

  const [copiedKey, setCopiedKey] = useState<'public' | 'local' | null>(null);
  const [confirmServerRestart, setConfirmServerRestart] = useState(false);
  const [restartingServer, setRestartingServer] = useState(false);

  const handleCopy = async (text: string, key: 'public' | 'local') => {
    const ok = await copyTextToClipboard(text);
    if (ok) {
      setCopiedKey(key);
      addToast('info', 'URL copied to clipboard');
      setTimeout(() => setCopiedKey(null), 2000);
    } else {
      addToast('error', 'Failed to copy URL');
    }
  };

  const statusMeta = (() => {
    switch (tunnel?.status) {
      case 'online':
        return {
          label: 'Online',
          cls: 'bg-ops-ok/10 text-ops-ok border-ops-ok/30',
        };
      case 'connecting':
      case 'restarting':
        return {
          label: tunnel.status === 'restarting' ? 'Restarting' : 'Connecting',
          cls: 'bg-ops-warn/10 text-ops-warn border-ops-warn/30',
        };
      case 'offline':
        return {
          label: 'Offline',
          cls: 'bg-ops-danger/10 text-ops-danger border-ops-danger/30',
        };
      case 'local_only':
        return {
          label: 'Local Only',
          cls: 'bg-ops-inset text-ops-secondary border-ops-border',
        };
      default:
        return {
          label: tunnel?.status || 'Initializing',
          cls: 'bg-ops-inset text-ops-muted border-ops-border',
        };
    }
  })();

  const isLocalOnly = tunnel?.provider === 'local_only' || tunnel?.status === 'local_only';
  const publicUrl = tunnel?.tunnel_url || '';
  const localUrl = tunnel?.local_url || '';

  return (
    <div className="ops-card p-4 flex flex-col gap-4">
      <div className="space-y-4">
        {/* Header */}
        <div className="flex items-center justify-between gap-2">
          <div className="flex items-center gap-2">
            <Globe className="w-4 h-4 text-ops-accent shrink-0" />
            <h2 className="text-xs font-semibold text-ops-text uppercase tracking-wider">
              Public Tunnel & Ingress
            </h2>
          </div>
          <div className="flex items-center gap-1.5">
            {tunnel?.provider && (
              <span className="text-[10px] font-mono px-1.5 py-0.5 rounded bg-ops-inset border border-ops-border text-ops-secondary uppercase">
                {tunnel.provider}
              </span>
            )}
            <span
              className={`text-[10px] font-mono px-2 py-0.5 rounded border ${statusMeta.cls}`}
            >
              {statusMeta.label}
            </span>
          </div>
        </div>

        {/* Public URL Box */}
        <div className="p-3 rounded-md bg-ops-inset border border-ops-border space-y-2">
          <div className="text-[11px] font-medium text-ops-secondary">Public Ingress URL</div>
          <div className="flex items-center gap-2">
            <div
              className="flex-1 min-w-0 font-mono text-xs text-ops-text bg-ops-surface border border-ops-border rounded px-2.5 py-2 truncate"
              title={publicUrl || undefined}
            >
              {publicUrl || (isLocalOnly ? 'Disabled (Local Only)' : 'Waiting for tunnel URL...')}
            </div>
            <button
              type="button"
              disabled={!publicUrl}
              onClick={() => handleCopy(publicUrl, 'public')}
              className="ops-btn h-8 px-2.5 bg-ops-elevated hover:bg-ops-border border border-ops-border text-xs text-ops-text shrink-0"
              title="Copy public URL"
            >
              {copiedKey === 'public' ? (
                <>
                  <Check className="w-3.5 h-3.5 text-ops-ok" />
                  <span>Copied</span>
                </>
              ) : (
                <>
                  <Copy className="w-3.5 h-3.5" />
                  <span>Copy</span>
                </>
              )}
            </button>
            {publicUrl && (
              <a
                href={publicUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="ops-btn h-8 w-8 bg-ops-elevated hover:bg-ops-border border border-ops-border text-ops-text shrink-0"
                title="Open public URL in new tab"
              >
                <ExternalLink className="w-3.5 h-3.5" />
              </a>
            )}
          </div>
        </div>

        {/* Local Ingress & Metadata */}
        <div className="p-3 rounded-md bg-ops-inset border border-ops-border space-y-2.5 text-xs">
          <div className="flex items-center justify-between gap-2">
            <span className="text-ops-secondary">Local Bind</span>
            <div className="flex items-center gap-1.5 min-w-0">
              <span className="num font-mono text-ops-text truncate">{localUrl || '—'}</span>
              {localUrl && (
                <button
                  type="button"
                  onClick={() => handleCopy(localUrl, 'local')}
                  aria-label="Copy local URL"
                  className="p-1 rounded text-ops-muted hover:text-ops-text hover:bg-ops-elevated"
                >
                  {copiedKey === 'local' ? (
                    <Check className="w-3 h-3 text-ops-ok" />
                  ) : (
                    <Copy className="w-3 h-3" />
                  )}
                </button>
              )}
            </div>
          </div>

          <div className="flex items-center justify-between gap-2 border-t border-ops-border pt-2">
            <span className="text-ops-secondary">Started At</span>
            <span className="num font-mono text-ops-text">{tunnel?.started_at || '—'}</span>
          </div>

          <div className="flex items-center justify-between gap-2 border-t border-ops-border pt-2">
            <span className="text-ops-secondary">Configured Provider</span>
            <span className="font-mono text-ops-text uppercase">
              {config?.tunnel.provider || '—'}
            </span>
          </div>

          {config?.tunnel.provider === 'tailscale' ? (
            <div className="flex items-center justify-between gap-2 border-t border-ops-border pt-2">
              <span className="text-ops-secondary">Tailscale URL</span>
              <span className="font-mono text-ops-text truncate max-w-[200px]">
                {config.tunnel.tailscale_url || tunnel?.tunnel_url || 'Auto-detect (tailscale serve)'}
              </span>
            </div>
          ) : config?.tunnel.provider === 'cloudflared' || config?.tunnel.provider === 'local_only' ? null : (
            <>
              <div className="flex items-center justify-between gap-2 border-t border-ops-border pt-2">
                <span className="text-ops-secondary">ngrok Authtoken</span>
                <span
                  className={`font-mono ${
                    config?.tunnel.ngrok_authtoken_configured ? 'text-ops-ok' : 'text-ops-muted'
                  }`}
                >
                  {config
                    ? config.tunnel.ngrok_authtoken_configured
                      ? 'Configured (Masked)'
                      : 'Not Set'
                    : '—'}
                </span>
              </div>

              <div className="flex items-center justify-between gap-2 border-t border-ops-border pt-2">
                <span className="text-ops-secondary">ngrok Domain</span>
                <span className="font-mono text-ops-text truncate max-w-[180px]">
                  {config?.tunnel.ngrok_domain || '—'}
                </span>
              </div>
            </>
          )}
        </div>

        {/* Last Error Banner */}
        {tunnel?.last_error && (
          <div className="p-2.5 rounded-md bg-ops-danger/10 border border-ops-danger/30 text-xs text-ops-danger flex items-start gap-2">
            <AlertTriangle className="w-4 h-4 shrink-0 mt-0.5" />
            <span className="font-mono break-words">{tunnel.last_error}</span>
          </div>
        )}

        {/* Restart Tunnel Action */}
        <div className="space-y-1.5">
          <button
            type="button"
            disabled={isLocalOnly || isRestartingTunnel}
            onClick={onRestartTunnel}
            className="ops-btn w-full h-9 px-3 bg-ops-elevated hover:bg-ops-border border border-ops-borderStrong text-xs text-ops-text font-medium"
          >
            {isRestartingTunnel ? (
              <>
                <Loader2 className="w-3.5 h-3.5 animate-spin" />
                <span>Restarting Tunnel...</span>
              </>
            ) : (
              <>
                <RotateCw className="w-3.5 h-3.5 text-ops-accent" />
                <span>Restart Public Tunnel</span>
              </>
            )}
          </button>
          {isLocalOnly && (
            <p className="text-[11px] text-ops-muted">
              Tunnel restart is unavailable in local-only mode. Configure an ngrok authtoken or place
              cloudflared.exe in Dashboard/ to enable remote ingress.
            </p>
          )}
        </div>
      </div>

      {/* Core Server Danger Zone */}
      <div className="pt-3 border-t border-ops-border space-y-2">
        <div className="flex items-center justify-between gap-2">
          <div>
            <div className="text-xs font-medium text-ops-text">Core Server Process</div>
            <div className="text-[11px] text-ops-muted">
              Exits backend process for supervisor/Task Scheduler restart.
            </div>
          </div>

          {confirmServerRestart ? (
            <div className="inline-flex items-center gap-1.5 shrink-0">
              <button
                type="button"
                disabled={restartingServer}
                onClick={() => {
                  setRestartingServer(true);
                  setConfirmServerRestart(false);
                  onRestartServer();
                  setTimeout(() => setRestartingServer(false), 3000);
                }}
                className="ops-btn h-8 px-2.5 bg-ops-danger hover:bg-red-500 text-white text-xs font-semibold"
              >
                Confirm Restart
              </button>
              <button
                type="button"
                onClick={() => setConfirmServerRestart(false)}
                className="ops-btn h-8 px-2.5 bg-ops-elevated border border-ops-border text-ops-secondary text-xs"
              >
                Cancel
              </button>
            </div>
          ) : (
            <button
              type="button"
              disabled={restartingServer}
              onClick={() => setConfirmServerRestart(true)}
              className="ops-btn h-8 px-3 bg-ops-danger/10 hover:bg-ops-danger/20 border border-ops-danger/30 text-ops-danger text-xs shrink-0"
            >
              <Power className="w-3.5 h-3.5" />
              <span>Restart Server</span>
            </button>
          )}
        </div>
      </div>
    </div>
  );
};
