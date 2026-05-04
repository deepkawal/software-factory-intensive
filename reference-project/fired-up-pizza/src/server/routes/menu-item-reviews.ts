import { Router } from "express";
import { getDatabase } from "../db";
import { listRecentReviewsForPizza, submitReview } from "../db/reviews";
import { parseSubmission } from "../lib/reviews-validation";

const DEFAULT_LIMIT = 10;
const MAX_LIMIT = 50;

function parsePizzaId(raw: string): number | null {
  const id = Number(raw);
  if (!Number.isInteger(id) || id <= 0 || String(id) !== raw) return null;
  return id;
}

export function createMenuItemReviewsRouter(): Router {
  const router = Router({ mergeParams: true });

  router.post("/", (req, res) => {
    const pizzaIdRaw = (req.params as { pizzaId: string }).pizzaId;
    const pizzaId = parsePizzaId(pizzaIdRaw);
    if (pizzaId === null) {
      res.status(400).json({
        errors: [{ field: "pizza_id", reason: "invalid_format" }],
      });
      return;
    }

    const parsed = parseSubmission(req.body);
    if (!parsed.ok) {
      res.status(400).json({ errors: parsed.errors });
      return;
    }

    const outcome = submitReview(getDatabase(), {
      pizzaId,
      phoneNumber: parsed.value.phoneNumber,
      rating: parsed.value.rating,
      reviewText: parsed.value.reviewText,
    });

    switch (outcome.kind) {
      case "inserted":
        res.status(201).json(outcome.row);
        return;
      case "updated":
        res.status(200).json(outcome.row);
        return;
      case "ineligible":
        res.status(403).json({
          error: "ineligible",
          message: "No order on file for this pizza.",
        });
        return;
      case "unknown_pizza":
        res.status(404).json({ error: "unknown_pizza" });
        return;
    }
  });

  router.get("/", (req, res) => {
    const pizzaIdRaw = (req.params as { pizzaId: string }).pizzaId;
    const pizzaId = parsePizzaId(pizzaIdRaw);
    if (pizzaId === null) {
      res.status(400).json({
        errors: [{ field: "pizza_id", reason: "invalid_format" }],
      });
      return;
    }

    let limit = DEFAULT_LIMIT;
    if (req.query.limit !== undefined) {
      const raw = String(req.query.limit);
      const parsedLimit = Number(raw);
      if (
        !Number.isInteger(parsedLimit) ||
        String(parsedLimit) !== raw ||
        parsedLimit < 1
      ) {
        res.status(400).json({
          errors: [{ field: "limit", reason: "invalid_format" }],
        });
        return;
      }
      limit = Math.min(parsedLimit, MAX_LIMIT);
    }

    const reviews = listRecentReviewsForPizza(getDatabase(), pizzaId, limit);
    res.json(reviews);
  });

  return router;
}
