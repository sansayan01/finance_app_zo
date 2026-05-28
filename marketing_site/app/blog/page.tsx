import type { Metadata } from 'next';
import { buildMetadata } from '@/components/seo/buildMetadata';
import { getAllPosts } from '@/lib/mdx';
import { Container } from '@/components/ui/container';
import { Section } from '@/components/ui/section';
import { PostCard } from '@/components/blog/PostCard';

export const metadata: Metadata = buildMetadata({
  title: 'Blog',
  description:
    'Insights on microfinance operations, field collections, and digital transformation for MFIs.',
  path: '/blog',
});

export const revalidate = 3600;

export default async function BlogPage() {
  const posts = await getAllPosts();

  return (
    <Section>
      <Container className="max-w-3xl">
        <h1 className="font-display text-display-1 font-bold text-text">Blog</h1>
        <p className="mt-4 text-lg text-text-muted">
          Insights on microfinance operations, field collections, and digital
          transformation.
        </p>

        {posts.length === 0 ? (
          <p className="mt-12 text-center text-text-muted">
            No posts yet. Check back soon.
          </p>
        ) : (
          <div className="mt-12 flex flex-col gap-6">
            {posts.map((post) => (
              <PostCard key={post.slug} post={post} />
            ))}
          </div>
        )}
      </Container>
    </Section>
  );
}
