import os
import jwt
import requests
from typing import Optional
from fastapi import Depends, HTTPException, status, Header
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.core.supabase_client import supabase_admin

SUPABASE_JWT_SECRET = os.getenv("SUPABASE_JWT_SECRET", "")
SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY", "")

security = HTTPBearer()


def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> dict:
    """
    Valida el JWT de Supabase.
    Intenta verificación local con HS256 primero; si falla (proyectos nuevos con RS256),
    hace introspección via Supabase Auth API.
    """
    token = credentials.credentials

    # Intento 1: verificación local HS256 (proyectos legacy)
    if SUPABASE_JWT_SECRET:
        try:
            payload = jwt.decode(
                token,
                SUPABASE_JWT_SECRET,
                algorithms=["HS256"],
                audience="authenticated",
            )
            return payload
        except jwt.ExpiredSignatureError:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token expirado.")
        except jwt.InvalidTokenError:
            pass  # Puede ser RS256, intentar introspección

    # Intento 2: introspección via Supabase Auth API (proyectos nuevos con RS256/asimétrico)
    try:
        resp = requests.get(
            f"{SUPABASE_URL}/auth/v1/user",
            headers={
                "Authorization": f"Bearer {token}",
                "apikey": SUPABASE_SERVICE_KEY,
            },
            timeout=5,
        )
        if resp.status_code == 200:
            user_data = resp.json()
            # Normalizamos al mismo formato que el payload JWT
            return {
                "sub": user_data.get("id"),
                "email": user_data.get("email"),
                "app_metadata": user_data.get("app_metadata", {}),
                "user_metadata": user_data.get("user_metadata", {}),
                "role": user_data.get("role", "authenticated"),
            }
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token inválido.")
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token inválido.")


def get_current_tenant_id(
    user: dict = Depends(get_current_user),
    x_support_tenant_id: Optional[str] = Header(default=None, alias="X-Support-Tenant-Id"),
) -> str:
    """Extrae el tenant_id del app_metadata del JWT, o permite a super-admins usar X-Support-Tenant-Id."""
    app_meta = user.get("app_metadata", {})

    if app_meta.get("is_super_admin"):
        if not x_support_tenant_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Super-admin debe proporcionar X-Support-Tenant-Id para acceder a datos de un módulo.",
            )
        # Validar que el tenant realmente existe antes de confiar en el header
        tenant_check = supabase_admin.table("tenants").select("id").eq("id", x_support_tenant_id).execute()
        if not tenant_check.data:
            raise HTTPException(status_code=404, detail="Tenant no encontrado.")
        return x_support_tenant_id

    tenant_id = app_meta.get("tenant_id")
    if not tenant_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="El usuario no pertenece a ningún tenant.",
        )

    # Verificar que el negocio está activo (no suspendido/cancelado)
    tenant_check = supabase_admin.table("tenants").select("status").eq("id", tenant_id).maybe_single().execute()
    tenant_status = (tenant_check.data or {}).get("status") if tenant_check is not None else None
    if tenant_status != "active":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Este negocio está suspendido o cancelado. Contacta a Dokko.",
        )

    return tenant_id


def require_super_admin(user: dict = Depends(get_current_user)) -> dict:
    """Verifica que el usuario sea super-admin."""
    app_meta = user.get("app_metadata", {})
    if not app_meta.get("is_super_admin"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acceso restringido a super-admins.",
        )
    return user
