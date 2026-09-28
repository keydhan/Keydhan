const KEY="keydhan_properties";

function getData(){
  return JSON.parse(localStorage.getItem(KEY)||"[]");
}

function saveData(data){
  localStorage.setItem(KEY,JSON.stringify(data));
}

function render(){
  const table=document.getElementById("propertyTable");
  if(!table)return;

  table.innerHTML="";

  getData().forEach(p=>{
    table.innerHTML+=`
      <tr>
        <td>${p.title}</td>
        <td>${p.location}</td>
        <td>${p.price}</td>
      </tr>`;
  });
}

const btn=document.getElementById("saveBtn");

if(btn){
  btn.onclick=()=>{
    const data=getData();

    data.push({
      title:document.getElementById("title").value,
      location:document.getElementById("location").value,
      price:document.getElementById("price").value,
      image:document.getElementById("image").value,
      desc:document.getElementById("desc").value
    });

    saveData(data);

    document.getElementById("title").value="";
    document.getElementById("location").value="";
    document.getElementById("price").value="";
    document.getElementById("image").value="";
    document.getElementById("desc").value="";

    render();
  };
}

render();
