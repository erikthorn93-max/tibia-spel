// Bygger ett kontaktark av valda sprites (uppskalat) så man kan se dem.
const fs=require("fs"),zlib=require("zlib");
const DIR="assets/sprites/items/";
function decode(p){const b=fs.readFileSync(p);let i=8,idat=[];let W,Hh;
  while(i<b.length){const len=b.readUInt32BE(i);const type=b.toString("ascii",i+4,i+8);const data=b.slice(i+8,i+8+len);
    if(type==="IHDR"){W=data.readUInt32BE(0);Hh=data.readUInt32BE(4);} if(type==="IDAT")idat.push(data); if(type==="IEND")break; i+=12+len;}
  const raw=zlib.inflateSync(Buffer.concat(idat));const out=new Uint8Array(W*Hh*4);let p2=0;
  for(let y=0;y<Hh;y++){p2++;for(let x=0;x<W*4;x++)out[y*W*4+x]=raw[p2++];}// filter 0
  return {W,Hh,d:out};}
const crcT=(()=>{const t=[];for(let n=0;n<256;n++){let c=n;for(let k=0;k<8;k++)c=(c&1)?(0xEDB88320^(c>>>1)):(c>>>1);t[n]=c>>>0;}return t;})();
function crc(b){let c=0xFFFFFFFF;for(let i=0;i<b.length;i++)c=crcT[(c^b[i])&0xFF]^(c>>>8);return(c^0xFFFFFFFF)>>>0;}
function chunk(t,d){const l=Buffer.alloc(4);l.writeUInt32BE(d.length,0);const tb=Buffer.from(t);const cc=Buffer.alloc(4);cc.writeUInt32BE(crc(Buffer.concat([tb,d])),0);return Buffer.concat([l,tb,d,cc]);}
function enc(W,Hh,img){const raw=Buffer.alloc((W*4+1)*Hh);let p=0;for(let y=0;y<Hh;y++){raw[p++]=0;for(let x=0;x<W*4;x++)raw[p++]=img[y*W*4+x];}
  const idat=zlib.deflateSync(raw,{level:9});const sig=Buffer.from([137,80,78,71,13,10,26,10]);const ih=Buffer.alloc(13);ih.writeUInt32BE(W,0);ih.writeUInt32BE(Hh,4);ih[8]=8;ih[9]=6;
  return Buffer.concat([sig,chunk("IHDR",ih),chunk("IDAT",idat),chunk("IEND",Buffer.alloc(0))]);}
const ids=["coal","mithril_ore","maple_log","yew_log","mithril_helmet","dragon_sword","runite_shield","yew_bow","magic_arrow","dragon_potion","prayer_potion","overload_potion","armageddon_rune","inferno_rune","blizzard_rune","potato","pumpkin_pie","cooked_kingfish","raw_manta","sunflower_herb","bear_pelt","dragon_bones","blessed_charm","gem_amulet","gem_ring","elder_throne","maple_table","fox_cloak","dragon_legs","mithril_platebody","yew_arrow","frostpetal_herb"];
const COLS=8,SC=4,CELL=32*SC+6,GW=COLS*CELL,GH=Math.ceil(ids.length/COLS)*CELL;
const out=new Uint8Array(GW*GH*4);
for(let i=0;i<GW*GH;i++){out[i*4]=28;out[i*4+1]=26;out[i*4+2]=32;out[i*4+3]=255;}
ids.forEach((id,idx)=>{const col=idx%COLS,row=(idx/COLS)|0;const ox=col*CELL+3,oy=row*CELL+3;
  let s;try{s=decode(DIR+id+".png");}catch(e){return;}
  for(let y=0;y<32;y++)for(let x=0;x<32;x++){const a=s.d[(y*32+x)*4+3];if(a<40)continue;
    for(let sy=0;sy<SC;sy++)for(let sx=0;sx<SC;sx++){const px=ox+x*SC+sx,py=oy+y*SC+sy;const o=(py*GW+px)*4;
      out[o]=s.d[(y*32+x)*4];out[o+1]=s.d[(y*32+x)*4+1];out[o+2]=s.d[(y*32+x)*4+2];out[o+3]=255;}}});
fs.writeFileSync("sprite_preview.png",enc(GW,GH,out));
console.log("skrev sprite_preview.png ("+GW+"x"+GH+", "+ids.length+" ikoner)");
