import UIKit
import WebKit
import UniformTypeIdentifiers

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = DashboardViewController()
        window?.makeKeyAndVisible()
        UIApplication.shared.isIdleTimerDisabled = true
        return true
    }
}

class DashboardViewController: UIViewController, WKNavigationDelegate, UIDocumentPickerDelegate {

    var webView: WKWebView!
    var toolbar: UIView!
    var toolbarTimer: Timer?
    let htmlKey = "saved_dashboard_html"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupWebView()
        setupToolbar()
        loadSavedHTML()
    }

    func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.backgroundColor = .black
        webView.isOpaque = true
        view.addSubview(webView)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tap.cancelsTouchesInView = false
        webView.addGestureRecognizer(tap)
    }

    func setupToolbar() {
        toolbar = UIView()
        toolbar.backgroundColor = UIColor(red: 0.06, green: 0.1, blue: 0.15, alpha: 0.95)
        toolbar.layer.cornerRadius = 14
        toolbar.layer.borderWidth = 1
        toolbar.layer.borderColor = UIColor(red: 0, green: 1, blue: 0.78, alpha: 0.4).cgColor
        toolbar.alpha = 0
        view.addSubview(toolbar)

        let importBtn = makeButton(title: "Import HTML", color: UIColor(red: 0, green: 1, blue: 0.78, alpha: 1))
        importBtn.addTarget(self, action: #selector(importHTML), for: .touchUpInside)

        let defaultBtn = makeButton(title: "Load Default", color: UIColor(red: 0.5, green: 0.7, blue: 1.0, alpha: 1))
        defaultBtn.addTarget(self, action: #selector(loadDefault), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [importBtn, defaultBtn])
        stack.axis = .horizontal
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(stack)

        toolbar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            toolbar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            toolbar.heightAnchor.constraint(equalToConstant: 56),
            stack.centerXAnchor.constraint(equalTo: toolbar.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -16),
        ])
    }

    func makeButton(title: String, color: UIColor) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.setTitleColor(color, for: .normal)
        btn.titleLabel?.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
        btn.backgroundColor = color.withAlphaComponent(0.12)
        btn.layer.cornerRadius = 10
        btn.layer.borderWidth = 1
        btn.layer.borderColor = color.withAlphaComponent(0.35).cgColor
        btn.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
        return btn
    }

    @objc func handleTap() {
        toolbar.alpha == 0 ? showToolbar() : hideToolbar()
    }

    func showToolbar() {
        toolbarTimer?.invalidate()
        UIView.animate(withDuration: 0.3) { self.toolbar.alpha = 1 }
        toolbarTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in self.hideToolbar() }
    }

    func hideToolbar() {
        toolbarTimer?.invalidate()
        UIView.animate(withDuration: 0.3) { self.toolbar.alpha = 0 }
    }

    @objc func importHTML() {
        hideToolbar()
        let picker: UIDocumentPickerViewController
        if #available(iOS 14.0, *) {
            picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.html])
        } else {
            picker = UIDocumentPickerViewController(documentTypes: ["public.html"], in: .import)
        }
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        do {
            let html = try String(contentsOf: url, encoding: .utf8)
            UserDefaults.standard.set(html, forKey: htmlKey)
            webView.loadHTMLString(html, baseURL: nil)
            showToast(message: "HTML imported!")
        } catch {
            showToast(message: "Failed to read file")
        }
    }

    func loadSavedHTML() {
        if let saved = UserDefaults.standard.string(forKey: htmlKey) {
            webView.loadHTMLString(saved, baseURL: nil)
        } else {
            webView.loadHTMLString(defaultHTML, baseURL: nil)
        }
    }

    @objc func loadDefault() {
        hideToolbar()
        UserDefaults.standard.removeObject(forKey: htmlKey)
        webView.loadHTMLString(defaultHTML, baseURL: nil)
        showToast(message: "Default loaded")
    }

    func showToast(message: String) {
        let toast = UILabel()
        toast.text = message
        toast.textColor = .white
        toast.backgroundColor = UIColor(red: 0.06, green: 0.1, blue: 0.15, alpha: 0.95)
        toast.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        toast.textAlignment = .center
        toast.layer.cornerRadius = 10
        toast.clipsToBounds = true
        toast.alpha = 0
        toast.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            toast.heightAnchor.constraint(equalToConstant: 36),
            toast.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),
        ])
        UIView.animate(withDuration: 0.3, animations: { toast.alpha = 1 }) { _ in
            UIView.animate(withDuration: 0.4, delay: 2.0, animations: { toast.alpha = 0 }) { _ in
                toast.removeFromSuperview()
            }
        }
    }

    override var prefersStatusBarHidden: Bool { return true }
    override var prefersHomeIndicatorAutoHidden: Bool { return true }

    // NOTE: HTML is stored in a separate property to avoid Swift string escape issues
    var defaultHTML: String {
        return buildDefaultHTML()
    }

    func buildDefaultHTML() -> String {
        var html = ""
        html += "<!DOCTYPE html><html lang='en'><head>"
        html += "<meta charset='UTF-8'>"
        html += "<meta name='viewport' content='width=device-width, initial-scale=1.0, user-scalable=no'>"
        html += "<style>"
        html += "*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}"
        html += ":root{"
        html += "--bg:#060a0f;--panel:rgba(255,255,255,0.05);--border:rgba(0,255,200,0.18);"
        html += "--accent:#00ffc8;--accent2:#00aaff;--text:#e8f4f0;--muted:rgba(232,244,240,0.4)}"
        html += "html,body{width:100%;height:100%;background:var(--bg);color:var(--text);"
        html += "font-family:-apple-system,'Helvetica Neue',Arial,sans-serif;"
        html += "overflow:hidden;-webkit-user-select:none;}"
        html += "body{background-image:"
        html += "radial-gradient(ellipse at 15% 50%,rgba(0,255,200,0.07) 0%,transparent 55%),"
        html += "radial-gradient(ellipse at 85% 15%,rgba(0,170,255,0.07) 0%,transparent 55%);}"
        html += "body::before{content:'';position:fixed;inset:0;"
        html += "background:repeating-linear-gradient(0deg,transparent,transparent 3px,rgba(0,0,0,0.06) 3px,rgba(0,0,0,0.06) 4px);"
        html += "pointer-events:none;z-index:999;}"
        html += ".grid{display:grid;grid-template-columns:1fr 1fr;grid-template-rows:auto 1fr;"
        html += "gap:12px;padding:14px;height:100vh;width:100vw;}"
        html += ".clock-panel{grid-column:1;grid-row:1;background:var(--panel);border:1px solid var(--border);"
        html += "border-radius:14px;padding:18px 22px;display:flex;flex-direction:column;"
        html += "justify-content:center;position:relative;overflow:hidden;}"
        html += ".clock-panel::after{content:'';position:absolute;top:0;left:10%;right:10%;height:1px;"
        html += "background:linear-gradient(90deg,transparent,var(--accent),transparent);}"
        html += ".time-row{display:flex;align-items:baseline;}"
        html += ".tnum{font-family:'Courier New',monospace;font-size:60px;font-weight:bold;"
        html += "color:var(--accent);text-shadow:0 0 20px rgba(0,255,200,0.55);line-height:1;}"
        html += ".colon{font-family:'Courier New',monospace;font-size:60px;font-weight:bold;"
        html += "color:var(--accent);line-height:1;width:22px;text-align:center;"
        html += "animation:blink 1s step-end infinite;}"
        html += ".ampm{font-family:'Courier New',monospace;font-size:18px;font-weight:bold;"
        html += "color:var(--accent2);margin-left:8px;align-self:flex-start;margin-top:10px;}"
        html += "@keyframes blink{0%,100%{opacity:1}50%{opacity:0}}"
        html += ".date-str{margin-top:8px;font-size:12px;color:var(--muted);letter-spacing:0.12em;text-transform:uppercase;}"
        html += ".cal-panel{grid-column:2;grid-row:1;background:var(--panel);border:1px solid var(--border);"
        html += "border-radius:14px;padding:14px 16px;display:flex;flex-direction:column;"
        html += "position:relative;overflow:hidden;}"
        html += ".cal-panel::after{content:'';position:absolute;top:0;left:10%;right:10%;height:1px;"
        html += "background:linear-gradient(90deg,transparent,var(--accent2),transparent);}"
        html += ".cal-head{display:flex;justify-content:space-between;align-items:center;margin-bottom:8px;}"
        html += ".cal-lbl{font-family:'Courier New',monospace;font-size:13px;font-weight:bold;"
        html += "color:var(--accent2);letter-spacing:0.1em;text-transform:uppercase;}"
        html += ".nav-wrap{display:flex;gap:6px;}"
        html += ".nav-btn{background:rgba(0,170,255,0.1);border:1px solid rgba(0,170,255,0.3);"
        html += "color:var(--accent2);border-radius:6px;width:28px;height:28px;font-size:18px;"
        html += "cursor:pointer;display:flex;align-items:center;justify-content:center;}"
        html += ".cal-grid{display:grid;grid-template-columns:repeat(7,1fr);gap:2px;flex:1;}"
        html += ".dn{text-align:center;font-size:10px;color:var(--muted);font-weight:600;padding:2px 0 4px;}"
        html += ".dc{text-align:center;font-size:12px;padding:5px 2px;border-radius:5px;"
        html += "color:rgba(232,244,240,0.55);display:flex;align-items:center;justify-content:center;}"
        html += ".dc.other{color:rgba(255,255,255,0.14);}"
        html += ".dc.today{background:var(--accent);color:#060a0f;font-weight:700;"
        html += "border-radius:50%;box-shadow:0 0 10px rgba(0,255,200,0.5);}"
        html += ".todo-panel{grid-column:1/3;grid-row:2;background:var(--panel);border:1px solid var(--border);"
        html += "border-radius:14px;padding:14px 18px;display:flex;flex-direction:column;"
        html += "position:relative;overflow:hidden;}"
        html += ".todo-panel::after{content:'';position:absolute;top:0;left:10%;right:10%;height:1px;"
        html += "background:linear-gradient(90deg,transparent,var(--accent),var(--accent2),transparent);}"
        html += ".todo-hdr{display:flex;justify-content:space-between;align-items:center;margin-bottom:10px;}"
        html += ".todo-ttl{font-family:'Courier New',monospace;font-size:12px;font-weight:bold;"
        html += "color:var(--accent);letter-spacing:0.12em;text-transform:uppercase;}"
        html += ".todo-rem{font-size:11px;color:var(--muted);}"
        html += ".inp-row{display:flex;gap:8px;margin-bottom:10px;}"
        html += ".t-inp{flex:1;background:rgba(255,255,255,0.05);border:1px solid rgba(0,255,200,0.22);"
        html += "border-radius:8px;padding:9px 12px;color:var(--text);font-size:14px;outline:none;}"
        html += ".t-inp::placeholder{color:var(--muted);}"
        html += ".add-b{background:rgba(0,255,200,0.12);border:1px solid rgba(0,255,200,0.35);"
        html += "color:var(--accent);border-radius:8px;padding:9px 16px;"
        html += "font-family:'Courier New',monospace;font-size:12px;font-weight:bold;cursor:pointer;white-space:nowrap;}"
        html += ".t-list{flex:1;overflow-y:auto;display:flex;flex-direction:column;gap:6px;-webkit-overflow-scrolling:touch;}"
        html += ".t-item{display:flex;align-items:center;gap:10px;padding:9px 10px;"
        html += "background:rgba(255,255,255,0.03);border:1px solid rgba(255,255,255,0.06);border-radius:8px;}"
        html += ".t-item.done{opacity:0.4;}"
        html += ".chk{width:20px;height:20px;border-radius:50%;border:1.5px solid rgba(0,255,200,0.4);"
        html += "background:transparent;cursor:pointer;flex-shrink:0;display:flex;"
        html += "align-items:center;justify-content:center;font-size:11px;color:var(--accent);}"
        html += ".t-item.done .chk{background:rgba(0,255,200,0.2);border-color:var(--accent);}"
        html += ".t-txt{flex:1;font-size:14px;color:var(--text);}"
        html += ".t-item.done .t-txt{text-decoration:line-through;color:var(--muted);}"
        html += ".del{background:none;border:none;color:rgba(255,80,80,0.4);cursor:pointer;font-size:15px;padding:2px 5px;}"
        html += ".empty{text-align:center;color:var(--muted);font-size:13px;padding:18px;font-style:italic;}"
        html += ".hint{position:fixed;bottom:70px;left:50%;transform:translateX(-50%);"
        html += "font-size:11px;color:rgba(255,255,255,0.2);letter-spacing:0.08em;pointer-events:none;}"
        html += "</style></head><body>"
        html += "<div class='grid'>"
        html += "<div class='clock-panel'>"
        html += "<div class='time-row'>"
        html += "<span class='tnum' id='hh'>12</span><span class='colon'>:</span>"
        html += "<span class='tnum' id='mm'>00</span><span class='colon'>:</span>"
        html += "<span class='tnum' id='ss'>00</span>"
        html += "<span class='ampm' id='ap'>AM</span>"
        html += "</div>"
        html += "<div class='date-str' id='ds'>Loading...</div>"
        html += "</div>"
        html += "<div class='cal-panel'>"
        html += "<div class='cal-head'>"
        html += "<div class='cal-lbl' id='calLbl'>--</div>"
        html += "<div class='nav-wrap'>"
        html += "<button class='nav-btn' onclick='shiftMonth(-1)'>&#8249;</button>"
        html += "<button class='nav-btn' onclick='shiftMonth(1)'>&#8250;</button>"
        html += "</div></div>"
        html += "<div class='cal-grid' id='calGrid'></div>"
        html += "</div>"
        html += "<div class='todo-panel'>"
        html += "<div class='todo-hdr'>"
        html += "<div class='todo-ttl'>Tasks</div>"
        html += "<div class='todo-rem' id='rem'>0 remaining</div>"
        html += "</div>"
        html += "<div class='inp-row'>"
        html += "<input class='t-inp' id='inp' type='text' placeholder='Add a new task...' maxlength='80'>"
        html += "<button class='add-b' onclick='addTask()'>+ ADD</button>"
        html += "</div>"
        html += "<div class='t-list' id='tList'></div>"
        html += "</div></div>"
        html += "<div class='hint'>TAP SCREEN TO IMPORT HTML</div>"
        html += "<script>"
        html += "var DAYS=['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];"
        html += "var MONS=['January','February','March','April','May','June','July','August','September','October','November','December'];"
        html += "function pad(n){return n<10?'0'+n:''+n;}"
        html += "function tick(){"
        html += "var n=new Date(),h=n.getHours(),m=n.getMinutes(),s=n.getSeconds();"
        html += "var ap=h>=12?'PM':'AM';h=h%12||12;"
        html += "document.getElementById('hh').textContent=pad(h);"
        html += "document.getElementById('mm').textContent=pad(m);"
        html += "document.getElementById('ss').textContent=pad(s);"
        html += "document.getElementById('ap').textContent=ap;"
        html += "document.getElementById('ds').textContent=DAYS[n.getDay()]+' - '+MONS[n.getMonth()]+' '+n.getDate()+', '+n.getFullYear();"
        html += "}"
        html += "setInterval(tick,1000);tick();"
        html += "var today=new Date(),cY=today.getFullYear(),cM=today.getMonth();"
        html += "function shiftMonth(d){cM+=d;if(cM>11){cM=0;cY++;}if(cM<0){cM=11;cY--;}buildCal();}"
        html += "function buildCal(){"
        html += "document.getElementById('calLbl').textContent=MONS[cM]+' '+cY;"
        html += "var g=document.getElementById('calGrid');g.innerHTML='';"
        html += "['Su','Mo','Tu','We','Th','Fr','Sa'].forEach(function(d){var e=document.createElement('div');e.className='dn';e.textContent=d;g.appendChild(e);});"
        html += "var first=new Date(cY,cM,1).getDay(),dim=new Date(cY,cM+1,0).getDate(),dip=new Date(cY,cM,0).getDate();"
        html += "var i,e;"
        html += "for(i=0;i<first;i++){e=document.createElement('div');e.className='dc other';e.textContent=dip-first+1+i;g.appendChild(e);}"
        html += "for(i=1;i<=dim;i++){e=document.createElement('div');e.className='dc';e.textContent=i;"
        html += "if(i===today.getDate()&&cM===today.getMonth()&&cY===today.getFullYear())e.className+=' today';"
        html += "g.appendChild(e);}"
        html += "for(i=1;i<=42-first-dim;i++){e=document.createElement('div');e.className='dc other';e.textContent=i;g.appendChild(e);}"
        html += "}"
        html += "buildCal();"
        html += "var tasks=[];try{tasks=JSON.parse(localStorage.getItem('dash_tasks')||'[]');}catch(x){tasks=[];}"
        html += "function save(){try{localStorage.setItem('dash_tasks',JSON.stringify(tasks));}catch(x){}}"
        html += "function addTask(){var inp=document.getElementById('inp');var txt=(inp.value||'').trim();if(!txt)return;tasks.unshift({id:Date.now(),text:txt,done:false});save();render();inp.value='';}"
        html += "function toggle(id){for(var i=0;i<tasks.length;i++)if(tasks[i].id===id){tasks[i].done=!tasks[i].done;break;}save();render();}"
        html += "function remove(id){tasks=tasks.filter(function(t){return t.id!==id;});save();render();}"
        html += "function render(){"    
        html += "var left=tasks.filter(function(t){return!t.done;}).length;"
        html += "document.getElementById('rem').textContent=left===0?'All done!':left+' remaining';"
        html += "var list=document.getElementById('tList');"
        html += "if(tasks.length===0){list.innerHTML='<div class=\"empty\">No tasks yet</div>';return;}"
        html += "list.innerHTML='';"
        html += "tasks.forEach(function(t){"
        html += "var item=document.createElement('div');item.className='t-item'+(t.done?' done':'');"
        html += "var chk=document.createElement('button');chk.className='chk';chk.textContent=t.done?'v':'';chk.onclick=(function(id){return function(){toggle(id);};})(t.id);"
        html += "var txt=document.createElement('div');txt.className='t-txt';txt.textContent=t.text;"
        html += "var del=document.createElement('button');del.className='del';del.textContent='x';del.onclick=(function(id){return function(){remove(id);};})(t.id);"
        html += "item.appendChild(chk);item.appendChild(txt);item.appendChild(del);list.appendChild(item);"
        html += "});}"
        html += "document.getElementById('inp').addEventListener('keydown',function(e){if(e.keyCode===13)addTask();});"
        html += "render();"
        html += "</script></body></html>"
        return html
    }
}
