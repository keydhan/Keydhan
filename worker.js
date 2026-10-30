// KeyDhan API v30 — KV-backed CMS. Set KEYDHAN_DB KV binding and ADMIN_API_KEY Worker secret.
const ALLOWED = new Set(["https://keydhan.com","https://www.keydhan.com","https://keydhan-v30-full-admin.keydhan-admin.pages.dev"]);
const cors = origin => ({
  "Access-Control-Allow-Origin": ALLOWED.has(origin) ? origin : "https://keydhan.com",
  "Access-Control-Allow-Methods":"GET,POST,PUT,DELETE,OPTIONS",
  "Access-Control-Allow-Headers":"Content-Type, X-Admin-Key",
  "Access-Control-Max-Age":"86400","Vary":"Origin"
});
const response = (body,status=200,origin="https://keydhan.com") => new Response(JSON.stringify(body),{status,headers:{"Content-Type":"application/json; charset=utf-8","Cache-Control":"no-store",...cors(origin)}});
const stamp=()=>new Date().toISOString();
const str=(v,n=5000)=>String(v??"").trim().slice(0,n);
const keys={properties:"properties",leads:"leads",offers:"loan_offers",settings:"site_settings",content:"site_content"};
async function read(env,key,fallback=[]){const raw=await env.KEYDHAN_DB.get(key);if(!raw)return fallback;const value=JSON.parse(raw);return value;}
async function write(env,key,value){await env.KEYDHAN_DB.put(key,JSON.stringify(value));}
function authorized(req,env){return !!env.ADMIN_API_KEY && req.headers.get("X-Admin-Key")===env.ADMIN_API_KEY;}
function idPath(path,prefix){return decodeURIComponent(path.slice(prefix.length).replace(/^\//,"").split("/")[0]||"");}
function property(b,old={}){return {id:old.id??b.id??crypto.randomUUID(),title:str(b.title??old.title,180),location:str(b.location??old.location,180),price:str(b.price??old.price,80),image:str(b.image??old.image,2000),description:str(b.description??b.desc??old.description??old.desc,5000),type:str(b.type??old.type??"Residential",80),bedrooms:str(b.bedrooms??old.bedrooms,20),bathrooms:str(b.bathrooms??old.bathrooms,20),area:str(b.area??old.area,80),whatsapp:str(b.whatsapp??old.whatsapp,30),mapUrl:str(b.mapUrl??old.mapUrl,2000),featured:(b.featured??old.featured)===true||String(b.featured??old.featured)==="true",status:str(b.status??old.status??"published",20),createdAt:old.createdAt||stamp(),updatedAt:stamp()};}
function offer(b,old={}){return {id:old.id??b.id??crypto.randomUUID(),title:str(b.title??old.title,180),lender:str(b.lender??old.lender,160),loanType:str(b.loanType??old.loanType,100),interestRate:str(b.interestRate??old.interestRate,80),fees:str(b.fees??old.fees,300),eligibility:str(b.eligibility??old.eligibility,1000),validity:str(b.validity??old.validity,80),url:str(b.url??old.url,1000),description:str(b.description??old.description,2000),status:str(b.status??old.status??"draft",20),createdAt:old.createdAt||stamp(),updatedAt:stamp()};}
export default {async fetch(req,env){
 const url=new URL(req.url),path=url.pathname.replace(/\/+$/,"")||"/",method=req.method,origin=req.headers.get("Origin")||"https://keydhan.com";
 if(method==="OPTIONS")return new Response(null,{status:204,headers:cors(origin)});
 if(!env.KEYDHAN_DB)return response({success:false,error:"KEYDHAN_DB KV binding missing"},500,origin);
 try{
  if(path==="/"||path==="/api/health")return response({success:true,service:"KeyDhan API",version:"30",status:"online"},200,origin);
  if(path==="/api/properties"&&method==="GET"){const list=await read(env,keys.properties,[]);return response({success:true,properties:list.filter(p=>(p.status||"published")==="published")},200,origin);}
  if(path==="/api/loan-offers"&&method==="GET"){const list=await read(env,keys.offers,[]);return response({success:true,offers:list.filter(o=>o.status==="published")},200,origin);}
  if(path==="/api/content"&&method==="GET")return response({success:true,content:await read(env,keys.content,{})},200,origin);
  if(path==="/api/settings"&&method==="GET")return response({success:true,settings:await read(env,keys.settings,{businessName:"KeyDhan",contactEmail:"hello@keydhan.com"})},200,origin);
  if(path==="/api/leads"&&method==="POST"){
   const b=await req.json();if(str(b.website,200))return response({success:true},201,origin);
   const name=str(b.name,100),phone=str(b.phone??b.mobile,30),email=str(b.email,150),message=str(b.message,2000);
   if(!name||(!phone&&!email))return response({success:false,error:"Name and phone or email are required"},400,origin);
   const list=await read(env,keys.leads,[]);const item={id:crypto.randomUUID(),name,phone,email,interest:str(b.interest??b.loanType,120),amount:str(b.amount??b.budget,80),city:str(b.city,100),propertyId:str(b.propertyId,100),message,status:"new",createdAt:stamp()};list.unshift(item);await write(env,keys.leads,list);let emailNotification="failed";try{if(env.EMAIL){const esc=v=>String(v??"").replaceAll("&","&amp;").replaceAll("<","&lt;").replaceAll(">","&gt;");const rows=[["Name",item.name],["Phone",item.phone],["Email",item.email],["Enquiry Type",item.interest],["Loan Amount / Budget",item.amount],["City",item.city],["Property ID",item.propertyId],["Message",item.message],["Received At",item.createdAt],["Lead ID",item.id]];const textBody="New customer enquiry received on KeyDhan\n\n"+rows.map(([k,v])=>k+": "+(v||"—")).join("\n");const htmlBody="<h2>New Customer Enquiry – KeyDhan</h2><table>"+rows.map(([k,v])=>"<tr><th>"+esc(k)+"</th><td>"+esc(v||"—")+"</td></tr>").join("")+"</table>";await env.EMAIL.send({from:"hello@keydhan.com",to:"hello@keydhan.com",subject:"New Customer Enquiry – KeyDhan",text:textBody,html:htmlBody});emailNotification="sent";}}catch(emailError){console.error("KeyDhan lead notification email failed",emailError?.message||emailError);}return response({success:true,leadId:item.id,emailNotification},201,origin);
  }
  if(path.startsWith("/api/admin/")){
   if(!authorized(req,env))return response({success:false,error:"Unauthorized: configure ADMIN_API_KEY Worker secret and enter the same key in Admin."},401,origin);
   if(path==="/api/admin/properties"){
    const list=await read(env,keys.properties,[]);
    if(method==="GET")return response({success:true,properties:list},200,origin);
    if(method==="POST"){const b=await req.json();if(!str(b.title,180)||!str(b.location,180)||!str(b.price,80))return response({success:false,error:"Title, location and price are required"},400,origin);const item=property(b);list.unshift(item);await write(env,keys.properties,list);return response({success:true,property:item},201,origin);}
   }
   if(path.startsWith("/api/admin/properties/")){
    const id=idPath(path,"/api/admin/properties"),list=await read(env,keys.properties,[]),i=list.findIndex(p=>String(p.id)===id);
    if(i<0)return response({success:false,error:"Property not found"},404,origin);
    if(method==="PUT"){list[i]=property(await req.json(),list[i]);await write(env,keys.properties,list);return response({success:true,property:list[i]},200,origin);}
    if(method==="DELETE"){list.splice(i,1);await write(env,keys.properties,list);return response({success:true},200,origin);}
   }
   if(path==="/api/admin/leads"){
    const list=await read(env,keys.leads,[]);
    if(method==="GET")return response({success:true,leads:list},200,origin);
    if(method==="PUT"){const b=await req.json(),item=list.find(x=>String(x.id)===String(b.id));if(!item)return response({success:false,error:"Lead not found"},404,origin);item.status=str(b.status||item.status,30);await write(env,keys.leads,list);return response({success:true,lead:item},200,origin);}
    if(method==="DELETE"){const id=url.searchParams.get("id"),next=list.filter(x=>String(x.id)!==id);if(next.length===list.length)return response({success:false,error:"Lead not found"},404,origin);await write(env,keys.leads,next);return response({success:true},200,origin);}
   }
   if(path==="/api/admin/loan-offers"){
    const list=await read(env,keys.offers,[]);
    if(method==="GET")return response({success:true,offers:list},200,origin);
    if(method==="POST"){const b=await req.json();if(!str(b.title,180)||!str(b.lender,160))return response({success:false,error:"Offer title and lender are required"},400,origin);const item=offer(b);list.unshift(item);await write(env,keys.offers,list);return response({success:true,offer:item},201,origin);}
   }
   if(path.startsWith("/api/admin/loan-offers/")){
    const id=idPath(path,"/api/admin/loan-offers"),list=await read(env,keys.offers,[]),i=list.findIndex(o=>String(o.id)===id);
    if(i<0)return response({success:false,error:"Offer not found"},404,origin);
    if(method==="PUT"){list[i]=offer(await req.json(),list[i]);await write(env,keys.offers,list);return response({success:true,offer:list[i]},200,origin);}
    if(method==="DELETE"){list.splice(i,1);await write(env,keys.offers,list);return response({success:true},200,origin);}
   }
   if(path==="/api/admin/settings"){
    const current=await read(env,keys.settings,{});
    if(method==="GET")return response({success:true,settings:current},200,origin);
    if(method==="PUT"){const b=await req.json(),next={businessName:str(b.businessName||"KeyDhan",120),contactEmail:str(b.contactEmail,150),contactPhone:str(b.contactPhone,30),whatsapp:str(b.whatsapp,30),address:str(b.address,300),updatedAt:stamp()};await write(env,keys.settings,next);return response({success:true,settings:next},200,origin);}
   }
   if(path==="/api/admin/content"){
    if(method==="GET")return response({success:true,content:await read(env,keys.content,{})},200,origin);
    if(method==="PUT"){const b=await req.json();if(!b||typeof b!=="object"||Array.isArray(b))return response({success:false,error:"Content must be a JSON object"},400,origin);await write(env,keys.content,b);return response({success:true,content:b},200,origin);}
   }
   if(path==="/api/admin/analytics"&&method==="GET"){
    const [p,l,o]=await Promise.all([read(env,keys.properties,[]),read(env,keys.leads,[]),read(env,keys.offers,[])]);
    return response({success:true,analytics:{totalProperties:p.length,publishedProperties:p.filter(x=>(x.status||"published")==="published").length,featuredProperties:p.filter(x=>x.featured).length,totalLeads:l.length,newLeads:l.filter(x=>x.status==="new").length,totalOffers:o.length,publishedOffers:o.filter(x=>x.status==="published").length}},200,origin);
   }
   return response({success:false,error:"Admin route or method not found"},404,origin);
  }
  return response({success:false,error:"Route not found"},404,origin);
 }catch(error){console.error("KeyDhan API error",error);return response({success:false,error:"Server error. Check Worker logs."},500,origin);}
}};