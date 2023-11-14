extends Spatial
class_name Gun

export(String) var bullet_scene = "res://src/race/weapons/Bullet.tscn"
export(String) var shell_scene = "res://src/race/weapons/BulletShell.tscn"
export(float) var ammo_cost = 1.0 # how much ammo per shot
export(float) var muzzle_velocity = 30.0
export(float) var firerate = 0.1
export(float) var damage = 1.0
export(float) var flash_length = 0.05
export(float) var recoil_force = 1.0
export(float) var shell_force = 1.0

var shells_enabled:bool = true # set by gfx settings (see toggle_shells_enabled)
var b:Bullet
var s:RigidBody

var BulletScene:Resource
var ShellScene:Resource

var cooldown:float = 0.0
var flash_timer:float = 0.0
var car:RigidBody

func _enter_tree() -> void:
	car = get_parent()
	BulletScene = load(bullet_scene)
	ShellScene = load(shell_scene)

func shoot() -> void:
	if car.is_in_group("cars") && cooldown <= 0 && car.ammo >= ammo_cost:
		call_deferred("spawn_bullet")
		if shells_enabled:
			call_deferred("spawn_shell")
		cooldown += firerate
		flash_timer = 0
		$MuzzleFlash.visible = true
		$MuzzleFlash/Light.visible = car.carlights_enabled
		car.change_ammo(-ammo_cost)
		car.apply_impulse(translation, -Vector3.BACK.rotated(Vector3.UP, rotation.y+car.rotation.y)*recoil_force)

func _process(delta:float) -> void:
	if cooldown > 0.0:
		cooldown -= delta
	if $MuzzleFlash.visible:
		if flash_timer >= flash_length:
			$MuzzleFlash.visible = false
		flash_timer += delta

func spawn_bullet() -> void:
	b = BulletScene.instance()
	b.creator_car = car
	b.transform = $Muzzle.global_transform
	b.velocity = b.transform.basis.z * muzzle_velocity
	if car.forward_velocity.normalized().dot(b.velocity) > 0: # add car velocity only when its in shooting direction
		b.velocity += car.forward_velocity
	b.damage = damage
	car.get_parent().add_child(b)
	b = null

func spawn_shell() -> void:
	s = ShellScene.instance()
	s.transform = $ShellSpawn.global_transform
	car.get_parent().add_child(s)
	s.apply_central_impulse((Vector3.RIGHT*shell_force).rotated(Vector3.UP, car.rotation.y)+car.linear_velocity*s.mass)
	s = null

func set_shells_enabled(enable:bool) -> void:
	shells_enabled = enable
