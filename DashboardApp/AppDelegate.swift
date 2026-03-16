import UIKit
import WebKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        let vc = DashboardViewController()
        window?.rootViewController = vc
        window?.makeKeyAndVisible()
        // Keep screen on
        UIApplication.shared.isIdleTimerDisabled = true
        return true
    }
}

class DashboardViewController: UIViewController, WKNavigationDelegate {
    var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Full screen black background
        view.backgroundColor = .black

        // Hide status bar
        setNeedsStatusBarAppearanceUpdate()

        // Setup WebView
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.backgroundColor = .black
        webView.isOpaque = false
        view.addSubview(webView)

        // Load HTML directly from string - no server needed!
        let html = dashboardHTML()
        webView.loadHTMLString(html, baseURL: nil)
    }

    override var prefersStatusBarHidden: Bool { return true }
    override var prefersHomeIndicatorAutoHidden: Bool { return true }

    func dashboardHTML() -> String {
        return """
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
<style>
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
:root {
  --bg: #060a0f;
  --panel: rgba(255,255,255,0.05);
  --border: rgba(0,255,200,0.18);
  --accent: #00ffc8;
  --accent2: #00aaff;
  --text: #e8f4f0;
  --muted: rgba(232,244,240,0.4);
}
html, body {
  width: 100%; height: 100%;
  background: var(--bg);
  color: var(--text);
  font-family: -apple-system, 'Helvetica Neue', Arial, sans-serif;
  overflow: hidden;
  -webkit-tap-highlight-color: transparent;
  -webkit-user-select: none;
}
body {
  background-image:
    radial-gradient(ellipse at 15% 50%, rgba(0,255,200,0.07) 0%, transparent 55%),
    radial-gradient(ellipse at 85% 15%, rgba(0,170,255,0.07) 0%, transparent 55%);
}
body::before {
  content: '';
  position: fixed; top:0;left:0;right:0;bottom:0;
  background: repeating-linear-gradient(0deg, transparent, transparent 3px, rgba(0,0,0,0.06) 3px, rgba(0,0,0,0.06) 4px);
  pointer-events: none; z-index: 999;
}
.grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  grid-template-rows: auto 1fr;
  gap: 12px; padding: 14px;
  height: 100vh; width: 100vw;
}
.clock-panel {
  grid-column: 1; grid-row: 1;
  background: var(--panel); border: 1px solid var(--border);
  border-radius: 14px; padding: 18px 22px;
  display: flex; flex-direction: column; justify-content: center;
  position: relative; overflow: hidden;
}
.clock-panel::after {
  content: ''; position: absolute;
  top:0; left:10%; right:10%; height:1px;
  background: linear-gradient(90deg, transparent, var(--accent), transparent);
}
.time-row { display: flex; align-items: baseline; }
.tnum {
  font-family: 'Courier New', Courier, monospace;
  font-size: 60px; font-weight: bold;
  color: var(--accent);
  text-shadow: 0 0 20px rgba(0,255,200,0.55);
  line-height: 1;
}
.colon {
  font-family: 'Courier New', Courier, monospace;
  font-size: 60px; font-weight: bold;
  color: var(--accent);
  text-shadow: 0 0 20px rgba(0,255,200,0.55);
  line-height: 1; width: 22px; text-align: center;
  animation: blink 1s step-end infinite;
}
.ampm {
  font-family: 'Courier New', Courier, monospace;
  font-size: 18px; font-weight: bold;
  color: var(--accent2); margin-left: 8px;
  align-self: flex-start; margin-top: 10px;
}
@keyframes blink { 0%,100%{opacity:1} 50%{opacity:0} }
.date-str {
  margin-top: 8px; font-size: 12px;
  color: var(--muted); letter-spacing: 0.12em; text-transform: uppercase;
}
.cal-panel {
  grid-column: 2; grid-row: 1;
  background: var(--panel); border: 1px solid var(--border);
  border-radius: 14px; padding: 14px 16px;
  display: flex; flex-direction: column;
  position: relative; overflow: hidden;
}
.cal-panel::after {
  content: ''; position: absolute;
  top:0; left:10%; right:10%; height:1px;
  background: linear-gradient(90deg, transparent, var(--accent2), transparent);
}
.cal-head {
  display: flex; justify-content: space-between;
  align-items: center; margin-bottom: 8px;
}
.cal-lbl {
  font-family: 'Courier New', Courier, monospace;
  font-size: 13px; font-weight: bold;
  color: var(--accent2); letter-spacing: 0.1em; text-transform: uppercase;
}
.nav-wrap { display: flex; gap: 6px; }
.nav-btn {
  background: rgba(0,170,255,0.1); border: 1px solid rgba(0,170,255,0.3);
  color: var(--accent2); border-radius: 6px;
  width: 28px; height: 28px; font-size: 18px; cursor: pointer;
  display: flex; align-items: center; justify-content: center;
}
.nav-btn:active { background: rgba(0,170,255,0.3); }
.cal-grid {
  display: grid; grid-template-columns: repeat(7, 1fr);
  gap: 2px; flex: 1;
}
.dn { text-align: center; font-size: 10px; color: var(--muted); font-weight: 600; padding: 2px 0 4px; }
.dc {
  text-align: center; font-size: 12px; padding: 5px 2px;
  border-radius: 5px; color: rgba(232,244,240,0.55);
  display: flex; align-items: center; justify-content: center;
}
.dc.other { color: rgba(255,255,255,0.14); }
.dc.today {
  background: var(--accent); color: #060a0f; font-weight: 700;
  border-radius: 50%; box-shadow: 0 0 10px rgba(0,255,200,0.5);
}
.todo-panel {
  grid-column: 1 / 3; grid-row: 2;
  background: var(--panel); border: 1px solid var(--border);
  border-radius: 14px; padding: 14px 18px;
  display: flex; flex-direction: column;
  position: relative; overflow: hidden;
}
.todo-panel::after {
  content: ''; position: absolute;
  top:0; left:10%; right:10%; height:1px;
  background: linear-gradient(90deg, transparent, var(--accent), var(--accent2), transparent);
}
.todo-hdr { display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px; }
.todo-ttl {
  font-family: 'Courier New', Courier, monospace;
  font-size: 12px; font-weight: bold; color: var(--accent);
  letter-spacing: 0.12em; text-transform: uppercase;
}
.todo-rem { font-size: 11px; color: var(--muted); }
.inp-row { display: flex; gap: 8px; margin-bottom: 10px; }
.t-inp {
  flex: 1; background: rgba(255,255,255,0.05);
  border: 1px solid rgba(0,255,200,0.22); border-radius: 8px;
  padding: 9px 12px; color: var(--text);
  font-family: -apple-system, sans-serif; font-size: 14px; outline: none;
}
.t-inp:focus { border-color: var(--accent); }
.t-inp::placeholder { color: var(--muted); }
.add-b {
  background: rgba(0,255,200,0.12); border: 1px solid rgba(0,255,200,0.35);
  color: var(--accent); border-radius: 8px; padding: 9px 16px;
  font-family: 'Courier New', monospace; font-size: 12px; font-weight: bold;
  cursor: pointer; white-space: nowrap;
}
.add-b:active { background: rgba(0,255,200,0.28); }
.t-list {
  flex: 1; overflow-y: auto;
  display: flex; flex-direction: column; gap: 6px;
  -webkit-overflow-scrolling: touch;
}
.t-item {
  display: flex; align-items: center; gap: 10px; padding: 9px 10px;
  background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.06);
  border-radius: 8px;
}
.t-item.done { opacity: 0.4; }
.chk {
  width: 20px; height: 20px; border-radius: 50%;
  border: 1.5px solid rgba(0,255,200,0.4); background: transparent;
  cursor: pointer; flex-shrink: 0; display: flex;
  align-items: center; justify-content: center; font-size: 11px; color: var(--accent);
}
.t-item.done .chk { background: rgba(0,255,200,0.2); border-color: var(--accent); }
.t-txt { flex: 1; font-size: 14px; color: var(--text); }
.t-item.done .t-txt { text-decoration: line-through; color: var(--muted); }
.del { background: none; border: none; color: rgba(255,80,80,0.4); cursor: pointer; font-size: 15px; padding: 2px 5px; border-radius: 4px; }
.del:active { color: rgba(255,80,80,1); }
.empty { text-align: center; color: var(--muted); font-size: 13px; padding: 18px; font-style: italic; }
.c-tl,.c-br { position: fixed; width: 36px; height: 36px; opacity: 0.25; }
.c-tl { top:8px; left:8px; border-top:2px solid var(--accent); border-left:2px solid var(--accent); }
.c-br { bottom:8px; right:8px; border-bottom:2px solid var(--accent2); border-right:2px solid var(--accent2); }
</style>
</head>
<body>
<div class="c-tl"></div><div class="c-br"></div>
<div class="grid">
  <div class="clock-panel">
    <div class="time-row">
      <span class="tnum" id="hh">12</span><span class="colon">:</span>
      <span class="tnum" id="mm">00</span><span class="colon">:</span>
      <span class="tnum" id="ss">00</span>
      <span class="ampm" id="ap">AM</span>
    </div>
    <div class="date-str" id="ds">Loading...</div>
  </div>
  <div class="cal-panel">
    <div class="cal-head">
      <div class="cal-lbl" id="calLbl">--</div>
      <div class="nav-wrap">
        <button class="nav-btn" onclick="shiftMonth(-1)">&#8249;</button>
        <button class="nav-btn" onclick="shiftMonth(1)">&#8250;</button>
      </div>
    </div>
    <div class="cal-grid" id="calGrid"></div>
  </div>
  <div class="todo-panel">
    <div class="todo-hdr">
      <div class="todo-ttl">&#9632; Tasks</div>
      <div class="todo-rem" id="rem">0 remaining</div>
    </div>
    <div class="inp-row">
      <input class="t-inp" id="inp" type="text" placeholder="Add a new task..." maxlength="80">
      <button class="add-b" onclick="addTask()">+ ADD</button>
    </div>
    <div class="t-list" id="tList"></div>
  </div>
</div>
<script>
var DAYS=['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
var MONS=['January','February','March','April','May','June','July','August','September','October','November','December'];
function pad(n){return n<10?'0'+n:''+n;}
function tick(){
  var n=new Date();
  var h=n.getHours(),m=n.getMinutes(),s=n.getSeconds();
  var ap=h>=12?'PM':'AM'; h=h%12||12;
  document.getElementById('hh').textContent=pad(h);
  document.getElementById('mm').textContent=pad(m);
  document.getElementById('ss').textContent=pad(s);
  document.getElementById('ap').textContent=ap;
  document.getElementById('ds').textContent=DAYS[n.getDay()]+'  \u00B7  '+MONS[n.getMonth()]+' '+n.getDate()+', '+n.getFullYear();
}
setInterval(tick,1000); tick();
var today=new Date(),cY=today.getFullYear(),cM=today.getMonth();
function shiftMonth(d){cM+=d;if(cM>11){cM=0;cY++;}if(cM<0){cM=11;cY--;}buildCal();}
function buildCal(){
  document.getElementById('calLbl').textContent=MONS[cM]+' '+cY;
  var g=document.getElementById('calGrid');g.innerHTML='';
  ['Su','Mo','Tu','We','Th','Fr','Sa'].forEach(function(d){var e=document.createElement('div');e.className='dn';e.textContent=d;g.appendChild(e);});
  var first=new Date(cY,cM,1).getDay(),dim=new Date(cY,cM+1,0).getDate(),dip=new Date(cY,cM,0).getDate();
  var i,e;
  for(i=0;i<first;i++){e=document.createElement('div');e.className='dc other';e.textContent=dip-first+1+i;g.appendChild(e);}
  for(i=1;i<=dim;i++){e=document.createElement('div');e.className='dc';e.textContent=i;if(i===today.getDate()&&cM===today.getMonth()&&cY===today.getFullYear())e.className+=' today';g.appendChild(e);}
  var tail=42-first-dim;
  for(i=1;i<=tail;i++){e=document.createElement('div');e.className='dc other';e.textContent=i;g.appendChild(e);}
}
buildCal();
var tasks=[];try{tasks=JSON.parse(localStorage.getItem('ipad_dash_tasks')||'[]');}catch(x){tasks=[];}
function save(){try{localStorage.setItem('ipad_dash_tasks',JSON.stringify(tasks));}catch(x){}}
function addTask(){var inp=document.getElementById('inp');var txt=(inp.value||'').replace(/^\\s+|\\s+$/g,'');if(!txt)return;tasks.unshift({id:Date.now(),text:txt,done:false});save();render();inp.value='';}
function toggle(id){for(var i=0;i<tasks.length;i++)if(tasks[i].id===id){tasks[i].done=!tasks[i].done;break;}save();render();}
function remove(id){tasks=tasks.filter(function(t){return t.id!==id;});save();render();}
function render(){
  var left=tasks.filter(function(t){return!t.done;}).length;
  document.getElementById('rem').textContent=left===0?'All done! \u2713':left+' remaining';
  var list=document.getElementById('tList');
  if(tasks.length===0){list.innerHTML='<div class="empty">No tasks yet</div>';return;}
  list.innerHTML='';
  tasks.forEach(function(t){
    var item=document.createElement('div');item.className='t-item'+(t.done?' done':'');
    var chk=document.createElement('button');chk.className='chk';chk.textContent=t.done?'\u2713':'';chk.onclick=(function(id){return function(){toggle(id);};})(t.id);
    var txt=document.createElement('div');txt.className='t-txt';txt.textContent=t.text;
    var del=document.createElement('button');del.className='del';del.textContent='\u2715';del.onclick=(function(id){return function(){remove(id);};})(t.id);
    item.appendChild(chk);item.appendChild(txt);item.appendChild(del);list.appendChild(item);
  });
}
document.getElementById('inp').addEventListener('keydown',function(e){if(e.keyCode===13)addTask();});
render();
</script>
</body>
</html>
"""
    }
}
