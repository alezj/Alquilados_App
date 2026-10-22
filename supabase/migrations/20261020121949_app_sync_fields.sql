-- Campos que usa la app local-first y que faltaban en las tablas existentes.
ALTER TABLE public.alquileres
  ADD COLUMN IF NOT EXISTS importe numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS "montoPago" numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS "cantidadDepositos" integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS "diaPago" integer NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS "cantidadMeses" integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS estado text NOT NULL DEFAULT 'Pendiente';

ALTER TABLE public.pagos
  ADD COLUMN IF NOT EXISTS "idAlquiler" bigint,
  ADD COLUMN IF NOT EXISTS periodo text,
  ADD COLUMN IF NOT EXISTS estado text NOT NULL DEFAULT 'Pendiente';

DO $$ BEGIN
  ALTER TABLE public.pagos
    ADD CONSTRAINT pagos_idAlquiler_fkey
    FOREIGN KEY ("idAlquiler") REFERENCES public.alquileres(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
