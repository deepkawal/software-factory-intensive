import Database from "better-sqlite3";
import { applySchema } from "./schema";

export type DB = Database.Database;

let _db: DB | null = null;

export function openDatabase(filename: string): DB {
  const db = new Database(filename);
  db.pragma("journal_mode = WAL");
  db.pragma("foreign_keys = ON");
  applySchema(db);
  return db;
}

export function getDatabase(): DB {
  if (!_db) {
    _db = openDatabase(process.env.DB_FILE ?? "fired-up-pizza.db");
  }
  return _db;
}

export function setDatabaseForTesting(db: DB | null): void {
  _db = db;
}
