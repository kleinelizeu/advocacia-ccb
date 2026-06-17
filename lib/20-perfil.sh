#!/usr/bin/env bash
# 20-perfil.sh — Cria o perfil dedicado (nome em PERFIL_PADRAO) e configura o Telegram dele.
#
# NOTA: nomes exatos de comandos/variáveis do Hermes podem variar entre versões.
# O passo é defensivo: tenta editar direto; se não reconhecer o formato, cai no
# assistente interativo do próprio Hermes (que guia o aluno).
#
# PERFIL_PADRAO vem do produto.conf (ex.: "clinica", "restaurante", "advocacia").

# Define PERFIL e caminhos derivados; salva no estado.
_definir_perfil() {
  local nome="${PERFIL:-$PERFIL_PADRAO}"
  if [[ "${MODO:-}" == "nativo" ]] && _perfil_existe "$nome" && ! passo_concluido perfil; then
    titulo "Já existe um agente chamado '$nome' nesta VPS."
    info "1) Usar/atualizar esse mesmo"
    info "2) Criar outro com um nome novo"
    local op; MENU_MAX=2
    perguntar op "O que prefere? (1 ou 2)" valida_opcao_menu "Digite 1 ou 2."
    if [[ "$op" == "2" ]]; then
      perguntar nome "Nome do novo agente (só letras minúsculas, ex.: ${PERFIL_PADRAO}loja):" \
        valida_nome_perfil "Use só letras minúsculas e números, começando por letra."
    fi
  fi
  salvar_var PERFIL "$nome"
  if [[ "${MODO:-}" == "nativo" ]]; then
    salvar_var PERFIL_DIR "/root/.hermes/profiles/$nome"
    salvar_var CONFIG_FILE "/root/.hermes/profiles/$nome/config.yaml"
    salvar_var ENV_FILE "/root/.hermes/profiles/$nome/.env"
    salvar_var PERFIL_BIN "/root/.local/bin/$nome"
    salvar_var GATEWAY_SVC "hermes-gateway-$nome"
  fi
}

_perfil_existe() {
  local nome="$1"
  if [[ "${MODO:-}" == "nativo" ]]; then
    [[ -d "/root/.hermes/profiles/$nome" ]] && return 0
    hermes profile list 2>/dev/null | grep -qw "$nome"
  else
    return 1   # Docker: o agente é o do container (sem perfis múltiplos por padrão)
  fi
}

passo_perfil() {
  passo "CRIANDO O SEU AGENTE"
  _definir_perfil

  if [[ "${MODO:-}" == "docker" ]]; then
    nota "No Docker usamos o agente do próprio container."
    salvar_var PERFIL "default"
    _configurar_telegram_docker
    return 0
  fi

  # ── Nativo ──
  if _perfil_existe "$PERFIL"; then
    ok "Agente '$PERFIL' já existe — vou só conferir a configuração."
  else
    info "Criando o agente '$PERFIL' (copiando o que já funciona do seu Hermes)..."
    if hermes profile create "$PERFIL" --clone >/dev/null 2>&1; then
      ok "Agente '$PERFIL' criado."
    else
      erro "Não consegui criar o agente automaticamente."
      dica "Rode manualmente:  hermes profile create $PERFIL --clone   e depois rode este assistente de novo."
      return 1
    fi
  fi

  _reconfigurar_telegram_nativo
  _instalar_servico_nativo
}

# Escreve o token/IDs do Telegram no .env do perfil (corrige o vazamento do --clone).
# Usa os nomes de variáveis oficiais do Hermes (v0.16):
#   TELEGRAM_BOT_TOKEN, TELEGRAM_ALLOWED_USERS, TELEGRAM_HOME_CHANNEL
_reconfigurar_telegram_nativo() {
  local env="$ENV_FILE"
  [[ -f "$env" ]] || { touch "$env"; chmod 600 "$env"; }
  backup_arquivo "$env"
  _set_env_var "$env" "TELEGRAM_BOT_TOKEN"      "$TELEGRAM_BOT_TOKEN"
  _set_env_var "$env" "TELEGRAM_ALLOWED_USERS"  "$TELEGRAM_CHAT_ID"
  _set_env_var "$env" "TELEGRAM_HOME_CHANNEL"   "$TELEGRAM_CHAT_ID"
  ok "Telegram do agente configurado com o seu bot novo (@${BOT_USERNAME:-?})."
  _avisar_outros_tokens "$env"
}

# _set_env_var arquivo CHAVE valor — substitui ou adiciona CHAVE=valor.
_set_env_var() {
  local arq="$1" chave="$2" valor="$3" tmp
  tmp="$(mktemp)"
  grep -viE "^${chave}=" "$arq" > "$tmp" 2>/dev/null || true
  printf '%s=%s\n' "$chave" "$valor" >> "$tmp"
  mv "$tmp" "$arq"
  chmod 600 "$arq" 2>/dev/null || true
}

# O --clone pode ter trazido outros tokens (Discord etc.). Alerta para rotacionar.
_avisar_outros_tokens() {
  local env="$1"
  if grep -qiE '(DISCORD|SLACK|WHATSAPP).*TOKEN' "$env"; then
    dica "Atenção: este perfil herdou tokens de outros serviços (Discord/Slack) do seu Hermes."
    dica "Por segurança, considere remover/rotacionar o que você não vai usar."
  fi
}

# Instala o serviço do gateway (liga no boot) e descobre o nome real do unit.
_instalar_servico_nativo() {
  local svc
  svc="$(_descobrir_unit)"
  if [[ -z "$svc" ]]; then
    info "Instalando o serviço que mantém o agente ligado..."
    # --run-as-user root: VPS de aluno roda como root (containers/LXC).
    # 'yes |' responde os prompts (instalar agora? iniciar no boot?).
    yes | "$PERFIL_BIN" gateway install --system --run-as-user root >/dev/null 2>&1 || true
    svc="$(_descobrir_unit)"
  fi
  if [[ -n "$svc" ]]; then
    salvar_var GATEWAY_SVC "$svc"
    systemctl restart "$svc" 2>/dev/null || systemctl start "$svc" 2>/dev/null || true
    ok "Agente ligado (serviço: $svc)."
  else
    dica "Não consegui instalar o serviço automaticamente."
    dica "Rode manualmente:  $PERFIL_BIN gateway install --system --run-as-user root"
  fi
}

# Localiza o unit systemd do gateway deste perfil (nome varia entre versões).
_descobrir_unit() {
  systemctl list-unit-files 2>/dev/null \
    | grep -oE "hermes[a-z-]*gateway[a-z-]*${PERFIL}[a-z-]*\.service|hermes[a-z-]*${PERFIL}[a-z-]*\.service" \
    | head -1
}

# Docker: garante que o token do Telegram do container é o do aluno.
_configurar_telegram_docker() {
  local env="$ENV_FILE"
  [[ -f "$env" ]] || { touch "$env"; }
  backup_arquivo "$env"
  _set_env_var "$env" "TELEGRAM_BOT_TOKEN"     "$TELEGRAM_BOT_TOKEN"
  _set_env_var "$env" "TELEGRAM_ALLOWED_USERS" "$TELEGRAM_CHAT_ID"
  _set_env_var "$env" "TELEGRAM_HOME_CHANNEL"  "$TELEGRAM_CHAT_ID"
  ok "Telegram configurado no container (vale após o restart)."
}
