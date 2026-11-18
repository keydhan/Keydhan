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
 const chooserStyle=document.createElement("style");chooserStyle.textContent="\n  .upi-app-chooser{margin:14px auto 4px;max-width:520px;text-align:left}.upi-app-chooser>p{text-align:center;margin:10px 0;color:var(--text)}.upi-app-options{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:9px}.upi-app-options a{display:flex;align-items:center;justify-content:center;min-height:44px;padding:9px 12px;border:1px solid rgba(212,175,55,.45);border-radius:10px;color:var(--gold);font-weight:750;text-decoration:none;background:rgba(212,175,55,.06)}.upi-app-options a:last-child{grid-column:1/-1}.upi-app-options a:focus,.upi-app-options a:hover{background:rgba(212,175,55,.16)}.upi-app-chooser small{display:block;text-align:center;margin-top:9px;color:var(--muted)}\n";document.head.appendChild(chooserStyle);
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
   const payLink=document.getElementById("businessUpiLink");
   payLink.href=uri;payLink.textContent="Choose UPI App to Pay";
   let chooser=document.getElementById("upiAppChooser");
   if(!chooser){
    chooser=document.createElement("div");chooser.id="upiAppChooser";chooser.className="upi-app-chooser";
    chooser.innerHTML='<p><strong>Choose your UPI app</strong></p><div class="upi-app-options"><a data-upi-app="gpay">Google Pay</a><a data-upi-app="phonepe">PhonePe</a><a data-upi-app="paytm">Paytm</a><a data-upi-app="bhim">BHIM</a><a data-upi-app="other">Other UPI Apps</a></div><small>Select an app installed on your phone. If an app is not installed, choose another option.</small>';
    payLink.insertAdjacentElement("afterend",chooser);
    const packages={gpay:"com.google.android.apps.nbu.paisa.user",phonepe:"com.phonepe.app",paytm:"net.one97.paytm",bhim:"in.org.npci.upiapp"};
    chooser.addEventListener("click",event=>{
     const link=event.target.closest("a[data-upi-app]");if(!link)return;
     event.preventDefault();const app=link.dataset.upiApp;
     if(app==="other"){window.location.href=uri;return;}
     const intent="intent://pay?"+uri.split("?")[1]+"#Intent;scheme=upi;package="+packages[app]+";action=android.intent.action.VIEW;end";
     window.location.href=intent;
    });
   }
   box.hidden=false;fields.hidden=false;
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