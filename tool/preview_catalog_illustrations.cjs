const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname,'..');
const { Resvg } = require(path.join(root,'build/catalog-media/render/node_modules/@resvg/resvg-js'));
const catalog = JSON.parse(fs.readFileSync(path.join(root,'assets/catalog/illustrations/manifest.json'))).images;
const directory = path.join(root,'build/qa-catalog');
fs.mkdirSync(directory,{recursive:true});
for(let page=0;page<Math.ceil(catalog.length/30);page++) {
  let cells='';
  catalog.slice(page*30,(page+1)*30).forEach((word,index)=>{
    const x=(index%5)*240,y=Math.floor(index/5)*170;
    const source=fs.readFileSync(path.join(root,'assets/catalog/illustration_sources',`${word.id}.svg`),'utf8');
    cells+=source.replace(/<svg\b[^>]*>/,`<svg x="${x}" y="${y}" width="240" height="150" viewBox="0 0 480 300">`);
    cells+=`<text x="${x+120}" y="${y+164}" font-family="Arial" font-size="16" text-anchor="middle" fill="#253B53">${word.english}</text>`;
  });
  const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="1020"><rect width="1200" height="1020" fill="#FFFFFF"/>${cells}</svg>`;
  fs.writeFileSync(path.join(directory,`contact-${String(page+1).padStart(2,'0')}.png`),new Resvg(svg).render().asPng());
}
console.log(`${catalog.length} images in ${Math.ceil(catalog.length/30)} contact sheets`);
