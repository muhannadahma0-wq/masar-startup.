import { z } from 'zod';

export const CriterionSchema = z.object({
  key: z.string().min(1), label: z.string().min(1), mandatory: z.boolean().default(true),
  operator: z.enum(['equals', 'includes', 'gte', 'lte', 'truthy']),
  expected: z.union([z.string(), z.number(), z.boolean(), z.array(z.string())]).optional(),
  sourceUrl: z.string().url().optional(), sourceExcerpt: z.string().max(1000).optional(),
});
export const EvaluationInputSchema = z.object({ startup: z.record(z.string(), z.unknown()), criteria: z.array(CriterionSchema).min(1).max(100) });
export type Criterion = z.infer<typeof CriterionSchema>;
export type EvaluationInput = z.infer<typeof EvaluationInputSchema>;
export type CriterionResult = { key: string; label: string; status: 'PASS' | 'FAIL' | 'UNKNOWN'; mandatory: boolean; reason: string; sourceUrl?: string };
export type EligibilityStatus = 'ELIGIBLE' | 'NOT_ELIGIBLE' | 'UNCERTAIN';
function compare(actual: unknown, criterion: Criterion): boolean | null {
  if (actual === undefined || actual === null || actual === '') return null;
  switch (criterion.operator) {
    case 'equals': return String(actual).trim().toLowerCase() === String(criterion.expected ?? '').trim().toLowerCase();
    case 'includes': {
      const allowed = Array.isArray(criterion.expected) ? criterion.expected : [criterion.expected].filter((x): x is string => typeof x === 'string');
      if (Array.isArray(actual)) return actual.some(v => allowed.includes(String(v)));
      return allowed.some(v => String(actual).toLowerCase().includes(v.toLowerCase()));
    }
    case 'gte': return Number.isFinite(Number(actual)) && Number(actual) >= Number(criterion.expected);
    case 'lte': return Number.isFinite(Number(actual)) && Number(actual) <= Number(criterion.expected);
    case 'truthy': return Boolean(actual);
    default: return null;
  }
}
/** Deterministic, explainable eligibility. A fit score never overrides these results. */
export function evaluateEligibility(input: EvaluationInput): { status: EligibilityStatus; results: CriterionResult[]; passed: number; failed: number; unknown: number } {
  const results = input.criteria.map((criterion): CriterionResult => {
    const compared = compare(input.startup[criterion.key], criterion);
    const status = compared === true ? 'PASS' : compared === false ? 'FAIL' : 'UNKNOWN';
    const reason = status === 'PASS' ? `The supplied value for ${criterion.label} satisfies the configured rule.` : status === 'FAIL' ? `The supplied value for ${criterion.label} does not satisfy the configured rule.` : `Insufficient or missing data to determine ${criterion.label}.`;
    return { key: criterion.key, label: criterion.label, status, mandatory: criterion.mandatory, reason, ...(criterion.sourceUrl ? { sourceUrl: criterion.sourceUrl } : {}) };
  });
  const mandatoryFail = results.some(r => r.mandatory && r.status === 'FAIL');
  const mandatoryUnknown = results.some(r => r.mandatory && r.status === 'UNKNOWN');
  const status: EligibilityStatus = mandatoryFail ? 'NOT_ELIGIBLE' : mandatoryUnknown ? 'UNCERTAIN' : 'ELIGIBLE';
  return { status, results, passed: results.filter(r => r.status === 'PASS').length, failed: results.filter(r => r.status === 'FAIL').length, unknown: results.filter(r => r.status === 'UNKNOWN').length };
}
