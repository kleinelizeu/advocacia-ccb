#!/usr/bin/env bash
# 11-negocio.sh — Motor genérico do questionário do negócio (data-driven).
#
# As perguntas de cada nicho ficam em  nicho/negocio.perguntas  (formato declarativo,
# sem bash) e o template do contexto em  nicho/business-context.template.md.
# Este arquivo é IDÊNTICO em todos os produtos (vem do installer-kit-ccb).
#
# Formato de nicho/negocio.perguntas (blocos separados por linha em branco):
#
#   # comentário (linha começando com #)
#   [campo]
#   placeholder = NOME_NEGOCIO        # nome do {{PLACEHOLDER}} no template
#   tipo        = texto               # texto | instagram   (default: texto)
#   valida      = valida_nao_vazio    # função validadora (opcional)
#   dica        = ...                 # mensagem se a validação falhar (opcional)
#   opcional    = sim                 # campo pode ficar vazio (opcional)
#   default     = (sob consulta)      # valor se ficar vazio (opcional)
#   texto       = Qual o nome do seu negócio?
#
#   [menu]
#   placeholder = TOM_DE_VOZ_DESCRICAO
#   titulo      = Como você fala com o cliente?
#   texto       = Escolha (1 a N):
#   opcao       = Rótulo curto | Frase que entra no contexto do agente.
#   opcao       = Outro rótulo | Outra frase.
#   outro       = sim                 # adiciona opção "Outro (eu descrevo)" (opcional)

_US=$'\x1f'   # separa rótulo|texto de uma opção
_RS=$'\x1e'   # separa opções entre si

# Arrays paralelos (preenchidos por _carregar_perguntas)
PERG_TIPO=(); PERG_PLACEHOLDER=(); PERG_VALIDA=(); PERG_DICA=()
PERG_OPCIONAL=(); PERG_DEFAULT=(); PERG_TITULO=(); PERG_TEXTO=()
PERG_OPCOES=(); PERG_OUTRO=(); PERG_N=0

_trim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }

_carregar_perguntas() {
  local arquivo="$1" linha t chave valor lab txt
  local i=-1
  PERG_TIPO=(); PERG_PLACEHOLDER=(); PERG_VALIDA=(); PERG_DICA=()
  PERG_OPCIONAL=(); PERG_DEFAULT=(); PERG_TITULO=(); PERG_TEXTO=()
  PERG_OPCOES=(); PERG_OUTRO=()
  [[ -f "$arquivo" ]] || { erro "Arquivo de perguntas não encontrado: $arquivo"; return 1; }
  while IFS= read -r linha || [[ -n "$linha" ]]; do
    t="$(_trim "$linha")"
    [[ -z "$t" || "${t:0:1}" == "#" ]] && continue
    case "$t" in
      "[campo]"|"[menu]")
        i=$((i+1))
        [[ "$t" == "[menu]" ]] && PERG_TIPO[i]="menu" || PERG_TIPO[i]="texto"
        PERG_PLACEHOLDER[i]=""; PERG_VALIDA[i]=""; PERG_DICA[i]=""
        PERG_OPCIONAL[i]=""; PERG_DEFAULT[i]=""; PERG_TITULO[i]=""
        PERG_TEXTO[i]=""; PERG_OPCOES[i]=""; PERG_OUTRO[i]=""
        ;;
      *)
        [[ "$t" == *"="* && $i -ge 0 ]] || continue
        chave="$(_trim "${t%%=*}")"
        valor="$(_trim "${t#*=}")"
        case "$chave" in
          tipo)        [[ "$valor" == "menu" ]] || PERG_TIPO[i]="$valor" ;;
          placeholder) PERG_PLACEHOLDER[i]="$valor" ;;
          valida)      PERG_VALIDA[i]="$valor" ;;
          dica)        PERG_DICA[i]="$valor" ;;
          opcional)    PERG_OPCIONAL[i]="1" ;;
          default)     PERG_DEFAULT[i]="$valor" ;;
          titulo)      PERG_TITULO[i]="$valor" ;;
          texto)       PERG_TEXTO[i]="$valor" ;;
          outro)       PERG_OUTRO[i]="1" ;;
          opcao)
            lab="$(_trim "${valor%%|*}")"
            txt="$(_trim "${valor#*|}")"
            if [[ -n "${PERG_OPCOES[i]}" ]]; then
              PERG_OPCOES[i]="${PERG_OPCOES[i]}${_RS}${lab}${_US}${txt}"
            else
              PERG_OPCOES[i]="${lab}${_US}${txt}"
            fi
            ;;
        esac
        ;;
    esac
  done < "$arquivo"
  PERG_N=$((i+1))
  (( PERG_N > 0 )) || { erro "Nenhuma pergunta válida em $arquivo."; return 1; }
}

# Pergunta um registro (texto/instagram ou menu) e salva no estado sob o placeholder.
_perguntar_registro() {
  local i="$1"
  local ph="${PERG_PLACEHOLDER[i]}" tipo="${PERG_TIPO[i]}"
  [[ -n "$ph" ]] || { erro "Pergunta #$i sem placeholder — pulando."; return 0; }

  if [[ "$tipo" == "menu" ]]; then
    [[ -n "${PERG_TITULO[i]}" ]] && titulo "${PERG_TITULO[i]}"
    local -a labels=() textos=() recs=()
    local oldIFS="$IFS" r n=0
    IFS="$_RS" read -ra recs <<< "${PERG_OPCOES[i]}"; IFS="$oldIFS"
    for r in "${recs[@]}"; do
      labels+=( "${r%%"$_US"*}" )
      textos+=( "${r#*"$_US"}" )
      n=$((n+1)); info "$n) ${labels[n-1]}"
    done
    local extra_outro=""
    if [[ "${PERG_OUTRO[i]}" == "1" ]]; then
      n=$((n+1)); info "$n) Outro (eu descrevo)"; extra_outro="$n"
    fi
    MENU_MAX="$n"
    local escolha
    perguntar escolha "${PERG_TEXTO[i]:-Escolha:}" valida_opcao_menu "Digite um número de 1 a $n."
    if [[ -n "$extra_outro" && "$escolha" == "$extra_outro" ]]; then
      local livre; perguntar livre "Descreva em uma frase:" valida_nao_vazio
      salvar_var "$ph" "$livre"
    else
      salvar_var "$ph" "${textos[escolha-1]}"
    fi
    return 0
  fi

  # texto / instagram
  local valida="${PERG_VALIDA[i]}" dica_erro="${PERG_DICA[i]}"
  if [[ "$tipo" == "instagram" ]]; then
    [[ -n "$valida" ]] || valida="valida_instagram"
    [[ -n "$dica_erro" ]] || dica_erro="Use só letras, números, ponto e _ (ex.: @minhaloja)."
  fi
  [[ -n "$dica_erro" ]] || dica_erro="Tenta de novo?"
  local -a flags=()
  [[ "${PERG_OPCIONAL[i]}" == "1" ]] && flags+=( --opcional )

  perguntar "$ph" "${PERG_TEXTO[i]}" "$valida" "$dica_erro" "${flags[@]}"
  # Default quando ficou vazio (campo opcional).
  if [[ -z "${!ph:-}" && -n "${PERG_DEFAULT[i]}" ]]; then
    printf -v "$ph" '%s' "${PERG_DEFAULT[i]}"
  fi
  # Prefixo @ no Instagram.
  if [[ "$tipo" == "instagram" ]]; then
    local v="${!ph:-}"; [[ -n "$v" && "$v" != @* ]] && printf -v "$ph" '%s' "@$v"
  fi
  salvar_var "$ph" "${!ph:-}"
}

passo_negocio() {
  passo "PASSO 4 DE 4 — Sobre o seu negócio"
  cat <<'EOT'
  Agora me conta sobre o seu negócio. Não precisa caprichar na escrita —
  responde do seu jeito, como se explicasse pra um amigo. O assistente
  transforma isso nas "instruções de trabalho" do seu agente.
EOT

  _carregar_perguntas "$BASE_DIR/nicho/negocio.perguntas" || return 1
  local idx
  for (( idx=0; idx<PERG_N; idx++ )); do
    _perguntar_registro "$idx"
  done

  _gerar_contexto
  _revisar_contexto
}

# Substitui {{PLACEHOLDER}} no template com as respostas (via python p/ escape seguro).
_gerar_contexto() {
  local template="$BASE_DIR/nicho/business-context.template.md"
  [[ -f "$template" ]] || { erro "Template do contexto não encontrado: $template"; return 1; }
  local i ph
  local -a phs=()
  for (( i=0; i<PERG_N; i++ )); do
    ph="${PERG_PLACEHOLDER[i]}"
    [[ -n "$ph" ]] || continue
    phs+=( "$ph" )
    export "$ph"          # exporta a variável (com seu valor atual) p/ o python
  done
  # Placeholders vão como argv (o script vem pelo heredoc em stdin via 'python3 -').
  python3 - "$template" "$ESTADO_CONTEXTO" "${phs[@]}" <<'PY'
import os, sys
template, destino = sys.argv[1], sys.argv[2]
phs = sys.argv[3:]
texto = open(template, encoding="utf-8").read()
for c in phs:
    texto = texto.replace("{{%s}}" % c, os.environ.get(c, ""))
open(destino, "w", encoding="utf-8").write(texto)
PY
  chmod 600 "$ESTADO_CONTEXTO"
  ok "Criei as instruções de trabalho do seu agente."
}

_revisar_contexto() {
  titulo "Veja como ficou (resumo):"
  sed -n '1,18p' "$ESTADO_CONTEXTO"
  echo "  ..."
  if ! confirmar "Ficou bom?" s; then
    dica "Sem problema — vamos refazer as perguntas do negócio (Enter mantém o que você já tinha digitado)."
    passo_negocio
  fi
}
