import type { Metadata } from 'next';

interface BuildMetadataOpts {
  title: string;
  description: string;
  path: string;
  image?: string;
  type?: 'website' | 'article';
  article?: {
    publishedTime: string;
    modifiedTime?: string;
    authors?: string[];
  };
}

/**
 * Build Next.js `Metadata` for a marketing route with full OpenGraph + Twitter
 * card support and a canonical URL.
 */
export function buildMetadata({
  title,
  description,
  path,
  image,
  type = 'website',
  article,
}: BuildMetadataOpts): Metadata {
  const baseUrl = process.env.NEXT_PUBLIC_SITE_URL ?? 'http://localhost:3000';
  const url = new URL(path, baseUrl).toString();
  const ogImage = image ?? new URL('/opengraph-image', baseUrl).toString();

  return {
    title,
    description,
    alternates: { canonical: url },
    openGraph: {
      title,
      description,
      url,
      type,
      images: [{ url: ogImage, width: 1200, height: 630 }],
      ...(article && {
        publishedTime: article.publishedTime,
        modifiedTime: article.modifiedTime,
        authors: article.authors,
      }),
    },
    twitter: {
      card: 'summary_large_image',
      title,
      description,
      images: [ogImage],
    },
  };
}
