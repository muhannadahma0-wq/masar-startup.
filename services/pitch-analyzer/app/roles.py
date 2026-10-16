"""Twenty bounded specialist roles; these are model tasks, not separate trained models."""
from dataclasses import dataclass
@dataclass(frozen=True)
class AgentRole:
    id: str
    name_en: str
    name_ar: str
    focus: str
    instructions: str
ROLES: tuple[AgentRole,...] = (
 AgentRole("pitch_structure","Pitch Structure Analyst","محلل بنية العرض","structure","Review slide sequence, narrative flow, missing sections, slide density and one clear message per slide."),
 AgentRole("problem_solution","Problem–Solution Analyst","محلل المشكلة والحل","problem_solution","Assess problem specificity, target user, severity, alternatives, solution and fit evidence."),
 AgentRole("value_proposition","Value Proposition Editor","محرر القيمة المقترحة","value_proposition","Review differentiation, clarity, customer benefits and unsupported claims."),
 AgentRole("customer_persona","Customer & Persona Analyst","محلل العملاء","customer","Assess buyer/user distinction, personas, segmentation and willingness-to-pay evidence."),
 AgentRole("market_sizing","Market Sizing Analyst","محلل حجم السوق","market","Review TAM/SAM/SOM logic, assumptions, geography, source dates and calculations. Never invent numbers."),
 AgentRole("competition","Competitive Landscape Analyst","محلل المنافسة","competition","Check alternatives, substitutes, differentiation and sourced comparisons."),
 AgentRole("business_model","Business Model Analyst","محلل نموذج العمل","business_model","Assess who pays, pricing, channels, revenue, key costs and consistency."),
 AgentRole("traction_metrics","Traction & Validation Analyst","محلل النمو والتحقق","traction","Review pilots, users, retention, revenue, LOIs and supporting evidence."),
 AgentRole("financial_model","Financial Model Reviewer","مراجع النموذج المالي","financials","Review budget, cash flow, runway, funding ask and projections. Do not invent figures."),
 AgentRole("unit_economics","Unit Economics Analyst","محلل اقتصاديات الوحدة","unit_economics","Check CAC, LTV, gross margin, payback and data needed to calculate them."),
 AgentRole("team_capabilities","Team & Governance Analyst","محلل الفريق","team","Assess founder experience, role coverage, advisors, hiring gaps and governance details."),
 AgentRole("go_to_market","Go-to-Market Strategist","استراتيجي السوق","gtm","Assess launch sequence, channels, sales cycle, partnerships and measurable next steps."),
 AgentRole("product_technology","Product & Technology Reviewer","مراجع المنتج والتقنية","product_technology","Review product scope, roadmap, feasibility, security risks, milestones and technical claims."),
 AgentRole("digital_presence","Digital Presence Reviewer","مراجع الحضور الرقمي","digital_presence","Review supplied website/social references only and mark external checks unverified."),
 AgentRole("risk_due_diligence","Risk & Due Diligence Analyst","محلل المخاطر","risk","Identify execution, market, regulatory, privacy, security and financial risks from supplied content."),
 AgentRole("claim_evidence","Claim & Evidence Auditor","مدقق الادعاءات","evidence","Map claims to evidence; flag absent, ambiguous, contradictory or unverified support."),
 AgentRole("copy_editor","Pitch Copy Editor","محرر نصوص العرض","copy_editing","Find grammar, repetition, jargon and unclear phrasing without adding facts."),
 AgentRole("slide_visual_review","Slide Visual & Accessibility Reviewer","مراجع التصميم","visual_design","With images, review hierarchy, contrast, density, alignment, charts and accessibility."),
 AgentRole("readiness_assessor","Startup Readiness Assessor","مقيّم الجاهزية","readiness","Summarize gaps across problem, market, model, traction, team and finance; not success probability."),
 AgentRole("funding_alignment","Funding Readiness & Alignment Analyst","محلل جاهزية التمويل","funding_alignment","Review common funding application needs, but never decide formal eligibility or predict success."),
)
assert len(ROLES)==20
