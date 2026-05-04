export interface Review {
  id: number;
  pizza_id: number;
  phone_tail: string;
  rating: number;
  review_text: string | null;
  created_at: number;
  updated_at: number;
}

export interface OwnReview extends Review {
  phone_number: string;
}

export interface MenuItemWithAggregate {
  id: number;
  name: string;
  description: string;
  base_price: number;
  category: string;
  available: boolean;
  avg_rating: number | null;
  review_count: number;
}

export interface SubmitReviewRequest {
  phone_number: string;
  rating: number;
  review_text?: string;
}
