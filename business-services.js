(function(){
 const API_URL="https://admin-api.keydhan.com/api";
 const defaults={
  businessServicesTitle:"Business Services for Your Next Move",
  businessServicesIntro:"Understand registrations that can help you formalise your business, meet applicable requirements and protect your brand.",
  businessMsmeDescription:"Information and guidance for eligible micro, small and medium enterprises.",
  businessMsmeWhy:"Udyam registration can help eligible businesses access applicable MSME schemes and benefits.",
  businessMsmeDocuments:"Aadhaar and PAN details are commonly required; exact requirements depend on the applicant and official process.",
  businessGstDescription:"Guidance on GST registration, eligibility and the application process.",
  businessGstWhy:"GST registration may be required depending on turnover, business activity and applicable rules.",
  businessGstDocuments:"PAN, business address and identity/contact details may be required. Requirements vary by business structure.",
  businessTrademarkDescription:"Guidance on applying to protect your business name, brand identity or logo.",
  businessTrademarkWhy:"A registered trademark can provide legal protection for the mark in its registered classes, subject to law.",
  businessTrademarkDocuments:"Brand/logo details, applicant information and the relevant goods/services classes may be needed."
 };
 const text=(id,value)=>{const el=document.getElementById(id);if(el&&typeof value==="string"&&value.trim())el.textContent=value;};
 function whatsappNumber(value){let n=String(value||"").replace(/\D/g,"");if(n.length===10)n="91"+n;return n;}
 async function init(){
  let content={},settings={};
  try{const [cr,sr]=await Promise.all([fetch(API_URL+"/content",{cache:"no-store"}),fetch(API_URL+"/settings",{cache:"no-store"})]);if(cr.ok){const d=await cr.json();content=d.content||{};}if(sr.ok){const d=await sr.json();settings=d.settings||{};}}catch(e){console.warn("Business Services CMS unavailable; showing defaults.",e);}
  Object.keys(defaults).forEach(id=>text(id,content[id]||defaults[id]));
  const number=whatsappNumber(settings.whatsapp);
  document.querySelectorAll("[data-service]").forEach(link=>{
   const service=link.getAttribute("data-service");
   if(number){const message="Hello KeyDhan, I would like to enquire about "+service+". Please share the process, eligibility, documents and applicable charges.";link.href="https://wa.me/"+number+"?text="+encodeURIComponent(message);link.target="_blank";}
   else{link.href="/contact.html";link.removeAttribute("target");link.title="Please configure the WhatsApp number in Admin Settings to enable direct WhatsApp enquiries.";}
  });
 }
 init();
})();