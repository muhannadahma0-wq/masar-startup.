# Research and Product Decisions

## Design decisions

- Make eligibility evidence-backed and three-state. A single false-eligible answer may mislead a founder into wasting limited time on an application they cannot submit.
- Treat the official source as the authority; search snippets and third-party directories are leads, not proof.
- Separate hard eligibility rules from fit ranking. A relevance score is not a funding-win probability.
- Founder approval is required before proposed slide text or extracted details update the canonical profile.
- Use the LLM for unstructured content review, not the final rule evaluation.
- Use a modest relational schema first. JSONB stores irregular analysis output; criteria, official sources, status, and version history remain queryable columns/tables.

## Reuse policy

External repositories can inform architecture but must not be copied before verifying their current license and dependency licenses. Review any India- or UK/EU-focused funding datasets before adapting them for Palestinian applicants. A dataset or crawler is not proof that opportunities are open to the intended geography.

## Evaluation plan

Build a small human-labelled set of decks and opportunity criteria. Measure extraction coverage, hallucinated or unsupported claims, false-eligible rate, uncertainty calibration, reviewer agreement and application-preparation time. Record source URL, captured excerpt/hash, verification date and reviewer for published opportunities.
