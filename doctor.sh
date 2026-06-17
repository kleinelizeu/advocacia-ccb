#!/usr/bin/env bash
# doctor.sh — Diagnóstico standalone (gerado a partir do installer-kit-ccb).
# Atalho para: instalar.sh doctor
set -euo pipefail
BASE_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=/dev/null
source "$BASE_DIR/produto.conf"
for f in "$BASE_DIR"/lib/*.sh; do source "$f"; done
init_estado
carregar_estado
mostrar_banner
rodar_doctor
