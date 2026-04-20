#!/usr/bin/env python3
"""
Orbit — UAT HTML Report Generator (PM Edition)
Combines Playwright test media + RICE prioritization + interview analysis.

Usage:
  python3 scripts/generate-uat-report.py --snaps reports/screenshots/flows-compare --videos reports/videos --out reports/my-report.html
"""
import argparse, base64, os, re, json
from datetime import datetime
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--title",  default="UAT Flow Report")
parser.add_argument("--out",    default="reports/uat-report.html")
parser.add_argument("--snaps",  default="reports/screenshots/flows-compare")
parser.add_argument("--videos", default="reports/videos")
parser.add_argument("--data",   default="reports/compare-data.json")
args = parser.parse_args()

SNAP=args.snaps; VDIR=args.videos; OUT=args.out; TITLE=args.title

def b64(path,mime):
    if not os.path.exists(path): return ""
    with open(path,"rb") as f: return f"data:{mime};base64,{base64.b64encode(f.read()).decode()}"
def b64img(n): return b64(os.path.join(SNAP,n),"image/png")
def b64vid(n): return b64(os.path.join(VDIR,n),"video/webm")
def img_tag(n,cap=""):
    src=b64img(n)
    if not src: return f'<div class="no-media">Not found: {n}</div>'
    return f'<figure><img src="{src}" loading="lazy" onclick="zoom(this)" alt="{cap}"><figcaption>{cap}</figcaption></figure>'
def vid_tag(n,cap=""):
    src=b64vid(n)
    if not src: return f'<div class="no-media">No video: {n}</div>'
    return f'<figure class="vf"><video controls preload="metadata" playsinline><source src="{src}" type="video/webm"></video><figcaption>▶ {cap}</figcaption></figure>'
def pair(L,R,la="NXT",lb="RM"):
    return f'<div class="pair"><div class="side sa"><span class="sl">{la}</span>{L}</div><div class="side sb"><span class="sl">{lb}</span>{R}</div></div>'

def list_media(d,ext):
    if not os.path.isdir(d): return []
    return sorted([f for f in os.listdir(d) if f.endswith(ext)])

all_imgs=list_media(SNAP,".png"); all_vids=list_media(VDIR,".webm")
def group(files):
    g={}
    for f in files:
        m=re.match(r'^([a-z]+)-(\d+)-(.+)\.(png|webm)$',f)
        if m:
            p,n,s,e=m.groups(); g.setdefault(p,[]).append((int(n),s,f))
    return {k:sorted(v) for k,v in g.items()}
ig=group(all_imgs); vg=group(all_vids)
pref=sorted(set(list(ig.keys())+list(vg.keys())))
pa=pref[0] if pref else "nxt"; pb=pref[1] if len(pref)>1 else None
la=pa.upper(); lb=pb.upper() if pb else "B"

ai_n={}; bi_n={}; av_n={}; bv_n={}
for n,s,f in ig.get(pa,[]): ai_n.setdefault(n,[]).append(f)
for n,s,f in ig.get(pb or "",[]):bi_n.setdefault(n,[]).append(f)
for n,s,f in vg.get(pa,[]): av_n.setdefault(n,[]).append(f)
for n,s,f in vg.get(pb or "",[]):bv_n.setdefault(n,[]).append(f)
nums=sorted(set(list(ai_n)+list(bi_n)+list(av_n)+list(bv_n)))
def fname(n):
    for x,s,_ in ig.get(pa,[])+ig.get(pb or "",[]):
        if x==n: return s
    return f"flow-{n}"

FLOW_LABELS={1:"Dashboard & Audit",2:"Meta Templates",3:"Social & OG",4:"Sitemaps",5:"Schema / JSON-LD",6:"Redirections",7:"Instant Indexing",8:"LLMs.txt",9:"Status & Tools"}

now=datetime.now().strftime("%Y-%m-%d %H:%M")
total_imgs=len(all_imgs); total_vids=len(all_vids); total_flows=len(nums)

# ── RICE Data from PM toolkit run ────────────────────────────────────────────
RICE_FEATURES = [
    {"rank":1, "name":"Social meta — default OG image",    "rice":22000, "reach":11000,"impact":"HIGH",  "effort":"XS","type":"quick-win", "q":1},
    {"rank":2, "name":"LLMs.txt auto-activation on install","rice":17000, "reach":8500, "impact":"HIGH",  "effort":"XS","type":"quick-win", "q":1},
    {"rank":3, "name":"Sitemap rewrite flush on activation","rice":15000, "reach":15000,"impact":"MED",   "effort":"XS","type":"quick-win", "q":1},
    {"rank":4, "name":"Redirections — menu placement UX",   "rice":7000,  "reach":7000, "impact":"MED",   "effort":"XS","type":"quick-win", "q":1},
    {"rank":5, "name":"404 Monitor module",                 "rice":4800,  "reach":12000,"impact":"HIGH",  "effort":"M", "type":"big-bet",   "q":1},
    {"rank":6, "name":"Breadcrumbs settings",               "rice":2133,  "reach":8000, "impact":"MED",   "effort":"S", "type":"fill-in",   "q":1},
    {"rank":7, "name":"Titles & Meta per-post-type depth",  "rice":1800,  "reach":9000, "impact":"HIGH",  "effort":"L", "type":"big-bet",   "q":2},
    {"rank":8, "name":"Instant Indexing API flow",          "rice":1600,  "reach":6000, "impact":"MED",   "effort":"S", "type":"fill-in",   "q":2},
    {"rank":9, "name":"Robot Instruction UI parity",        "rice":1600,  "reach":4000, "impact":"LOW",   "effort":"XS","type":"fill-in",   "q":2},
    {"rank":10,"name":"Status & diagnostics panel",         "rice":833,   "reach":5000, "impact":"LOW",   "effort":"S", "type":"fill-in",   "q":2},
]

# ── Interview Analyzer Output ─────────────────────────────────────────────────
PAIN_POINTS = [
    ("high",   "Every serious WP site generates 404s and needs a way to track and fix them — NXT has no 404 Monitor"),
    ("high",   "LLMs.txt feature exists but /llms.txt returns 404 on fresh install — hard to promote a broken feature"),
    ("medium", "Redirections buried under Advanced tab — RankMath has it in the main menu (critical for SEO management)"),
    ("medium", "Dashboard shows only Run Checks — no module status or score visible at a glance"),
    ("medium", "Sitemap_index.xml returns 404 in RankMath UAT — needs rewrite flush, confusing for new users"),
    ("medium", "Titles & Meta depth: RM has 14 tabs with per-post-type control, NXT has one page"),
    ("medium", "Instant Indexing page shows 0 input fields — connection flow unclear vs RankMath's clear API key field"),
]

FEATURE_REQUESTS = [
    ("critical", "Redirections — move to main menu, not buried in Advanced"),
    ("high",     "404 Monitor — dedicated page for tracking and fixing broken URLs"),
    ("high",     "LLMs.txt — auto-activate on install, no manual steps for the flagship differentiator"),
    ("high",     "Per-post-type meta templates — power users need granular control"),
    ("medium",   "Dashboard module status — show what's enabled at a glance"),
    ("medium",   "Breadcrumbs settings — used by 60% of SEO-focused WP sites"),
    ("medium",   "Status/diagnostics page — for support and troubleshooting"),
    ("low",      "Instant Indexing — simplify API connection flow"),
]

SENTIMENT = {"score": -0.5, "label": "Cautiously Negative",
             "positive": 4, "negative": 12,
             "summary": "UAT exposed more gaps than strengths. Core SEO (schema, sitemap, OG) works. Discovery features (LLMs.txt) are strategic wins but not working. Missing 404 Monitor is the biggest credibility gap for professional recommendation."}

# ── Build HTML blocks ─────────────────────────────────────────────────────────

def rice_badge(t):
    m={"quick-win":("qw","Quick Win"),"big-bet":("bb","Big Bet"),"fill-in":("fi","Fill-In")}
    cls,lbl=m.get(t,("fi","—"))
    return f'<span class="rb rb-{cls}">{lbl}</span>'

def q_badge(q): return f'<span class="qb q{q}">Q{q}</span>'

RICE_TABLE = f"""
<table class="rice-tbl">
  <thead><tr>
    <th>#</th><th>Feature</th><th>RICE</th><th>Reach</th><th>Impact</th><th>Effort</th><th>Type</th><th>Quarter</th>
  </tr></thead>
  <tbody>
""" + "".join(f"""    <tr>
      <td class="rn">{f['rank']}</td>
      <td class="fn">{f['name']}</td>
      <td class="rs">{f['rice']:,}</td>
      <td class="mu">{f['reach']:,}</td>
      <td class="imp imp-{f['impact'].lower()}">{f['impact']}</td>
      <td class="mu">{f['effort']}</td>
      <td>{rice_badge(f['type'])}</td>
      <td>{q_badge(f['q'])}</td>
    </tr>\n""" for f in RICE_FEATURES) + "  </tbody></table>"

sev_icon={"high":"🔴","medium":"🟡","low":"🟢"}
PAIN_HTML = "<ul class='pp-list'>" + "".join(
    f'<li class="pp pp-{s}"><span class="sev">{sev_icon.get(s,"·")}</span><span>{t}</span></li>'
    for s,t in PAIN_POINTS) + "</ul>"

pri_icon={"critical":"🔴","high":"🟠","medium":"🟡","low":"🟢"}
REQ_HTML = "<ul class='req-list'>" + "".join(
    f'<li class="req req-{p}"><span class="pri">{pri_icon.get(p,"·")}</span><span>{t}</span></li>'
    for p,t in FEATURE_REQUESTS) + "</ul>"

score_pct = int((SENTIMENT['positive']/(SENTIMENT['positive']+SENTIMENT['negative']))*100)
score_bar_color = "#f85149" if score_pct < 40 else "#d29922" if score_pct < 65 else "#3fb950"
SENTIMENT_HTML = f"""
<div class="sent-wrap">
  <div class="sent-score">
    <div class="sent-label">{SENTIMENT['label']}</div>
    <div class="sent-bar-wrap"><div class="sent-bar" style="width:{score_pct}%;background:{score_bar_color}"></div></div>
    <div class="sent-nums"><span style="color:#3fb950">✓ {SENTIMENT['positive']} positive signals</span> &nbsp;·&nbsp; <span style="color:#f85149">✗ {SENTIMENT['negative']} negative signals</span></div>
  </div>
  <p class="sent-summary">{SENTIMENT['summary']}</p>
</div>"""

# ── Feature comparison ────────────────────────────────────────────────────────
FEATURES = [
    ("Settings Architecture",       "React SPA — 1 page, hash routing",   "Multi-page WP admin per module",      None),
    ("Dashboard",                    "SEO Audit with Run Checks",           "Module overview + quick stats",       "rm"),
    ("Meta Templates",               "✓ Per post-type (1 page)",            "✓ 14-tab panel (per post-type)",      "rm"),
    ("Social / OG Meta",             "✓ Social tab in General",             "✓ Social Meta in Titles & Meta",      None),
    ("XML Sitemap",                  "✓ sitemap.xml → 200 OK",              "✗ sitemap_index.xml → 404",           "nxt"),
    ("Schema / JSON-LD",             "✓ Org · Person · WebSite",           "✓ Org · Person · WebSite",            None),
    ("Redirections",                 "✓ Under Advanced (buried)",           "✓ Dedicated menu page + CRUD",        "rm"),
    ("404 Monitor",                  "✗ Not available",                     "✓ Dedicated admin page",              "rm"),
    ("Instant Indexing / IndexNow",  "✓ Advanced → Instant Indexing",       "✓ Standalone module",                 None),
    ("LLMs.txt (AI crawlers)",       "✓ Settings exist (404 on fresh install)", "✗ Not available",                "nxt*"),
    ("Breadcrumbs",                  "✗ Not found in nav",                  "✓ General Settings tab",              "rm"),
    ("Robots.txt Editor",            "✓ Advanced → Robots.txt Editor",      "✓ General Settings tab",              None),
    ("Image SEO",                    "✓ Advanced → Image SEO",              "✓ Within Titles & Meta",              None),
    ("Status & Diagnostics",         "✗ Import/Export only",                "✓ Full diagnostics + DB tools",       "rm"),
    ("Onboarding Wizard",            "✗ None",                              "✓ Setup wizard",                      "rm"),
    ("Role Manager",                 "✗ Not found",                         "✓ Role Manager module",               "rm"),
    ("Validation",                   "✓ Advanced → Validation",             "Via Status & Tools",                  None),
    ("Import / Export",              "✓ Dedicated tab",                     "✓ Status & Tools",                    None),
]

def f_row(feat,nv,rv,winner):
    nc = "win" if winner=="nxt" or winner=="nxt*" else ""
    rc = "win" if winner=="rm" else ""
    star = '<sup title="works but needs manual enable">*</sup>' if winner=="nxt*" else ""
    return f'<tr><td class="ff">{feat}</td><td class="{nc}">{nv}{star}</td><td class="{rc}">{rv}</td></tr>'

FEAT_TABLE = f"""<table class="ft">
  <thead><tr><th>Feature</th><th class="col-a">{la}</th><th class="col-b">{lb}</th></tr></thead>
  <tbody>
""" + "".join(f_row(*r) for r in FEATURES) + "  </tbody></table>"

# ── Flow sections ─────────────────────────────────────────────────────────────
def flow_sec(idx):
    ais=ai_n.get(idx,[]); bis=bi_n.get(idx,[])
    avs=av_n.get(idx,[]); bvs=bv_n.get(idx,[])
    label=FLOW_LABELS.get(idx, fname(idx).replace("-"," ").title())
    body=f'<p class="fl">Flow {idx} — {label}</p>'
    for i in range(max(len(ais),len(bis))):
        af=ais[i] if i<len(ais) else None; bf=bis[i] if i<len(bis) else None
        L=img_tag(af,(af or "").replace(".png","").replace("-"," ").title()) if af else '<div class="no-media">—</div>'
        R=img_tag(bf,(bf or "").replace(".png","").replace("-"," ").title()) if bf else '<div class="no-media">—</div>'
        body+=pair(L,R,la,lb)
    av=avs[0] if avs else None; bv=bvs[0] if bvs else None
    L=vid_tag(av,f"{la} — {label}") if av else '<div class="no-media">No video</div>'
    R=vid_tag(bv,f"{lb} — {label}") if bv else '<div class="no-media">No video</div>'
    body+=pair(L,R,la,lb)
    return f'<div class="sec" id="flow{idx}"><div class="sh"><span class="snum">Flow {idx}</span><h2>{label}</h2></div>{body}</div>'

flow_secs="".join(flow_sec(n) for n in nums)

# ── Nav ───────────────────────────────────────────────────────────────────────
nav='<a href="#pm">PM Priorities</a><a href="#interview">Pain Points</a><a href="#compare">Features</a><a href="#flows">Recordings</a>'
for n in nums:
    nav+=f'<a href="#flow{n}">{n}·{FLOW_LABELS.get(n,fname(n))[:18]}</a>'

# ── CSS ───────────────────────────────────────────────────────────────────────
CSS="""
:root{--bg:#0d1117;--bg2:#161b22;--bg3:#21262d;--bd:#30363d;--t:#e6edf3;--mu:#8b949e;
--g:#3fb950;--r:#f85149;--y:#d29922;--b:#58a6ff;--ca:#9b70e0;--cb:#f07050}
*{box-sizing:border-box;margin:0;padding:0}
body{background:var(--bg);color:var(--t);font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;line-height:1.65;font-size:14px}
a{color:var(--b)} code{background:var(--bg3);padding:1px 5px;border-radius:3px;font-size:12px}
sup{font-size:10px;color:var(--y);cursor:help}
.hdr{background:linear-gradient(135deg,#1a1f35,#0d1117);border-bottom:1px solid var(--bd);padding:28px 44px}
.hdr h1{font-size:24px;font-weight:700;margin-bottom:6px}
.sub{color:var(--mu);font-size:12px;margin-bottom:12px}
.badges{display:flex;gap:8px;flex-wrap:wrap}
.badge{padding:3px 10px;border-radius:12px;font-size:11px;font-weight:700}
.ba{background:rgba(155,112,224,.15);color:var(--ca);border:1px solid var(--ca)}
.bb{background:rgba(240,112,80,.15);color:var(--cb);border:1px solid var(--cb)}
.bi{background:rgba(88,166,255,.1);color:var(--b);border:1px solid rgba(88,166,255,.3)}
.bp{background:rgba(63,185,80,.1);color:var(--g);border:1px solid rgba(63,185,80,.3)}
nav{background:var(--bg2);border-bottom:1px solid var(--bd);padding:0 44px;display:flex;overflow-x:auto;position:sticky;top:0;z-index:100}
nav a{padding:11px 12px;font-size:12px;color:var(--mu);text-decoration:none;white-space:nowrap;border-bottom:2px solid transparent;transition:.15s}
nav a:hover,nav a.active{color:var(--t);border-bottom-color:var(--b)}
.wrap{max-width:1400px;margin:0 auto;padding:32px 44px}
.sec{margin-bottom:52px;scroll-margin-top:52px}
.sh{display:flex;align-items:center;gap:10px;margin-bottom:18px;padding-bottom:10px;border-bottom:1px solid var(--bd)}
.snum{background:rgba(88,166,255,.1);color:var(--b);font-size:11px;font-weight:700;padding:3px 9px;border-radius:4px}
.sh h2{font-size:18px;font-weight:700}
.sh p{color:var(--mu);font-size:13px;margin-top:3px}
.cols2{display:grid;grid-template-columns:1fr 1fr;gap:24px;margin-bottom:28px}
/* RICE table */
.rice-tbl{width:100%;border-collapse:collapse;background:var(--bg2);border-radius:10px;overflow:hidden;margin-bottom:20px}
.rice-tbl th{background:var(--bg3);padding:9px 12px;text-align:left;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.5px;color:var(--mu)}
.rice-tbl td{padding:10px 12px;border-bottom:1px solid var(--bg3);font-size:13px;vertical-align:middle}
.rice-tbl tr:last-child td{border-bottom:none}
.rice-tbl tr:hover td{background:rgba(88,166,255,.04)}
.rn{color:var(--mu);font-size:11px;width:28px}.fn{font-weight:500}
.rs{font-weight:700;color:var(--b);font-size:14px}.mu{color:var(--mu)}
.imp-high{color:var(--r);font-weight:700}.imp-med{color:var(--y);font-weight:600}.imp-low{color:var(--mu)}
.rb{font-size:10px;padding:2px 8px;border-radius:10px;font-weight:700}
.rb-qw{background:rgba(63,185,80,.15);color:var(--g)}
.rb-bb{background:rgba(248,81,73,.12);color:var(--r)}
.rb-fi{background:rgba(88,166,255,.1);color:var(--b)}
.qb{font-size:10px;padding:2px 7px;border-radius:4px;font-weight:700}
.q1{background:rgba(155,112,224,.15);color:var(--ca)}.q2{background:rgba(240,112,80,.15);color:var(--cb)}
/* Pain points */
.pp-list,.req-list{list-style:none;display:flex;flex-direction:column;gap:5px}
.pp,.req{display:flex;gap:10px;font-size:13px;padding:8px 12px;border-radius:6px;align-items:flex-start}
.pp-high{background:rgba(248,81,73,.07)}.pp-medium{background:rgba(210,153,34,.07)}.pp-low{background:rgba(63,185,80,.07)}
.req-critical{background:rgba(248,81,73,.1)}.req-high{background:rgba(240,112,80,.07)}
.req-medium{background:rgba(210,153,34,.07)}.req-low{background:rgba(63,185,80,.06)}
.sev,.pri{font-size:14px;flex-shrink:0;line-height:1.4}
/* Sentiment */
.sent-wrap{background:var(--bg2);border:1px solid var(--bd);border-radius:10px;padding:18px 22px}
.sent-label{font-weight:700;font-size:15px;margin-bottom:8px}
.sent-bar-wrap{background:var(--bg3);height:6px;border-radius:3px;margin-bottom:8px;overflow:hidden}
.sent-bar{height:6px;border-radius:3px;transition:.3s}
.sent-nums{font-size:12px;color:var(--mu);margin-bottom:10px}
.sent-summary{font-size:13px;color:var(--mu);line-height:1.7}
/* Feature table */
.ft{width:100%;border-collapse:collapse;background:var(--bg2);border-radius:10px;overflow:hidden;margin:0}
.ft th{background:var(--bg3);padding:9px 14px;text-align:left;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.5px;color:var(--mu)}
.col-a{color:var(--ca)!important}.col-b{color:var(--cb)!important}
.ft td{padding:9px 14px;border-bottom:1px solid var(--bg3);font-size:13px;vertical-align:top}
.ft tr:last-child td{border-bottom:none}
.ft td.win{color:var(--g);font-weight:600}.ff{color:var(--t);font-weight:500}
/* Media */
.pair{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:12px}
.side{background:var(--bg2);border:1px solid var(--bd);border-radius:10px;padding:10px;display:flex;flex-direction:column;gap:6px}
.sa{border-top:2px solid var(--ca)}.sb{border-top:2px solid var(--cb)}
.sl{font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.5px;padding:2px 7px;border-radius:3px;display:inline-block;margin-bottom:2px}
.sa .sl{background:rgba(155,112,224,.15);color:var(--ca)}.sb .sl{background:rgba(240,112,80,.15);color:var(--cb)}
figure{margin:0}
figure img{width:100%;border-radius:6px;border:1px solid var(--bd);cursor:zoom-in;display:block}
figure img:hover{opacity:.88}
figcaption{font-size:11px;color:var(--mu);margin-top:3px}
.vf video{width:100%;border-radius:6px;border:1px solid var(--bd);background:#000}
.no-media{padding:20px;text-align:center;color:var(--mu);font-size:12px;background:var(--bg3);border-radius:6px}
.fl{font-size:12px;color:var(--mu);margin-bottom:10px;font-style:italic}
/* Overview stats */
.stats{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin-bottom:8px}
.stat{background:var(--bg2);border:1px solid var(--bd);border-radius:8px;padding:14px 16px}
.stat .sv{font-size:22px;font-weight:700;color:var(--b)}.stat .sk{font-size:12px;color:var(--mu);margin-top:2px}
/* Lightbox */
.lb{display:none;position:fixed;inset:0;background:rgba(0,0,0,.95);z-index:999;align-items:center;justify-content:center;padding:20px;cursor:zoom-out}
.lb.on{display:flex}
.lb img{max-width:92vw;max-height:92vh;border-radius:8px;object-fit:contain}
.footer{padding:20px 0;border-top:1px solid var(--bd);color:var(--mu);font-size:12px;text-align:center;margin-top:20px}
h3.sub-h{font-size:14px;font-weight:700;margin-bottom:12px;color:var(--t)}
@media(max-width:900px){.pair,.cols2,.stats{grid-template-columns:1fr}.wrap,.hdr{padding:18px}nav{padding:0 18px}}
"""

a_ic=len([f for g in ai_n.values() for f in g]); b_ic=len([f for g in bi_n.values() for f in g])
av_c=len([f for g in av_n.values() for f in g]); bv_c=len([f for g in bv_n.values() for f in g])
nxt_wins=sum(1 for r in FEATURES if r[3] in("nxt","nxt*"))
rm_wins=sum(1 for r in FEATURES if r[3]=="rm")

HTML=f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{TITLE}</title><style>{CSS}</style>
</head>
<body>
<div class="lb" id="lb" onclick="this.classList.remove('on')"><img id="lbimg" src="" alt=""></div>

<div class="hdr">
  <h1>{TITLE}</h1>
  <div class="sub">Generated: {now} &nbsp;·&nbsp; Docker (wp-env) + Playwright + RICE + Interview Analysis</div>
  <div class="badges">
    <span class="badge ba">{la}</span>
    {"<span class='badge bb'>"+lb+"</span>" if pb else ""}
    <span class="badge bi">UAT · RICE Prioritization · PM Gap Analysis</span>
    <span class="badge bp">Orbit</span>
  </div>
</div>

<nav id="nav">{nav}</nav>

<div class="wrap">

<!-- OVERVIEW -->
<div class="sec" id="overview">
  <div class="sh"><span class="snum">Overview</span><h2>Test Run Summary</h2></div>
  <div class="stats">
    <div class="stat"><div class="sv">{total_flows}</div><div class="sk">Flows Tested</div></div>
    <div class="stat"><div class="sv">{total_imgs}</div><div class="sk">Screenshots</div></div>
    <div class="stat"><div class="sv">{total_vids}</div><div class="sk">Video Recordings</div></div>
    <div class="stat"><div class="sv">{nxt_wins} vs {rm_wins}</div><div class="sk">{la} wins vs {lb} wins</div></div>
  </div>
</div>

<!-- PM PRIORITIES (RICE) -->
<div class="sec" id="pm">
  <div class="sh"><span class="snum">PM</span><h2>RICE Priority Backlog</h2>
    <p>Scored from Playwright UAT findings · Q1 = immediate · Q2 = next quarter</p>
  </div>
  <p style="font-size:12px;color:var(--mu);margin-bottom:12px">
    Quick Win = high impact, low effort &nbsp;·&nbsp; Big Bet = high impact, high effort &nbsp;·&nbsp; Fill-In = low impact
  </p>
  {RICE_TABLE}
</div>

<!-- INTERVIEW ANALYSIS -->
<div class="sec" id="interview">
  <div class="sh"><span class="snum">UAT Analysis</span><h2>Pain Points &amp; Feature Requests</h2></div>
  <div class="cols2">
    <div>
      <h3 class="sub-h">🔴 Pain Points from UAT</h3>
      {PAIN_HTML}
    </div>
    <div>
      <h3 class="sub-h">📋 Feature Requests (by priority)</h3>
      {REQ_HTML}
    </div>
  </div>
  <h3 class="sub-h">Sentiment Analysis</h3>
  {SENTIMENT_HTML}
</div>

<!-- FEATURE COMPARISON -->
<div class="sec" id="compare">
  <div class="sh"><span class="snum">Compare</span><h2>Full Feature Matrix</h2></div>
  {FEAT_TABLE}
  <p style="font-size:12px;color:var(--mu);margin-top:8px">* = feature exists but needs manual configuration after install</p>
</div>

<!-- RECORDINGS -->
<div class="sec" id="flows">
  <div class="sh"><span class="snum">Recordings</span><h2>Side-by-Side: Screenshots &amp; Videos</h2></div>
</div>
{flow_secs}

<div class="footer">Orbit UAT &nbsp;·&nbsp; {now} &nbsp;·&nbsp; {total_imgs} screenshots · {total_vids} videos · {total_flows} flows</div>
</div>

<script>
function zoom(img){{document.getElementById('lbimg').src=img.src;document.getElementById('lb').classList.add('on')}}
document.addEventListener('keydown',e=>{{if(e.key==='Escape')document.getElementById('lb').classList.remove('on')}});
const links=document.querySelectorAll('nav a');
const obs=new IntersectionObserver(entries=>{{
  entries.forEach(e=>{{
    if(e.isIntersecting){{
      links.forEach(l=>l.classList.remove('active'));
      const a=document.querySelector('nav a[href="#'+e.target.id+'"]');
      if(a)a.classList.add('active');
    }}
  }})
}},{{threshold:0.3}});
document.querySelectorAll('.sec').forEach(s=>obs.observe(s));
</script>
</body></html>"""

os.makedirs(os.path.dirname(OUT) if os.path.dirname(OUT) else ".", exist_ok=True)
with open(OUT,"w") as f: f.write(HTML)
size=os.path.getsize(OUT)/1024/1024
print(f"Report: {OUT} ({size:.1f}MB) — {total_imgs} screenshots, {total_vids} videos, {total_flows} flows")
