import Link from 'next/link';
import type { BlogPost } from '@/lib/mdx';

interface PostCardProps {
  post: BlogPost;
}

function formatDate(dateStr: string) {
  return new Intl.DateTimeFormat('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  }).format(new Date(dateStr));
}

export function PostCard({ post }: PostCardProps) {
  return (
    <article className="group rounded-xl2 border border-border bg-surface p-6 transition-shadow hover:shadow-glass dark:hover:shadow-glass-dk">
      <Link href={`/blog/${post.slug}`}>
        <h2 className="font-display text-xl font-bold text-text group-hover:text-indigo">
          {post.frontmatter.title}
        </h2>
      </Link>
      <div className="mt-2 flex items-center gap-2 text-xs text-text-muted">
        <time dateTime={post.frontmatter.date}>
          {formatDate(post.frontmatter.date)}
        </time>
        <span>&middot;</span>
        <span>{post.frontmatter.author}</span>
        <span>&middot;</span>
        <span>{post.readingTimeMinutes} min read</span>
      </div>
      <p className="mt-3 text-sm text-text-muted">{post.excerpt}</p>
    </article>
  );
}
