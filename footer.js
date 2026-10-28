/* KeyDhan Common Public Footer — one shared renderer, centrally managed in Admin. */
(function(){
  const mount=document.querySelector('[data-keydhan-footer]');
  let footer=mount?null:document.querySelector('footer.site-footer');
  if(mount){
    mount.innerHTML='<footer class="site-footer" aria-label="KeyDhan website footer">'+
      '<h3 class="footer-brand"><span class="footer-brand-key">Key</span><span class="footer-brand-dhan">Dhan</span><sup class="footer-trademark">™</sup></h3>'+
      '<p class="footer-email"><a href="mailto:hello@keydhan.com" aria-label="Email hello@keydhan.com"><svg class="footer-mail-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><rect x="3" y="5" width="18" height="14" rx="2" fill="none" stroke="currentColor" stroke-width="1.8"/><path d="m4 7 8 6 8-6" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg><span>hello@keydhan.com</span></a></p>'+
      '<p class="footer-copyright"><span>© 2026</span> <span class="footer-copyright-brand"><span class="footer-brand-key">Key</span><span class="footer-brand-dhan">Dhan</span><sup class="footer-trademark">™</sup></span><span class="footer-rights">. All Rights Reserved.</span></p>'+
      '</footer>';
    footer=mount.querySelector('footer.site-footer');
  }
  if(!footer)return;
  const API='https://admin-api.keydhan.com/api';
  const safeHex=value=>/^#[0-9a-f]{6}$/i.test(String(value||''))?String(value).toUpperCase():'';
  const safeUrl=value=>{try{const u=new URL(value);return ['https:','http:'].includes(u.protocol)?u.href:'';}catch{return '';}};
  const setBrand=(selector,value)=>{const el=footer.querySelector(selector);if(el&&typeof value==='string'&&value.trim())el.textContent=value.trim();};
  async function applySettings(){
    try{
      const [settingsResponse,contentResponse]=await Promise.all([
        fetch(API+'/settings',{cache:'no-store',headers:{Accept:'application/json'}}),
        fetch(API+'/content',{cache:'no-store',headers:{Accept:'application/json'}})
      ]);
      const settingsPayload=settingsResponse.ok?await settingsResponse.json():{};
      const contentPayload=contentResponse.ok?await contentResponse.json():{};
      const settings=settingsPayload.settings||{};
      const cfg=(contentPayload.content||{}).footer||{};
      setBrand('.footer-brand-key',cfg.brandKey);
      setBrand('.footer-brand-dhan',cfg.brandDhan);
      const brandDhanColor=safeHex(cfg.brandDhanColor);
      const mainDhan=footer.querySelector('.footer-brand .footer-brand-dhan');
      if(mainDhan&&brandDhanColor)mainDhan.style.color=brandDhanColor;
      const copyrightDhan=footer.querySelector('.footer-copyright-brand .footer-brand-dhan');
      const copyrightDhanColor=safeHex(cfg.copyrightDhanColor);
      if(copyrightDhan&&copyrightDhanColor)copyrightDhan.style.color=copyrightDhanColor;
      const email=footer.querySelector('.footer-email');
      const emailLink=footer.querySelector('.footer-email a');
      const emailText=footer.querySelector('.footer-email a span');
      const configuredEmail=typeof cfg.footerEmail==='string'?cfg.footerEmail.trim():'';
      const emailValue=configuredEmail||(typeof settings.contactEmail==='string'?settings.contactEmail.trim():'');
      if(email&&cfg.showEmail===false)email.hidden=true;
      else if(email&&emailValue&&emailLink&&emailText){
        email.hidden=false;emailText.textContent=emailValue;emailLink.href='mailto:'+emailValue;
        emailLink.setAttribute('aria-label','Email '+emailValue);
      }
      const copyright=footer.querySelector('.footer-copyright');
      if(copyright&&cfg.showCopyright===false)copyright.hidden=true;
      else if(copyright){
        copyright.hidden=false;
        const year=copyright.querySelector(':scope > span:first-child');
        if(year&&cfg.copyrightYear)year.textContent='© '+String(cfg.copyrightYear).replace(/[^0-9]/g,'').slice(0,4);
        const rights=copyright.querySelector('.footer-rights');
        if(rights){const text=typeof cfg.rightsText==='string'&&cfg.rightsText.trim()?cfg.rightsText.trim():'All Rights Reserved.';rights.textContent='. '+text;}
      }
      let social=footer.querySelector('.footer-social-links');
      if(social)social.remove();
      const socials=[['Instagram',cfg.instagram],['Facebook',cfg.facebook],['LinkedIn',cfg.linkedin]]
        .map(([label,url])=>({label,url:safeUrl(url)})).filter(item=>item.url);
      if(socials.length){
        social=document.createElement('nav');social.className='footer-social-links';
        social.setAttribute('aria-label','Social media');
        socials.forEach(item=>{
          const a=document.createElement('a');a.href=item.url;a.textContent=item.label;
          a.target='_blank';a.rel='noopener noreferrer';social.appendChild(a);
        });
        footer.appendChild(social);
      }
    }catch(error){console.warn('KeyDhan footer settings unavailable; showing default common footer.',error);}
  }
  applySettings();
})();
