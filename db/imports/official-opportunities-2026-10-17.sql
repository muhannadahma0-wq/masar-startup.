-- Masar Startup: official funding-program candidates checked 2026-10-17.
-- Safe import: only NEW rows, always status='review'. No publish/update/delete.
-- Run after confirming DATABASE_URL points to the intended Masar database and backing it up:
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f db/imports/official-opportunities-2026-10-17.sql

BEGIN;

CREATE TEMP TABLE _masar_candidates (
 slug TEXT PRIMARY KEY, name TEXT NOT NULL, organization TEXT NOT NULL, description TEXT NOT NULL,
 support_type TEXT NOT NULL, eligible_geographies TEXT[] NOT NULL, excluded_geographies TEXT[] NOT NULL,
 sectors TEXT[] NOT NULL, eligible_stages TEXT[] NOT NULL, amount_min NUMERIC(16,2), amount_max NUMERIC(16,2),
 currency CHAR(3), deadline TIMESTAMPTZ, rolling_admissions BOOLEAN NOT NULL,
 application_language TEXT[] NOT NULL, official_url TEXT NOT NULL, official_criteria TEXT NOT NULL
) ON COMMIT DROP;

INSERT INTO _masar_candidates VALUES
(
 'rise-palestine-startup-grant-review-2026','RISE Palestine Startup Grant','RISE Palestine Initiative',
 'Grant support for early-stage startups in Gaza, the West Bank, and East Jerusalem affected by the war, intended to help cover operating costs and lost revenues. Published cap: USD 50,000 per startup. Review candidate only: the official application page says solicitation and disbursement begin after a minimum USD 500,000 commitment; current intake has not been independently confirmed.',
 'grant', ARRAY['Gaza','West Bank','East Jerusalem']::TEXT[], ARRAY[]::TEXT[],
 ARRAY['technology','digital products or services']::TEXT[], ARRAY[]::TEXT[],
 NULL,50000,'USD',NULL,FALSE,ARRAY[]::TEXT[],
 'https://risepalestine.intersecthub.org/grants/startup-grant/',
 'Early-stage startups in Gaza, the West Bank, and East Jerusalem affected by the war; stated cap USD 50,000 per startup. The official page says applications and disbursements begin after a minimum USD 500,000 commitment. Confirm current threshold, intake, geography, registration and technology criteria before publication.'
),
(
 'scale-market-access-matching-grants-review-2026','Scale (Market-Access Matching Grants)','IPSD II / Scale',
 'Cost-sharing market-access grants for eligible Palestinian technology and technology-enabled startups and innovative SMEs pursuing a specific, verifiable market opportunity. Official page states up to 80% of eligible costs, capped at USD 30,000 per firm; eligible women-owned/managed firms may qualify for up to 90% within the same cap. Applications are rolling but subject to funding availability, so this record remains in review.',
 'grant', ARRAY['Palestine','Gaza','West Bank','East Jerusalem']::TEXT[], ARRAY[]::TEXT[],
 ARRAY['technology','technology-enabled','innovative SME']::TEXT[], ARRAY[]::TEXT[],
 NULL,30000,'USD',NULL,TRUE,ARRAY[]::TEXT[],
 'https://ipsd.ps/content/programs/scale-market-access-matching-grants.html',
 'Applicant must be legally registered with the Palestinian Ministry of National Economy, have an active tax file, have operated for at least three months, have annual revenue no greater than USD 5 million, demonstrate a verified market opportunity, be ready to enter or expand in a target market, and provide the required cost-share. Applications are rolling subject to funding availability and requirements. Confirm availability and geographic handling before publication.'
),
(
 'start-now-interest-free-financing-review-2026','Start Now – Interest-Free Project Financing','Palestine Monetary Authority / Palestinian Employment Fund',
 'Repayable interest-free financing for eligible small and micro-projects, not a grant. The official PMA page states a maximum USD 10,000, a grace period up to 12 months, and repayment up to 48 months. The page does not clearly confirm a current intake; geographic coverage and current application route require reviewer confirmation.',
 'other', ARRAY['Palestine']::TEXT[], ARRAY[]::TEXT[], ARRAY[]::TEXT[], ARRAY[]::TEXT[],
 NULL,10000,'USD',NULL,FALSE,ARRAY[]::TEXT[],
 'https://www.pma.ps/start-now-program',
 'Interest-free repayable financing, not a grant. Conditions shown include borrower age at least 22; ownership of at least 51% and self-management for at least one year; no more than nine workers; annual sales not exceeding USD 200,000; official registration or a tax file; no overdue installments; proof of use of funds; and monthly income sufficient to cover installments. Additional conditions apply to disability and vocational/technical education categories. Confirm current intake and geography before publication.'
),
(
 'rise-team-company-stipend-review-2026','RISE Palestine TEAM Grant — Company Stipend','RISE Palestine Initiative',
 'Emergency support for established Palestinian technology companies affected by the war. Official English page states up to USD 10,000 per company to support tech-talent salaries, while the official Arabic contribution page describes up to USD 10,000 per month for up to three months. The amount period is inconsistent across official pages and must be clarified directly. The official application page says opening/disbursement depends on a minimum USD 500,000 commitment; current availability is unconfirmed.',
 'grant', ARRAY['Gaza']::TEXT[], ARRAY[]::TEXT[], ARRAY['technology','tech consultancy','outsourcing']::TEXT[], ARRAY[]::TEXT[],
 NULL,NULL,'USD',NULL,FALSE,ARRAY[]::TEXT[],
 'https://risepalestine.intersecthub.org/grants/team-grant/',
 'Company pathway: established technology company operating in Palestine; the page permits registered companies or companies in the process of/committed to Palestinian registration. Company should provide technology consultancies, outsourcing or technology-based consultancy services; show launched product/service traction and customer validation; and evidence operations/revenue affected by the war. Stipend amount period conflicts between official English and Arabic pages. Confirm eligible geography, exact amount/period and current intake before publication.'
),
(
 'rise-team-freelancer-stipend-review-2026','RISE Palestine TEAM Grant — Freelancer Stipend','RISE Palestine Initiative',
 'Emergency stipend for technology freelancers affected by the war. The official page states up to USD 1,500 per month for up to six months. The overview describes affected freelancers in Gaza, the West Bank and East Jerusalem, while the detailed freelancer eligibility section specifically says the freelancer must have operated out of Gaza and have a registered bank account in Palestine. Keep the scope in review until the program confirms the controlling criterion and funding availability.',
 'grant', ARRAY['Gaza','West Bank','East Jerusalem']::TEXT[], ARRAY[]::TEXT[], ARRAY['technology','software','hardware','systems']::TEXT[], ARRAY[]::TEXT[],
 NULL,NULL,'USD',NULL,FALSE,ARRAY[]::TEXT[],
 'https://risepalestine.intersecthub.org/grants/team-grant/',
 'Freelancer pathway: detailed eligibility says the freelancer operated out of Gaza, has a registered Palestinian bank account, derives primary revenue from technology services/products/platforms/hardware/software/systems, and can evidence unfulfilled contractual obligations caused by the war. The overview also mentions West Bank and East Jerusalem; human confirmation required before using a hard geography rule. Maximum stated support is USD 1,500 per month for up to six months. Current intake must be confirmed.'
),
(
 'safe-palestine-bridge-financing-review-2026','SAFE Palestine — Startup Bridge Financing','RISE Palestine Initiative',
 'Bridge financing for Palestinian technology startups described by the official RISE Startup Grant page as up to USD 200,000 per startup through a mix of grants and SAFE notes. The same application asks startups to indicate interest in this pathway. The precise qualifying performance/financing tests need manual review because the published wording combines multiple alternatives; it must not be presented as a guaranteed grant or published as open until confirmed.',
 'other', ARRAY['Palestine','Gaza','West Bank','East Jerusalem']::TEXT[], ARRAY[]::TEXT[], ARRAY['technology','digital products','software-driven hardware']::TEXT[], ARRAY[]::TEXT[],
 NULL,200000,'USD',NULL,FALSE,ARRAY[]::TEXT[],
 'https://risepalestine.intersecthub.org/grants/startup-grant/',
 'Hybrid bridge financing described as a mix of grants and SAFE notes, up to USD 200,000 per startup. Applicants are directed to indicate interest in the Startup Grant application. The page lists thresholds involving prior VC financing over USD 100,000, accelerator grant funding of USD 50,000 or more, or monthly revenue below USD 30,000; confirm the exact logical conditions, eligibility, instrument, application status and funding availability with RISE before publication.'
);

CREATE TEMP TABLE _masar_sources (
 slug TEXT NOT NULL REFERENCES _masar_candidates(slug), source_url TEXT NOT NULL,
 source_title TEXT NOT NULL, source_excerpt TEXT NOT NULL, is_official BOOLEAN NOT NULL DEFAULT TRUE,
 PRIMARY KEY (slug,source_url)
) ON COMMIT DROP;

INSERT INTO _masar_sources (slug,source_url,source_title,source_excerpt) VALUES
('rise-palestine-startup-grant-review-2026','https://risepalestine.intersecthub.org/apply-for-support/','RISE Palestine — Apply for Support','Upon raising a minimum threshold of $500,000, RISE Palestine will begin soliciting funding applications from startups and disbursing aid.'),
('rise-palestine-startup-grant-review-2026','https://risepalestine.intersecthub.org/grants/startup-grant/','RISE Palestine — Startup Grant','Grant amounts will be a maximum of $50,000 per startup.'),
('rise-palestine-startup-grant-review-2026','https://risepalestine.intersecthub.org/wp-content/uploads/2026/04/RISE-Palestine_Startup-Grant-Application-Information-.pdf','RISE Palestine — Startup Grant Application Information (official PDF)','The startup has a legally registered organization/company'),
('scale-market-access-matching-grants-review-2026','https://ipsd.ps/content/programs/scale-market-access-matching-grants.html','IPSD II — Scale (Market-Access Matching Grants)','Cost-sharing of up to 80% of eligible expenditures with a maximum ceiling of USD 30,000 per firm. Scale applications are accepted on a rolling basis, subject to funding availability and program requirements. Eligibility includes Palestinian Ministry of National Economy registration, active tax file, at least three months operating, and a verified market opportunity.'),
('start-now-interest-free-financing-review-2026','https://www.pma.ps/start-now-program','Palestine Monetary Authority — Start Now','سقف تمويل يصل إلى 10,000 دولار أمريكي. بدون تكلفة (لا يوجد فوائد). The page describes repayable financing and borrower/project eligibility conditions.'),
('rise-palestine-startup-grant-review-2026','https://risepalestine.intersecthub.org/ar/%D8%B3%D8%A7%D9%87%D9%85/','RISE Palestine Arabic — Contribute / programme funding counter','Official Arabic contribution page has displayed a collected-funding counter of USD 510,000 of USD 3,500,000. This is not proof that the required minimum commitment has been secured; confirm directly.'),
('rise-team-company-stipend-review-2026','https://risepalestine.intersecthub.org/grants/team-grant/','RISE Palestine — TEAM Grant','The page describes emergency relief and emergency-hire stipends for technology companies affected by the war; its English page states up to USD 10,000 per company and a minimum USD 500,000 commitment condition.'),
('rise-team-company-stipend-review-2026','https://risepalestine.intersecthub.org/ar/%D8%B3%D8%A7%D9%87%D9%85/','RISE Palestine Arabic — Contribute / TEAM company stipend','The Arabic programme page describes up to USD 10,000 per month for up to three months, creating an amount-period conflict with the English TEAM page.'),
('rise-team-freelancer-stipend-review-2026','https://risepalestine.intersecthub.org/grants/team-grant/','RISE Palestine — TEAM Grant','The detailed freelancer pathway says applicants operated out of Gaza, have a registered Palestinian bank account, earn primary revenue from technical work, and can evidence unfulfilled contracts; up to USD 1,500 monthly for up to six months.'),
('safe-palestine-bridge-financing-review-2026','https://risepalestine.intersecthub.org/grants/startup-grant/','RISE Palestine — Startup Grant / SAFE Palestine bridge financing','The page describes up to USD 200,000 per eligible startup via a mix of grants and SAFE notes; exact qualification alternatives require human confirmation.');

CREATE TEMP TABLE _masar_criteria (
 slug TEXT NOT NULL REFERENCES _masar_candidates(slug), criterion_key TEXT NOT NULL, label TEXT NOT NULL,
 description TEXT NOT NULL, rule_type TEXT NOT NULL, expected_value JSONB, mandatory BOOLEAN NOT NULL DEFAULT TRUE,
 source_url TEXT NOT NULL, order_index INTEGER NOT NULL, PRIMARY KEY (slug,criterion_key)
) ON COMMIT DROP;

INSERT INTO _masar_criteria
(slug,criterion_key,label,description,rule_type,expected_value,mandatory,source_url,order_index) VALUES
('rise-palestine-startup-grant-review-2026','affected_by_war','Affected by the war on Gaza','Official page describes startups impacted by the war on Gaza; reviewer must assess applicant evidence.','truthy','true'::jsonb,TRUE,'https://risepalestine.intersecthub.org/apply-for-support/',1),
('rise-palestine-startup-grant-review-2026','legally_registered_organization','Legal registration','The linked official application-information PDF refers to a legally registered organization/company. Confirm current wording and any exceptions before using this as an automated rejection rule.','custom_review','"Verify against current official PDF"'::jsonb,TRUE,'https://risepalestine.intersecthub.org/wp-content/uploads/2026/04/RISE-Palestine_Startup-Grant-Application-Information-.pdf',2),
('rise-palestine-startup-grant-review-2026','technology_or_digital_business','Technology or digital business','Verify the exact current technology/digital-product criteria in official application documents; do not infer a pass from a sector label alone.','custom_review','"Verify against current official PDF"'::jsonb,TRUE,'https://risepalestine.intersecthub.org/wp-content/uploads/2026/04/RISE-Palestine_Startup-Grant-Application-Information-.pdf',3),
('scale-market-access-matching-grants-review-2026','palestinian_business_registration','Palestinian business registration','Legally registered with the Palestinian Ministry of National Economy.','truthy','true'::jsonb,TRUE,'https://ipsd.ps/content/programs/scale-market-access-matching-grants.html',1),
('scale-market-access-matching-grants-review-2026','active_tax_file','Active tax file','Applicant has an active tax file with the Palestinian Ministry of Finance.','truthy','true'::jsonb,TRUE,'https://ipsd.ps/content/programs/scale-market-access-matching-grants.html',2),
('scale-market-access-matching-grants-review-2026','months_operational','Operational for at least three months','The business has been operational for at least three months.','gte','3'::jsonb,TRUE,'https://ipsd.ps/content/programs/scale-market-access-matching-grants.html',3),
('scale-market-access-matching-grants-review-2026','annual_revenue_usd','Annual revenue limit (USD)','Annual revenue does not exceed USD 5 million.','lte','5000000'::jsonb,TRUE,'https://ipsd.ps/content/programs/scale-market-access-matching-grants.html',4),
('scale-market-access-matching-grants-review-2026','verified_market_opportunity','Verified market opportunity','Applicant can provide verifiable evidence of a specific market opportunity linked to the requested activity.','truthy','true'::jsonb,TRUE,'https://ipsd.ps/content/programs/scale-market-access-matching-grants.html',5),
('scale-market-access-matching-grants-review-2026','cost_share_available','Required cost-share contribution','Applicant can provide the required cost-share contribution.','truthy','true'::jsonb,TRUE,'https://ipsd.ps/content/programs/scale-market-access-matching-grants.html',6),
('start-now-interest-free-financing-review-2026','borrower_age_years','Borrower age','The official page lists a minimum borrower age of 22.','gte','22'::jsonb,TRUE,'https://www.pma.ps/start-now-program',1),
('start-now-interest-free-financing-review-2026','ownership_percent','Ownership stake','Applicant owns at least 51% of the project.','gte','51'::jsonb,TRUE,'https://www.pma.ps/start-now-program',2),
('start-now-interest-free-financing-review-2026','years_self_managing_project','Years self-managing project','Applicant has managed the project themselves for at least one year.','gte','1'::jsonb,TRUE,'https://www.pma.ps/start-now-program',3),
('start-now-interest-free-financing-review-2026','employee_count','Number of workers','The project has no more than nine workers.','lte','9'::jsonb,TRUE,'https://www.pma.ps/start-now-program',4),
('start-now-interest-free-financing-review-2026','annual_sales_usd','Annual sales limit (USD)','Annual sales do not exceed USD 200,000.','lte','200000'::jsonb,TRUE,'https://www.pma.ps/start-now-program',5),
('start-now-interest-free-financing-review-2026','registered_or_tax_file','Registration or tax file','Project is registered with an official body/institution/association or has a tax file.','truthy','true'::jsonb,TRUE,'https://www.pma.ps/start-now-program',6),
('start-now-interest-free-financing-review-2026','no_overdue_installments','No overdue installments','Borrower has no overdue installments.','truthy','true'::jsonb,TRUE,'https://www.pma.ps/start-now-program',7),
('start-now-interest-free-financing-review-2026','income_covers_installment','Income sufficient for repayment','Monthly project or family income is sufficient to cover the installment.','truthy','true'::jsonb,TRUE,'https://www.pma.ps/start-now-program',8),
('rise-team-company-stipend-review-2026','legal_registration_status','Company legal registration status','Official page permits a registered company or a company in the process of or committed to registration; reviewer confirmation is required.','custom_review','"Review registration evidence and programme wording"'::jsonb,TRUE,'https://risepalestine.intersecthub.org/grants/team-grant/',1),
('rise-team-company-stipend-review-2026','company_technology_services','Technology company activity','Company pathway covers technical consultancy, outsourcing and technology-based services; confirm fit against the current official criteria.','custom_review','"Review company service/activity"'::jsonb,TRUE,'https://risepalestine.intersecthub.org/grants/team-grant/',2),
('rise-team-company-stipend-review-2026','launched_service_and_traction','Launched service and customer traction','Company should evidence a launched product/service with traction and customer validation.','truthy','true'::jsonb,TRUE,'https://risepalestine.intersecthub.org/grants/team-grant/',3),
('rise-team-company-stipend-review-2026','war_impact_evidence','Evidence of impact from the war','Company should evidence how the war affected operations and revenue.','truthy','true'::jsonb,TRUE,'https://risepalestine.intersecthub.org/grants/team-grant/',4),
('rise-team-freelancer-stipend-review-2026','freelancer_operated_location','Freelancer operating location','The detailed criteria specify Gaza, while the overview names Gaza, the West Bank and East Jerusalem. Do not hard-reject by geography until the program confirms the operative rule.','custom_review','"Confirm eligibility geography with RISE"'::jsonb,TRUE,'https://risepalestine.intersecthub.org/grants/team-grant/',1),
('rise-team-freelancer-stipend-review-2026','palestinian_bank_account','Registered bank account in Palestine','The detailed freelancer criteria state that the applicant should have a registered bank account in Palestine.','truthy','true'::jsonb,TRUE,'https://risepalestine.intersecthub.org/grants/team-grant/',2),
('rise-team-freelancer-stipend-review-2026','technical_work_primary_income','Technology work as primary income','Freelancer’s professional work and primary revenue are directly related to technical services/products/platforms/hardware/software/systems.','truthy','true'::jsonb,TRUE,'https://risepalestine.intersecthub.org/grants/team-grant/',3),
('rise-team-freelancer-stipend-review-2026','unfulfilled_contract_evidence','Evidence of unfulfilled contracts','Freelancer can provide evidence of unfulfilled contractual obligations due to the war.','truthy','true'::jsonb,TRUE,'https://risepalestine.intersecthub.org/grants/team-grant/',4),
('safe-palestine-bridge-financing-review-2026','safe_program_eligibility_review','SAFE Palestine financial/traction criteria','Published thresholds are phrased as alternatives and require direct confirmation. Keep this criterion as a human review until the exact logical conditions and instrument are confirmed.','custom_review','"Human review required; verify exact thresholds"'::jsonb,TRUE,'https://risepalestine.intersecthub.org/grants/startup-grant/',1);

CREATE TEMP TABLE _masar_imported (id UUID NOT NULL, slug TEXT PRIMARY KEY) ON COMMIT DROP;

-- Conservative duplicate detection. Existing rows are skipped, never edited/deleted.
WITH added AS (
 INSERT INTO opportunities (
  slug,name,organization,description,support_type,status,eligible_geographies,excluded_geographies,
  sectors,eligible_stages,amount_min,amount_max,currency,deadline,rolling_admissions,
  application_language,official_url,submission_url,official_criteria,last_verified_at
 )
 SELECT c.slug,c.name,c.organization,c.description,c.support_type,'review',c.eligible_geographies,
  c.excluded_geographies,c.sectors,c.eligible_stages,c.amount_min,c.amount_max,c.currency,c.deadline,
  c.rolling_admissions,c.application_language,c.official_url,NULL,c.official_criteria,now()
 FROM _masar_candidates c
 WHERE NOT EXISTS (
  SELECT 1 FROM opportunities o
  WHERE lower(btrim(o.slug))=lower(btrim(c.slug))
   OR lower(btrim(o.name))=lower(btrim(c.name))
   OR (
    NOT EXISTS (
      SELECT 1 FROM _masar_candidates sibling
      WHERE sibling.slug <> c.slug
        AND regexp_replace(lower(sibling.official_url), '/+$', '') =
            regexp_replace(lower(c.official_url), '/+$', '')
    )
    AND regexp_replace(lower(coalesce(o.official_url,'')), '/+$', '') =
        regexp_replace(lower(c.official_url), '/+$', '')
   )
 )
 ON CONFLICT (slug) DO NOTHING
 RETURNING id,slug
)
INSERT INTO _masar_imported (id,slug) SELECT id,slug FROM added;

-- Attach source evidence and criteria only to rows created in this run.
INSERT INTO opportunity_sources (opportunity_id,source_url,source_title,source_excerpt,checked_at,check_method,is_official)
SELECT i.id,s.source_url,s.source_title,s.source_excerpt,now(),'manual_official_source_review_2026-10-17',s.is_official
FROM _masar_imported i JOIN _masar_sources s ON s.slug=i.slug
ON CONFLICT (opportunity_id,source_url) DO NOTHING;

INSERT INTO eligibility_criteria (opportunity_id,criterion_key,label,description,rule_type,expected_value,mandatory,source_id,order_index,is_active)
SELECT i.id,c.criterion_key,c.label,c.description,c.rule_type,c.expected_value,c.mandatory,s.id,c.order_index,TRUE
FROM _masar_imported i
JOIN _masar_criteria c ON c.slug=i.slug
JOIN opportunity_sources s ON s.opportunity_id=i.id
 AND regexp_replace(lower(s.source_url),'/+$','')=regexp_replace(lower(c.source_url),'/+$','')
ON CONFLICT (opportunity_id,criterion_key) DO NOTHING;

INSERT INTO audit_log (actor_user_id,action,entity_type,entity_id,changes)
SELECT NULL,'official_candidate_imported_for_review','opportunity',i.id,
 jsonb_build_object('slug',i.slug,'status','review','import_file','db/imports/official-opportunities-2026-10-17.sql','published',FALSE)
FROM _masar_imported i;

INSERT INTO source_discovery_runs (source_name,completed_at,status,items_discovered,items_changed,metadata)
VALUES (
 'official-funding-candidates-2026-10-17',now(),'completed',
 (SELECT count(*) FROM _masar_candidates),(SELECT count(*) FROM _masar_imported),
 jsonb_build_object('import_file','db/imports/official-opportunities-2026-10-17.sql',
 'inserted_status','review','published',false,'existing_records_modified',0,
 'duplicate_policy','skip by slug, name, official URL or existing source URL',
 'availability_note','Six official-source candidates; current application availability and unresolved source conflicts remain subject to human review.')
);

SELECT (SELECT count(*) FROM _masar_candidates) AS candidates_in_file,
       (SELECT count(*) FROM _masar_imported) AS newly_inserted,
       (SELECT count(*) FROM _masar_candidates)-(SELECT count(*) FROM _masar_imported) AS skipped_as_existing;
SELECT id,slug FROM _masar_imported ORDER BY slug;

COMMIT;
