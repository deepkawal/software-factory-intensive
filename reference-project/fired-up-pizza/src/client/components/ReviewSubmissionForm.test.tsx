import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { ReviewSubmissionForm } from "./ReviewSubmissionForm";

const PHONE = "+15551234567";

interface MockResponseInit {
  status: number;
  body: unknown;
}

function mockFetchOnce({ status, body }: MockResponseInit): void {
  vi.spyOn(globalThis, "fetch").mockImplementationOnce(async () =>
    new Response(JSON.stringify(body), {
      status,
      headers: { "Content-Type": "application/json" },
    }),
  );
}

beforeEach(() => {
  vi.restoreAllMocks();
});

afterEach(() => {
  vi.restoreAllMocks();
});

describe("ReviewSubmissionForm", () => {
  it("starts in idle with a Rate this pizza button", () => {
    render(
      <ReviewSubmissionForm
        pizzaId={1}
        pizzaName="Margherita"
        phoneNumber={PHONE}
      />,
    );
    expect(
      screen.getByRole("button", { name: "Rate this pizza" }),
    ).toBeInTheDocument();
  });

  it("opens the form and disables Submit until a rating is picked", async () => {
    render(
      <ReviewSubmissionForm
        pizzaId={1}
        pizzaName="Margherita"
        phoneNumber={PHONE}
      />,
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Rate this pizza" }),
    );
    const submit = await screen.findByRole("button", { name: "Submit" });
    expect(submit).toBeDisabled();
    fireEvent.click(screen.getByRole("button", { name: "4 stars" }));
    await waitFor(() => expect(submit).not.toBeDisabled());
  });

  it("posts the expected body shape on submit and shows the saved panel on 201", async () => {
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(
        new Response(
          JSON.stringify({
            id: 1,
            pizza_id: 1,
            phone_tail: "4567",
            phone_number: PHONE,
            rating: 5,
            review_text: "Yum",
            created_at: 1,
            updated_at: 1,
          }),
          { status: 201, headers: { "Content-Type": "application/json" } },
        ),
      );

    render(
      <ReviewSubmissionForm
        pizzaId={1}
        pizzaName="Margherita"
        phoneNumber={PHONE}
      />,
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Rate this pizza" }),
    );
    fireEvent.click(screen.getByRole("button", { name: "5 stars" }));
    fireEvent.change(
      screen.getByRole("textbox", { name: /review/i }),
      { target: { value: "Yum" } },
    );
    fireEvent.click(screen.getByRole("button", { name: "Submit" }));

    await screen.findByText(/Thanks — review saved/);
    expect(fetchMock).toHaveBeenCalled();
    const [, init] = fetchMock.mock.calls[0]!;
    const body = JSON.parse((init?.body as string) ?? "{}");
    expect(body).toEqual({
      phone_number: PHONE,
      rating: 5,
      review_text: "Yum",
    });
  });

  it("treats 200 the same as 201", async () => {
    mockFetchOnce({
      status: 200,
      body: {
        id: 1,
        pizza_id: 1,
        phone_tail: "4567",
        phone_number: PHONE,
        rating: 4,
        review_text: null,
        created_at: 1,
        updated_at: 2,
      },
    });
    render(
      <ReviewSubmissionForm
        pizzaId={1}
        pizzaName="Margherita"
        phoneNumber={PHONE}
      />,
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Rate this pizza" }),
    );
    fireEvent.click(screen.getByRole("button", { name: "4 stars" }));
    fireEvent.click(screen.getByRole("button", { name: "Submit" }));
    await screen.findByText(/Thanks — review saved/);
  });

  it("shows the validation error message on a 400 response", async () => {
    mockFetchOnce({ status: 400, body: { errors: [] } });
    render(
      <ReviewSubmissionForm
        pizzaId={1}
        pizzaName="Margherita"
        phoneNumber={PHONE}
      />,
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Rate this pizza" }),
    );
    fireEvent.click(screen.getByRole("button", { name: "4 stars" }));
    fireEvent.click(screen.getByRole("button", { name: "Submit" }));
    await screen.findByRole("alert");
    expect(
      screen.getByText("Please check your rating and review."),
    ).toBeInTheDocument();
  });

  it("shows the ineligible message on a 403 response", async () => {
    mockFetchOnce({ status: 403, body: { error: "ineligible" } });
    render(
      <ReviewSubmissionForm
        pizzaId={1}
        pizzaName="Margherita"
        phoneNumber={PHONE}
      />,
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Rate this pizza" }),
    );
    fireEvent.click(screen.getByRole("button", { name: "4 stars" }));
    fireEvent.click(screen.getByRole("button", { name: "Submit" }));
    await screen.findByRole("alert");
    expect(
      screen.getByText(/We couldn't find an order/),
    ).toBeInTheDocument();
  });

  it("Change reopens the form with rating + text prefilled", async () => {
    mockFetchOnce({
      status: 201,
      body: {
        id: 1,
        pizza_id: 1,
        phone_tail: "4567",
        phone_number: PHONE,
        rating: 5,
        review_text: "Loved it",
        created_at: 1,
        updated_at: 1,
      },
    });
    render(
      <ReviewSubmissionForm
        pizzaId={1}
        pizzaName="Margherita"
        phoneNumber={PHONE}
      />,
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Rate this pizza" }),
    );
    fireEvent.click(screen.getByRole("button", { name: "5 stars" }));
    fireEvent.click(screen.getByRole("button", { name: "Submit" }));
    await screen.findByText(/Thanks — review saved/);
    fireEvent.click(screen.getByRole("button", { name: "Change" }));
    const textarea = await screen.findByRole("textbox", { name: /review/i });
    expect(textarea).toHaveValue("Loved it");
    expect(
      screen.getByRole("button", { name: "5 stars" }),
    ).toHaveAttribute("aria-pressed", "true");
  });

  it("does not include the phone number in the rendered DOM", () => {
    const { container } = render(
      <ReviewSubmissionForm
        pizzaId={1}
        pizzaName="Margherita"
        phoneNumber={PHONE}
      />,
    );
    expect(container.innerHTML.includes(PHONE)).toBe(false);
  });

  it("omits review_text when whitespace-only", async () => {
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(
        new Response(
          JSON.stringify({
            id: 1,
            pizza_id: 1,
            phone_tail: "4567",
            phone_number: PHONE,
            rating: 4,
            review_text: null,
            created_at: 1,
            updated_at: 1,
          }),
          { status: 201, headers: { "Content-Type": "application/json" } },
        ),
      );
    render(
      <ReviewSubmissionForm
        pizzaId={1}
        pizzaName="Margherita"
        phoneNumber={PHONE}
      />,
    );
    fireEvent.click(
      screen.getByRole("button", { name: "Rate this pizza" }),
    );
    fireEvent.click(screen.getByRole("button", { name: "4 stars" }));
    fireEvent.change(
      screen.getByRole("textbox", { name: /review/i }),
      { target: { value: "   " } },
    );
    fireEvent.click(screen.getByRole("button", { name: "Submit" }));
    await screen.findByText(/Thanks — review saved/);
    const [, init] = fetchMock.mock.calls[0]!;
    const body = JSON.parse((init?.body as string) ?? "{}");
    expect("review_text" in body).toBe(false);
  });
});
