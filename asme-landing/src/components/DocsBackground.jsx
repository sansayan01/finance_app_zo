import { useEffect, useRef } from "react";

export default function DocsBackground() {
  const canvasRef = useRef(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext("2d");
    let animationFrameId;

    // Handle resize
    const resizeCanvas = () => {
      canvas.width = window.innerWidth;
      canvas.height = window.innerHeight;
    };
    window.addEventListener("resize", resizeCanvas);
    resizeCanvas();

    // Node particle definition
    const particles = [];
    const particleCount = Math.min(60, Math.floor((window.innerWidth * window.innerHeight) / 25000));
    const connectionDistance = 120;

    // Colors themed to match MicroFlow (indigo/cyan)
    const baseColors = [
      { r: 139, g: 92, b: 246 },  // Purple/Indigo
      { r: 6, g: 182, b: 212 },   // Cyan
      { r: 236, g: 72, b: 153 },  // Pink
    ];

    // Create particles
    for (let i = 0; i < particleCount; i++) {
      const color = baseColors[Math.floor(Math.random() * baseColors.length)];
      particles.push({
        x: Math.random() * canvas.width,
        y: Math.random() * canvas.height,
        vx: (Math.random() - 0.5) * 0.4, // ultra-slow drift
        vy: (Math.random() - 0.5) * 0.4,
        radius: Math.random() * 2 + 1.5,
        color: color,
        pulseSpeed: 0.02 + Math.random() * 0.03,
        pulseVal: Math.random() * Math.PI,
      });
    }

    // Animation Loop
    const draw = () => {
      ctx.clearRect(0, 0, canvas.width, canvas.height);

      // Draw background space dark glow
      const radialGlow = ctx.createRadialGradient(
        canvas.width * 0.5,
        canvas.height * 0.3,
        10,
        canvas.width * 0.5,
        canvas.height * 0.3,
        Math.max(canvas.width, canvas.height) * 0.8
      );
      radialGlow.addColorStop(0, "#08031d");
      radialGlow.addColorStop(1, "#02000a");
      ctx.fillStyle = radialGlow;
      ctx.fillRect(0, 0, canvas.width, canvas.height);

      // Update & Draw Particles (Floating Nodes)
      particles.forEach((p) => {
        p.x += p.vx;
        p.y += p.vy;

        // Boundary reflection
        if (p.x < 0 || p.x > canvas.width) p.vx *= -1;
        if (p.y < 0 || p.y > canvas.height) p.vy *= -1;

        // Pulsing glow size
        p.pulseVal += p.pulseSpeed;
        const currentRadius = p.radius + Math.sin(p.pulseVal) * 0.8;

        // Draw particle glow
        ctx.beginPath();
        const glowGrad = ctx.createRadialGradient(
          p.x, p.y, 0,
          p.x, p.y, currentRadius * 4
        );
        glowGrad.addColorStop(0, `rgba(${p.color.r}, ${p.color.g}, ${p.color.b}, 0.6)`);
        glowGrad.addColorStop(1, `rgba(${p.color.r}, ${p.color.g}, ${p.color.b}, 0)`);
        ctx.fillStyle = glowGrad;
        ctx.arc(p.x, p.y, currentRadius * 4, 0, Math.PI * 2);
        ctx.fill();

        // Draw particle center dot
        ctx.beginPath();
        ctx.arc(p.x, p.y, currentRadius, 0, Math.PI * 2);
        ctx.fillStyle = `rgba(${p.color.r}, ${p.color.g}, ${p.color.b}, 0.8)`;
        ctx.fill();
      });

      // Draw Connection Lines (Edges)
      for (let i = 0; i < particles.length; i++) {
        for (let j = i + 1; j < particles.length; j++) {
          const dx = particles[i].x - particles[j].x;
          const dy = particles[i].y - particles[j].y;
          const dist = Math.sqrt(dx * dx + dy * dy);

          if (dist < connectionDistance) {
            const opacity = (1 - dist / connectionDistance) * 0.15;
            ctx.beginPath();
            ctx.moveTo(particles[i].x, particles[i].y);
            ctx.lineTo(particles[j].x, particles[j].y);

            // Line gradient matches connecting node colors
            const grad = ctx.createLinearGradient(
              particles[i].x, particles[i].y,
              particles[j].x, particles[j].y
            );
            grad.addColorStop(0, `rgba(${particles[i].color.r}, ${particles[i].color.g}, ${particles[i].color.b}, ${opacity})`);
            grad.addColorStop(1, `rgba(${particles[j].color.r}, ${particles[j].color.g}, ${particles[j].color.b}, ${opacity})`);

            ctx.strokeStyle = grad;
            ctx.lineWidth = 0.8;
            ctx.stroke();
          }
        }
      }

      animationFrameId = requestAnimationFrame(draw);
    };

    draw();

    // Cleanup
    return () => {
      window.removeEventListener("resize", resizeCanvas);
      cancelAnimationFrame(animationFrameId);
    };
  }, []);

  return (
    <div className="fixed inset-0 z-0 overflow-hidden pointer-events-none">
      {/* Canvas holding the Graphify Constellation */}
      <canvas ref={canvasRef} className="block w-full h-full" />

      {/* Cyber Dot Grid Overlay */}
      <div className="absolute inset-0 opacity-[0.03] dot-grid pointer-events-none" />

      {/* Dark frosted glass overlay — so text is 100% readable and contrast is high */}
      <div className="absolute inset-0 bg-gradient-to-b from-[#030014]/70 via-[#030014]/80 to-[#030014]/95 pointer-events-none" />
    </div>
  );
}
