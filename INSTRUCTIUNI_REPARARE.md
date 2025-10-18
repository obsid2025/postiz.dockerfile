# Instrucțiuni de Reparare LinkedIn în Postiz

## Problema
Când încerci să adaugi o pagină de business LinkedIn în Postiz:
- Imaginea paginii nu apare (eroare la upload)
- Pagina nu se salvează corect sau apare cu numele greșit

## Cauza
Patch-urile anterioare au fost aplicate pe căi incorecte în imaginea Docker.

## Soluție - Pași de Urmat

### 1. Pe Serverul Ubuntu (unde construiești imaginea Docker)

#### Pasul 1.1: Creează Dockerfile-ul Corect

Creează un fișier numit `Dockerfile.postiz` cu următorul conținut:

```dockerfile
FROM ghcr.io/gitroomhq/postiz-app:v1.60.1

# Patch 1: Protecție pentru erori la upload-ul imaginilor de integrare
RUN sed -i 's|: await this.storage.uploadSimple(picture)|: await this.storage.uploadSimple(picture).catch((err) => { console.error("Uploading the integrations image failed."); console.error(err); return picture; })|g' \
    /app/apps/backend/dist/libraries/nestjs-libraries/src/database/prisma/integrations/integration.service.js

# Patch 2: Corectare mapare în linkedin.page.provider
RUN sed -i 's|page: e\.organizationalTarget\.split|pageId: e.organizationalTarget.split|g' \
    /app/apps/backend/dist/libraries/nestjs-libraries/src/integrations/social/linkedin.page.provider.js

# Patch 3: Corectare parametru body în integrations.controller (CALEA CORECTĂ!)
RUN sed -i 's|body\.page\b|body.pageId|g' \
    /app/apps/backend/dist/apps/backend/src/api/routes/integrations.controller.js

USER node
EXPOSE 3000 5000
```

#### Pasul 1.2: Construiește Imaginea

```bash
docker build -t ghcr.io/obsid2025/postiz-custom:latest -f Dockerfile.postiz .
```

#### Pasul 1.3: Verifică Patch-urile (IMPORTANT!)

Înainte de a face push, verifică că patch-urile s-au aplicat corect:

```bash
# Verifică că fișierul există și patch-ul s-a aplicat
docker run --rm ghcr.io/obsid2025/postiz-custom:latest sh -c "grep -o 'body\.pageId' /app/apps/backend/dist/apps/backend/src/api/routes/integrations.controller.js | head -1"
```

Ar trebui să vezi output: `body.pageId`

Dacă vezi `body.page` sau nimic, patch-ul NU s-a aplicat!

#### Pasul 1.4: Verificare Completă (Opțional)

```bash
# Verifică Patch 1 - Upload imagine
docker run --rm ghcr.io/obsid2025/postiz-custom:latest sh -c "grep -o 'uploadSimple(picture).catch' /app/apps/backend/dist/libraries/nestjs-libraries/src/database/prisma/integrations/integration.service.js | head -1"
# Ar trebui să vezi: uploadSimple(picture).catch

# Verifică Patch 2 - LinkedIn pageId
docker run --rm ghcr.io/obsid2025/postiz-custom:latest sh -c "grep -o 'pageId: e.organizationalTarget.split' /app/apps/backend/dist/libraries/nestjs-libraries/src/integrations/social/linkedin.page.provider.js | head -1"
# Ar trebui să vezi: pageId: e.organizationalTarget.split

# Verifică Patch 3 - Body parameter
docker run --rm ghcr.io/obsid2025/postiz-custom:latest sh -c "grep -C2 'saveLinkedin' /app/apps/backend/dist/apps/backend/src/api/routes/integrations.controller.js | grep pageId"
# Ar trebui să vezi linie cu body.pageId
```

#### Pasul 1.5: Push Imaginea

```bash
docker push ghcr.io/obsid2025/postiz-custom:latest
```

### 2. În Coolify

#### Pasul 2.1: Restart Serviciul

În Coolify, accesează instanța Postiz și dai restart la serviciu pentru a trage imaginea nouă.

**SAU**

Dacă ai setat un tag specific (nu `latest`), actualizează tag-ul în configurarea Coolify:
```
ghcr.io/obsid2025/postiz-custom:latest
```

#### Pasul 2.2: Verifică Log-urile

După restart, verifică că serviciul pornește corect:
- Nu ar trebui să vezi erori în log-uri
- Verifică că serviciile backend și frontend sunt running

### 3. Testare Funcționalitate

#### Test 1: Adăugare LinkedIn Personal
1. Accesează: `https://postiz.obsid.ro/integrations/social/linkedin`
2. Autentifică-te cu LinkedIn
3. Ar trebui să apară contul tău personal direct conectat

#### Test 2: Adăugare LinkedIn Page (Business)
1. Accesează: `https://postiz.obsid.ro/integrations/social/linkedin-page`
2. Autentifică-te cu LinkedIn
3. Ar trebui să apară un dialog cu lista de pagini business
4. Selectează o pagină
5. Dă click pe "Save"
6. Verifică:
   - ✅ Pagina apare în listă cu numele corect
   - ✅ Logo-ul paginii apare (dacă LinkedIn returnează unul valid)
   - ✅ Nu apare semnul exclamării (warning)
   - ✅ Poți posta pe pagina respectivă

## Troubleshooting

### Problema: Patch-ul nu se aplică (vezi body.page în loc de body.pageId)

**Cauză:** Calea către fișier este incorectă pentru versiunea ta de Postiz

**Soluție:** Găsește calea corectă:

```bash
# Găsește toate fișierele integrations.controller.js
docker run --rm ghcr.io/gitroomhq/postiz-app:v1.60.1 find /app -name "integrations.controller.js" -type f

# Verifică conținutul fiecărui fișier găsit
docker run --rm ghcr.io/gitroomhq/postiz-app:v1.60.1 cat /cale/gasita/integrations.controller.js | grep -A5 saveLinkedin
```

Caută fișierul care conține metoda `saveLinkedin` și folosește calea respectivă în Dockerfile.

### Problema: Imaginea paginii nu apare

**Cauză 1:** Patch 1 nu s-a aplicat
**Soluție:** Verifică că vezi `.catch((err)` în `integration.service.js`

**Cauză 2:** LinkedIn nu returnează un URL valid pentru logo
**Soluție:** Acesta este un comportament normal pentru unele pagini. Patch-ul previne crash-ul, dar poza va rămâne implicită.

### Problema: După selectarea paginii, apare contul personal cu exclamație

**Cauză:** Patch 3 nu s-a aplicat - backend-ul nu primește `pageId` corect
**Soluție:** Re-verifică că patch-ul s-a aplicat pe calea corectă

### Problema: Versiunea veche funcționează, cea nouă nu

**Explicație:** Versiunea veche are probabil un cod diferit sau o structură diferită a directoarelor. Patch-urile sunt specifice pentru v1.60.1.

**Soluții:**
1. Rămâi pe versiunea veche (dacă funcționează)
2. Adaptează patch-urile pentru versiunea nouă (vezi secțiunea de mai sus)
3. Așteaptă un fix oficial de la dezvoltatorii Postiz

## Verificare Finală - Checklist

După aplicarea tuturor patch-urilor:

- [ ] Imaginea Docker s-a construit fără erori
- [ ] Toate cele 3 patch-uri sunt verificate și aplicate corect
- [ ] Imaginea a fost push-uită pe ghcr.io
- [ ] Serviciul Coolify a fost restartat
- [ ] LinkedIn personal se conectează corect
- [ ] LinkedIn page afișează lista de pagini business
- [ ] Salvarea unei pagini business funcționează
- [ ] Pagina salvată apare cu numele corect în listă
- [ ] Poți crea și posta conținut pe pagina business

## Script Automat de Verificare

Am creat și un script `verify-patches.sh` care automatizează verificarea:

```bash
chmod +x verify-patches.sh
./verify-patches.sh ghcr.io/obsid2025/postiz-custom:latest
```

## Note Importante

1. **Backup:** Înainte de a face orice modificare, asigură-te că ai backup la datele din Postiz
2. **Test:** Testează pe un environment de development înainte de production
3. **Versiuni:** Aceste patch-uri sunt specifice pentru v1.60.1. Pentru alte versiuni, ar putea fi necesare ajustări
4. **Update Viitor:** La următorul update al Postiz, va trebui să re-aplici patch-urile sau să verifici dacă bug-ul a fost rezolvat oficial

## Întrebări Frecvente

**Î: Pot folosi direct `/integrations/social/linkedin` în loc de `/integrations/social/linkedin-page`?**
R: Da, dar vei conecta profilul personal, nu pagina business. Pentru pagini business, trebuie să folosești `linkedin-page`.

**Î: De ce pe serverul vechi funcționează fără patch-uri?**
R: Probabil rulează o versiune mai veche de Postiz care nu avea acest bug sau avea o structură diferită a codului.

**Î: Pot reveni la versiunea veche?**
R: Da, specifică tag-ul versiunii vechi în Coolify: `ghcr.io/gitroomhq/postiz-app:versiune-veche`

**Î: Patch-urile afectează alte funcționalități?**
R: Nu, patch-urile sunt foarte specifice pentru integrarea LinkedIn și protecția la upload imagini. Restul funcționalităților rămân neschimbate.
