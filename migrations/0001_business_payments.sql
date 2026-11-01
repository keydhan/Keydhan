-- KeyDhan Cashfree payment foundation (sandbox only).
-- No customer data or payment credentials are stored in this migration.

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS business_services (
  service_key TEXT PRIMARY KEY,
  display_name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  active INTEGER NOT NULL DEFAULT 0 CHECK (active IN (0, 1)),
  professional_fee_paise INTEGER CHECK (professional_fee_paise IS NULL OR professional_fee_paise >= 0),
  tax_rate_basis_points INTEGER NOT NULL DEFAULT 0 CHECK (tax_rate_basis_points BETWEEN 0 AND 10000),
  currency TEXT NOT NULL DEFAULT 'INR' CHECK (currency = 'INR'),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS payment_orders (
  order_id TEXT PRIMARY KEY,
  cashfree_order_id TEXT UNIQUE,
  service_key TEXT NOT NULL REFERENCES business_services(service_key),
  customer_name TEXT NOT NULL,
  customer_email TEXT,
  customer_phone TEXT NOT NULL,
  professional_fee_paise INTEGER NOT NULL CHECK (professional_fee_paise >= 0),
  tax_paise INTEGER NOT NULL DEFAULT 0 CHECK (tax_paise >= 0),
  government_fee_paise INTEGER NOT NULL DEFAULT 0 CHECK (government_fee_paise >= 0),
  total_amount_paise INTEGER NOT NULL CHECK (total_amount_paise > 0),
  currency TEXT NOT NULL DEFAULT 'INR' CHECK (currency = 'INR'),
  payment_status TEXT NOT NULL DEFAULT 'CREATED'
    CHECK (payment_status IN ('CREATED','PENDING','PAID','FAILED','CANCELLED','REFUNDED','PARTIALLY_REFUNDED')),
  gateway_environment TEXT NOT NULL CHECK (gateway_environment IN ('SANDBOX','PRODUCTION')),
  cashfree_payment_id TEXT,
  cashfree_payment_session_id TEXT,
  service_status TEXT NOT NULL DEFAULT 'NEW'
    CHECK (service_status IN ('NEW','IN_PROGRESS','COMPLETED','ON_HOLD','CANCELLED')),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_payment_orders_created_at ON payment_orders(created_at);
CREATE INDEX IF NOT EXISTS idx_payment_orders_payment_status ON payment_orders(payment_status);
CREATE INDEX IF NOT EXISTS idx_payment_orders_service_key ON payment_orders(service_key);
CREATE INDEX IF NOT EXISTS idx_payment_orders_phone ON payment_orders(customer_phone);
CREATE INDEX IF NOT EXISTS idx_payment_orders_cashfree_order ON payment_orders(cashfree_order_id);

CREATE TABLE IF NOT EXISTS payment_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  provider_event_id TEXT NOT NULL UNIQUE,
  order_id TEXT NOT NULL REFERENCES payment_orders(order_id),
  cashfree_payment_id TEXT,
  event_type TEXT NOT NULL,
  signature_verified INTEGER NOT NULL CHECK (signature_verified IN (0,1)),
  processing_status TEXT NOT NULL DEFAULT 'RECEIVED'
    CHECK (processing_status IN ('RECEIVED','PROCESSED','IGNORED','FAILED')),
  received_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  processed_at TEXT,
  error_code TEXT
);

CREATE INDEX IF NOT EXISTS idx_payment_events_order_id ON payment_events(order_id);

CREATE TABLE IF NOT EXISTS business_service_requests (
  request_id TEXT PRIMARY KEY,
  order_id TEXT NOT NULL UNIQUE REFERENCES payment_orders(order_id),
  service_key TEXT NOT NULL REFERENCES business_services(service_key),
  customer_name TEXT NOT NULL,
  customer_email TEXT,
  customer_phone TEXT NOT NULL,
  customer_notes TEXT NOT NULL DEFAULT '',
  fulfilment_status TEXT NOT NULL DEFAULT 'NEW'
    CHECK (fulfilment_status IN ('NEW','IN_PROGRESS','COMPLETED','ON_HOLD','CANCELLED')),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_service_requests_status ON business_service_requests(fulfilment_status);
CREATE INDEX IF NOT EXISTS idx_service_requests_phone ON business_service_requests(customer_phone);

-- Initial catalogue is deliberately inactive and unpriced until KeyDhan confirms
-- its own professional fees, applicable taxes, and the service scope.
INSERT OR IGNORE INTO business_services(service_key, display_name, description, active)
VALUES
 ('gst-registration', 'GST Registration Assistance', 'Guidance and assistance with GST registration. Government approval and timelines are determined by the relevant authority.', 0),
 ('gst-return-filing', 'GST Return Filing Assistance', 'Assistance with GST return preparation and filing, subject to scope confirmation.', 0),
 ('pan-application', 'PAN Application / Correction Assistance', 'Assistance with PAN application or correction. Processing is controlled by the authorised agency.', 0),
 ('udyam-registration', 'MSME / Udyam Registration Assistance', 'Guidance for eligible enterprises applying for Udyam registration.', 0),
 ('trademark-registration', 'Trademark Registration Assistance', 'Assistance with trademark application preparation and filing workflow. Registration is not guaranteed.', 0);
