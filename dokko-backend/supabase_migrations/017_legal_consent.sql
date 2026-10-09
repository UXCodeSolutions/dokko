-- FASE 25 — Ley 172-13 (Protección de Datos Personales)
-- Consentimiento individual + política de retención configurable por tenant.

alter table public.gym_members
    add column if not exists consent_granted_at timestamptz;

alter table public.realestate_leads
    add column if not exists consent_granted_at timestamptz;

alter table public.salon_clients
    add column if not exists consent_granted_at timestamptz;

alter table public.tenants
    add column if not exists retention_days integer not null default 90;