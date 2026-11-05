#!/usr/bin/env bash
# Grava a nova imagem no deployment.yaml do serviço, em fase3/gitops, e envia o commit para a branch.
# Uso: update-gitops-tag.sh <serviço> <imagem completa com tag>
set -euo pipefail

# O script descarta alterações locais com git reset --hard, por isso só roda no GitHub Actions.
if [[ "${GITHUB_ACTIONS:-}" != "true" ]]; then
  echo "Este script só roda no GitHub Actions." >&2
  exit 1
fi

service="$1"
image="$2"
file="fase3/gitops/${service}/deployment.yaml"
branch="${GITOPS_BRANCH:-main}"

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

for attempt in 1 2 3 4 5; do
  git fetch origin "$branch"
  git reset --hard "origin/$branch"

  sed -i -E "s|^([[:space:]]*image:[[:space:]]*).*/togglemaster/${service}:.*$|\1${image}|" "$file"
  if ! grep -qF "image: ${image}" "$file"; then
    echo "Não encontrei a linha de imagem de ${service} em ${file}." >&2
    exit 1
  fi

  if git diff --quiet -- "$file"; then
    echo "A imagem já está em ${image}."
    exit 0
  fi

  git add "$file"
  git commit -m "ci(gitops): ${service} -> ${image##*:}"
  if git push origin "HEAD:${branch}"; then
    echo "Tag de ${service} atualizada para ${image##*:}."
    exit 0
  fi

  echo "Outro serviço enviou um commit antes. Nova tentativa (${attempt}/5)."
  sleep $((attempt * 3))
done

echo "Não foi possível enviar a nova tag depois de 5 tentativas." >&2
exit 1
