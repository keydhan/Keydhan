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
 const prices={"MSME / Udyam Registration":500,"GST Registration":1000,"Trademark Registration":2000,"PAN Application":500};
 const upi="greenindiaearth@upi";
 async function init(){
  // Bind the application flow immediately; CMS content loads separately so a slow API cannot hide or delay Apply.
  const loadContent=async()=>{let content={};try{const r=await fetch(API_URL+"/content",{cache:"no-store"});if(r.ok){const d=await r.json();content=d.content||{};}}catch(e){console.warn("Business Services CMS unavailable; showing defaults.",e);}Object.keys(defaults).forEach(id=>text(id,content[id]||defaults[id]));};
  loadContent();
  const applyButtons=document.querySelectorAll("[data-apply-service]");
  const form=document.getElementById("businessServiceForm"),select=document.getElementById("bsService"),pay=document.getElementById("businessPay"),fields=document.getElementById("businessApplicationFields");
  if(!form||!select)return;
  const fixedService=document.body.dataset.fixedService;
  select.addEventListener("change",()=>{
   const fee=prices[select.value],box=document.getElementById("businessPay");
   if(!fee){box.hidden=true;fields.hidden=true;return;}
   const uri="upi://pay?pa="+upi+"&pn="+encodeURIComponent("KEY DHAN")+"&am="+fee.toFixed(2)+"&cu=INR&tn="+encodeURIComponent("KeyDhan "+select.value);
   document.getElementById("businessFee").textContent="Pay ₹"+fee.toLocaleString("en-IN");
   document.getElementById("businessQr").src="https://api.qrserver.com/v1/create-qr-code/?size=240x240&margin=8&data="+encodeURIComponent(uri);
   document.getElementById("businessUpiLink").href=uri;box.hidden=false;fields.hidden=false;
  });
  if(fixedService&&prices[fixedService]){select.value=fixedService;select.hidden=true;}
  const beginButton=document.getElementById("beginServiceApplication");
  if(beginButton)beginButton.addEventListener("click",()=>{document.getElementById("servicePaymentFlow").hidden=false;select.dispatchEvent(new Event("change"));beginButton.hidden=true;});
  applyButtons.forEach(button=>button.addEventListener("click",()=>{select.value=button.getAttribute("data-apply-service");select.dispatchEvent(new Event("change"));document.getElementById("businessApply").scrollIntoView({behavior:"smooth",block:"start"});}));
  form.addEventListener("submit",async e=>{
   e.preventDefault();
   const status=document.getElementById("businessStatus"),button=form.querySelector("button[type=submit]");
   if(!prices[select.value]){status.textContent="Please select a service.";return;}
   const file=form.elements.paymentScreenshot.files[0];
   if(!file||file.size>5*1024*1024||!["image/jpeg","image/png","image/webp"].includes(file.type)){status.textContent="Please upload a JPG, PNG or WEBP screenshot up to 5 MB.";return;}
   button.disabled=true;button.textContent="Submitting…";status.textContent="Sending your application securely…";
   try{
    const data=new FormData(form);
    const response=await fetch(API_URL+"/business-service-enquiry",{method:"POST",body:data});
    const result=await response.json();
    if(!response.ok||!result.success)throw new Error(result.error||"Submission failed. Please try again.");
    status.textContent=result.message||"Application submitted successfully.";
    form.reset();pay.hidden=true;fields.hidden=true;
   }catch(err){status.textContent=err.message||"Unable to submit. Please try again or contact KeyDhan on WhatsApp.";}
   finally{button.disabled=false;button.innerHTML='Submit Application <span aria-hidden="true">↗</span>';}
  });
 }
 init();
})();