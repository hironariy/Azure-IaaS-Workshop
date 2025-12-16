/**
 * HTML sanitization utilities
 * Strips unsafe tags/attributes to mitigate stored XSS when rendering user content.
 */

import { JSDOM } from 'jsdom';
import createDOMPurify from 'dompurify';

// Use a JSDOM window for server-side sanitization; cast to satisfy DOMPurify typings
const window = new JSDOM('').window as unknown as Window;
// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-expect-error JSDOM window implements the required DOMPurify Window shape at runtime
const DOMPurify = createDOMPurify(window);

const DEFAULT_ALLOWED_TAGS = [
  'a', 'b', 'i', 'em', 'strong', 'p', 'ul', 'ol', 'li', 'br', 'span', 'code', 'pre',
];

const DEFAULT_ALLOWED_ATTR = ['href', 'title', 'rel', 'target'];

export function sanitizeHtml(input?: string | null): string {
  if (!input) return '';
  return DOMPurify.sanitize(input, {
    ALLOWED_TAGS: DEFAULT_ALLOWED_TAGS,
    ALLOWED_ATTR: DEFAULT_ALLOWED_ATTR,
    RETURN_TRUSTED_TYPE: false,
  });
}

export function sanitizePlain(input?: string | null): string {
  if (!input) return '';
  return sanitizeHtml(input).replace(/<[^>]+>/g, '');
}

export function sanitizeTagValue(value: string): string {
  return sanitizePlain(value).toLowerCase().trim();
}
