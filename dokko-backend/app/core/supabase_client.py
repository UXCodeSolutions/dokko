import os
import time
import httpx
import httpcore
from supabase import create_client, Client
from supabase.lib.client_options import SyncClientOptions
from functools import lru_cache
import postgrest._sync.request_builder as _pgrqb

SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY", "")

# El cliente por defecto de supabase-py usa HTTP/2 (postgrest/_sync/client.py http2=True),
# lo que provoca fallos intermitentes "httpcore.ReadError: [Errno 35] Resource temporarily
# unavailable" contra el HAProxy de Supabase. Forzamos HTTP/1.1 con nuestro propio cliente.
_HTTPX_CLIENT = httpx.Client(
    follow_redirects=True,
    timeout=httpx.Timeout(60.0, connect=15.0),
    limits=httpx.Limits(max_keepalive_connections=10, max_connections=25),
)

# Supabase también devuelve timeouts raros en su edge (ej. "Gateway Timeout"). postgrest
# solo reintenta 503/520 en GET/HEAD; añadimos reintento para fallos de transporte
# transitorios en lecturas idempotentes (GET/HEAD). Las escrituras se dejan a un solo intento
# para evitar dobles inserts.
_TRANSIENT = (
    httpx.ReadError,
    httpx.TimeoutException,
    httpx.ConnectError,
    httpx.RemoteProtocolError,
    httpx.NetworkError,
    httpx.TransportError,
    httpcore.ReadError,
    httpcore.ConnectError,
    httpcore.RemoteProtocolError,
    httpcore.NetworkError,
    httpcore.TimeoutException,
)

_ORIG_SEND_WITH_RETRY = _pgrqb.send_with_retry


def _safe_send_with_retry(req):
    last_exc = None
    for attempt in range(4):
        try:
            return _ORIG_SEND_WITH_RETRY(req)
        except _TRANSIENT as exc:  # noqa: PERF203
            last_exc = exc
            if req.http_method not in ("GET", "HEAD") or not getattr(
                req, "retry_enabled", True
            ):
                raise
            time.sleep(0.3 * (attempt + 1))
    raise last_exc


_pgrqb.send_with_retry = _safe_send_with_retry


@lru_cache(maxsize=1)
def get_supabase_admin() -> Client:
    """
    Cliente con Service Role Key — bypassa RLS para operaciones del backend.
    NUNCA exponer esta key al frontend.
    """
    options = SyncClientOptions(httpx_client=_HTTPX_CLIENT)
    return create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY, options=options)


# Alias para imports directos (inicialización lazy en primera llamada)
class _LazyClient:
    def __getattr__(self, name):
        return getattr(get_supabase_admin(), name)


supabase_admin = _LazyClient()