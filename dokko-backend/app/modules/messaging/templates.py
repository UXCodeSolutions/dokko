"""Plantillas por defecto de mensajería y motor de renderizado.

Las plantillas usan marcadores {{clave}}. El backend renderiza el mensaje final
antes de guardarlo, de modo que el personal solo abre WhatsApp y envía.
"""

DEFAULT_TEMPLATES: dict = {
    "salon": {
        "salon.reminder": {
            "label": "Recordatorio de cita",
            "body": (
                "Hola {{client}}! 👋 {{business}} te recuerda tu cita del "
                "{{date}} a las {{time}}. Te esperamos 💈"
            ),
        },
        "salon.waitlist_slot": {
            "label": "Cupo libre (lista de espera)",
            "body": (
                "Hola {{client}}! 😊 Quedó libre un espacio en {{business}}. "
                "Eres primero en la lista de espera. Escríbenos para reservar "
                "tu visita 🙌"
            ),
        },
        "salon.feedback": {
            "label": "Feedback post-servicio",
            "body": (
                "Hola {{client}}, esperamos que hayas disfrutado tu visita a "
                "{{business}}. Cuéntanos cómo estuvo: {{link}}"
            ),
        },
    },
    "gym": {
        "gym.reminder": {
            "label": "Recordatorio de membresía",
            "body": (
                "Hola {{member}}! 👋 Te recordamos que tu membresía en "
                "{{business}} vence el {{date}}. ¡No dejes de entrenar! 🔥"
            ),
        },
    },
    "realestate": {
        "re.lead": {
            "label": "Primer contacto con lead",
            "body": "Hola {{lead}}! 👋 Soy {{agent}} de {{business}}.",
        },
    },
}


def render(body: str, params: dict) -> str:
    """Sustituye {{clave}} = value. Las claves ausentes se dejan como están."""
    out = body
    for key, value in (params or {}).items():
        out = out.replace("{{" + key + "}}", str(value))
    return out


def default_template(module: str, key: str) -> dict:
    module_templates = DEFAULT_TEMPLATES.get(module, {})
    return module_templates.get(key)