(function(){
const $=id=>document.getElementById(id);
const start=$('startTest'),share=$('shareResult'),status=$('speedStatus');
const endpoint='https://speed.cloudflare.com';
let latest=null;
const setStatus=(s)=>{status.textContent=s;};
const setPhase=s=>{$('speedPhase').textContent=s;};
const timeoutSignal=ms=>{const c=new AbortController(),t=setTimeout(()=>c.abort(),ms);return {signal:c.signal,clear:()=>clearTimeout(t)};};
async function pingTest(){
 const samples=[];
 for(let i=0;i<8;i++){
  const t=performance.now(),q=timeoutSignal(8000);
  try{const r=await fetch(endpoint+'/__down?bytes=0&cacheBust='+Math.random(),{cache:'no-store',signal:q.signal});if(!r.ok)throw Error('Ping request failed');await r.arrayBuffer();samples.push(performance.now()-t);}finally{q.clear();}
 }
 const avg=samples.reduce((a,b)=>a+b,0)/samples.length;
 const jitter=samples.slice(1).reduce((a,b,i)=>a+Math.abs(b-samples[i]),0)/(samples.length-1);
 return {ping:avg,jitter};
}
async function downloadTest(){
 const sizes=[1000000,5000000,10000000],rates=[];
 for(const bytes of sizes){
  const t=performance.now(),q=timeoutSignal(25000);
  try{const r=await fetch(endpoint+'/__down?bytes='+bytes+'&cacheBust='+Math.random(),{cache:'no-store',signal:q.signal});if(!r.ok)throw Error('Download test request failed');const data=await r.arrayBuffer();const sec=(performance.now()-t)/1000;if(data.byteLength>0&&sec>0)rates.push(data.byteLength*8/sec/1000000);}finally{q.clear();}
 }
 if(!rates.length)throw Error('Could not measure download speed.');
 return rates[rates.length-1];
}
async function uploadTest(){
 const bytes=2000000,data=new Blob([new Uint8Array(bytes)],{type:'text/plain'});
 const t=performance.now(),q=timeoutSignal(25000);
 try{const r=await fetch(endpoint+'/__up?cacheBust='+Math.random(),{method:'POST',body:data,cache:'no-store',signal:q.signal});if(!r.ok)throw Error('Upload test request failed');await r.arrayBuffer();const sec=(performance.now()-t)/1000;if(sec<=0)throw Error('Upload timing failed.');return bytes*8/sec/1000000;}finally{q.clear();}
}
function fmt(n){return Number(n).toFixed(1);}
start.addEventListener('click',async()=>{
 start.disabled=true;share.disabled=true;latest=null;
 $('speedValue').textContent='--';$('pingValue').textContent='--';$('downloadValue').textContent='--';$('uploadValue').textContent='--';$('jitterValue').textContent='-- ms';
 try{
  setPhase('PING TEST');setStatus('Measuring response time…');
  const p=await pingTest();$('pingValue').textContent=fmt(p.ping);$('jitterValue').textContent=fmt(p.jitter)+' ms';
  setPhase('DOWNLOAD');setStatus('Measuring download speed…');
  const down=await downloadTest();$('downloadValue').textContent=fmt(down);$('speedValue').textContent=fmt(down);
  setPhase('UPLOAD');setStatus('Measuring upload speed…');
  const up=await uploadTest();$('uploadValue').textContent=fmt(up);$('speedValue').textContent=fmt(down);
  latest={ping:fmt(p.ping),jitter:fmt(p.jitter),download:fmt(down),upload:fmt(up),date:new Date().toLocaleString()};
  setPhase('TEST COMPLETE');setStatus('Speed test completed. Results are estimates for this connection at this time.');share.disabled=false;
 }catch(e){
  setPhase('TEST INCOMPLETE');setStatus((e.name==='AbortError'?'The speed test timed out. ':'Speed test could not complete. ')+(e.message||'Check your connection and try again.'));
 }finally{start.disabled=false;start.textContent='↻ Test Again';}
});
share.addEventListener('click',async()=>{
 if(!latest)return;
 const msg='My Internet Speed Test – KeyDhan\nPing: '+latest.ping+' ms\nJitter: '+latest.jitter+' ms\nDownload: '+latest.download+' Mbps\nUpload: '+latest.upload+' Mbps\nTested: '+latest.date+'\nhttps://keydhan.com/tools/internet-speed-test/';
 if(navigator.share){try{await navigator.share({title:'KeyDhan Internet Speed Test',text:msg});}catch(e){if(e.name!=='AbortError')setStatus('Unable to share this result.');}}
 else{try{await navigator.clipboard.writeText(msg);setStatus('Result copied. You can paste it into WhatsApp or another app.');}catch(e){setStatus('Sharing is not supported by this browser.');}}
});
})();