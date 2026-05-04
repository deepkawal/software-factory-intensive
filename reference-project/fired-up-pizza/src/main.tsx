import React from "react";
import ReactDOM from "react-dom/client";
import {
  BrowserRouter,
  Link,
  Navigate,
  Route,
  Routes,
} from "react-router-dom";
import { MenuPage } from "./client/pages/MenuPage";
import { OrderConfirmationPage } from "./client/pages/OrderConfirmationPage";
import { PizzaDetailPage } from "./client/pages/PizzaDetailPage";

function App(): JSX.Element {
  return (
    <div className="min-h-screen bg-orange-50">
      <header className="bg-red-700 text-white p-6">
        <Link to="/" className="block">
          <h1 className="text-3xl font-bold">Fired Up Pizza</h1>
          <p className="text-orange-200">Fresh pies, fired up fast</p>
        </Link>
      </header>
      <main>
        <Routes>
          <Route path="/" element={<Navigate to="/menu" replace />} />
          <Route path="/menu" element={<MenuPage />} />
          <Route path="/menu/:pizzaId" element={<PizzaDetailPage />} />
          <Route path="/order/confirm" element={<OrderConfirmationPage />} />
        </Routes>
      </main>
    </div>
  );
}

const rootElement = document.getElementById("root");
if (rootElement) {
  ReactDOM.createRoot(rootElement).render(
    <React.StrictMode>
      <BrowserRouter>
        <App />
      </BrowserRouter>
    </React.StrictMode>,
  );
}
