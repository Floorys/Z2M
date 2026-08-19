# port.awk - конвертер стратегий Zapret2UI (winws2) в UCI-секции zapret2 (OpenWrt)
# Вызов: awk -v lists="<список list_hosts_*>" -v Q="'" -f port.awk strategy.txt

function trim(s){ sub(/^[ \t\r]+/,"",s); sub(/[ \t\r]+$/,"",s); return s }

function resolve(name,   i,n,arr,lc){
  n=split(lists,arr," "); lc=tolower(name); if(lc=="exclude") lc="user_exclude"
  for(i=1;i<=n;i++) if(tolower(substr(arr[i],12))==lc) return arr[i]
  return "" }

function remap(tok,   n,f,i,out,seg,val){
  n=split(tok,f,":"); out=""
  for(i=1;i<=n;i++){ seg=f[i]
    if(seg ~ /^blob=/){ val=substr(seg,6); if(val in bmap) seg="blob=" bmap[val] }
    else if(seg ~ /^seqovl_pattern=/){ val=substr(seg,16); if(val in bmap) seg="seqovl_pattern=" bmap[val] }
    out = out (i==1?"":":") seg }
  return out }

BEGIN{ np=1 }

{ line=trim($0)
  if(line=="" || line ~ /^#/) next
  if(line ~ /^--lua-init=/){ luainit[++nl]=substr(line,12); next }
  n=split(line,t," "); for(i=1;i<=n;i++) q[++nq]=t[i] }

END{
  for(k=1;k<=nq;k++){ tok=q[k]
    if(tok=="--new"){ np++; continue }
    if(tok=="{WF_TCP}" || tok=="{WF_UDP}" || tok ~ /^--wf/) continue
    if(tok=="--ctrack-disable=0") continue
    if(tok ~ /^--blob=/){ s=substr(tok,8); p=index(s,":"); alias=substr(s,1,p-1); path=substr(s,p+2)
      gsub(/\\/,"/",path); m=split(path,pp,"/"); base=pp[m]; sub(/\.bin$/,"",base)
      bmap[alias]="blob_" base; need[base]=1; continue }
    if(tok ~ /^--ipcache-/){ glob=glob (glob==""?"":" ") tok; continue }
    if(tok ~ /^--lua-gc=/){ luagc=substr(tok,10); continue }
    if(tok ~ /^--ctrack-timeouts=/){ ctt=substr(tok,19); continue }
    prof[np]=prof[np] (prof[np]==""?"":" ") tok }

  for(b in need) print "uci -q set zapret2.blob_" b ".enabled=" Q "1" Q

  for(p=1;p<=np;p++){
    proto=""; port=""; l7=""; hl=""; hle=""; script=""
    m=split(prof[p],a," ")
    for(i=1;i<=m;i++){ x=a[i]
      if(x ~ /^--filter-tcp=/){ proto="tcp"; port=substr(x,14)
        if(!(port in st)){ st[port]=1; tcpp=tcpp (tcpp==""?"":",") port } continue }
      if(x ~ /^--filter-udp=/){ proto="udp"; port=substr(x,14)
        if(!(port in su)){ su[port]=1; udpp=udpp (udpp==""?"":",") port } continue }
      if(x ~ /^--filter-l7=/){ l7=substr(x,13); continue }
      if(x ~ /^--filter-l3=/) continue
      if(x ~ /^\{HOSTLIST:/){ nm=x; sub(/^\{HOSTLIST:/,"",nm); sub(/\}$/,"",nm)
        hl=resolve(nm); if(hl=="") warn=warn "\n# ВНИМАНИЕ: НЕ НАЙДЕН список хостов: " nm; continue }
      if(x=="{HOSTLIST}"){ hl=resolve("user"); continue }
      if(x ~ /^\{EXCLUDE:/){ nm=x; sub(/^\{EXCLUDE:/,"",nm); sub(/\}$/,"",nm)
        hle=resolve(nm); if(hle=="") warn=warn "\n# ВНИМАНИЕ: НЕ НАЙДЕН список исключений: " nm; continue }
      if(x ~ /^\{IPSET/){ warn=warn "\n# ВНИМАНИЕ: " x " не перенесён, добавь IP-список вручную"; continue }
      if(x ~ /^--hostlist=/){ nm=x; sub(/.*zapret_hosts_/,"",nm); sub(/\.txt$/,"",nm); hl=resolve(nm); continue }
      if(x ~ /^--hostlist-exclude=/){ nm=x; sub(/.*zapret_hosts_/,"",nm); sub(/\.txt$/,"",nm); hle=resolve(nm); continue }
      script = script (script==""?"":" ") remap(x) }

    if(p==1 && glob!="") script = glob (script==""?"":" ") script
    tag = (hl!="" ? tolower(substr(hl,12)) : (hle!="" ? "rest" : "any"))
    sec = "p" p "_" (l7=="" ? proto : tolower(l7)) "_" tag; gsub(/[^a-z0-9_]/,"_",sec)

    print "uci set zapret2." sec "=strategy"
    print "uci set zapret2." sec ".enabled=" Q "1" Q
    if(proto!="") print "uci set zapret2." sec ".protocol=" Q proto Q
    if(port!="")  print "uci set zapret2." sec ".port=" Q port Q
    print "uci set zapret2." sec ".filter_l3=" Q "ipv4" Q
    if(l7!="")  print "uci set zapret2." sec ".filter_l7=" Q l7 Q
    if(hl!="")  print "uci add_list zapret2." sec ".hostlist=" Q hl Q
    if(hle!="") print "uci add_list zapret2." sec ".hostlist_exclude=" Q hle Q
    print "uci set zapret2." sec ".script=" Q script Q }

  if(tcpp!="") print "uci set zapret2.main.nfqws_ports_tcp=" Q tcpp Q
  if(udpp!="") print "uci set zapret2.main.nfqws_ports_udp=" Q udpp Q
  if(luagc!="") print "uci set zapret2.main.lua_gc=" Q luagc Q
  if(ctt!="")   print "uci set zapret2.main.ctrack_timeouts=" Q ctt Q

  if(nl>0){ print ": > /opt/zapret2/lua/zz-custom.lua"
    for(i=1;i<=nl;i++) print "echo \"" luainit[i] "\" >> /opt/zapret2/lua/zz-custom.lua"
    print "uci set zapret2.lua_zz_custom=luascript"
    print "uci set zapret2.lua_zz_custom.path=" Q "/opt/zapret2/lua/zz-custom.lua" Q
    print "uci set zapret2.lua_zz_custom.enabled=" Q "1" Q }

  if(warn!="") print warn
}
