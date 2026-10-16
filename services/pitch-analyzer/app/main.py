from __future__ import annotations
import asyncio, hmac, os
from uuid import uuid4
from fastapi import Depends, FastAPI, File, Form, Header, HTTPException, UploadFile
from fastapi.responses import JSONResponse
from .extract import extract_deck
from .schemas import AnalysisResponse
from .agents import analyze_with_agents
app=FastAPI(title="Masar Startup Pitch Analyzer",version="0.1.0",docs_url="/docs",redoc_url=None)
MAX_FILE_BYTES=int(os.getenv("MAX_FILE_SIZE_MB","20"))*1024*1024
SERVICE_TOKEN=os.getenv("PITCH_SERVICE_TOKEN","").strip()
async def validate_internal_token(authorization:str|None=Header(default=None))->None:
    if not SERVICE_TOKEN:
        if os.getenv("NODE_ENV")=="production":raise HTTPException(status_code=503,detail="PITCH_SERVICE_TOKEN must be configured in production")
        return
    supplied=(authorization or "").removeprefix("Bearer ").strip()
    if not hmac.compare_digest(supplied,SERVICE_TOKEN):raise HTTPException(status_code=401,detail="Unauthorized internal service request")
@app.get("/health")
async def health():return {"ok":True,"service":"masar-pitch-analyzer","agent_roles":20,"framework":"LangGraph"}
@app.post("/internal/analyze",response_model=AnalysisResponse,dependencies=[Depends(validate_internal_token)])
async def analyze(file:UploadFile=File(...),startup_name:str=Form(default="Unnamed startup")):
    filename=(file.filename or "").strip();extension=filename.lower().rsplit(".",1)[-1] if "." in filename else ""
    allowed={"pdf":{"application/pdf","application/octet-stream"},"pptx":{"application/vnd.openxmlformats-officedocument.presentationml.presentation","application/octet-stream"}}
    if extension not in allowed:raise HTTPException(status_code=415,detail="Only PDF and PPTX files are supported.")
    if file.content_type not in allowed[extension]:raise HTTPException(status_code=415,detail="File extension and content type do not match.")
    raw=await file.read(MAX_FILE_BYTES+1)
    if len(raw)>MAX_FILE_BYTES:raise HTTPException(status_code=413,detail=f"Maximum upload size is {MAX_FILE_BYTES//(1024*1024)} MB.")
    if not raw:raise HTTPException(status_code=400,detail="Uploaded file is empty.")
    if not os.getenv("OPENAI_API_KEY"):raise HTTPException(status_code=503,detail="OPENAI_API_KEY is not configured; AI analysis is unavailable.")
    try:slides,images=await asyncio.to_thread(extract_deck,filename,raw)
    except ValueError as exc:raise HTTPException(status_code=422,detail=str(exc)) from exc
    except Exception as exc:raise HTTPException(status_code=422,detail=f"Could not read the uploaded document: {type(exc).__name__}") from exc
    report,agents=await analyze_with_agents(startup_name[:120],slides,images)
    payload=AnalysisResponse(analysis_id=str(uuid4()),startup_name=startup_name[:120],filename=filename,page_count=len(slides),report=report,agent_results=agents,architecture={"orchestrator":"LangGraph fan-out and synthesis","parallelism":f"20 roles; up to {max(1,int(os.getenv('ANALYSIS_CONCURRENCY','8')))} provider calls at once","agent_model":os.getenv("OPENAI_AGENT_MODEL","gpt-6.1-sol"),"synthesis_model":os.getenv("OPENAI_SYNTHESIS_MODEL","gpt-6-astra"),"visual_review":"Rendered PDF pages when available; PPTX text and layout hints"})
    return JSONResponse(content=payload.model_dump(mode="json"))
