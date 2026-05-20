import { ImageResponse } from 'next/og';

export const runtime = 'edge';
export const alt = 'MicroFlow Pro';
export const size = { width: 1200, height: 630 };
export const contentType = 'image/png';

export default function OGImage() {
  return new ImageResponse(
    (
      <div
        style={{
          background: 'linear-gradient(135deg, #6366f1 0%, #8b5cf6 50%, #0ea5e9 100%)',
          width: '100%',
          height: '100%',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          fontFamily: 'system-ui, sans-serif',
        }}
      >
        <h1
          style={{
            fontSize: 72,
            fontWeight: 800,
            color: 'white',
            margin: 0,
            letterSpacing: '-0.02em',
          }}
        >
          MicroFlow Pro
        </h1>
        <p
          style={{
            fontSize: 28,
            color: 'rgba(255,255,255,0.85)',
            marginTop: 16,
            maxWidth: 700,
            textAlign: 'center',
            lineHeight: 1.4,
          }}
        >
          Run your MFI field operations from one app, online or off.
        </p>
      </div>
    ),
    { ...size },
  );
}
