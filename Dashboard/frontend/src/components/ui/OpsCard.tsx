import React from 'react';

interface OpsCardProps {
  children: React.ReactNode;
  className?: string;
}

export const OpsCard: React.FC<OpsCardProps> = ({ children, className = '' }) => (
  <section className={`ops-card p-4 ${className}`}>{children}</section>
);

interface CardHeaderProps {
  icon?: React.ReactNode;
  title: string;
  subtitle?: string;
  badge?: React.ReactNode;
  actions?: React.ReactNode;
}

export const CardHeader: React.FC<CardHeaderProps> = ({
  icon,
  title,
  subtitle,
  badge,
  actions,
}) => (
  <div className="space-y-1">
    <div className="flex flex-wrap items-center justify-between gap-2.5">
      <div className="flex items-center gap-2 min-w-0 flex-wrap">
        <div className="flex items-center gap-2 min-w-0">
          {icon && <span className="shrink-0">{icon}</span>}
          <h2 className="text-xs font-semibold text-ops-text uppercase tracking-wider truncate">
            {title}
          </h2>
        </div>
        {badge && <span className="shrink-0">{badge}</span>}
      </div>
      {actions && <div className="flex items-center gap-1.5 shrink-0">{actions}</div>}
    </div>
    {subtitle && <p className="text-xs text-ops-secondary">{subtitle}</p>}
  </div>
);
