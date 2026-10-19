from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
import postgrest.exceptions

load_dotenv()

from app.core.supabase_client import supabase_admin
from app.core.auth import get_current_tenant_id
from app.modules.gym.router import router as gym_router
from app.modules.shared.agenda_router import router as agenda_router
from app.modules.realestate.router import router as realestate_router
from app.modules.salon.router import router as salon_router
from app.modules.messaging.router import router as messaging_router
from app.modules.billing.router import router as billing_router
from app.modules.super_admin.router import router as super_admin_router

app = FastAPI(
    title="Dokko Backend API",
    description="API Gateway para la plataforma Dokko. Valida JWTs de Supabase y aplica lógica de negocio por módulo.",
    version="1.0.0",
)

# CORS — permite llamadas desde el frontend web (Flutter web, Chrome dev, etc.)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(postgrest.exceptions.APIError)
async def postgrest_error_handler(request: Request, exc: postgrest.exceptions.APIError):
    code = getattr(exc, "code", "") or ""
    if code == "22P02":
        return JSONResponse(status_code=400, content={"detail": "Identificador no válido."})
    if "DOBLE_BOOKING" in str(exc):
        return JSONResponse(status_code=409, content={"detail": str(exc)})
    if code == "PGRST205":
        return JSONResponse(status_code=500, content={"detail": f"Tabla o columna no encontrada: {exc}"})
    return JSONResponse(status_code=500, content={"detail": f"Error de base de datos: {exc}"})

# Super-admin: usa service role (bypasea RLS) para operaciones privilegiadas
app.include_router(super_admin_router, prefix="/super-admin", tags=["Super Admin"])
app.include_router(gym_router, prefix="/gym", tags=["Gym"])
app.include_router(agenda_router, prefix="/agenda", tags=["Agenda"])
app.include_router(realestate_router, prefix="/realestate", tags=["Real Estate"])
app.include_router(salon_router, tags=["Salon"])
app.include_router(messaging_router, tags=["Messaging"])
app.include_router(billing_router, prefix="/billing", tags=["Billing"])

@app.get("/health")
def health_check():
    return {"status": "ok", "message": "Dokko API is running."}
