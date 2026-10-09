from urllib.parse import quote
import re
from typing import Optional


class MessageProvider:
    """Interfaz de proveedor de mensajería. (FASE 28: piloto deep-link a WhatsApp).

    El piloto usa WaDeepLinkProvider (gratis, el personal abre el enlace y envía).
    En el futuro un WhatsAppCloudProvider puede cubrir el envío 100% automático.
    """

    def build_link(self, phone_digits: str, body: str) -> str:
        raise NotImplementedError


class WaDeepLinkProvider(MessageProvider):
    """Genera https://wa.me/<tel>?text=<mensaje prefabricado> sin tocar la API."""

    def build_link(self, phone_digits: str, body: str) -> str:
        return f"https://wa.me/{phone_digits}?text={quote(body)}"


def normalize_phone(phone: Optional[str]) -> Optional[str]:
    """Normaliza un teléfono a dígitos E.164 (sin '+') para wa.me.

    Asume República Dominicana: números de 10 dígitos → prefijo '+1'.
    Devuelve None si no hay suficientes dígitos para un enlace válido.
    """
    if not phone:
        return None
    digits = re.sub(r"\D", "", str(phone))
    if not digits:
        return None
    if digits.startswith("1") and len(digits) == 11:
        return digits
    if len(digits) == 10:
        return "1" + digits
    if len(digits) in (11, 12):
        return digits
    return None