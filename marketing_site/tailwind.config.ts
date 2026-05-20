import type { Config } from 'tailwindcss';

export default {
  darkMode: 'class',
  content: [
    './app/**/*.{ts,tsx,mdx}',
    './components/**/*.{ts,tsx}',
    './content/**/*.mdx',
  ],
  theme: {
    extend: {
      colors: {
        indigo: {
          DEFAULT: 'rgb(var(--color-indigo) / <alpha-value>)',
          dark: 'rgb(var(--color-indigo-dark) / <alpha-value>)',
        },
        violet: 'rgb(var(--color-violet) / <alpha-value>)',
        cyan: 'rgb(var(--color-cyan) / <alpha-value>)',
        bg: 'rgb(var(--color-bg) / <alpha-value>)',
        surface: 'rgb(var(--color-surface) / <alpha-value>)',
        'surface-2': 'rgb(var(--color-surface-2) / <alpha-value>)',
        text: 'rgb(var(--color-text) / <alpha-value>)',
        'text-muted': 'rgb(var(--color-text-muted) / <alpha-value>)',
        border: 'rgb(var(--color-border) / <alpha-value>)',
        ring: 'rgb(var(--color-ring) / <alpha-value>)',
      },
      backgroundImage: {
        brand:
          'linear-gradient(135deg, rgb(var(--color-indigo)) 0%, rgb(var(--color-violet)) 100%)',
        'brand-soft':
          'linear-gradient(135deg, rgb(var(--color-indigo) / .85) 0%, rgb(var(--color-violet) / .85) 50%, rgb(var(--color-cyan) / .75) 100%)',
        'hero-glow':
          'radial-gradient(60% 50% at 50% 0%, rgb(var(--color-indigo) / .35) 0%, rgb(var(--color-violet) / .15) 35%, transparent 70%)',
      },
      fontFamily: {
        display: ['var(--font-outfit)', 'system-ui', 'sans-serif'],
        sans: ['var(--font-jakarta)', 'system-ui', 'sans-serif'],
      },
      fontSize: {
        'display-1': [
          'clamp(2.75rem, 5vw + 1rem, 4.5rem)',
          { lineHeight: '1.05', letterSpacing: '-0.02em' },
        ],
        'display-2': [
          'clamp(2rem, 3vw + 1rem, 3.25rem)',
          { lineHeight: '1.1', letterSpacing: '-0.015em' },
        ],
      },
      borderRadius: {
        xl2: '1.25rem',
        '2xl2': '1.75rem',
      },
      boxShadow: {
        glass:
          '0 8px 30px rgb(0 0 0 / 0.06), inset 0 1px 0 rgb(255 255 255 / 0.5)',
        'glass-dk':
          '0 8px 30px rgb(0 0 0 / 0.45), inset 0 1px 0 rgb(255 255 255 / 0.06)',
        brand: '0 18px 60px -20px rgb(99 102 241 / 0.55)',
      },
      spacing: {
        '18': '4.5rem',
        '22': '5.5rem',
        '30': '7.5rem',
      },
    },
  },
} satisfies Config;
