#!/bin/bash

# Script pentru verificarea patch-urilor aplicate în imaginea Docker Postiz

IMAGE_NAME="${1:-ghcr.io/obsid2025/postiz-custom:latest}"

echo "========================================"
echo "Verificare Patch-uri Postiz"
echo "Imagine: $IMAGE_NAME"
echo "========================================"
echo ""

# Funcție pentru verificare
check_patch() {
    local patch_name="$1"
    local file_path="$2"
    local search_pattern="$3"
    local expected="$4"

    echo "[$patch_name]"
    echo "Fișier: $file_path"

    # Verifică dacă fișierul există
    if ! docker run --rm "$IMAGE_NAME" test -f "$file_path" 2>/dev/null; then
        echo "❌ EROARE: Fișierul nu există!"
        return 1
    fi

    # Caută pattern-ul
    result=$(docker run --rm "$IMAGE_NAME" grep -o "$search_pattern" "$file_path" 2>/dev/null | head -1)

    if [[ "$result" == *"$expected"* ]]; then
        echo "✅ SUCCES: Patch aplicat corect"
        echo "   Găsit: $result"
    else
        echo "❌ EROARE: Patch NU este aplicat corect"
        echo "   Așteptat: $expected"
        echo "   Găsit: $result"
    fi
    echo ""
}

# Patch 1: Protecție upload imagine
check_patch \
    "Patch 1: Protecție Upload Imagine" \
    "/app/apps/backend/dist/libraries/nestjs-libraries/src/database/prisma/integrations/integration.service.js" \
    "uploadSimple(picture).catch" \
    ".catch"

# Patch 2: LinkedIn pageId mapping
check_patch \
    "Patch 2: LinkedIn pageId Mapping" \
    "/app/apps/backend/dist/libraries/nestjs-libraries/src/integrations/social/linkedin.page.provider.js" \
    "pageId: e.organizationalTarget.split" \
    "pageId:"

# Patch 3: Body parameter în controller
check_patch \
    "Patch 3: Body Parameter Controller" \
    "/app/apps/backend/dist/apps/backend/src/api/routes/integrations.controller.js" \
    "body.pageId" \
    "body.pageId"

echo "========================================"
echo "Verificare completă!"
echo "========================================"

# Afișează un fragment din fișierul controller pentru inspecție manuală
echo ""
echo "Fragment din integrations.controller.js (metoda saveLinkedin):"
echo "---------------------------------------------------------------"
docker run --rm "$IMAGE_NAME" sh -c "grep -A10 'saveLinkedin' /app/apps/backend/dist/apps/backend/src/api/routes/integrations.controller.js | head -15"
