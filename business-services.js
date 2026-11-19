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
 const chooserStyle=document.createElement("style");chooserStyle.textContent="\n.upi-app-chooser{margin:14px auto 4px;max-width:520px;text-align:left}.upi-app-chooser>p{text-align:center;margin:10px 0;color:var(--text)}.upi-app-options{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:9px}.upi-app-options button{display:flex;align-items:center;justify-content:center;min-height:54px;padding:10px 12px;border:1.5px solid rgba(212,175,55,.45);border-radius:12px;color:var(--gold);font-weight:750;background:rgba(212,175,55,.06);cursor:pointer}.upi-app-options button:last-child{grid-column:1/-1}.upi-app-options button.selected{border:2px solid #e3bd36;background:rgba(212,175,55,.24);color:#ffe28a;box-shadow:0 0 0 3px rgba(212,175,55,.16),0 0 18px rgba(212,175,55,.18)}.upi-app-options button.selected:after{content:' ✓';margin-left:7px}.upi-app-chooser small{display:block;text-align:center;margin-top:9px;color:var(--muted)}.upi-continue{display:block;width:100%;margin-top:14px;padding:14px;border:0;border-radius:12px;background:#d7b333;color:#101827;font-weight:850;font-size:16px;cursor:pointer}.upi-continue:disabled{opacity:.45;cursor:not-allowed}\n";document.head.appendChild(chooserStyle);
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
   payLink.href=uri;payLink.textContent="UPI payment link (use if needed)";fields.hidden=true;
   let chooser=document.getElementById("upiAppChooser");
   if(!chooser){
    chooser=document.createElement("div");chooser.id="upiAppChooser";chooser.className="upi-app-chooser";
    chooser.innerHTML='<p><strong>1. Choose your UPI app</strong></p><div class="upi-app-options"><button type="button" data-upi-app="gpay" aria-pressed="false">Google Pay</button><button type="button" data-upi-app="phonepe" aria-pressed="false">PhonePe</button><button type="button" data-upi-app="paytm" aria-pressed="false">Paytm</button><button type="button" data-upi-app="bhim" aria-pressed="false">BHIM</button><button type="button" data-upi-app="other" aria-pressed="false">Other UPI Apps</button></div><small>Tap one app only. Your selection will be highlighted.</small><button type="button" class="upi-continue" hidden>Continue to Pay</button>';
    payLink.insertAdjacentElement("afterend",chooser);
    let selectedApp="";
    chooser.addEventListener("click",event=>{
     const option=event.target.closest("button[data-upi-app]");
     if(option){selectedApp=option.dataset.upiApp;chooser.querySelectorAll("button[data-upi-app]").forEach(btn=>{btn.classList.toggle("selected",btn===option);btn.setAttribute("aria-pressed",btn===option?"true":"false");});const continueButton=chooser.querySelector(".upi-continue");continueButton.hidden=false;continueButton.disabled=false;continueButton.textContent="Continue to Pay with "+option.textContent.trim();return;}
     const next=event.target.closest(".upi-continue");
     if(!next||!selectedApp)return;
     fields.hidden=false;fields.scrollIntoView({behavior:"smooth",block:"start"});
     if(selectedApp==="other"){window.location.href=uri;return;}
     const query=uri.split("?")[1],isAndroid=/Android/i.test(navigator.userAgent);
     if(isAndroid){const packages={gpay:"com.google.android.apps.nbu.paisa.user",phonepe:"com.phonepe.app",paytm:"net.one97.paytm",bhim:"in.org.npci.upiapp"};window.location.href="intent://pay?"+query+"#Intent;scheme=upi;package="+packages[selectedApp]+";action=android.intent.action.VIEW;end";}
     else{const schemes={gpay:"gpay://upi/pay?",phonepe:"phonepe://pay?",paytm:"paytmmp://pay?",bhim:"bhim://upi/pay?"};window.location.href=schemes[selectedApp]+query;}
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