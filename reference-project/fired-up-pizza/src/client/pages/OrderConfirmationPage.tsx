import { useLocation } from "react-router-dom";
import { ReviewSubmissionForm } from "../components/ReviewSubmissionForm";

export interface OrderConfirmationLocationState {
  orderId: number;
  phoneNumber: string;
  pizzas: Array<{ menu_item_id: number; name: string }>;
}

export function OrderConfirmationPage(): JSX.Element {
  const location = useLocation();
  const state = (location.state ?? null) as
    | OrderConfirmationLocationState
    | null;

  if (!state) {
    return (
      <div className="max-w-3xl mx-auto p-6">
        <h1 className="text-2xl font-bold">No recent order</h1>
        <p className="mt-2 text-gray-600">
          Place an order from the menu to see this page.
        </p>
      </div>
    );
  }

  const distinctPizzas: Array<{ menu_item_id: number; name: string }> = [];
  const seen = new Set<number>();
  for (const pizza of state.pizzas) {
    if (!seen.has(pizza.menu_item_id)) {
      seen.add(pizza.menu_item_id);
      distinctPizzas.push(pizza);
    }
  }

  return (
    <div className="max-w-3xl mx-auto p-6">
      <h1 className="text-2xl font-bold">Order confirmed</h1>
      <p className="mt-2 text-gray-600">
        Thanks for your order! Below you can rate each pizza.
      </p>
      <section
        aria-label="Rate your pizzas"
        className="mt-6 space-y-4"
      >
        {distinctPizzas.map((pizza) => (
          <ReviewSubmissionForm
            key={pizza.menu_item_id}
            pizzaId={pizza.menu_item_id}
            pizzaName={pizza.name}
            phoneNumber={state.phoneNumber}
          />
        ))}
      </section>
    </div>
  );
}
