// Arsenal: Playwright Chromium WebGL / mobile touch QA.
// CCGS principles: capture evidence and report NOT ASSESSED honestly.
// No Claude model, tokens or other paid execution required.
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import crypto from 'node:crypto';
import { chromium } from 'playwright';

const root = path.resolve('build');
const output = path.resolve('build/qa/browser');
fs.mkdirSync(output, {recursive:true});
const report = {status:'FAIL',checks:[],errors:[],browser:'Chromium/SwiftShader',
  comparison_to_reference_video:'NOT ASSESSED',physical_android_fps:'NOT ASSESSED'};
const mime={'.html':'text/html','.js':'text/javascript','.wasm':'application/wasm',
  '.pck':'application/octet-stream','.png':'image/png','.json':'application/json','.svg':'image/svg+xml'};
const server=http.createServer((req,res)=>{
  const requested=decodeURIComponent((req.url??'/').split('?')[0]);
  const file=path.resolve(root,'.'+(requested==='/'?'/index.html':requested));
  if(!(file===root||file.startsWith(root+path.sep))||!fs.existsSync(file)||!fs.statSync(file).isFile()){
    res.writeHead(404);res.end('Not found');return;
  }
  res.setHeader('Content-Type',mime[path.extname(file)]??'application/octet-stream');
  res.setHeader('Cross-Origin-Opener-Policy','same-origin');
  res.setHeader('Cross-Origin-Embedder-Policy','require-corp');
  fs.createReadStream(file).pipe(res);
});
const port=8844;
const sha=buf=>crypto.createHash('sha256').update(buf).digest('hex');
const checked=(name,pass,details='')=>{
  report.checks.push({name,status:pass?'PASS':'FAIL',details});
  if(!pass)report.errors.push(name+(details?': '+details:''));
};
let browser;
try{
  if(!fs.existsSync(path.resolve(root,'index.html')))throw new Error('Godot Web HTML export absent');
  await new Promise((resolve,reject)=>server.listen(port,'127.0.0.1',err=>err?reject(err):resolve()));
  browser=await chromium.launch({headless:true,executablePath:'/usr/bin/chromium',args:[
    '--enable-webgl','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader',
    '--disable-dev-shm-usage','--no-sandbox'
  ]});
  for(const mode of ['desktop','mobile']){
    const ctx=await browser.newContext(mode==='mobile'?
      {viewport:{width:896,height:414},deviceScaleFactor:1,hasTouch:true,isMobile:true}:
      {viewport:{width:1280,height:720},deviceScaleFactor:1,hasTouch:false,isMobile:false});
    const page=await ctx.newPage();
    const pageErrors=[],failedRequests=[];
    let downloadedPack=false;
    page.on('pageerror',e=>pageErrors.push(e.message));
    page.on('requestfailed',r=>failedRequests.push(r.url()+' '+r.failure()?.errorText));
    page.on('response',r=>{if(r.url().endsWith('.pck')&&r.status()===200)downloadedPack=true;});
    try{
      await page.goto('http://127.0.0.1:'+port+'/',{waitUntil:'domcontentloaded',timeout:90000});
      await page.waitForSelector('canvas',{state:'visible',timeout:90000});
      await page.waitForFunction(()=>{
        const c=document.querySelector('canvas');
        return c&&c.width>200&&c.height>150;
      },{timeout:45000}).catch(()=>{});
      await page.waitForTimeout(9000);
      const info=await page.evaluate(()=>{
        const c=document.querySelector('canvas');
        return {canvas:!!c,width:c?.width??0,height:c?.height??0,
          touchPoints:navigator.maxTouchPoints,webgl2:!!c?.getContext('webgl2')};
      });
      const shot=await page.screenshot({path:path.join(output,mode+'.png'),animations:'disabled',timeout:30000});
      checked(mode+'-visible-game-canvas',info.canvas&&info.width>200&&info.height>150,JSON.stringify(info));
      checked(mode+'-game-package-loaded',downloadedPack,'.pck HTTP 200');
      checked(mode+'-screenshot-produced',shot.length>9000,shot.length+' bytes sha256:'+sha(shot));
      if(mode==='mobile'){
        checked('mobile-touch-capable',info.touchPoints>0,'navigator.maxTouchPoints='+info.touchPoints);
        // Chromium emits real touch input. GDScript tests separately assert
        // the joystick movement and auto-fire mechanics.
        const cdp=await ctx.newCDPSession(page);
        const y=312,x=130;
        await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x,y,id:1}]});
        await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:x+82,y:y-29,id:1}]});
        await page.waitForTimeout(650);
        await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
        const touched=await page.screenshot({path:path.join(output,'mobile-after-touch.png'),timeout:30000});
        checked('mobile-touch-input-sent',touched.length>9000,
          'CDP touch start/drag/end; GDScript verifies movement separately');
      }
      checked(mode+'-javascript-errors',pageErrors.length===0,pageErrors.slice(0,5).join('; '));
      checked(mode+'-failed-requests',failedRequests.length===0,failedRequests.slice(0,5).join('; '));
    }catch(e){
      checked(mode+'-browser-session',false,String(e).slice(0,600));
      await page.screenshot({path:path.join(output,mode+'-failure.png'),timeout:8000}).catch(()=>{});
    }finally{await ctx.close();}
  }
  report.status=report.errors.length?'FAIL':'PASS';
}catch(e){report.errors.push(String(e));}
finally{
  fs.writeFileSync(path.resolve('build/qa/browser-report.json'),JSON.stringify(report,null,2)+'\n');
  console.log('ARSENAL_BROWSER_QA_'+report.status,JSON.stringify(report.checks.map(c=>[c.name,c.status])));
  if(report.errors.length)console.error(report.errors.join('\n'));
  await browser?.close().catch(()=>{});
  if(server.listening)await new Promise(resolve=>server.close(resolve));
}
if(report.errors.length)process.exitCode=1;
