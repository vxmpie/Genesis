/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        genesis: {
          bg: "#0A0A0F",
          card: "#12131F",
          elevated: "#181928",
          input: "#0E0F18",
          border: "rgba(255, 255, 255, 0.08)",
          borderGlow: "rgba(0, 229, 255, 0.35)",
          accent: "#FF3C3C",
          accentGlow: "rgba(255, 60, 60, 0.3)",
          cyan: "#00E5FF",
          cyanGlow: "rgba(0, 229, 255, 0.25)",
          green: "#00FF88",
          greenGlow: "rgba(0, 255, 136, 0.25)",
          amber: "#FFB800",
          amberGlow: "rgba(255, 184, 0, 0.25)",
          blue: "#3B82F6",
          purple: "#A855F7",
        }
      },
      fontFamily: {
        sans: ["Inter", "-apple-system", "BlinkMacSystemFont", "sans-serif"],
        mono: ["JetBrains Mono", "Consolas", "monospace"],
      },
      boxShadow: {
        'glow-accent': '0 0 20px rgba(255, 60, 60, 0.3)',
        'glow-cyan': '0 0 20px rgba(0, 229, 255, 0.25)',
        'glow-green': '0 0 20px rgba(0, 255, 136, 0.25)',
        'glow-amber': '0 0 20px rgba(255, 184, 0, 0.25)',
        'card': '0 8px 32px rgba(0, 0, 0, 0.5), inset 0 1px 0 rgba(255, 255, 255, 0.06)',
      },
      borderRadius: {
        'card': '12px',
      },
      gridTemplateColumns: {
        '16': 'repeat(16, minmax(0, 1fr))',
      }
    },
  },
  plugins: [],
}
