import { useQuery } from "@tanstack/react-query";
import { api } from "./client";

export const useCities = () =>
  useQuery({
    queryKey: ["cities"],
    queryFn: () => api.listCities(),
    refetchInterval: 15_000,
  });

export const useCityStatus = (city: string | null) =>
  useQuery({
    queryKey: ["status", city],
    queryFn: () => api.cityStatus(city),
    enabled: !!city,
    refetchInterval: 5_000,
  });

export const useAgents = (city: string | null) =>
  useQuery({
    queryKey: ["agents", city],
    queryFn: () => api.listAgents(city),
    enabled: !!city,
    refetchInterval: 5_000,
  });

export const useRigs = (city: string | null) =>
  useQuery({
    queryKey: ["rigs", city],
    queryFn: () => api.listRigs(city),
    enabled: !!city,
    refetchInterval: 30_000,
  });

export const useBeads = (city: string | null, rig: string | null) =>
  useQuery({
    queryKey: ["beads", city, rig],
    queryFn: () =>
      api.listBeads(city, { limit: 500, rig: rig ?? undefined }),
    enabled: !!city,
    refetchInterval: 5_000,
  });

export const useBead = (city: string | null, id: string | null) =>
  useQuery({
    queryKey: ["bead", city, id],
    queryFn: () => api.getBead(city, id!),
    enabled: !!id && !!city,
  });

export const useEvents = (city: string | null) =>
  useQuery({
    queryKey: ["events", city],
    queryFn: () => api.listEvents(city, { limit: 100 }),
    enabled: !!city,
    refetchInterval: 4_000,
  });

export const useOrders = (city: string | null) =>
  useQuery({
    queryKey: ["orders", city],
    queryFn: () => api.listOrders(city),
    enabled: !!city,
    refetchInterval: 15_000,
  });
