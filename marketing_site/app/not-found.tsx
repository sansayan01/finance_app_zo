import Link from 'next/link';
import { Nav } from '@/components/layout/Nav';
import { Footer } from '@/components/layout/Footer';
import { Container } from '@/components/ui/container';

export default function NotFound() {
  return (
    <>
      <Nav />
      <main className="flex min-h-[60vh] items-center">
        <Container className="text-center">
          <h1 className="font-display text-display-1 font-bold text-text">404</h1>
          <p className="mt-4 text-lg text-text-muted">
            The page you&apos;re looking for doesn&apos;t exist.
          </p>
          <div className="mt-8 flex justify-center gap-4">
            <Link
              href="/"
              className="inline-flex h-10 items-center rounded-lg bg-brand px-4 text-sm font-medium text-white shadow-brand transition-opacity hover:opacity-90"
            >
              Go Home
            </Link>
            <Link
              href="/blog"
              className="inline-flex h-10 items-center rounded-lg border border-border px-4 text-sm font-medium text-text transition-colors hover:bg-surface-2"
            >
              Read Blog
            </Link>
          </div>
        </Container>
      </main>
      <Footer />
    </>
  );
}
