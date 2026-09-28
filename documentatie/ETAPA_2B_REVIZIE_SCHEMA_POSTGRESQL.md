# AUTOSTART VANCEA Manager — Etapa 2B: revizia schemei propuse

**Sursă:** `DOSAR_TEHNIC_AUTOSTART_VANCEA_Manager.md`, versiunea 1.1.
**Stare:** proiect de migrație verificat static, neaplicat. Nu s-a accesat baza Supabase.

## Livrabile și ordine

1. `001_schema_initiala_PROPUNERE_NEEXECUTATA.sql`: tranzacție unică, extensie, nouă tabele, constrângeri, indexuri, funcții, trigger-e, RLS și revocări. Nu este idempotent: se aplică o singură dată pe o schemă fără aceste tabele.
2. `ETAPA_2B_TESTE_SQL_NEEXECUTATE.sql`: verificare de catalog și zece teste de integritate într-o tranzacție încheiată cu `ROLLBACK`; necesită un profil `utilizatori` legat de un cont Auth creat corect.
3. `001_schema_initiala_ROLLBACK_NEEXECUTAT.sql`: demontare inversă, **distructivă**, rezervată unei baze de test izolate după verificarea unui backup.

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
- Triggerul de programare calculează `sfarsit` la inserare și respinge modificarea duratei/identității la actualizare. Pentru cursant, blochează rândul său (`FOR UPDATE`) și caută intervale ocupante prin **toate** înscrierile sale. La nivelul `READ COMMITTED`, două tranzacții pentru același cursant sunt serializate; o coliziune între înscrieri diferite necesită și test cu două sesiuni reale. Capetele comune nu se suprapun.
- Trigger-ele de stare împiedică dezactivarea vehiculului/instructorului, închiderea înscrierii sau repartizarea nouă cât există programări viitoare nerezolvate. Alte trigger-e țin tariful fix în prezența plăților, protejează soldul și numără încercările de examen sub blocarea înscrierii.
- Totalul achitat, restul și orele efectuate se **interoghează**, nu există coloane derivate: `SUM(plata confirmata - rambursare confirmata)`; `tarif_curs - SUM(...)`; `COUNT(sedinte finalizate) * 90` minute, împărțit la 60 pentru ore cronologice.

### RLS și CNP

Migrația activează RLS la toate cele nouă tabele și retrage toate privilegiile pe tabele de la `PUBLIC`, `anon`, `authenticated`, plus `EXECUTE` pe cele opt funcții interne. Nu adaugă încă politici ori granturi de citire/scriere: accesul normal din Next.js va fi indisponibil până la etapa autentificării și autorizării minime. `service_role`/proprietarul pot administra baza; nu se folosesc ca substitut pentru politici în aplicație.

În etapa de acces, citirea `cursanti` se acordă doar pe coloanele nesensibile necesare, **fără** `SELECT` pe tabelă, deoarece acesta ar include `cnp`. Citirea/corectarea CNP și schimbarea rolului necesită operații înguste care verifică identitatea și rolul pe server și în SQL; `anon` nu primește astfel de funcții. Nu se introduc date reale în demo.

### Ordinea și revenirea

**Creare:** `BEGIN` → schema `extensions`/`btree_gist` → `persoane`, `utilizatori`, `cursanti`, `instructori`, `vehicule` → `inscrieri`/unicitate activă → `programari`/GiST → `plati` → `examene` → indexuri → opt funcții → 16 trigger-e → nouă RLS → revocări → `COMMIT`.

**Rollback, numai după aprobare pentru baza de test:** `examene` → `plati` → `programari` → `inscrieri` → `vehicule` → `instructori` → `cursanti` → `utilizatori` → `persoane` → cele opt funcții, invers. `DROP TABLE` elimină indexuri, FK și trigger-e ale tabelei. Nu se folosesc `CASCADE`, nu se atinge `auth.users`, iar `btree_gist`/`extensions` rămân pentru a nu afecta alte proiecte.

## Verificarea efectuată, fără bază de date

Un parser PostgreSQL a acceptat 61 instrucțiuni în migrație, 19 în rollback și 4 în scriptul de teste; verificarea AST a numărat 9 tabele în ordinea necesară, 14 FK cu `RESTRICT` în ambele direcții, PK/NOT NULL, indexul unic parțial, 2 EXCLUDE, 8 funcții, 16 trigger-e, 9 activări RLS și revocările aferente. Parserul de gramatică PL/pgSQL nu a raportat erori în cele opt corpuri; au fost inspectate manual condițiile semideschise și dependențele rollbackului. **Analiza statică nu echivalează cu executarea/compilarea funcțiilor în instanța PostgreSQL** și nu verifică extensia/operatorii, privilegiile rolului de migrație ori efectele la concurență. Nicio instrucțiune SQL nu a fost executată.

## Ce se testează imediat după aplicare

1. Înainte: verificați că cele nouă tabele lipsesc, schema `auth.users` există, PostgreSQL suportă `gen_random_uuid()`, extensia `btree_gist` poate fi activată și rolul migrației are drepturile necesare. Folosiți o bază de dezvoltare izolată și un backup.
2. După `COMMIT`: verificați în catalog cele nouă tabele, 14 FK `RESTRICT`, două EXCLUDE, indexul unic parțial, 16 trigger-e, nouă RLS, granturile revocate și absența coloanei `programari.id_cursant`.
3. Cu un cont Auth demonstrativ creat prin fluxul Auth și profilul său `utilizatori`, rulați scriptul tranzacțional de teste: CNP duplicat (23505), înscriere activă duplicată (23505), tarif invalid (23514), sfârșit recalculat la 90 minute, suprapunere instructor/vehicul/cursant (23P01), capăt comun permis, vehicul în service refuzat (23514), ștergere părinte cu istoric blocată (23503). `ROLLBACK` trebuie să elimine toate datele de test.
4. În **două conexiuni** reale, țineți tranzacția A deschisă la inserare și încercați coliziuni în B: cursant prin înscrieri diferite, instructor, vehicul și două înscrieri active. B trebuie să aștepte ori să eșueze corect la commit, fără două rezervări ocupante. Testați și anularea urmată de reutilizarea slotului.
5. Înainte de a construi modulele financiare/examene, extindeți testele cu supraplată, rambursare peste plata inițială, două confirmări concurente, succesiunea încercărilor și tranziții terminale; testați RLS/granturile cu rolurile reale înainte de accesul din UI.

## Riscuri și delimitări

- Modelul nu ține cronologia completă a fiecărei repartizări a instructorului; rândul de programare păstrează instructorul efectiv. O cronologie integrală ar cere mecanism de audit sau tabelă nouă aprobată.
- CNP cu 13 cifre validează formatul, nu cifra de control sau identitatea; pentru demo se folosesc numai valori fictive. RLS protejează rânduri, nu coloane.
- 90 minute înseamnă 1,5 **ore cronologice**. Conversia în „ore didactice” nu este definită în dosar. `timestamptz` stochează un instant; formularul trebuie să respingă orele locale inexistente/ambigue la schimbarea orei în `Europe/Bucharest`.
- Data implicită a înscrierii se calculează prin `((now() AT TIME ZONE 'Europe/Bucharest')::date)`, folosind data locală din București la începutul tranzacției, independent de fusul sesiunii PostgreSQL. Serverul poate trimite explicit data locală corectă. Rezervările retroactive sunt permise de schema V1 pentru a testa și istoricul; regulile suplimentare de calendar se stabilesc separat.
- Trigger-ele folosesc `SECURITY DEFINER`, `search_path` fix și tabele calificate. Rolul care aplică migrația trebuie să fie unul de încredere, cu acces complet la cele nouă tabele; nu se activează `FORCE ROW LEVEL SECURITY` fără revizuire. SQL Editor/owner pot ocoli accesul aplicației.
- Migrația este tranzacțională, dar prima execuție pe o bază reală poate eșua dacă extensia este instalată în altă schemă, dacă drepturile diferă sau dacă există obiecte cu aceleași nume. `DROP` din rollback distruge datele; nu este un mecanism de „undo” pentru producție.

**Punct de oprire:** în această etapă se livrează proiectul, revizia și testele neexecutate. Aplicarea în Supabase și orice commit/push necesită o sarcină ulterioară, după citirea și acceptarea riscurilor.
