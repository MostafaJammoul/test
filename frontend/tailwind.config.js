/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        // Custom blockchain theme colors
        primary: {
          50: '#eff6ff',
          100: '#dbeafe',
          200: '#bfdbfe',
          300: '#93c5fd',
          400: '#60a5fa',
          500: '#3b82f6',
          600: '#2563eb',
          700: '#1d4ed8',
          800: '#1e40af',
          900: '#1e3a8a',
        },
        blockchain: {
          hot: '#f59e0b',  // Amber for hot chain
          cold: '#3b82f6', // Blue for cold chain
        },
        role: {
          admin: '#dc2626',       // Red for SystemAdmin
          investigator: '#10b981', // Green for BlockchainInvestigator
          auditor: '#6366f1',     // Indigo for BlockchainAuditor
          court: '#8b5cf6',       // Purple for BlockchainCourt
        }
      },
    },
  },
  plugins: [],
}
