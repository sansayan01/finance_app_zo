import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import Link from 'next/link';
import { buildMetadata } from '@/components/seo/buildMetadata';
import { getAllPosts, getPostBySlug } from '@/lib/mdx';
import { Container } from '@/components/ui/container';
import { Section } from '@/components/ui/section';
import { PostHeader } from '@/components/blog/PostHeader';
import { PostBody } from '@/components/blog/PostBody';
import { ArticleJsonLd } from '@/components/blog/ArticleJsonLd';

export const revalidate = 3600;

interface PageProps {
  params: Promise<{ slug: string }>;
}

export async function generateStaticParams() {
  const posts = await getAllPosts();
  return posts.map((post) => ({ slug: post.slug }));
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { slug } = await params;
  const post = await getPostBySlug(slug);
  if (!post) return { title: 'Not found' };

  return buildMetadata({
    title: post.frontmatter.title,
    description: post.frontmatter.description,
    path: `/blog/${post.slug}`,
    image: post.frontmatter.ogImage,
    type: 'article',
    article: {
      publishedTime: post.frontmatter.date,
      modifiedTime: post.frontmatter.updated,
      authors: [post.frontmatter.author],
    },
  });
}

export default async function BlogPostPage({ params }: PageProps) {
  const { slug } = await params;
  const post = await getPostBySlug(slug);
  if (!post) notFound();

  return (
    <>
      <ArticleJsonLd post={post} />
      <Section>
        <Container className="max-w-3xl">
          <PostHeader post={post} />
          <PostBody>
            <div dangerouslySetInnerHTML={{ __html: post.content }} />
          </PostBody>
          <div className="mt-12 border-t border-border pt-6">
            <Link
              href="/blog"
              className="text-sm font-medium text-indigo transition-colors hover:text-indigo-dark"
            >
              &larr; Back to Blog
            </Link>
          </div>
        </Container>
      </Section>
    </>
  );
}
