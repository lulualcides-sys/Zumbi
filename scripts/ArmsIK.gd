extends RefCounted
## Godot 4.7 native TwoBoneIK3D — weapon drives hand pose, not vice versa.
## Only the player receives the two modifiers. Zombies use baked clips.
## Both hand targets are children of the rifle mount and follow aim/rotation.

static func _normalize_bone(raw: String) -> String:
    return raw.to_lower().replace("_", "").replace(":", "").replace(".", "").replace(" ", "")

static func _lookup(skeleton: Skeleton3D, phrase: String) -> int:
    var needle := _normalize_bone(phrase)
    for idx in range(skeleton.get_bone_count()):
        var name := _normalize_bone(skeleton.get_bone_name(idx))
        if name.ends_with(needle) or name.contains(needle):
            return idx
    return -1

static func _target(parent: Node3D, label: String, local_at: Vector3) -> Marker3D:
    var mark := Marker3D.new()
    mark.name = label
    mark.position = local_at
    parent.add_child(mark)
    return mark

static func _create_solver(skeleton: Skeleton3D, label: String, root_bone: int, mid_bone: int, hand_bone: int,
                           grip: Marker3D, pole: Marker3D) -> TwoBoneIK3D:
    var solver := TwoBoneIK3D.new()
    solver.name = label
    skeleton.add_child(solver)
    solver.setting_count = 1
    solver.set_root_bone_name(0, skeleton.get_bone_name(root_bone))
    solver.set_middle_bone_name(0, skeleton.get_bone_name(mid_bone))
    solver.set_end_bone_name(0, skeleton.get_bone_name(hand_bone))
    solver.set_target_node(0, solver.get_path_to(grip))
    solver.set_pole_node(0, solver.get_path_to(pole))
    solver.influence = 0.80
    solver.active = true
    return solver

static func attach(character: CharacterBody3D, skeleton: Skeleton3D, rifle_mount: Node3D) -> Dictionary:
    if skeleton == null:
        return {"active": false}
    var right_arm := _lookup(skeleton, "RightArm")
    var right_forearm := _lookup(skeleton, "RightForeArm")
    var right_hand := _lookup(skeleton, "RightHand")
    var left_arm := _lookup(skeleton, "LeftArm")
    var left_forearm := _lookup(skeleton, "LeftForeArm")
    var left_hand := _lookup(skeleton, "LeftHand")
    if min(right_arm, right_forearm, right_hand, left_arm, left_forearm, left_hand) < 0:
        push_warning("IK disabled: soldier skeleton missing one or more arm bones")
        return {"active": false}

    var right_grip := _target(rifle_mount, "PistolGripIK", Vector3(0.065, -0.075, -0.095))
    var left_grip := _target(rifle_mount, "HandguardIK", Vector3(-0.125, 0.00, 0.19))
    var right_pole := _target(character, "RightElbowPole", Vector3(0.85, 0.64, -0.18))
    var left_pole := _target(character, "LeftElbowPole", Vector3(-0.85, 0.64, -0.18))
    var right_solver := _create_solver(skeleton, "RightHandGripIK", right_arm, right_forearm, right_hand, right_grip, right_pole)
    var left_solver := _create_solver(skeleton, "LeftSupportGripIK", left_arm, left_forearm, left_hand, left_grip, left_pole)

    print("TWO_HAND_IK_ACTIVE: right=[", right_arm, ",", right_forearm, ",", right_hand,
          "] left=[", left_arm, ",", left_forearm, ",", left_hand, "]")
    return {
        "active": true, "right_ik": right_solver, "left_ik": left_solver,
        "right_grip": right_grip, "left_grip": left_grip,
        "right_pole": right_pole, "left_pole": left_pole
    }
