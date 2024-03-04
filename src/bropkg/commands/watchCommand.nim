# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import pkg/[watchout, httpx, websocketx]
import pkg/kapsis/[runtime, cli]
import std/[times, os, strutils, net, osproc,
          options, asyncdispatch, htmlgen]

from ../engine/parser import getCachePath

var hasOutput: bool

proc parseStylesheet(path, outpath, mainPath: string, isMain: bool, cflags: seq[string]) =
  display("✨ Changes detected")
  display(path, indent = 2, br="after")
  if isMain:
    if path.getFileSize > 0:
      let broCommand = execCmdEx("bro " & path & " " & outpath & " --cache")
      display(broCommand.output)
    else:
      display("Stylesheet is empty")
  else:
    let bast = execCmdEx("bro ast " & path & " " & getCachePath(path.parentDir, path))
    if bast.exitCode != 0:
      display(bast.output)
    else:
      let broCommand = execCmdEx("bro " & mainPath & " " & outpath & " "  & cflags.join(" "))
      display(broCommand.output)

proc runCommand*(v: Values) =
  var stylesheetPath: string
  var cssPath: string
  hasOutput = v.has("output")
  if v.has("style"):
    stylesheetPath = v.get("style").absolutePath()
    if not stylesheetPath.fileExists:
      display("Stylesheet does not exists")
      QuitFailure.quit
  else:
    QuitFailure.quit

  if hasOutput:
    cssPath = v.get("output")
    if cssPath.splitFile.ext != ".css":
      display("Output path missing `.css` extension\n" & cssPath)
      QuitFailure.quit
    if not cssPath.isAbsolute:
      cssPath.normalizePath
      cssPath = cssPath.absolutePath()

  var delay = 550
  if v.has("delay"):
    try:
      delay = parseInt v.get("delay")
    except ValueError:
      display("Invalid number for `delay`")
      QuitFailure.quit

  if v.flag("sync"):
    if not hasOutput:
      display("Output path is required when using --sync\n" & cssPath)
      QuitFailure.quit
    display("✨ Watching for changes...")
    display("🪄 CSS Reload & Browser Sync: http://localhost:9009", br="after")
  else:
    display("✨ Watching for changes...", br="after")

  var watchMain = @[stylesheetPath.parentDir() / "*.bass"] # only main stylsheet
  var cflags = @["cache"]
  if v.flag("min"):
    cflags.add("min")
  proc watchoutCallback(file: watchout.File) {.closure.} =
    parseStylesheet(file.getPath, cssPath, stylesheetPath, file.getPath == stylesheetPath, cflags)
  
  let broCommand = execCmdEx("bro " & stylesheetPath & " " & cssPath & " " & cflags.join(" "))
  display(broCommand.output)
  if broCommand.exitCode != 0: QuitFailure.quit
  # startThread(watchoutCallback, watchMain, delay, shouldJoinThread = v.flag("sync") == false)

  if v.flag("sync"):
    const inlineCSS = """
* {margin:0; padding:0;}
body{
  background-color: #111718;
  color: whitesmoke;
  font-size: 20px;
  font-family:sans-serif;
  margin:0;
  padding:0;
  display:grid;
}
h1 {
  margin-bottom: 15px
}

main{
  align-self:center;
  text-align:center;
  max-width:890px;
  margin:auto;
}

.sweetsyntax {
  overflow-y: scroll;
  font-weight: 500;
  border: 1px solid #EEE;
  border-radius: 20px;
  overflow: hidden;
  font-family: monospace;
  box-shadow: 0 4px 2px 2px rgba(0,0,0,.15);
  display: block;
  text-align: left;
  max-height: 350px;
  width: 750px;
  margin:auto
}

.sweetsyntax.dark-theme {
  background-color: #161f20;
  border-color: #343434;
  color:  whitesmoke;
}

.sweetsyntax ul {
  margin: 0;
  padding: 0;
  list-style: none;
  counter-reset: count;
  line-height:  normal;
}

.sweetsyntax li:last-child, .sweetsyntax li:last-child:before {
  padding-bottom: 10px !important
}

.sweetsyntax li {
  counter-increment: count;
  line-height: normal;
  font-size: 16px;
  padding: 0 4px 0 0;
  height: 30px;
  display: block;
  overflow: hidden;
  position: relative;
}

.sweetsyntax[show-lines="true"] li:before {
  content: counter(count);
  padding: 10px 10px 0;
  opacity: .2;
  min-width: 30px;
  display: inline-block;
  text-align: right;
  background: rgba(0,0,0,.6);
  min-height: 27px;
  margin-right: 5px;
}

.sweetsyntax[show-hover-line="true"] li:hover:before {
  opacity: .5;
}

/**
 * Dark Theme
 */
.sweetsyntax.dark-theme li span::selection {
  background-color: #141515;
}

.sweetsyntax.dark-theme li {
  color: whitesmoke;
}

.sweetsyntax.dark-theme[show-stripes="true"] li:nth-of-type(2n) {
  background-color: rgba(255,255,255,.025);
}
"""
    const jsSnippet = """
// BroStyle CSS Reload & Browser Syncing (development mode)
const broSocket = new WebSocket("ws://127.0.0.1:6710/ws");
var lastTimeModified = localStorage.getItem("watchout") || 0
broSocket.addEventListener("message", (e) => {
  if(parseInt(e.data) > lastTimeModified) {
    localStorage.setItem("watchout", e.data);
    lastTimeModified = e.data;
    location.reload();
  }
})
"""
    const inlineJS = """
var SweetSyntax=function(e){"use strict";class t{observerOptions=e=>({root:null,rootMargin:"0px",threshold:[0,.1,.2,.3,.4,.5,.6,.7,.8,.9,1],trackVisibility:!0,delay:100});makeObservable(e,t,s){new IntersectionObserver(s,this.observerOptions(e)).observe(e)}static elementFitsIn(e,t){let s=e=>e.getBoundingClientRect();return((e,t)=>({get collidedTop(){return s(e).top<s(t).top},get collidedBottom(){return s(e).bottom>s(t).bottom},get collidedLeft(){return s(e).left<s(t).left},get collidedRight(){return s(e).right>s(t).right},get overflowTop(){return s(t).top-s(e).top},get overflowBottom(){return s(e).bottom-s(t).bottom},get overflowLeft(){return s(t).left-s(e).left},get overflowRight(){return s(e).right-s(t).right}}))(e,t)}}const s={contains:(e,t=[])=>Array.isArray(t)?t.some((t=>e.includes(t))):e.includes(t),swapKeyValue:(e={})=>Object.fromEntries(Object.entries(e).map((e=>e.reverse()))),hasClass:(e,t)=>!!e&&e.classList.contains(t)};class r{#e=null;#t=null;#s=[];#r={};#n={lpar:"(",rpar:")",lbrk:"[",rbrk:"]",lcurl:"{",rcurl:"}",colon:":",semi:";",comma:",",dot:".",minus:"-",plus:"+",asterisk:"*",modul:"%",hash:"#",around:"@",and:"&",slash:"/",bslash:"\\"};#o={show_stripes:!0,show_lines:!0};#l;#a;#i;#c;#h;#u=!1;static#d="sweetsyntax.worker.js";static count=20;constructor(e={}){this.#e=e.selector,this.#a=new t,this.#r=e.schemas,this.#o=e.appearance??this.#o,this.#l=function(e){e.setAttribute("sweetsyntax-loaded",!0)},!0===e.enable_multithreading&&(this.#u=!0),this.#b(),this.#p()}#p(){let e=this.#o;e.show_stripes&&!0===e.show_stripes&&this.#e.setAttribute("show-stripes","true"),e.show_lines&&!0===e.show_lines&&this.#e.setAttribute("show-lines","true"),e.show_hover_line&&!0===e.show_hover_line&&this.#e.setAttribute("show-hover-line","true")}#b(){if(this.#u){let e=new Worker(r.#d);e.addEventListener("message",(e=>{var t=1;e.data.lines.forEach((e=>{let s=this.#m(e,t);this.#t.insertAdjacentElement("beforeend",s),this.#f(s),t++}))})),this.#h=new Worker(r.#d),this.#g({type:"parse.content.line",content:this.#e.textContent,syntax:this.#r},e),this.#e.textContent="",this.#t=document.createElement("ul"),this.#e.insertAdjacentElement("beforeend",this.#t),this.#l(this.#e)}}#w(e){e.length,this.#e.textContent="",this.#t=document.createElement("ul"),this.#e.insertAdjacentElement("beforeend",this.#t)}#g(e,t){return new Promise((s=>{t.postMessage(e)}))}#m(e,t){let r=document.createElement("li");return e.forEach((e=>{let n=document.createElement("span");if(n.className=`ss-${e[0]}`,s.contains(e[1],Object.values(this.#n))){let t=s.swapKeyValue(this.#n);n.classList.add(t[e[1]])}n.textContent=e[1],r.setAttribute("id",`l${t}`),r.insertAdjacentElement("beforeend",n)})),r}#f(e){let t=e.childNodes,r=t.length;for(var n=0;n<r;++n){let e=t[n];if(s.hasClass(e,"ss-nam")&&null!=e.nextSibling)s.hasClass(e.nextSibling,"lpar")?e.classList.add("ss-func"):s.hasClass(e.nextSibling,"colon")&&(e.className="ss-property");else if(s.hasClass(e,"slash")&&s.hasClass(e.nextSibling,"asterisk")){var o=null;for(e.classList.add("comment_block","start");null!==(o=o?o.nextSibling:e.nextSibling)&&!1!==s.hasClass(o,"asterisk");)o.classList.add("comment_block","start")}else if(s.hasClass(e,"ss-spc")&&s.hasClass(e.nextSibling,"asterisk")){o=null;for(e.className="comment_block body";null!==(o=o?o.nextSibling:e.nextSibling);)o.className="comment_block body"}}}#k(e,t,r){let n=t[r].classList.value;if(s.contains(n,e))for(var o=r+1;;){let s=t[o];if(void 0===s)break;s.className=Array.isArray(e)?e.join(" "):e,++o}}#v(e){this.#a.makeObservable(e,this.#e,((t,s)=>{t.forEach((t=>{if(t.isIntersecting){let e=document.createElement("li");this.#t.insertAdjacentElement("beforeend",e),s.disconnect()}t.target;let r=Math.floor(100*t.intersectionRatio);r>0?e.setAttribute("observable",r):e.setAttribute("observable",0)}))}))}}return function(e,t){if("undefined"!=typeof document)t(document);else if(e)throw new Error("no doc")}(!1,(function(e){var t=e.querySelector("head"),s=e.createElement("style");s.textContent="\n.ss-com {\n  color: #888\n}\n\n.ss-num {\n  color: #6cb6ff;\n}\n\n.ss-nam {\n  color: whitesmoke;\n}\n\n.ss-func {\n  color: lightskyblue;\n}\n\n.ss-property {\n  color: rgb(106, 150, 212)\n}\n\n.ss-key {\n  color: salmon;\n  font-weight: 600;\n}\n\n.ss-str {\n  color: rgb(205, 145, 170);\n}\n\n.ss-pct,\n.ss-pct.lpar,\n.ss-pct.rpar,\n.ss-pct.lcurl,\n.ss-pct.rcurl {\n  color: lightcoral;\n}\n\n",t.insertBefore(s,t.firstChild)})),e.init=function(e={}){if(void 0!==e.enable_multithreading&&!0===e.enable_multithreading&&!window.Worker)throw new Error("Your browser doesn't support WebWorker. Upgrade your browser, it's 2023!");let t=document.querySelectorAll(e.selector);for(var s=0;s<t.length;s++)e.selector=t[s],new r(e)},e.on=function(e,t){},Object.defineProperty(e,"__esModule",{value:!0}),e}({});
document.addEventListener('DOMContentLoaded', function() {
  SweetSyntax.init({
    selector: ".sweetsyntax",
    enable_multithreading: true,
    appearance: {
      show_stripes: false,
      show_lines: true,
      show_hover_line: true
    },
    schemas: {
      'javascript': {
        name: "JavaScript",
        assignment: '=',
        annotations: ["param", "return", "author", "year", "copyright"],
        annotations_prefix: '@',
        punctuation: [' ' , '.', ',', ';', ':', '{', '}', '(', ')', '[', ']', '+', '=', '>', '<'],
        comment_inline: "//",
        comment_block: {
          start: "/*",
          body: "*",
          end: "*/"
        },
        reserved: [
          "await", "break", "case", "catch", "class", "const", "continue", "debugger",
          "default", "delete", "do", "else", "export", "extends", "finally", "for", "from",
          "function", "if", "import", "in", "instanceof", "implements", "let", "new",
          "return", "super", "switch", "this", "throw", "true", "try", "typeof",
          "var", "void", "while", "with", "yield", 
        ],
        string: ["\"", "'"],
      }
    }
  })
})
"""
    const indexHtml = html(
      head(
        meta(charset="utf-8"),
        title("BroStyle &mdash; Browser Syncing"),
        style(inlineCSS),
      ),
      body(
        main(
          img(
            src="https://github.com/openpeeps/bro/raw/main/.github/bro.png",
            alt="BroStyle Logo", width="170px", height="170px"),
          h1("Live and running..."),
          p("CSS Reload & Browser syncing via WebSockets!"),
          `pre`(class="sweetsyntax dark-theme", style="margin:35px 0", jsSnippet),
          p(style="text-align:center",
            small("&copy; 2023 😋 LGPLv3 License"),
            br(),
            small("Made by Humans from OpenPeeps")
          )
        ),
        script(inlineJS)
      )
    )

    let cssStylesheetPath = stylesheetPath.changeFileExt("css")
    let getWorkerJS = """!function(){"use strict";const e=function(e,t={}){var n=new Set,a=new Set,s="";const d=e.length;for(var i=0;i<d;i++)if("\n"==e[i])n.add(a),a=new Set;else if(-1!=["0","1","2","3","4","5","6","7","8","9"].indexOf(e[i]))a.add(["num",e[i]]);else if(-1!=t.punctuation.indexOf(e[i]))-1==t.reserved.indexOf(s)?0!=s.length&&a.add(["nam",s]):a.add(["key",s]),a.add(["pct",e[i]]),s="";else if(-1!=['"',"'"].indexOf(e[i])){for(s+=e[i],i++;'"'!=e[i];)s+=e[i],i++;s+=e[i],a.add(["str",s]),s=""}else s+=e[i];return n};onmessage=function(t){var n;t.data.status=!1,"parse.content.line"===t.data.type&&(n={lines:e(Array.from(t.data.content),t.data.syntax.javascript)},t.data.status=!0),postMessage(n)}}();"""
    proc onRequest(req: Request) {.async.} =
      if req.httpMethod == some(HttpGet):
        case req.path.get()
        of "/":
          req.send(indexHtml)
        of "/sweetsyntax.worker.js":
          req.send(getWorkerJS)
        of "/ws":
          try:
            var ws = await newWebSocket(req)
            await ws.send($toUnix(cssStylesheetPath.getLastModificationTime))
            while ws.readyState == Open:
              await ws.send($toUnix(cssStylesheetPath.getLastModificationTime))
            ws.close()
          except WebSocketClosedError:
            echo "Socket closed"
          except WebSocketProtocolMismatchError:
            echo "Socket tried to use an unknown protocol: ", getCurrentExceptionMsg()
          except WebSocketError:
            req.send(Http404)
        else:
          req.send(Http404)
    run(onRequest, initSettings(port = 9009.Port))
  QuitSuccess.quit