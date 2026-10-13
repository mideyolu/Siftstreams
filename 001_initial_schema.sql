BEGIN;

CREATE TABLE products (
    product_id   TEXT PRIMARY KEY,
    name         TEXT NOT NULL,
    category     TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE orders (
    order_id     TEXT PRIMARY KEY,
    user_id      TEXT,
    session_id   TEXT,
    status       TEXT NOT NULL CHECK (
        status IN ('pending', 'confirmed', 'cancelled', 'completed')
    ),
    country_code CHAR(2),
    currency     CHAR(3) NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL,
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_orders_created_at ON orders (created_at);
CREATE INDEX idx_orders_status_created_at ON orders (status, created_at);
CREATE INDEX idx_orders_session_id ON orders (session_id);

CREATE TABLE order_items (
    order_item_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_item_id TEXT, -- Added to identify distinct line items for the same product
    order_id      TEXT NOT NULL REFERENCES orders(order_id) ON DELETE RESTRICT,
    product_id    TEXT NOT NULL REFERENCES products(product_id) ON DELETE RESTRICT,
    quantity      INTEGER NOT NULL CHECK (quantity > 0),
    unit_price    NUMERIC(14, 2) NOT NULL CHECK (unit_price >= 0),
    currency      CHAR(3) NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
    -- Removed UNIQUE (order_id, product_id) to allow duplicate product line items with different options
);

CREATE INDEX idx_order_items_product_id ON order_items (product_id);
CREATE INDEX idx_order_items_order_id ON order_items (order_id);

CREATE TABLE payments (
    payment_id   TEXT PRIMARY KEY,
    order_id     TEXT NOT NULL REFERENCES orders(order_id) ON DELETE RESTRICT,
    status       TEXT NOT NULL CHECK (
        status IN ('pending', 'succeeded', 'failed', 'cancelled')
    ),
    amount       NUMERIC(14, 2) NOT NULL CHECK (amount > 0),
    currency     CHAR(3) NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    succeeded_at TIMESTAMPTZ
);

CREATE INDEX idx_payments_order_id ON payments (order_id);
CREATE INDEX idx_payments_status_succeeded_at
    ON payments (status, succeeded_at);

CREATE TABLE refunds (
    refund_id    TEXT PRIMARY KEY,
    payment_id   TEXT NOT NULL REFERENCES payments(payment_id) ON DELETE RESTRICT,
    amount       NUMERIC(14, 2) NOT NULL CHECK (amount > 0),
    currency     CHAR(3) NOT NULL,
    status       TEXT NOT NULL CHECK (
        status IN ('pending', 'succeeded', 'failed')
    ),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    refunded_at  TIMESTAMPTZ
);

CREATE INDEX idx_refunds_payment_id ON refunds (payment_id);
CREATE INDEX idx_refunds_status_refunded_at
    ON refunds (status, refunded_at);

CREATE TABLE events (
    event_id          TEXT PRIMARY KEY,
    event_type        TEXT NOT NULL CHECK (
        event_type IN (
            'product_viewed',
            'add_to_cart',
            'order_created',
            'payment_succeeded',
            'payment_failed',
            'refund_succeeded'
        )
    ),
    event_version     INTEGER NOT NULL DEFAULT 1 CHECK (event_version > 0),
    occurred_at       TIMESTAMPTZ NOT NULL,
    received_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed_at      TIMESTAMPTZ,
    user_id           TEXT,
    session_id        TEXT,
    product_id        TEXT, -- Removed FK constraint to allow tracking unregistered products
    order_id          TEXT REFERENCES orders(order_id) ON DELETE RESTRICT,
    country_code      CHAR(2),
    payload           JSONB NOT NULL DEFAULT '{}'::JSONB,
    processing_status TEXT NOT NULL DEFAULT 'processed' CHECK (
        processing_status IN ('processed', 'rejected', 'dead_lettered')
    )
);

CREATE INDEX idx_events_occurred_at ON events (occurred_at);
CREATE INDEX idx_events_type_time ON events (event_type, occurred_at);
CREATE INDEX idx_events_session_time ON events (session_id, occurred_at);
CREATE INDEX idx_events_order_id ON events (order_id);
CREATE INDEX idx_events_product_id ON events (product_id);

CREATE TABLE metric_aggregates (
    metric_name  TEXT NOT NULL,
    bucket_start TIMESTAMPTZ NOT NULL,
    dimensions   JSONB NOT NULL DEFAULT '{}'::JSONB,
    value        NUMERIC(18, 4) NOT NULL,
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (metric_name, bucket_start, dimensions)
);

-- ============================================================================
-- CURRENCY CONSISTENCY ENFORCEMENT
-- ============================================================================

-- Function to validate order_items currency against orders currency
CREATE OR REPLACE FUNCTION check_order_item_currency()
RETURNS TRIGGER AS $$
DECLARE
    order_curr CHAR(3);
BEGIN
    SELECT currency INTO order_curr FROM orders WHERE order_id = NEW.order_id;
    IF FOUND AND NEW.currency <> order_curr THEN
        RAISE EXCEPTION 'Currency mismatch: order_item currency (%) does not match order currency (%)',
            NEW.currency, order_curr;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_order_item_currency
BEFORE INSERT OR UPDATE ON order_items
FOR EACH ROW EXECUTE FUNCTION check_order_item_currency();

-- Function to validate payments currency against orders currency
CREATE OR REPLACE FUNCTION check_payment_currency()
RETURNS TRIGGER AS $$
DECLARE
    order_curr CHAR(3);
BEGIN
    SELECT currency INTO order_curr FROM orders WHERE order_id = NEW.order_id;
    IF FOUND AND NEW.currency <> order_curr THEN
        RAISE EXCEPTION 'Currency mismatch: payment currency (%) does not match order currency (%)',
            NEW.currency, order_curr;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_payment_currency
BEFORE INSERT OR UPDATE ON payments
FOR EACH ROW EXECUTE FUNCTION check_payment_currency();

-- Function to validate refunds currency against payments currency
CREATE OR REPLACE FUNCTION check_refund_currency()
RETURNS TRIGGER AS $$
DECLARE
    payment_curr CHAR(3);
BEGIN
    SELECT currency INTO payment_curr FROM payments WHERE payment_id = NEW.payment_id;
    IF FOUND AND NEW.currency <> payment_curr THEN
        RAISE EXCEPTION 'Currency mismatch: refund currency (%) does not match payment currency (%)',
            NEW.currency, payment_curr;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_refund_currency
BEFORE INSERT OR UPDATE ON refunds
FOR EACH ROW EXECUTE FUNCTION check_refund_currency();

COMMIT;
