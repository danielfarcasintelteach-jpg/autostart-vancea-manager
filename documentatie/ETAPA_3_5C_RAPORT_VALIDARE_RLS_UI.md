# AUTOSTART VANCEA Manager — Raport validare Etapa 3.5C

**Data validării:** 25.10.2026
**Etapa:** 3.5C — separarea practică a datelor pe roluri și validarea interfeței prin RLS
**Mediu:** dezvoltare locală Next.js + proiect Supabase de dezvoltare
**Commit de bază:** `e4e97ab57f4be3d4b1f9201489208f3f19c974a5`

## 1. Scop

Etapa 3.5C verifică practic faptul că interfața pe roluri implementată în 3.5A și citirile server-side prin RLS implementate în 3.5B respectă matricea de acces definită pentru rolurile `administrator`, `secretariat`, `instructor` și `cursant`.

Testarea nu se bazează numai pe existența rutelor. Au fost create două linii distincte de date demonstrative, A și B, pentru a demonstra că politicile RLS filtrează efectiv datele nerelevante.

## 2. Fixture persistent

Fixture-ul reproductibil este păstrat în:

`baza_date/teste/ETAPA_3_5C_FIXTURE_PERSISTENT.sql`

Au fost folosite trei conturi Auth demo preexistente, fără profil public înaintea testului:

- `secretariat.demo@example.com`
- `instructor.a.demo@example.com`
- `cursant.a.demo@example.com`

Fixture-ul a creat și legat profilurile publice corespunzătoare, plus două seturi distincte A/B de:

- 2 cursanți;
- 2 instructori;
- 2 vehicule;
- 2 înscrieri;
- 2 programări;
- 2 plăți;
- 2 examene.

Rezultatul SQL de control a fost:

| Resursă fixture | Număr |
| --- | ---: |
| Cursanți | 2 |
| Instructori | 2 |
| Vehicule | 2 |
| Înscrieri | 2 |
| Programări | 2 |
| Plăți | 2 |
| Examene | 2 |

## 3. Autentificare demo

Parolele celor trei conturi demo au fost setate local prin Supabase Admin API, fără salvarea cheii secrete sau a parolelor în repository.

Autentificarea `signInWithPassword` a fost verificată cu succes pentru toate cele trei conturi:

- `secretariat.demo@example.com` — OK;
- `instructor.a.demo@example.com` — OK;
- `cursant.a.demo@example.com` — OK.

Cheia secretă și parola nu au fost introduse în cod, documentație sau Git.

## 4. Validare Secretariat

Autentificarea a redirecționat corect la:

`/cont/secretariat`

Interfața nu afișează zona „Conturi și roluri”.

Citirile server-side filtrate prin RLS au afișat:

| Resursă | Valoare observată |
| --- | ---: |
| Persoane | 7 |
| Cursanți | 2 |
| Instructori | 2 |
| Vehicule | 2 |
| Înscrieri | 2 |
| Programări | 2 |
| Plăți | 2 |
| Examene | 2 |

Rezultat: **APROBAT**.

## 5. Validare Instructor A

Autentificarea a redirecționat corect la:

`/cont/instructor`

Citirile server-side filtrate prin RLS au afișat:

| Resursă | Valoare observată |
| --- | ---: |
| Profil instructor | 1 |
| Cursanți relevanți | 1 |
| Vehicule relevante | 1 |
| Înscrieri repartizate | 1 |
| Programările mele | 1 |
| Examene relevante | 1 |

Interfața nu afișează nicio resursă financiară și nu există card pentru „Plăți”.

Accesarea manuală a `/cont/administrator` a redirecționat utilizatorul înapoi la `/cont/instructor`.

Rezultat: **APROBAT**.

## 6. Validare Cursant A

Autentificarea a redirecționat corect la:

`/cont/cursant`

Citirile server-side filtrate prin RLS au afișat:

| Resursă | Valoare observată |
| --- | ---: |
| Profil cursant | 1 |
| Înscrierile mele | 1 |
| Programările mele | 1 |
| Plățile mele | 1 |
| Examenele mele | 1 |
| Vehicule din programările mele | 1 |

Accesarea manuală a `/cont/administrator` a redirecționat utilizatorul înapoi la `/cont/cursant`.

Rezultat: **APROBAT**.

## 7. Verificări tehnice aferente 3.5B/3.5C

Înaintea testelor UI au trecut fără erori:

- `npx tsc --noEmit`;
- `npm run lint`;
- `npm run build`;
- `git diff --check`.

Build-ul Next.js a generat rutele:

- `/`;
- `/autentificare`;
- `/acces-neactivat`;
- `/cont`;
- `/cont/administrator`;
- `/cont/secretariat`;
- `/cont/instructor`;
- `/cont/cursant`.

## 8. Concluzie

Etapa 3.5C demonstrează practic că:

1. rolul este determinat pe server din profilul utilizatorului autentificat;
2. rutele nepermise sunt respinse prin redirecționare către panoul rolului curent;
3. citirile sunt executate server-side cu sesiunea utilizatorului curent;
4. politicile RLS filtrează datele la nivel de bază de date;
5. Instructor A și Cursant A văd numai setul relevant lor, deși în baza de date există și setul B;
6. instructorul nu primește acces la plăți;
7. secretariatul nu primește administrarea conturilor și rolurilor;
8. nici cheia secretă Supabase, nici parolele demo nu sunt păstrate în repository.

**Verdict Etapa 3.5C: APROBATĂ.**
