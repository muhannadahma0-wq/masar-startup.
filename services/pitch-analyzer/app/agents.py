"""Parallel LangGraph pitch-deck review. Twenty roles run as model tasks, not separate trained models."""
from __future__ import annotations
import asyncio, json, operator, os, re
from typing import Annotated, Any, TypedDict
from langgraph.graph import END, START, StateGraph
from langgraph.types import Send
from openai import AsyncOpenAI
from .roles import ROLES
from .schemas import AgentResult, AnalysisReport
MODEL=os.getenv("OPENAI_AGENT_MODEL","gpt-6.1-sol")
SYNTHESIS_MODEL=os.getenv("OPENAI_SYNTHESIS_MODEL","gpt-6-astra")
LIMIT=max(1,int(os.getenv("ANALYSIS_CONCURRENCY","8")))
semaphore=asyncio.Semaphore(LIMIT); client:AsyncOpenAI|None=None
class State(TypedDict,total=False):
    pitch_text:str
    slides_json:str
    startup_name:str
    slide_images:list[str]
    agent_id:str
    agent_name:str
    agent_focus:str
    agent_instructions:str
    results:Annotated[dict[str,dict[str,Any]],operator.or_]
    report:dict[str,Any]
def get_client()->AsyncOpenAI:
    global client
    key=os.getenv("OPENAI_API_KEY","").strip()
    if not key: raise RuntimeError("OPENAI_API_KEY is not configured")
    if client is None: client=AsyncOpenAI(api_key=key)
    return client
def parse_json(text:str)->dict[str,Any]:
    text=re.sub(r"^```(?:json)?\s*|\s*```$","",text.strip(),flags=re.I|re.S)
    try:
        value=json.loads(text);return value if isinstance(value,dict) else {"summary":text}
    except json.JSONDecodeError:
        start,end=text.find("{"),text.rfind("}")
        if start>=0 and end>start:
            try:return json.loads(text[start:end+1])
            except json.JSONDecodeError:pass
        return {"summary":text,"findings":[],"strengths":[],"missing_data":["Could not parse model JSON."]}
def fan_out(state:State)->list[Send]:
    out=[]
    for role in ROLES:
        payload={"agent_id":role.id,"agent_name":role.name_en,"agent_focus":role.focus,"agent_instructions":role.instructions,"pitch_text":state.get("pitch_text",""),"slides_json":state.get("slides_json","[]"),"startup_name":state.get("startup_name","Unnamed startup")}
        if role.id=="slide_visual_review":payload["slide_images"]=state.get("slide_images",[])
        out.append(Send("review",payload))
    return out
async def review(state:State)->dict[str,Any]:
    aid=state.get("agent_id","unknown")
    try:
        role=next(r for r in ROLES if r.id==aid);prompt=(f"Startup: {state.get('startup_name','Unnamed startup')}\nRole: {role.name_en}\nTask: {role.instructions}\n\nReview only the supplied deck. Never invent metrics, market sizes, sources, traction, or facts. Label missing evidence and cite slide/page references. Do not assess formal grant eligibility or predict funding success.\n\nSlides: {state.get('slides_json','[]')[:22000]}\nText: {state.get('pitch_text','')[:22000]}\nReturn JSON keys: summary, score (0-100 or null), strengths, findings (title,severity,details,recommendation,evidence_excerpt,slide_reference,evidence_status), missing_data, limitations.")
        content=[{"type":"input_text","text":prompt}]
        if aid=="slide_visual_review":
            for image_url in state.get("slide_images",[])[:6]:content.append({"type":"input_image","image_url":image_url,"detail":"low"})
        async with semaphore:
            response=await get_client().responses.create(model=MODEL,reasoning={"effort":"medium"},max_output_tokens=1800,text={"format":{"type":"json_object"}},input=[{"role":"system","content":"Analyze startup pitches rigorously. Never add unsupported facts. Return valid JSON only."},{"role":"user","content":content}])
        data=parse_json(response.output_text or "{}");data.setdefault("summary","No summary returned.");data.setdefault("score",None);data.setdefault("strengths",[]);data.setdefault("findings",[]);data.setdefault("missing_data",[]);data.setdefault("limitations",[])
        result=AgentResult(agent_id=aid,agent_name=role.name_en,**{k:data[k] for k in ("status","summary","score","strengths","findings","missing_data","limitations") if k in data})
    except Exception as exc:
        message="Specialist unavailable; check provider configuration and retry."
        if "OPENAI_API_KEY" in str(exc):message="OPENAI_API_KEY is not configured."
        result=AgentResult(agent_id=aid,agent_name=state.get("agent_name",aid),status="error",summary=message,limitations=[type(exc).__name__])
    return {"results":{aid:result.model_dump()}}
async def synthesize(state:State)->dict[str,Any]:
    results=state.get("results",{});complete=[r for r in results.values() if r.get("status")=="completed"]
    try:
        evidence=json.dumps(list(results.values()),ensure_ascii=False)[:50000]
        async with semaphore:
            response=await get_client().responses.create(model=SYNTHESIS_MODEL,reasoning={"effort":"high"},max_output_tokens=5000,text={"format":{"type":"json_object"}},input=[{"role":"system","content":"Synthesize review findings, remove duplicates, never invent facts, and explain missing evidence. A readiness score is not a probability of funding success; human review is required. Return JSON only."},{"role":"user","content":f"Startup: {state.get('startup_name','Unnamed startup')}\nCompleted roles: {len(complete)}/20\nResults: {evidence}\nReturn summary, readiness_score (0-100 or null), score_explanation, strengths, improvement_priorities, rewrite_suggestions, assumptions_to_verify and disclaimer."}])
        data=parse_json(response.output_text or "{}");data["status"]="completed" if len(complete)==20 else "partial";report=AnalysisReport(**data).model_dump()
    except Exception as exc:
        findings=[];strengths=[];scores=[]
        for item in complete:
            strengths.extend(x for x in item.get("strengths",[]) if isinstance(x,str))
            if isinstance(item.get("score"),int):scores.append(item["score"])
            findings.extend(x for x in item.get("findings",[]) if isinstance(x,dict))
        report=AnalysisReport(status="partial",summary="Specialist results are available; synthesis failed, so review them manually.",readiness_score=round(sum(scores)/len(scores)) if scores else None,score_explanation="Mean of available specialist scores, for guidance only.",strengths=list(dict.fromkeys(strengths))[:8],improvement_priorities=findings[:15],assumptions_to_verify=["Review agent outputs because synthesis did not complete."],disclaimer="Partial AI draft; human review required, not investment advice or a funding-success prediction.").model_dump();report["synthesis_error"]=type(exc).__name__
    return {"report":report}
def build_graph():
    graph=StateGraph(State);graph.add_node("review",review);graph.add_node("synthesize",synthesize);graph.add_conditional_edges(START,fan_out,["review"]);graph.add_edge("review","synthesize");graph.add_edge("synthesize",END);return graph.compile()
graph=build_graph()
async def analyze_with_agents(startup_name:str,slides:list[dict[str,Any]],slide_images:list[str])->tuple[AnalysisReport,list[AgentResult]]:
    text="\n\n".join(f"[{s.get('reference','Slide')}]\n{s.get('text','')}" for s in slides)
    if len(text.strip())<30:raise ValueError("Not enough readable text was extracted from this deck.")
    final=await graph.ainvoke({"pitch_text":text[:80000],"slides_json":json.dumps(slides,ensure_ascii=False)[:60000],"startup_name":startup_name,"slide_images":slide_images,"results":{}})
    raw=final.get("results",{});out=[]
    for role in ROLES:out.append(AgentResult(**raw.get(role.id,{"agent_id":role.id,"agent_name":role.name_en,"status":"error","summary":"No result returned."})))
    return AnalysisReport(**final.get("report",{"status":"partial","summary":"No synthesis report returned."})),out
