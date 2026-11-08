class_name PeaProjectile
extends Projectile
## [P91] THE STRAIGHT ROUND - and, since P91, nothing but a name.
##
## Everything this class used to own is a column of its row in `data/projectiles.csv`: the
## shape of the flight (轨迹 = 直线), the picture (外观 = pea), the cues, and whatever rider
## the shot carries. The BASE flies it, collides with it, bounces it and draws it; the class
## is kept because a shot still has to be a script the factory can instantiate, and because
## a future shot that needs behaviour the table cannot express inherits from the base and
## says so here.
