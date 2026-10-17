import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import multer from 'multer';
import { z } from 'zod';
import { Pool } from 'pg';
import { evaluateEligibility, EvaluationInputSchema } from './eligibility.js';
const app = express();
const port = Number(process.env.PORT || 4000);
const maxFileBytes = Number(process.env.MAX_FILE_SIZE_MB || 20) * 1024 * 1024;
const pitchServiceUrl = process.env.PITCH_ANALYZER_URL || 'http://127.0.0.1:8000/internal/analyze';
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: maxFileBytes, files: 1 } });
const pool = process.env.DATABASE_URL ? new Pool({ connectionString: process.env.DATABASE_URL, max: 8, idleTimeoutMillis: 30_000, connectionTimeoutMillis: 5_000, ssl: process.env.DATABASE_SSL === 'true' ? { rejectUnauthorized: true } : undefined }) : null;
const supabaseUrl = process.env.SUPABASE_URL?.trim();
const supabasePublishableKey = process.env.SUPABASE_PUBLISHABLE_KEY;
const supabaseRestConfigured = Boolean(supabaseUrl && supabasePublishableKey);

function getSupabaseHeaders(): Record<string, string> {
  if (!supabasePublishableKey) throw new Error('Supabase publishable key is not configured');
  return {
    apikey: supabasePublishableKey,
  };
}

async function fetchPublishedOpportunities(): Promise<unknown[]> {
  if (!supabaseUrl || !supabasePublishableKey) throw new Error('Supabase REST is not configured');
  const url = new URL('/rest/v1/opportunities', supabaseUrl);
  url.searchParams.set('select', 'id,name,organization,description,type:support_type,amount_min,amount_max,currency,deadline,sourceUrl:official_url,lastVerifiedAt:last_verified_at');
  url.searchParams.set('status', 'eq.published');
  url.searchParams.set('approved_at', 'not.is.null');
  url.searchParams.set('order', 'deadline.asc.nullsfirst');
  url.searchParams.set('limit', '200');
  const response = await fetch(url, {
    headers: getSupabaseHeaders(),
    signal: AbortSignal.timeout(5_000),
  });
  if (!response.ok) throw new Error(`Supabase REST returned HTTP ${response.status}`);
  return await response.json() as unknown[];
}

async function checkSupabaseRest(): Promise<boolean> {
  if (!supabaseUrl || !supabasePublishableKey) return false;
  try {
    const url = new URL('/rest/v1/opportunities', supabaseUrl);
    url.searchParams.set('select', 'id');
    url.searchParams.set('limit', '1');
    const response = await fetch(url, {
      headers: getSupabaseHeaders(),
      signal: AbortSignal.timeout(5_000),
    });
    return response.ok;
  } catch {
    return false;
  }
}

type AuthCheck = 'valid' | 'invalid' | 'unavailable';

async function validateSupabaseAccessToken(authorization: string | undefined): Promise<AuthCheck> {
  if (!supabaseUrl || !supabasePublishableKey) return 'unavailable';
  if (!authorization?.startsWith('Bearer ') || authorization.length < 16) return 'invalid';
  try {
    const response = await fetch(new URL('/auth/v1/user', supabaseUrl), {
      headers: {
        apikey: supabasePublishableKey,
        authorization,
      },
      signal: AbortSignal.timeout(5_000),
    });
    if (response.status === 401 || response.status === 403) return 'invalid';
    if (!response.ok) return 'unavailable';
    const user = await response.json() as { id?: unknown };
    return typeof user.id === 'string' && user.id.length > 0 ? 'valid' : 'invalid';
  } catch {
    return 'unavailable';
  }
}

const requireSupabaseAuth: express.RequestHandler = (req, res, next) => {
  void (async () => {
    if (!supabaseRestConfigured) {
      res.status(503).json({ error: 'AUTH_NOT_CONFIGURED' });
      return;
    }
    const result = await validateSupabaseAccessToken(req.get('authorization'));
    if (result === 'invalid') {
      res.status(401).json({ error: 'AUTHENTICATION_REQUIRED' });
      return;
    }
    if (result === 'unavailable') {
      res.status(503).json({ error: 'AUTH_SERVICE_UNAVAILABLE' });
      return;
    }
    next();
  })().catch(next);
};
const allowedOrigins = (process.env.WEB_ORIGIN || 'http://localhost:5173').split(',').map(x => x.trim());
app.disable('x-powered-by');
app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
app.use(cors({ origin: allowedOrigins, credentials: false, methods: ['GET', 'POST', 'OPTIONS'] }));
app.use(express.json({ limit: '1mb' }));
const demoOpportunities = [
 { id:'op1', name:'Local Innovation Grant', organization:'Example development fund', type:'grant', status:'illustrative', sourceUrl:null, lastVerifiedAt:null },
 { id:'op2', name:'Regional Startup Lab', organization:'Example accelerator network', type:'accelerator', status:'illustrative', sourceUrl:null, lastVerifiedAt:null },
 { id:'op3', name:'Impact Founders Program', organization:'Example social impact hub', type:'incubator', status:'illustrative', sourceUrl:null, lastVerifiedAt:null },
 { id:'op4', name:'Future Solutions Challenge', organization:'Example innovation challenge', type:'competition', status:'illustrative', sourceUrl:null, lastVerifiedAt:null },
];
app.get('/', (_req, res) => res.json({ ok:true, service:'masar-api', status:'prototype', health:'/health' }));
app.get('/health', async (_req, res) => {
  let database = 'not_configured';
  if (pool) {
    try {
      await pool.query('SELECT 1');
      database = 'connected';
    } catch {
      database = 'unavailable';
    }
  } else if (supabaseRestConfigured) {
    database = await checkSupabaseRest() ? 'connected' : 'unavailable';
  }
  res.json({ ok: true, service: 'masar-api', status: 'prototype', database });
});
app.get('/api/opportunities', async (_req, res) => {
  if (pool) {
    try {
      const result = await pool.query(`SELECT id, name, organization, description, support_type AS type, amount_min, amount_max, currency, deadline, official_url AS "sourceUrl", last_verified_at AS "lastVerifiedAt" FROM opportunities WHERE status = 'published' AND approved_at IS NOT NULL ORDER BY deadline ASC NULLS LAST LIMIT 200`);
      return res.json({ items: result.rows, mode: 'database', disclaimer: 'Published records should be backed by reviewed official sources.' });
    } catch (err) {
      console.error('Opportunity query failed', err);
      return res.status(503).json({ error: 'OPPORTUNITY_DATABASE_UNAVAILABLE' });
    }
  }

  if (supabaseRestConfigured) {
    try {
      const items = await fetchPublishedOpportunities();
      return res.json({ items, mode: 'database', disclaimer: 'Published records should be backed by reviewed official sources.' });
    } catch (err) {
      console.error('Supabase opportunity query failed', err);
      return res.status(503).json({ error: 'OPPORTUNITY_DATABASE_UNAVAILABLE' });
    }
  }

  if (process.env.NODE_ENV === 'production') {
    return res.status(503).json({ error: 'OPPORTUNITY_DATABASE_NOT_CONFIGURED' });
  }
  return res.json({ items: demoOpportunities, mode: 'demo', disclaimer: 'Illustrative records only. Replace with reviewed official-source records before production.' });
});
app.post('/api/eligibility/evaluate',(req,res)=>{const parsed=EvaluationInputSchema.safeParse(req.body);if(!parsed.success)return res.status(400).json({error:'INVALID_EVALUATION_INPUT',details:parsed.error.flatten()});return res.json(evaluateEligibility(parsed.data));});
const AnalyzeFieldsSchema = z.object({ startup_name: z.string().trim().min(1).max(120).default('Unnamed startup') });
app.post('/api/pitch-analyses',requireSupabaseAuth,upload.single('file'),async(req,res)=>{
 if(!req.file)return res.status(400).json({error:'FILE_REQUIRED',message:'Upload a PDF or PPTX file.'});
 const ext=req.file.originalname.toLowerCase().split('.').pop();const allowedMime=new Set(['application/pdf','application/vnd.openxmlformats-officedocument.presentationml.presentation']);
 if(!['pdf','pptx'].includes(ext||'')||!allowedMime.has(req.file.mimetype))return res.status(415).json({error:'UNSUPPORTED_FILE_TYPE',message:'Only PDF and PPTX are supported.'});
 const fields=AnalyzeFieldsSchema.safeParse({startup_name:req.body.startup_name||'Unnamed startup'});if(!fields.success)return res.status(400).json({error:'INVALID_STARTUP_NAME'});
 try{const form=new FormData();form.append('file',new Blob([new Uint8Array(req.file.buffer)],{type:req.file.mimetype}),req.file.originalname);form.append('startup_name',fields.data.startup_name);const headers:Record<string,string>={};if(process.env.PITCH_SERVICE_TOKEN)headers.authorization=`Bearer ${process.env.PITCH_SERVICE_TOKEN}`;const response=await fetch(pitchServiceUrl,{method:'POST',headers,body:form,signal:AbortSignal.timeout(180_000)});const body=await response.json().catch(()=>({error:'INVALID_PITCH_SERVICE_RESPONSE'}));return res.status(response.status).json(body);}catch(error){const message=error instanceof Error?error.message:'Unknown error';return res.status(503).json({error:'PITCH_ANALYZER_UNAVAILABLE',message:'The pitch analysis service is not available. Check PITCH_ANALYZER_URL and service logs.',diagnostic:process.env.NODE_ENV==='production'?undefined:message});}
});
app.use((err:unknown,_req:express.Request,res:express.Response,_next:express.NextFunction)=>{if(err instanceof multer.MulterError&&err.code==='LIMIT_FILE_SIZE')return res.status(413).json({error:'FILE_TOO_LARGE',maxFileSizeMB:Number(process.env.MAX_FILE_SIZE_MB||20)});console.error('Unhandled API error',err);return res.status(500).json({error:'INTERNAL_SERVER_ERROR'});});
app.listen(port,'0.0.0.0',()=>console.log(`Masar API listening on http://0.0.0.0:${port}`));
