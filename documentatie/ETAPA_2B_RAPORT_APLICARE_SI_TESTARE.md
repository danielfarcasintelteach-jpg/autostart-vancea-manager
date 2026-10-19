# AUTOSTART VANCEA Manager — Etapa 2B: raport de aplicare și testare

**Sursă:** `DOSAR_TEHNIC_AUTOSTART_VANCEA_Manager.md`, versiunea 1.2.
**Stare:** migrarea inițială a fost aplicată și testată în baza Supabase de dezvoltare. Rezultatele de mai jos sunt cele verificate și comunicate de beneficiar; actualizarea acestui repository nu a executat SQL în Supabase.

## Livrabile și ordine

1. `001_schema_initiala.sql`: migrarea aplicată, cu extensie, nouă tabele, constrângeri, indexuri, funcții, trigger-e, RLS și revocări. Nu este idempotentă: se aplică o singură dată pe o schemă fără aceste tabele.
2. `ETAPA_2B_TESTE_SQL.sql`: verificare de catalog și zece teste de integritate trecute; tranzacția s-a încheiat cu `ROLLBACK`, fără păstrarea datelor sale temporare. Profilul demonstrativ `admin.demo@example.com` rămâne pentru Etapa 3.
3. `001_schema_initiala_ROLLBACK_NEEXECUTAT.sql`: script **distructiv**, neexecutat și păstrat explicit cu acest statut.

### Inventar exact al tabelelor

Toate au `data_crearii timestamptz NOT NULL DEFAULT now()` și `data_modificarii timestamptz NOT NULL DEFAULT now()`, menținute de trigger. PK înseamnă și `NOT NULL`/`UNIQUE`; celelalte câmpuri nemarcate `NULL` în script sunt explicit `NOT NULL`.

| Tabelă | Coloane și tipuri specifice | Protecții esențiale |
| --- | --- | --- |
| `persoane` | `id_persoana uuid` PK; `nume`, `prenume varchar(100)` NN; `telefon varchar(30)`, `email varchar(254)`, `data_nasterii date`, `adresa text` NULL | Nume și prenume nevide. |
| `utilizatori` | `id_utilizator uuid` PK și FK `auth.users(id)`; `id_persoana uuid` NN; `rol varchar(20)` NN; `activ boolean` NN implicit `true` | `id_persoana UNIQUE`; patru roluri; nicio parolă. |
| `cursanti` | `id_cursant uuid` PK; `id_persoana uuid` NN; `cnp varchar(13)` NN; `stare varchar(10)` NN implicit `activ`; `observatii text` NULL | `id_persoana` și `cnp` UNIQUE; exact 13 cifre; stări activ/inactiv. |
| `instructori` | `id_instructor uuid` PK; `id_persoana uuid` NN; `data_angajarii date` NULL; `stare varchar(10)` NN implicit `activ`; `observatii text` NULL | `id_persoana UNIQUE`; stări activ/inactiv. |
| `vehicule` | `id_vehicul uuid` PK; `numar_inmatriculare varchar(20)`, `marca`, `model varchar(100)` NN; `an_fabricatie smallint` NULL; `stare varchar(15)` NN implicit `activ`; `observatii text` NULL | Număr UNIQUE, canonic `[A-Z0-9]+`; marcă/model nevide; an >=1900; activ/service/indisponibil/inactiv. |
| `inscrieri` | `id_inscriere uuid` PK; `id_cursant`, `id_instructor uuid` NN; `categorie char(1)` NN implicit B; `data_inscrierii date` NN implicit `((now() AT TIME ZONE 'Europe/Bucharest')::date)`; `tarif_curs numeric(12,2)` NN; `stare varchar(12)` NN implicit activa; `data_finalizarii date`, `observatii text` NULL | B, tarif >0, stări activa/finalizata/anulata, dată finalizare exact pentru finalizata; unic parțial pe cursant activ. |
| `programari` | `id_programare uuid` PK; `id_inscriere`, `id_instructor`, `id_vehicul`, `id_utilizator_creare uuid` NN; `inceput`, `sfarsit timestamptz` NN; `stare varchar(12)` NN implicit programata; `observatii text` NULL | Fără `id_cursant`; durată exact 90 minute; două excluderi GiST și trigger pentru cursant; anulat nu ocupă. |
| `plati` | `id_plata uuid` PK; `id_inscriere`, `id_utilizator_inregistrare uuid` NN; `id_plata_initiala uuid` NULL; `tip varchar(12)`, `suma numeric(12,2)`, `stare varchar(15)`, `data_platii timestamptz` NN; `metoda_plata varchar(20)`, `referinta text` NULL | Sumă pozitivă; legătura rambursării cu plata inițială; sold și plafoane verificate de trigger. |
| `examene` | `id_examen uuid` PK; `id_inscriere uuid`, `tip_examen varchar(10)`, `numar_incercare smallint`, `data_examenului timestamptz`, `stare varchar(15)` NN; `rezultat varchar(10)`, `punctaj smallint`, `observatii text` NULL | `UNIQUE(id_inscriere,tip_examen,numar_incercare)`; rezultat obligatoriu exact la sustinut; punctaj doar la teorie. |

Toate **14 FK** au `ON DELETE RESTRICT ON UPDATE RESTRICT`, inclusiv cea spre `auth.users` și autoreferința rambursărilor. Fără `CASCADE`/`SET NULL`: istoria nu devine ambiguă; trecerea în stări inactive/anulate este operația obișnuită. În plus, `DELETE` nu este acordat niciunui rol al aplicației. Administratorul bazei rămâne capabil să șteargă rânduri terminale fără copii; excepțiile legale/administrative cer procedură separată.

### Indexuri și mecanisme

- PK și `UNIQUE`: indexuri B-tree generate automat. `uq_inscrieri_cursant_activ` este index B-tree unic parțial `WHERE stare='activa'`.
- `btree_gist`: operatorul de egalitate GiST pentru UUID. `ex_programari_instructor` și `ex_programari_vehicul` includ `tstzrange(inceput,sfarsit,'[)') WITH &&`, filtrate la `programata`, `finalizata`, `absent`; aceste două constrângeri își creează indexurile GiST.
- Indexuri B-tree suplimentare: `idx_persoane_nume_prenume`, `idx_inscrieri_cursant`, `idx_inscrieri_instructor`, `idx_programari_inscriere_inceput`, `idx_programari_instructor_inceput`, `idx_programari_vehicul_inceput`, `idx_programari_creator`, `idx_plati_inscriere_data`, `idx_plati_inregistrare`, `idx_plati_initiala`, `idx_examene_inscriere_data`.
- Triggerul de programare calculează `sfarsit` la inserare și respinge modificarea duratei/identității la actualizare. Pentru cursant, blochează rândul său (`FOR UPDATE`) și caută intervale ocupante prin **toate** înscrierile sale. La nivelul `READ COMMITTED`, două tranzacții pentru același cursant sunt serializate; coliziunea concurentă a fost verificată cu două sesiuni reale. Capetele comune nu se suprapun.
- Trigger-ele de stare împiedică dezactivarea vehiculului/instructorului, închiderea înscrierii sau repartizarea nouă cât există programări viitoare nerezolvate. Alte trigger-e țin tariful fix în prezența plăților, protejează soldul și numără încercările de examen sub blocarea înscrierii.
- Totalul achitat, restul și orele efectuate se **interoghează**, nu există coloane derivate: `SUM(plata confirmata - rambursare confirmata)`; `tarif_curs - SUM(...)`; `COUNT(sedinte finalizate) * 90` minute, împărțit la 60 pentru ore cronologice.

### RLS și CNP

Migrația a activat RLS la toate cele nouă tabele și a revocat privilegiile pe tabele de la `PUBLIC`, `anon` și `authenticated`, plus `EXECUTE` pe cele opt funcții interne. Există intenționat **zero politici RLS operaționale**. Verificarea efectivă a arătat că `anon` și `authenticated` au `SELECT/INSERT/UPDATE/DELETE = false` pe fiecare dintre cele nouă tabele și nu pot citi `cursanti.cnp`. Accesul normal din Next.js așteaptă politicile și granturile operaționale din Etapa 3. `service_role`/proprietarul pot administra baza; nu se folosesc ca substitut pentru politici în aplicație.

În etapa de acces, citirea `cursanti` se acordă doar pe coloanele nesensibile necesare, **fără** `SELECT` pe tabelă, deoarece acesta ar include `cnp`. Citirea/corectarea CNP și schimbarea rolului necesită operații înguste care verifică identitatea și rolul pe server și în SQL; `anon` nu primește astfel de funcții. Nu se introduc date reale în demo.

### Ordinea și revenirea

**Creare:** `BEGIN` → schema `extensions`/`btree_gist` → `persoane`, `utilizatori`, `cursanti`, `instructori`, `vehicule` → `inscrieri`/unicitate activă → `programari`/GiST → `plati` → `examene` → indexuri → opt funcții → 16 trigger-e → nouă RLS → revocări → `COMMIT`.

**Rollback neexecutat și distructiv:** scriptul ar elimina `examene` → `plati` → `programari` → `inscrieri` → `vehicule` → `instructori` → `cursanti` → `utilizatori` → `persoane` → cele opt funcții, invers. `DROP TABLE` ar elimina indexurile, FK și trigger-ele aferente. Scriptul nu folosește `CASCADE`, nu atinge `auth.users`, iar `btree_gist`/`extensions` ar rămâne. Nu a fost rulat în Etapa 2B.

## Rezultatele aplicării și testării în Supabase de dezvoltare

| Verificare | Rezultat consemnat |
| --- | --- |
| Migrarea inițială | Aplicată cu succes. |
| Obiecte și integritate | Exact 9 tabele; `btree_gist` versiunea 1.7; 8 funcții; 16 trigger-e; 2 constrângeri `EXCLUDE`; 14/14 FK cu `ON UPDATE RESTRICT / ON DELETE RESTRICT`. |
| Protecție inițială | RLS activ pe toate cele 9 tabele; 0 politici RLS operaționale, intenționat. Pentru `anon` și `authenticated`, `SELECT/INSERT/UPDATE/DELETE = false` pe fiecare tabelă și lipsă acces la `cursanti.cnp`. |
| Testele din script | 10/10 teste SQL funcționale trecute; `ROLLBACK` a eliminat datele temporare ale tranzacției de test. |
| Concurență instructor | Suprapunerea a fost respinsă cu `23P01`, `ex_programari_instructor`. |
| Concurență vehicul | Suprapunerea a fost respinsă cu `23P01`, `ex_programari_vehicul`. |
| Concurență cursant | Suprapunerea a fost respinsă cu `23P01`, mesajul `Cursantul are o sedinta suprapusa`, din `public.verifica_programare()`. |
| Înscrieri active concurente | A doua înscriere activă pentru același cursant a fost respinsă cu `23505`, `uq_inscrieri_cursant_activ`. |
| Curățarea datelor auxiliare | Înregistrările `conc.*` și vehiculele `TESTCONC*` au fost șterse; verificarea finală a indicat `0 / 0`. |

Profilul demonstrativ `admin.demo@example.com` rămâne pentru Etapa 3. Rezultatele de mai sus provin din verificarea bazei de dezvoltare comunicată de beneficiar; această actualizare a fișierelor nu a repetat testele SQL și nu a modificat baza.

## Continuare după Etapa 2B

- În Etapa 3 se implementează și se testează politicile RLS operaționale și granturile necesare fluxurilor aplicației, înainte de accesul CRUD din interfață.
- Înainte de modulele financiare și de examene, se extind testele pentru supraplată, rambursare peste plata inițială, două confirmări concurente, succesiunea încercărilor și tranziții terminale.

## Riscuri și delimitări

- Modelul nu ține cronologia completă a fiecărei repartizări a instructorului; rândul de programare păstrează instructorul efectiv. O cronologie integrală ar cere mecanism de audit sau tabelă nouă aprobată.
- CNP cu 13 cifre validează formatul, nu cifra de control sau identitatea; pentru demo se folosesc numai valori fictive. RLS protejează rânduri, nu coloane.
- 90 minute înseamnă 1,5 **ore cronologice**. Conversia în „ore didactice” nu este definită în dosar. `timestamptz` stochează un instant; formularul trebuie să respingă orele locale inexistente/ambigue la schimbarea orei în `Europe/Bucharest`.
- Data implicită a înscrierii se calculează prin `((now() AT TIME ZONE 'Europe/Bucharest')::date)`, folosind data locală din București la începutul tranzacției, independent de fusul sesiunii PostgreSQL. Serverul poate trimite explicit data locală corectă. Rezervările retroactive sunt permise de schema V1 pentru a testa și istoricul; regulile suplimentare de calendar se stabilesc separat.
- Trigger-ele folosesc `SECURITY DEFINER`, `search_path` fix și tabele calificate. Rolul care aplică migrația trebuie să fie unul de încredere, cu acces complet la cele nouă tabele; nu se activează `FORCE ROW LEVEL SECURITY` fără revizuire. SQL Editor/owner pot ocoli accesul aplicației.
- Migrația este tranzacțională și nu este destinată reaplicării peste obiectele deja create. `DROP` din rollback distruge datele; nu este un mecanism de „undo” pentru producție.

**Închiderea Etapei 2B:** schema a fost aplicată și testele au fost executate în mediul de dezvoltare, iar rollback-ul a rămas neexecutat. Actualizarea acestui repository se oprește fără commit sau push.
