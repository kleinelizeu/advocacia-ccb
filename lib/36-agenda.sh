#!/usr/bin/env bash
# 36-agenda.sh — Conecta a agenda do negócio (Google Calendar) para o agente MARCAR sozinho.
# Só roda quando o produto.conf tem AGENDA="google" (passo condicional no instalar.sh).
#
# Modelo de auth: SERVICE ACCOUNT, SEM domain-wide delegation — o aluno compartilha a agenda
# com o e-mail do service account (Gmail pessoal funciona). Sem token que expira → autônomo.
# O conector é modelos/gcal_mcp.py (rodado via `uv run`, deps via PEP 723). Validado na VPS:
# `hermes mcp add gcal --command uv --args run <script> --env GOOGLE_APPLICATION_CREDENTIALS=...
#  --env GOOGLE_CALENDAR_ID=...` conecta e expõe consultar_disponibilidade/listar_eventos/criar_evento.

passo_agenda() {
  passo "CONECTAR A AGENDA (GOOGLE CALENDAR)"
  cat <<'EOT'
  Para o agente MARCAR sozinho na sua Google Agenda, você cria uma "conta de serviço"
  (de graça) e compartilha sua agenda com ela. É uma vez só:

   1. Entre em https://console.cloud.google.com e crie/escolha um projeto.
   2. Ative a API:  procure "Google Calendar API"  ->  Ativar.
   3. Crie a conta de serviço:  "IAM e administração" -> "Contas de serviço" -> Criar.
   4. Nela:  Chaves -> Adicionar chave -> Criar nova -> JSON  -> baixe o arquivo.
   5. Copie o e-mail da conta de serviço (termina com ...iam.gserviceaccount.com).
   6. No Google Agenda (calendar.google.com) -> Configurações da agenda ->
      "Compartilhar com pessoas/grupos específicos" -> adicione esse e-mail
      com a permissão  "Fazer alterações nos eventos".
EOT
  echo
  _agenda_garantir_uv   || return 1
  _agenda_coletar_sa    || return 1
  perguntar GCAL_ID "Qual o e-mail da Google Agenda onde o agente deve marcar? (normalmente o seu e-mail do Google)" \
    valida_nao_vazio
  salvar_var GCAL_ID "$GCAL_ID"
  _agenda_registrar_mcp
}

# Garante o 'uv' (roda o conector da agenda com as deps isoladas).
_agenda_garantir_uv() {
  if command -v uv >/dev/null 2>&1; then ok "uv presente."; return 0; fi
  info "Instalando o uv (motor que roda o conector da agenda)..."
  curl -LsSf https://astral.sh/uv/install.sh 2>/dev/null | sh >/dev/null 2>&1 || true
  export PATH="/root/.local/bin:$HOME/.local/bin:$PATH"
  if command -v uv >/dev/null 2>&1; then ok "uv instalado."
  else erro "Não consegui instalar o uv."; dica "Instale o uv (https://astral.sh/uv) e rode '${CLI_NAME}' de novo."; return 1; fi
}

# Coleta o JSON do service account (colar até a linha FIM) e guarda em $ESTADO_DIR/gcal-sa.json.
_agenda_coletar_sa() {
  local dest="$ESTADO_DIR/gcal-sa.json"
  if [[ -f "$dest" ]] && _agenda_json_valido "$dest"; then
    GCAL_SA_PATH="$dest"; salvar_var GCAL_SA_PATH "$dest"
    ok "Já tenho a credencial da agenda guardada (de antes)."
    return 0
  fi
  info "Cole agora TODO o conteúdo do arquivo JSON da conta de serviço."
  info "Quando terminar, digite numa linha sozinha:  FIM"
  printf '%s> ' ""
  local tmp linha; tmp="$(mktemp)"
  while IFS= read -r linha </dev/tty; do
    [[ "$linha" == "FIM" ]] && break
    printf '%s\n' "$linha" >> "$tmp"
  done
  if ! _agenda_json_valido "$tmp"; then
    erro "Isso não parece um JSON de conta de serviço válido (precisa de type=service_account, client_email e private_key)."
    rm -f "$tmp"; dica "Baixe o JSON de novo (passo 4) e cole inteiro."; return 1
  fi
  mkdir -p "$ESTADO_DIR"; chmod 700 "$ESTADO_DIR"
  mv "$tmp" "$dest"; chmod 600 "$dest"
  GCAL_SA_PATH="$dest"; salvar_var GCAL_SA_PATH "$dest"
  local email; email="$(python3 -c "import json;print(json.load(open('$dest')).get('client_email',''))" 2>/dev/null)"
  ok "Credencial da agenda guardada (só aqui na sua VPS)."
  caixa "CONFIRME: compartilhe sua Google Agenda com este e-mail," "$email" "com a permissão 'Fazer alterações nos eventos'."
}

_agenda_json_valido() {
  python3 -c "import json,sys;d=json.load(open('$1'));sys.exit(0 if d.get('type')=='service_account' and d.get('client_email') and d.get('private_key') else 1)" 2>/dev/null
}

_agenda_mcp_registrado() { hermes_cli mcp list 2>/dev/null | grep -qi gcal; }

# Registra o conector como MCP 'gcal' no agente.
_agenda_registrar_mcp() {
  local uv script
  uv="$(command -v uv || echo /root/.local/bin/uv)"
  script="$BASE_DIR/modelos/gcal_mcp.py"
  [[ -f "$script" ]] || { erro "Conector da agenda não encontrado ($script)."; return 1; }
  if _agenda_mcp_registrado; then ok "Agenda já conectada ao agente."; return 0; fi
  info "Conectando a agenda ao agente (pode baixar dependências na 1ª vez)..."
  # Credenciais vão como ARGUMENTOS POSICIONAIS (caminho do SA + id da agenda), não via --env:
  # alguns hosts MCP não propagam --env ao subprocesso (validado na VPS). NÃO redirecionar
  # stdin de /dev/null: o 'yes' responde ao prompt "Enable all tools?".
  yes 2>/dev/null | hermes_cli mcp add gcal --command "$uv" --args run "$script" "$GCAL_SA_PATH" "$GCAL_ID" >/dev/null 2>&1 || true
  if _agenda_mcp_registrado; then
    _reiniciar_gateway
    ok "Agenda conectada! O agente agora marca os agendamentos sozinho."
  else
    dica "Não consegui conectar a agenda automaticamente."
    dica "Rode '${CLI_NAME} doctor' (ele tenta de novo) ou rode '${CLI_NAME}' novamente."
  fi
}

# Checagem do doctor (chamada por 90-checks só quando AGENDA está ligada).
check_agenda() {
  if [[ -f "${GCAL_SA_PATH:-/dev/null}" ]] && _agenda_json_valido "${GCAL_SA_PATH}"; then
    _chk "Credencial da agenda (service account) presente."
  else
    _bad "Credencial da agenda ausente/incompleta — rode '${CLI_NAME}' (passo da agenda)."
  fi
  if hermes_cli mcp list 2>/dev/null | grep -qi gcal; then
    _chk "Google Calendar conectado (o agente marca sozinho)."
  else
    _bad "Google Calendar não conectado. Rode '${CLI_NAME}' (passo da agenda) para reconectar."
  fi
}
