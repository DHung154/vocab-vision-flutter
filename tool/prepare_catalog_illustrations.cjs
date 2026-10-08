// Reproducible educational compositions from OpenMoji 16.0.0 + original SVGs.
// npm install --prefix build/catalog-media/render openmoji@16.0.0 @resvg/resvg-js@2.6.2
// dart run tool/export_catalog.dart
// node tool/prepare_catalog_illustrations.cjs
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const modules = path.join(root, 'build/catalog-media/render/node_modules');
const { Resvg } = require(path.join(modules, '@resvg/resvg-js'));
const openmoji = path.join(modules, 'openmoji');
const catalog = JSON.parse(fs.readFileSync(path.join(root, 'build/catalog-media/catalog.json')));
const metadata = JSON.parse(fs.readFileSync(path.join(openmoji, 'data/openmoji.json')));
const normalize = value => value.replaceAll('\uFE0F', '');
const emojiMap = new Map(metadata.map(item => [normalize(item.emoji), item]));
const output = path.join(root, 'assets/catalog/illustrations');
const sources = path.join(root, 'assets/catalog/illustration_sources');
fs.mkdirSync(output, { recursive: true });
fs.mkdirSync(sources, { recursive: true });
const ink = '#253B53', blue = '#3286D9', mint = '#61C9B4', gold = '#F6C84E';
let used = new Map();
function icon(emoji, x = 120, y = 25, size = 240) {
  const item = emojiMap.get(normalize(emoji));
  if (!item) throw new Error(`No OpenMoji artwork for ${emoji}`);
  const svg = fs.readFileSync(path.join(openmoji, `color/svg/${item.hexcode}.svg`), 'utf8');
  used.set(item.hexcode, item);
  return svg.replace(/<svg\b[^>]*>/, `<svg x="${x}" y="${y}" width="${size}" height="${size}" viewBox="0 0 72 72">`);
}
function code(hex, x = 120, y = 25, size = 240) {
  const item = metadata.find(item => item.hexcode === hex);
  if (!item) throw new Error(`Unknown artwork ${hex}`);
  return icon(item.emoji, x, y, size);
}
const rect = (x,y,w,h,fill,rx=12) => `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${rx}" fill="${fill}" stroke="${ink}" stroke-width="5"/>`;
const circle = (x,y,r,fill) => `<circle cx="${x}" cy="${y}" r="${r}" fill="${fill}" stroke="${ink}" stroke-width="5"/>`;
const line = (x,y,x2,y2,color=ink,width=6) => `<path d="M${x} ${y}L${x2} ${y2}" fill="none" stroke="${color}" stroke-width="${width}" stroke-linecap="round"/>`;
const shape = (d,fill) => `<path d="${d}" fill="${fill}" stroke="${ink}" stroke-width="5" stroke-linejoin="round" stroke-linecap="round"/>`;
const text = (value,x,y,size=26,fill=ink) => `<text x="${x}" y="${y}" font-family="Arial" font-size="${size}" font-weight="700" text-anchor="middle" fill="${fill}">${value}</text>`;
const arrow = (x,y,dx=45) => line(x,y,x+dx,y,blue,7)+shape(`M${x+dx-12*Math.sign(dx)} ${y-10}L${x+dx} ${y}L${x+dx-12*Math.sign(dx)} ${y+10}`,'none');
const ordinary = {
  apple:'🍎',banana:'🍌',orange:'🍊',grape:'🍇',watermelon:'🍉',mango:'🥭',pear:'🍐',peach:'🍑',strawberry:'🍓',coconut:'🥥',
  carrot:'🥕',potato:'🥔',tomato:'🍅',onion:'🧅',cucumber:'🥒',corn:'🌽',pumpkin:'🎃',
  cat:'🐈',dog:'🐕',rabbit:'🐇',bird:'🐦',fish:'🐟',lion:'🦁',bear:'🐻',monkey:'🐒',horse:'🐎',cow:'🐄',goat:'🐐',
  tiger:'🐅',elephant:'🐘',giraffe:'🦒',zebra:'🦓',panda:'🐼',fox:'🦊',wolf:'🐺',hamster:'🐹',turtle:'🐢',
  eagle:'🦅',parrot:'🦜',swan:'🦢',owl:'🦉',pigeon:'E009',rooster:'🐓',
  whale:'🐋',dolphin:'🐬',shark:'🦈',octopus:'🐙',crab:'🦀',goldfish:'E000',
  ant:'🐜',butterfly:'🦋',bee:'🐝',beetle:'🪲',ladybug:'🐞',mosquito:'🦟',grasshopper:'🦗',
  tree:'🌳',flower:'🌼',rose:'🌹',sunflower:'🌻',leaf:'🍃',
  hand:'✋',eye:'👁',ear:'👂',nose:'👃',mouth:'👄',foot:'🦶',
  happy:'😄',tired:'E280',sad:'😢',angry:'😠',excited:'🤩',scared:'😨',calm:'😌',proud:'😊',
  folder:'📁',globe:'🌐',chair:'🪑',sofa:'🛋',door:'🚪',window:'🪟',clock:'🕒',mirror:'🪞',alarm_clock:'⏰',
  spoon:'🥄',pan:'🍳',pot:'🍲',knife:'🔪',bed:'🛏',
  shoe:'👟',hat:'🧢',sandals:'🩴',boots:'👢',scarf:'🧣',gloves:'🧤',shirt:'👕',dress:'👗',pants:'👖',socks:'🧦',coat:'🧥',
  rice:'🍚',bread:'🍞',noodles:'🍜',soup:'🥣',egg:'🥚',chicken:'🍗',sandwich:'🥪',pizza:'🍕',milk:'🥛',tea:'🍵',coffee:'☕',
  home:'🏠',school:'🏫',park:'🏞',hospital:'🏥',museum:'🏛',hotel:'🏨',ticket:'🎟',map:'🗺',suitcase:'🧳',
  bus:'🚌',bicycle:'🚲',car:'🚗',train:'🚆',plane:'✈',boat:'⛵',taxi:'🚕',traffic_light:'🚦',sign:'E094',
  computer:'💻',tablet:'E1CC',phone:'📱',camera:'📷',keyboard:'⌨',mouse:'🖱',screen:'🖥',charger:'🔌',
  puzzle:'🧩',kite:'🪁',robot:'🤖',teddy_bear:'🧸',ball:'⚽',
  piano:'🎹',guitar:'🎸',drum:'🥁',violin:'🎻',flute:'🪈',trumpet:'🎺',
  music:'🎵',drawing:'🖍',painting:'🎨',singing:'🧑‍🎤',dancing:'💃',cooking:'🧑‍🍳',reading:'📖',
  football:'⚽',swimming:'🏊',basketball:'🏀',tennis:'🎾',volleyball:'🏐',running:'🏃',cycling:'🚴',run:'🏃',write:'✍',stand:'🧍',wash:'E0B2',
  sunny:'☀',rainy:'🌧',cloudy:'☁',windy:'🌬',snowy:'🌨',storm:'⛈',rainbow:'🌈',
  mountain:'⛰',beach:'🏖',island:'🏝',
  doctor:'E301',teacher:'🧑‍🏫',nurse:'E302',farmer:'🧑‍🌾',chef:'🧑‍🍳',firefighter:'🧑‍🚒',baby:'👶',grandmother:'👵',grandfather:'👴',
};
function smallIcon(emoji,x,y,size=110) { return icon(emoji,x,y,size); }
function person(pose='stand') {
  const head = circle(225,65,24,'#FFD9AA');
  if (pose==='sit') return rect(190,174,80,14,mint,4)+line(190,187,190,253)+line(266,188,266,253)+line(190,102,190,171,mint,10)+head+line(225,90,225,157,blue,20)+line(225,157,290,157,ink,10)+line(290,157,290,222,ink,10)+line(290,222,314,222,ink,8)+line(225,113,254,137);
  if (pose==='jump') return head+line(225,92,225,165,blue,20)+line(225,113,184,76)+line(225,113,268,76)+line(225,165,190,200)+line(225,165,261,197)+line(186,240,282,240,mint)+line(314,229,314,165,blue,7)+shape('M302 179L314 165L326 179','none');
  return head+line(225,94,225,168,blue,20)+line(225,114,191,157)+line(225,114,259,157)+line(225,168,199,237)+line(225,168,251,237);
}
function calendar(label,selected=0,month=false) {
  let content=rect(108,42,264,218,'#FFF')+rect(108,42,264,53,blue)+text(label,240,77,25,'#FFF')+line(155,25,155,55)+line(325,25,325,55);
  if(month) {
    for(let i=1;i<=31;i++) content += text(String(i),137+((i-1)%7)*34,125+Math.floor((i-1)/7)*27,17);
  } else {
    ['M','T','W','T','F','S','S'].forEach((d,i)=>content+=text(d,132+i*36,124,17));
    for(let i=0;i<7;i++) content += circle(132+i*36,165,12,i===selected?gold:'#EAF4FF');
    content+=line(147,214,332,214,'#D7E4EE',6);
  }
  return content;
}
function custom(id) {
  const colors={red:'#EE5658',blue:'#3286D9',green:'#56B878',yellow:'#F6CF4A',black:'#263238',white:'#FFFFFF',pink:'#F09CB8',purple:'#9B75D4'};
  if(colors[id]) return shape('M240 37C220 70 156 125 156 179A84 84 0 0 0 324 179C324 125 260 70 240 37Z',colors[id])+shape('M190 161Q178 196 204 216','none');
  const numbers={one:1,two:2,three:3,four:4,five:5,six:6,ten:10};
  if(numbers[id]) {
    let content=text(String(numbers[id]),146,193,116,blue);
    for(let i=0;i<numbers[id];i++) content+=circle(255+(i%3)*50,95+Math.floor(i/3)*47,15,[mint,gold,'#F28A8E'][i%3]);
    return content;
  }
  if(id==='star') return icon('⭐');
  if(id==='heart') return icon('❤');
  const shapes={circle:circle(240,150,88,blue),square:rect(151,61,178,178,mint,2),triangle:shape('M240 48L343 240L137 240Z',gold),rectangle:rect(113,91,254,118,blue,2),oval:'<ellipse cx="240" cy="150" rx="122" ry="75" fill="#F09CB8" stroke="#253B53" stroke-width="5"/>'};
  if(shapes[id]) return shapes[id];
  const weekdays={monday:0,tuesday:1,wednesday:2,thursday:3,friday:4,sunday:6};
  if(id in weekdays) return calendar(id[0].toUpperCase()+id.slice(1),weekdays[id]);
  if(id==='january') return calendar('January',0,true);
  if(['today','tomorrow','yesterday'].includes(id)) {
    let s=''; ['Yesterday','Today','Tomorrow'].forEach((label,i)=>{
      const active=label.toLowerCase()===id;
      s+=rect(32+i*151,95,135,125,active?'#FFF2B8':'#FFF')+rect(32+i*151,95,135,38,active?blue:'#B6CADB')+text(label,99+i*151,120,17,'#FFF')+text(String(i+14),99+i*151,190,43,active?blue:'#92A9BA');
      if(active) s+=shape(`M${80+i*151} 240L${99+i*151} 225L${118+i*151} 240`,mint);
    }); return s;
  }
  if(['morning','afternoon','evening','night'].includes(id)) {
    const night=id==='night',evening=id==='evening';
    const sky=night?'#233750':evening?'#F2A98D':'#BFEBFF';
    return rect(45,32,390,235,sky,25)+shape('M45 222Q152 165 230 225T435 220L435 267L45 267Z',night?'#3F6B73':mint)+(night?smallIcon('🌙',272,55,125):smallIcon('☀',id==='morning'?68:245,evening?125:45,130))+(night?smallIcon('⭐',87,63,62)+smallIcon('⭐',187,112,45):smallIcon('☁',180,74,113));
  }
  if(['spring','summer','autumn','winter'].includes(id)) {
    if(id==='spring') return icon('🌳',105,10,240)+smallIcon('🌷',55,154,95)+smallIcon('🌼',310,154,95)+smallIcon('🌸',243,63,79);
    if(id==='summer') return icon('🌳',115,25,235)+smallIcon('☀',320,10,100)+line(95,251,397,251,mint);
    if(id==='autumn') return icon('🍂',125,18,240)+smallIcon('🍁',57,134,100)+smallIcon('🍁',328,119,95);
    return icon('🌲',121,35,228)+smallIcon('❄',43,28,83)+smallIcon('❄',322,39,95)+line(92,258,393,258,'#FFF',18);
  }
  switch(id) {
    case 'pumpkin': return shape('M240 67C143 30 92 101 106 168C116 232 197 254 240 235C290 255 366 227 375 166C385 105 328 32 240 67Z','#F6A441')+line(237,69,246,39,'#63894D',16)+shape('M216 76C177 112 171 188 223 231','none')+shape('M263 77C305 122 309 192 259 230','none');
    case 'marker': return shape('M138 198L295 59L333 101L176 240Z',blue)+shape('M138 198L126 249L176 240Z','#303747')+shape('M295 59L316 42L355 84L333 101Z',mint);
    case 'stapler': return shape('M104 214L358 214L375 186L120 175Z',blue)+shape('M120 169L318 101L342 130L150 199Z','#8CBFDB')+shape('M130 168L291 116L311 83L123 128Z',blue)+circle(125,170,10,gold);
    case 'calculator': {
      let s=rect(160,31,160,239,blue,18)+rect(176,49,128,50,'#D6EBDD',6)+text('123',240,85,29);
      for(let y=0;y<4;y++)for(let x=0;x<3;x++)s+=rect(179+x*42,118+y*32,30,22,x===2?gold:'#FFF',4); return s;
    }
    case 'table': return rect(93,112,294,33,'#DDB98D',8)+line(120,147,109,253,ink,10)+line(360,147,371,253,ink,10);
    case 'desk': return rect(75,109,326,24,'#DDB98D',6)+rect(306,134,76,92,blue,4)+line(105,134,105,252)+line(374,226,374,252)+line(307,169,381,169)+line(328,151,355,151)+line(328,197,355,197)+smallIcon('📖',125,41,103);
    case 'lamp': return shape('M204 59L279 59L311 135L172 135Z',gold)+line(242,136,242,232)+rect(194,230,96,17,blue,7);
    case 'plate': return '<ellipse cx="240" cy="150" rx="129" ry="88" fill="#FFF" stroke="#253B53" stroke-width="5"/><ellipse cx="240" cy="150" rx="93" ry="61" fill="#EAF4FF" stroke="#8EBBDD" stroke-width="4"/>';
    case 'bowl': return shape('M105 105L375 105Q353 237 240 243Q126 239 105 105Z',blue)+'<ellipse cx="240" cy="105" rx="135" ry="32" fill="#FFF" stroke="#253B53" stroke-width="5"/>';
    case 'fridge': return rect(159,28,164,246,'#D9E9F3',12)+line(160,112,322,112)+line(188,66,188,91)+line(188,147,188,185)+line(172,275,172,282)+line(310,275,310,282)+smallIcon('🍎',233,143,68);
    case 'pillow': return shape('M113 72Q137 82 240 80Q331 82 365 72Q355 163 365 225Q256 214 114 225Q126 149 113 72Z','#FFF')+shape('M132 95Q240 104 343 95M136 202Q246 193 341 202','none');
    case 'blanket': return shape('M134 59L358 84L327 245L104 217Z','#F3ABBB')+shape('M134 59L352 83L318 185L110 160Z','#B394D2')+line(128,171,322,195,'#FFF',6)+line(118,201,316,225,'#FFF',6);
    case 'wardrobe': return rect(116,36,247,222,'#DDB98D',8)+line(238,37,238,256)+line(220,139,220,169)+line(256,139,256,169)+line(134,258,134,274)+line(344,258,344,274);
    case 'skirt': return shape('M179 51L302 51L363 247L116 247Z','#F3A9BB')+rect(179,47,123,27,'#F18CA8',5)+line(205,76,177,242)+line(238,77,237,244)+line(272,76,302,242);
    case 'sweater': return shape('M177 66L210 51Q240 83 270 51L303 66L358 164L315 183L292 132L292 254L188 254L188 132L165 183L122 164Z',blue)+line(193,221,288,221,mint,6);
    case 'belt': return shape('M103 140Q103 78 274 83L343 83L343 139L264 139Q151 131 153 173Q161 212 337 207L337 247Q99 251 103 140Z','#AC825C')+rect(316,78,76,65,gold,5)+rect(330,91,46,36,'#DDB98D',2)+line(341,108,386,108);
    case 'water': return shape('M240 35C211 87 171 123 171 179A69 69 0 0 0 309 179C309 123 269 87 240 35Z',blue)+shape('M194 170Q182 202 210 216','none');
    case 'juice': return shape('M173 91L309 91L290 252L191 252Z','#F4A347')+line(269,142,286,48)+line(286,48,323,48)+smallIcon('🍊',70,138,127);
    case 'lemonade': return shape('M167 91L309 91L290 252L185 252Z','#F9E28A')+line(257,167,279,45)+line(279,45,318,45)+smallIcon('🍋',68,155,141)+circle(217,141,13,'#FFF')+circle(257,182,12,'#FFF');
    case 'cabbage': return circle(240,149,98,'#A9CF72')+shape('M237 62Q148 111 166 200Q221 189 237 62Z','#70B574')+shape('M254 65Q328 119 311 204Q259 196 254 65Z','#84C384')+shape('M178 224Q251 157 317 222Q258 273 178 224Z','#66A96B');
    case 'seed': return shape('M223 47Q332 80 294 197Q266 258 205 240Q147 222 167 150Q181 89 223 47Z','#B58C64')+shape('M233 76Q194 131 194 199','none');
    case 'grass': {let s=''; for(let i=0;i<9;i++)s+=shape(`M${87+i*34} 246Q${68+i*34} 168 ${95+i*34} ${70+(i%3)*25}Q${112+i*34} 171 ${104+i*34} 246Z`,i%2?mint:'#71AF64'); return s;}
    case 'seahorse': return shape('M266 46C209 21 194 58 208 87L168 108L189 127L216 112Q250 155 208 194C163 238 211 276 249 254C278 235 257 210 237 220Q225 230 239 236Q212 250 210 230C210 211 270 197 281 165C295 125 248 105 257 79L299 74L299 58Z','#E9B65C')+circle(238,64,4,ink)+shape('M274 121L304 145L279 166',gold)+line(243,133,268,130)+line(239,152,273,152)+line(229,172,261,177);
    case 'guinea_pig': return '<ellipse cx="241" cy="168" rx="119" ry="76" fill="#C39365" stroke="#253B53" stroke-width="5"/>'+circle(166,116,28,'#C39365')+circle(208,138,29,'#FFF')+circle(222,143,5,ink)+circle(141,165,6,'#F3ABBB')+line(182,237,177,250)+line(303,231,306,249)+line(130,173,104,165)+line(132,183,109,185);
    case 'puppy': return icon('🐕',114,24,221)+smallIcon('🎾',325,164,71);
    case 'kitten': return icon('🐈',114,25,221)+smallIcon('🧶',323,171,74);
    case 'head': return circle(240,135,86,'#FFD9AA')+shape('M159 120Q158 37 240 38Q320 41 324 110L299 82Q239 116 190 81Z','#AC825C')+circle(209,135,5,ink)+circle(270,135,5,ink)+shape('M212 174Q241 194 270 174','none')+line(204,247,276,247,blue,20);
    case 'mother': return smallIcon('👩',78,39,229)+smallIcon('👧',283,118,135)+smallIcon('❤',311,32,66);
    case 'father': return smallIcon('👨',78,39,229)+smallIcon('👦',283,118,135)+smallIcon('❤',311,32,66);
    case 'sister': return smallIcon('👧',43,53,224)+smallIcon('👦',251,95,169)+smallIcon('⭐',171,29,62);
    case 'brother': return smallIcon('👦',43,53,224)+smallIcon('👧',251,95,169)+smallIcon('⭐',171,29,62);
    case 'cousin': return smallIcon('👧',31,54,214)+smallIcon('👦',234,54,214)+shape('M173 237Q240 278 305 237','none');
    case 'read': return smallIcon('🧒',161,1,158)+smallIcon('📖',128,138,225);
    case 'listen': return icon('👂',75,42,221)+smallIcon('🎵',299,52,121);
    case 'sit': return person('sit');
    case 'jump': return person('jump');
    case 'open': return rect(157,38,174,223,'#6C8293',3)+shape('M158 38L274 67L274 267L158 261Z','#DDB98D')+circle(255,166,5,gold)+arrow(319,164,55);
    case 'close': return rect(161,38,161,223,'#DDB98D',3)+circle(301,166,5,gold)+arrow(375,164,-43);
    case 'wake': return smallIcon('🛏',96,104,253)+smallIcon('☀',325,4,100)+smallIcon('🧒',157,6,149)+line(205,135,166,113,blue,8)+line(275,135,308,100,blue,8);
    case 'brush': return shape('M201 64L270 64Q303 118 269 157L259 251L219 251L208 157Q172 111 201 64Z','#DDB98D')+rect(207,65,58,77,'#F4ABBA',22)+line(217,77,217,132)+line(237,77,237,132)+line(255,77,255,132);
    case 'brush_teeth': return icon('🦷',105,19,221)+smallIcon('🪥',286,91,133);
    case 'eat': return smallIcon('🧒',78,12,170)+smallIcon('🍽',161,118,233)+smallIcon('🥪',230,161,92);
    case 'drink': return smallIcon('🧒',94,26,214)+shape('M290 109L372 109L361 202L302 202Z',blue)+arrow(357,74,-44);
    case 'sleep': return icon('🛏',101,80,269)+smallIcon('💤',269,11,123);
    case 'library': return smallIcon('🏛',92,4,267)+smallIcon('📚',281,148,151);
    case 'classroom': return rect(115,35,250,119,'#55856D')+text('A B C',240,108,38,'#FFF')+rect(74,202,137,20,'#DDB98D',4)+rect(270,202,137,20,'#DDB98D',4)+line(92,223,92,269)+line(196,223,196,269)+line(288,223,288,269)+line(391,223,391,269);
    case 'market': return rect(110,117,259,114,'#DDB98D',6)+shape('M100 117L137 56L345 56L382 117Z','#F5AFB3')+line(168,57,154,117,'#FFF',14)+line(231,57,231,117,'#FFF',14)+line(294,57,308,117,'#FFF',14)+smallIcon('🍎',129,135,75)+smallIcon('🥕',211,135,75)+smallIcon('🍌',290,134,75)+line(121,232,121,264)+line(354,232,354,264);
    case 'airport': return rect(72,139,342,115,'#BFDCEB',8)+rect(142,169,56,86,'#FFF',2)+rect(268,169,56,86,'#FFF',2)+smallIcon('✈',145,8,202);
    case 'passport': return rect(150,40,183,223,blue,13)+smallIcon('🌐',178,100,123)+text('PASSPORT',241,79,17,'#FFF')+line(196,237,286,237,'#FFF',4);
    case 'guide': return smallIcon('🧑',70,12,190)+smallIcon('🗺',225,113,178)+smallIcon('📍',335,27,80);
    case 'driver': return smallIcon('🧑',76,8,196)+smallIcon('🚗',195,99,214);
    case 'bridge': return shape('M71 205Q240 20 409 205L409 226L70 226Z','#EAA889')+shape('M120 211Q240 93 360 211Z','#D6F1F5')+line(60,255,424,255,blue,12)+line(72,200,408,200);
    case 'road': return shape('M188 39L293 39L390 271L91 271Z','#728495')+line(240,53,240,93,'#FFF',7)+line(240,121,240,167,'#FFF',9)+line(240,196,240,253,'#FFF',11);
    case 'sidewalk': return shape('M108 266L370 266L305 40L177 40Z','#E6D4B5')+line(135,185,343,185)+line(154,120,324,120)+line(170,71,309,71)+line(240,41,240,265)+smallIcon('🚶',307,128,128);
    case 'crossing': {let s=rect(62,55,356,206,'#758391',5); for(let i=0;i<5;i++)s+=rect(101+i*60,96,36,122,'#FFF',1); return s;}
    case 'river': return rect(40,30,400,240,'#94C996',20)+shape('M208 30C352 76 131 127 252 180Q348 219 278 270L160 270Q257 216 163 183C54 120 266 85 146 30Z','#80C9EC')+smallIcon('🌳',45,130,115)+smallIcon('🌳',310,43,110);
    case 'lake': return '<ellipse cx="240" cy="193" rx="173" ry="63" fill="#80C9EC" stroke="#253B53" stroke-width="5"/>'+smallIcon('🌳',86,10,166)+smallIcon('🌲',286,32,137)+line(147,182,216,182,'#FFF',4)+line(258,218,321,218,'#FFF',4);
    case 'forest': return smallIcon('🌳',22,53,205)+smallIcon('🌲',138,3,251)+smallIcon('🌳',274,65,191);
    case 'sky': return rect(45,32,390,236,'#B7E8FC',24)+smallIcon('☁',51,97,182)+smallIcon('☁',221,46,191)+smallIcon('☀',308,155,95);
    case 'doll': return circle(240,91,40,'#FFD9AA')+shape('M201 87Q188 41 239 37Q286 38 284 91L266 65L209 65Z','#AC825C')+shape('M218 139L262 139L298 231L182 231Z','#F3A9BB')+line(221,145,181,170)+line(260,145,301,170)+line(216,230,208,261)+line(264,230,272,261)+circle(226,91,3,ink)+circle(254,91,3,ink);
    case 'blocks': return rect(103,150,104,104,mint,8)+text('A',155,220,51)+rect(219,150,104,104,gold,8)+text('B',271,220,51)+rect(160,34,104,104,'#F3A9BB',8)+text('C',212,104,51);
    default: return null;
  }
}
const manifest = [];
for (const word of catalog.filter(word => !word.image || word.image.startsWith('assets/catalog/illustrations/'))) {
  used = new Map();
  // Specific compositions take precedence over the generic library mapping.
  const content = custom(word.id) ?? (ordinary[word.id]?.startsWith('E') && ordinary[word.id].length===4 ? code(ordinary[word.id]) : ordinary[word.id] ? icon(ordinary[word.id]) : null);
  if(!content) throw new Error(`Missing illustration: ${word.id}`);
  const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="640" height="400" viewBox="0 0 480 300"><rect width="480" height="300" fill="#FFF8ED"/><ellipse cx="240" cy="270" rx="127" ry="12" fill="#E7E9D9"/>${content}</svg>`;
  fs.writeFileSync(path.join(sources,`${word.id}.svg`),svg);
  fs.writeFileSync(path.join(output,`${word.id}.png`),new Resvg(svg,{font:{loadSystemFonts:true}}).render().asPng());
  manifest.push({id:word.id,english:word.english,vietnamese:word.vietnamese,file:`${word.id}.png`,license:'CC BY-SA 4.0',attribution:used.size?'OpenMoji contributors (https://openmoji.org), CC BY-SA 4.0; composition/adaptations by Vocab Vision':'Vocab Vision original educational illustration, CC BY-SA 4.0',sources:[...used.values()].map(item=>({hexcode:item.hexcode,annotation:item.annotation,author:item.openmoji_author,url:`https://github.com/hfg-gmuend/openmoji/blob/16.0.0/color/svg/${item.hexcode}.svg`}))});
}
fs.writeFileSync(path.join(output,'manifest.json'),JSON.stringify({openmoji_version:'16.0.0',width:640,height:400,images:manifest},null,2));
fs.copyFileSync(path.join(openmoji,'LICENSE.txt'),path.join(output,'LICENSE.txt'));
const own=manifest.filter(item=>!item.sources.length).map(item=>`  '${item.id}',`).join('\n');
fs.writeFileSync(path.join(root,'lib/core/media/starter_illustrations.dart'),`// Generated by tool/prepare_catalog_illustrations.cjs.\nconst originalStarterIllustrations = <String>{\n${own}\n};\n\nString starterIllustrationAttribution(String id) =>\n    originalStarterIllustrations.contains(id)\n    ? 'Vocab Vision original educational illustration, CC BY-SA 4.0'\n    : 'OpenMoji contributors (https://openmoji.org), CC BY-SA 4.0; composition/adaptations by Vocab Vision';\n`);
const bytes=manifest.reduce((total,item)=>total+fs.statSync(path.join(output,item.file)).size,0);
console.log(JSON.stringify({images:manifest.length,bytes,original:manifest.filter(item=>!item.sources.length).length}));
