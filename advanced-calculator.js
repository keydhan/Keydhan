/* KeyDhan Advanced EMI Calculator */
(function(){
 const $=id=>document.getElementById(id);
 const money=value=>"₹"+Number(value).toLocaleString("en-IN",{minimumFractionDigits:2,maximumFractionDigits:2});
 const moneyTrim=value=>"₹"+Number(value).toLocaleString("en-IN",{maximumFractionDigits:2});
 const localToday=()=>{const d=new Date();return new Date(d.getFullYear(),d.getMonth(),d.getDate());};
 const dateText=d=>d.toLocaleDateString("en-IN",{day:"2-digit",month:"short",year:"numeric"});
 const loanType=$("advLoanType"),oldWrap=$("advOldLoanWrap"),oldLoan=$("advOldLoan"),results=$("advResults");
 const toggleOld=()=>{const topup=loanType.value==="topup";oldWrap.hidden=!topup;oldLoan.required=topup;if(!topup)oldLoan.value="";};
 const formatLoanInput=input=>{
  const digits=String(input.value||"").replace(/,/g,"").replace(/[^0-9.]/g,"");
  const parts=digits.split(".");
  const whole=(parts.shift()||"").replace(/^0+(?=\d)/,"");
  const decimal=parts.length?"."+parts.join("").replace(/\./g,""):"";
  input.value=whole?Number(whole).toLocaleString("en-IN")+decimal:(decimal? "0"+decimal:"");
 };
 const stripLeadingZeros=input=>{
  const value=String(input.value||"");
  if(!value)return;
  const normalized=value.replace(/^0+(?=\d)/,"");
  if(normalized!==value)input.value=normalized;
 };
 const advLoanInput=$("advLoan"),pfInput=$("advPf"),insuranceInput=$("advInsurance");
 advLoanInput.addEventListener("input",()=>formatLoanInput(advLoanInput));
 [pfInput,insuranceInput,oldLoan].forEach(input=>input.addEventListener("input",()=>stripLeadingZeros(input)));
 loanType.addEventListener("change",toggleOld);toggleOld();
 const makeRow=(label,value)=>'<div class="advanced-result-row"><span>'+label+'</span><strong>'+value+'</strong></div>';
 let copyText="";
 $("advCalculate").addEventListener("click",()=>{
  const P=Number($("advLoan").value.replace(/,/g,"")),annualRate=Number($("advRate").value);
  let months=Number($("advTenure").value);if($("advTenureUnit").value==="y")months*=12;
  const pfPercent=Number($("advPf").value),insurance=Number($("advInsurance").value);
  const old=loanType.value==="topup"?Number(oldLoan.value):0;
  const fields=[ $("advLoan"),$("advRate"),$("advTenure"),$("advPf"),$("advInsurance"),oldLoan ];
  fields.forEach(f=>f.setCustomValidity(""));
  if(!pfInput.value.trim()){pfInput.setCustomValidity("Enter the Processing Fee / PF percentage.");pfInput.reportValidity();return;}
  if(!insuranceInput.value.trim()){insuranceInput.setCustomValidity("Enter the Insurance Amount. Enter 0 if there is no insurance.");insuranceInput.reportValidity();return;}
  if(!(P>0)){ $("advLoan").setCustomValidity("Enter a loan amount greater than zero.");$("advLoan").reportValidity();return;}
  if(!(annualRate>0)){ $("advRate").setCustomValidity("Enter an annual interest rate greater than zero.");$("advRate").reportValidity();return;}
  if(!(months>0)){ $("advTenure").setCustomValidity("Enter a valid tenure.");$("advTenure").reportValidity();return;}
  if(pfPercent<0||pfPercent>100||insurance<0){alert("Enter PF percentage between 0 and 100, and a non-negative insurance amount.");return;}
  if(loanType.value==="topup"&&!(old>0)){oldLoan.setCustomValidity("Old loan principal amount is mandatory for a Top-up Loan.");oldLoan.reportValidity();return;}
  if(old>P){oldLoan.setCustomValidity("Old loan principal cannot exceed the total loan amount.");oldLoan.reportValidity();return;}
  const r=annualRate/1200;
  const emi=P*r*Math.pow(1+r,months)/(Math.pow(1+r,months)-1);
  const disbursement=localToday();
  let days=0,firstEmi;
  if(disbursement.getDate()<=5) firstEmi=new Date(disbursement.getFullYear(),disbursement.getMonth()+1,5);
  else{
   const cutoff=new Date(disbursement.getFullYear(),disbursement.getMonth()+1,5);
   days=Math.max(0,Math.round((Date.UTC(cutoff.getFullYear(),cutoff.getMonth(),cutoff.getDate())-Date.UTC(disbursement.getFullYear(),disbursement.getMonth(),disbursement.getDate()))/86400000));
   firstEmi=new Date(disbursement.getFullYear(),disbursement.getMonth()+2,5);
  }
  const pf=P*pfPercent/100,gst=pf*.18,pfIncludingGst=pf+gst;
  const preEmi=P*(annualRate/1200)*(days/30),stamp=100;
  const net=P-pfIncludingGst-preEmi-stamp-insurance-old;
  if(net<0){alert("Total deductions exceed the loan amount. Please check PF, insurance and old loan principal.");return;}
  const rows=[
   ["Loan Amount",money(P)],
   ["PF ("+pfPercent.toString()+"% of loan amount)",money(pf)],
   ["PF GST (18%)",money(gst)],
   ["Total PF including GST",money(pfIncludingGst)],
   ["Pre-EMI"+(days?" ("+days+" days)": " (0 days)") ,money(preEmi)],
   ["Stamp Paper",money(stamp)],
   ["Insurance",money(insurance)]
  ];
  if(loanType.value==="topup")rows.push(["Old Loan Principal Amount",money(old)]);
  rows.push(["After Deduction — Final Loan Amount Disbursed",money(net)],["EMI",money(emi)],["First EMI Date",dateText(firstEmi)]);
  $("advNetDisbursed").textContent=money(net);
  $("advResultRows").innerHTML=rows.map(([label,value])=>makeRow(label,value)).join("");
  const moneyWhole=value=>"₹"+Number(value).toLocaleString("en-IN",{maximumFractionDigits:0});
  const copyRows=[
   "Loan amount: "+moneyWhole(P),
   "",
   "Deduction",
   "1. Total PF including GST: "+moneyWhole(pfIncludingGst),
   "2. Pre-EMI: "+moneyTrim(preEmi),
   "3. Stamp paper: "+moneyWhole(stamp),
   "4. Insurance: "+moneyTrim(insurance)
  ];
  if(loanType.value==="topup")copyRows.push("5. Old loan amount (Principal): "+moneyWhole(old));
  copyRows.push(
   "",
   "After deduction final loan amount disbursed: *"+moneyTrim(net)+"*",
   "",
   "EMI: *"+money(emi)+"*",
   "First EMI Date: "+dateText(firstEmi),
   "Tenure: "+months+" months"
  );
  copyText=copyRows.join("\n");
  $("advCopyStatus").textContent="";results.hidden=false;results.scrollIntoView({behavior:"smooth",block:"start"});
 });
 $("advReset").addEventListener("click",()=>{
  ["advLoan","advRate","advTenure","advOldLoan"].forEach(id=>$(id).value="");
  $("advPf").value="";$("advInsurance").value="";$("advTenureUnit").value="m";loanType.value="fresh";toggleOld();results.hidden=true;copyText="";$("advCopyStatus").textContent="";
 });
 $("advCopy").addEventListener("click",async()=>{
  if(!copyText){$("advCopyStatus").textContent="Calculate first, then copy the result.";return;}
  try{
   if(navigator.clipboard&&window.isSecureContext)await navigator.clipboard.writeText(copyText);
   else{
    const area=document.createElement("textarea");area.value=copyText;area.setAttribute("readonly","");area.style.position="fixed";area.style.opacity="0";document.body.appendChild(area);area.select();const ok=document.execCommand("copy");area.remove();if(!ok)throw new Error("Copy failed");
   }
   $("advCopyStatus").textContent="Copied! Paste this message into WhatsApp.";
  }catch(e){$("advCopyStatus").textContent="Copy was blocked by your browser. Please try again or copy manually.";}
 });
})();