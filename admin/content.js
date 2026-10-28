const ids=['heroTitle','heroSubtitle','heroButton','heroImage','propertiesTitle','contactTitle','footerText','aboutText','services','seoTitle','seoDescription'];
let currentContent={};
async function load(){try{const d=await api('/admin/content');currentContent=d.content||{};const c=currentContent;ids.forEach(id=>{if($(id))$(id).value=id==='services'?(c.services||[]).join('\n'):(c[id]||'')});hideNotice()}catch(e){showError(e)}}
$('save').onclick=async()=>{const c={...currentContent};ids.forEach(id=>{if($(id))c[id]=id==='services'?$(id).value.split('\n').map(x=>x.trim()).filter(Boolean):$(id).value.trim()});try{await api('/admin/content',{method:'PUT',body:JSON.stringify(c)});currentContent=c;toast('Content saved');hideNotice()}catch(e){showError(e)}};
$('reload').onclick=load;load();
