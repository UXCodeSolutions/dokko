-- 013: Imágenes de productos para el módulo gym (venta estilo tienda)
-- Añade la columna image_url y crea el bucket de storage con políticas por tenant.

ALTER TABLE gym_products ADD COLUMN IF NOT EXISTS image_url TEXT;

-- Bucket público para imágenes de productos
INSERT INTO storage.buckets (id, name, public)
VALUES ('product-images', 'product-images', true)
ON CONFLICT (id) DO NOTHING;

-- Subida: solo el dueño del tenant puede escribir en storage/{tenant_id}/
CREATE POLICY "Product Images: Subida por tenant" ON storage.objects
FOR INSERT TO authenticated WITH CHECK (
    bucket_id = 'product-images'
    AND (storage.foldername(name))[1] = (
        SELECT tenant_id::text FROM tenant_users WHERE user_id = auth.uid() LIMIT 1
    )
);

CREATE POLICY "Product Images: Actualización por tenant" ON storage.objects
FOR UPDATE TO authenticated
USING (
    bucket_id = 'product-images'
    AND (storage.foldername(name))[1] = (
        SELECT tenant_id::text FROM tenant_users WHERE user_id = auth.uid() LIMIT 1
    )
)
WITH CHECK (
    bucket_id = 'product-images'
    AND (storage.foldername(name))[1] = (
        SELECT tenant_id::text FROM tenant_users WHERE user_id = auth.uid() LIMIT 1
    )
);

CREATE POLICY "Product Images: Borrado por tenant" ON storage.objects
FOR DELETE TO authenticated USING (
    bucket_id = 'product-images'
    AND (storage.foldername(name))[1] = (
        SELECT tenant_id::text FROM tenant_users WHERE user_id = auth.uid() LIMIT 1
    )
);

-- Lectura pública
CREATE POLICY "Product Images: Lectura pública" ON storage.objects
FOR SELECT TO public USING (bucket_id = 'product-images');