#!/usr/bin/env python3
"""
Road Side Dosa - Roblox Place File Generator
Generates a complete .rbxlx file with environment, scripts, UI, and all game systems.
"""

import os
import uuid
import html

# === REFERENT ID GENERATOR ===
_ref_counter = 0
def ref():
    global _ref_counter
    _ref_counter += 1
    return f"RBX{_ref_counter:08X}"

def escape(text):
    return html.escape(text, quote=True)

# === LOAD LUA SCRIPTS ===
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

def load_script(path):
    full = os.path.join(SCRIPT_DIR, path)
    with open(full, 'r') as f:
        return f.read()

# Load all scripts
config_lua = load_script("scripts/modules/Config.lua")
nightdata_lua = load_script("scripts/modules/NightData.lua")
gamemanager_lua = load_script("scripts/server/GameManager.lua")
npcmanager_lua = load_script("scripts/server/NPCManager.lua")
datamanager_lua = load_script("scripts/server/DataManager.lua")
gamepassmanager_lua = load_script("scripts/server/GamePassManager.lua")
clientcontroller_lua = load_script("scripts/client/ClientController.lua")

# === XML BUILDERS ===
def prop_string(name, value):
    return f'<string name="{name}">{escape(value)}</string>'

def prop_bool(name, value):
    return f'<bool name="{name}">{"true" if value else "false"}</bool>'

def prop_int(name, value):
    return f'<int name="{name}">{value}</int>'

def prop_float(name, value):
    return f'<float name="{name}">{value}</float>'

def prop_double(name, value):
    return f'<double name="{name}">{value}</double>'

def prop_vector3(name, x, y, z):
    return f'<Vector3 name="{name}"><X>{x}</X><Y>{y}</Y><Z>{z}</Z></Vector3>'

def prop_cframe(name, x, y, z, r00=1,r01=0,r02=0,r10=0,r11=1,r12=0,r20=0,r21=0,r22=1):
    return f'''<CoordinateFrame name="{name}">
<X>{x}</X><Y>{y}</Y><Z>{z}</Z>
<R00>{r00}</R00><R01>{r01}</R01><R02>{r02}</R02>
<R10>{r10}</R10><R11>{r11}</R11><R12>{r12}</R12>
<R20>{r20}</R20><R21>{r21}</R21><R22>{r22}</R22>
</CoordinateFrame>'''

def prop_color3(name, r, g, b):
    return f'<Color3 name="{name}"><R>{r}</R><G>{g}</G><B>{b}</B></Color3>'

def prop_color3uint8(name, r, g, b):
    """Pack RGB (0-255 ints) into Roblox Color3uint8 format"""
    val = (0xFF << 24) | (int(r) << 16) | (int(g) << 8) | int(b)
    return f'<Color3uint8 name="{name}">{val}</Color3uint8>'

def color_float_to_uint8(r, g, b):
    """Convert 0.0-1.0 float color to packed Color3uint8"""
    ri, gi, bi = int(r*255), int(g*255), int(b*255)
    val = (0xFF << 24) | (ri << 16) | (gi << 8) | bi
    return val

def prop_token(name, value):
    return f'<token name="{name}">{value}</token>'

def prop_udim2(name, xs, xo, ys, yo):
    return f'<UDim2 name="{name}"><XS>{xs}</XS><XO>{xo}</XO><YS>{ys}</YS><YO>{yo}</YO></UDim2>'

def prop_content(name, value=""):
    if value:
        return f'<Content name="{name}"><url>{escape(value)}</url></Content>'
    return f'<Content name="{name}"><null></null></Content>'

def prop_protected_string(name, code):
    return f'<ProtectedString name="{name}"><![CDATA[{code}]]></ProtectedString>'

def prop_binarystring(name, value=""):
    return f'<BinaryString name="{name}">{value}</BinaryString>'

# === VALUE OBJECT BUILDERS (for proper attribute replacement) ===
def make_bool_value(name, value):
    """Create a BoolValue instance child (replaces BinaryString attributes)"""
    r = ref()
    return f'''<Item class="BoolValue" referent="{r}">
<Properties>
{prop_string("Name", name)}
{prop_bool("Value", value)}
</Properties>
</Item>'''

def make_string_value(name, value):
    """Create a StringValue instance child (replaces BinaryString attributes)"""
    r = ref()
    return f'''<Item class="StringValue" referent="{r}">
<Properties>
{prop_string("Name", name)}
{prop_string("Value", value)}
</Properties>
</Item>'''

# === PART BUILDER ===
def make_part(name, x, y, z, sx, sy, sz, color=(0.5,0.5,0.5), material=256,
              transparency=0, anchored=True, cancollide=True, children="", shape=1,
              attributes=None):
    r = ref()

    # Build attribute children using proper Value objects
    attr_children = ""
    if attributes:
        for k, v in attributes.items():
            if isinstance(v, bool):
                attr_children += make_bool_value(k, v)
            elif isinstance(v, str):
                attr_children += make_string_value(k, v)

    # Convert float color (0-1) to uint8
    cr, cg, cb = int(color[0]*255), int(color[1]*255), int(color[2]*255)
    color_packed = (0xFF << 24) | (cr << 16) | (cg << 8) | cb

    return f'''<Item class="Part" referent="{r}">
<Properties>
{prop_string("Name", name)}
{prop_bool("Anchored", anchored)}
{prop_bool("CanCollide", cancollide)}
{prop_cframe("CFrame", x, y, z)}
<Color3uint8 name="Color3uint8">{color_packed}</Color3uint8>
{prop_token("Material", material)}
{prop_vector3("size", sx, sy, sz)}
{prop_token("shape", shape)}
{prop_float("Transparency", transparency)}
</Properties>
{attr_children}
{children}
</Item>'''

def make_pointlight(brightness=1, color=(1,1,0.9), range_val=20, enabled=True, controllable=False):
    r = ref()
    # Use BoolValue child for controllable flag instead of attribute
    ctrl_child = ""
    if controllable:
        ctrl_child = make_bool_value("Controllable", True)
    return f'''<Item class="PointLight" referent="{r}">
<Properties>
{prop_string("Name", "PointLight")}
{prop_float("Brightness", brightness)}
{prop_color3("Color", color[0], color[1], color[2])}
{prop_float("Range", range_val)}
{prop_bool("Enabled", enabled)}
</Properties>
{ctrl_child}
</Item>'''

def make_spotlight(brightness=1, color=(1,1,1), range_val=30, angle=90, face=1, enabled=True):
    r = ref()
    return f'''<Item class="SpotLight" referent="{r}">
<Properties>
{prop_float("Brightness", brightness)}
{prop_color3("Color", color[0], color[1], color[2])}
{prop_float("Range", range_val)}
{prop_float("Angle", angle)}
{prop_token("Face", face)}
{prop_bool("Enabled", enabled)}
</Properties>
</Item>'''

def make_script(name, source, class_name="Script", disabled=False):
    r = ref()
    return f'''<Item class="{class_name}" referent="{r}">
<Properties>
{prop_string("Name", name)}
{prop_protected_string("Source", source)}
{prop_bool("Disabled", disabled)}
</Properties>
</Item>'''

def make_modulescript(name, source):
    return make_script(name, source, class_name="ModuleScript")

def make_localscript(name, source):
    return make_script(name, source, class_name="LocalScript")

def make_folder(name, children=""):
    r = ref()
    return f'''<Item class="Folder" referent="{r}">
<Properties>
{prop_string("Name", name)}
</Properties>
{children}
</Item>'''

def make_remote_event(name):
    r = ref()
    return f'''<Item class="RemoteEvent" referent="{r}">
<Properties>
{prop_string("Name", name)}
</Properties>
</Item>'''

def make_bindable_event(name):
    r = ref()
    return f'''<Item class="BindableEvent" referent="{r}">
<Properties>
{prop_string("Name", name)}
</Properties>
</Item>'''

def make_sound(name, sound_id="", volume=1, looped=False, parent_ref=None):
    r = ref()
    return f'''<Item class="Sound" referent="{r}">
<Properties>
{prop_string("Name", name)}
{prop_content("SoundId", sound_id)}
{prop_float("Volume", volume)}
{prop_bool("Looped", looped)}
</Properties>
</Item>'''

# === UI BUILDERS ===
def make_screengui(name, children="", enabled=True, display_order=0):
    r = ref()
    return f'''<Item class="ScreenGui" referent="{r}">
<Properties>
{prop_string("Name", name)}
{prop_bool("Enabled", enabled)}
{prop_int("DisplayOrder", display_order)}
{prop_bool("ResetOnSpawn", False)}
</Properties>
{children}
</Item>'''

def make_frame(name, pos="0,0,0,0", size="1,0,1,0", bg_color=(0.1,0.1,0.1),
               bg_transparency=0, visible=True, children="", zindex=1):
    r = ref()
    xs,xo,ys,yo = [float(x) for x in pos.split(",")]
    sxs,sxo,sys,syo = [float(x) for x in size.split(",")]
    return f'''<Item class="Frame" referent="{r}">
<Properties>
{prop_string("Name", name)}
{prop_udim2("Position", xs,int(xo),ys,int(yo))}
{prop_udim2("Size", sxs,int(sxo),sys,int(syo))}
{prop_color3("BackgroundColor3", bg_color[0], bg_color[1], bg_color[2])}
{prop_float("BackgroundTransparency", bg_transparency)}
{prop_bool("Visible", visible)}
{prop_int("ZIndex", zindex)}
</Properties>
{children}
</Item>'''

def make_textlabel(name, text, pos="0,0,0,0", size="1,0,1,0", text_color=(1,1,1),
                   bg_transparency=1, font=4, text_scaled=True, zindex=1, visible=True):
    r = ref()
    xs,xo,ys,yo = [float(x) for x in pos.split(",")]
    sxs,sxo,sys,syo = [float(x) for x in size.split(",")]
    return f'''<Item class="TextLabel" referent="{r}">
<Properties>
{prop_string("Name", name)}
{prop_string("Text", text)}
{prop_udim2("Position", xs,int(xo),ys,int(yo))}
{prop_udim2("Size", sxs,int(sxo),sys,int(syo))}
{prop_color3("TextColor3", text_color[0], text_color[1], text_color[2])}
{prop_float("BackgroundTransparency", bg_transparency)}
{prop_token("Font", font)}
{prop_bool("TextScaled", text_scaled)}
{prop_int("ZIndex", zindex)}
{prop_bool("Visible", visible)}
</Properties>
</Item>'''

def make_textbutton(name, text, pos="0,0,0,0", size="0,100,0,40", bg_color=(0.3,0.3,0.3),
                    text_color=(1,1,1), font=4, text_scaled=True, children=""):
    r = ref()
    xs,xo,ys,yo = [float(x) for x in pos.split(",")]
    sxs,sxo,sys,syo = [float(x) for x in size.split(",")]
    return f'''<Item class="TextButton" referent="{r}">
<Properties>
{prop_string("Name", name)}
{prop_string("Text", text)}
{prop_udim2("Position", xs,int(xo),ys,int(yo))}
{prop_udim2("Size", sxs,int(sxo),sys,int(syo))}
{prop_color3("BackgroundColor3", bg_color[0], bg_color[1], bg_color[2])}
{prop_color3("TextColor3", text_color[0], text_color[1], text_color[2])}
{prop_token("Font", font)}
{prop_bool("TextScaled", text_scaled)}
</Properties>
{children}
</Item>'''

def make_imagelabel(name, pos="0,0,0,0", size="1,0,1,0", image="",
                    bg_transparency=1, image_transparency=0, visible=True):
    r = ref()
    xs,xo,ys,yo = [float(x) for x in pos.split(",")]
    sxs,sxo,sys,syo = [float(x) for x in size.split(",")]
    return f'''<Item class="ImageLabel" referent="{r}">
<Properties>
{prop_string("Name", name)}
{prop_udim2("Position", xs,int(xo),ys,int(yo))}
{prop_udim2("Size", sxs,int(sxo),sys,int(syo))}
{prop_content("Image", image)}
{prop_float("BackgroundTransparency", bg_transparency)}
{prop_float("ImageTransparency", image_transparency)}
{prop_bool("Visible", visible)}
</Properties>
</Item>'''

def make_uicorner(radius=8):
    r = ref()
    return f'''<Item class="UICorner" referent="{r}">
<Properties>
<UDim name="CornerRadius"><S>0</S><O>{radius}</O></UDim>
</Properties>
</Item>'''

# === BUILD RESTAURANT ENVIRONMENT ===
def build_restaurant():
    parts = []

    # == FLOOR ==
    parts.append(make_part("Floor", 0, 0, 0, 40, 1, 30,
                           color=(0.25, 0.18, 0.12), material=256))  # Dark wood

    # == WALLS ==
    # Back wall
    parts.append(make_part("WallBack", 0, 6, -15, 40, 12, 0.5,
                           color=(0.35, 0.25, 0.18), material=256))
    # Left wall
    parts.append(make_part("WallLeft", -20, 6, 0, 0.5, 12, 30,
                           color=(0.35, 0.25, 0.18), material=256))
    # Right wall
    parts.append(make_part("WallRight", 20, 6, 0, 0.5, 12, 30,
                           color=(0.35, 0.25, 0.18), material=256))
    # Front wall (with gap for door and windows)
    parts.append(make_part("WallFrontLeft", -15, 6, 15, 10, 12, 0.5,
                           color=(0.35, 0.25, 0.18), material=256))
    parts.append(make_part("WallFrontRight", 15, 6, 15, 10, 12, 0.5,
                           color=(0.35, 0.25, 0.18), material=256))
    parts.append(make_part("WallFrontTop", 0, 10.5, 15, 20, 3, 0.5,
                           color=(0.35, 0.25, 0.18), material=256))

    # == CEILING ==
    parts.append(make_part("Ceiling", 0, 12, 0, 40, 0.5, 30,
                           color=(0.2, 0.15, 0.1), material=256))

    # == COUNTER (serving area) ==
    parts.append(make_part("Counter", 0, 2, 5, 12, 4, 2,
                           color=(0.4, 0.3, 0.2), material=256))
    # Counter top
    parts.append(make_part("CounterTop", 0, 4.1, 5, 13, 0.3, 2.5,
                           color=(0.5, 0.35, 0.2), material=256))

    # Counter target (where NPCs walk to - in front of counter, customer side)
    parts.append(make_part("CounterTarget", 0, 1, 7, 1, 1, 1,
                           color=(0,1,0), transparency=1, cancollide=False))

    # == LED ORDER DISPLAY SCREEN (mounted on wall behind counter) ==
    led_screen_ref = ref()
    led_surface_ref = ref()
    led_title_ref = ref()
    led_orders_ref = ref()
    led_screen_xml = f'''<Item class="Part" referent="{led_screen_ref}">
<Properties>
{prop_string("Name", "OrderScreen")}
{prop_bool("Anchored", True)}
{prop_bool("CanCollide", True)}
{prop_cframe("CFrame", 0, 7.5, 4)}
<Color3uint8 name="Color3uint8">{color_float_to_uint8(0.05, 0.05, 0.08)}</Color3uint8>
{prop_token("Material", 272)}
{prop_vector3("size", 8, 4, 0.3)}
{prop_token("shape", 1)}
{prop_float("Transparency", 0)}
</Properties>
{make_pointlight(0.6, (0.2, 0.8, 0.2), 10)}
<Item class="SurfaceGui" referent="{led_surface_ref}">
<Properties>
{prop_string("Name", "OrderDisplay")}
{prop_token("Face", 5)}
{prop_bool("Active", False)}
{prop_bool("ClipsDescendants", True)}
</Properties>
<Item class="TextLabel" referent="{led_title_ref}">
<Properties>
{prop_string("Name", "TitleText")}
{prop_string("Text", "=== ORDERS ===")}
{prop_udim2("Position", 0, 0, 0, 0)}
{prop_udim2("Size", 1, 0, 0.2, 0)}
{prop_color3("TextColor3", 0, 1, 0)}
{prop_float("BackgroundTransparency", 1)}
{prop_token("Font", 8)}
{prop_bool("TextScaled", True)}
</Properties>
</Item>
<Item class="TextLabel" referent="{led_orders_ref}">
<Properties>
{prop_string("Name", "OrdersText")}
{prop_string("Text", "Waiting for customers...")}
{prop_udim2("Position", 0, 0, 0.2, 0)}
{prop_udim2("Size", 1, 0, 0.8, 0)}
{prop_color3("TextColor3", 0, 0.9, 0)}
{prop_float("BackgroundTransparency", 1)}
{prop_token("Font", 4)}
{prop_bool("TextScaled", True)}
{prop_bool("TextWrapped", True)}
</Properties>
</Item>
</Item>
</Item>'''
    parts.append(led_screen_xml)
    # LED screen frame/border (metallic rim)
    parts.append(make_part("OrderScreenFrame", 0, 7.5, 3.8, 8.5, 4.5, 0.15,
                           color=(0.3, 0.3, 0.35), material=272))

    # == KITCHEN AREA ==
    # Kitchen floor (slightly raised)
    parts.append(make_part("KitchenFloor", 0, 0.2, -8, 20, 0.4, 12,
                           color=(0.3, 0.3, 0.3), material=272))  # Slate

    # == TAWA (Griddle) ==
    parts.append(make_part("Tawa", -5, 3.5, -8, 3, 0.3, 3,
                           color=(0.15, 0.15, 0.15), material=272, shape=2,
                           children=make_pointlight(0.8, (1, 0.5, 0.1), 8)))
    # Tawa stand
    parts.append(make_part("TawaStand", -5, 2, -8, 2, 3, 2,
                           color=(0.3, 0.3, 0.3), material=272))

    # == FRIDGE ==
    # Fridge body (back + sides)
    parts.append(make_part("Fridge", -12, 3.5, -12, 3, 7, 2.5,
                           color=(0.7, 0.7, 0.75), material=272))
    # Fridge door (separate part for open/close animation)
    parts.append(make_part("FridgeDoor", -12, 3.5, -10.7, 3, 6.8, 0.15,
                           color=(0.72, 0.72, 0.77), material=272))
    # Fridge handle
    parts.append(make_part("FridgeHandle", -10.8, 4, -10.6, 0.2, 2, 0.2,
                           color=(0.5, 0.5, 0.5), material=272))
    # Batter inside fridge (visible when door opens)
    parts.append(make_part("FridgeBatter", -12, 2.5, -12, 1.2, 1.8, 1,
                           color=(0.9, 0.85, 0.7), material=256, transparency=1))

    # == DINING TABLES (center table removed for clear NPC path to counter) ==
    # Table positions: left-front, right-front, left-back, right-back (no center)
    table_positions = [(-8, 10), (8, 10), (-8, 2), (8, 2)]
    for i, (tx, tz) in enumerate(table_positions):
        # Table top: 6 wide, 0.5 thick, 4 deep
        parts.append(make_part(f"Table{i+1}", tx, 3.5, tz, 6, 0.5, 4,
                               color=(0.4, 0.28, 0.18), material=256))
        # 4 table legs
        for lx, lz in [(-2.5, -1.5), (2.5, -1.5), (-2.5, 1.5), (2.5, 1.5)]:
            parts.append(make_part(f"TableLeg{i+1}_{lx}_{lz}", tx+lx, 1.75, tz+lz, 0.4, 3.5, 0.4,
                                   color=(0.3, 0.2, 0.12), material=256))
        # Menu card on each table (small standing card)
        menu_card_ref = ref()
        menu_card_surface_ref = ref()
        menu_card_text_ref = ref()
        menu_card_xml = f'''<Item class="Part" referent="{menu_card_ref}">
<Properties>
{prop_string("Name", f"MenuCard{i+1}")}
{prop_bool("Anchored", True)}
{prop_bool("CanCollide", True)}
{prop_cframe("CFrame", tx, 4.3, tz)}
<Color3uint8 name="Color3uint8">{color_float_to_uint8(0.9, 0.85, 0.7)}</Color3uint8>
{prop_token("Material", 256)}
{prop_vector3("size", 1, 1.4, 0.1)}
{prop_token("shape", 1)}
{prop_float("Transparency", 0)}
</Properties>
<Item class="SurfaceGui" referent="{menu_card_surface_ref}">
<Properties>
{prop_string("Name", "MenuText")}
{prop_token("Face", 5)}
{prop_bool("Active", False)}
</Properties>
<Item class="TextLabel" referent="{menu_card_text_ref}">
<Properties>
{prop_string("Name", "MenuLabel")}
{prop_string("Text", "MENU\\nDosa  $150\\nSoda  $150\\nAyran  $150")}
{prop_udim2("Position", 0, 0, 0, 0)}
{prop_udim2("Size", 1, 0, 1, 0)}
{prop_color3("TextColor3", 0.2, 0.1, 0)}
{prop_float("BackgroundTransparency", 1)}
{prop_token("Font", 4)}
{prop_bool("TextScaled", True)}
</Properties>
</Item>
</Item>
</Item>'''
        parts.append(menu_card_xml)

    # == CHAIRS (2 per table, matching 4 tables) ==
    chair_positions = [
        (-8, 11.8), (-8, 8.2),   # Table 1 (left-front)
        (8, 11.8), (8, 8.2),     # Table 2 (right-front)
        (-8, 3.8), (-8, 0.2),    # Table 3 (left-back)
        (8, 3.8), (8, 0.2),      # Table 4 (right-back)
    ]
    for i, (cx, cz) in enumerate(chair_positions):
        # Chair seat: 2.5 wide, 0.4 thick, 2.5 deep
        parts.append(make_part(f"Chair{i+1}", cx, 2, cz, 2.5, 0.4, 2.5,
                               color=(0.35, 0.22, 0.12), material=256))
        # Chair legs (4)
        for lx, lz in [(-1, -1), (1, -1), (-1, 1), (1, 1)]:
            parts.append(make_part(f"ChairLeg{i+1}_{lx}_{lz}", cx+lx, 1, cz+lz, 0.25, 2, 0.25,
                                   color=(0.3, 0.2, 0.12), material=256))
        # Chair back: 2.5 wide, 2.5 tall, 0.3 thick
        facing_back = 1 if cz > 5 else -1  # face toward counter
        parts.append(make_part(f"ChairBack{i+1}", cx, 3.5, cz + (1.1 * facing_back), 2.5, 2.5, 0.3,
                               color=(0.35, 0.22, 0.12), material=256))

    # == WINDOWS (with shutter frames) ==
    for i, wx in enumerate([-5, 5]):
        wname = ["left", "right"][i]
        # Window frame
        parts.append(make_part(f"WindowFrame_{wname}", wx, 6, 15.2, 5, 5, 0.3,
                               color=(0.3, 0.2, 0.1), material=256))
        # Window glass
        parts.append(make_part(f"WindowGlass_{wname}", wx, 6, 15.1, 4.5, 4.5, 0.1,
                               color=(0.5, 0.7, 0.9), material=256, transparency=0.6))

    # == SHUTTERS (direct workspace children so GameManager can find them) ==
    # Left window shutter
    parts.append(make_part("Shutter_left", -5, 6, 15.3, 4.8, 4.8, 0.15,
                           color=(0.5, 0.5, 0.5), material=272, transparency=0.8))
    # Right window shutter
    parts.append(make_part("Shutter_right", 5, 6, 15.3, 4.8, 4.8, 0.15,
                           color=(0.5, 0.5, 0.5), material=272, transparency=0.8))
    # Front shutter (main entrance)
    parts.append(make_part("Shutter_front", 0, 5, 15.3, 9, 9, 0.15,
                           color=(0.5, 0.5, 0.5), material=272, transparency=0.8))

    # == PHONE ==
    parts.append(make_part("Phone", 6, 4.3, 5, 0.5, 0.3, 0.8,
                           color=(0.1, 0.1, 0.1), material=256,
                           children=make_sound("RingSound", "", 0.8)))

    # == ROAD OUTSIDE ==
    parts.append(make_part("Road", 0, -0.3, 30, 60, 0.5, 20,
                           color=(0.2, 0.2, 0.2), material=256))
    # Road lines
    parts.append(make_part("RoadLine1", 0, -0.01, 30, 4, 0.01, 0.3,
                           color=(0.9, 0.9, 0.1), material=256))
    parts.append(make_part("RoadLine2", -12, -0.01, 30, 4, 0.01, 0.3,
                           color=(0.9, 0.9, 0.1), material=256))
    parts.append(make_part("RoadLine3", 12, -0.01, 30, 4, 0.01, 0.3,
                           color=(0.9, 0.9, 0.1), material=256))

    # == PARKING AREA (for Terrifier Truck) ==
    parts.append(make_part("ParkingArea", 25, -0.2, 25, 10, 0.5, 10,
                           color=(0.25, 0.25, 0.25), material=256))

    # == TERRIFIER TRUCK (Cursed Object - Ice Cream Van style) ==
    # Main body with BoolValue CursedObject and StringValue NPCType
    truck_children = (
        make_pointlight(0.4, (1, 0, 0), 18) +
        make_bool_value("CursedObject", True) +
        make_string_value("NPCType", "TerrifierTruck")
    )
    parts.append(make_part("TerrifierTruck", 25, 3, 25, 5, 5, 10,
                           color=(0.95, 0.95, 0.98), material=256,
                           children=truck_children))
    # Truck roof (red stripe)
    parts.append(make_part("TruckRoof", 25, 6, 25, 5.2, 0.3, 10.2,
                           color=(0.8, 0.15, 0.15), material=256))
    # Truck cabin (front)
    parts.append(make_part("TruckCabin", 25, 3, 19.5, 5, 4, 2,
                           color=(0.85, 0.85, 0.9), material=256))
    # Windshield (dark, can't see inside)
    parts.append(make_part("TruckWindshield", 25, 4.5, 18.3, 4, 2, 0.1,
                           color=(0.05, 0.05, 0.1), material=256, transparency=0.2))
    # Wheels
    for wx, wz in [(22.8, 22), (27.2, 22), (22.8, 28), (27.2, 28)]:
        parts.append(make_part(f"TruckWheel_{wx}_{wz}", wx, 0.8, wz, 0.5, 1.5, 1.5,
                               color=(0.1, 0.1, 0.1), material=256, shape=2))
    # Ice cream cone on top (creepy)
    parts.append(make_part("IceCreamCone", 25, 7, 25, 1, 2, 1,
                           color=(0.9, 0.7, 0.4), material=256))
    parts.append(make_part("IceCreamScoop", 25, 8.5, 25, 1.2, 1.2, 1.2,
                           color=(1, 0.6, 0.7), material=256, shape=2))
    # Red stripe along side
    parts.append(make_part("TruckStripe", 22.4, 3, 25, 0.1, 1, 9,
                           color=(0.8, 0.1, 0.1), material=256))
    parts.append(make_part("TruckStripe2", 27.6, 3, 25, 0.1, 1, 9,
                           color=(0.8, 0.1, 0.1), material=256))
    # Eerie red headlights
    parts.append(make_part("TruckHeadlight1", 23.5, 3, 18.3, 0.8, 0.8, 0.1,
                           color=(1, 0, 0), material=256, transparency=0.3,
                           children=make_pointlight(0.8, (1, 0, 0), 25)))
    parts.append(make_part("TruckHeadlight2", 26.5, 3, 18.3, 0.8, 0.8, 0.1,
                           color=(1, 0, 0), material=256, transparency=0.3))

    # == BACK ROOM (Safe room for Night 5) ==
    parts.append(make_part("BackRoomDoor", 0, 4, -14.8, 3, 7, 0.3,
                           color=(0.4, 0.25, 0.15), material=256))
    parts.append(make_part("BackRoomFloor", 0, 0, -22, 10, 1, 8,
                           color=(0.2, 0.15, 0.1), material=256))
    parts.append(make_part("BackRoomWallL", -5, 4, -22, 0.5, 8, 8,
                           color=(0.3, 0.2, 0.15), material=256))
    parts.append(make_part("BackRoomWallR", 5, 4, -22, 0.5, 8, 8,
                           color=(0.3, 0.2, 0.15), material=256))
    parts.append(make_part("BackRoomWallBack", 0, 4, -26, 10, 8, 0.5,
                           color=(0.3, 0.2, 0.15), material=256))
    # Safe room trigger (using BoolValue instead of BinaryString attribute)
    safe_children = make_bool_value("SafeRoom", True)
    parts.append(make_part("SafeRoomTrigger", 0, 2, -22, 8, 4, 6,
                           transparency=1, cancollide=False,
                           children=safe_children))

    # == NEON SIGN with SurfaceGui text ==
    neon_sign_ref = ref()
    neon_surface_ref = ref()
    neon_text_ref = ref()
    neon_glow_ref = ref()
    neon_sign_xml = f'''<Item class="Part" referent="{neon_sign_ref}">
<Properties>
{prop_string("Name", "NeonSign")}
{prop_bool("Anchored", True)}
{prop_bool("CanCollide", True)}
{prop_cframe("CFrame", 0, 11, 15.5)}
<Color3uint8 name="Color3uint8">{color_float_to_uint8(0.15, 0.05, 0.02)}</Color3uint8>
{prop_token("Material", 256)}
{prop_vector3("size", 14, 3, 0.3)}
{prop_token("shape", 1)}
{prop_float("Transparency", 0)}
</Properties>
{make_pointlight(2.5, (1, 0.5, 0), 35)}
<Item class="SurfaceGui" referent="{neon_surface_ref}">
<Properties>
{prop_string("Name", "NeonText")}
{prop_token("Face", 5)}
{prop_bool("Active", False)}
{prop_bool("ClipsDescendants", False)}
</Properties>
<Item class="TextLabel" referent="{neon_text_ref}">
<Properties>
{prop_string("Name", "SignText")}
{prop_string("Text", "ROAD SIDE DOSA")}
{prop_udim2("Position", 0, 0, 0, 0)}
{prop_udim2("Size", 1, 0, 1, 0)}
{prop_color3("TextColor3", 1, 0.5, 0)}
{prop_float("BackgroundTransparency", 1)}
{prop_token("Font", 8)}
{prop_bool("TextScaled", True)}
{prop_float("TextStrokeTransparency", 0.3)}
{prop_color3("TextStrokeColor3", 0.8, 0.2, 0)}
</Properties>
</Item>
</Item>
<Item class="PointLight" referent="{neon_glow_ref}">
<Properties>
{prop_string("Name", "NeonGlow")}
{prop_float("Brightness", 1.5)}
{prop_color3("Color", 1, 0.3, 0)}
{prop_float("Range", 20)}
{prop_bool("Enabled", True)}
</Properties>
</Item>
</Item>'''
    parts.append(neon_sign_xml)

    # Sub-sign: "OPEN 24 HRS" (eerie because it's nighttime)
    parts.append(make_part("SubSign", 0, 9.5, 15.5, 5, 0.8, 0.2,
                           color=(0.8, 0.1, 0.1), material=256,
                           children=make_pointlight(0.5, (1, 0.1, 0.1), 10)))

    # == INTERIOR LIGHTS ==
    light_positions = [(-8, 11, 0), (0, 11, 0), (8, 11, 0), (0, 11, -8)]
    for i, (lx, ly, lz) in enumerate(light_positions):
        light_child = make_pointlight(0.5, (1, 0.9, 0.7), 25, controllable=True)
        parts.append(make_part(f"CeilingLight{i+1}", lx, ly, lz, 1, 0.3, 1,
                               color=(1, 0.95, 0.8), material=256,
                               children=light_child))

    # == STOVE/GAS (next to tawa) ==
    parts.append(make_part("GasStove", -5, 1, -8, 3.5, 2, 3.5,
                           color=(0.15, 0.15, 0.2), material=272))
    # Flame effect
    parts.append(make_part("Flame", -5, 3.2, -8, 1, 0.5, 1,
                           color=(1, 0.5, 0), material=256, transparency=0.3,
                           children=make_pointlight(1.5, (1, 0.4, 0), 6)))

    # == SINK ==
    parts.append(make_part("Sink", 8, 2.5, -10, 2.5, 1.5, 2,
                           color=(0.6, 0.6, 0.65), material=272))

    # == ADDITIONAL RESTAURANT PROPS ==

    # Menu board on back wall
    parts.append(make_part("MenuBoard", 0, 8, -14.7, 6, 3, 0.2,
                           color=(0.1, 0.1, 0.1), material=256))
    # Menu board light
    parts.append(make_part("MenuBoardLight", 0, 9.8, -14.5, 6.5, 0.2, 0.3,
                           color=(0.8, 0.8, 0.8), material=272,
                           children=make_spotlight(0.6, (1, 0.95, 0.85), 10, 120, 1)))

    # Shelf with jars (behind counter)
    parts.append(make_part("Shelf1", -12, 5, -14.5, 8, 0.3, 1.5,
                           color=(0.4, 0.28, 0.18), material=256))
    parts.append(make_part("Shelf2", -12, 7, -14.5, 8, 0.3, 1.5,
                           color=(0.4, 0.28, 0.18), material=256))
    # Jars on shelf
    for j, jx in enumerate([-15, -13, -11, -9]):
        parts.append(make_part(f"Jar{j+1}", jx, 5.6, -14.5, 0.6, 1, 0.6,
                               color=(0.3, 0.6, 0.3), material=256, transparency=0.3))
    # Spice containers
    for j, jx in enumerate([-14, -12, -10]):
        parts.append(make_part(f"Spice{j+1}", jx, 7.6, -14.5, 0.8, 0.8, 0.6,
                               color=(0.7, 0.4, 0.1), material=256))

    # Cash register on counter
    parts.append(make_part("CashRegister", 4, 4.5, 5, 1.2, 1, 1,
                           color=(0.15, 0.15, 0.15), material=272))
    parts.append(make_part("CashScreen", 4, 5.2, 4.7, 0.8, 0.5, 0.1,
                           color=(0.1, 0.3, 0.1), material=256))

    # Paper towel roll holder
    parts.append(make_part("PaperTowel", 10, 4, -8, 0.4, 0.8, 0.4,
                           color=(1, 1, 1), material=256))

    # Trash bin
    parts.append(make_part("TrashBin", 12, 1.5, -6, 1.5, 3, 1.5,
                           color=(0.3, 0.3, 0.35), material=272))

    # Dosa batter bucket (near tawa)
    parts.append(make_part("BatterBucket", -3, 1.5, -10, 1, 1.5, 1,
                           color=(0.8, 0.8, 0.85), material=272))

    # Wall clock
    parts.append(make_part("WallClock", -19.7, 8, 5, 0.2, 1.5, 1.5,
                           color=(0.3, 0.2, 0.1), material=256, shape=2))

    # Outdoor elements
    # Street lamp
    parts.append(make_part("StreetLampPole", -15, 5, 25, 0.3, 10, 0.3,
                           color=(0.3, 0.3, 0.3), material=272))
    parts.append(make_part("StreetLampHead", -15, 10.5, 25, 1.5, 0.3, 1.5,
                           color=(0.2, 0.2, 0.2), material=272,
                           children=make_pointlight(0.8, (1, 0.8, 0.5), 35)))
    # Second street lamp
    parts.append(make_part("StreetLampPole2", 15, 5, 25, 0.3, 10, 0.3,
                           color=(0.3, 0.3, 0.3), material=272))
    parts.append(make_part("StreetLampHead2", 15, 10.5, 25, 1.5, 0.3, 1.5,
                           color=(0.2, 0.2, 0.2), material=272,
                           children=make_pointlight(0.8, (1, 0.8, 0.5), 35)))

    # Dumpster outside
    parts.append(make_part("Dumpster", -25, 2, 20, 3, 3, 2,
                           color=(0.2, 0.35, 0.2), material=272))

    # Sidewalk
    parts.append(make_part("Sidewalk", 0, -0.1, 18, 45, 0.3, 5,
                           color=(0.5, 0.5, 0.5), material=256))

    # Potted plant at entrance
    parts.append(make_part("PotPlant1", -10, 1.5, 14, 1, 3, 1,
                           color=(0.2, 0.5, 0.15), material=256))
    parts.append(make_part("Pot1", -10, 0.5, 14, 1.2, 1, 1.2,
                           color=(0.5, 0.3, 0.15), material=256))
    # Another plant
    parts.append(make_part("PotPlant2", 10, 1.5, 14, 1, 3, 1,
                           color=(0.2, 0.5, 0.15), material=256))
    parts.append(make_part("Pot2", 10, 0.5, 14, 1.2, 1, 1.2,
                           color=(0.5, 0.3, 0.15), material=256))

    # Ceiling fan (not spinning - creepy stopped fan)
    parts.append(make_part("CeilingFanBase", 0, 11.5, 3, 0.5, 0.5, 0.5,
                           color=(0.3, 0.3, 0.3), material=272))
    parts.append(make_part("FanBlade1", 0, 11.3, 3, 4, 0.1, 0.5,
                           color=(0.35, 0.25, 0.15), material=256))
    parts.append(make_part("FanBlade2", 0, 11.3, 3, 0.5, 0.1, 4,
                           color=(0.35, 0.25, 0.15), material=256))

    # Blood stain on floor (subtle horror detail)
    parts.append(make_part("BloodStain", -6, 0.52, 8, 2, 0.01, 1.5,
                           color=(0.3, 0.05, 0.05), material=256, transparency=0.6))

    # == CLEANUP ZONE (for naked guy event Night 2) ==
    cleanup_children = make_bool_value("CleanupZone", True)
    parts.append(make_part("MessZone", 3, 0.52, 10, 2.5, 0.01, 2,
                           color=(0.4, 0.3, 0.1), material=256, transparency=1,
                           children=cleanup_children))

    # == MOP (near sink, player can pick up) ==
    parts.append(make_part("Mop", 10, 2, -10, 0.15, 4, 0.15,
                           color=(0.5, 0.35, 0.2), material=256))
    parts.append(make_part("MopHead", 10, 0.5, -10, 0.8, 0.3, 0.5,
                           color=(0.6, 0.6, 0.65), material=256))

    # == COOKING VISUAL FEEDBACK ==
    # Dosa on tawa (appears during cooking, initially hidden)
    cooking_children = make_bool_value("CookingVisual", True)
    parts.append(make_part("DosaOnTawa", -5, 3.65, -8, 2, 0.1, 2,
                           color=(0.85, 0.7, 0.4), material=256, transparency=1, shape=2,
                           children=cooking_children))

    # == IMPROVED SAFE ROOM (Night 5) ==
    # Hiding cabinet in safe room
    parts.append(make_part("HidingCabinet", -3, 2, -24, 2, 4, 1.5,
                           color=(0.3, 0.22, 0.12), material=256))
    # Cabinet door
    parts.append(make_part("CabinetDoor", -3, 2, -23.2, 1.8, 3.5, 0.15,
                           color=(0.35, 0.25, 0.15), material=256))
    # Old mattress on floor
    parts.append(make_part("Mattress", 2, 0.7, -23, 3, 0.4, 2,
                           color=(0.5, 0.45, 0.4), material=256))
    # Flickering bulb in safe room
    parts.append(make_part("SafeRoomBulb", 0, 7.5, -22, 0.3, 0.3, 0.3,
                           color=(1, 0.9, 0.6), material=256,
                           children=make_pointlight(0.2, (1, 0.85, 0.6), 12)))
    # Creepy writing on wall
    parts.append(make_part("WallWriting", 0, 4, -25.7, 4, 2, 0.1,
                           color=(0.3, 0.05, 0.05), material=256, transparency=0.4))

    # == CCTV CAMERAS ==
    cctv_positions = [
        ("CCTV_Front", 0, 11, 14, 0, 0, -1),    # Looking at entrance
        ("CCTV_Kitchen", 0, 11, -6, 0, 0, 1),     # Looking at kitchen
        ("CCTV_Road", 15, 11, 14, 0, 0, -1),      # Looking at road
        ("CCTV_Parking", 19, 8, 15, 1, 0, 0),     # Looking at parking
    ]
    cctv_parts = []
    for name, cx, cy, cz, fx, fy, fz in cctv_positions:
        cctv_parts.append(make_part(name, cx, cy, cz, 0.5, 0.5, 0.8,
                                    color=(0.2, 0.2, 0.2), material=272))

    # == NPC SPAWN POINTS (just outside entrance, so they walk in through door) ==
    spawn_parts = []
    spawn_positions = [(0, 1, 18), (-3, 1, 18), (3, 1, 18)]
    for i, (sx, sy, sz) in enumerate(spawn_positions):
        spawn_parts.append(make_part(f"Spawn{i+1}", sx, sy, sz, 1, 1, 1,
                                     transparency=1, cancollide=False))

    # == SPAWNLOCATION ==
    spawn_loc = f'''<Item class="SpawnLocation" referent="{ref()}">
<Properties>
{prop_string("Name", "SpawnLocation")}
{prop_cframe("CFrame", 0, 2, 12)}
{prop_vector3("size", 6, 1, 6)}
{prop_bool("Anchored", True)}
{prop_float("Transparency", 1)}
{prop_bool("AllowTeamChangeOnTouch", False)}
{prop_int("Duration", 0)}
</Properties>
</Item>'''

    return "\n".join(parts), "\n".join(cctv_parts), "\n".join(spawn_parts), spawn_loc

# === BUILD UI ===
def build_ui():
    """Build the complete game UI"""

    # --- HUD ---
    hud_children = "\n".join([
        # Night label (top center)
        make_textlabel("NightLabel", "Night 1", "0.4,0,0,10", "0.2,0,0,30",
                       text_color=(1,0.8,0.3), font=8),
        # Currency (top right)
        make_textlabel("CurrencyLabel", "$0", "0.8,0,0,10", "0.15,0,0,30",
                       text_color=(0,1,0), font=8),
        # Batter count
        make_textlabel("BatterLabel", "Batter: 0", "0,10,0,10", "0.15,0,0,25",
                       text_color=(1,0.9,0.5), font=4),
        # Lights indicator
        make_textlabel("LightsIndicator", "LIGHTS: ON", "0,10,0,40", "0.12,0,0,20",
                       text_color=(0,1,0), font=4),
        # Gaze warning (hidden by default)
        make_textlabel("GazeWarning", "DON'T LOOK!", "0.3,0,0.4,0", "0.4,0,0,40",
                       text_color=(1,0,0), font=8, visible=False),
        # Stamina bar
        make_frame("StaminaBar", "0.35,0,0.92,0", "0.3,0,0,15",
                   bg_color=(0.15,0.15,0.15), children=
                   make_frame("Fill", "0,0,0,0", "1,0,1,0", bg_color=(0,0.8,0))),
        # Menu container (for food item buttons)
        make_frame("MenuContainer", "0.3,0,0.85,0", "0.4,0,0,50",
                   bg_color=(0,0,0), bg_transparency=1),
        # Shutter buttons
        make_textbutton("Shutter_front", "Front: OPEN", "0.85,0,0.3,0", "0,120,0,30",
                        bg_color=(0.8,0.2,0.2), text_color=(1,1,1)),
        make_textbutton("Shutter_left", "Left: OPEN", "0.85,0,0.37,0", "0,120,0,30",
                        bg_color=(0.8,0.2,0.2), text_color=(1,1,1)),
        make_textbutton("Shutter_right", "Right: OPEN", "0.85,0,0.44,0", "0,120,0,30",
                        bg_color=(0.8,0.2,0.2), text_color=(1,1,1)),
        # Controls hint
        make_textlabel("ControlsHint",
                       "[F] Batter  [T] Cook  [E] Interact  [C] CCTV  [L] Lights  [1/2/3] Shutters  [Shift] Sprint  [B] Shop  [Tab] Leaderboard",
                       "0,0,0.96,0", "1,0,0,25", text_color=(0.6,0.6,0.6), font=4,
                       text_scaled=True),
    ])
    hud = make_frame("HUD", "0,0,0,0", "1,0,1,0", bg_transparency=1, children=hud_children)

    # --- Phone UI ---
    phone_children = "\n".join([
        make_frame("PhoneBG", "0.3,0,0.2,0", "0.4,0,0.5,0", bg_color=(0.05,0.05,0.05),
                   children="\n".join([
                       make_uicorner(12),
                       make_textlabel("CallerLabel", "MANAGER", "0.1,0,0.05,0", "0.8,0,0,30",
                                      text_color=(0,1,0), font=8),
                       make_textlabel("PhoneIcon", "📞", "0.4,0,0.15,0", "0.2,0,0.2,0",
                                      text_color=(0,1,0), font=4),
                   ])),
    ])
    phone = make_frame("PhoneUI", "0,0,0,0", "1,0,1,0", bg_color=(0,0,0),
                       bg_transparency=0.5, visible=True, children=phone_children, zindex=5)

    # --- Dialogue UI ---
    dialogue_children = "\n".join([
        make_frame("DialogueBG", "0.15,0,0.7,0", "0.7,0,0.15,0", bg_color=(0.05,0.05,0.08),
                   children="\n".join([
                       make_uicorner(8),
                       make_textlabel("DialogueText", "", "0.05,0,0.1,0", "0.8,0,0.7,0",
                                      text_color=(0.9,0.9,0.9), font=4, text_scaled=True),
                       make_textlabel("ProgressLabel", "1/1", "0.85,0,0.05,0", "0.1,0,0,20",
                                      text_color=(0.5,0.5,0.5), font=4),
                       # Skip hint
                       make_textlabel("SkipHint", "[Click to skip]", "0.3,0,0.85,0", "0.4,0,0,15",
                                      text_color=(0.4,0.4,0.4), font=4, visible=True),
                   ])),
    ])
    dialogue = make_frame("DialogueUI", "0,0,0,0", "1,0,1,0", bg_transparency=1,
                          visible=True, children=dialogue_children, zindex=6)

    # --- CCTV UI ---
    cctv_children = "\n".join([
        make_frame("CCTVOverlay", "0,0,0,0", "1,0,1,0", bg_color=(0,0,0), bg_transparency=0.3),
        make_textlabel("CameraLabel", "CAM 1", "0.02,0,0.02,0", "0,80,0,25",
                       text_color=(1,0,0), font=8),
        make_textlabel("RecLabel", "● REC", "0.85,0,0.02,0", "0,80,0,25",
                       text_color=(1,0,0), font=8),
        make_textlabel("CCTVHint", "[Q/E] Switch Camera  [C] Exit CCTV", "0.3,0,0.95,0", "0.4,0,0,20",
                       text_color=(0.8,0.8,0.8), font=4),
        # Anomaly warning (GamePass: Anomaly Identifier)
        make_textlabel("AnomalyWarning", "", "0.2,0,0.08,0", "0.6,0,0,30",
                       text_color=(1,0,0), font=8, visible=False),
    ])
    cctv = make_frame("CCTVUI", "0,0,0,0", "1,0,1,0", bg_transparency=1,
                      visible=False, children=cctv_children, zindex=4)

    # --- Death UI ---
    death_children = "\n".join([
        make_textlabel("YouDiedLabel", "YOU DIED", "0.25,0,0.2,0", "0.5,0,0,60",
                       text_color=(0.8,0,0), font=8),
        make_textlabel("CauseLabel", "", "0.2,0,0.4,0", "0.6,0,0,30",
                       text_color=(0.7,0.7,0.7), font=4),
        make_textlabel("NightLabel", "Night 1", "0.35,0,0.5,0", "0.3,0,0,25",
                       text_color=(0.5,0.5,0.5), font=4),
        make_textbutton("RetryButton", "RETRY", "0.35,0,0.65,0", "0.3,0,0,50",
                        bg_color=(0.6,0.1,0.1), text_color=(1,1,1),
                        children=make_uicorner(8)),
    ])
    death = make_frame("DeathUI", "0,0,0,0", "1,0,1,0", bg_color=(0,0,0),
                       bg_transparency=0.2, visible=False, children=death_children, zindex=8)

    # --- Menu Selection UI ---
    menu_children = "\n".join([
        make_textlabel("MenuTitle", "Select Item to Serve", "0.3,0,0.3,0", "0.4,0,0,30",
                       text_color=(1,0.8,0.3), font=8),
        make_frame("ItemButtons", "0.2,0,0.4,0", "0.6,0,0.2,0", bg_transparency=1),
    ])
    menu = make_frame("MenuUI", "0,0,0,0", "1,0,1,0", bg_color=(0,0,0),
                      bg_transparency=0.5, visible=False, children=menu_children, zindex=7)

    # --- Jump Scare UI ---
    jumpscare_children = "\n".join([
        make_imagelabel("ScareImage", "0,0,0,0", "1,0,1,0", image="",
                        bg_transparency=0, image_transparency=1, visible=False),
        make_frame("RedFlash", "0,0,0,0", "1,0,1,0", bg_color=(0.8,0,0), bg_transparency=0.3),
    ])
    jumpscare = make_frame("JumpscareUI", "0,0,0,0", "1,0,1,0", bg_color=(0,0,0),
                           visible=False, children=jumpscare_children, zindex=10)

    # --- Night Start UI ---
    nightstart_children = "\n".join([
        make_textlabel("TitleLabel", "NIGHT 1", "0.2,0,0.35,0", "0.6,0,0,80",
                       text_color=(0.8,0.2,0.1), font=8),
    ])
    nightstart = make_frame("NightStartUI", "0,0,0,0", "1,0,1,0", bg_color=(0,0,0),
                            visible=False, children=nightstart_children, zindex=9)

    # --- Lobby / Title Screen ---
    lobby_children = "\n".join([
        # Dark overlay
        make_frame("LobbyBG", "0,0,0,0", "1,0,1,0", bg_color=(0.02,0.01,0.03), bg_transparency=0.15),
        # Title
        make_textlabel("TitleLabel", "ROAD SIDE DOSA", "0.15,0,0.1,0", "0.7,0,0,80",
                       text_color=(0.9,0.35,0.05), font=8),
        # Subtitle
        make_textlabel("SubtitleLabel", "A Psychological Horror Experience", "0.2,0,0.25,0", "0.6,0,0,30",
                       text_color=(0.7,0.2,0.1), font=4),
        # Tagline
        make_textlabel("TaglineLabel", "5 Nights. 1 Dhaba. Infinite Terror.", "0.2,0,0.32,0", "0.6,0,0,22",
                       text_color=(0.5,0.5,0.5), font=4),
        # Instructions
        make_textlabel("InstructionsLabel",
                       "Cook dosa. Serve customers. Follow the rules. Survive.",
                       "0.15,0,0.42,0", "0.7,0,0,20",
                       text_color=(0.6,0.55,0.4), font=4),
        # Start button
        make_textbutton("StartButton", "START SHIFT", "0.35,0,0.55,0", "0.3,0,0,60",
                        bg_color=(0.7,0.25,0.05), text_color=(1,1,1),
                        children=make_uicorner(10)),
        # Credits
        make_textlabel("CreditsLabel", "v3.0", "0.85,0,0.92,0", "0.1,0,0,18",
                       text_color=(0.3,0.3,0.3), font=4),
        # Controls info
        make_textlabel("ControlsInfo",
                       "Controls: WASD Move | Shift Sprint | F Batter | T Cook | C CCTV | L Lights | 1-2-3 Shutters | B Shop | Tab Leaderboard",
                       "0.1,0,0.7,0", "0.8,0,0,18",
                       text_color=(0.4,0.4,0.4), font=4),
    ])
    lobby = make_frame("LobbyUI", "0,0,0,0", "1,0,1,0", bg_transparency=0, children=lobby_children)

    # --- GamePass Shop UI ---
    gamepass_children = "\n".join([
        make_frame("ShopBG", "0.2,0,0.15,0", "0.6,0,0.7,0", bg_color=(0.05,0.03,0.08),
                   children="\n".join([
                       make_uicorner(12),
                       make_textlabel("ShopTitle", "GAME PASSES", "0.1,0,0.02,0", "0.8,0,0,40",
                                      text_color=(1,0.8,0.2), font=8),
                       make_textlabel("ShopSubtitle", "[B] to close", "0.35,0,0.1,0", "0.3,0,0,18",
                                      text_color=(0.5,0.5,0.5), font=4),
                       # Pass 1: Anomaly Identifier
                       make_textbutton("Pass_AnomalyIdentifier",
                                       "Anomaly Identifier (250R$)\\nHighlights anomaly NPCs on CCTV",
                                       "0.05,0,0.18,0", "0.9,0,0,55",
                                       bg_color=(0.15,0.05,0.2), text_color=(0.9,0.7,1),
                                       children=make_uicorner(8)),
                       # Pass 2: Jumpscare Friend
                       make_textbutton("Pass_JumpscareFriend",
                                       "Jumpscare Friend (100R$)\\nPrank nearby players [J key]",
                                       "0.05,0,0.33,0", "0.9,0,0,55",
                                       bg_color=(0.2,0.05,0.1), text_color=(1,0.7,0.8),
                                       children=make_uicorner(8)),
                       # Pass 3: The Gun
                       make_textbutton("Pass_TheGun",
                                       "The Gun (350R$)\\nDefend against threats [R key]",
                                       "0.05,0,0.48,0", "0.9,0,0,55",
                                       bg_color=(0.15,0.1,0.05), text_color=(1,0.85,0.5),
                                       children=make_uicorner(8)),
                       # Pass 4: Humanity Serum
                       make_textbutton("Pass_HumanitySerum",
                                       "Humanity Serum (500R$)\\nTransform anomaly NPCs [H key]",
                                       "0.05,0,0.63,0", "0.9,0,0,55",
                                       bg_color=(0.05,0.15,0.1), text_color=(0.5,1,0.8),
                                       children=make_uicorner(8)),
                       # Controls hint
                       make_textlabel("PassControls",
                                      "Purchase passes in Roblox Store to activate",
                                      "0.1,0,0.82,0", "0.8,0,0,20",
                                      text_color=(0.4,0.4,0.4), font=4),
                   ])),
    ])
    gamepass = make_frame("GamePassUI", "0,0,0,0", "1,0,1,0", bg_color=(0,0,0),
                          bg_transparency=0.4, visible=True, children=gamepass_children, zindex=6)

    # --- Leaderboard UI ---
    leaderboard_children = "\n".join([
        make_frame("LeaderboardBG", "0.25,0,0.1,0", "0.5,0,0.8,0", bg_color=(0.05,0.05,0.08),
                   children="\n".join([
                       make_uicorner(12),
                       make_textlabel("LeaderboardTitle", "TOP CHEFS", "0.1,0,0.02,0", "0.8,0,0,40",
                                      text_color=(1,0.85,0), font=8),
                       make_textlabel("LeaderboardSubtitle", "[Tab] to close", "0.35,0,0.1,0", "0.3,0,0,18",
                                      text_color=(0.5,0.5,0.5), font=4),
                       # Leaderboard list container
                       make_frame("LeaderboardList", "0.05,0,0.15,0", "0.9,0,0.8,0",
                                  bg_color=(0.03,0.03,0.05), bg_transparency=0.5,
                                  children="\n".join([
                                      make_textlabel("HeaderLabel", "#  Player  Earnings",
                                                     "0,5,0,3", "1,-10,0,25",
                                                     text_color=(0.7,0.7,0.7), font=8),
                                  ])),
                   ])),
    ])
    leaderboard = make_frame("LeaderboardUI", "0,0,0,0", "1,0,1,0", bg_color=(0,0,0),
                             bg_transparency=0.4, visible=True, children=leaderboard_children, zindex=6)

    # Each overlay goes into its own ScreenGui with Enabled=false
    lobby_gui = make_screengui("LobbyScreenGui", lobby, enabled=True, display_order=0)
    main_gui = make_screengui("MainUI", "\n".join([hud]), enabled=True, display_order=1)
    phone_gui = make_screengui("PhoneScreenGui", "\n".join([phone, dialogue]), enabled=False, display_order=5)
    cctv_gui = make_screengui("CCTVScreenGui", cctv, enabled=False, display_order=4)
    death_gui = make_screengui("DeathScreenGui", death, enabled=False, display_order=8)
    menu_gui = make_screengui("MenuScreenGui", menu, enabled=False, display_order=7)
    jumpscare_gui = make_screengui("JumpscareScreenGui", jumpscare, enabled=False, display_order=10)
    nightstart_gui = make_screengui("NightStartScreenGui", nightstart, enabled=False, display_order=9)
    gamepass_gui = make_screengui("GamePassScreenGui", gamepass, enabled=False, display_order=6)
    leaderboard_gui = make_screengui("LeaderboardScreenGui", leaderboard, enabled=False, display_order=6)

    return "\n".join([lobby_gui, main_gui, phone_gui, cctv_gui, death_gui, menu_gui, jumpscare_gui, nightstart_gui, gamepass_gui, leaderboard_gui])

# === BUILD REMOTE EVENTS ===
def build_remotes():
    remote_names = [
        "StartNight", "EndNight", "PhoneRing", "PhoneDialogue", "PhoneDialogueEnd",
        "PlayerDeath", "NightComplete", "TriggerEvent", "UpdateHUD",
        "JumpScare", "SpawnNPC", "NPCDialogue", "NPCLeave",
        "RequestStartNight", "RequestRetry",
        "GrabBatter", "CookDosa", "ServeCustomer",
        "ToggleShutter", "ToggleLights", "GazeDeath",
        "TruckArrival", "SpillBatter", "ReachedSafeRoom",
        "CleanMess", "LookedAtFace",
        "UpdateCurrency", "UpdateNightProgress", "RecordDeath", "RecordServe",
        "GameCompleted", "LoadPlayerData",
        "UpdateLeaderboard",
        "TradeRequest", "TradeRequestReceived", "TradeAccept", "TradeComplete",
        "GamePassOwned", "CheckGamePass", "GamePassCheckResult",
        "UseJumpscareFriend", "UseHumanitySerum", "NPCTransformed",
    ]
    events = "\n".join([make_remote_event(name) for name in remote_names])
    return make_folder("Remotes", events)

# === BUILD LIGHTING ===
def build_lighting():
    r = ref()
    atmosphere_ref = ref()
    bloom_ref = ref()
    color_ref = ref()
    cctv_filter_ref = ref()

    return f'''<Item class="Lighting" referent="{r}">
<Properties>
{prop_string("Name", "Lighting")}
{prop_float("Brightness", 0.3)}
{prop_float("ClockTime", 22)}
{prop_color3("Ambient", 0.05, 0.03, 0.08)}
{prop_color3("OutdoorAmbient", 0.03, 0.02, 0.05)}
{prop_float("FogEnd", 180)}
{prop_color3("FogColor", 0.04, 0.02, 0.06)}
{prop_token("Technology", 3)}
{prop_float("EnvironmentDiffuseScale", 0.3)}
{prop_float("EnvironmentSpecularScale", 0.2)}
{prop_bool("GlobalShadows", True)}
</Properties>
<Item class="Atmosphere" referent="{atmosphere_ref}">
<Properties>
{prop_string("Name", "NightAtmosphere")}
{prop_float("Density", 0.35)}
{prop_float("Offset", 0)}
{prop_color3("Color", 0.1, 0.08, 0.15)}
{prop_color3("Decay", 0.5, 0.4, 0.6)}
{prop_float("Glare", 0.1)}
{prop_float("Haze", 3)}
</Properties>
</Item>
<Item class="BloomEffect" referent="{bloom_ref}">
<Properties>
{prop_string("Name", "HorrorBloom")}
{prop_float("Intensity", 0.4)}
{prop_float("Size", 30)}
{prop_float("Threshold", 1.5)}
</Properties>
</Item>
<Item class="ColorCorrectionEffect" referent="{color_ref}">
<Properties>
{prop_string("Name", "HorrorColor")}
{prop_float("Brightness", -0.05)}
{prop_float("Contrast", 0.15)}
{prop_float("Saturation", -0.3)}
{prop_color3("TintColor", 0.9, 0.85, 1)}
</Properties>
</Item>
<Item class="ColorCorrectionEffect" referent="{cctv_filter_ref}">
<Properties>
{prop_string("Name", "CCTVFilter")}
{prop_float("Brightness", -0.1)}
{prop_float("Contrast", 0.3)}
{prop_float("Saturation", -1)}
{prop_color3("TintColor", 0.8, 1, 0.8)}
{prop_bool("Enabled", False)}
</Properties>
</Item>
</Item>'''

# === BUILD SOUND SERVICE ===
def build_sounds():
    r = ref()
    return f'''<Item class="SoundService" referent="{r}">
<Properties>
{prop_string("Name", "SoundService")}
</Properties>
{make_sound("AmbientHorror", "rbxassetid://9112854440", 0.3, True)}
{make_sound("JumpScareSound", "rbxassetid://9114265792", 1.0, False)}
{make_sound("PhoneRing", "rbxassetid://9114220987", 0.8, False)}
{make_sound("CookingSound", "rbxassetid://9114248953", 0.5, False)}
{make_sound("ShutterSound", "rbxassetid://9114254790", 0.7, False)}
{make_sound("HeartbeatSound", "rbxassetid://9113655458", 0.4, True)}
{make_sound("FootstepSound", "rbxassetid://9114267993", 0.3, False)}
{make_sound("VictorySound", "rbxassetid://9114854738", 0.8, False)}
{make_sound("DoorCreak", "rbxassetid://9114263621", 0.6, False)}
{make_sound("WhisperSound", "rbxassetid://9113489604", 0.3, False)}
{make_sound("TruckEngine", "rbxassetid://9114229867", 0.5, False)}
{make_sound("ManagerVoice", "rbxassetid://9114220987", 0.6, False)}
{make_sound("CustomerVoice", "rbxassetid://9114248953", 0.4, False)}
{make_sound("DialogueTick", "rbxassetid://9114267993", 0.15, False)}
</Item>'''

# === ASSEMBLE FULL RBXLX ===
def generate():
    restaurant_parts, cctv_parts, spawn_parts, spawn_loc = build_restaurant()
    ui = build_ui()
    remotes = build_remotes()
    lighting = build_lighting()
    sounds = build_sounds()

    workspace_ref = ref()
    sss_ref = ref()
    rs_ref = ref()
    ss_ref = ref()
    sg_ref = ref()
    sps_ref = ref()
    sp_ref = ref()

    xml = f'''<?xml version="1.0" encoding="utf-8"?>
<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">
<Meta name="ExplicitAutoJoints">true</Meta>
<External>null</External>
<External>nil</External>

<!-- === WORKSPACE === -->
<Item class="Workspace" referent="{workspace_ref}">
<Properties>
{prop_string("Name", "Workspace")}
</Properties>

<!-- Restaurant Building -->
{restaurant_parts}

<!-- NPC Spawn Points -->
{make_folder("NPCSpawns", spawn_parts)}

<!-- NPCs Folder -->
{make_folder("NPCs")}

<!-- CCTV Cameras -->
{make_folder("CCTVCameras", cctv_parts)}

<!-- Spawn Location -->
{spawn_loc}

<!-- Camera -->
<Item class="Camera" referent="{ref()}">
<Properties>
{prop_string("Name", "Camera")}
{prop_cframe("CFrame", 0, 8, 20)}
</Properties>
</Item>

</Item>

<!-- === LIGHTING === -->
{lighting}

<!-- === SERVER SCRIPT SERVICE === -->
<Item class="ServerScriptService" referent="{sss_ref}">
<Properties>
{prop_string("Name", "ServerScriptService")}
</Properties>
{make_script("GameManager", gamemanager_lua)}
{make_script("NPCManager", npcmanager_lua)}
{make_script("DataManager", datamanager_lua)}
{make_script("GamePassManager", gamepassmanager_lua)}
</Item>

<!-- === REPLICATED STORAGE === -->
<Item class="ReplicatedStorage" referent="{rs_ref}">
<Properties>
{prop_string("Name", "ReplicatedStorage")}
</Properties>
{make_modulescript("Config", config_lua)}
{make_modulescript("NightData", nightdata_lua)}
{remotes}
</Item>

<!-- === SERVER STORAGE === -->
<Item class="ServerStorage" referent="{ss_ref}">
<Properties>
{prop_string("Name", "ServerStorage")}
</Properties>
{make_bindable_event("NightStartBindable")}
</Item>

<!-- === STARTER GUI === -->
<Item class="StarterGui" referent="{sg_ref}">
<Properties>
{prop_string("Name", "StarterGui")}
</Properties>
{ui}
</Item>

<!-- === STARTER PLAYER SCRIPTS === -->
<Item class="StarterPlayer" referent="{ref()}">
<Properties>
{prop_string("Name", "StarterPlayer")}
</Properties>
<Item class="StarterPlayerScripts" referent="{sps_ref}">
<Properties>
{prop_string("Name", "StarterPlayerScripts")}
</Properties>
{make_localscript("ClientController", clientcontroller_lua)}
</Item>
</Item>

<!-- === STARTER PACK === -->
<Item class="StarterPack" referent="{sp_ref}">
<Properties>
{prop_string("Name", "StarterPack")}
</Properties>
</Item>

<!-- === SOUND SERVICE === -->
{sounds}

<!-- === TEAMS === -->
<Item class="Teams" referent="{ref()}">
<Properties>
{prop_string("Name", "Teams")}
</Properties>
</Item>

</roblox>'''

    return xml

# === MAIN ===
if __name__ == "__main__":
    output_dir = os.path.dirname(os.path.abspath(__file__))
    output_path = os.path.join(output_dir, "RoadSideDosa.rbxlx")

    xml_content = generate()

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(xml_content)

    print(f"Generated: {output_path}")
    print(f"File size: {os.path.getsize(output_path) / 1024:.1f} KB")
    print("Open this file in Roblox Studio to test and publish!")
