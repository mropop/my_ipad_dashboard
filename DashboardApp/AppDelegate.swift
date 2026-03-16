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
    var floatBtn: UIButton!       // always-visible small button
    var toolbar: UIView!          // expanded toolbar
    var isToolbarVisible = false
    let htmlKey = "saved_dashboard_html"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupWebView()
        setupFloatButton()
        setupToolbar()
        loadSavedHTML()
    }

    // MARK: - WebView (fills entire screen)
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
    }

    // MARK: - Small floating button (always on top, top-right corner)
    func setupFloatButton() {
        floatBtn = UIButton(type: .system)
        floatBtn.setTitle("☰", for: .normal)
        floatBtn.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        floatBtn.setTitleColor(UIColor(red: 0, green: 1, blue: 0.78, alpha: 0.6), for: .normal)
        floatBtn.backgroundColor = UIColor(white: 0, alpha: 0.4)
        floatBtn.layer.cornerRadius = 18
        floatBtn.layer.borderWidth = 1
        floatBtn.layer.borderColor = UIColor(red: 0, green: 1, blue: 0.78, alpha: 0.25).cgColor
        floatBtn.translatesAutoresizingMaskIntoConstraints = false
        floatBtn.addTarget(self, action: #selector(toggleToolbar), for: .touchUpInside)
        view.addSubview(floatBtn)

        NSLayoutConstraint.activate([
            floatBtn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            floatBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            floatBtn.widthAnchor.constraint(equalToConstant: 36),
            floatBtn.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    // MARK: - Expanded toolbar (appears below float button)
    func setupToolbar() {
        toolbar = UIView()
        toolbar.backgroundColor = UIColor(red: 0.05, green: 0.08, blue: 0.12, alpha: 0.97)
        toolbar.layer.cornerRadius = 14
        toolbar.layer.borderWidth = 1
        toolbar.layer.borderColor = UIColor(red: 0, green: 1, blue: 0.78, alpha: 0.35).cgColor
        toolbar.layer.shadowColor = UIColor.black.cgColor
        toolbar.layer.shadowOpacity = 0.6
        toolbar.layer.shadowRadius = 12
        toolbar.isHidden = true
        toolbar.alpha = 0
        view.addSubview(toolbar)

        let importBtn = makeToolbarButton(title: "📂  Import HTML", color: UIColor(red: 0, green: 1, blue: 0.78, alpha: 1))
        importBtn.addTarget(self, action: #selector(importHTML), for: .touchUpInside)

        let defaultBtn = makeToolbarButton(title: "↺  Load Default", color: UIColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1))
        defaultBtn.addTarget(self, action: #selector(loadDefault), for: .touchUpInside)

        let closeBtn = makeToolbarButton(title: "✕  Close", color: UIColor(red: 1, green: 0.4, blue: 0.4, alpha: 1))
        closeBtn.addTarget(self, action: #selector(toggleToolbar), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [importBtn, defaultBtn, closeBtn])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(stack)

        toolbar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: floatBtn.bottomAnchor, constant: 8),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            toolbar.widthAnchor.constraint(equalToConstant: 200),
            stack.topAnchor.constraint(equalTo: toolbar.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -12),
        ])
    }

    func makeToolbarButton(title: String, color: UIColor) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.setTitleColor(color, for: .normal)
        btn.contentHorizontalAlignment = .left
        btn.titleLabel?.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        btn.backgroundColor = color.withAlphaComponent(0.1)
        btn.layer.cornerRadius = 8
        btn.layer.borderWidth = 1
        btn.layer.borderColor = color.withAlphaComponent(0.3).cgColor
        btn.contentEdgeInsets = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        return btn
    }

    // MARK: - Toggle toolbar
    @objc func toggleToolbar() {
        if isToolbarVisible {
            UIView.animate(withDuration: 0.2, animations: {
                self.toolbar.alpha = 0
            }) { _ in
                self.toolbar.isHidden = true
            }
        } else {
            toolbar.isHidden = false
            UIView.animate(withDuration: 0.2) {
                self.toolbar.alpha = 1
            }
        }
        isToolbarVisible = !isToolbarVisible
    }

    // MARK: - Import HTML
    @objc func importHTML() {
        toggleToolbar()
        let picker: UIDocumentPickerViewController
        if #available(iOS 14.0, *) {
            // Accept html, text, and public.data so .html files are always selectable
            picker = UIDocumentPickerViewController(forOpeningContentTypes: [
                UTType.html,
                UTType.text,
                UTType.plainText,
                UTType.data
            ])
        } else {
            picker = UIDocumentPickerViewController(documentTypes: [
                "public.html",
                "public.text",
                "public.plain-text",
                "public.data"
            ], in: .import)
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
            showToast(message: "✅  HTML imported!")
        } catch {
            showToast(message: "❌  Failed to read file")
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        // do nothing
    }

    // MARK: - Load HTML
    func loadSavedHTML() {
        if let saved = UserDefaults.standard.string(forKey: htmlKey) {
            webView.loadHTMLString(saved, baseURL: nil)
        } else {
            webView.loadHTMLString(buildDefaultHTML(), baseURL: nil)
        }
    }

    @objc func loadDefault() {
        toggleToolbar()
        UserDefaults.standard.removeObject(forKey: htmlKey)
        webView.loadHTMLString(buildDefaultHTML(), baseURL: nil)
        showToast(message: "↺  Default loaded")
    }

    // MARK: - Toast
    func showToast(message: String) {
        let toast = UILabel()
        toast.text = "  " + message + "  "
        toast.textColor = .white
        toast.backgroundColor = UIColor(red: 0.05, green: 0.08, blue: 0.12, alpha: 0.97)
        toast.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        toast.textAlignment = .center
        toast.layer.cornerRadius = 10
        toast.layer.borderWidth = 1
        toast.layer.borderColor = UIColor(red: 0, green: 1, blue: 0.78, alpha: 0.3).cgColor
        toast.clipsToBounds = true
        toast.alpha = 0
        toast.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            toast.heightAnchor.constraint(equalToConstant: 38),
        ])
        UIView.animate(withDuration: 0.25, animations: { toast.alpha = 1 }) { _ in
            UIView.animate(withDuration: 0.3, delay: 2.2, animations: { toast.alpha = 0 }) { _ in
                toast.removeFromSuperview()
            }
        }
    }

    override var prefersStatusBarHidden: Bool { return true }
    override var prefersHomeIndicatorAutoHidden: Bool { return true }

    // MARK: - Default HTML
    func buildDefaultHTML() -> String {
        var h = ""
        h += "<!DOCTYPE html><html lang='en'><head>"
        h += "<meta charset='UTF-8'>"
        h += "<meta name='viewport' content='width=device-width,initial-scale=1.0,user-scalable=no'>"
        h += "<style>"
        h += "*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}"
        h += ":root{--bg:#060a0f;--panel:rgba(255,255,255,0.05);--border:rgba(0,255,200,0.18);"
        h += "--accent:#00ffc8;--accent2:#00aaff;--text:#e8f4f0;--muted:rgba(232,244,240,0.4)}"
        h += "html,body{width:100%;height:100%;background:var(--bg);color:var(--text);"
        h += "font-family:-apple-system,'Helvetica Neue',Arial,sans-serif;overflow:hidden;-webkit-user-select:none}"
        h += "body{background-image:radial-gradient(ellipse at 15% 50%,rgba(0,255,200,0.07) 0%,transparent 55%),"
        h += "radial-gradient(ellipse at 85% 15%,rgba(0,170,255,0.07) 0%,transparent 55%)}"
        h += "body::before{content:'';position:fixed;inset:0;background:repeating-linear-gradient(0deg,transparent,transparent 3px,rgba(0,0,0,0.06) 3px,rgba(0,0,0,0.06) 4px);pointer-events:none;z-index:999}"
        h += ".grid{display:grid;grid-template-columns:1fr 1fr;grid-template-rows:auto 1fr;gap:12px;padding:14px;height:100vh;width:100vw}"
        h += ".clock-panel{grid-column:1;grid-row:1;background:var(--panel);border:1px solid var(--border);border-radius:14px;padding:18px 22px;display:flex;flex-direction:column;justify-content:center;position:relative;overflow:hidden}"
        h += ".clock-panel::after{content:'';position:absolute;top:0;left:10%;right:10%;height:1px;background:linear-gradient(90deg,transparent,var(--accent),transparent)}"
        h += ".time-row{display:flex;align-items:baseline}"
        h += ".tnum{font-family:'Courier New',monospace;font-size:60px;font-weight:bold;color:var(--accent);text-shadow:0 0 20px rgba(0,255,200,0.55);line-height:1}"
        h += ".colon{font-family:'Courier New',monospace;font-size:60px;font-weight:bold;color:var(--accent);line-height:1;width:22px;text-align:center;animation:blink 1s step-end infinite}"
        h += ".ampm{font-family:'Courier New',monospace;font-size:18px;font-weight:bold;color:var(--accent2);margin-left:8px;align-self:flex-start;margin-top:10px}"
        h += "@keyframes blink{0%,100%{opacity:1}50%{opacity:0}}"
        h += ".date-str{margin-top:8px;font-size:12px;color:var(--muted);letter-spacing:0.12em;text-transform:uppercase}"
        h += ".cal-panel{grid-column:2;grid-row:1;background:var(--panel);border:1px solid var(--border);border-radius:14px;padding:14px 16px;display:flex;flex-direction:column;position:relative;overflow:hidden}"
        h += ".cal-panel::after{content:'';position:absolute;top:0;left:10%;right:10%;height:1px;background:linear-gradient(90deg,transparent,var(--accent2),transparent)}"
        h += ".cal-head{display:flex;justify-content:space-between;align-items:center;margin-bottom:8px}"
        h += ".cal-lbl{font-family:'Courier New',monospace;font-size:13px;font-weight:bold;color:var(--accent2);letter-spacing:0.1em;text-transform:uppercase}"
        h += ".nav-wrap{display:flex;gap:6px}"
        h += ".nav-btn{background:rgba(0,170,255,0.1);border:1px solid rgba(0,170,255,0.3);color:var(--accent2);border-radius:6px;width:28px;height:28px;font-size:18px;cursor:pointer;display:flex;align-items:center;justify-content:center}"
        h += ".cal-grid{display:grid;grid-template-columns:repeat(7,1fr);gap:2px;flex:1}"
        h += ".dn{text-align:center;font-size:10px;color:var(--muted);font-weight:600;padding:2px 0 4px}"
        h += ".dc{text-align:center;font-size:12px;padding:5px 2px;border-radius:5px;color:rgba(232,244,240,0.55);display:flex;align-items:center;justify-content:center}"
        h += ".dc.other{color:rgba(255,255,255,0.14)}"
        h += ".dc.today{background:var(--accent);color:#060a0f;font-weight:700;border-radius:50%;box-shadow:0 0 10px rgba(0,255,200,0.5)}"
        h += ".todo-panel{grid-column:1/3;grid-row:2;background:var(--panel);border:1px solid var(--border);border-radius:14px;padding:14px 18px;display:flex;flex-direction:column;position:relative;overflow:hidden}"
        h += ".todo-panel::after{content:'';position:absolute;top:0;left:10%;right:10%;height:1px;background:linear-gradient(90deg,transparent,var(--accent),var(--accent2),transparent)}"
        h += ".todo-hdr{display:flex;justify-content:space-between;align-items:center;margin-bottom:10px}"
        h += ".todo-ttl{font-family:'Courier New',monospace;font-size:12px;font-weight:bold;color:var(--accent);letter-spacing:0.12em;text-transform:uppercase}"
        h += ".todo-rem{font-size:11px;color:var(--muted)}"
        h += ".inp-row{display:flex;gap:8px;margin-bottom:10px}"
        h += ".t-inp{flex:1;background:rgba(255,255,255,0.05);border:1px solid rgba(0,255,200,0.22);border-radius:8px;padding:9px 12px;color:var(--text);font-size:14px;outline:none}"
        h += ".t-inp::placeholder{color:var(--muted)}"
        h += ".add-b{background:rgba(0,255,200,0.12);border:1px solid rgba(0,255,200,0.35);color:var(--accent);border-radius:8px;padding:9px 16px;font-family:'Courier New',monospace;font-size:12px;font-weight:bold;cursor:pointer;white-space:nowrap}"
        h += ".t-list{flex:1;overflow-y:auto;display:flex;flex-direction:column;gap:6px;-webkit-overflow-scrolling:touch}"
        h += ".t-item{display:flex;align-items:center;gap:10px;padding:9px 10px;background:rgba(255,255,255,0.03);border:1px solid rgba(255,255,255,0.06);border-radius:8px}"
        h += ".t-item.done{opacity:0.4}"
        h += ".chk{width:20px;height:20px;border-radius:50%;border:1.5px solid rgba(0,255,200,0.4);background:transparent;cursor:pointer;flex-shrink:0;display:flex;align-items:center;justify-content:center;font-size:11px;color:var(--accent)}"
        h += ".t-item.done .chk{background:rgba(0,255,200,0.2);border-color:var(--accent)}"
        h += ".t-txt{flex:1;font-size:14px;color:var(--text)}"
        h += ".t-item.done .t-txt{text-decoration:line-through;color:var(--muted)}"
        h += ".del{background:none;border:none;color:rgba(255,80,80,0.4);cursor:pointer;font-size:15px;padding:2px 5px}"
        h += ".empty{text-align:center;color:var(--muted);font-size:13px;padding:18px;font-style:italic}"
        h += "</style></head><body>"
        h += "<div class='grid'>"
        h += "<div class='clock-panel'><div class='time-row'>"
        h += "<span class='tnum' id='hh'>12</span><span class='colon'>:</span>"
        h += "<span class='tnum' id='mm'>00</span><span class='colon'>:</span>"
        h += "<span class='tnum' id='ss'>00</span><span class='ampm' id='ap'>AM</span>"
        h += "</div><div class='date-str' id='ds'>Loading...</div></div>"
        h += "<div class='cal-panel'><div class='cal-head'>"
        h += "<div class='cal-lbl' id='calLbl'>--</div>"
        h += "<div class='nav-wrap'>"
        h += "<button class='nav-btn' onclick='shiftMonth(-1)'>&#8249;</button>"
        h += "<button class='nav-btn' onclick='shiftMonth(1)'>&#8250;</button>"
        h += "</div></div><div class='cal-grid' id='calGrid'></div></div>"
        h += "<div class='todo-panel'><div class='todo-hdr'>"
        h += "<div class='todo-ttl'>Tasks</div>"
        h += "<div class='todo-rem' id='rem'>0 remaining</div></div>"
        h += "<div class='inp-row'>"
        h += "<input class='t-inp' id='inp' type='text' placeholder='Add a new task...' maxlength='80'>"
        h += "<button class='add-b' onclick='addTask()'>+ ADD</button>"
        h += "</div><div class='t-list' id='tList'></div></div>"
        h += "</div>"
        h += "<script>"
        h += "var DAYS=['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];"
        h += "var MONS=['January','February','March','April','May','June','July','August','September','October','November','December'];"
        h += "function pad(n){return n<10?'0'+n:''+n}"
        h += "function tick(){var n=new Date(),h=n.getHours(),m=n.getMinutes(),s=n.getSeconds();"
        h += "var ap=h>=12?'PM':'AM';h=h%12||12;"
        h += "document.getElementById('hh').textContent=pad(h);"
        h += "document.getElementById('mm').textContent=pad(m);"
        h += "document.getElementById('ss').textContent=pad(s);"
        h += "document.getElementById('ap').textContent=ap;"
        h += "document.getElementById('ds').textContent=DAYS[n.getDay()]+' - '+MONS[n.getMonth()]+' '+n.getDate()+', '+n.getFullYear();}"
        h += "setInterval(tick,1000);tick();"
        h += "var today=new Date(),cY=today.getFullYear(),cM=today.getMonth();"
        h += "function shiftMonth(d){cM+=d;if(cM>11){cM=0;cY++;}if(cM<0){cM=11;cY--;}buildCal();}"
        h += "function buildCal(){document.getElementById('calLbl').textContent=MONS[cM]+' '+cY;"
        h += "var g=document.getElementById('calGrid');g.innerHTML='';"
        h += "['Su','Mo','Tu','We','Th','Fr','Sa'].forEach(function(d){var e=document.createElement('div');e.className='dn';e.textContent=d;g.appendChild(e);});"
        h += "var first=new Date(cY,cM,1).getDay(),dim=new Date(cY,cM+1,0).getDate(),dip=new Date(cY,cM,0).getDate();"
        h += "var i,e;"
        h += "for(i=0;i<first;i++){e=document.createElement('div');e.className='dc other';e.textContent=dip-first+1+i;g.appendChild(e);}"
        h += "for(i=1;i<=dim;i++){e=document.createElement('div');e.className='dc';e.textContent=i;"
        h += "if(i===today.getDate()&&cM===today.getMonth()&&cY===today.getFullYear())e.className+=' today';"
        h += "g.appendChild(e);}"
        h += "for(i=1;i<=42-first-dim;i++){e=document.createElement('div');e.className='dc other';e.textContent=i;g.appendChild(e);}}"
        h += "buildCal();"
        h += "var tasks=[];try{tasks=JSON.parse(localStorage.getItem('dash_tasks')||'[]');}catch(x){tasks=[];}"
        h += "function save(){try{localStorage.setItem('dash_tasks',JSON.stringify(tasks));}catch(x){}}"
        h += "function addTask(){var inp=document.getElementById('inp');var txt=(inp.value||'').trim();if(!txt)return;tasks.unshift({id:Date.now(),text:txt,done:false});save();render();inp.value='';}"
        h += "function toggle(id){for(var i=0;i<tasks.length;i++)if(tasks[i].id===id){tasks[i].done=!tasks[i].done;break;}save();render();}"
        h += "function remove(id){tasks=tasks.filter(function(t){return t.id!==id;});save();render();}"
        h += "function render(){var left=tasks.filter(function(t){return!t.done;}).length;"
        h += "document.getElementById('rem').textContent=left===0?'All done!':left+' remaining';"
        h += "var list=document.getElementById('tList');"
        h += "if(tasks.length===0){list.innerHTML='<div class=\"empty\">No tasks yet</div>';return;}"
        h += "list.innerHTML='';"
        h += "tasks.forEach(function(t){var item=document.createElement('div');item.className='t-item'+(t.done?' done':'');"
        h += "var chk=document.createElement('button');chk.className='chk';chk.textContent=t.done?'v':'';chk.onclick=(function(id){return function(){toggle(id);};})(t.id);"
        h += "var txt=document.createElement('div');txt.className='t-txt';txt.textContent=t.text;"
        h += "var del=document.createElement('button');del.className='del';del.textContent='x';del.onclick=(function(id){return function(){remove(id);};})(t.id);"
        h += "item.appendChild(chk);item.appendChild(txt);item.appendChild(del);list.appendChild(item);});}"
        h += "document.getElementById('inp').addEventListener('keydown',function(e){if(e.keyCode===13)addTask();});"
        h += "render();"
        h += "</script></body></html>"
        return h
    }
}
