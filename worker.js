export default {
  async fetch(request, env) {

    const cors = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type"
    };

    if(request.method==="OPTIONS"){
      return new Response(null,{status:204,headers:cors});
    }

    const url=new URL(request.url);

    if(url.pathname==="/api/properties"){

      let properties=JSON.parse(await env.KEYDHAN_DB.get("properties")||"[]");

      if(request.method==="GET"){
        return Response.json(properties,{headers:cors});
      }

      if(request.method==="POST"){
        const body=await request.json();

        body.id=Date.now();

        properties.unshift(body);

        await env.KEYDHAN_DB.put("properties",JSON.stringify(properties));

        return Response.json({success:true,id:body.id},{headers:cors});
      }

      if(request.method==="PUT"){
        const body=await request.json();

        properties=properties.map(p=>p.id===body.id?body:p);

        await env.KEYDHAN_DB.put("properties",JSON.stringify(properties));

        return Response.json({success:true},{headers:cors});
      }

      if(request.method==="DELETE"){
        const id=Number(url.searchParams.get("id"));

        properties=properties.filter(p=>p.id!==id);

        await env.KEYDHAN_DB.put("properties",JSON.stringify(properties));

        return Response.json({success:true},{headers:cors});
      }

    }

    return Response.json({success:false},{status:404,headers:cors});

  }
}
