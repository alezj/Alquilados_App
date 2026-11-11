-- Additive fields: existing contracts keep a zero-day grace period.
ALTER TABLE public.alquileres
  ADD COLUMN IF NOT EXISTS "diasProrroga" integer NOT NULL DEFAULT 0
  CHECK ("diasProrroga" BETWEEN 0 AND 365);
ALTER TABLE public.inquilinos
  ADD COLUMN IF NOT EXISTS telefono text;
