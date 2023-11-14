extends Area
class_name HitArea # eg. curb
# MONITORED BY WHEELAREAS

# -> !!!!!!!!!!!!GETS APPLIED PER WHEEL!!!!!!!!!!!!!!!!!
export(float) var hit_force_enter = 0.0
export(float) var hit_force_exit = 0.0
export(float) var linear_friction = 0.0 # general damp
export(float) var angular_friction = 0.0
export(float) var lateral_friction = 0.0 # allows to adjust drifts
export(float) var wheel_force_boost = 0.0 # eg. speedpads 
# lack of longitudinal_friction means the brakes (just a handbrake atm) cannot be affected (will change if needed)
export(Color) var smoke_color = null
