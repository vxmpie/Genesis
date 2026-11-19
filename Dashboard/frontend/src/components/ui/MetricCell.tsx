import React from 'react';
import type { SemanticTone } from './StatusBadge';

interface MetricCellProps {
  label: string;
  value: React.ReactNode;
  subValue?: React.ReactNode;
  tone?: SemanticTone;
  className?: string;
}

const VALUE_TONES: Record<SemanticTone, string> = {
  ok: 'text-ops-ok',
  warn: 'text-ops-warn',
  danger: 'text-ops-danger',
  info: 'text-ops-telemetry',
  accent: 'text-ops-accent',
  muted: 'text-ops-text',
};

export const MetricCell: React.FC<MetricCellProps> = ({
  label,
  value,
  subValue,
  tone = 'muted',
  className = '',
}) => (
  <div
    className={`p-3 rounded-md bg-ops-inset border border-ops-border flex flex-col justify-between gap-1 min-w-0 ${className}`}
  >
    <span className="text-[10px] font-mono uppercase tracking-wider text-ops-muted truncate">
      {label}
    </span>
    <div className={`num font-mono text-sm font-semibold truncate ${VALUE_TONES[tone]}`}>
      {value}
    </div>
    {subValue !== undefined && (
      <div className="num text-[11px] font-mono text-ops-secondary truncate">{subValue}</div>
    )}
  </div>
);
