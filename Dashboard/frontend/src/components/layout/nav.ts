import type React from 'react';
import {
  Activity,
  BellRing,
  Cpu,
  LayoutDashboard,
  MonitorSmartphone,
} from 'lucide-react';
import type { WorkspaceView } from '../../types/dashboard';

export interface NavItemConfig {
  id: WorkspaceView;
  label: string;
  shortLabel: string;
  shortcut: string;
  description: string;
  icon: React.ComponentType<{ className?: string }>;
}

export const NAV_ITEMS: readonly NavItemConfig[] = [
  {
    id: 'overview',
    label: 'Overview',
    shortLabel: 'Overview',
    shortcut: '1',
    description: 'Executive host telemetry, fleet status, and core controls',
    icon: LayoutDashboard,
  },
  {
    id: 'instances',
    label: 'Instances',
    shortLabel: 'Instances',
    shortcut: '2',
    description: 'MuMu emulator slots, Roblox presence, and VM disk sentinel',
    icon: MonitorSmartphone,
  },
  {
    id: 'system',
    label: 'System',
    shortLabel: 'System',
    shortcut: '3',
    description: 'Auto-Boost, kernel tuning, hardening drift, and deep clean',
    icon: Cpu,
  },
  {
    id: 'telemetry',
    label: 'Telemetry & Net',
    shortLabel: 'Telemetry',
    shortcut: '4',
    description: 'Time-series charts, per-core matrix, network, and event logs',
    icon: Activity,
  },
  {
    id: 'alerts',
    label: 'Alerts & Tunnel',
    shortLabel: 'Alerts',
    shortcut: '5',
    description: 'Discord notification pipeline, delivery log, and public tunnel',
    icon: BellRing,
  },
];
