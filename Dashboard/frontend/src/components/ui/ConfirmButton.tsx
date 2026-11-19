import React, { useEffect, useState } from 'react';
import { Loader2 } from 'lucide-react';

interface ConfirmButtonProps {
  label: string;
  confirmLabel?: string;
  pendingLabel?: string;
  icon?: React.ReactNode;
  pending?: boolean;
  disabled?: boolean;
  tone?: 'danger' | 'warn' | 'accent';
  compact?: boolean;
  title?: string;
  onConfirm: () => void;
}

const IDLE_TONES: Record<'danger' | 'warn' | 'accent', string> = {
  danger: 'bg-ops-danger/10 hover:bg-ops-danger/20 text-ops-danger border-ops-danger/30',
  warn: 'bg-ops-warn/10 hover:bg-ops-warn/20 text-ops-warn border-ops-warn/30',
  accent: 'bg-ops-accent hover:bg-blue-500 text-white border-ops-accent',
};

const CONFIRM_TONES: Record<'danger' | 'warn' | 'accent', string> = {
  danger: 'bg-ops-danger hover:bg-red-500 text-white border-ops-danger',
  warn: 'bg-ops-warn hover:bg-amber-400 text-black border-ops-warn',
  accent: 'bg-ops-accent hover:bg-blue-500 text-white border-ops-accent',
};

export const ConfirmButton: React.FC<ConfirmButtonProps> = ({
  label,
  confirmLabel = 'Confirm',
  pendingLabel,
  icon,
  pending = false,
  disabled = false,
  tone = 'danger',
  compact = false,
  title,
  onConfirm,
}) => {
  const [armed, setArmed] = useState(false);
  const inactive = disabled || pending;
  const [prevInactive, setPrevInactive] = useState(inactive);

  if (inactive !== prevInactive) {
    setPrevInactive(inactive);
    if (inactive && armed) {
      setArmed(false);
    }
  }

  useEffect(() => {
    if (!armed) return;
    const timer = setTimeout(() => setArmed(false), 6000);
    return () => clearTimeout(timer);
  }, [armed]);

  if (armed && !inactive) {
    return (
      <div className="inline-flex items-center gap-1 shrink-0">
        <button
          type="button"
          onClick={() => {
            setArmed(false);
            onConfirm();
          }}
          className={`ops-btn border font-semibold ${
            compact ? 'h-7 px-2 text-[11px]' : 'h-8 px-2.5 text-xs'
          } ${CONFIRM_TONES[tone]}`}
        >
          <span>{confirmLabel}</span>
        </button>
        <button
          type="button"
          onClick={() => setArmed(false)}
          className={`ops-btn bg-ops-elevated hover:bg-ops-border text-ops-secondary border border-ops-border ${
            compact ? 'h-7 px-2 text-[11px]' : 'h-8 px-2 text-xs'
          }`}
        >
          Cancel
        </button>
      </div>
    );
  }

  return (
    <button
      type="button"
      disabled={disabled || pending}
      title={title}
      onClick={() => setArmed(true)}
      className={`ops-btn border ${
        compact ? 'h-7 px-2 text-[11px]' : 'h-8 px-2.5 text-xs'
      } ${IDLE_TONES[tone]}`}
    >
      {pending ? <Loader2 className="w-3.5 h-3.5 animate-spin shrink-0" /> : icon}
      <span>{pending && pendingLabel ? pendingLabel : label}</span>
    </button>
  );
};
