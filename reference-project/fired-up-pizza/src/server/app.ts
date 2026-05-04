import express, { type Express } from "express";
import { createApiRouter } from "./routes";

export function createApp(): Express {
  const app = express();
  app.use(express.json());
  app.use("/api/v1", createApiRouter());
  return app;
}
