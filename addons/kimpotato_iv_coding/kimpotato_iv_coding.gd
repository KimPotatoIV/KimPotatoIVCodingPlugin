# 이 스크립트가 엔진 에디터 자체에서 돌아가도록 선언
@tool

# 에디터의 창을 제어하거나 타이핑 신호를 낚아채는 애드온으로서 작동할 수 있게 함
extends EditorPlugin

##################################################
# 파티클 효과에 사용할 이미지 파일명 상수
const POTATO_PAW_FILE: String = "/potato_paw.png"
# 우측 하단에서 춤추는 감자 스프라이트 이미지 파일명 상수
const POTATO_SPRITE_FILE: String = "/potato_sprite.png"
# 스프라이트 시트 애니메이션에 포함된 총 프레임 수 (총 4컷)
const SPRITE_FRAME_COUNT: int  = 4
# 가로세로 정해진 픽셀 단위 크기 (32x32 사이즈의 픽셀 아트)
const SPRITE_FRAME_SIZE:  int  = 32
# 애니메이션이 재생될 속도 (초당 6프레임 재생, 숫자가 클수록 빨라짐)
const SPRITE_FPS: float = 6.0
# 애니메이션을 코드 편집창 우측 하단 모서리로부터 띄울 여백
const SPRITE_MARGIN: float = 16.0

# 엔진 에디터의 스크립트 편집기 창 객체를 담아둘 변수
var script_editor: ScriptEditor = null
# 파티클 효과에 사용할 발바닥 이미지를 담을 변수
var potato_texture: Texture2D = null
# 직전까지 활성화되어 신호(Signal)를 연결해 두었던 코드 편집기(CodeEdit) 창을
# 기억하고 추적하여 창을 바꿀 때 예전 창에 남아있는 신호를 깔끔하게 끊어내어
# 중복 버그를 막는 용도로 사용하는 변수
var last_code_edit: CodeEdit = null
# 로드한 감자 스프라이트 전체 시트 이미지를 담아둘 변수
var potato_sprite_texture: Texture2D = null
# 에디터 화면 우측 하단에 실제로 배치되어 그려질 2D 스프라이트 노드 변수
var potato_sprite: Sprite2D = null
# 매 프레임(delta)마다 시간을 누적하여 프레임 전환 타이밍을 계산하는 타이머 변수
var anim_timer: float = 0.0
# 현재 캐릭터가 보여주고 있는 애니메이션의 몇 번째(0~3) 프레임인지 기억하는 변수
var anim_frame: int = 0
 ##################################################
"""
▶ 왜 _init()이나 _ready()가 아닌 _enter_tree()에서 설정을 할까?
	- _init()은 객체가 메모리에 올라가는 생성자 시점이기 때문에
		플러그인이 엔진 시스템에 완전히 등록되기도 전으로 오류 발생
	- _ready()는 노드의 평생 동안 최초 딱 한 번만 실행되기 때문에
		애드온을 껐다가 다시 켤 때 실행되지 않아 오류 발생
▶ 왜 AnimatedSprite2D나 AnimationPlayer 같은 편한 애니메이션 노드를 안 쓸까?
	- AnimatedSprite2D는 Scene 파일에 저장된 'SpriteFrames'라는 별도의 Resource 파일이
		연결되어 있어야만 작동함. 하지만 코드로만 돌아가는 가벼운 스크립트 플러그인 특성상,
		이 자원 파일을 에디터 내부에서 매번 가상으로 만들고 설정하는 게 비효율적
	- AnimationPlayer 역시 작동하려면 애니메이션 데이터를 담은 트랙 정보와 부모 노드가
		유기적으로 엮여야 해서, 코드 몇 줄로 굴리기에는 구조가 너무 무겁고 복잡해짐
	- 결론적으로 에디터 툴(Tool)을 만들 때는, 외부 종속성(추가 자원 파일) 없이
		'스크립트 파일 하나'와 '이미지 한 장'만으로 깔끔하게 구동되는 게 가장
		안전하고 가볍기 때문
"""
# 이 플러그인이 에디터의 씬 트리에 들어가는 순간(애드온이 활성화될 때) 실행되는 함수
func _enter_tree() -> void:
	print("Plugin activated successfully.")
	
	# 에디터 인터페이스 시스템으로부터 스크립트 에디터 창의 제어권을 가져옴
	script_editor = get_editor_interface().get_script_editor()
	
	# 스크립트 에디터를 성공적으로 찾았다면 신호를 연결
	if script_editor != null:
		# 사용자가 다른 스크립트로 전환할 때(editor_script_changed) 
		# _on_script_changed 함수가 실행되도록 연결(connect)
		script_editor.editor_script_changed.connect(_on_script_changed)
		# 애드온이 켜진 순간, 현재 열려 있는 스크립트 창이 있다면 강제로 연결하기 위해
		# _on_script_changed 함수를 강제 호출
		_on_script_changed()
	
	# 파티클 효과에 사용할 이미지 경로를 가져옴
	var img_path: String = \
		get_script().get_path().get_base_dir() + POTATO_PAW_FILE
	
	# 해당 경로에 실제로 이미지 파일이 존재하는지 확인
	if ResourceLoader.exists(img_path) == true:
		# potato_texture 변수에 로드(load)
		potato_texture = load(img_path)
	
	# 감자 애니메이션에 사용할 이미지 경로를 가져옴
	var sprite_path: String = \
		get_script().get_path().get_base_dir() + POTATO_SPRITE_FILE
	# 해당 경로에 실제로 이미지 파일이 존재하는지 확인
	if ResourceLoader.exists(sprite_path):
		# potato_sprite_texture 변수에 로드(load)
		potato_sprite_texture = load(sprite_path)
	
	# Sprite2D 노드 생성 및 에디터에 주입
	potato_sprite = Sprite2D.new()
	potato_sprite.region_enabled = true
	potato_sprite.region_rect = Rect2(0, 0, SPRITE_FRAME_SIZE, SPRITE_FRAME_SIZE)
	potato_sprite.texture = potato_sprite_texture
	potato_sprite.scale = Vector2(2.0, 2.0)
	# 픽셀아트라면 TEXTURE_FILTER_NEAREST 권장
	potato_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	# 동적 생성한 스프라이트 노드를 에디터 화면의 자식 노드로 강제 주입하여 렌더링 되게 만듦
	get_editor_interface().get_base_control().add_child(potato_sprite)

##################################################
# 이 플러그인이 에디터의 씬 트리에서 제외되는 순간(애드온이 비활성화될 때) 실행되는 함수
func _exit_tree() -> void:
	print("Plugin deactivated.")
	
	"""
	플러그인이 비활성화될 때 에디터에 남은 유령 신호(Signal)로 인한
	크래시를 막기 위한 청소작업
	"""
	# 스크립트 에디터 객체가 메모리에 안전하게 존재하고,
	# 그 에디터에 _on_script_changed 함수가 실제로 연결되어 있는 상태라면
	if script_editor \
		and script_editor.editor_script_changed.is_connected(_on_script_changed):
		# 연결해 두었던 유령 신호(Signal)를 안전하게 끊어서 크래시 버그를 방지
		script_editor.editor_script_changed.disconnect(_on_script_changed)

	# 직전까지 추적하던 last_code_edit이 메모리에 안전하게 존재하고 있는지 확인
	if last_code_edit and is_instance_valid(last_code_edit):
		# 해당 편집창에 우리가 연결해 둔 _on_text_changed()가 아직 남아있다면
		if last_code_edit.text_changed.is_connected(_on_text_changed):
			# 연결을 확실히 끊음
			last_code_edit.text_changed.disconnect(_on_text_changed)
	# 추적 변수를 완전히 비워줌
	last_code_edit = null
	
	# 화면 우측 하단에 배치했던 감자 스프라이트 노드가 메모리에 존재한다면
	if potato_sprite and is_instance_valid(potato_sprite):
		# queue_free()를 호출하여 다음 프레임에 안전하게 메모리에서 해제 및 제거
		potato_sprite.queue_free()
		# 변수를 비워 유령 노드가 가리키는 찌꺼기 참조를 차단
		potato_sprite = null

##################################################
"""
▶  왜 사용하지 않는 '_script: Script = null' 매개변수가 들어있을까?
	- 스크립트를 바꿀 때, 엔진은 무조건 '바뀐 스크립트 데이터'를 매개변수로 던짐
	- 만약 이 매개변수(_script)를 없애버리면, 매개변수 누락으로 오류 발생
▶ 왜 중간에 그냥 'return'을 하는데도 정상 작동할까?
	- 프로그램이 처음 켜지는 시점에는 에디터 창이 완전히 그려지기도 전이라
		'get_current_editor()'가 null을 반환하기에 일단 'return'으로 안전처리
	- 하지만 엔진이 로딩을 끝내고 에디터 창을 모니터에 제대로 띄우는 순간,
		엔진 백엔드에서 'editor_script_changed' 신호(Signal)를 다시 쏴줌
"""
# 다른 스크립트로 전환할 때마다 실행되는 함수
func _on_script_changed(_script: Script = null) -> void:
	# 이전에 코딩하던 스크립트 창(last_code_edit)이 존재하고, 
	# 그 창에 여전히 타이핑 신호(_on_text_changed)가 연결되어 있는 상태일 때
	if last_code_edit \
		and last_code_edit.text_changed.is_connected(_on_text_changed):
		# 새 창으로 넘어가기 전에 예전 창과의 신호 연결을 끊음
		last_code_edit.text_changed.disconnect(_on_text_changed)
	
	# 현재 활성화된 에디터 창 객체를 시스템으로부터 안전하게 가져옴
	var current_editor = script_editor.get_current_editor()
	# 만약 에디터 시스템이 아직 로딩 중이라 null이라면, 오류 방지를 위해 즉시 반환
	if current_editor == null:
		return
	
	# 내부의 실제 텍스트 편집기(BaseEditor) 창을 가져옴
	# BaseEditor는 ScriptEditor 중에서도 코드를 작성하는 부분
	var current_code_edit: CodeEdit = current_editor.get_base_editor()
	# 글자를 입력하는 편집기(CodeEdit) 창을 정상적으로 찾았다면
	if current_code_edit != null:
		# 사용자가 키보드로 글자를 칠 때 발생하는 엔진 내장 신호인 'text_changed'를 감지
		# 똑같은 신호가 중복으로 연결되어 파티클이 무한으로 뿜어져 나오는 것을 막기 위해,
		# _on_text_changed() 함수와 연결되어 있지 않은 최초 1회만 안전하게 연결
		if not current_code_edit.text_changed.is_connected(_on_text_changed):
			current_code_edit.text_changed.connect(_on_text_changed)
			# 방금 새로 연결한 현재 편집기 창을 last_code_edit에 저장
			# 나중에 다른 스크립트로 창을 바꿀 때 안전하게 끊기 위함
			last_code_edit = current_code_edit
			print("Typing signal connected to the current script editor.")

##################################################
"""
▶ 왜 글자를 칠 때마다 에디터 객체와 편집창을 또 가져올까?
	- _on_script_changed()에서 이미 연결은 해두었지만, 사용자가 마구 타이핑하는 도중에
		창을 닫거나 에디터 내부 상태가 순간적으로 바뀔 수 있음
	- 커서의 정확한 현재 위치(픽셀 좌표)를 실시간으로 확인하기 위해,
		글자가 입력되는 순간마다 안전하게 최신 창 정보를 다시 확인하는 것
▶ 로컬 좌표(Local)와 글로벌 좌표(Global)를 왜 더할까?
	- get_caret_draw_pos()는 글자 창 내부(BaseEditor)에서
		커서가 우측/하단으로 몇 픽셀 움직였는지만 알려줌 (상대 좌표)
	- 하지만 우리가 파티클을 뿌릴 곳은 고도 에디터 모니터 전체 화면(전역 좌표)
	- 따라서 글자 창이 모니터 어디에 배치되어 있는지(Global)의 시작점에
			창 내부의 커서 위치(Local)를 바느질하듯 더해줘야
			모니터 화면상의 정확한 절대 좌표가 완성됨
"""
# 글자가 입력/삭제될 때마다 최종적으로 도달하는 함수
func _on_text_changed() -> void:
	# 현재 활성화된 코드 편집기 창 객체를 안전하게 가져옴
	var current_code_edit: CodeEdit = _get_current_code_edit()
	# 만약 편집기 창을 정상적으로 가져오지 못했다면
	if current_code_edit == null:
		# 오류 방지를 위해 즉시 반환
		return
	
	# 현재 편집창 내부에서 커서(Caret)가 위치한 상대적인 픽셀 좌표(Local)를 구함
	var cursor_local_pos:  Vector2 = current_code_edit.get_caret_draw_pos()
	# 편집창 노드 자체가 엔진 전체 화면에서 어디에 위치하는지 절대 전역 좌표(Global)를 구함
	var editor_global_pos: Vector2 = current_code_edit.get_global_transform().origin
	# 전역 좌표에 상대 좌표를 더해 화면상의 완벽한 위치를 계산하고 파티클을 생성
	spawn_potato_particle(editor_global_pos + cursor_local_pos)
	# 에디터 화면 전체를 뒤흔드는 함수 호출
	shake_editor()

##################################################
"""
▶ '사라짐' 뒤에 바로 'ㄴ'을 치면 왜 파티클이 안 나올까?
	- 한글은 자음과 모음이 합쳐지는 조합형 문자이기 때문에 발생하는 고유의 현상
	- 받침(ㅁ)을 치고 나서 자음(ㄴ)을 곧바로 누르면,
			엔진은 앞 글자의 겹받침을 만드려는 건가 싶어서 글자가 최종 확정될 때까지
			'text_changed' 신호(Signal)를 순간적으로 대기(지연)시킴
	- 그다음 모음을 입력해 새 글자가 완전히 독립되는 순간 다시 정상적으로 파티클 생성
"""
# 발바닥 파티클 노드를 실시간으로 만들고 뿜어주는 함수
func spawn_potato_particle(spawn_pos: Vector2) -> void:
	# 몇 안 되는 이펙트 때문에 GPU를 켜는 건 낭비이므로,
	# 에디터에 부담이 덜한 CPU 파티클을 사용
	var particles: CPUParticles2D = CPUParticles2D.new()
	
	# 파티클이 터지기 시작할 중심 위치를 커서의 화면 절대 좌표로 지정
	particles.position = spawn_pos
	# 한 번 타이핑할 때 동시다발적으로 터져 나올 발바닥 개수를 지정 (5개)
	particles.amount = 5
	# 일회성(one_shot)으로 한 번만 터지고 멈추도록 설정
	particles.one_shot = true
	# 파티클이 발사될 때, 수치 1.0(100%)을 주어 분수처럼 한 번에 팍 터지도록 만듦
	particles.explosiveness = 1.0
	# 발사된 파티클 입자가 화면에 살아서 존재할 시간(수명)을 초 단위로 지정 (1.0초)
	particles.lifetime = 1.0
	# 가상의 하방 중력을 주어, 파티클들이 포물선을 그리며 아래로 툭 떨어지게 만듦
	particles.gravity = Vector2(0, 700) 
	# 파티클이 처음 뿜어져 나갈 때의 최소 및 최대 속도를 픽셀 단위로 지정
	particles.initial_velocity_min = 240.0
	particles.initial_velocity_max = 440.0

	# 파티클이 소멸할 때 자연스럽게 크기가 줄어들도록 커브(Curve) 자원을 만듦
	var scale_curve: Curve = Curve.new()
	# 태어난 직후(0.0)에는 원래 크기 100%(1.0)로 시작
	scale_curve.add_point(Vector2(0.0, 1.0))
	# 수명이 다한 직후(1.0)에는 크기가 0.0이 되어 사라짐
	scale_curve.add_point(Vector2(1.0, 0.0))
	# 이 크기 커브 데이터를 파티클 노드 속성에 대입
	particles.scale_amount_curve = scale_curve
	
	# 만약 미리 로드해둔 감자 발바닥 이미지 변수가 비어있지 않다면
	if potato_texture:
		# 파티클의 Texture로 설정
		particles.texture = potato_texture
	
	# 에디터 전체 화면 창의 최상위 컨트롤 노드(BaseControl)를 참조
	var editor_main_screen = get_editor_interface().get_base_control()
	# 동적 생성한 파티클 노드를 에디터 화면의 자식 노드로 강제 주입하여 렌더링 되게 만듦
	editor_main_screen.add_child(particles)

	# 파티클 수명(1.0초)이 끝난 뒤에도 노드가 에디터에 쓰레기로 남아
	# 컴퓨터가 느려지는 것을 막기 위해, 엔진 내에 일회성 타이머를 생성
	var timer: SceneTreeTimer = get_tree().create_timer(particles.lifetime)
	# 수명이 끝나는 순간 메모리에서 해제(queue_free)하도록 연결
	timer.timeout.connect(particles.queue_free)

##################################################
"""
▶ spawn_potato_particle()와 마찬가지로, 한글 조합 중(예: '사라짐' + 'ㄴ')에는 
	text_changed 신호(Signal)가 일시 지연되므로 화면 흔들기도 순간적으로 멈추거나
	엇박자가 날 수 있음
"""
# 사용자가 타이핑할 때마다 에디터 화면 전체를 흔들어주는 함수
func shake_editor() -> void:
	# 에디터 최상위 화면 노드를 가져옴
	var editor_main_screen: Control = get_editor_interface().get_base_control()
	# 만약 에디터 화면 노드를 정상적으로 참조하지 못했다면
	if editor_main_screen == null:
		# 오류 방지를 위해 즉시 반환
		return
	
	# 타이핑 속도가 빠를 때 이전 흔들기 트윈(Tween)을 강제로 끊어버리면 화면이 끊기므로,
	# 이전 Tween을 kill() 하지 않고 매 순간 새로운 트윈을 병렬 생성해 덮어쓰도록 유도
	var tween: Tween = create_tween()
	# Tween의 보간 스타일을 파동 모양의 곡선 방식(TRANS_SINE)으로 지정
	tween.set_trans(Tween.TRANS_SINE)
	# 애니메이션 가속 및 감속 방식을 Tween의 목표치에 도달할 때
	# 부드럽게 멈추는 방식(EASE_OUT)으로 설정
	tween.set_ease(Tween.EASE_OUT)
	# 화면을 뒤흔들 픽셀 범위를 무작위로 계산하여 설정
	var random_offset: Vector2 = Vector2(
		randf_range(-10.0, 10.0),
		randf_range(-10.0, 10.0)
		)
	
	"""
	▶ tween_property()를 연속으로 쓰면 동시에 작동할까?
		- 아님. 엔진의 Tween은 기본적으로 순서대로 줄을 서서 작동 (대기열/Queue 시스템)
	"""
	# 0.03초 동안 에디터 전체 화면을 임의로 흔듦
	tween.tween_property(editor_main_screen, "position", random_offset, 0.03)
	# 튕겨 나간 직후 곧바로 0.05초 동안 다시 원래 정위치(Vector2.ZERO)로 부드럽게 원상 복구
	tween.tween_property(editor_main_screen, "position", Vector2.ZERO, 0.05)

##################################################
"""
▶ 왜 우측 하단 좌표(rect.end)에서 값을 더하지 않고 '뺄셈(-)'을 할까?
	- Sprite2D의 중심점(Centered) 속성이 켜져 있으면, 노드의 position은 캐릭터의
		'정중앙'이 됨
	- 만약 rect.end 좌표를 그대로 캐릭터 위치로 주면, 캐릭터의 중심이 모서리에 딱 걸쳐서 
		화면 밖으로 절반쯤 잘려 나가게 됨
	- 따라서 캐릭터가 화면 안쪽으로 이쁘게 들어오도록 '스프라이트 실제 크기의 절반'에 
		'원하는 여백(SPRITE_MARGIN)'을 더한 만큼 좌측 상단 방향(-)으로 당겨주는 것
"""
func _process(delta: float) -> void:
	# 감자 스프라이트가 없거나, 유효하지 않거나,
	# 아직 이미지 텍스처가 제대로 로드되지 않았다면
	if potato_sprite == null or not is_instance_valid(potato_sprite) \
		or potato_sprite.texture == null:
		# 오류 방지를 위해 즉시 반환
		return
	
	# 현재 열려 있는 실제 코드 편집창 창 객체를 가져옴
	var code_edit: CodeEdit = _get_current_code_edit()
	# 편집창을 성공적으로 찾았다면 위치 추적 시작
	if code_edit != null:
		# 편집창의 화면상 전역 사각형 영역 정보(Rect2)를 한 번에 가져옴
		var rect: Rect2 = code_edit.get_global_rect()
		# 우측 하단 모서리(rect.end)에서 안쪽으로 당겨서 중심 위치 결정
		potato_sprite.position = rect.end - Vector2(
			SPRITE_FRAME_SIZE * potato_sprite.scale.x / 2.0 + SPRITE_MARGIN,
			SPRITE_FRAME_SIZE * potato_sprite.scale.y / 2.0 + SPRITE_MARGIN
		)
		# 위치가 정상적으로 잡혔으므로 캐릭터를 화면에 보이도록 켬
		potato_sprite.visible = true
	# 편집창이 닫혀 있거나 찾을 수 없다면 캐릭터를 화면에서 숨김
	else:
		potato_sprite.visible = false
		return

	# 매 프레임마다 누적된 시간(delta)을 애니메이션 타이머에 더함
	anim_timer += delta
	# 타이머가 한 프레임이 유지되어야 할 목표 시간(1.0 / FPS)에 도달했을 때
	if anim_timer >= 1.0 / SPRITE_FPS:
		# 목표 시간을 차감하여 타이머를 리셋 (잔여 시간을 남겨두어 부드러운 프레임 유지)
		anim_timer -= 1.0 / SPRITE_FPS
		# 다음 프레임 번호로 넘기되, 총 프레임 개수(4컷)를 벗어나면 다시 0번으로 순환
		anim_frame = (anim_frame + 1) % SPRITE_FRAME_COUNT
		# 스프라이트 시트 이미지에서 현재 프레임 번호에 맞는 사각형 영역을 계산해 갱신
		potato_sprite.region_rect = Rect2(
			anim_frame * SPRITE_FRAME_SIZE, 0,
			SPRITE_FRAME_SIZE, SPRITE_FRAME_SIZE
		)

##################################################
# 현재 에디터에서 활성화된 실제 코드 편집창(CodeEdit) 노드를 안전하게 반환하는 헬퍼 함수
func _get_current_code_edit() -> CodeEdit:
	# 스크립트 에디터 매니저 시스템이 아직 메모리에 없다면
	if script_editor == null:
		# 오류 방지를 위해 null 반환
		return null
	
	# 현재 유저가 보고 있는 스크립트 편집기 창의 상위 컨테이너를 가져옴
	var cur = script_editor.get_current_editor()
	# 현재 열려 있는 스크립트 창이 아예 없다면
	if cur == null:
		# 오류 방지를 위해 null 반환
		return null
	
	# 상위 컨테이너 내부에서 실제 코드가 작성되는 진짜 텍스트 편집기 노드를 최종 반환
	return cur.get_base_editor()
