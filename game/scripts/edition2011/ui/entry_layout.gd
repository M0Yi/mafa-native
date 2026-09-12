class_name EditionEntryLayout
extends RefCounted

# Measured against this client's Prguse 65/73 pixels. No archive (7,-44) offset.
# Button art and hit areas share these rectangles; do not scale them separately.
const CREATE_ORIGIN:=Vector2(420,85)
const CREATE_NAME:=Rect2(72,108,136,18)
const CREATE_SUBMIT:=Rect2(103,359,76,33)
const CREATE_CLOSE:=Rect2(247,30,16,23)
const JOBS: Array[Rect2]=[Rect2(47,156,44,36),Rect2(92,156,44,36),Rect2(137,156,44,36)]
const SEXES: Array[Rect2]=[Rect2(92,230,44,35),Rect2(137,230,44,35)]
const SELECT: Array[Rect2]=[Rect2(133,452,76,33),Rect2(685,453,76,33)]
const NAMES: Array[Rect2]=[Rect2(112,491,97,18),Rect2(665,493,97,18)]
const LEVELS: Array[Rect2]=[Rect2(112,521,46,17),Rect2(665,523,46,17)]
const CLASSES: Array[Rect2]=[Rect2(112,551,88,17),Rect2(665,552,88,17)]
const ROSTER: Dictionary={
	"enter":Rect2(385,456,44,21),"create":Rect2(348,486,120,20),
	"delete":Rect2(347,506,120,21),"credits":Rect2(362,527,92,20),
	"logout":Rect2(379,547,56,20),
}

static func create_rect(local: Rect2) -> Rect2:
	return Rect2(CREATE_ORIGIN+local.position,local.size)
