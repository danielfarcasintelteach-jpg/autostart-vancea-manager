-- AUTOSTART VANCEA Manager - Etapa 2B, migrare initiala aplicata in Supabase de dezvoltare.
-- Se aplica o singura data, pe o baza fara aceste noua tabele.
-- Cerinte: PostgreSQL Supabase, rol cu drept de CREATE, schema auth.users existenta.
-- Testele de concurenta si RLS sunt obligatorii inainte de utilizarea aplicatiei.

BEGIN;
CREATE SCHEMA IF NOT EXISTS extensions;
SET LOCAL search_path = pg_catalog, public, extensions;
CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA extensions;

-- 1. Parinti si profiluri: nicio tabela proprie nu contine parola.
CREATE TABLE public.persoane (
  id_persoana uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nume varchar(100) NOT NULL,
  prenume varchar(100) NOT NULL,
  telefon varchar(30),
  email varchar(254),
  data_nasterii date,
  adresa text,
  data_crearii timestamptz NOT NULL DEFAULT now(),
  data_modificarii timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_persoane_nume CHECK (btrim(nume) <> '' AND btrim(prenume) <> '')
);

CREATE TABLE public.utilizatori (
  id_utilizator uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  id_persoana uuid NOT NULL UNIQUE REFERENCES public.persoane(id_persoana) ON DELETE RESTRICT ON UPDATE RESTRICT,
  rol varchar(20) NOT NULL,
  activ boolean NOT NULL DEFAULT true,
  data_crearii timestamptz NOT NULL DEFAULT now(),
  data_modificarii timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_utilizatori_rol CHECK (rol IN ('administrator', 'secretariat', 'instructor', 'cursant'))
);

CREATE TABLE public.cursanti (
  id_cursant uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  id_persoana uuid NOT NULL UNIQUE REFERENCES public.persoane(id_persoana) ON DELETE RESTRICT ON UPDATE RESTRICT,
  cnp varchar(13) NOT NULL UNIQUE,
  stare varchar(10) NOT NULL DEFAULT 'activ',
  observatii text,
  data_crearii timestamptz NOT NULL DEFAULT now(),
  data_modificarii timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_cursanti_cnp CHECK (cnp ~ '^[0-9]{13}$'),
  CONSTRAINT ck_cursanti_stare CHECK (stare IN ('activ', 'inactiv'))
);

CREATE TABLE public.instructori (
  id_instructor uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  id_persoana uuid NOT NULL UNIQUE REFERENCES public.persoane(id_persoana) ON DELETE RESTRICT ON UPDATE RESTRICT,
  data_angajarii date,
  stare varchar(10) NOT NULL DEFAULT 'activ',
  observatii text,
  data_crearii timestamptz NOT NULL DEFAULT now(),
  data_modificarii timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_instructori_stare CHECK (stare IN ('activ', 'inactiv'))
);

CREATE TABLE public.vehicule (
  id_vehicul uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  numar_inmatriculare varchar(20) NOT NULL UNIQUE,
  marca varchar(100) NOT NULL,
  model varchar(100) NOT NULL,
  an_fabricatie smallint,
  stare varchar(15) NOT NULL DEFAULT 'activ',
  observatii text,
  data_crearii timestamptz NOT NULL DEFAULT now(),
  data_modificarii timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_vehicule_numar CHECK (numar_inmatriculare ~ '^[A-Z0-9]+$'),
  CONSTRAINT ck_vehicule_descriere CHECK (btrim(marca) <> '' AND btrim(model) <> ''),
  CONSTRAINT ck_vehicule_an CHECK (an_fabricatie IS NULL OR an_fabricatie >= 1900),
  CONSTRAINT ck_vehicule_stare CHECK (stare IN ('activ', 'service', 'indisponibil', 'inactiv'))
);

-- 2. Inscrierea fixeaza tariful; doar una activa per cursant.
CREATE TABLE public.inscrieri (
  id_inscriere uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  id_cursant uuid NOT NULL REFERENCES public.cursanti(id_cursant) ON DELETE RESTRICT ON UPDATE RESTRICT,
  id_instructor uuid NOT NULL REFERENCES public.instructori(id_instructor) ON DELETE RESTRICT ON UPDATE RESTRICT,
  categorie char(1) NOT NULL DEFAULT 'B',
  data_inscrierii date NOT NULL DEFAULT ((now() AT TIME ZONE 'Europe/Bucharest')::date),
  tarif_curs numeric(12,2) NOT NULL,
  stare varchar(12) NOT NULL DEFAULT 'activa',
  data_finalizarii date,
  observatii text,
  data_crearii timestamptz NOT NULL DEFAULT now(),
  data_modificarii timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_inscrieri_categorie CHECK (categorie = 'B'),
  CONSTRAINT ck_inscrieri_tarif CHECK (tarif_curs > 0),
  CONSTRAINT ck_inscrieri_stare CHECK (stare IN ('activa', 'finalizata', 'anulata')),
  CONSTRAINT ck_inscrieri_finalizare CHECK ((stare = 'finalizata') = (data_finalizarii IS NOT NULL)),
  CONSTRAINT ck_inscrieri_data CHECK (data_finalizarii IS NULL OR data_finalizarii >= data_inscrierii)
);
CREATE UNIQUE INDEX uq_inscrieri_cursant_activ ON public.inscrieri (id_cursant) WHERE stare = 'activa';

-- 3. Calendarul foloseste intervale semi-deschise: [inceput, sfarsit).
-- Fara id_cursant: acesta se obtine numai din inscrieri.id_cursant.
CREATE TABLE public.programari (
  id_programare uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  id_inscriere uuid NOT NULL REFERENCES public.inscrieri(id_inscriere) ON DELETE RESTRICT ON UPDATE RESTRICT,
  id_instructor uuid NOT NULL REFERENCES public.instructori(id_instructor) ON DELETE RESTRICT ON UPDATE RESTRICT,
  id_vehicul uuid NOT NULL REFERENCES public.vehicule(id_vehicul) ON DELETE RESTRICT ON UPDATE RESTRICT,
  inceput timestamptz NOT NULL,
  sfarsit timestamptz NOT NULL,
  stare varchar(12) NOT NULL DEFAULT 'programata',
  id_utilizator_creare uuid NOT NULL REFERENCES public.utilizatori(id_utilizator) ON DELETE RESTRICT ON UPDATE RESTRICT,
  observatii text,
  data_crearii timestamptz NOT NULL DEFAULT now(),
  data_modificarii timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_programari_stare CHECK (stare IN ('programata', 'finalizata', 'anulata', 'absent')),
  CONSTRAINT ck_programari_durata CHECK (sfarsit - inceput = interval '90 minutes'),
  CONSTRAINT ex_programari_instructor EXCLUDE USING gist
    (id_instructor WITH =, tstzrange(inceput, sfarsit, '[)') WITH &&)
    WHERE (stare IN ('programata', 'finalizata', 'absent')),
  CONSTRAINT ex_programari_vehicul EXCLUDE USING gist
    (id_vehicul WITH =, tstzrange(inceput, sfarsit, '[)') WITH &&)
    WHERE (stare IN ('programata', 'finalizata', 'absent'))
);

-- 4. Istoric financiar si examene; totalurile nu sunt coloane.
CREATE TABLE public.plati (
  id_plata uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  id_inscriere uuid NOT NULL REFERENCES public.inscrieri(id_inscriere) ON DELETE RESTRICT ON UPDATE RESTRICT,
  id_utilizator_inregistrare uuid NOT NULL REFERENCES public.utilizatori(id_utilizator) ON DELETE RESTRICT ON UPDATE RESTRICT,
  id_plata_initiala uuid REFERENCES public.plati(id_plata) ON DELETE RESTRICT ON UPDATE RESTRICT,
  tip varchar(12) NOT NULL,
  suma numeric(12,2) NOT NULL,
  stare varchar(15) NOT NULL DEFAULT 'in_asteptare',
  data_platii timestamptz NOT NULL DEFAULT now(),
  metoda_plata varchar(20),
  referinta text,
  data_crearii timestamptz NOT NULL DEFAULT now(),
  data_modificarii timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_plati_tip CHECK (tip IN ('plata', 'rambursare')),
  CONSTRAINT ck_plati_suma CHECK (suma > 0),
  CONSTRAINT ck_plati_stare CHECK (stare IN ('in_asteptare', 'confirmata', 'anulata')),
  CONSTRAINT ck_plati_referinta CHECK ((tip = 'rambursare') = (id_plata_initiala IS NOT NULL)),
  CONSTRAINT ck_plati_fara_autoreferinta CHECK (id_plata_initiala IS NULL OR id_plata_initiala <> id_plata)
);

CREATE TABLE public.examene (
  id_examen uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  id_inscriere uuid NOT NULL REFERENCES public.inscrieri(id_inscriere) ON DELETE RESTRICT ON UPDATE RESTRICT,
  tip_examen varchar(10) NOT NULL,
  numar_incercare smallint NOT NULL,
  data_examenului timestamptz NOT NULL,
  stare varchar(15) NOT NULL DEFAULT 'programat',
  rezultat varchar(10),
  punctaj smallint,
  observatii text,
  data_crearii timestamptz NOT NULL DEFAULT now(),
  data_modificarii timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_examene_incercare UNIQUE (id_inscriere, tip_examen, numar_incercare),
  CONSTRAINT ck_examene_tip CHECK (tip_examen IN ('teoretic', 'practic')),
  CONSTRAINT ck_examene_incercare CHECK (numar_incercare > 0),
  CONSTRAINT ck_examene_stare CHECK (stare IN ('programat', 'sustinut', 'anulat', 'neprezentat')),
  CONSTRAINT ck_examene_rezultat CHECK (rezultat IS NULL OR rezultat IN ('admis', 'respins')),
  CONSTRAINT ck_examene_completare CHECK ((stare = 'sustinut') = (rezultat IS NOT NULL)),
  CONSTRAINT ck_examene_punctaj CHECK (punctaj IS NULL OR (tip_examen = 'teoretic' AND punctaj >= 0))
);

-- Indexurile PK/UNIQUE si cele doua EXCLUDE se creeaza deja automat.
CREATE INDEX idx_persoane_nume_prenume ON public.persoane (nume, prenume);
CREATE INDEX idx_inscrieri_cursant ON public.inscrieri (id_cursant);
CREATE INDEX idx_inscrieri_instructor ON public.inscrieri (id_instructor);
CREATE INDEX idx_programari_inscriere_inceput ON public.programari (id_inscriere, inceput);
CREATE INDEX idx_programari_instructor_inceput ON public.programari (id_instructor, inceput);
CREATE INDEX idx_programari_vehicul_inceput ON public.programari (id_vehicul, inceput);
CREATE INDEX idx_programari_creator ON public.programari (id_utilizator_creare);
CREATE INDEX idx_plati_inscriere_data ON public.plati (id_inscriere, data_platii);
CREATE INDEX idx_plati_inregistrare ON public.plati (id_utilizator_inregistrare);
CREATE INDEX idx_plati_initiala ON public.plati (id_plata_initiala);
CREATE INDEX idx_examene_inscriere_data ON public.examene (id_inscriere, data_examenului);

-- 5. Reguli intre randuri/tabele. Definitia si REVOKE sunt in aceeasi tranzactie.
CREATE FUNCTION public.actualizeaza_audit() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    NEW.data_crearii := now();
  ELSE
    NEW.data_crearii := OLD.data_crearii;
  END IF;
  NEW.data_modificarii := now();
  RETURN NEW;
END;
$$;

CREATE FUNCTION public.verifica_inscriere() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE
  stare_cursant varchar(10);
  stare_instructor varchar(10);
  verifica_legaturi boolean := false;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NEW.id_inscriere IS DISTINCT FROM OLD.id_inscriere
       OR NEW.id_cursant IS DISTINCT FROM OLD.id_cursant
       OR NEW.categorie IS DISTINCT FROM OLD.categorie
       OR NEW.data_inscrierii IS DISTINCT FROM OLD.data_inscrierii THEN
      RAISE EXCEPTION 'Identitatea inscrierii nu se modifica' USING ERRCODE = '23514';
    END IF;
    IF OLD.stare <> 'activa' AND (
      NEW.stare IS DISTINCT FROM OLD.stare
      OR NEW.data_finalizarii IS DISTINCT FROM OLD.data_finalizarii
      OR NEW.id_instructor IS DISTINCT FROM OLD.id_instructor
      OR NEW.tarif_curs IS DISTINCT FROM OLD.tarif_curs
    ) THEN
      RAISE EXCEPTION 'Inscrierea inchisa nu se rescrie' USING ERRCODE = '23514';
    END IF;
    IF NEW.tarif_curs IS DISTINCT FROM OLD.tarif_curs
       AND EXISTS (SELECT 1 FROM public.plati WHERE id_inscriere = OLD.id_inscriere) THEN
      RAISE EXCEPTION 'Tariful cu plati inregistrate nu se schimba' USING ERRCODE = '23514';
    END IF;
    IF (NEW.stare IS DISTINCT FROM OLD.stare AND NEW.stare <> 'activa')
       OR NEW.id_instructor IS DISTINCT FROM OLD.id_instructor THEN
      IF EXISTS (
        SELECT 1 FROM public.programari
        WHERE id_inscriere = OLD.id_inscriere AND stare = 'programata' AND inceput >= now()
      ) THEN
        RAISE EXCEPTION 'Rezolvati programarile viitoare inainte de inchidere/repartizare'
          USING ERRCODE = '23514';
      END IF;
    END IF;
    verifica_legaturi := NEW.id_instructor IS DISTINCT FROM OLD.id_instructor;
  ELSIF NEW.stare <> 'activa' THEN
    RAISE EXCEPTION 'Inscrierea noua trebuie sa fie activa' USING ERRCODE = '23514';
  ELSE
    verifica_legaturi := true;
  END IF;

  IF verifica_legaturi THEN
    SELECT stare INTO stare_cursant FROM public.cursanti
      WHERE id_cursant = NEW.id_cursant FOR UPDATE;
    SELECT stare INTO stare_instructor FROM public.instructori
      WHERE id_instructor = NEW.id_instructor FOR UPDATE;
    IF stare_cursant IS DISTINCT FROM 'activ' OR stare_instructor IS DISTINCT FROM 'activ' THEN
      RAISE EXCEPTION 'Cursantul si instructorul trebuie sa fie activi' USING ERRCODE = '23514';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE FUNCTION public.verifica_programare() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE
  inscriere public.inscrieri%ROWTYPE;
  stare_cursant varchar(10);
  stare_instructor varchar(10);
  stare_vehicul varchar(15);
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NEW.id_programare IS DISTINCT FROM OLD.id_programare
       OR NEW.id_inscriere IS DISTINCT FROM OLD.id_inscriere
       OR NEW.id_instructor IS DISTINCT FROM OLD.id_instructor
       OR NEW.id_vehicul IS DISTINCT FROM OLD.id_vehicul
       OR NEW.id_utilizator_creare IS DISTINCT FROM OLD.id_utilizator_creare
       OR NEW.inceput IS DISTINCT FROM OLD.inceput
       OR NEW.sfarsit IS DISTINCT FROM OLD.sfarsit THEN
      RAISE EXCEPTION 'Reprogramarea cere anulare si rand nou' USING ERRCODE = '23514';
    END IF;
    IF OLD.stare <> 'programata' AND NEW.stare IS DISTINCT FROM OLD.stare THEN
      RAISE EXCEPTION 'Starea finala a sedintei nu se reactiveaza' USING ERRCODE = '23514';
    END IF;
    IF NEW.stare <> 'programata' OR OLD.stare <> 'programata' THEN
      RETURN NEW; -- anulata elibereaza slotul; finalizata/absent il pastreaza
    END IF;
  ELSE
    NEW.sfarsit := NEW.inceput + interval '90 minutes';
    IF NEW.stare <> 'programata' THEN
      RAISE EXCEPTION 'Programarea noua incepe in stare programata' USING ERRCODE = '23514';
    END IF;
  END IF;

  SELECT * INTO inscriere FROM public.inscrieri
    WHERE id_inscriere = NEW.id_inscriere FOR UPDATE;
  IF NOT FOUND OR inscriere.stare <> 'activa' OR inscriere.id_instructor <> NEW.id_instructor THEN
    RAISE EXCEPTION 'Inscriere inactiva sau instructor nerepartizat' USING ERRCODE = '23514';
  END IF;
  SELECT stare INTO stare_cursant FROM public.cursanti
    WHERE id_cursant = inscriere.id_cursant FOR UPDATE;
  SELECT stare INTO stare_instructor FROM public.instructori
    WHERE id_instructor = NEW.id_instructor FOR UPDATE;
  SELECT stare INTO stare_vehicul FROM public.vehicule
    WHERE id_vehicul = NEW.id_vehicul FOR UPDATE;
  IF stare_cursant IS DISTINCT FROM 'activ' OR stare_instructor IS DISTINCT FROM 'activ'
     OR stare_vehicul IS DISTINCT FROM 'activ' THEN
    RAISE EXCEPTION 'Cursantul, instructorul si vehiculul trebuie sa fie activi' USING ERRCODE = '23514';
  END IF;

  -- Interogare noua DUPA blocarea cursantului; in READ COMMITTED vede tranzactia precedenta.
  IF EXISTS (
    SELECT 1 FROM public.programari AS p
    JOIN public.inscrieri AS i ON i.id_inscriere = p.id_inscriere
    WHERE i.id_cursant = inscriere.id_cursant
      AND p.id_programare <> NEW.id_programare
      AND p.stare IN ('programata', 'finalizata', 'absent')
      AND p.inceput < NEW.sfarsit AND NEW.inceput < p.sfarsit
  ) THEN
    RAISE EXCEPTION 'Cursantul are o sedinta suprapusa' USING ERRCODE = '23P01';
  END IF;
  RETURN NEW;
END;
$$;

CREATE FUNCTION public.protejeaza_vehicul() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  IF NEW.id_vehicul IS DISTINCT FROM OLD.id_vehicul THEN
    RAISE EXCEPTION 'Identitatea vehiculului nu se modifica' USING ERRCODE = '23514';
  END IF;
  IF OLD.stare = 'activ' AND NEW.stare <> 'activ' AND EXISTS (
    SELECT 1 FROM public.programari WHERE id_vehicul = OLD.id_vehicul
      AND stare = 'programata' AND inceput >= now()
  ) THEN
    RAISE EXCEPTION 'Vehiculul are programari viitoare' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

CREATE FUNCTION public.protejeaza_instructor() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  IF NEW.id_instructor IS DISTINCT FROM OLD.id_instructor
     OR NEW.id_persoana IS DISTINCT FROM OLD.id_persoana THEN
    RAISE EXCEPTION 'Identitatea instructorului nu se modifica' USING ERRCODE = '23514';
  END IF;
  IF OLD.stare = 'activ' AND NEW.stare <> 'activ' AND (
    EXISTS (SELECT 1 FROM public.inscrieri
      WHERE id_instructor = OLD.id_instructor AND stare = 'activa')
    OR EXISTS (SELECT 1 FROM public.programari
      WHERE id_instructor = OLD.id_instructor AND stare = 'programata' AND inceput >= now())
  ) THEN
    RAISE EXCEPTION 'Instructorul are inscrieri active sau programari viitoare' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

CREATE FUNCTION public.protejeaza_cursant() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  IF NEW.id_cursant IS DISTINCT FROM OLD.id_cursant
     OR NEW.id_persoana IS DISTINCT FROM OLD.id_persoana THEN
    RAISE EXCEPTION 'Identitatea cursantului nu se modifica' USING ERRCODE = '23514';
  END IF;
  IF OLD.stare = 'activ' AND NEW.stare <> 'activ' AND EXISTS (
    SELECT 1 FROM public.inscrieri WHERE id_cursant = OLD.id_cursant AND stare = 'activa'
  ) THEN
    RAISE EXCEPTION 'Cursantul are o inscriere activa' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

CREATE FUNCTION public.verifica_plata() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE
  tarif numeric(12,2);
  total numeric(12,2);
  initiala public.plati%ROWTYPE;
  rambursat numeric(12,2);
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF OLD.stare <> 'in_asteptare' THEN
      RAISE EXCEPTION 'Plata finala nu se modifica; creati un eveniment nou' USING ERRCODE = '23514';
    END IF;
    IF NEW.id_plata IS DISTINCT FROM OLD.id_plata
       OR NEW.id_inscriere IS DISTINCT FROM OLD.id_inscriere
       OR NEW.id_utilizator_inregistrare IS DISTINCT FROM OLD.id_utilizator_inregistrare
       OR NEW.id_plata_initiala IS DISTINCT FROM OLD.id_plata_initiala
       OR NEW.tip IS DISTINCT FROM OLD.tip OR NEW.suma IS DISTINCT FROM OLD.suma
       OR NEW.data_platii IS DISTINCT FROM OLD.data_platii
       OR NEW.metoda_plata IS DISTINCT FROM OLD.metoda_plata
       OR NEW.referinta IS DISTINCT FROM OLD.referinta THEN
      RAISE EXCEPTION 'Datele platii nu se modifica; numai starea se confirma/anuleaza'
        USING ERRCODE = '23514';
    END IF;
  END IF;
  SELECT tarif_curs INTO tarif FROM public.inscrieri
    WHERE id_inscriere = NEW.id_inscriere FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Inscriere inexistenta' USING ERRCODE = '23503';
  END IF;
  IF NEW.tip = 'rambursare' THEN
    SELECT * INTO initiala FROM public.plati WHERE id_plata = NEW.id_plata_initiala;
    IF NOT FOUND OR initiala.id_inscriere <> NEW.id_inscriere OR initiala.tip <> 'plata' THEN
      RAISE EXCEPTION 'Rambursarea indica o plata a aceleiasi inscrieri' USING ERRCODE = '23514';
    END IF;
  END IF;
  IF NEW.stare = 'confirmata' THEN
    SELECT COALESCE(SUM(CASE WHEN tip = 'plata' THEN suma ELSE -suma END), 0)
      INTO total FROM public.plati
      WHERE id_inscriere = NEW.id_inscriere AND stare = 'confirmata';
    IF NEW.tip = 'plata' AND total + NEW.suma > tarif THEN
      RAISE EXCEPTION 'Plata depaseste tariful' USING ERRCODE = '23514';
    ELSIF NEW.tip = 'rambursare' THEN
      IF initiala.stare <> 'confirmata' OR total - NEW.suma < 0 THEN
        RAISE EXCEPTION 'Rambursare fara plata confirmata sau sold suficient' USING ERRCODE = '23514';
      END IF;
      SELECT COALESCE(SUM(suma), 0) INTO rambursat FROM public.plati
        WHERE id_plata_initiala = NEW.id_plata_initiala AND stare = 'confirmata';
      IF rambursat + NEW.suma > initiala.suma THEN
        RAISE EXCEPTION 'Rambursarea depaseste plata initiala' USING ERRCODE = '23514';
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE FUNCTION public.verifica_examen() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE
  urmatoarea_incercare integer;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NEW.id_examen IS DISTINCT FROM OLD.id_examen
       OR NEW.id_inscriere IS DISTINCT FROM OLD.id_inscriere
       OR NEW.tip_examen IS DISTINCT FROM OLD.tip_examen
       OR NEW.numar_incercare IS DISTINCT FROM OLD.numar_incercare
       OR NEW.data_examenului IS DISTINCT FROM OLD.data_examenului THEN
      RAISE EXCEPTION 'Incercarea nu se rescrie; creati un rand nou' USING ERRCODE = '23514';
    END IF;
    IF OLD.stare <> 'programat' AND (
      NEW.stare IS DISTINCT FROM OLD.stare
      OR NEW.rezultat IS DISTINCT FROM OLD.rezultat
      OR NEW.punctaj IS DISTINCT FROM OLD.punctaj
    ) THEN
      RAISE EXCEPTION 'Rezultatul examenului final nu se rescrie' USING ERRCODE = '23514';
    END IF;
  ELSE
    PERFORM 1 FROM public.inscrieri WHERE id_inscriere = NEW.id_inscriere FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Inscriere inexistenta' USING ERRCODE = '23503';
    END IF;
    SELECT COALESCE(MAX(numar_incercare), 0) + 1 INTO urmatoarea_incercare
      FROM public.examene
      WHERE id_inscriere = NEW.id_inscriere AND tip_examen = NEW.tip_examen;
    IF NEW.numar_incercare IS NOT NULL AND NEW.numar_incercare <> urmatoarea_incercare THEN
      RAISE EXCEPTION 'Numarul urmatoarei incercari este %', urmatoarea_incercare
        USING ERRCODE = '23514';
    END IF;
    NEW.numar_incercare := urmatoarea_incercare;
    IF NEW.stare <> 'programat' THEN
      RAISE EXCEPTION 'Examenul nou incepe in stare programat' USING ERRCODE = '23514';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- Business triggers, apoi auditul (prefixul zz). UPDATE pe randurile finale este limitat.
CREATE TRIGGER verifica_inscriere BEFORE INSERT OR UPDATE ON public.inscrieri
FOR EACH ROW EXECUTE FUNCTION public.verifica_inscriere();
CREATE TRIGGER verifica_programare BEFORE INSERT OR UPDATE ON public.programari
FOR EACH ROW EXECUTE FUNCTION public.verifica_programare();
CREATE TRIGGER protejeaza_vehicul BEFORE UPDATE ON public.vehicule
FOR EACH ROW EXECUTE FUNCTION public.protejeaza_vehicul();
CREATE TRIGGER protejeaza_instructor BEFORE UPDATE ON public.instructori
FOR EACH ROW EXECUTE FUNCTION public.protejeaza_instructor();
CREATE TRIGGER protejeaza_cursant BEFORE UPDATE ON public.cursanti
FOR EACH ROW EXECUTE FUNCTION public.protejeaza_cursant();
CREATE TRIGGER verifica_plata BEFORE INSERT OR UPDATE ON public.plati
FOR EACH ROW EXECUTE FUNCTION public.verifica_plata();
CREATE TRIGGER verifica_examen BEFORE INSERT OR UPDATE ON public.examene
FOR EACH ROW EXECUTE FUNCTION public.verifica_examen();

CREATE TRIGGER zz_audit BEFORE INSERT OR UPDATE ON public.persoane FOR EACH ROW EXECUTE FUNCTION public.actualizeaza_audit();
CREATE TRIGGER zz_audit BEFORE INSERT OR UPDATE ON public.utilizatori FOR EACH ROW EXECUTE FUNCTION public.actualizeaza_audit();
CREATE TRIGGER zz_audit BEFORE INSERT OR UPDATE ON public.cursanti FOR EACH ROW EXECUTE FUNCTION public.actualizeaza_audit();
CREATE TRIGGER zz_audit BEFORE INSERT OR UPDATE ON public.instructori FOR EACH ROW EXECUTE FUNCTION public.actualizeaza_audit();
CREATE TRIGGER zz_audit BEFORE INSERT OR UPDATE ON public.vehicule FOR EACH ROW EXECUTE FUNCTION public.actualizeaza_audit();
CREATE TRIGGER zz_audit BEFORE INSERT OR UPDATE ON public.inscrieri FOR EACH ROW EXECUTE FUNCTION public.actualizeaza_audit();
CREATE TRIGGER zz_audit BEFORE INSERT OR UPDATE ON public.programari FOR EACH ROW EXECUTE FUNCTION public.actualizeaza_audit();
CREATE TRIGGER zz_audit BEFORE INSERT OR UPDATE ON public.plati FOR EACH ROW EXECUTE FUNCTION public.actualizeaza_audit();
CREATE TRIGGER zz_audit BEFORE INSERT OR UPDATE ON public.examene FOR EACH ROW EXECUTE FUNCTION public.actualizeaza_audit();

-- 6. Siguranta initiala: nici anon, nici authenticated nu primesc acces pana la politici.
-- RLS este activ pe toate cele noua tabele; etapa de autorizare adauga granturi/politici explicite.
ALTER TABLE public.persoane ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.utilizatori ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cursanti ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.instructori ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicule ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inscrieri ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.programari ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.plati ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.examene ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.persoane, public.utilizatori, public.cursanti,
  public.instructori, public.vehicule, public.inscrieri, public.programari,
  public.plati, public.examene FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.actualizeaza_audit(), public.verifica_inscriere(),
  public.verifica_programare(), public.protejeaza_vehicul(), public.protejeaza_instructor(),
  public.protejeaza_cursant(), public.verifica_plata(), public.verifica_examen()
  FROM PUBLIC, anon, authenticated;

COMMIT;
