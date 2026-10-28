/* KeyDhan Standard Footer — settings are centrally managed in Admin. */
(async function(){
  const footer=document.querySelector('footer.site-footer');
  if(!footer)return;
  const API='https://admin-api.keydhan.com/api';
  const setText=(selector,value)=>{const el=footer.querySelector(selector);if(el&&typeof value==='string')el.textContent=value;};
  const safeUrl=value=>{try{const u=new URL(value);return ['https:','http:'].includes(u.protocol)?u.href:'';}catch{return '';}};
  try{
    const [settingsResponse,contentResponse]=await Promise.all([fetch(API+'/settings',{cache:'no-store',headers:{Accept:'application/json'}}),fetch(API+'/content',{cache:'no-store',headers:{Accept:'application/json'}})]);
    const settingsPayload=settingsResponse.ok?await settingsResponse.json():{};
    const contentPayload=contentResponse.ok?await contentResponse.json():{};
    const settings=settingsPayload.settings||{};
    const cfg=(contentPayload.content||{}).footer||{};
    const key=footer.querySelector('.footer-brand-key');
    const dhan=footer.querySelector('.footer-brand-dhan');
    if(key&&typeof cfg.brandKey==='string'&&cfg.brandKey.trim())key.textContent=cfg.brandKey.trim();
    if(dhan&&typeof cfg.brandDhan==='string'&&cfg.brandDhan.trim())dhan.textContent=cfg.brandDhan.trim();
    const email=footer.querySelector('.footer-email');
    const emailLink=footer.querySelector('.footer-email a');
    const emailText=footer.querySelector('.footer-email a span');
    const emailValue=typeof settings.contactEmail==='string'?settings.contactEmail.trim():'';
    if(email&&cfg.showEmail===false)email.hidden=true;
    else if(email&&emailValue&&emailLink&&emailText){email.hidden=false;emailText.textContent=emailValue;emailLink.href='mailto:'+emailValue;emailLink.setAttribute('aria-label','Email '+emailValue);}
    const copyright=footer.querySelector('.footer-copyright');
    if(copyright&&cfg.showCopyright===false)copyright.hidden=true;
    else if(copyright){
      copyright.hidden=false;
      const year=copyright.querySelector(':scope > span:first-child');
      if(year&&cfg.copyrightYear)year.textContent='© '+String(cfg.copyrightYear).replace(/[^0-9]/g,'').slice(0,4);
      const rights=copyright.querySelector('.footer-rights');
      if(rights){const rightsText=typeof cfg.rightsText==='string'&&cfg.rightsText.trim()?cfg.rightsText.trim():'All Rights Reserved.';rights.textContent='. '+rightsText;}
    }
    const socials=[['Instagram',cfg.instagram],['Facebook',cfg.facebook],['LinkedIn',cfg.linkedin]].map(([label,url])=>({label,url:safeUrl(url)})).filter(x=>x.url);
    let social=footer.querySelector('.footer-social-links');
    if(social)social.remove();
    if(socials.length){
      social=document.createElement('nav');social.className='footer-social-links';social.setAttribute('aria-label','Social media');
      socials.forEach(item=>{const a=document.createElement('a');a.href=item.url;a.textContent=item.label;a.target='_blank';a.rel='noopener noreferrer';social.appendChild(a);});
      footer.appendChild(social);
    }
  }catch(error){console.warn('Footer settings unavailable; keeping built-in footer.',error);}
})();