import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { generateSlug, generateUniqueSlug } = require('../dist/src/models/Post.js');

const RESERVED_URL_CHARACTERS = /[/?#%&]/u;

function assertValidSlug(slug) {
  assert.notEqual(slug, '');
  assert.equal(slug.startsWith('-'), false);
  assert.equal(slug.endsWith('-'), false);
  assert.equal(RESERVED_URL_CHARACTERS.test(slug), false);
}

describe('generateSlug', () => {
  const examples = [
    ['日本語の記事タイトル', '日本語の記事タイトル'],
    ['中文標題', '中文標題'],
    ['한국어 제목', '한국어-제목'],
    ['Café résumé', 'café-résumé'],
    ['Azure 日本語の記事', 'azure-日本語の記事'],
  ];

  for (const [title, expectedSlug] of examples) {
    it(`should preserve Unicode letters and numbers when title is ${title}`, () => {
      const slug = generateSlug(title);

      assert.equal(slug, expectedSlug);
      assertValidSlug(slug);
    });
  }

  it('should use title-independent fallback when title contains only emoji', () => {
    const slug = generateSlug('😀🎉🚀');

    assert.match(slug, /^post-[0-9a-f]{12}$/u);
    assertValidSlug(slug);
  });

  it('should use title-independent fallback when title contains only punctuation', () => {
    const slug = generateSlug('/?#%&!!!');

    assert.match(slug, /^post-[0-9a-f]{12}$/u);
    assertValidSlug(slug);
  });

  it('should drop reserved URL characters when title contains reserved separators', () => {
    const slug = generateSlug('Azure /? #% & 日本語');

    assert.equal(slug, 'azure-日本語');
    assertValidSlug(slug);
  });

  it('should truncate by code points without broken surrogates when title is long', () => {
    const slug = generateSlug(`${'𐐷'.repeat(120)}-`);

    assert.equal(Array.from(slug).length, 100);
    assert.equal(slug, '𐐷'.repeat(100));
    assert.equal(slug.includes('\uFFFD'), false);
    assertValidSlug(slug);
  });
});

describe('generateUniqueSlug', () => {
  it('should return base slug when no collision exists', async () => {
    const checkedSlugs = [];
    const slug = await generateUniqueSlug('azure-日本語の記事', 'student', async (candidate) => {
      checkedSlugs.push(candidate);
      return false;
    });

    assert.equal(slug, 'azure-日本語の記事');
    assert.deepEqual(checkedSlugs, ['azure-日本語の記事']);
  });

  it('should append username when base slug already exists', async () => {
    const takenSlugs = new Set(['azure-日本語の記事']);
    const slug = await generateUniqueSlug('azure-日本語の記事', 'student', async (candidate) =>
      takenSlugs.has(candidate)
    );

    assert.equal(slug, 'azure-日本語の記事-by-student');
    assertValidSlug(slug);
  });

  it('should append counter when base and username slugs already exist', async () => {
    const takenSlugs = new Set(['azure-日本語の記事', 'azure-日本語の記事-by-student']);
    const slug = await generateUniqueSlug('azure-日本語の記事', 'student', async (candidate) =>
      takenSlugs.has(candidate)
    );

    assert.equal(slug, 'azure-日本語の記事-by-student-2');
    assertValidSlug(slug);
  });
});
