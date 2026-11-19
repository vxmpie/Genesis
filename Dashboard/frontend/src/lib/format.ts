// --- Formatting Helpers ---
export function formatUptime(seconds: number | null | undefined): string {
  if (typeof seconds !== 'number' || !Number.isFinite(seconds) || seconds < 0) {
    return '—';
  }
  const total = Math.floor(seconds);
  const d = Math.floor(total / 86400);
  const h = Math.floor((total % 86400) / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  const hms = `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  return d > 0 ? `${d}d ${hms}` : hms;
}

export function formatCompactUptime(seconds: number | null | undefined): string {
  if (typeof seconds !== 'number' || !Number.isFinite(seconds) || seconds < 0) {
    return '—';
  }
  const total = Math.floor(seconds);
  const d = Math.floor(total / 86400);
  const h = Math.floor((total % 86400) / 3600);
  const m = Math.floor((total % 3600) / 60);
  if (d > 0) return `${d}d ${h}h ${m}m`;
  if (h > 0) return `${h}h ${m}m`;
  return `${m}m`;
}

export function formatPercent(val: number | null | undefined, digits = 0): string {
  if (typeof val !== 'number' || !Number.isFinite(val)) {
    return '—';
  }
  return `${val.toFixed(digits)}%`;
}

export function formatGb(val: number | null | undefined, digits = 1): string {
  if (typeof val !== 'number' || !Number.isFinite(val)) {
    return '—';
  }
  return `${val.toFixed(digits)} GB`;
}

export function formatMb(val: number | null | undefined, digits = 0): string {
  if (typeof val !== 'number' || !Number.isFinite(val)) {
    return '—';
  }
  return `${val.toFixed(digits)} MB`;
}

export function formatMs(val: number | null | undefined, digits = 1): string {
  if (typeof val !== 'number' || !Number.isFinite(val) || val <= 0) {
    return '—';
  }
  return `${val.toFixed(digits)} ms`;
}

export function formatIsoToLocalTime(iso: string | null | undefined): string {
  if (!iso) return '—';
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return '—';
  return date.toLocaleTimeString([], {
    hour12: false,
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  });
}

export function formatEventTime(timeStr: string | null | undefined): string {
  if (!timeStr) return '—';
  const parts = timeStr.split(' ');
  return parts.length >= 2 ? parts[1] : timeStr;
}

export async function copyTextToClipboard(text: string): Promise<boolean> {
  if (!text) return false;
  try {
    if (navigator.clipboard && typeof navigator.clipboard.writeText === 'function') {
      await navigator.clipboard.writeText(text);
      return true;
    }
  } catch {
  }
  try {
    const textarea = document.createElement('textarea');
    textarea.value = text;
    textarea.setAttribute('readonly', '');
    textarea.style.position = 'fixed';
    textarea.style.opacity = '0';
    document.body.appendChild(textarea);
    textarea.select();
    const ok = document.execCommand('copy');
    document.body.removeChild(textarea);
    return ok;
  } catch {
    return false;
  }
}
