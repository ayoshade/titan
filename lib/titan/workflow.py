"""Titan desktop operations. Inputs stay argv data; no shell interpolation."""
from __future__ import annotations
import ast, datetime, fcntl, hashlib, json, math, operator, os, pathlib, re, shutil, signal, subprocess, sys, tempfile, time
from paths import ROOT, CONFIG, STATE, RUNTIME, SETTINGS, preferences
for directory in (CONFIG, STATE, RUNTIME): directory.mkdir(mode=0o700, parents=True, exist_ok=True)
if not (STATE/'shell-settings.json').exists():
    (STATE/'shell-settings.json').write_text('{"barVisible": true}\n')
    (STATE/'shell-settings.json').chmod(0o600)
os.environ['CLIPHIST_DB_PATH'] = str(RUNTIME/'clipboard.db')

def run(*args, **kwargs):
    return subprocess.run([str(x) for x in args], check=True, **kwargs)
def output(*args):
    return run(*args, capture_output=True, text=True).stdout.strip()
def notify(text, detail=''):
    subprocess.run(['notify-send', 'Titan — '+text, detail], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
def require(name):
    if shutil.which(name): return
    notify(name+' is not installed', 'Run '+str(ROOT/'scripts/install-workflow')+' for desktop tools. Optional apps have separate installation; see Super+K.')
    raise SystemExit(1)
def launch(*args):
    require(args[0]); subprocess.Popen([str(x) for x in args], start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
def ipc(method, *args): return run('qs','-c','umbra','ipc','call','shell',method,*args,stdout=subprocess.DEVNULL)
def hypr(query): return json.loads(output('hyprctl','-j',query))
def dispatch(expression): return run('hyprctl','dispatch',expression,stdout=subprocess.DEVNULL)
def evaluate(expression): return run('hyprctl','eval',expression,stdout=subprocess.DEVNULL)
def lua(value): return json.dumps(value, ensure_ascii=True)
def active():
    window=hypr('activewindow')
    if not re.fullmatch(r'0x[0-9a-fA-F]+',window.get('address','')): raise SystemExit(0)
    return window

def load_state():
    try: return json.loads((STATE/'workflow.json').read_text())
    except FileNotFoundError: return {}
def atomic(path, text):
    fd, name=tempfile.mkstemp(dir=path.parent)
    with os.fdopen(fd,'w') as file: file.write(text)
    os.replace(name,path)
def save_state(data):
    atomic(STATE/'workflow.json',json.dumps(data,indent=2)+'\n')
    lines=['-- Generated Titan runtime preferences. Managed by scripts/workflow.']
    for ws,layout in data.get('layouts',{}).items():
        if re.fullmatch(r'-?\d+',ws) and layout in ('dwindle','scrolling'):
            lines.append(f'hl.workspace_rule({{workspace={lua(ws)},layout={lua(layout)}}})')
    if data.get('gaps'): lines.append('hl.config({general={gaps_in=0,gaps_out=0}})')
    if data.get('square'): lines.append('hl.config({layout={single_window_aspect_ratio={1,1}}})')
    for name,scale in data.get('scales',{}).items():
        if re.fullmatch(r'[A-Za-z0-9._-]+',name) and isinstance(scale,(int,float)) and 1<=scale<=4:
            lines.append(f'hl.monitor({{output={lua(name)},mode="preferred",position="auto",scale={scale}}})')
    atomic(STATE/'hypr-runtime.lua','\n'.join(lines)+'\n')

def app(name):
    web={'chatgpt':'https://chatgpt.com','grok':'https://grok.com','calendar':'https://app.hey.com/calendar/weeks/',
         'email':'https://app.hey.com','email-new':'https://app.hey.com/messages/new?display=standalone&new_window=true',
         'youtube':'https://youtube.com/','whatsapp':'https://web.whatsapp.com/','messages':'https://messages.google.com/web/conversations',
         'photos':'https://photos.google.com/','maps':'https://maps.google.com/','x':'https://x.com/','x-post':'https://x.com/compose/post'}
    if name in web: return launch('firefox','--new-window',web[name])
    cwd=pathlib.Path.home()
    try:
        window=active(); pid=window.get('pid',0)
        # Foreground terminal child holds the useful cwd, not Kitty's original cwd.
        children=pathlib.Path(f'/proc/{pid}/task/{pid}/children').read_text().split()
        cwd=pathlib.Path(f'/proc/{children[-1] if children else pid}/cwd').resolve(strict=True)
    except (OSError,SystemExit): pass
    commands={'terminal':['kitty'],'browser':['firefox'],'browser-private':['firefox','--private-window'],
              'files':['thunar'],'files-cwd':['thunar',str(cwd)],'editor':['kitty','--directory',str(cwd),'nvim'],
              'tmux':['kitty','--directory',str(cwd),'tmux','new-session','-A','-s','titan'],'herdr':['kitty','herdr'],
              'spotify':['spotify'],'cliamp':['kitty','cliamp'],'docker':['kitty','lazydocker'],'signal':['signal-desktop'],
              'obsidian':['obsidian'],'omawrite':['omawrite'],'passwords':['1password'],'activity':['kitty','btop'],
              'codex':['kitty','--directory',str(ROOT),'codex'],'claude':['kitty','--directory',str(ROOT),'claude']}
    command=commands[name]
    for binary in command:
        if binary in ('nvim','tmux','herdr','cliamp','lazydocker','btop','codex','claude'): require(binary)
    launch(*command)

def window_operation(name,args):
    data=load_state()
    if name=='layout':
        ws=hypr('activeworkspace'); key=str(ws['id']); layout='scrolling' if ws.get('tiledLayout')=='dwindle' else 'dwindle'
        evaluate(f'hl.workspace_rule({{workspace={lua(key)},layout={lua(layout)}}})')
        data.setdefault('layouts',{})[key]=layout; save_state(data); notify('Workspace layout: '+layout); return
    if name in ('gaps','square','desktop'):
        if name=='desktop':
            status=json.loads(output('qs','-c','umbra','ipc','call','shell','status'))
            enabled=not(data.get('gaps') and not status.get('barVisible',True))
            data['gaps']=enabled; ipc('setBar',str(not enabled).lower())
        else: data[name]=not data.get(name,False)
        if name=='square': evaluate('hl.config({layout={single_window_aspect_ratio={'+('1,1' if data['square'] else '0,0')+'}}})')
        else: evaluate('hl.config({general={gaps_in='+('0' if data['gaps'] else '5')+',gaps_out='+('0' if data['gaps'] else '14')+'}})')
        save_state(data); return
    window=active(); target=lua('address:'+window['address'])
    if name=='tiled-fullscreen': dispatch('hl.dsp.window.fullscreen_state({window='+target+',internal=0,client='+('0' if window.get('fullscreenClient')==2 else '2')+'})')
    elif name=='transparency': dispatch(f'hl.dsp.window.set_prop({{window={target},prop="opaque",value="toggle"}})')
    elif name=='pop':
        if window.get('pinned'):
            dispatch(f'hl.dsp.window.pin({{window={target}}})'); dispatch(f'hl.dsp.window.float({{window={target},action="off"}})')
        else:
            monitor=next(m for m in hypr('monitors') if m['id']==window['monitor'])
            width=min(1300,round(monitor['width']/monitor['scale']*.8)); height=min(900,round(monitor['height']/monitor['scale']*.8))
            dispatch(f'hl.dsp.window.float({{window={target},action="on"}})')
            dispatch(f'hl.dsp.window.resize({{window={target},x={width},y={height}}})')
            dispatch(f'hl.dsp.window.center({{window={target}}})'); dispatch(f'hl.dsp.window.pin({{window={target}}})')
            dispatch(f'hl.dsp.window.alter_zorder({{window={target},mode="top"}})')
    elif name=='width':
        key=hashlib.sha256((str(window['workspace']['id'])+'\0'+window.get('class','')).encode()).hexdigest()
        widths=data.setdefault('widths',{})
        if args[0]=='save': widths[key]=window['size'][0]; save_state(data); notify('Window width saved')
        elif key in widths:
            desired=widths[key]; current=window['size'][0]
            # Dwindle's split direction can invert resize deltas. Probe and converge.
            if current==desired: return
            dispatch(f'hl.dsp.window.resize({{window={target},x=10,y=0,relative=true}})')
            after=next((w['size'][0] for w in hypr('clients') if w['address']==window['address']),current)
            direction=1 if after>=current else -1
            for _ in range(6):
                if after==desired: break
                dispatch(f'hl.dsp.window.resize({{window={target},x={(desired-after)*direction},y=0,relative=true}})')
                latest=next((w['size'][0] for w in hypr('clients') if w['address']==window['address']),after)
                if latest==after: break
                after=latest
        else: notify('No saved width','Use Super+Alt+Home on this workspace first.')

def clipboard(action,args):
    require('cliphist')
    if action=='start':
        if subprocess.run(['systemctl','--user','is-active','--quiet','titan-clipboard.service']).returncode==0: return
        run('systemd-run','--user','--collect','--unit=titan-clipboard','--setenv=WAYLAND_DISPLAY='+os.environ.get('WAYLAND_DISPLAY','wayland-1'),
            '--setenv=CLIPHIST_DB_PATH='+os.environ['CLIPHIST_DB_PATH'],'wl-paste','--watch',ROOT/'scripts/workflow','clipboard-store',stdout=subprocess.DEVNULL)
    elif action=='store':
        if os.environ.get('CLIPBOARD_STATE') in ('sensitive','nil','clear'): return
        content=sys.stdin.buffer.read(1048577)
        if len(content)<=1048576: run('cliphist','-db-path',os.environ['CLIPHIST_DB_PATH'],'-max-items','100','store',input=content)
    elif action=='list':
        result=subprocess.run(['cliphist','-db-path',os.environ['CLIPHIST_DB_PATH'],'list'],capture_output=True,text=True)
        print(json.dumps([{'label':line.partition('\t')[2], 'detail':'Enter copies this item', 'action':'clipboard-copy', 'value':line.partition('\t')[0]} for line in result.stdout.splitlines()]))
    elif action=='copy':
        if not re.fullmatch(r'\d+',args[0]): raise ValueError('Invalid clipboard item')
        decoded=run('cliphist','-db-path',os.environ['CLIPHIST_DB_PATH'],'decode',input=(args[0]+'\n').encode(),capture_output=True).stdout
        run('wl-copy',input=decoded)
    elif action=='clear': run('cliphist','-db-path',os.environ['CLIPHIST_DB_PATH'],'wipe')

def audio(action,args):
    if action=='volume':
        amount=int(args[0]); run('wpctl','set-volume','-l','1','@DEFAULT_AUDIO_SINK@',str(abs(amount))+'%'+('+' if amount>0 else '-')); ipc('osd','volume')
    elif action in ('mute','mic'):
        run('wpctl','set-mute','@DEFAULT_AUDIO_SOURCE@' if action=='mic' else '@DEFAULT_AUDIO_SINK@','toggle'); ipc('osd','volume')
    elif action=='switch': ipc('cycleAudio')

def brightness(amount):
    value=int(amount)
    flag=str(abs(value))+'%'+('+' if value>0 else '-') if amount.startswith(('+','-')) else str(value)+'%'
    run('brightnessctl','-n','1','set',flag); ipc('osd','brightness')

def keyboard_light(action):
    devices=list(pathlib.Path('/sys/class/leds').glob('*kbd_backlight*'))
    if not devices: notify('No keyboard backlight detected'); return
    device=devices[0]; maximum=int((device/'max_brightness').read_text()); current=int((device/'brightness').read_text())
    value=(current+1)%(maximum+1) if action=='cycle' else max(0,min(maximum,current+(1 if action=='up' else -1)))
    run('brightnessctl','-d',device.name,'set',str(value))

def touchpad(action):
    data=load_state(); enabled=not data.get('touchpadEnabled',True) if action=='toggle' else action=='on'
    devices=[d['name'] for d in hypr('devices').get('mice',[]) if 'touchpad' in d['name'].lower()]
    if not devices: notify('No touchpad detected'); return
    for device in devices: evaluate(f'hl.device({{name={lua(device)},enabled={str(enabled).lower()}}})')
    data['touchpadEnabled']=enabled; save_state(data)

def scale(direction):
    data=load_state(); monitor=next(m for m in hypr('monitors') if m['focused']); current=monitor['scale']
    # A clean fractional scale divides both physical dimensions in 1/120 units.
    divisor=math.gcd(monitor['width']*120,monitor['height']*120)
    candidates=[]
    for value in (1,1.25,1.6,2,3,4):
        units=min(divisor,round(value*120))
        while divisor%units: units+=1
        cleaned=units/120
        if cleaned not in candidates: candidates.append(cleaned)
    candidates.sort(); index=min(range(len(candidates)),key=lambda i:abs(candidates[i]-current))
    value=candidates[max(0,min(len(candidates)-1,index+(1 if direction=='up' else -1)))]
    name=monitor['name']; evaluate(f'hl.monitor({{output={lua(name)},mode="preferred",position={lua(str(monitor["x"])+"x"+str(monitor["y"]))},scale={value}}})')
    data.setdefault('scales',{})[name]=value; save_state(data); notify('Monitor scale: '+str(value))

def mirror():
    data=load_state(); monitors=hypr('monitors'); internal=next((m for m in monitors if re.match(r'^(eDP|LVDS|DSI)-',m['name'])),None)
    external=next((m for m in monitors if not re.match(r'^(eDP|LVDS|DSI)-',m['name'])),None)
    if not internal or not external: notify('Connect an external monitor to use mirroring'); return
    enabled=not data.get('mirror',False)
    evaluate(f'hl.monitor({{output={lua(external["name"])},mode="preferred",position="auto",scale=1,mirror={lua(internal["name"] if enabled else "")}}})')
    data['mirror']=enabled; save_state(data)

def nightlight(action='toggle'):
    # Temperature comes from Settings → System/Display (nightlightTemp, kelvin).
    require('wlsunset')
    active=subprocess.run(['systemctl','--user','is-active','--quiet','titan-nightlight.service']).returncode==0
    try: temp=int(json.loads(SETTINGS.read_text()).get('nightlightTemp',4500))
    except (FileNotFoundError,json.JSONDecodeError,ValueError,TypeError): temp=4500
    temp=max(2500,min(6000,temp))
    if action=='apply' and not active: return
    if active: run('systemctl','--user','stop','titan-nightlight.service')
    if action=='toggle' and active: notify('Nightlight disabled'); return
    if action=='off': return
    run('systemd-run','--user','--collect','--unit=titan-nightlight','--setenv=WAYLAND_DISPLAY='+os.environ.get('WAYLAND_DISPLAY','wayland-1'),
        'wlsunset','-T',str(temp+1),'-t',str(temp),'-S','00:00','-s','23:59',stdout=subprocess.DEVNULL)
    if action=='toggle': notify('Nightlight enabled',f'{temp} K')

OPS={ast.Add:operator.add,ast.Sub:operator.sub,ast.Mult:operator.mul,ast.Div:operator.truediv,ast.Mod:operator.mod,ast.Pow:operator.pow,ast.FloorDiv:operator.floordiv}
GAME_OPTIONS=('animations:enabled','decoration:blur:enabled','decoration:shadow:enabled')
def option(name): return bool(json.loads(output('hyprctl','getoption',name,'-j')).get('bool',True))
def game_mode_active():
    # A Hyprland reload restores configured effects, which leaves a stale saved state.
    return (RUNTIME/'game-mode.json').exists() and not option('animations:enabled')
def game_mode():
    path=RUNTIME/'game-mode.json'
    if game_mode_active():
        saved=json.loads(path.read_text())
        values=[lua(bool(saved.get(name,True))) for name in GAME_OPTIONS]
        evaluate('hl.config({animations={enabled=%s},decoration={blur={enabled=%s},shadow={enabled=%s}}})' % tuple(values))
        path.unlink(); notify('Game mode disabled')
    else:
        atomic(path,json.dumps({name:option(name) for name in GAME_OPTIONS})+'\n')
        evaluate('hl.config({animations={enabled=false},decoration={blur={enabled=false},shadow={enabled=false}}})')
        notify('Game mode enabled','Animations, blur and shadows are off until toggled again or Hyprland reloads.')
def toggle_state():
    nightlight=subprocess.run(['systemctl','--user','is-active','--quiet','titan-nightlight.service']).returncode==0
    return {'nightlight':nightlight,'gameMode':game_mode_active()}
def publish_toggles():
    # The shell watches this file, so changes from keys or agents show up at once.
    atomic(RUNTIME/'toggles.json',json.dumps(toggle_state())+'\n')
def toggles():
    state=toggle_state(); atomic(RUNTIME/'toggles.json',json.dumps(state)+'\n'); print(json.dumps(state))

SCHEMA=ROOT/'config/quickshell/umbra/theme/settings-schema.json'
def settings_valid(spec,value):
    kind=spec['type']
    if kind=='bool': return isinstance(value,bool)
    if kind=='int': return isinstance(value,int) and not isinstance(value,bool) and spec['min']<=value<=spec['max']
    if kind=='choice': return value in spec['options']
    if kind=='color': return value=='' or bool(re.fullmatch(r'#[0-9a-fA-F]{6}',str(value)))
    if kind=='string': return isinstance(value,str) and len(value)<=64
    if kind=='map': return isinstance(value,dict)
    return False
def settings(action,args):
    # Same file and schema as the Settings app; the shell reloads it on change.
    schema=json.loads(SCHEMA.read_text())['settings']; path=SETTINGS
    try: stored=json.loads(path.read_text())
    except (FileNotFoundError,json.JSONDecodeError): stored={}
    current={k:stored.get(k,v['default']) for k,v in schema.items()}
    if action=='get':
        if args and args[0] not in schema: raise ValueError('Unknown setting: '+args[0])
        print(json.dumps(current[args[0]] if args else current,indent=None if args else 2)); return
    if action=='schema': print(json.dumps(schema,indent=2)); return
    key=args[0]
    if key not in schema: raise ValueError('Unknown setting: '+key)
    if action=='reset': stored.pop(key,None)
    elif action=='set':
        raw=args[1]
        try: value=json.loads(raw)
        except json.JSONDecodeError: value=raw
        if not settings_valid(schema[key],value): raise ValueError(f'Invalid value for {key}: {raw}')
        stored[key]=value
    else: raise ValueError('settings get|set|reset|schema')
    atomic(path,json.dumps(stored,indent=2)+'\n')

WALLPAPERS=pathlib.Path(os.environ.get('TITAN_WALLPAPERS',str(pathlib.Path.home()/'Pictures/Wallpapers')))
def wallpaper(action,args):
    # Same per-theme map the shell's wallpaper picker writes in settings.json.
    theme=preferences().get('theme','graphite')
    files=sorted(str(p) for p in (WALLPAPERS/theme).glob('*') if p.suffix.lower() in ('.jpg','.jpeg','.png','.webp'))
    files.append(str(ROOT/'assets/wallpapers/blacksite.svg'))
    path=SETTINGS
    try: stored=json.loads(path.read_text())
    except (FileNotFoundError,json.JSONDecodeError): stored={}
    chosen=stored.get('wallpapers',{}).get(theme) or (files[0] if files else '')
    if action=='list': print(json.dumps({'theme':theme,'current':chosen,'files':files},indent=2)); return
    if action=='current': print(chosen); return
    if action=='next': target=files[(files.index(chosen)+1)%len(files)] if chosen in files else (files[0] if files else '')
    elif action=='set': target=str(pathlib.Path(args[0]).expanduser().resolve(strict=True))
    else: raise ValueError('wallpaper list|current|next|set PATH')
    if not target: raise ValueError('No wallpapers for '+theme+'; run scripts/fetch-wallpapers '+theme)
    stored.setdefault('wallpapers',{})[theme]=target
    atomic(path,json.dumps(stored,indent=2)+'\n'); print(target)

def calculate(expression):
    if len(expression)>200: raise ValueError('Expression too long')
    def visit(node,depth=0):
        if depth>20: raise ValueError('Expression too complex')
        if isinstance(node,ast.Constant) and type(node.value) in (int,float): result=node.value
        elif isinstance(node,ast.UnaryOp) and isinstance(node.op,(ast.UAdd,ast.USub)):
            result=visit(node.operand,depth+1)*(1 if isinstance(node.op,ast.UAdd) else -1)
        elif isinstance(node,ast.BinOp) and type(node.op) in OPS:
            left,right=visit(node.left,depth+1),visit(node.right,depth+1)
            if isinstance(node.op,ast.Pow) and abs(right)>100: raise ValueError('Exponent too large')
            result=OPS[type(node.op)](left,right)
        elif isinstance(node,ast.Name) and node.id in ('pi','e'): result=getattr(math,node.id)
        else: raise ValueError('Use numbers, parentheses, + - * / // % **, pi or e')
        if not isinstance(result,(int,float)) or abs(result)>1e100: raise ValueError('Result outside supported range')
        return result
    return str(visit(ast.parse(expression,mode='eval').body))

def reminders(action,value=''):
    if action=='set':
        match=re.fullmatch(r'\s*(\d+)\s+(.{1,300})',value)
        if not match: raise ValueError('Enter minutes followed by reminder text, e.g. 20 Stretch')
        minutes=int(match[1]); text=match[2]
        if not 1<=minutes<=525600: raise ValueError('Use 1–525600 minutes')
        key='titan-reminder-'+str(time.time_ns()); due=time.time()+minutes*60
        # The notification argv is preserved in the transient systemd service.
        run('systemd-run','--user','--collect','--unit='+key,'--on-calendar='+datetime.datetime.fromtimestamp(due).strftime('%Y-%m-%d %H:%M:%S'),
            '--timer-property=Persistent=true','notify-send','Titan reminder',text,stdout=subprocess.DEVNULL)
        data=load_state(); data.setdefault('reminders',[]).append({'unit':key,'text':text,'due':due}); save_state(data); notify('Reminder set',text)
    elif action=='list':
        data=load_state(); items=[r for r in data.get('reminders',[]) if r['due']>time.time()]
        print(json.dumps([{'label':r['text'],'detail':datetime.datetime.fromtimestamp(r['due']).strftime('%a %H:%M'),'action':'none'} for r in items]))
    elif action=='clear':
        data=load_state()
        for reminder in data.get('reminders',[]):
            subprocess.run(['systemctl','--user','stop',reminder['unit']+'.timer',reminder['unit']+'.service'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        data['reminders']=[]; save_state(data); notify('Reminders cleared')

def info(kind):
    if kind=='time': notify(datetime.datetime.now().strftime('%A, %B %-d — %H:%M'))
    elif kind=='battery':
        batteries=list(pathlib.Path('/sys/class/power_supply').glob('BAT*'))
        if not batteries: notify('No battery detected'); return
        device=batteries[0]; notify('Battery '+(device/'capacity').read_text().strip()+'%',(device/'status').read_text().strip())

def focused_monitor(): return next(m for m in hypr('monitors') if m['focused'])
def monitor_geometry(m):
    width,height=round(m['width']/m['scale']),round(m['height']/m['scale'])
    if m.get('transform',0)%2: width,height=height,width
    return [m['x'],m['y'],width,height]
def geometry(rect): return f'{rect[0]},{rect[1]} {rect[2]}x{rect[3]}'
def rectangles():
    monitor=focused_monitor(); ws=monitor['activeWorkspace']['id']
    return list(dict.fromkeys(tuple(w['at']+w['size']) for w in hypr('clients') if w['workspace']['id']==ws and not w.get('hidden')))
def cursor():
    pos=output('hyprctl','cursorpos').split(','); return int(pos[0]),int(pos[1])
def under_cursor(rects):
    x,y=cursor(); hits=[r for r in rects if r[0]<=x<r[0]+r[2] and r[1]<=y<r[1]+r[3]]
    return min(hits,key=lambda r:r[2]*r[3]) if hits else None

def selection(action):
    try: state=json.loads((RUNTIME/'selection.json').read_text())
    except FileNotFoundError: return
    pid=state['pid']
    try:
        if pathlib.Path(f'/proc/{pid}/comm').read_text().strip()!='slurp': return
    except FileNotFoundError: return
    rects=rectangles()
    if action in ('full','window'):
        rect=monitor_geometry(focused_monitor()) if action=='full' else under_cursor(rects) or monitor_geometry(focused_monitor())
        atomic(RUNTIME/'selection-result',geometry(rect)); os.kill(pid,signal.SIGTERM); return
    ordered=sorted(rects,key=lambda r:(r[1],r[0]))
    if not ordered: return
    current=under_cursor(ordered); index=ordered.index(current) if current else -1
    if action in ('next','prev'): chosen=ordered[(index+(1 if action=='next' else -1))%len(ordered)]
    else:
        x,y=cursor() if current is None else (current[0]+current[2]/2,current[1]+current[3]/2)
        def score(r):
            dx,dy=r[0]+r[2]/2-x,r[1]+r[3]/2-y
            main,other={'left':(-dx,dy),'right':(dx,dy),'up':(-dy,dx),'down':(dy,dx)}[action]
            return main+abs(other)*2 if main>0 else math.inf
        chosen=min(ordered,key=score)
        if score(chosen)==math.inf: return
    evaluate(f'hl.dispatch(hl.dsp.cursor.move({{x={chosen[0]+chosen[2]//2},y={chosen[1]+chosen[3]//2}}}))')

def pick():
    require('slurp'); rects=rectangles()+[tuple(monitor_geometry(focused_monitor()))]
    marker=RUNTIME/'selection-result'; marker.unlink(missing_ok=True)
    proc=subprocess.Popen(['slurp'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,text=True)
    atomic(RUNTIME/'selection.json',json.dumps({'pid':proc.pid}))
    try:
        selected=proc.communicate('\n'.join(geometry(r) for r in rects)+'\n')[0].strip()
        if marker.exists(): selected=marker.read_text(); marker.unlink()
        if not selected: return None
        match=re.fullmatch(r'(-?\d+),(-?\d+) (\d+)x(\d+)',selected)
        if not match: return None
        x,y,w,h=map(int,match.groups())
        if w*h<20:
            hits=[r for r in rects if r[0]<=x<r[0]+r[2] and r[1]<=y<r[1]+r[3]]
            if hits: selected=geometry(min(hits,key=lambda r:r[2]*r[3]))
        return selected
    finally: (RUNTIME/'selection.json').unlink(missing_ok=True)

def capture(kind):
    if kind=='color':
        require('hyprpicker')
        if subprocess.run(['systemctl','--user','is-active','--quiet','titan-colorpicker.service']).returncode==0: run('systemctl','--user','stop','titan-colorpicker.service')
        else: run('systemd-run','--user','--collect','--unit=titan-colorpicker','--setenv=WAYLAND_DISPLAY='+os.environ.get('WAYLAND_DISPLAY','wayland-1'),'hyprpicker','-a',stdout=subprocess.DEVNULL)
        return
    if kind=='record':
        require('wf-recorder')
        if subprocess.run(['systemctl','--user','is-active','--quiet','titan-screenrecord.service']).returncode==0:
            run('systemctl','--user','kill','--signal=SIGINT','titan-screenrecord.service'); notify('Recording stopped','Saved in ~/Videos/Recordings'); return
    if kind=='text': require('tesseract')
    selected=geometry(monitor_geometry(focused_monitor())) if kind=='full' else pick()
    if not selected: return
    if kind=='record':
        folder=pathlib.Path.home()/'Videos/Recordings'; folder.mkdir(parents=True,exist_ok=True)
        file=folder/(datetime.datetime.now().strftime('%Y-%m-%d_%H-%M-%S')+'.mp4')
        run('systemd-run','--user','--collect','--unit=titan-screenrecord','--setenv=WAYLAND_DISPLAY='+os.environ.get('WAYLAND_DISPLAY','wayland-1'),
            'wf-recorder','-g',selected,'-f',str(file),stdout=subprocess.DEVNULL); notify('Recording started','Alt+Print stops and saves it.'); return
    if kind=='text':
        fd,path=tempfile.mkstemp(suffix='.png',dir=RUNTIME); os.close(fd)
        try:
            run('grim','-g',selected,path); text=output('tesseract',path,'stdout','-l','eng')
            run('wl-copy',input=text.encode()); notify('Text copied from screenshot')
        finally: pathlib.Path(path).unlink(missing_ok=True)
    else:
        folder=pathlib.Path.home()/'Pictures/Screenshots'; folder.mkdir(parents=True,exist_ok=True)
        fd,path=tempfile.mkstemp(prefix=datetime.datetime.now().strftime('%Y-%m-%d_%H-%M-%S-'),suffix='.png',dir=folder); os.close(fd)
        run('grim','-g',selected,path); run('wl-copy','--type','image/png',input=pathlib.Path(path).read_bytes()); notify('Screenshot saved',path)

def webcam(action):
    windows=[w for w in hypr('clients') if w.get('class')=='TitanWebcam']
    if action=='toggle':
        if windows: dispatch(f'hl.dsp.window.close({{window={lua("address:"+windows[0]["address"])}}})'); return
        require('mpv'); devices=list(pathlib.Path('/dev').glob('video*'))
        if not devices: notify('No webcam detected'); return
        evaluate('hl.window_rule({match={class="^TitanWebcam$"},float=true,pin=true,size="320 240"})')
        launch('mpv','--title=Titan webcam','--wayland-app-id=TitanWebcam','--profile=low-latency','--no-audio',f'av://v4l2:{devices[0]}'); return
    if not windows: notify('Enable webcam overlay from Super+Ctrl+C first'); return
    window=windows[0]; factor=.9 if action=='smaller' else 1.1
    dispatch(f'hl.dsp.window.resize({{window={lua("address:"+window["address"])},x={max(120,round(window["size"][0]*factor))},y={max(90,round(window["size"][1]*factor))}}})')

def keybindings():
    catalog=json.loads((ROOT/'config/hypr/keybindings.json').read_text())
    codes={**{i+9:str(i%10) for i in range(1,11)},20:'minus',21:'equal',34:'[',35:']'}
    def display(key):
        key=re.sub(r'code:(\d+)',lambda m:codes.get(int(m[1]),m[0]),key)
        for word in ('SUPER','CTRL','ALT','SHIFT'): key=key.replace(word,word.title())
        return key.replace(' + ','+')
    items=[{'label':display(item['key']),'detail':item['description'],'action':'none'} for item in catalog]
    if shutil.which('voxtype'):
        items.extend([{'label':'Super+Ctrl+X','detail':'Toggle dictation','action':'none'},
                      {'label':'F9','detail':'Start dictation (press)','action':'none'},
                      {'label':'F9','detail':'Stop dictation (release)','action':'none'}])
    print(json.dumps(items))

def main(argv):
    name,*args=argv
    if name=='app': app(args[0])
    elif name in ('layout','gaps','square','desktop','tiled-fullscreen','transparency','pop','width'): window_operation(name,args)
    elif name=='close-all': ipc('menu','close-all')
    elif name=='close-all-confirmed':
        for w in hypr('clients'):
            if re.fullmatch(r'0x[0-9a-fA-F]+',w.get('address','')): dispatch(f'hl.dsp.window.close({{window={lua("address:"+w["address"])}}})')
    elif name=='policy':
        if args[0]!='lid': notify('Always-awake policy is active','Idle locking and display-off stay disabled. Manual lock: Super+Ctrl+L.')
    elif name.startswith('clipboard-'): clipboard(name.split('-',1)[1],args)
    elif name=='audio': audio(args[0],args[1:])
    elif name=='brightness': brightness(args[0])
    elif name=='keyboard-light': keyboard_light(args[0])
    elif name=='touchpad': touchpad(args[0])
    elif name=='media':
        if args[0]=='switch': ipc('cycleMedia')
        else: run('playerctl',args[0])
    elif name=='scale': scale(args[0])
    elif name=='mirror': mirror()
    elif name=='nightlight': nightlight(args[0] if args else 'toggle'); publish_toggles()
    elif name=='game-mode': game_mode(); publish_toggles()
    elif name=='toggles': toggles()
    elif name=='settings': settings(args[0] if args else 'get',args[1:])
    elif name=='wallpaper': wallpaper(args[0] if args else 'current',args[1:])
    elif name=='calculator': print(calculate(args[0]))
    elif name=='copy-text': run('wl-copy',input=args[0].encode()); notify('Copied')
    elif name=='capture': capture(args[0])
    elif name=='selection': selection(args[0])
    elif name=='pick':
        selected=pick()
        if selected: print(selected)
        else: raise SystemExit(1)
    elif name=='webcam': webcam(args[0])
    elif name=='keybindings': keybindings()
    elif name=='worldclock':
        from zoneinfo import ZoneInfo
        zones={'Local':None,'Chicago':'America/Chicago','New York':'America/New_York','London':'Europe/London','Berlin':'Europe/Berlin','Tokyo':'Asia/Tokyo','Sydney':'Australia/Sydney'}
        print(json.dumps([{'label':label,'detail':datetime.datetime.now(ZoneInfo(zone) if zone else None).strftime('%a %H:%M'),'action':'none'} for label,zone in zones.items()]))
    elif name=='reminder-set': reminders('set',args[0])
    elif name=='reminder-list': reminders('list')
    elif name=='reminder-clear': reminders('clear')
    elif name=='info': info(args[0])
    elif name=='weather':
        # User explicitly submits a place before contacting the weather service.
        from urllib.parse import quote
        launch('firefox','--new-window','https://wttr.in/'+quote(args[0],safe=''))
    elif name=='transcode':
        require('ffmpeg'); source=pathlib.Path(args[0]).expanduser().resolve(strict=True)
        if not source.is_file(): raise ValueError('Select a local video file')
        target=source.with_name(source.stem+'-titan.mp4')
        run('ffmpeg','-nostdin','-n','-i',source,'-c:v','libx264','-crf','23','-c:a','aac',target,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL); notify('Transcode complete',str(target))
    elif name=='eject':
        require('eject'); run('eject')
    elif name=='bar-set': atomic(STATE/'shell-settings.json',json.dumps({'barVisible':args[0]=='true'})+'\n')
    elif name in ('none','shell-init'): pass
    else: raise ValueError('Unknown operation: '+name)

if __name__=='__main__':
    try:
        # Serial state writers avoid lost changes from simultaneous key presses.
        lock=open(STATE/'workflow.lock','a')
        if len(sys.argv)>1 and sys.argv[1] in ('settings','wallpaper','game-mode','layout','gaps','square','desktop','width','touchpad','scale','mirror','reminder-set','reminder-clear'):
            fcntl.flock(lock,fcntl.LOCK_EX)
        main(sys.argv[1:])
    except (ValueError,KeyError,SyntaxError,ZeroDivisionError,OverflowError,OSError,subprocess.CalledProcessError) as error:
        notify('Operation failed',str(error)[:300]); print(str(error),file=sys.stderr); sys.exit(1)
