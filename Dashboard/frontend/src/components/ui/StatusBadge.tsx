import React from 'react';

export type SemanticTone = 'ok' | 'warn' | 'danger' | 'info' | 'accent' | 'muted';

interface StatusBadgeProps {
  tone?: SemanticTone;
  children: React.ReactNode;
  dot?: boolean;
  className?: string;
  title?: string;
}

const TONE_CLASSES: Record<SemanticTone, string> = {
  ok: 'bg-ops-ok/10 text-ops-ok border-ops-ok/30',
  warn: 'bg-ops-warn/10 text-ops-warn border-ops-warn/30',
  danger: 'bg-ops-danger/10 text-ops-danger border-ops-danger/30',
  info: 'bg-ops-telemetry/10 text-ops-telemetry border-ops-telemetry/30',
  accent: 'bg-ops-accent/10 text-ops-accent border-ops-accent/30',
  muted: 'bg-ops-inset text-ops-muted border-ops-border',
};

const DOT_CLASSES: Record<SemanticTone, string> = {
  ok: 'bg-ops-ok',
  warn: 'bg-ops-warn',
  danger: 'bg-ops-danger',
  info: 'bg-ops-telemetry',
  accent: 'bg-ops-accent',
  muted: 'bg-ops-muted',
};

export const StatusBadge: React.FC<StatusBadgeProps> = ({
  tone = 'muted',
  children,
  dot = false,
  className = '',
  title,
}) => (
  <span
    title={title}
    className={`inline-flex items-center gap-1.5 text-[10px] font-mono px-1.5 py-0.5 rounded border whitespace-nowrap ${TONE_CLASSES[tone]} ${className}`}
  >
    {dot && <span className={`w-1.5 h-1.5 rounded-full shrink-0 ${DOT_CLASSES[tone]}`} />}
    <span>{children}</span>
  </span>
);
