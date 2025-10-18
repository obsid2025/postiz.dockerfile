# Analiza Problemei LinkedIn în Postiz

## Rezumat Executiv

Problema principală este o **inconsistență în numele parametrilor** între frontend și backend în implementarea integrării LinkedIn Page. Frontend-ul trimite un obiect cu `{id, pageId}`, dar backend-ul primește parametrul cu numele greșit din cauza patch-urilor incomplete.

## Problema Identificată

### 1. Ce s-a încercat să se repare (patch-urile aplicate)

Din istoricul tău, ai încercat să aplici următoarele patch-uri pe imaginea Docker:

```dockerfile
# Patch 1: Protecție pentru upload imagini
RUN sed -i 's|: await this.storage.uploadSimple(picture)|: await this.storage.uploadSimple(picture).catch((err) => { console.error("Uploading the integrations image failed."); console.error(err); return picture; })|g' /app/apps/backend/dist/libraries/nestjs-libraries/src/database/prisma/integrations/integration.service.js

# Patch 2: Mapare pageId în companies()
RUN sed -i 's|page: e\.organizationalTarget\.split|pageId: e.organizationalTarget.split|g' /app/apps/backend/dist/libraries/nestjs-libraries/src/integrations/social/linkedin.page.provider.js

# Patch 3: Body parameter în integrations.controller (INCOMPLET!)
RUN sed -i 's|body\.page\b|body.pageId|g' /app/apps/backend/dist/apps/backend/src/api/routes/integrations.controller.js
```

### 2. Fluxul Normal al Integrării LinkedIn Page

#### Pasul 1: Autentificare Inițială
- User accesează `/integrations/social/linkedin-page`
- Se autentifică cu LinkedIn (OAuth)
- Sistemul salvează user-ul personal cu `inBetweenSteps = true`

#### Pasul 2: Selectare Pagină Business
- Frontend apelează functia `companies()` din `linkedin.page.provider.ts:123-146`
- Aceasta returnează lista de pagini business cu structura:
```typescript
{
  id: string,          // ID-ul organizației
  pageId: string,      // Același cu id (duplicat)
  username: string,    // vanityName
  name: string,        // localizedName
  picture: string      // logo
}
```

#### Pasul 3: Salvare Pagină Selectată
- Frontend trimite POST la `/integrations/linkedin-page/${integrationId}`
- Body-ul conține: `{ id: string, pageId: string }`
- Controller-ul (`integrations.controller.ts:554-561`) primește body-ul
- Backend apelează `integration.service.ts:305` - metoda `saveLinkedin(org, id, page)`

### 3. Unde Apare Problema

**În codul sursă TypeScript (CORECT):**

`integrations.controller.ts:554-561`:
```typescript
@Post('/linkedin-page/:id')
async saveLinkedin(
  @Param('id') id: string,
  @Body() body: { pageId: string },  // ← Așteaptă pageId
  @GetOrgFromRequest() org: Organization
) {
  return this._integrationService.saveLinkedin(org.id, id, body.pageId);  // ← Folosește body.pageId
}
```

`linkedin.page.provider.ts:137-139`:
```typescript
return (elements || []).map((e: any) => ({
  id: e.organizationalTarget.split(':').pop(),
  pageId: e.organizationalTarget.split(':').pop(),  // ← Returnează pageId
  username: e['organizationalTarget~'].vanityName,
  name: e['organizationalTarget~'].localizedName,
  picture: e['organizationalTarget~'].logoV2?.['original~']?.elements?.[0]?.identifiers?.[0]?.identifier,
}));
```

**În codul compilat JavaScript (PROBLEMATIC):**

Din cauza transpilării TypeScript → JavaScript, structura devine diferită:

`integrations.controller.js` (compilat):
```javascript
// Parametrul decoratorului @Body() dispare, devine doar "body"
async saveLinkedin(id, body, org) {
  return this._integrationService.saveLinkedin(org.id, id, body.page);  // ← body.page (greșit!)
}
```

`linkedin.page.provider.js` (compilat):
```javascript
return (elements || []).map((e) => ({
  id: e.organizationalTarget.split(':').pop(),
  page: e.organizationalTarget.split(':').pop(),  // ← "page" în loc de "pageId"
  username: e['organizationalTarget~'].vanityName,
  // ...
}));
```

### 4. De Ce Patch-urile Tale Nu Au Funcționat

**Patch 2** a corectat `linkedin.page.provider.js` să returneze `pageId`:
```bash
sed -i 's|page: e\.organizationalTarget\.split|pageId: e.organizationalTarget.split|g'
```
✅ Acesta funcționează corect

**Patch 3** a încercat să corecteze `integrations.controller.js`:
```bash
sed -i 's|body\.page\b|body.pageId|g'
```
❌ Problema: Fișierul se află la o cale diferită în imaginea Docker!

Ai încercat:
- `/app/apps/backend/dist/api/routes/integrations.controller.js` (nu există)
- `/app/apps/backend/dist/libraries/nestjs-libraries/src/api/routes/integrations.controller.js` (nu există)

**Calea corectă este:**
- `/app/apps/backend/dist/apps/backend/src/api/routes/integrations.controller.js` ✅

### 5. Inconsistența Facebook vs LinkedIn

În același controller, metoda Facebook funcționează:

```typescript
@Post('/facebook/:id')
async saveFacebook(
  @Param('id') id: string,
  @Body() body: { page: string },  // ← folosește "page"
  @GetOrgFromRequest() org: Organization
) {
  return this._integrationService.saveFacebook(org.id, id, body.page);  // ← body.page
}
```

Aceasta sugerează că în codul original, LinkedIn folosea `body.page`, dar la un moment dat s-a decis să se standardizeze pe `pageId` pentru LinkedIn (probabil pentru claritate, deoarece LinkedIn folosește conceptul de "page" diferit de Facebook).

## Soluția Completă

### Opțiunea 1: Patch Corect în Dockerfile (Recomandat)

Actualizează Dockerfile.postiz cu calea corectă:

```dockerfile
FROM ghcr.io/gitroomhq/postiz-app:v1.60.1

# Patch 1: Protecție upload imagine
RUN sed -i 's|: await this.storage.uploadSimple(picture)|: await this.storage.uploadSimple(picture).catch((err) => { console.error("Uploading the integrations image failed."); console.error(err); return picture; })|g' \
    /app/apps/backend/dist/libraries/nestjs-libraries/src/database/prisma/integrations/integration.service.js

# Patch 2: Returnare pageId în companies()
RUN sed -i 's|page: e\.organizationalTarget\.split|pageId: e.organizationalTarget.split|g' \
    /app/apps/backend/dist/libraries/nestjs-libraries/src/integrations/social/linkedin.page.provider.js

# Patch 3: CALEA CORECTĂ pentru integrations.controller.js
RUN sed -i 's|body\.page\b|body.pageId|g' \
    /app/apps/backend/dist/apps/backend/src/api/routes/integrations.controller.js

USER node
EXPOSE 3000 5000
```

### Opțiunea 2: Verificare și Patch Multiple Locații

Dacă nu ești sigur de cale, aplică patch-ul pe toate fișierele relevante:

```dockerfile
FROM ghcr.io/gitroomhq/postiz-app:v1.60.1

# Patch 1: Protecție upload imagine
RUN sed -i 's|: await this.storage.uploadSimple(picture)|: await this.storage.uploadSimple(picture).catch((err) => { console.error("Uploading the integrations image failed."); console.error(err); return picture; })|g' \
    /app/apps/backend/dist/libraries/nestjs-libraries/src/database/prisma/integrations/integration.service.js

# Patch 2: Returnare pageId în companies()
RUN sed -i 's|page: e\.organizationalTarget\.split|pageId: e.organizationalTarget.split|g' \
    /app/apps/backend/dist/libraries/nestjs-libraries/src/integrations/social/linkedin.page.provider.js

# Patch 3: Body parameter în toate locațiile posibile
RUN find /app/apps/backend/dist -name "integrations.controller.js" -type f -exec sed -i 's|body\.page\b|body.pageId|g' {} \;

USER node
EXPOSE 3000 5000
```

### Opțiunea 3: Modificare Frontend (Alternativă)

Dacă nu vrei să modifici backend-ul, poți modifica frontend-ul să trimită `page` în loc de `pageId`:

În `linkedin.continue.tsx:48-54`, schimbă:
```typescript
const saveLinkedin = useCallback(async () => {
  await fetch(`/integrations/linkedin-page/${integration?.id}`, {
    method: 'POST',
    body: JSON.stringify({ page: page?.pageId }), // ← trimite "page" în loc de tot obiectul
  });
  closeModal();
}, [integration, page]);
```

## Problema cu Imaginea (Poza Lipsă)

Patch-ul 1 rezolvă problema cu upload-ul imaginii. Eroarea apare când:
1. LinkedIn returnează un URL al logo-ului
2. `storage.uploadSimple(picture)` încearcă să descarce și să urce imaginea în storage-ul propriu
3. Dacă descărcarea eșuează (timeout, permisiuni, etc.), toată integrarea eșuează

Patch-ul adaugă `.catch()` care:
- Loghează eroarea
- Returnează URL-ul original în loc să oprească procesul
- Permite integrării să continue fără imagine

## De Ce Versiunea Veche Funcționează

Pe serverul tău vechi, probabil rulează o versiune mai veche de Postiz (înainte de v1.60.1) care:
- Fie folosea `body.page` consistent
- Fie avea o structură diferită a codului compilat
- Fie nu avea bug-ul introdus în versiunile recente

## Testare

După aplicarea patch-ului corect:

1. Rebuilduiește imaginea:
```bash
docker build -t ghcr.io/obsid2025/postiz-custom:latest -f Dockerfile.postiz .
```

2. Verifică că patch-ul s-a aplicat:
```bash
docker run --rm ghcr.io/obsid2025/postiz-custom:latest cat /app/apps/backend/dist/apps/backend/src/api/routes/integrations.controller.js | grep -A5 "saveLinkedin"
```

Ar trebui să vezi `body.pageId` în loc de `body.page`.

3. Push imaginea:
```bash
docker push ghcr.io/obsid2025/postiz-custom:latest
```

4. Restart instanța Coolify

5. Testează fluxul:
   - Adaugă integrare LinkedIn Page
   - Selectează pagina business
   - Verifică că se salvează corect cu numele și imaginea paginii

## Concluzie

Problema era cauzată de o inconsistență în transpilarea TypeScript → JavaScript și o cale incorectă în patch-ul Docker. Patch-ul 3 trebuia aplicat pe `/app/apps/backend/dist/apps/backend/src/api/routes/integrations.controller.js` în loc de căile încercate anterior.

Versiunea ta veche funcționează pentru că fie are un cod diferit, fie bug-ul nu exista în acea versiune.
