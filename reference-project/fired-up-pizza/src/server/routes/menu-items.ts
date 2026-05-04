import { Router } from "express";
import { getDatabase } from "../db";
import {
  getMenuItemWithAggregate,
  listMenuItemsWithAggregates,
} from "../db/reviews";

export function createMenuItemsRouter(): Router {
  const router = Router();

  router.get("/", (req, res) => {
    const category =
      typeof req.query.category === "string" ? req.query.category : undefined;
    const items = listMenuItemsWithAggregates(getDatabase(), category);
    res.json(items);
  });

  router.get("/:pizzaId", (req, res) => {
    const pizzaIdParam = req.params.pizzaId;
    const pizzaId = Number(pizzaIdParam);
    if (
      !Number.isInteger(pizzaId) ||
      pizzaId <= 0 ||
      String(pizzaId) !== pizzaIdParam
    ) {
      res
        .status(400)
        .json({
          errors: [{ field: "pizza_id", reason: "invalid_format" }],
        });
      return;
    }
    const item = getMenuItemWithAggregate(getDatabase(), pizzaId);
    if (!item) {
      res.status(404).json({ error: "unknown_pizza" });
      return;
    }
    res.json(item);
  });

  return router;
}
