import React from 'react';
import { Sidebar } from './Sidebar';
import { TopBar } from './TopBar';
import { MobileBottomNav } from './MobileBottomNav';

interface AppShellProps {
  children: React.ReactNode;
}

export const AppShell: React.FC<AppShellProps> = ({ children }) => {
  return (
    <div className="min-h-screen bg-ops-bg text-ops-text flex font-sans">
      <Sidebar />
      <div className="flex-1 min-w-0 flex flex-col min-h-screen">
        <TopBar />
        <main className="flex-1 w-full max-w-[1440px] mx-auto px-3 sm:px-5 lg:px-6 py-4 sm:py-5 pb-24 lg:pb-6">
          {children}
        </main>
      </div>
      <MobileBottomNav />
    </div>
  );
};
