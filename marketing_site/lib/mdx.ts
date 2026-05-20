import fs from 'node:fs';
import path from 'node:path';
import matter from 'gray-matter';
import readingTime from 'reading-time';
import { z } from 'zod';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

const FrontmatterSchema = z.object({
  title: z.string().min(1),
  description: z.string().min(1),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  updated: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  author: z.string().min(1),
  draft: z.boolean().optional().default(false),
  ogImage: z.string().optional(),
});

export type Frontmatter = z.infer<typeof FrontmatterSchema>;

export interface BlogPost {
  slug: string;
  frontmatter: Frontmatter;
  content: string;
  readingTimeMinutes: number;
  excerpt: string;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const BLOG_DIR = path.join(process.cwd(), 'content', 'blog');

function computeExcerpt(text: string, maxLen = 160): string {
  const stripped = text.replace(/[#*`\[\]()!>]/g, '').replace(/\n+/g, ' ').trim();
  if (stripped.length <= maxLen) return stripped;
  return stripped.slice(0, maxLen).replace(/\s+\S*$/, '') + '…';
}

function readPostFile(filename: string): BlogPost | null {
  const filePath = path.join(BLOG_DIR, filename);
  if (!fs.existsSync(filePath)) return null;

  const raw = fs.readFileSync(filePath, 'utf-8');
  const { data, content } = matter(raw);

  const parsed = FrontmatterSchema.safeParse(data);
  if (!parsed.success) return null;

  const slug = filename.replace(/\.mdx$/, '');
  const stats = readingTime(content);

  return {
    slug,
    frontmatter: parsed.data,
    content,
    readingTimeMinutes: Math.ceil(stats.minutes),
    excerpt: computeExcerpt(content),
  };
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

interface GetAllPostsOpts {
  includeDrafts?: boolean;
}

export async function getAllPosts(
  opts: GetAllPostsOpts = {},
): Promise<BlogPost[]> {
  const { includeDrafts = false } = opts;
  const isProd = process.env.NODE_ENV === 'production';

  if (!fs.existsSync(BLOG_DIR)) return [];

  const files = fs.readdirSync(BLOG_DIR).filter((f) => f.endsWith('.mdx'));

  const posts = files
    .map(readPostFile)
    .filter((p): p is BlogPost => p !== null)
    .filter((p) => (isProd && !includeDrafts ? !p.frontmatter.draft : true))
    .sort(
      (a, b) =>
        new Date(b.frontmatter.date).getTime() -
        new Date(a.frontmatter.date).getTime(),
    );

  return posts;
}

export async function getPostBySlug(
  slug: string,
): Promise<BlogPost | null> {
  const isProd = process.env.NODE_ENV === 'production';
  const post = readPostFile(`${slug}.mdx`);
  if (!post) return null;
  if (isProd && post.frontmatter.draft) return null;
  return post;
}
