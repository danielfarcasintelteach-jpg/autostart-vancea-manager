# AUTOSTART VANCEA Manager — Raport Etapa 4

**Data:** 25.10.2026
**Etapa:** 4 — consolidarea conturilor și datelor demonstrative
**Commit de bază:** `8c577e6` — `Audit final integrare si securitate Etapa 3.6`

## 1. Scop

Etapa 4 stabilește setul demonstrativ stabil pe care se vor construi și testa modulele funcționale ale aplicației.

Nu au fost acordate drepturi suplimentare rolului `authenticated`, nu au fost introduse date personale reale și nu a fost modificat modelul de securitate validat în Etapa 3.6.

## 2. Conturile demonstrative oficiale

Setul oficial al aplicației conține patru conturi:

| Cont | Rol | Profil | Stare |
| --- | --- | --- | --- |
| `admin.demo@example.com` | administrator | da | activ |
| `secretariat.demo@example.com` | secretariat | da | activ |
| `instructor.a.demo@example.com` | instructor | da | activ |
| `cursant.a.demo@example.com` | cursant | da | activ |

Toate cele patru conturi sunt confirmate în Supabase Auth.

Contul instructor este legat de o entitate `instructori`, iar contul cursant este legat de o entitate `cursanti`.

## 3. Identități tehnice de test

Patru conturi Auth fictive sunt păstrate intenționat fără profil `public.utilizatori`:

| Cont | Scop |
| --- | --- |
| `instructor.b.demo@example.com` | scenarii comparative și negative pentru instructor |
| `cursant.b.demo@example.com` | scenarii comparative A/B pentru cursant și RLS |
| `inactiv.demo@example.com` | teste privind accesul neactivat/inactiv |
| `fara.profil.demo@example.com` | teste pentru cont Auth fără profil al aplicației |

Aceste conturi nu fac parte din setul oficial de utilizatori ai aplicației.

Confirmarea adresei de e-mail nu este o cerință pentru identitățile folosite exclusiv în testele SQL care verifică existența lor în `auth.users`. În starea validată, `instructor.b.demo@example.com` este neconfirmat și rămâne fără profil.

## 4. Setul persistent de date

Fixture-ul `ETAPA_3_5C_FIXTURE_PERSISTENT.sql` rămâne baza setului persistent de dezvoltare.

Auditul Etapei 4 confirmă:

| Resursă | Număr |
| --- | ---: |
| Conturi Auth fictive | 8 |
| Profiluri demo oficiale | 4 |
| Instructori Demo35C | 2 |
| Cursanți Demo35C | 2 |
| Vehicule demo | 2 |
| Înscrieri demo | 2 |
| Programări demo | 2 |
| Plăți demo | 2 |
| Examene demo | 2 |

Valorile CNP utilizate în fixture sunt exclusiv fictive.

## 5. Separarea conturilor

Conturile sunt împărțite explicit în două categorii:

1. **conturi oficiale demo** — utilizate pentru autentificarea în interfață și testarea celor patru roluri;
2. **identități tehnice de test** — utilizate numai de scenariile SQL și testele negative/comparative.

Această separare previne folosirea accidentală a unui cont tehnic ca utilizator real al aplicației.

## 6. Securitate

În timpul inventarului inițial, accesul direct la `auth.users` din rolul `authenticated` a fost respins cu `permission denied`.

Nu s-a acordat `SELECT ON auth.users TO authenticated`.

Inventarul administrativ a fost executat temporar cu `SET LOCAL ROLE postgres` într-o tranzacție `READ ONLY`, fără modificarea granturilor aplicației.

Modelul de securitate validat în Etapa 3.6 rămâne neschimbat.

## 7. Audit reproductibil

Fișierul:

`baza_date/teste/ETAPA_4_AUDIT_CONTURI_DATE_DEMO.sql`

verifică:

- existența exactă a celor opt conturi Auth fictive;
- confirmarea celor patru conturi oficiale;
- rolurile și starea activă a celor patru profiluri;
- legătura instructorului și cursantului cu entitățile lor;
- absența profilului pentru cele patru identități tehnice;
- existența setului persistent Demo35C.

Rezultatul validat este:

`ETAPA_4_AUDIT_OK | 8 | 4 | 2 | 2 | 2`

## 8. Verdict

**ETAPA 4 — APROBATĂ.**

Conturile și datele demonstrative sunt consolidate și pot constitui baza stabilă pentru modulele funcționale următoare.

Următoarea etapă este **Etapa 5 — Cursanți**.
