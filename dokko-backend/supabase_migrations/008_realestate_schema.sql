-- =====================================================================================
-- FASE 17: Schema del Módulo Inmobiliaria (Real Estate)
-- Ejecutar en el SQL Editor de Supabase
-- =====================================================================================

-- Agentes Inmobiliarios
CREATE TABLE IF NOT EXISTS realestate_agents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id), -- Opcional, si tiene cuenta en el sistema
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    commission_rate DECIMAL(5,2) DEFAULT 0, -- Porcentaje de comisión estándar (ej: 5.00)
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Propiedades (Inmuebles)
CREATE TABLE IF NOT EXISTS realestate_properties (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    
    -- Información básica
    title TEXT NOT NULL,
    description TEXT,
    property_type TEXT NOT NULL CHECK (property_type IN ('house', 'apartment', 'commercial', 'land', 'office', 'industrial')),
    operation_type TEXT NOT NULL CHECK (operation_type IN ('sale', 'rent', 'both')),
    status TEXT NOT NULL DEFAULT 'available' CHECK (status IN ('available', 'reserved', 'sold', 'rented', 'inactive')),
    
    -- Precios y financiero
    price_sale DECIMAL(14,2),
    price_rent DECIMAL(14,2),
    currency TEXT DEFAULT 'USD',
    hoa_fee DECIMAL(10,2), -- Gastos comunes / expensas
    property_tax DECIMAL(10,2),
    
    -- Dimensiones y características
    bedrooms INT DEFAULT 0,
    bathrooms DECIMAL(3,1) DEFAULT 0, -- 1.5 baños
    parking_spots INT DEFAULT 0,
    square_meters_built DECIMAL(10,2),
    square_meters_land DECIMAL(10,2),
    year_built INT,
    
    -- Ubicación
    address TEXT,
    city TEXT,
    state TEXT,
    zip_code TEXT,
    country TEXT,
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    
    -- Medios e integraciones
    images JSONB DEFAULT '[]'::JSONB, -- URLs
    features JSONB DEFAULT '[]'::JSONB, -- ["piscina", "gimnasio", "balcon"]
    mls_id TEXT, -- ID del Multiple Listing Service
    virtual_tour_url TEXT,
    
    -- Relaciones
    assigned_agent_id UUID REFERENCES realestate_agents(id),
    owner_name TEXT,
    owner_phone TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Leads (Clientes Potenciales)
CREATE TABLE IF NOT EXISTS realestate_leads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    source TEXT, -- 'website', 'facebook', 'referral', etc
    
    status TEXT NOT NULL DEFAULT 'new' CHECK (status IN ('new', 'contacted', 'visiting', 'negotiating', 'closed_won', 'closed_lost')),
    
    -- Preferencias de búsqueda
    interested_in TEXT CHECK (interested_in IN ('sale', 'rent')),
    budget_min DECIMAL(14,2),
    budget_max DECIMAL(14,2),
    preferred_cities JSONB DEFAULT '[]'::JSONB,
    min_bedrooms INT,
    
    assigned_agent_id UUID REFERENCES realestate_agents(id),
    interested_property_id UUID REFERENCES realestate_properties(id),
    
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Dossiers (Documentos / Presentaciones generadas)
CREATE TABLE IF NOT EXISTS realestate_dossiers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    property_id UUID REFERENCES realestate_properties(id),
    lead_id UUID REFERENCES realestate_leads(id),
    file_url TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Comisiones (Registro de ganancias por ventas/alquileres)
CREATE TABLE IF NOT EXISTS realestate_commissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    property_id UUID NOT NULL REFERENCES realestate_properties(id),
    lead_id UUID REFERENCES realestate_leads(id),
    agent_id UUID NOT NULL REFERENCES realestate_agents(id),
    
    amount DECIMAL(14,2) NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'cancelled')),
    
    closed_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================================================
-- RLS: Aislamiento estricto de todos los datos del módulo Inmobiliaria
-- =====================================================================================
ALTER TABLE realestate_agents ENABLE ROW LEVEL SECURITY;
ALTER TABLE realestate_properties ENABLE ROW LEVEL SECURITY;
ALTER TABLE realestate_leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE realestate_dossiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE realestate_commissions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "RealEstate: aislamiento por tenant" ON realestate_agents FOR ALL USING (tenant_id = public.tenant_id() OR public.is_super_admin());
CREATE POLICY "RealEstate: aislamiento por tenant" ON realestate_properties FOR ALL USING (tenant_id = public.tenant_id() OR public.is_super_admin());
CREATE POLICY "RealEstate: aislamiento por tenant" ON realestate_leads FOR ALL USING (tenant_id = public.tenant_id() OR public.is_super_admin());
CREATE POLICY "RealEstate: aislamiento por tenant" ON realestate_dossiers FOR ALL USING (tenant_id = public.tenant_id() OR public.is_super_admin());
CREATE POLICY "RealEstate: aislamiento por tenant" ON realestate_commissions FOR ALL USING (tenant_id = public.tenant_id() OR public.is_super_admin());

-- =====================================================================================
-- FIN DEL SCRIPT
-- =====================================================================================
