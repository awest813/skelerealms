[gd_resource type="Resource" load_steps=2 format=3]

[ext_resource type="Script" path="res://addons/skelerealms/scripts/misc/skconfig.gd" id="1"]

[resource]
script = ExtResource("1")
default_world = "demo_world"
default_world_position = Vector3(0, 1.2, 0)
equipment_slots = Array[StringName]([&"head", &"body", &"hands", &"feet", &"weapon"])
skills = {
&"speech": 10,
&"stealth": 10
}
attributes = {
&"strength": 5,
&"agility": 5
}
default_currency = &"snails"
skill_xp_formula = "int(100 + skill_level * 25)"
character_xp_formula = "int(200 + character_level * 50)"
