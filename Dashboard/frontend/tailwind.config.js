/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        ops: {
          bg: "#09090B",
          chrome: "#0C0C0F",
          surface: "#111115",
          elevated: "#17171D",
          inset: "#0B0B0E",
          border: "#22222A",
          borderStrong: "#32323E",
          text: "#F4F4F5",
          secondary: "#A1A1AA",
          muted: "#71717A",
          accent: "#3B82F6",
          telemetry: "#06B6D4",
          ok: "#10B981",
          warn: "#F59E0B",
          danger: "#EF4444",
        },
        genesis: {
          bg: "#09090B",
          card: "#111115",
          elevated: "#17171D",
          input: "#0B0B0E",
          border: "#22222A",
          borderGlow: "#32323E",
          accent: "#EF4444",
          accentGlow: "rgba(239, 68, 68, 0.15)",
          cyan: "#06B6D4",
          cyanGlow: "rgba(6, 182, 212, 0.15)",
          green: "#10B981",
          greenGlow: "rgba(16, 185, 129, 0.15)",
          amber: "#F59E0B",
          amberGlow: "rgba(245, 158, 11, 0.15)",
          blue: "#3B82F6",
          purple: "#8B5CF6",
        },
      },
      fontFamily: {
        sans: ["Inter", "-apple-system", "BlinkMacSystemFont", "sans-serif"],
        mono: ["JetBrains Mono", "Consolas", "monospace"],
      },
      boxShadow: {
        "glow-accent": "none",
        "glow-cyan": "none",
        "glow-green": "none",
        "glow-amber": "none",
        "card": "0 1px 2px rgba(0, 0, 0, 0.35)",
      },
      borderRadius: {
        "card": "8px",
      },
      gridTemplateColumns: {
        "16": "repeat(16, minmax(0, 1fr))",
      },
    },
  },
  plugins: [],
};
