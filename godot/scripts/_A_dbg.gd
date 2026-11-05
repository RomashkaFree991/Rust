extends SceneTree
var f := 0
var c
func _init():
	var r := Node3D.new(); get_root().add_child(r)
	c = Character.new(); r.add_child(c)
	c.set_weapon("assault_rifle")
	var n: Node3D = c.weapon_node
	for ch in n.find_children("*", "", true, false):
		if ch is Node3D: print(ch.name, " ", ch.get_class(), " xf ", ch.transform)
func _process(_d):
	f += 1
	if f == 10:
		var g = c.weapon_geo
		var wt: Transform3D = c.weapon_node.global_transform
		print("geo ", g)
		print("tip w ", wt * g.tip, " butt w ", wt * g.butt, " hand w ", wt * g.hand)
		quit()
	return false
