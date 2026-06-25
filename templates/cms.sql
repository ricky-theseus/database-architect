-- ============================================================
-- Schema: Content Management System
-- Domain: Blog / CMS with authors, posts, tags, full-text search
-- Source: database-architect SKILL.md §20.3
-- Usage: psql -U postgres -d yourdb -f cms.sql
-- ============================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Enums
CREATE TYPE post_status AS ENUM ('draft', 'published', 'archived');
CREATE TYPE comment_status AS ENUM ('pending', 'approved', 'spam', 'deleted');

-- Authors
CREATE TABLE authors (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email       TEXT NOT NULL UNIQUE,
    name        TEXT NOT NULL,
    bio         TEXT,
    avatar_url  TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE authors IS 'Content authors/editors';

-- Posts
CREATE TABLE posts (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    author_id     BIGINT NOT NULL REFERENCES authors(id),
    slug          TEXT NOT NULL UNIQUE,
    title         TEXT NOT NULL,
    body          TEXT NOT NULL,
    excerpt       TEXT,
    cover_image   TEXT,
    status        post_status NOT NULL DEFAULT 'draft',
    published_at  TIMESTAMPTZ,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE posts IS 'Blog posts/articles';

-- Tags
CREATE TABLE tags (
    id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    slug  TEXT NOT NULL UNIQUE,
    name  TEXT NOT NULL
);
COMMENT ON TABLE tags IS 'Content tags';

-- Post-Tag mapping
CREATE TABLE post_tags (
    post_id BIGINT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    tag_id  BIGINT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (post_id, tag_id)
);
COMMENT ON TABLE post_tags IS 'Many-to-many post-tag relationship';

-- Comments
CREATE TABLE comments (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    post_id     BIGINT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    parent_id   BIGINT REFERENCES comments(id),  -- threaded comments
    author_name TEXT NOT NULL,
    author_email TEXT,
    body        TEXT NOT NULL,
    status      comment_status NOT NULL DEFAULT 'pending',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE comments IS 'Post comments (threaded via parent_id)';

-- Media
CREATE TABLE media (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    author_id   BIGINT NOT NULL REFERENCES authors(id),
    filename    TEXT NOT NULL,
    mime_type   TEXT NOT NULL,
    size_bytes  BIGINT NOT NULL,
    url         TEXT NOT NULL,
    alt_text    TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE media IS 'Uploaded media files';

-- Indexes
CREATE INDEX idx_posts_author ON posts (author_id);
CREATE INDEX idx_posts_slug ON posts (slug);
CREATE INDEX idx_posts_status_published ON posts (status, published_at DESC)
    WHERE status = 'published';
CREATE INDEX idx_posts_search ON posts
    USING GIN (to_tsvector('english', title || ' ' || COALESCE(body, '')));
CREATE INDEX idx_comments_post ON comments (post_id);
CREATE INDEX idx_comments_status ON comments (status) WHERE status = 'pending';
CREATE INDEX idx_comments_parent ON comments (parent_id) WHERE parent_id IS NOT NULL;
CREATE INDEX idx_media_author ON media (author_id);
CREATE INDEX idx_post_tags_tag ON post_tags (tag_id);
