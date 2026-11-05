(function(){
const grid=document.getElementById('toolGrid'),search=document.getElementById('toolSearch'),filters=document.getElementById('toolFilters'),count=document.getElementById('toolCount'),title=document.getElementById('catalogTitle');if(!grid||!search||!filters)return;
const cards=[...grid.querySelectorAll('.tool-card')];
const cats={
'image-to-text':'text','qr-code-generator':'productivity','pdf-to-text':'pdf','image-metadata-remover':'image',
'image-to-pdf':'pdf','merge-pdf':'pdf','pdf-to-image':'pdf','jpg-to-png':'image','image-pdf-to-pdf':'pdf','image-compressor':'image','pdf-compressor':'pdf','split-pdf':'pdf','rotate-pdf':'pdf','organize-pdf':'pdf','extract-pdf-pages':'pdf','delete-pdf-pages':'pdf','page-numbers':'pdf','pdf-watermark':'pdf','png-to-jpg':'image','image-to-webp':'image','image-resizer':'image','image-cropper':'image','image-rotator':'image','passport-photo':'image','signature-resizer':'image',
'image-to-text':'text','qr-code-generator':'productivity','pdf-to-text':'pdf','image-metadata-remover':'image',
'pdf-to-word':'pdf','word-to-pdf':'pdf','sign-pdf':'pdf','edit-pdf':'pdf','word-counter':'text','password-generator':'productivity','json-formatter':'developer','csv-to-excel':'productivity','image-resize-to-kb':'image','photo-signature-forms':'image','currency-converter':'productivity','text-to-speech':'text','scientific-calculator':'productivity','age-calculator':'productivity','unit-converter':'productivity','percentage-calculator':'productivity','bmi-calculator':'productivity','qr-code-scanner':'productivity','fancy-text-generator':'text','online-timer':'productivity'
};
cards.forEach(card=>{if(!card.dataset.category){const slug=card.getAttribute('href').split('/').filter(Boolean).pop();card.dataset.category=cats[slug]||'pdf';card.dataset.keywords=(card.innerText+' '+slug).toLowerCase();}});
const priority={pdf:0,image:1,text:2,productivity:3,developer:4,emi:5,gst:6,pan:7};
cards.sort((a,b)=>(priority[a.dataset.category]??99)-(priority[b.dataset.category]??99));
cards.forEach(card=>grid.appendChild(card));
let active='all';
function apply(){const q=search.value.trim().toLowerCase();let visible=0;cards.forEach(card=>{const ok=(active==='all'||card.dataset.category===active)&&(!q||card.dataset.keywords.includes(q));card.hidden=!ok;if(ok)visible++;});count.textContent=visible+' of '+cards.length+' tools';if(title)title.textContent=active==='all'?'All Free Tools':(filters.querySelector('button[data-filter="'+active+'"]')?.textContent||'All Free Tools');}
filters.addEventListener('click',e=>{const b=e.target.closest('button[data-filter]');if(!b)return;active=b.dataset.filter;filters.querySelectorAll('button').forEach(x=>x.classList.toggle('active',x===b));apply();});
search.addEventListener('input',apply);apply();
})();