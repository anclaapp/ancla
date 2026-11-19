const V='ancla-v3';const SHELL=['./','./index.html','./manifest.webmanifest','./icon.svg'];
self.addEventListener('install',e=>{e.waitUntil(caches.open(V).then(c=>c.addAll(SHELL)).then(()=>self.skipWaiting()));});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==V&&k!=='ancla-share').map(k=>caches.delete(k)))).then(()=>self.clients.claim()));});
self.addEventListener('fetch',e=>{
  const r=e.request,u=new URL(r.url);
  if(r.method==='POST'&&u.pathname.endsWith('/share-target')){
    e.respondWith((async()=>{
      const fd=await r.formData();const c=await caches.open('ancla-share');let i=0;
      for(const f of fd.getAll('media')){if(f&&f.size){await c.put(new URL('./shared/'+Date.now()+'-'+(i++),self.registration.scope).href,new Response(f,{headers:{'Content-Type':f.type||'application/octet-stream'}}));}}
      const text=[fd.get('title'),fd.get('text'),fd.get('url')].filter(Boolean).join('\n');
      if(text){await c.put(new URL('./shared/t-'+Date.now(),self.registration.scope).href,new Response(text,{headers:{'Content-Type':'text/plain'}}));}
      return Response.redirect(new URL('./?shared=1',self.registration.scope).href,303);
    })());return;
  }
  if(r.method!=='GET')return;
  e.respondWith(caches.match(r).then(h=>h||fetch(r).then(res=>{if(res.ok&&u.origin===location.origin){const cp=res.clone();caches.open(V).then(c=>c.put(r,cp));}return res;}).catch(()=>caches.match('./index.html'))));
});
