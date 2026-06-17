#!/usr/bin/env bash
# 50-exposicao.sh — Expõe o webhook na internet com HTTPS.
#   Docker: rota no Traefik (URL estável).
#   Nativo: Cloudflare Tunnel como serviço systemd (URL *.trycloudflare.com).
#
# TUNEL_UNIT / TUNEL_LOG / WEBHOOK_PORT vêm do 00-core (derivados de CLI_NAME),
# para que dois produtos na mesma VPS não colidam na unit do túnel.

passo_exposicao() {
  passo "ABRINDO COM SEGURANÇA PARA A INTERNET"
  if [[ "${MODO:-}" == "docker" ]]; then
    _exposicao_docker
  else
    _exposicao_nativo
  fi
}

# ── Docker: labels do Traefik ────────────────────────────────────────────────
_exposicao_docker() {
  local cf="$COMPOSE_FILE"
  source "$ENV_FILE" 2>/dev/null || true
  local projeto="${COMPOSE_PROJECT_NAME:-$(basename "$COMPOSE_DIR")}"
  local dominio="${projeto}.${TRAEFIK_HOST:-}"

  if grep -q "${projeto}-webhook" "$cf" 2>/dev/null; then
    ok "Rota HTTPS do webhook já configurada no Traefik."
  else
    backup_arquivo "$cf"
    COMPOSE_FILE="$cf" python3 - <<'PY'
import os
path = os.environ["COMPOSE_FILE"]
src = open(path, encoding="utf-8").read()
insert = (
"      - traefik.http.routers.${COMPOSE_PROJECT_NAME}.service=${COMPOSE_PROJECT_NAME}\n"
"      - traefik.http.routers.${COMPOSE_PROJECT_NAME}.priority=1\n"
"      - traefik.http.routers.${COMPOSE_PROJECT_NAME}-webhook.rule=Host(`${COMPOSE_PROJECT_NAME}.${TRAEFIK_HOST}`) && PathPrefix(`/webhooks`)\n"
"      - traefik.http.routers.${COMPOSE_PROJECT_NAME}-webhook.entrypoints=websecure\n"
"      - traefik.http.routers.${COMPOSE_PROJECT_NAME}-webhook.tls.certresolver=letsencrypt\n"
"      - traefik.http.routers.${COMPOSE_PROJECT_NAME}-webhook.service=${COMPOSE_PROJECT_NAME}-webhook\n"
"      - traefik.http.routers.${COMPOSE_PROJECT_NAME}-webhook.priority=10\n"
"      - traefik.http.services.${COMPOSE_PROJECT_NAME}-webhook.loadbalancer.server.port=8644\n"
)
target = "      - traefik.http.services.${COMPOSE_PROJECT_NAME}.loadbalancer.server.port=4860\n"
if target in src and "${COMPOSE_PROJECT_NAME}-webhook" not in src:
    src = src.replace(target, target + insert, 1)
    open(path, "w", encoding="utf-8").write(src)
    print("ok")
else:
    print("skip")
PY
    ( cd "$COMPOSE_DIR" && docker compose up -d >/dev/null 2>&1 ) || true
    ok "Rota HTTPS do webhook adicionada ao Traefik."
  fi

  local url="https://${dominio}/webhooks/zernio"
  salvar_var WEBHOOK_URL "$url"
  ok "Endereço do seu webhook (estável): $url"
}

# ── Nativo: Cloudflare Tunnel como serviço ───────────────────────────────────
_exposicao_nativo() {
  _instalar_cloudflared || return 1
  _instalar_servico_tunel
  _capturar_url_tunel
}

_instalar_cloudflared() {
  if command -v cloudflared >/dev/null 2>&1; then
    ok "cloudflared já está instalado."
    return 0
  fi
  info "Instalando o cloudflared (cria o túnel seguro)..."
  local arch deb
  arch="$(dpkg --print-architecture 2>/dev/null || echo amd64)"
  deb="/tmp/cloudflared.deb"
  if curl -fsSL -o "$deb" \
      "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${arch}.deb" 2>/dev/null \
      && dpkg -i "$deb" >/dev/null 2>&1; then
    ok "cloudflared instalado."
  else
    erro "Não consegui instalar o cloudflared automaticamente."
    dica "Instale manualmente (https://pkg.cloudflare.com) e rode '${CLI_NAME}' de novo."
    return 1
  fi
}

_instalar_servico_tunel() {
  local unit="/etc/systemd/system/${TUNEL_UNIT}.service"
  if [[ ! -f "$unit" ]]; then
    sed -e "s|__TUNEL_LOG__|${TUNEL_LOG}|g" \
        -e "s|__WEBHOOK_PORT__|${WEBHOOK_PORT}|g" \
        -e "s|__PRODUTO_NOME__|${PRODUTO_NOME}|g" \
        "$BASE_DIR/modelos/cloudflared.service.tmpl" > "$unit"
    systemctl daemon-reload
  fi
  : > "$TUNEL_LOG" 2>/dev/null || true
  systemctl enable --now "$TUNEL_UNIT" >/dev/null 2>&1 || systemctl restart "$TUNEL_UNIT"
  ok "Túnel seguro ligado (e religa sozinho se a VPS reiniciar)."
}

_capturar_url_tunel() {
  local url="" tentativa
  for tentativa in {1..15}; do
    url="$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$TUNEL_LOG" 2>/dev/null | tail -1 || true)"
    [[ -n "$url" ]] && break
    sleep 2
  done
  if [[ -z "$url" ]]; then
    dica "O túnel subiu mas ainda não mostrou o endereço. Rode '${CLI_NAME} doctor' em 1 minuto."
    return 0
  fi
  salvar_var WEBHOOK_URL "${url}/webhooks/zernio"
  ok "Endereço do seu webhook: ${url}/webhooks/zernio"
  caixa "IMPORTANTE: este endereço pode mudar se a VPS reiniciar." \
        "Se as respostas pararem, rode:  ${CLI_NAME} doctor" \
        "Ele mostra o endereço novo para você atualizar no Zernio."
}
