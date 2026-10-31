/* Shared KeyDhan mobile navigation for Free Tools pages. */
(function(){
 const header=document.querySelector('body > header');
 if(header && header.dataset.kdMenuReady==='true') return;
 const btn=document.getElementById('menuBtn');
 const menu=document.getElementById('menu');
 if(!btn||!menu||btn.dataset.kdMenuBound==='true')return;
 let backdrop=document.querySelector('.mobile-menu-backdrop');
 if(!backdrop){backdrop=document.createElement('div');backdrop.className='mobile-menu-backdrop';backdrop.setAttribute('aria-hidden','true');document.body.appendChild(backdrop);}
 const close=()=>{menu.classList.remove('show');backdrop.classList.remove('show');btn.setAttribute('aria-expanded','false');btn.setAttribute('aria-label','Open navigation menu');document.body.classList.remove('menu-open');};
 const open=()=>{menu.classList.add('show');backdrop.classList.add('show');btn.setAttribute('aria-expanded','true');btn.setAttribute('aria-label','Close navigation menu');document.body.classList.add('menu-open');};
 btn.addEventListener('click',e=>{e.preventDefault();e.stopPropagation();menu.classList.contains('show')?close():open();});
 backdrop.addEventListener('click',close);
 menu.addEventListener('click',e=>{if(e.target.closest('a'))close();});
 document.addEventListener('keydown',e=>{if(e.key==='Escape')close();});
 document.addEventListener('click',e=>{if(menu.classList.contains('show')&&!menu.contains(e.target)&&!btn.contains(e.target))close();});
 window.addEventListener('resize',()=>{if(window.innerWidth>768)close();});
})();