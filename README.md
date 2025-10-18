# Postiz LinkedIn Page Fix - Docker Build

Acest repository conține patch-urile necesare pentru a repara integrarea LinkedIn Page în Postiz v1.60.1.

## Problema

Când încerci să adaugi o pagină de business LinkedIn în Postiz:
- Nu se asociază pagina de business, ci contul personal
- Imaginea paginii nu apare (eroare la upload)

## Soluția

Dockerfile-ul conține 3 patch-uri care rezolvă problema:
1. **Protecție upload imagine** - previne crash-uri la imagini invalide
2. **Corectare linkedin.page.provider** - returnează `pageId` corect
3. **Corectare integrations.controller** - acceptă `body.pageId` în loc de `body.page`

## Deployment pe Server Ubuntu

### 1. Clonează repository-ul pe server

```bash
cd ~
git clone https://github.com/obsid2025/postiz.dockerfile.git
cd postiz.dockerfile
```

### 2. Construiește imaginea Docker

```bash
docker build -t ghcr.io/obsid2025/postiz-custom:latest -f Dockerfile.postiz.fixed .
```

### 3. Verifică că patch-urile s-au aplicat

```bash
# Rulează scriptul de verificare
chmod +x verify-patches.sh
./verify-patches.sh ghcr.io/obsid2025/postiz-custom:latest
```

Ar trebui să vezi toate cele 3 patch-uri ca fiind **✅ APLICAT**.

### 4. Login la GitHub Container Registry

```bash
# Creează un Personal Access Token pe GitHub cu permisiuni write:packages
echo "YOUR_GITHUB_TOKEN" | docker login ghcr.io -u obsid2025 --password-stdin
```

### 5. Push imaginea

```bash
docker push ghcr.io/obsid2025/postiz-custom:latest
```

### 6. Configurare în Coolify

1. Accesează instanța Postiz în Coolify
2. Schimbă imaginea Docker de la:
   ```
   ghcr.io/gitroomhq/postiz-app:v1.60.1
   ```
   La:
   ```
   ghcr.io/obsid2025/postiz-custom:latest
   ```
3. Restart serviciul

### 7. Testare

1. Accesează: `https://postiz.obsid.ro/integrations/social/linkedin-page`
2. Autentifică-te cu LinkedIn
3. Selectează pagina de business
4. Verifică că se salvează corect

## Fișiere în Repository

- `Dockerfile.postiz.fixed` - Dockerfile cu toate patch-urile
- `verify-patches.sh` - Script de verificare automată
- `INSTRUCTIUNI_REPARARE.md` - Ghid detaliat de troubleshooting
- `PROBLEMA_LINKEDIN_ANALIZA.md` - Analiză tehnică completă a bug-ului

## Update la Versiuni Noi

Când Postiz lansează o versiune nouă (ex: v1.61.0):

1. Modifică prima linie din `Dockerfile.postiz.fixed`:
   ```dockerfile
   FROM ghcr.io/gitroomhq/postiz-app:v1.61.0
   ```

2. Re-build și re-push imaginea:
   ```bash
   docker build -t ghcr.io/obsid2025/postiz-custom:latest -f Dockerfile.postiz.fixed .
   docker push ghcr.io/obsid2025/postiz-custom:latest
   ```

3. Restart în Coolify

## Suport

Pentru probleme sau întrebări, vezi fișierul `INSTRUCTIUNI_REPARARE.md` pentru troubleshooting detaliat.

## Licență

Patch-urile sunt bazate pe Postiz (Apache License 2.0)
