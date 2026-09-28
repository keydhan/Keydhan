const API="https://admin-api.keydhan.com/api/properties";

let editId=null;

async function render(){

const table=document.getElementById("propertyTable");

table.innerHTML="<tr><td colspan='4'>Loading...</td></tr>";

try{

const res=await fetch(API);

const data=await res.json();

table.innerHTML="";

if(!data.length){
table.innerHTML="<tr><td colspan='4'>No Property</td></tr>";
return;
}

data.forEach(p=>{

table.innerHTML+=`
<tr>
<td>${p.title}</td>
<td>${p.location}</td>
<td>${p.price}</td>
<td>
<button onclick="editProperty(${p.id})">Edit</button>
<button onclick="deleteProperty(${p.id})">Delete</button>
</td>
</tr>`;

});

window.properties=data;

}catch{

table.innerHTML="<tr><td colspan='4'>API Failed</td></tr>";

}

}

async function saveProperty(){

const property={

id:editId,

title:title.value.trim(),

location:location.value.trim(),

price:price.value.trim(),

image:image.value.trim(),

desc:desc.value.trim(),

featured:false

};

const method=editId?"PUT":"POST";

await fetch(API,{
method,
headers:{"Content-Type":"application/json"},
body:JSON.stringify(property)
});

clearForm();

render();

}

function editProperty(id){

const p=properties.find(x=>x.id===id);

editId=id;

title.value=p.title;

location.value=p.location;

price.value=p.price;

image.value=p.image;

desc.value=p.desc;

saveBtn.innerText="Update Property";

window.scrollTo({top:0,behavior:"smooth"});

}

async function deleteProperty(id){

if(!confirm("Delete Property?")) return;

await fetch(API+"?id="+id,{method:"DELETE"});

render();

}

function clearForm(){

editId=null;

title.value="";
location.value="";
price.value="";
image.value="";
desc.value="";
saveBtn.innerText="Save Property";

}

saveBtn.onclick=saveProperty;

render();
