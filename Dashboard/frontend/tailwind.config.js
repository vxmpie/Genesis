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
      },
      fontFamily: {
        sans: ["Inter", "-apple-system", "BlinkMacSystemFont", "sans-serif"],
        mono: ["JetBrains Mono", "Consolas", "monospace"],
      },
      boxShadow: {
        "card": "0 1px 2px rgba(0, 0, 0, 0.35)",
      },
      borderRadius: {
        "card": "8px",
      },
    },
  },
  plugins: [],
};
