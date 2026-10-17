-- Run only against the disposable PostgreSQL integration database.
-- All synthetic identities and rows are rolled back at the end.
BEGIN;

INSERT INTO auth.users (id, email, raw_user_meta_data)
VALUES
 ('10000000-0000-0000-0000-000000000001','founder-a@example.test','{"display_name":"Founder A","preferred_language":"en"}'::jsonb),
 ('10000000-0000-0000-0000-000000000002','founder-b@example.test','{"display_name":"Founder B","preferred_language":"ar"}'::jsonb);

DO $test$
BEGIN
 IF (SELECT count(*) FROM public.users WHERE auth_user_id IN (
   '10000000-0000-0000-0000-000000000001'::uuid,
   '10000000-0000-0000-0000-000000000002'::uuid
 )) <> 2 THEN
   RAISE EXCEPTION 'Auth signup trigger did not map both users';
 END IF;
 IF EXISTS (
   SELECT 1 FROM public.users
   WHERE role <> 'founder'
     AND auth_user_id IN ('10000000-0000-0000-0000-000000000001'::uuid,'10000000-0000-0000-0000-000000000002'::uuid)
 ) THEN
   RAISE EXCEPTION 'New signup received a privileged role';
 END IF;
END
$test$;

INSERT INTO public.startup_profiles (id, owner_user_id, name)
VALUES
 ('20000000-0000-0000-0000-000000000001',
  (SELECT id FROM public.users WHERE auth_user_id='10000000-0000-0000-0000-000000000001'),
  'Founder A startup'),
 ('20000000-0000-0000-0000-000000000002',
  (SELECT id FROM public.users WHERE auth_user_id='10000000-0000-0000-0000-000000000002'),
  'Founder B startup');

INSERT INTO public.opportunities
 (id,slug,name,organization,description,support_type,status,official_url,last_verified_at,approved_at)
VALUES
 ('30000000-0000-0000-0000-000000000001','rls-test-published','RLS test published opportunity','Test','Disposable RLS fixture','grant','published','https://example.test/published-opportunity',now(),now()),
 ('30000000-0000-0000-0000-000000000002','rls-test-review','RLS test review opportunity','Test','Must stay private from public clients','grant','review',NULL,NULL,NULL);

INSERT INTO public.application_records (startup_id, opportunity_id, notes)
VALUES
 ('20000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Private application A'),
 ('20000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001','Private application B');

SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claim.sub','',true);
DO $test$
BEGIN
 IF (SELECT count(*) FROM public.opportunities) <> 1
    OR EXISTS (SELECT 1 FROM public.opportunities WHERE status <> 'published' OR approved_at IS NULL) THEN
   RAISE EXCEPTION 'Anonymous catalogue visibility is not restricted to approved published opportunities';
 END IF;
 IF has_table_privilege('anon','public.startup_profiles','SELECT') THEN
   RAISE EXCEPTION 'Anonymous role unexpectedly has startup profile table privileges';
 END IF;
 IF has_table_privilege('anon','public.audit_log','SELECT') THEN
   RAISE EXCEPTION 'Anonymous role unexpectedly has audit log privileges';
 END IF;
END
$test$;

RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
DO $test$
DECLARE role_update_denied boolean := false;
        cross_owner_insert_denied boolean := false;
BEGIN
 IF (SELECT count(*) FROM public.users) <> 1 THEN
   RAISE EXCEPTION 'Founder can see another user row';
 END IF;
 IF (SELECT count(*) FROM public.startup_profiles) <> 1
    OR EXISTS (SELECT 1 FROM public.startup_profiles WHERE name='Founder B startup') THEN
   RAISE EXCEPTION 'Founder can see another startup profile';
 END IF;
 IF (SELECT count(*) FROM public.application_records) <> 1
    OR EXISTS (SELECT 1 FROM public.application_records WHERE notes='Private application B') THEN
   RAISE EXCEPTION 'Founder can see another founder application';
 END IF;
 IF (SELECT count(*) FROM public.opportunities) <> 1
    OR EXISTS (SELECT 1 FROM public.opportunities WHERE status='review') THEN
   RAISE EXCEPTION 'Founder can see unpublished opportunities';
 END IF;
 IF (SELECT private.current_masar_user_role()) <> 'founder' THEN
   RAISE EXCEPTION 'Current founder identity/role was not resolved';
 END IF;

 BEGIN
   EXECUTE 'UPDATE public.users SET role = ''admin'' WHERE id = $1'
     USING (SELECT private.current_masar_user_id());
 EXCEPTION WHEN insufficient_privilege THEN
   role_update_denied := true;
 END;
 IF NOT role_update_denied THEN
   RAISE EXCEPTION 'Founder was able to update their own role';
 END IF;

 BEGIN
   INSERT INTO public.application_records (startup_id, opportunity_id, notes)
   VALUES ('20000000-0000-0000-0000-000000000002',
           '30000000-0000-0000-0000-000000000001',
           'cross-owner injection must be denied');
 EXCEPTION WHEN insufficient_privilege THEN
   cross_owner_insert_denied := true;
 END;
 IF NOT cross_owner_insert_denied THEN
   RAISE EXCEPTION 'Founder inserted an application for another founder';
 END IF;
END
$test$;

ROLLBACK;
