const businessIds=['businessName','contactEmail','contactPhone','whatsapp','address'];
const footerIds=['footerBrandKey','footerBrandDhan','footerCopyrightYear','footerRightsText','footerInstagram','footerFacebook','footerLinkedIn'];
const footerDefaults={brandKey:'Key',brandDhan:'Dhan',copyrightYear:'2026',rightsText:'All Rights Reserved.',showEmail:true,showCopyright:true,instagram:'',facebook:'',linkedin:''};
let loadedSettings={};
let loadedContent={};
function putFooter(f={}){
 const v={...footerDefaults,...f};
 $('footerBrandKey').value=v.brandKey;
 $('footerBrandDhan').value=v.brandDhan;
 $('footerCopyrightYear').value=v.copyrightYear;
 $('footerRightsText').value=v.rightsText;
 $('footerInstagram').value=v.instagram||'';
 $('footerFacebook').value=v.facebook||'';
 $('footerLinkedIn').value=v.linkedin||'';
 $('footerShowEmail').checked=v.showEmail!==false;
 $('footerShowCopyright').checked=v.showCopyright!==false;
}
function readFooter(){
 return {
  brandKey:$('footerBrandKey').value.trim()||'Key',
  brandDhan:$('footerBrandDhan').value.trim()||'Dhan',
  copyrightYear:$('footerCopyrightYear').value.trim()||String(new Date().getFullYear()),
  rightsText:$('footerRightsText').value.trim()||'All Rights Reserved.',
  showEmail:$('footerShowEmail').checked,
  showCopyright:$('footerShowCopyright').checked,
  instagram:$('footerInstagram').value.trim(),
  facebook:$('footerFacebook').value.trim(),
  linkedin:$('footerLinkedIn').value.trim()
 };
}
async function load(){
 try{
  const d=await api('/admin/settings');
  loadedSettings=d.settings||{};
  businessIds.forEach(id=>$(id).value=loadedSettings[id]||'');
  const contentData=await api('/admin/content');
  loadedContent=contentData.content||{};
  putFooter(loadedContent.footer||{});
  hideNotice();
 }catch(e){showError(e)}
}
$('settingsForm').onsubmit=async e=>{
 e.preventDefault();
 const s={...loadedSettings};
 businessIds.forEach(id=>s[id]=$(id).value.trim());
 s.footer=readFooter();
 try{
  await api('/admin/settings',{method:'PUT',body:JSON.stringify(s)});
  loadedSettings=s;toast('Settings saved');hideNotice();
 }catch(e){showError(e)}
};
$('footerForm').onsubmit=async e=>{
 e.preventDefault();
 const btn=$('saveFooter');btn.disabled=true;
 const c={...loadedContent,footer:readFooter()};
 try{
  await api('/admin/content',{method:'PUT',body:JSON.stringify(c)});
  loadedContent=c;toast('Footer settings saved and published');hideNotice();
 }catch(e){showError(e)}
 finally{btn.disabled=false}
};
$('reload').onclick=load;
$('reloadFooter').onclick=load;
load();
