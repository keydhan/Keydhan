const API='/admin/api';const $=id=>document.getElementById(id);const KEY_SLOT='keydhan_admin_api_key';const key=()=>sessionStorage.getItem(KEY_SLOT)||'';function setKey(){const value=prompt('Enter the Admin API Key configured as ADMIN_API_KEY in the Cloudflare Worker.');if(value===null)return;if(!value.trim()){sessionStorage.removeItem(KEY_SLOT);toast('API key cleared for this tab.');return;}sessionStorage.setItem(KEY_SLOT,value.trim());toast('API key saved for this tab. Reloading data…');if(typeof window.reloadAdminData==='function')window.reloadAdminData();else location.reload()} $('apiKeyButton')?.addEventListener('click',setKey);async function api(path,options={}){const headers={'Accept':'application/json','X-Admin-Key':key(),...(options.body?{'Content-Type':'application/json'}:{}),...(options.headers||{})};const r=await fetch(API+path,{...options,headers,cache:'no-store'});let d;try{d=await r.json()}catch{throw Error('API returned invalid JSON (HTTP '+r.status+')')}if(!r.ok||d.success===false)throw Error(d.error||'Request failed (HTTP '+r.status+')');return d}function esc(s){return String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}function toast(s){const n=document.createElement('div');n.className='toast';n.textContent=s;document.body.append(n);setTimeout(()=>n.remove(),2600)}function showError(e){const n=$('notice');if(n){n.classList.remove('hidden');n.textContent=e.message||String(e)}console.error(e)}function hideNotice(){const n=$('notice');if(n)n.classList.add('hidden')}

// Accessible mobile navigation toggle
document.querySelectorAll('.mobile-nav-toggle').forEach(button=>{
  button.addEventListener('click',()=>{
    const nav=document.getElementById(button.getAttribute('aria-controls'));
    if(!nav)return;
    const open=button.getAttribute('aria-expanded')!=='true';
    button.setAttribute('aria-expanded',String(open));
    nav.classList.toggle('nav-open',open);
    const label=button.querySelector('.menu-label');
    if(label)label.textContent=open?'Close menu':'Menu';
    const icon=button.querySelector('.menu-icon');
    if(icon)icon.textContent=open?'×':'☰';
  });
});
document.querySelectorAll('.nav a').forEach(link=>link.addEventListener('click',()=>{
  const nav=link.closest('.nav');const button=document.querySelector('.mobile-nav-toggle');
  if(nav&&button&&window.matchMedia('(max-width: 800px)').matches){nav.classList.remove('nav-open');button.setAttribute('aria-expanded','false');const label=button.querySelector('.menu-label');if(label)label.textContent='Menu';const icon=button.querySelector('.menu-icon');if(icon)icon.textContent='☰';}
}));
