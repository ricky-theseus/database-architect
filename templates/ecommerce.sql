-- ============================================================
-- Schema: E-Commerce
-- Domain: Online store with products, inventory, orders
-- Source: database-architect SKILL.md §20.2
-- Usage: psql -U postgres -d yourdb -f ecommerce.sql
-- ============================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Enums
CREATE TYPE product_status AS ENUM ('active', 'draft', 'archived');
CREATE TYPE order_status AS ENUM ('pending', 'paid', 'shipped', 'delivered', 'cancelled');

-- Categories (hierarchical)
CREATE TABLE categories (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    parent_id   BIGINT REFERENCES categories(id),
    slug        TEXT NOT NULL UNIQUE,
    name        TEXT NOT NULL,
    description TEXT,
    sort_order  INTEGER NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE categories IS 'Product categories (self-referencing for hierarchy)';

-- Products
CREATE TABLE products (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sku         TEXT NOT NULL UNIQUE,
    name        TEXT NOT NULL,
    description TEXT,
    price       NUMERIC(12,2) NOT NULL CHECK (price >= 0),
    cost        NUMERIC(12,2) CHECK (cost >= 0),
    stock       INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
    status      product_status NOT NULL DEFAULT 'draft',
    category_id BIGINT REFERENCES categories(id),
    metadata    JSONB DEFAULT '{}',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE products IS 'Product catalog items';

-- Users (customer accounts)
CREATE TABLE users (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email       TEXT NOT NULL UNIQUE,
    name        TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    address     JSONB,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Orders
CREATE TABLE orders (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users(id),
    status      order_status NOT NULL DEFAULT 'pending',
    subtotal    NUMERIC(12,2) NOT NULL CHECK (subtotal >= 0),
    discount    NUMERIC(12,2) DEFAULT 0 CHECK (discount >= 0),
    total       NUMERIC(12,2) NOT NULL CHECK (total >= 0),
    currency    TEXT NOT NULL DEFAULT 'USD',
    note        TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE orders IS 'Customer orders';

-- Order items
CREATE TABLE order_items (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id    BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id  BIGINT NOT NULL REFERENCES products(id),
    quantity    INTEGER NOT NULL CHECK (quantity > 0),
    unit_price  NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0),
    total       NUMERIC(12,2) NOT NULL CHECK (total >= 0)
);
COMMENT ON TABLE order_items IS 'Line items within an order';

-- Payments
CREATE TABLE payments (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id    BIGINT NOT NULL REFERENCES orders(id),
    method      TEXT NOT NULL CHECK (method IN ('card', 'alipay', 'wechat', 'bank')),
    amount      NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    status      TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'succeeded', 'failed', 'refunded')),
    gateway_payment_id TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE payments IS 'Payment transactions';

-- Indexes
CREATE INDEX idx_products_status ON products (status) WHERE status = 'active';
CREATE INDEX idx_products_category ON products (category_id) WHERE category_id IS NOT NULL;
CREATE INDEX idx_products_sku ON products (sku);
CREATE INDEX idx_products_search ON products
    USING GIN (to_tsvector('english', name || ' ' || COALESCE(description, '')));
CREATE INDEX idx_orders_user ON orders (user_id);
CREATE INDEX idx_orders_status ON orders (status);
CREATE INDEX idx_orders_created ON orders (created_at DESC);
CREATE INDEX idx_order_items_order ON order_items (order_id);
CREATE INDEX idx_payments_order ON payments (order_id);
CREATE INDEX idx_categories_parent ON categories (parent_id) WHERE parent_id IS NOT NULL;
