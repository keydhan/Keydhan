function saveProperty(){

const title=document.getElementById("title").value;
const price=document.getElementById("price").value;
const location=document.getElementById("location").value;
const bhk=document.getElementById("bhk").value;
const description=document.getElementById("description").value;
const featured=document.getElementById("featured").checked;
const image=document.getElementById("image").value;

let properties=JSON.parse(localStorage.getItem("kd_properties")||"[]");

properties.unshift({

id:Date.now(),
title,
price,
location,
bhk,
description,
image,
featured

});

localStorage.setItem("kd_properties",JSON.stringify(properties));

alert("Property saved successfully.");

document.getElementById("propertyForm").reset();

}

function loadLocalProperties(){

const list=document.getElementById("propertyList");

if(!list) return;

const properties=JSON.parse(localStorage.getItem("kd_properties")||"[]");

list.innerHTML="";

properties.forEach(p=>{

list.innerHTML+=`

<div style="background:#071323;padding:18px;border-radius:18px;margin-bottom:15px">

<h3>${p.title}</h3>

<p>${p.price}</p>

<p>${p.location}</p>

<button onclick="deleteProperty(${p.id})">Delete</button>

</div>

`;

});

}

function deleteProperty(id){

let properties=JSON.parse(localStorage.getItem("kd_properties")||"[]");

properties=properties.filter(p=>p.id!==id);

localStorage.setItem("kd_properties",JSON.stringify(properties));

loadLocalProperties();

}

document.addEventListener("DOMContentLoaded",loadLocalProperties);
