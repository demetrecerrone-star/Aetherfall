extends Control
## Shared, artwork-free fantasy vista for title and loading screens.
## All geometry is 2D, with no imported textures, shaders, or 3D world startup.
var reduced_motion := false
var dimmed := false
var _clock := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if not reduced_motion:
		_clock += delta
		queue_redraw()

func _polygon(points: PackedVector2Array, shade: Color) -> void:
	draw_colored_polygon(points, shade)

func _cloud(cx: float, cy: float, width: float, shade: Color) -> void:
	# Flat overlapping ovals: cheap to draw on Android's Compatibility renderer.
	draw_circle(Vector2(cx - width * .24, cy + width * .015), width * .17, shade)
	draw_circle(Vector2(cx, cy - width * .065), width * .24, shade)
	draw_circle(Vector2(cx + width * .23, cy), width * .17, shade)
	draw_rect(Rect2(cx-width*.29,cy,width*.59,width*.11),shade)

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 10.0 or h < 10.0:
		return
	var minute := _clock
	# Dusky blue sky with amber horizon; layered rects avoid texture memory.
	for i in range(32):
		var t := float(i)/32.0
		var sky := Color("071324").lerp(Color("395671"),t)
		if t > .56:
			sky = sky.lerp(Color("9b746a"),(t-.56)*.25)
		draw_rect(Rect2(0,h*t,w,h/32.0+1.0),sky)
	# Moon halo on the far side of the village.
	var moon := Vector2(w*.765,h*.245)
	for i in range(6,0,-1):
		draw_circle(moon,h*(.06+float(i)*.017),Color(.42,.78,.96,.013))
	draw_circle(moon,h*.064,Color("a8c9ce"))
	draw_circle(moon+Vector2(h*.017,-h*.014),h*.058,Color("aecad0"))
	# Stars gently pulse; no particles are instantiated.
	for i in range(43):
		var px := fposmod(float(i*673+129),w)
		var py := fposmod(float(i*293+17),h*.65)
		var opacity := .34 if reduced_motion else .28+.21*sin(minute*.7+float(i)*2.7)
		draw_circle(Vector2(px,py), 1.3 if i%4 else 2.0,Color(0.84,0.92,1.0,opacity))
	# Three drifting cloud banks, each with distinct speed/depth.
	for layer in range(3):
		for j in range(4):
			var speed := (3.0+float(layer)*2.8)*minute
			var cx := fposmod(float(j)*w*.39 + float(layer)*w*.17 + speed + w*.20, w*1.48)-w*.23
			var cy := h*(.18+float(layer)*.115)+sin(float(j*4+layer)) * h*.025
			_cloud(cx,cy,w*(.08+float(layer)*.025),Color(.50,.67,.77,.062+float(layer)*.025))
	# Distant peaks.
	_polygon(PackedVector2Array([Vector2(0,h*.72),Vector2(w*.14,h*.46),Vector2(w*.22,h*.59),Vector2(w*.33,h*.39),Vector2(w*.47,h*.69),Vector2(w*.62,h*.40),Vector2(w*.73,h*.64),Vector2(w*.90,h*.43),Vector2(w,h*.55),Vector2(w,h),Vector2(0,h)]),Color("40546a"))
	_polygon(PackedVector2Array([Vector2(0,h*.82),Vector2(w*.17,h*.57),Vector2(w*.32,h*.77),Vector2(w*.47,h*.57),Vector2(w*.63,h*.83),Vector2(w*.85,h*.51),Vector2(w,h*.68),Vector2(w,h),Vector2(0,h)]),Color("283e51"))
	# Town wall and gate, drawn behind the illuminated aether doorway.
	draw_rect(Rect2(w*.51,h*.68,w*.49,h*.26),Color("243245"))
	for i in range(21):
		draw_rect(Rect2(w*(.515+float(i)*.024),h*.655,w*.014,h*.037),Color("27374b"))
	var tower_x := [w*.57,w*.88,w*.94]
	for x in tower_x:
		draw_rect(Rect2(x-w*.017,h*.47,w*.034,h*.27),Color("253548"))
		_polygon(PackedVector2Array([Vector2(x-w*.029,h*.47),Vector2(x,h*.40),Vector2(x+w*.029,h*.47)]),Color("3e4c60"))
		draw_rect(Rect2(x-w*.004,h*.54,w*.008,h*.045),Color("d9bd7c"))
	# Amber village windows and pitched rooftops.
	for i in range(5):
		var hx := w*(.535+float(i)*.085)
		var hy := h*(.665+(float(i%3)*.045))
		draw_rect(Rect2(hx,hy-w*.009,w*.063,h*.098),Color("202d3e"))
		_polygon(PackedVector2Array([Vector2(hx-w*.010,hy),Vector2(hx+w*.031,hy-h*.066),Vector2(hx+w*.073,hy)]),Color("3c4555"))
		draw_rect(Rect2(hx+w*.021,hy+h*.023,w*.014,h*.024),Color("ebc17a"))
	# Lit archway beyond the stone plaza, softly glowing and pulsing.
	var center := Vector2(w*.775,h*.66)
	var radius := h*.192
	for i in range(6,0,-1):
		draw_circle(center+Vector2(0,-radius*.21),radius*(.75+float(i)*.16),Color(.14,.66,.96,.009))
	var pulse := 0.0 if reduced_motion else .055*sin(minute*.83)
	draw_circle(center+Vector2(0,-radius*.21),radius*.73,Color(.26,.82,.93,.13+pulse))
	for band in range(4):
		var angle := minute*(.06 if band%2==0 else -.055) + float(band)*.85
		draw_arc(center+Vector2(0,-radius*.21),radius*(.66+float(band)*.12),angle,angle+TAU*.85,88,Color(.62,.92,1.0,.55-float(band)*.085),2.2,true)
	for i in range(14):
		var theta := TAU*float(i)/14.0+minute*.055
		var edge := Vector2(cos(theta),sin(theta))
		draw_line(center+Vector2(0,-radius*.21)+edge*radius*.74,center+Vector2(0,-radius*.21)+edge*radius*.82,Color(.93,.84,.57,.60),2.1,true)
	# Tall stone arch uprights and lintel give the gateway a tangible silhouette.
	for side in [-1.0,1.0]:
		draw_rect(Rect2(center.x+side*radius*.9-radius*.105,center.y-radius*1.56,radius*.21,radius*1.58),Color("667483"))
		draw_rect(Rect2(center.x+side*radius*.9-radius*.08,center.y-radius*1.50,radius*.16,radius*.14),Color("98a0a1"))
	draw_rect(Rect2(center.x-radius,center.y-radius*1.69,radius*2,radius*.24),Color("707d87"))
	for i in range(7):
		draw_rect(Rect2(center.x-radius+float(i)*radius*.31,center.y-radius*1.82,radius*.18,radius*.14),Color("798993"))
	# Cobblestone path and plaza lead toward the gate.
	_polygon(PackedVector2Array([Vector2(w*.685,h*.82),Vector2(w*.853,h*.82),Vector2(w*.99,h),Vector2(w*.52,h)]),Color("53616a"))
	for i in range(7):
		var v := float(i)/7.0
		var y := h*(.82+v*v*.18)
		var half := w*(.085+v*.15)
		draw_line(Vector2(w*.77-half,y),Vector2(w*.77+half,y),Color(.19,.25,.31,.35),1.6,true)
	# Low shrubs and silhouettes frame the valley without covering the menu.
	_polygon(PackedVector2Array([Vector2(0,h*.87),Vector2(w*.16,h*.77),Vector2(w*.35,h*.88),Vector2(w*.51,h*.80),Vector2(w*.62,h),Vector2(0,h)]),Color("112336"))
	_polygon(PackedVector2Array([Vector2(w*.91,h*.83),Vector2(w,h*.74),Vector2(w,h),Vector2(w*.84,h)]),Color("0e2030"))
	for i in range(13):
		var x := w*(.47+float(i)*.041)
		var y := h*(.88+.045*sin(float(i)*1.6))
		draw_circle(Vector2(x,y),h*(.018+.01*float(i%3)),Color("102938"))
	# Fog bands and sparse drifting motes.
	for i in range(4):
		var yy := h*(.64+float(i)*.083)
		draw_rect(Rect2(w*.40,yy,w*.60,h*.029),Color(.57,.71,.78,.023))
	for i in range(30):
		var px := fposmod(float(i*397+21)+minute*(5.0+float(i%3)*3.0),w*.55)+w*.43
		var py := fposmod(float(i*193+79)-minute*(3.0+float(i%5)),h*.49)+h*.36
		draw_circle(Vector2(px,py),1.6 if i%4 else 2.6,Color(.71,.92,1.0,.30))
	# Separate higher contrast for the actual menu/card area.
	draw_rect(Rect2(0,0,w*.50,h),Color(.025,.045,.085,.30))
	if dimmed:
		draw_rect(Rect2(Vector2.ZERO,size),Color(.02,.045,.09,.46))
