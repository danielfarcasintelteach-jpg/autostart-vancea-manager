# AUTOSTART VANCEA Manager — Raport audit final Etapa 3.6

**Data auditului:** 25.10.2026
**Etapa:** 3.6 — audit final de integrare și securitate pentru blocul 3.x
**Commit de bază:** `1210f38` — `Validare separare date pe roluri Etapa 3.5C`

## 1. Scop

Etapa 3.6 închide tehnic blocul 3.x printr-un audit integrat al aplicației Next.js, autentificării Supabase, autorizării server-side, politicilor RLS, operațiilor SQL protejate, coloanelor sensibile, jurnalului de audit, dependențelor software și artefactelor versionate.

Auditul nu introduce funcționalități CRUD noi. Scopul său este verificarea faptului că mecanismele implementate în Etapele 3.1–3.5 funcționează împreună fără ocolirea controalelor de securitate.

## 2. Audit dependențe și build — 3.6A

În cadrul auditului, dependențele de securitate au fost actualizate la:

- Next.js `16.4.3`;
- React `19.2.9`;
- React DOM `19.2.9`;
- `eslint-config-next` `16.4.3`;
- `source-map-js` `1.2.2`.

Validările executate după actualizare:

- `npm audit --omit=dev` — `0 vulnerabilities`;
- `npx tsc --noEmit` — PASS;
- `npm run lint` — PASS;
- `npm run build` — PASS;
- toate rutele aplicației au fost generate cu succes;
- Proxy-ul Next.js/Supabase a fost inclus în build.

Verdict 3.6A: **APROBATĂ**.

## 3. Audit live Supabase — 3.6B

Auditul catalogului PostgreSQL/Supabase a fost executat în tranzacție `READ ONLY`.

Rezultatul final:

| Verificare | Rezultat |
| --- | ---: |
| Funcții helper în schema `intern` | 10 |
| Funcții private în schema `operatii` | 30 |
| Wrapper-e RPC în schema `public` | 30 |
| Politici RLS | 10 |

Rezultat SQL: `ETAPA_3_6B_AUDIT_LIVE_OK`.

Au fost confirmate următoarele:

- RLS activ pe cele 10 tabele relevante, inclusiv `jurnal_audit`;
- `anon` nu are acces direct la datele aplicației;
- `authenticated` nu are `INSERT`, `UPDATE`, `DELETE` sau `TRUNCATE` direct pe tabelele operaționale;
- funcțiile `intern.*` sunt `SECURITY DEFINER`, `STABLE`, cu `search_path` fix;
- funcțiile `operatii.*` sunt `SECURITY DEFINER`, cu `search_path` fix și verificare internă a identității/rolului;
- wrapper-ele `public.*` sunt `SECURITY INVOKER`;
- coloana `cursanti.cnp` nu este citibilă direct de `authenticated` sau `anon`;
- `plati.cheie_idempotenta` nu este expusă direct;
- indexul unic de idempotentă și trigger-ul de protecție sunt active;
- `jurnal_audit` nu este accesibil direct rolurilor API;
- trigger-ele de protecție append-only sunt active.

În timpul primului control, o încercare de citire directă din `public.jurnal_audit` a fost respinsă cu `permission denied`. Nu s-a acordat ulterior `SELECT`; comportamentul a fost consemnat ca dovadă pozitivă că jurnalul este izolat conform proiectării.

Verdict 3.6B: **APROBATĂ**.

## 4. Igienizarea artefactelor — 3.6C

Fixture-ul persistent din Etapa 3.5C a fost revizuit astfel încât să nu mai depindă de o adresă reală de administrator.

Selectorul administratorului a fost schimbat la contul demonstrativ:

`admin.demo@example.com`

Conturile folosite în artefactele de test sunt exclusiv conturi demonstrative `@example.com`.

Cerința N04 din dosarul tehnic a fost clarificată pentru a distinge valorile CNP fictive, necesare testării formatului și unicității, de CNP-urile reale, care nu trebuie publicate în cod, teste sau capturi.

Scanarea finală a repository-ului confirmă:

- fără e-mailuri personale reale în fișierele urmărite;
- fără `sb_secret_`;
- fără chei `service_role`;
- fără chei private;
- fără parole sau tokenuri introduse în artefactele versionate;
- singurul fișier `.env` urmărit este `cod/.env.example`;
- `.env.local` rămâne exclus din Git.

## 5. Integrarea autentificării și autorizării

Autentificarea este realizată prin Supabase Auth și client SSR.

Profilul aplicației este citit din `public.utilizatori`, iar rolul nu este acceptat din formular, URL sau stare client.

Rolurile aplicației sunt:

- `administrator`;
- `secretariat`;
- `instructor`;
- `cursant`.

Rutele `/cont/*` sunt protejate server-side. Accesarea unei rute aparținând altui rol redirecționează utilizatorul la panoul propriu.

Profilurile absente sau inactive nu primesc acces operațional.

Citirile din interfață folosesc sesiunea SSR a utilizatorului și sunt filtrate prin RLS. Nu este folosită cheia `service_role` pentru citirile aplicației.

## 6. Separarea datelor pe roluri

Validarea practică din Etapa 3.5C a confirmat:

- administrator — acces global conform rolului;
- secretariat — acces operațional fără administrarea conturilor;
- instructor — numai resursele relevante/repartizate;
- cursant — numai propriile date și resursele aferente;
- instructorul nu vede plățile;
- accesul la rute aparținând altui rol este refuzat/redirecționat.

Seturile demonstrative A/B au demonstrat că RLS exclude datele străine utilizatorului.

## 7. Modelul operațiilor protejate

Scrierile operaționale sunt proiectate pe modelul:

`client / Server Action -> wrapper public SECURITY INVOKER -> operatii.* SECURITY DEFINER -> tabele`

Funcțiile private revalidează identitatea și rolul prin `auth.uid()` și profilul activ.

Nu există DML direct acordat rolului `authenticated` pe tabelele operaționale.

Operațiile sensibile privind conturile, rolurile și CNP-ul folosesc funcții dedicate și auditabile.

## 8. CNP și date sensibile

CNP-ul nu este inclus în granturile obișnuite de citire.

Administratorul și secretariatul îl pot consulta/corecta numai prin operațiile dedicate.

Consultarea CNP este auditată, însă valoarea CNP nu este înscrisă în `jurnal_audit`.

Valorile de 13 cifre prezente în testele SQL sunt exclusiv valori fictive pentru validarea tehnică a formatului și unicității.

## 9. Jurnal și idempotentă

`public.jurnal_audit` este append-only:

- fără acces direct pentru `anon`/`authenticated`;
- UPDATE/DELETE/TRUNCATE sunt protejate prin trigger;
- operațiile controlate scriu auditul în aceeași tranzacție.

Plățile folosesc `cheie_idempotenta` cu index unic parțial și protecție împotriva modificării ulterioare.

## 10. Limite rămase

Etapa 3.6 validează blocul de infrastructură și securitate 3.x, nu întreaga aplicație finală.

Rămân pentru etapele funcționale următoare:

- interfețele CRUD complete;
- listele și formularele operaționale;
- rapoartele;
- testele de volum și responsive complete;
- auditul final al aplicației înainte de deployment;
- configurarea și verificarea mediului de producție.

## 11. Verdict

**ETAPA 3.6 — APROBATĂ.**

Blocul 3.x este considerat închis din punct de vedere al autentificării, profilurilor, rolurilor, RLS, operațiilor SQL controlate, protecției CNP, auditului, idempotentei, rutelor pe roluri și citirilor server-side.

Starea obținută constituie baza securizată pentru dezvoltarea modulelor funcționale următoare.
