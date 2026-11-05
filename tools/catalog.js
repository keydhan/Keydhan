(function(){
const grid=document.getElementById('toolGrid'),search=document.getElementById('toolSearch'),filters=document.getElementById('toolFilters'),count=document.getElementById('toolCount'),title=document.getElementById('catalogTitle');
if(!grid||!search||!filters)return;
const cards=[...grid.querySelectorAll('.tool-card')];
const categoryBySlug={
'pdf-to-text':'pdf','image-to-pdf':'pdf','merge-pdf':'pdf','pdf-to-image':'pdf','image-pdf-to-pdf':'pdf','pdf-compressor':'pdf','split-pdf':'pdf','rotate-pdf':'pdf','organize-pdf':'pdf','extract-pdf-pages':'pdf','delete-pdf-pages':'pdf','page-numbers':'pdf','pdf-watermark':'pdf','pdf-to-word':'pdf','word-to-pdf':'pdf','sign-pdf':'pdf','edit-pdf':'pdf',
'image-to-text':'text','image-metadata-remover':'image','jpg-to-png':'image','image-compressor':'image','png-to-jpg':'image','image-to-webp':'image','image-resizer':'image','image-cropper':'image','image-rotator':'image','passport-photo':'image','signature-resizer':'image','ai-background-remover':'image','heic-to-jpg':'image','image-resize-to-kb':'image','photo-signature-forms':'image',
'qr-code-generator':'productivity','password-generator':'productivity','csv-to-excel':'productivity','currency-converter':'productivity','scientific-calculator':'productivity','age-calculator':'productivity','unit-converter':'productivity','percentage-calculator':'productivity','bmi-calculator':'productivity','qr-code-scanner':'productivity','online-timer':'productivity',
'word-counter':'text','text-to-speech':'text','fancy-text-generator':'text','json-formatter':'developer',
'home-loan-affordability':'emi','balance-transfer-calculator':'emi','stamp-duty-calculator':'emi','home-loan-prepayment':'emi','business-loan-emi-calculator':'emi','home-loan-eligibility':'emi'
};
const order=['pdf','image','text','productivity','developer','emi','gst','pan'];
const labels={pdf:'PDF Tools',image:'Image Tools',text:'Text & Writing Tools',productivity:'Productivity Tools',developer:'Developer Tools',emi:'EMI Calculators',gst:'GST Tools',pan:'PAN Tools'};
const groups={};order.forEach(k=>groups[k]=[]);
cards.forEach((card,i)=>{
 const slug=(card.getAttribute('href')||'').split('/').filter(Boolean).pop()||'';
 const cat=card.dataset.category||categoryBySlug[slug]||(/gst-tools/.test(card.href)?'gst':/pan-tools/.test(card.href)?'pan':'pdf');
 card.dataset.category=cat;
 card.dataset.keywords=(card.dataset.keywords||card.innerText+' '+slug).toLowerCase();
 card.dataset.originalOrder=String(i);
 (groups[cat]||(groups[cat]=[])).push(card);
});
const sectionRoot=document.createElement('div');sectionRoot.className='catalog-groups';grid.replaceWith(sectionRoot);
const popular=document.createElement('section');popular.className='catalog-extra popular-section';popular.innerHTML='<div class="catalog-section-head"><div><span class="catalog-kicker">QUICK ACCESS</span><h2>Popular Tools</h2><p>Frequently used tools, ready in one tap</p></div><span class="catalog-section-count">6 PICKS</span></div><div class="popular-links"></div>';
const popularLinks=popular.querySelector('.popular-links');
const popularSlugs=['image-to-pdf','merge-pdf','pdf-to-image','pdf-compressor','image-pdf-to-pdf','qr-code-generator'];
popularSlugs.forEach(slug=>{const card=cards.find(c=>(c.href.split('/').filter(Boolean).pop()||'')===slug);if(card){const a=document.createElement('a');a.href=card.href;a.innerHTML='<span>'+((card.querySelector('.tool-icon')||{}).textContent||'✦')+'</span><strong>'+((card.querySelector('h2')||{}).textContent||'Tool')+'</strong><i>↗</i>';popularLinks.appendChild(a);}});
const recent=document.createElement('section');recent.className='catalog-extra recent-tools';recent.innerHTML='<div class="catalog-section-head"><div><span class="catalog-kicker">FRESH ON KEYDHAN</span><h2>Recently Added</h2><p>Explore the latest additions to the toolbox</p></div><span class="catalog-section-count">NEW</span></div><div class="recent-links"></div>';
const recentLinks=recent.querySelector('.recent-links');
cards.filter(c=>c.classList.contains('new-tool-card')).slice(-8).reverse().forEach(card=>{const a=document.createElement('a');a.href=card.href;a.innerHTML='<span>'+((card.querySelector('.tool-icon')||{}).textContent||'✦')+'</span><strong>'+((card.querySelector('h2')||{}).textContent||'Tool')+'</strong><i>NEW</i>';recentLinks.appendChild(a);});
const originalHeading=document.querySelector('.catalog-heading');
if(originalHeading){originalHeading.after(popular);popular.after(sectionRoot);sectionRoot.after(recent);}else{sectionRoot.before(popular);sectionRoot.after(recent);}
const sectionNodes={};
order.forEach(cat=>{
 const items=groups[cat]||[];if(!items.length)return;
 const section=document.createElement('section');section.className='tool-category-section';section.dataset.group=cat;
 const head=document.createElement('div');head.className='catalog-section-head category-head';
 const left=document.createElement('div');const h=document.createElement('h2');h.textContent=labels[cat]||cat;const p=document.createElement('p');p.textContent=cat==='pdf'?'Convert, organize, compress and manage PDF files':cat==='image'?'Edit, resize and convert images in your browser':cat==='emi'?'Plan home loans, business loans and property costs':'Useful tools for everyday tasks';
 left.append(h,p);const n=document.createElement('span');n.className='catalog-section-count';n.textContent=items.length+' TOOLS';head.append(left,n);
 const list=document.createElement('div');list.className='tool-grid category-grid';items.forEach(c=>list.appendChild(c));section.append(head,list);sectionRoot.append(section);sectionNodes[cat]=section;
});
function apply(){
 const q=search.value.trim().toLowerCase();let visible=0;
 order.forEach(cat=>{const section=sectionNodes[cat];if(!section)return;let groupVisible=0;
 (groups[cat]||[]).forEach(card=>{const ok=(active==='all'||cat===active)&&(!q||card.dataset.keywords.includes(q));card.hidden=!ok;if(ok){visible++;groupVisible++;}});
 section.hidden=groupVisible===0;
 const n=section.querySelector('.catalog-section-count');if(n)n.textContent=groupVisible+' TOOLS';
 });
 count.textContent=visible+' of '+cards.length+' tools';
 if(title)title.textContent=active==='all'?'All Free Tools':(labels[active]||'All Free Tools');
 const showExtras=active==='all'&&!q;popular.hidden=!showExtras;recent.hidden=!showExtras;
}
let active='all';
filters.addEventListener('click',e=>{const b=e.target.closest('button[data-filter]');if(!b)return;active=b.dataset.filter;filters.querySelectorAll('button').forEach(x=>x.classList.toggle('active',x===b));apply();});
search.addEventListener('input',apply);apply();
})();