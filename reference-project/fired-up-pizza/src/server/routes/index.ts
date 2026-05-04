import { Router } from "express";
import { createMenuItemReviewsRouter } from "./menu-item-reviews";
import { createMenuItemsRouter } from "./menu-items";

export function createApiRouter(): Router {
  const router = Router();

  const menuItems = createMenuItemsRouter();
  menuItems.use("/:pizzaId/reviews", createMenuItemReviewsRouter());
  router.use("/menu-items", menuItems);

  return router;
}
