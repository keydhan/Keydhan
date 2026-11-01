(function(){
 const API_URL="https://admin-api.keydhan.com/api";
 const SERVICE_NAMES={"msme-udyam":"MSME / Udyam Registration","gst-registration":"GST Registration","trademark-registration":"Trademark Registration","pan-registration":"PAN Registration"};
 let checkoutReady=false;
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
 document.addEventListener("click",event=>{const link=event.target.closest("[data-pay-service]");if(!link)return;event.preventDefault();startPayment(link.getAttribute("data-pay-service"),link);});
})();