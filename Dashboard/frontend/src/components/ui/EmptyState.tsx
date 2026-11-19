import React from 'react';

interface EmptyStateProps {
  title: string;
  description?: string;
  icon?: React.ReactNode;
  action?: React.ReactNode;
  className?: string;
}

export const EmptyState: React.FC<EmptyStateProps> = ({
  title,
  description,
  icon,
  action,
  className = '',
}) => (
  <div
    className={`py-7 px-4 rounded-md border border-ops-border bg-ops-inset flex flex-col items-center justify-center text-center gap-1.5 ${className}`}
  >
    {icon && <div className="text-ops-muted mb-0.5">{icon}</div>}
    <div className="text-xs font-medium text-ops-secondary">{title}</div>
    {description && (
      <div className="text-[11px] font-mono text-ops-muted max-w-md">{description}</div>
    )}
    {action && <div className="mt-2">{action}</div>}
  </div>
);
