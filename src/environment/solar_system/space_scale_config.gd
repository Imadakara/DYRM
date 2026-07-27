class_name SpaceScaleConfig
extends Resource

## Радиус слоя Local, метры (= юниты Godot). FR-01
@export var local_radius_m: float = 2000.0

## Коэффициент логарифмического сжатия дальнего космоса, юниты. FR-04, формула 6.4.3
@export var compression_k: float = 220.0
## Опорное расстояние сжатия, километры. FR-04, формула 6.4.3
@export var compression_d0_km: float = 1.0e6
## Порог углового диаметра, ниже которого видимый размер тела фиксируется, градусы. FR-05
@export var min_angular_diameter_deg: float = 0.12

## near/far плоскости камеры слоя Deep.
@export var deep_near: float = 0.1
@export var deep_far: float = 10000.0
