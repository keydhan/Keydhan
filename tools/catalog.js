(function(){
const grid=document.getElementById('toolGrid'),search=document.getElementById('toolSearch'),filters=document.getElementById('toolFilters'),count=document.getElementById('toolCount');if(!grid||!search||!filters)return;
const cards=[...grid.querySelectorAll('.tool-card')];
const cats={
'image-to-text':'text','qr-code-generator':'productivity','pdf-to-text':'pdf','image-metadata-remover':'image',
'image-to-pdf':'pdf','merge-pdf':'pdf','pdf-to-image':'pdf','jpg-to-png':'image','image-pdf-to-pdf':'pdf','image-compressor':'image','pdf-compressor':'pdf','split-pdf':'pdf','rotate-pdf':'pdf','organize-pdf':'pdf','extract-pdf-pages':'pdf','delete-pdf-pages':'pdf','page-numbers':'pdf','pdf-watermark':'pdf','png-to-jpg':'image','image-to-webp':'image','image-resizer':'image','image-cropper':'image','image-rotator':'image','passport-photo':'image','signature-resizer':'image'
};
cards.forEach(card=>{if(!card.dataset.category){const slug=card.getAttribute('href').split('/').filter(Boolean).pop();card.dataset.category=cats[slug]||'pdf';card.dataset.keywords=(card.innerText+' '+slug).toLowerCase();}});
let active='all';
function apply(){const q=search.value.trim().toLowerCase();let visible=0;cards.forEach(card=>{const ok=(active==='all'||card.dataset.category===active)&&(!q||card.dataset.keywords.includes(q));card.hidden=!ok;if(ok)visible++;});count.textContent=visible+' of '+cards.length+' tools';}
filters.addEventListener('click',e=>{const b=e.target.closest('button[data-filter]');if(!b)return;active=b.dataset.filter;filters.querySelectorAll('button').forEach(x=>x.classList.toggle('active',x===b));apply();});
search.addEventListener('input',apply);apply();
})();