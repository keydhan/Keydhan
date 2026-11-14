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
 const SERVICE_NAMES={"msme-udyam":"MSME / Udyam Registration","gst-registration":"GST Registration","trademark-registration":"Trademark Registration","pan-registration":"PAN Registration"};
 const text=(id,value)=>{const el=document.getElementById(id);if(el&&typeof value==="string"&&value.trim())el.textContent=value;};
 const WHATSAPP_BASE="https://wa.me/keydhan";
 async function init(){
  let content={};
  try{const cr=await fetch(API_URL+"/content",{cache:"no-store"});if(cr.ok){const d=await cr.json();content=d.content||{};}}catch(e){console.warn("Business Services CMS unavailable; showing defaults.",e);}
  Object.keys(defaults).forEach(id=>text(id,content[id]||defaults[id]));
  document.querySelectorAll("[data-enquire-service]").forEach(link=>{const service=link.getAttribute("data-enquire-service");link.href=WHATSAPP_BASE+"?text="+encodeURIComponent("Hello KeyDhan, I would like to enquire about "+service+". Please share the process, eligibility, documents and applicable charges.");link.target="_blank";link.rel="noopener noreferrer";});
 }
 function loadCheckout(){return new Promise((resolve,reject)=>{if(window.Razorpay){resolve();return;}const s=document.createElement("script");s.src="https://checkout.razorpay.com/v1/checkout.js";s.onload=()=>resolve();s.onerror=()=>reject(new Error("Payment checkout could not be loaded"));document.head.appendChild(s);});}
 async function startPayment(service,link){
  if(link.dataset.busy==="1")return;link.dataset.busy="1";const old=link.textContent;link.textContent="Please wait…";
  try{
   await loadCheckout();
   const orderRes=await fetch(API_URL+"/payments/razorpay/order",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({service})});
   const order=await orderRes.json();if(!orderRes.ok||!order.success)throw new Error(order.error||"Unable to start payment");
   const checkout=new Razorpay({key:order.keyId,amount:order.amount,currency:order.currency,name:"KeyDhan",description:SERVICE_NAMES[service],order_id:order.orderId,theme:{color:"#d4af37"},modal:{ondismiss:function(){link.dataset.busy="0";link.textContent=old;}},handler:async function(result){
    try{const verifyRes=await fetch(API_URL+"/payments/razorpay/verify",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify(result)});const verified=await verifyRes.json();if(!verifyRes.ok||!verified.success||!verified.verified)throw new Error(verified.error||"Payment verification failed");alert("Payment successful! Your "+SERVICE_NAMES[service]+" payment has been verified. KeyDhan will contact you for the next steps.");}
    catch(error){alert("Payment received, but verification is pending. Please contact hello@keydhan.com with your payment ID: "+(result.razorpay_payment_id||""));console.error(error);}
    finally{link.dataset.busy="0";link.textContent=old;}
   }});
   checkout.on("payment.failed",function(){alert("Payment was not completed. Please try again.");link.dataset.busy="0";link.textContent=old;});
   checkout.open();
  }catch(error){alert(error.message||"Unable to start payment. Please try again.");link.dataset.busy="0";link.textContent=old;console.error(error);}
 }
 document.addEventListener("click",event=>{const pay=event.target.closest("[data-pay-service]");if(pay){event.preventDefault();startPayment(pay.getAttribute("data-pay-service"),pay);return;}});
 init();
})();