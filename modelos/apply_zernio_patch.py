#!/usr/bin/env python3
"""Adiciona suporte ao header X-Zernio-Signature no webhook do Hermes. Idempotente.

Funciona em Docker e no nativo. O caminho do webhook.py vem do argumento 1
ou da variável de ambiente HERMES_WEBHOOK_PY; se nenhum for dado, tenta os
locais conhecidos. Sair com 0 sempre (não derrubar o start do gateway).
"""
from pathlib import Path
import os
import sys


def candidatos():
    arg = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("HERMES_WEBHOOK_PY", "")
    if arg:
        yield Path(arg)
    yield Path("/opt/hermes/gateway/platforms/webhook.py")
    yield Path("/usr/local/lib/hermes-agent/gateway/platforms/webhook.py")


def patch_webhook(target: Path) -> None:
    src = target.read_text()
    if "# Zernio: X-Zernio-Signature" in src:
        return  # já aplicado

    old = "        # Generic: X-Webhook-Signature"
    new = (
        "        # Zernio: X-Zernio-Signature = <hex HMAC-SHA256 do corpo>\n"
        "        zernio_sig = request.headers.get(\"X-Zernio-Signature\", \"\")\n"
        "        if zernio_sig:\n"
        "            expected = hmac.new(\n"
        "                secret.encode(), body, hashlib.sha256\n"
        "            ).hexdigest()\n"
        "            return hmac.compare_digest(zernio_sig, expected)\n"
        "\n"
        "        # Generic: X-Webhook-Signature"
    )
    if old in src:
        target.write_text(src.replace(old, new, 1))


def patch_openai_sdk() -> None:
    """Corrige crash de NoneType no SDK da OpenAI (response.output None)."""
    try:
        import openai
    except Exception:
        return
    sdk = Path(openai.__file__).parent / "lib" / "_parsing" / "_responses.py"
    if not sdk.exists():
        return
    s = sdk.read_text()
    old = "for output in response.output:"
    new = "for output in (response.output or []):"
    if old in s and new not in s:
        sdk.write_text(s.replace(old, new, 1))


def main() -> int:
    for target in candidatos():
        if target.exists():
            try:
                patch_webhook(target)
            except Exception:
                pass
            break
    patch_openai_sdk()
    return 0


if __name__ == "__main__":
    sys.exit(main())
