import type Database from "better-sqlite3";

const SCHEMA_SQL = `
CREATE TABLE IF NOT EXISTS menu_items (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        TEXT    NOT NULL,
  description TEXT    NOT NULL DEFAULT '',
  base_price  INTEGER NOT NULL,
  category    TEXT    NOT NULL,
  available   INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS orders (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  phone_number TEXT    NOT NULL,
  status       TEXT    NOT NULL DEFAULT 'placed',
  created_at   INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS order_items (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id     INTEGER NOT NULL REFERENCES orders(id),
  menu_item_id INTEGER NOT NULL REFERENCES menu_items(id),
  size         TEXT    NOT NULL DEFAULT 'medium',
  crust        TEXT    NOT NULL DEFAULT 'classic'
);

CREATE TABLE IF NOT EXISTS reviews (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  pizza_id     INTEGER NOT NULL REFERENCES menu_items(id),
  phone_number TEXT    NOT NULL,
  rating       INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  review_text  TEXT,
  created_at   INTEGER NOT NULL,
  updated_at   INTEGER NOT NULL,
  UNIQUE (pizza_id, phone_number)
);

CREATE INDEX IF NOT EXISTS idx_reviews_pizza_recent
  ON reviews (pizza_id, updated_at DESC);
`;

export function applySchema(db: Database.Database): void {
  db.exec(SCHEMA_SQL);
}
