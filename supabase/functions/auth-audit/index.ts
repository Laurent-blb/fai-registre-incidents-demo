import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type, x-auth-audit-secret"};
Deno.serve(async req=>{
  if(req.method==='OPTIONS') return new Response('ok',{headers:cors});
  const secret=Deno.env.get('AUTH_AUDIT_SECRET');
  if(!secret || req.headers.get('x-auth-audit-secret')!==secret) return new Response('Unauthorized',{status:401,headers:cors});
  const body=await req.json().catch(()=>({}));
  const supabase=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const {error}=await supabase.from('security_events').insert({event_type:body.event_type||'login_failed',email:body.email||null,user_id:body.user_id||null,ip_address:body.ip_address||null,user_agent:body.user_agent||null,metadata:body.metadata||{}});
  if(error)return new Response(JSON.stringify({error:error.message}),{status:400,headers:{...cors,'Content-Type':'application/json'}});
  return new Response(JSON.stringify({ok:true}),{headers:{...cors,'Content-Type':'application/json'}});
});
