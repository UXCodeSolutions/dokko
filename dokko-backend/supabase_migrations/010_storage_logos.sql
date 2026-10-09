-- Crear el bucket de storage para logos
INSERT INTO storage.buckets (id, name, public) 
VALUES ('logos', 'logos', true)
ON CONFLICT (id) DO NOTHING;

-- Política para que usuarios autenticados puedan subir logos
CREATE POLICY "Logos: Subida permitida" ON storage.objects
FOR INSERT TO authenticated WITH CHECK (bucket_id = 'logos');

-- Política para lectura pública de los logos
CREATE POLICY "Logos: Lectura pública" ON storage.objects
FOR SELECT TO public USING (bucket_id = 'logos');
