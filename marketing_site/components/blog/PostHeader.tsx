import type { BlogPost } from '@/lib/mdx';

interface PostHeaderProps {
  post: BlogPost;
}

function formatDate(dateStr: string) {
  return new Intl.DateTimeFormat('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  }).format(new Date(dateStr));
}

export function PostHeader({ post }: PostHeaderProps) {
  return (
    <header className="mb-8 border-b border-border pb-8">
      <h1 className="font-display text-display-2 font-bold text-text">
        {post.frontmatter.title}
      </h1>
      <div className="mt-4 flex flex-wrap items-center gap-2 text-sm text-text-muted">
        <time dateTime={post.frontmatter.date}>
          {formatDate(post.frontmatter.date)}
        </time>
        {post.frontmatter.updated && (
          <>
            <span>&middot;</span>
            <span>Updated {formatDate(post.frontmatter.updated)}</span>
          </>
        )}
        <span>&middot;</span>
        <span>{post.frontmatter.author}</span>
        <span>&middot;</span>
        <span>{post.readingTimeMinutes} min read</span>
      </div>
    </header>
  );
}
