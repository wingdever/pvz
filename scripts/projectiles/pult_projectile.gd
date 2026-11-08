class_name PultProjectile
extends Projectile
## [P91] THE LOBBED SHOT - also nothing but a name now.
##
## Its three differences used to live here, and all three are the 抛射 trajectory of the
## shot's row: a melon is thrown AT a body and flies over whatever stands in between
## (`_stops_for`), it is not what the 铁门 is carried to stop (`straight_shot = false`), and
## its y rides a parabola while its x still does the colliding (`_arc_y()`). The base reads
## `轨迹 = 抛射` and does all three, which is why a 卷心菜 and a 西瓜 are two ROWS rather
## than two classes.
