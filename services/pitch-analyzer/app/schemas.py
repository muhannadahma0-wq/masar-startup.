from typing import Literal
from pydantic import BaseModel, Field

class Finding(BaseModel):
    title: str
    severity: Literal["critical", "high", "medium", "low", "info"] = "medium"
    details: str
    recommendation: str = ""
    evidence_excerpt: str | None = None
    slide_reference: str | None = None
    evidence_status: Literal["supported", "partial", "missing", "unverified", "contradictory"] = "unverified"

class AgentResult(BaseModel):
    agent_id: str
    agent_name: str
    status: Literal["completed", "unavailable", "error"] = "completed"
    summary: str = ""
    score: int | None = Field(default=None, ge=0, le=100)
    strengths: list[str] = Field(default_factory=list)
    findings: list[Finding] = Field(default_factory=list)
    missing_data: list[str] = Field(default_factory=list)
    limitations: list[str] = Field(default_factory=list)

class RewriteSuggestion(BaseModel):
    slide_reference: str | None = None
    original_excerpt: str | None = None
    suggested_text: str
    rationale: str
    requires_founder_input: list[str] = Field(default_factory=list)

class AnalysisReport(BaseModel):
    title: str = "Masar Startup — Pitch Analysis"
    status: Literal["completed", "partial"]
    summary: str
    readiness_score: int | None = Field(default=None, ge=0, le=100)
    score_explanation: str = ""
    strengths: list[str] = Field(default_factory=list)
    improvement_priorities: list[Finding] = Field(default_factory=list)
    rewrite_suggestions: list[RewriteSuggestion] = Field(default_factory=list)
    assumptions_to_verify: list[str] = Field(default_factory=list)
    human_review_required: bool = True
    disclaimer: str = "AI-generated draft for founder review; not investment advice or a prediction of funding success."

class AnalysisResponse(BaseModel):
    analysis_id: str
    startup_name: str
    filename: str
    page_count: int
    report: AnalysisReport
    agent_results: list[AgentResult]
    architecture: dict[str, str]
