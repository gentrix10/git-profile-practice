#!/usr/bin/env bash
#
# Git·GitHub 인터랙티브 튜토리얼 (단계 기반 플로우)
#
# 사용법:
#   ./tutorial.sh            튜토리얼 화면(TUI) 시작 ← 학생용 기본 실행 방법
#                            (Windows에서는 '시작하기.bat' 더블클릭으로 자동 실행)
#   ./tutorial.sh show       현재 챕터 안내만 한 번 출력
#   ./tutorial.sh progress   전체 진행 상황 보기
#   ./tutorial.sh reset      진행 상황 초기화
#
# 동작 방식:
#   - 전체 과정은 7개 챕터, 총 46개의 마이크로 단계로 구성된다.
#   - 각 단계는 '실행해야 할 명령'이 정확히 정해져 있다.
#   - 입력이 이 단계의 명령이면 → 실행 → 결과 검증 → 성공 시에만 다음 단계.
#   - 다른 명령은 실행하지 않고 안내한다. (관찰용 명령 git status/log/diff 등은 예외로 항상 허용)
#
# 이 스크립트는 여러분의 파일을 수정하지 않아요.
# 단 하나의 예외: 이 폴더를 clone으로 받아 배포 저장소의 기록(.git)이
# 이미 들어 있는 경우, 학습자의 확인(y)을 받아 그 기록을 지웁니다.

cd "$(dirname "$0")" || exit 1

STATE_FILE=".tutorial-state"
PROFILE="profile.md"
TOTAL_CH=7
TOTAL_FLOW=46

# ──────────────────────────── 출력 도구 ────────────────────────────

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_GREEN=$'\033[32m'; C_RED=$'\033[31m'; C_YELLOW=$'\033[33m'
  C_CYAN=$'\033[36m';  C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'; C_OFF=$'\033[0m'
else
  C_GREEN=""; C_RED=""; C_YELLOW=""; C_CYAN=""; C_BOLD=""; C_DIM=""; C_OFF=""
fi

LINE="──────────────────────────────────────────────────"

say()   { printf '%s\n' "$*"; }
blank() { printf '\n'; }
ok()    { say "${C_GREEN}✔ $*${C_OFF}"; }
bad()   { say "${C_RED}✘ $*${C_OFF}"; }
tip()   { say "${C_YELLOW}  → $*${C_OFF}"; }

# ──────────────────────────── 상태 관리 ────────────────────────────

load_state() {
  STEP=1
  if [ -f "$STATE_FILE" ]; then
    STEP=$(sed -n 's/^STEP=//p' "$STATE_FILE")
  fi
  case "$STEP" in ''|*[!0-9]*) STEP=1 ;; esac
  [ "$STEP" -lt 1 ] && STEP=1
  [ "$STEP" -gt $((TOTAL_FLOW + 1)) ] && STEP=$((TOTAL_FLOW + 1))
}

save_state() { printf 'STEP=%s\n' "$STEP" > "$STATE_FILE"; }

# ──────────────────────────── git 헬퍼 ────────────────────────────

in_repo()        { [ -d .git ]; }
has_commits()    { git rev-parse -q --verify HEAD >/dev/null 2>&1; }
current_branch() { git symbolic-ref --short -q HEAD 2>/dev/null; }
commit_count()   { git rev-list --count HEAD 2>/dev/null || echo 0; }
tree_clean()     { [ -z "$(git status --porcelain 2>/dev/null)" ]; }
branch_exists()  { git rev-parse -q --verify "refs/heads/$1" >/dev/null 2>&1; }
remote_branch_exists() { git rev-parse -q --verify "refs/remotes/$1" >/dev/null 2>&1; }
file_at()        { git show "$1:$PROFILE" 2>/dev/null; }
staged_profile() { git diff --cached --name-only 2>/dev/null | grep -q "$PROFILE"; }
# profile.md 의 '좋아하는 색' 줄 내용
color_line()     { grep '^좋아하는 색' "$1" 2>/dev/null | head -1; }
color_line_at()  { file_at "$1" | grep '^좋아하는 색' | head -1; }

# clone으로 받은 폴더 감지: 커밋 이력이나 원격이 있으면 배포 저장소의 기록이다.
pre_existing_repo() {
  in_repo || return 1
  has_commits && return 0
  [ -n "$(git remote 2>/dev/null)" ] && return 0
  return 1
}

# 기존 기록을 지우고 처음부터 시작하도록 돕는다 (확인 후에만 삭제)
fresh_init_offer() {
  bad "이 폴더에는 이미 다른 저장소의 기록(.git)이 들어 있어요."
  say "  아마 이 폴더를 zip이 아니라 clone으로 받았기 때문이에요."
  say "  이 튜토리얼은 '아무 기록도 없는 상태'에서 시작해야 합니다."
  blank
  printf '기존 기록(.git)을 완전히 지우고 새로 시작할까요? (파일 내용은 그대로 남아요) [y/N] '
  read -r ans 2>/dev/null || ans=""
  case "$ans" in
    y|Y)
      if rm -rf .git 2>/dev/null && [ ! -d .git ]; then
        blank
        ok "기존 기록을 깨끗이 지웠어요! 이제 평범한 폴더가 되었습니다."
        tip "다시  git init  을 입력하세요."
      else
        bad "기록을 지우지 못했어요. 창을 모두 닫고 다시 시도하거나 선생님을 불러 주세요."
      fi
      ;;
    *)
      say "취소했어요. 준비가 되면 다시  git init  을 입력하세요."
      ;;
  esac
}

# ──────────────────────────── 챕터 정의 ────────────────────────────

step_title() {
  case "$1" in
    1) echo "준비하기 & 저장소 만들기" ;;
    2) echo "첫 커밋 만들기 (add & commit)" ;;
    3) echo "변경을 기록하고 이력 보기 (diff & log)" ;;
    4) echo "브랜치 만들고 병합하기 (branch & merge)" ;;
    5) echo "GitHub에 올리기 (remote & push)" ;;
    6) echo "Pull Request 보내기" ;;
    7) echo "충돌(Conflict) 해결하기" ;;
  esac
}

chapter_intro() {
  case "$1" in
    1) echo "Git = 변경 이력을 기록하는 도구. 먼저 내 정보를 등록하고 저장소를 만듭니다." ;;
    2) echo "기록의 3단계:  파일 수정 → git add (기록할 것 선택) → git commit (영구 기록)" ;;
    3) echo "의미 있는 변경마다 커밋을 쌓아요. 이번엔 변경을 확인하는 명령과 함께!" ;;
    4) echo "브랜치 = 평행 우주. main은 그대로 두고 복사본에서 작업한 뒤 합칩니다(merge)." ;;
    5) echo "내 컴퓨터의 기록을 GitHub로! (docs/github-guide.md 를 옆에 펴 두세요)" ;;
    6) echo "협업의 핵심 Pull Request:  브랜치 push → PR 생성 → 리뷰 → Merge → pull" ;;
    7) echo "같은 줄을 두 브랜치에서 다르게 고치면 충돌! 일부러 만들어 직접 해결합니다." ;;
  esac
}

ch_range() {
  case "$1" in
    1) echo "1 6" ;;
    2) echo "7 11" ;;
    3) echo "12 16" ;;
    4) echo "17 23" ;;
    5) echo "24 26" ;;
    6) echo "27 34" ;;
    7) echo "35 46" ;;
  esac
}

# ──────────────────────────── 마이크로 단계 정의 ────────────────────────────
# S_CH   : 소속 챕터
# S_TYPE : cmd(명령 입력) | edit(파일 수정 후 Enter) | action(브라우저 작업 후 Enter)
# S_PAT  : cmd 단계에서 허용하는 명령 패턴 (ERE)
# S_NOW  : "지금 할 일" 표시 (cmd 단계는 명령 그대로)
# S_LIST : 챕터 체크리스트에 표시할 한 줄
# S_HINT : 추가 힌트 (선택)

step_def() {
  S_CH=0; S_TYPE=cmd; S_PAT=""; S_NOW=""; S_LIST=""; S_HINT=""; S_OKMSG=""
  case "$1" in
    1)  S_CH=1; S_PAT='^git config --global user\.name .+$'
        S_NOW='git config --global user.name "내이름"'
        S_LIST='git config --global user.name "내이름"     ← 따옴표 안은 자기 것으로!'
        S_HINT='커밋 기록에 남을 이름이에요. 예: git config --global user.name "홍길동"' ;;
    2)  S_CH=1; S_PAT='^git config --global user\.email .+$'
        S_NOW='git config --global user.email "내이메일"'
        S_LIST='git config --global user.email "내이메일"' ;;
    3)  S_CH=1; S_PAT='^git config --global core\.quotepath false$'
        S_NOW='git config --global core.quotepath false'
        S_LIST='git config --global core.quotepath false    ← 한글 깨짐 방지' ;;
    4)  S_CH=1; S_PAT='^git init$'
        S_NOW='git init'
        S_LIST='git init                                    ← 이 폴더를 저장소로! (.git 생성)' ;;
    5)  S_CH=1; S_PAT='^git branch -[mM] main$'
        S_NOW='git branch -m main'
        S_LIST='git branch -m main                          ← 브랜치 이름을 main으로 (GitHub 표준)'
        S_HINT='-m 은 move(이름 바꾸기). 방금 만든 브랜치의 이름을 main 으로 맞춰요.' ;;
    6)  S_CH=1; S_PAT='^git status$'
        S_NOW='git status'
        S_LIST='git status                                  ← 상태 확인. 앞으로 습관처럼!' ;;
    7)  S_CH=2; S_TYPE=edit
        S_NOW="edit 로 파일 수정·저장 → Enter"
        S_LIST="edit 입력 → 'TODO-이름' 줄을 내 이름으로 바꾸고 저장 → Enter" ;;
    8)  S_CH=2; S_PAT='^git status$'
        S_NOW='git status'
        S_LIST='git status                                  ← 수정된 파일이 빨간색으로!' ;;
    9)  S_CH=2; S_PAT='^git add (\.|profile\.md)$'
        S_NOW='git add .'
        S_LIST='git add .                                   ← 기록할 파일 담기 (. = 전부)' ;;
    10) S_CH=2; S_PAT='^git status$'
        S_NOW='git status'
        S_LIST='git status                                  ← 초록색으로 변신!' ;;
    11) S_CH=2; S_PAT='^git commit -m .+$'
        S_NOW='git commit -m "프로필에 이름 작성"'
        S_LIST='git commit -m "프로필에 이름 작성"            ← 영구 기록 (첫 커밋!)'
        S_HINT='-m 뒤에는 이 변경을 설명하는 메시지를 따옴표로 감싸 적어요.' ;;
    12) S_CH=3; S_TYPE=edit
        S_NOW="edit 로 파일 수정·저장 → Enter"
        S_LIST="edit 입력 → 'TODO-취미' 줄을 취미 목록으로 (예: - 농구) → Enter" ;;
    13) S_CH=3; S_PAT='^git diff$'
        S_NOW='git diff'
        S_LIST='git diff                                    ← 바뀐 내용 확인 (q 로 나가기)' ;;
    14) S_CH=3; S_PAT='^git add (profile\.md|\.)$'
        S_NOW='git add profile.md'
        S_LIST='git add profile.md' ;;
    15) S_CH=3; S_PAT='^git commit -m .+$'
        S_NOW='git commit -m "취미 목록 추가"'
        S_LIST='git commit -m "취미 목록 추가"' ;;
    16) S_CH=3; S_PAT='^git log --oneline$'
        S_NOW='git log --oneline'
        S_LIST='git log --oneline                           ← 쌓인 커밋 구경하기' ;;
    17) S_CH=4; S_PAT='^git switch -c feature/intro$'
        S_NOW='git switch -c feature/intro'
        S_LIST='git switch -c feature/intro                 ← 브랜치를 만들고 이동 (-c = create)' ;;
    18) S_CH=4; S_TYPE=edit
        S_NOW="edit 로 파일 수정·저장 → Enter"
        S_LIST="edit 입력 → 'TODO-소개' 줄을 한 문장 소개로 → Enter" ;;
    19) S_CH=4; S_PAT='^git add (\.|profile\.md)$'
        S_NOW='git add .'
        S_LIST='git add .' ;;
    20) S_CH=4; S_PAT='^git commit -m .+$'
        S_NOW='git commit -m "소개 작성"'
        S_LIST='git commit -m "소개 작성"' ;;
    21) S_CH=4; S_PAT='^git switch main$'
        S_NOW='git switch main'
        S_LIST='git switch main                             ← 소개가 사라져요! (다른 우주)'
        S_OKMSG='profile.md 를 열어 보세요 — 방금 쓴 소개가 없죠? 브랜치가 다른 우주라서예요!' ;;
    22) S_CH=4; S_PAT='^git merge feature/intro$'
        S_NOW='git merge feature/intro'
        S_LIST='git merge feature/intro                     ← 합치면 소개가 돌아옵니다' ;;
    23) S_CH=4; S_PAT='^git branch -d feature/intro$'
        S_NOW='git branch -d feature/intro'
        S_LIST='git branch -d feature/intro                 ← 다 쓴 브랜치 정리' ;;
    24) S_CH=5; S_TYPE=action
        S_NOW="브라우저에서 작업 후 Enter"
        S_LIST="GitHub에서 새 저장소 만들기 (guide ① / ⚠ README 체크 금지!) → 끝나면 Enter"
        S_HINT='docs/github-guide.md 의 ①번을 그대로 따라 하면 돼요.' ;;
    25) S_CH=5; S_PAT='^git remote add origin [^ ]+$'
        S_NOW='git remote add origin <내 저장소 주소>'
        S_LIST='git remote add origin https://github.com/아이디/저장소.git'
        S_HINT='주소는 저장소 만들기 완료 화면에서 복사할 수 있어요.' ;;
    26) S_CH=5; S_PAT='^git push -u origin main$'
        S_NOW='git push -u origin main'
        S_LIST='git push -u origin main                     ← GitHub로 올리기! (로그인 창이 뜨면 로그인)'
        S_HINT='로그인 창이 안 보이면 작업표시줄을 확인하세요 — 다른 창 뒤에 숨기도 해요.' ;;
    27) S_CH=6; S_PAT='^git switch -c feature/dream$'
        S_NOW='git switch -c feature/dream'
        S_LIST='git switch -c feature/dream' ;;
    28) S_CH=6; S_TYPE=edit
        S_NOW="edit 로 파일 수정·저장 → Enter"
        S_LIST="edit 입력 → 'TODO-장래희망' 줄을 채우고 저장 → Enter" ;;
    29) S_CH=6; S_PAT='^git add (\.|profile\.md)$'
        S_NOW='git add .'
        S_LIST='git add .' ;;
    30) S_CH=6; S_PAT='^git commit -m .+$'
        S_NOW='git commit -m "장래 희망 작성"'
        S_LIST='git commit -m "장래 희망 작성"' ;;
    31) S_CH=6; S_PAT='^git push origin feature/dream$'
        S_NOW='git push origin feature/dream'
        S_LIST='git push origin feature/dream               ← 브랜치를 GitHub로' ;;
    32) S_CH=6; S_TYPE=action
        S_NOW="브라우저에서 PR 생성·Merge 후 Enter"
        S_LIST="GitHub 웹에서 PR 생성 → Files changed 확인 → Merge (guide ③) → Enter"
        S_HINT='push 후 저장소를 새로고침하면 노란 상자의 Compare & pull request 버튼이 보여요.' ;;
    33) S_CH=6; S_PAT='^git switch main$'
        S_NOW='git switch main'
        S_LIST='git switch main' ;;
    34) S_CH=6; S_PAT='^git pull$'
        S_NOW='git pull'
        S_LIST='git pull                                    ← 병합 결과를 내 컴퓨터로!' ;;
    35) S_CH=7; S_PAT='^git switch -c theme-red$'
        S_NOW='git switch -c theme-red'
        S_LIST='git switch -c theme-red' ;;
    36) S_CH=7; S_TYPE=edit
        S_NOW="edit 로 파일 수정·저장 → Enter"
        S_LIST="edit 입력 → 맨 아래 줄을  좋아하는 색: 빨강  으로 → Enter" ;;
    37) S_CH=7; S_PAT='^git add (\.|profile\.md)$'
        S_NOW='git add .'
        S_LIST='git add .' ;;
    38) S_CH=7; S_PAT='^git commit -m .+$'
        S_NOW='git commit -m "빨강"'
        S_LIST='git commit -m "빨강"' ;;
    39) S_CH=7; S_PAT='^git switch main$'
        S_NOW='git switch main'
        S_LIST='git switch main                             ← 여기선 아직 (아직 없음) 상태!' ;;
    40) S_CH=7; S_TYPE=edit
        S_NOW="edit 로 파일 수정·저장 → Enter"
        S_LIST="edit 입력 → ★같은 줄★을  좋아하는 색: 파랑  으로 → Enter"
        S_HINT='theme-red 와 다른 내용이어야 충돌이 나요!' ;;
    41) S_CH=7; S_PAT='^git add (\.|profile\.md)$'
        S_NOW='git add .'
        S_LIST='git add .' ;;
    42) S_CH=7; S_PAT='^git commit -m .+$'
        S_NOW='git commit -m "파랑"'
        S_LIST='git commit -m "파랑"' ;;
    43) S_CH=7; S_PAT='^git merge theme-red$'
        S_NOW='git merge theme-red'
        S_LIST='git merge theme-red                         ← 💥 충돌이 나는 게 정상!'
        S_OKMSG='💥 충돌 발생 — 계획대로예요! Git이 파일 안에 질문을 적어 뒀어요. (충돌은 오류가 아니라 질문)' ;;
    44) S_CH=7; S_TYPE=edit
        S_NOW="edit 로 마커 정리·저장 → Enter"
        S_LIST="edit 입력 → <<<<<<< ======= >>>>>>> 마커 3줄을 지우고 최종 한 줄만 남기고 저장 → Enter"
        S_HINT='<<<<<<< 위아래가 두 브랜치의 내용이에요. 마커를 다 지우고 원하는 내용만! (보라로 타협도 OK)' ;;
    45) S_CH=7; S_PAT='^git add (profile\.md|\.)$'
        S_NOW='git add profile.md'
        S_LIST='git add profile.md                          ← "해결했어요"라고 알려주기' ;;
    46) S_CH=7; S_PAT='^git commit -m .+$'
        S_NOW='git commit -m "충돌 해결"'
        S_LIST='git commit -m "충돌 해결"                    ← 완주!' ;;
  esac
}

chapter_of() {
  if [ "$1" -gt "$TOTAL_FLOW" ]; then echo $((TOTAL_CH + 1)); return; fi
  step_def "$1"; echo "$S_CH"
}

# 각 단계의 명령이 '무엇을 하는 명령인지' 한 줄 설명 (화면의 '지금 할 일' 아래에 표시)
step_desc() {
  case "$1" in
    1)  echo "git config = Git의 설정을 바꾸는 명령. 커밋 기록에 남을 내 이름을 등록해요." ;;
    2)  echo "커밋 기록에 남을 이메일을 등록해요. (GitHub 계정 이메일과 같으면 좋아요)" ;;
    3)  echo "출력에서 한글 파일 이름이 깨져 보이지 않게 하는 설정이에요." ;;
    4)  echo "git init = 이 폴더에 저장소(.git)를 만들어, Git이 이력을 기록하기 시작해요." ;;
    5)  echo "git branch -m = 브랜치 이름 바꾸기. 기본 브랜치를 GitHub 표준인 main으로 맞춰요." ;;
    6)  echo "git status = 지금 저장소의 상태(무엇이 수정/대기/기록됐는지)를 보여주는 명령이에요." ;;
    7)  echo "파일을 고치는 것이 모든 기록의 시작 — profile.md가 여러분의 실습 파일이에요." ;;
    8)  echo "git status = 상태 확인. 방금 수정한 파일이 빨간색(아직 기록 대상 아님)으로 보여요." ;;
    9)  echo "git add = 변경한 파일을 Staging Area(커밋 대기석)에 올려요. '.'은 '전부'라는 뜻." ;;
    10) echo "add 후의 변화 관찰 — 초록색이면 커밋 준비 완료라는 뜻이에요." ;;
    11) echo "git commit = 대기석의 내용을 저장소에 영구 기록(스냅샷). -m 뒤는 설명 메시지예요." ;;
    12) echo "새 변경을 만들어요. 커밋은 의미 있는 변경마다 하나씩 쌓는 거예요." ;;
    13) echo "git diff = 아직 커밋하지 않은 변경 내용을 줄 단위로 보여줘요. (-)삭제 (+)추가" ;;
    14) echo "git add <파일> = 그 파일만 콕 집어 커밋 대기석에 올려요." ;;
    15) echo "git commit = 새 스냅샷을 하나 더 기록. 이렇게 이력이 쌓여요." ;;
    16) echo "git log = 지금까지의 커밋 이력 보기. --oneline 은 한 줄씩 요약 표시예요." ;;
    17) echo "git switch -c = 새 브랜치(평행 우주)를 만들고 바로 이동해요. (-c = create)" ;;
    18) echo "이 수정은 feature/intro 브랜치 위에서 일어나요 — main은 아직 그대로!" ;;
    19) echo "git add = 변경 파일을 커밋 대기석에 올리기. 브랜치 위에서도 똑같아요." ;;
    20) echo "git commit = 이 스냅샷은 feature/intro 우주에만 기록돼요." ;;
    21) echo "git switch = 브랜치 이동. main으로 돌아오면 파일 내용도 main의 모습으로 바뀌어요!" ;;
    22) echo "git merge = 다른 브랜치의 변경 내용을 지금 브랜치(main)로 합쳐요." ;;
    23) echo "git branch -d = 병합이 끝나 더 안 쓰는 브랜치를 삭제(delete)해요." ;;
    24) echo "GitHub 저장소 = 인터넷에 있는 '원격 저장소'. 백업·공유·협업의 시작이에요." ;;
    25) echo "git remote add = 원격 저장소 주소를 origin 이라는 별명으로 등록해요." ;;
    26) echo "git push = 내 커밋들을 원격 저장소로 올려요. -u 는 다음부터 git push 만 쳐도 되게 연결." ;;
    27) echo "git switch -c = PR용 작업 브랜치를 새로 만들어 이동해요." ;;
    28) echo "이 변경이 곧 Pull Request의 내용이 될 거예요." ;;
    29) echo "git add = 변경 파일을 커밋 대기석에 올리기." ;;
    30) echo "git commit = 브랜치에 스냅샷 기록. PR로 보낼 준비 완료!" ;;
    31) echo "git push origin <브랜치> = 이 브랜치 하나만 골라 GitHub로 올려요 — PR의 재료!" ;;
    32) echo "PR(Pull Request) = '이 변경을 합쳐 주세요' 요청. 동료가 검토한 뒤 Merge해요." ;;
    33) echo "git switch = 병합 결과를 받을 main 브랜치로 이동해요." ;;
    34) echo "git pull = 원격의 새 커밋(방금 Merge된 결과)을 내 컴퓨터로 받아와요." ;;
    35) echo "git switch -c = 충돌 실험용 브랜치를 만들어 이동해요." ;;
    36) echo "이 브랜치에서는 '빨강'으로 — 잠시 후 main에서는 같은 줄을 다르게 고칠 거예요." ;;
    37) echo "git add = 변경 파일을 커밋 대기석에 올리기." ;;
    38) echo "git commit = theme-red 우주에 '빨강' 스냅샷 기록." ;;
    39) echo "git switch = main으로 이동. 여기의 파일은 아직 (아직 없음) 상태예요." ;;
    40) echo "main에서는 '파랑'으로 — 같은 줄이 두 우주에서 서로 달라졌어요!" ;;
    41) echo "git add = 변경 파일을 커밋 대기석에 올리기." ;;
    42) echo "git commit = main 우주에 '파랑' 스냅샷 기록. 이제 충돌 준비 완료!" ;;
    43) echo "git merge = 합치기 시도. 같은 줄이 서로 다르면 Git이 사람에게 물어봐요 = 충돌!" ;;
    44) echo "충돌 해결 = 파일 속 마커를 지우고 최종 내용을 사람이 직접 정하는 것이에요." ;;
    45) echo "git add = '이 파일의 충돌을 해결했어요'라고 Git에게 알려주는 신호예요." ;;
    46) echo "git commit = 충돌 해결을 마무리하는 병합 커밋. 이것으로 완주!" ;;
  esac
}

# ──────────────────────────── 단계 검증 ────────────────────────────
# cmd 단계: 명령 실행 후 호출 (LAST_RC = 명령 종료 코드)
# edit/action 단계: Enter 입력 시 호출
# 통과 = 0, 실패 = 1 (실패 시 진단 메시지 출력)

step_verify() {
  case "$1" in
    1)  [ -n "$(git config user.name)" ] && return 0
        bad "user.name 이 아직 비어 있어요. 따옴표 안에 이름을 넣었나요?"; return 1 ;;
    2)  [ -n "$(git config user.email)" ] && return 0
        bad "user.email 이 아직 비어 있어요."; return 1 ;;
    3)  [ "$(git config core.quotepath)" = "false" ] && return 0
        bad "core.quotepath 가 false 로 설정되지 않았어요."; return 1 ;;
    4)  in_repo && return 0
        bad "저장소가 만들어지지 않았어요. 출력 메시지를 읽어 보세요."; return 1 ;;
    5)  [ "$(current_branch)" = "main" ] && return 0
        bad "브랜치 이름이 main 으로 바뀌지 않았어요. 출력 메시지를 읽어 보세요."; return 1 ;;
    7)  if grep -q "TODO-이름" "$PROFILE" 2>/dev/null; then
          bad "profile.md 에 아직 'TODO-이름' 줄이 남아 있어요. 수정한 뒤 꼭 '저장'했나요?"
          return 1
        fi
        return 0 ;;
    9|19|29|37|41) staged_profile && return 0
        bad "profile.md 가 아직 담기지 않았어요. 출력 메시지를 확인해 보세요."; return 1 ;;
    11) has_commits && ! file_at HEAD | grep -q "TODO-이름" && return 0
        bad "커밋이 만들어지지 않았어요. 출력 메시지를 읽어 보세요."; return 1 ;;
    12) if grep -q "TODO-취미" "$PROFILE" 2>/dev/null; then
          bad "profile.md 에 아직 'TODO-취미' 줄이 남아 있어요. 저장까지 했는지 확인!"
          return 1
        fi
        return 0 ;;
    14) staged_profile && return 0
        bad "profile.md 가 아직 담기지 않았어요."; return 1 ;;
    15) [ "$(commit_count)" -ge 2 ] && ! file_at HEAD | grep -q "TODO-취미" && return 0
        bad "커밋이 만들어지지 않았어요."; return 1 ;;
    17) [ "$(current_branch)" = "feature/intro" ] && return 0
        bad "feature/intro 브랜치로 이동하지 못했어요."; return 1 ;;
    18) if grep -q "TODO-소개" "$PROFILE" 2>/dev/null; then
          bad "'TODO-소개' 줄이 아직 남아 있어요. 저장까지 확인!"; return 1
        fi
        return 0 ;;
    20) ! file_at HEAD | grep -q "TODO-소개" && tree_clean && return 0
        bad "커밋이 완료되지 않았어요. git status 로 확인해 보세요."; return 1 ;;
    21|33|39) [ "$(current_branch)" = "main" ] && return 0
        bad "main 으로 이동하지 못했어요. 출력 메시지를 읽어 보세요."; return 1 ;;
    22) ! file_at main | grep -q "TODO-소개" && return 0
        bad "병합이 완료되지 않았어요."; return 1 ;;
    23) ! branch_exists feature/intro && return 0
        bad "브랜치가 삭제되지 않았어요. 출력 메시지를 읽어 보세요."; return 1 ;;
    24|32) return 0 ;;
    25) git remote get-url origin >/dev/null 2>&1 && return 0
        bad "origin 이 등록되지 않았어요. 주소를 정확히 붙여넣었나요?"; return 1 ;;
    26) if [ "$LAST_RC" -ne 0 ]; then
          bad "push 가 실패했어요. 출력의 마지막 줄을 읽어 보세요."
          tip "로그인 문제라면 브라우저 로그인 창을 확인하고 다시 같은 명령을 입력하세요."
          return 1
        fi
        remote_branch_exists origin/main && \
          [ "$(git rev-parse main 2>/dev/null)" = "$(git rev-parse origin/main 2>/dev/null)" ] && return 0
        bad "GitHub에 올라간 내용을 확인하지 못했어요."; return 1 ;;
    27) [ "$(current_branch)" = "feature/dream" ] && return 0
        bad "feature/dream 브랜치로 이동하지 못했어요."; return 1 ;;
    28) if grep -q "TODO-장래희망" "$PROFILE" 2>/dev/null; then
          bad "'TODO-장래희망' 줄이 아직 남아 있어요."; return 1
        fi
        return 0 ;;
    30) ! file_at HEAD | grep -q "TODO-장래희망" && tree_clean && return 0
        bad "커밋이 완료되지 않았어요."; return 1 ;;
    31) [ "$LAST_RC" -eq 0 ] && remote_branch_exists origin/feature/dream && return 0
        bad "push 가 완료되지 않았어요. 출력 메시지를 읽어 보세요."; return 1 ;;
    34) if [ "$LAST_RC" -ne 0 ]; then bad "pull 이 실패했어요. 출력 메시지를 읽어 보세요."; return 1; fi
        if file_at main | grep -q "TODO-장래희망"; then
          bad "받아왔지만 장래 희망이 없네요 — GitHub에서 PR을 아직 Merge하지 않은 것 같아요."
          tip "브라우저에서 Merge를 끝낸 뒤, 다시  git pull  을 입력하세요. (guide ③)"
          return 1
        fi
        return 0 ;;
    35) [ "$(current_branch)" = "theme-red" ] && return 0
        bad "theme-red 브랜치로 이동하지 못했어요."; return 1 ;;
    36) if color_line "$PROFILE" | grep -q "(아직 없음)"; then
          bad "'좋아하는 색' 줄이 아직 (아직 없음) 그대로예요. 수정 후 저장!"
          return 1
        fi
        return 0 ;;
    38) ! color_line_at HEAD | grep -q "(아직 없음)" && tree_clean && return 0
        bad "커밋이 완료되지 않았어요."; return 1 ;;
    40) if color_line "$PROFILE" | grep -q "(아직 없음)"; then
          bad "'좋아하는 색' 줄이 아직 (아직 없음) 그대로예요."
          return 1
        fi
        if [ "$(color_line "$PROFILE")" = "$(color_line_at theme-red)" ]; then
          bad "theme-red 브랜치와 똑같은 내용이에요 — 이러면 충돌이 나지 않아요!"
          tip "다른 색으로 바꿔 주세요. (theme-red 는 빨강이니까 파랑 추천)"
          return 1
        fi
        return 0 ;;
    42) ! color_line_at main | grep -q "(아직 없음)" && tree_clean && return 0
        bad "커밋이 완료되지 않았어요."; return 1 ;;
    43) if [ -f .git/MERGE_HEAD ] && grep -q '^<<<<<<<' "$PROFILE" 2>/dev/null; then
          return 0
        fi
        if [ "$LAST_RC" -eq 0 ]; then
          bad "어라, 충돌 없이 그냥 합쳐졌네요. 두 브랜치의 내용이 같았던 것 같아요."
          tip "선생님과 함께 확인하거나, 이 단계는 넘어가도 좋아요."
        else
          bad "병합이 예상과 다르게 진행됐어요. git status 로 상태를 확인해 보세요."
        fi
        return 1 ;;
    44) if grep -q '^<<<<<<<\|^=======$\|^>>>>>>>' "$PROFILE" 2>/dev/null; then
          bad "마커(<<<<<<< / ======= / >>>>>>>)가 아직 남아 있어요. 세 줄 모두 지워 주세요!"
          return 1
        fi
        if color_line "$PROFILE" | grep -q "(아직 없음)"; then
          bad "'좋아하는 색' 줄에 최종 내용을 남겨 주세요."
          return 1
        fi
        return 0 ;;
    45) staged_profile && return 0
        bad "profile.md 가 아직 담기지 않았어요."; return 1 ;;
    46) [ ! -f .git/MERGE_HEAD ] && tree_clean && ! file_at main | grep -q '<<<<<<<' && return 0
        bad "커밋이 완료되지 않았어요. git status 로 확인해 보세요."; return 1 ;;
    *)  # 관찰용 명령 단계(status/diff/log 등): 정상 종료면 통과
        [ "$LAST_RC" -eq 0 ] && return 0
        bad "명령이 정상 완료되지 않았어요. 출력 메시지를 읽어 보세요."; return 1 ;;
  esac
}

# ──────────────────────────── 입력 처리 (플로우의 심장) ────────────────────────────
# 반환: 0 = 단계 통과(진행됨), 1 = 현재 단계 유지, 2 = 유지 + 화면 전체 다시 그리기

# 진행과 무관하게 언제든 실행을 허용하는 관찰용 명령
OBSERVE_PAT='^git status$|^git log( .*)?$|^git diff( .*)?$|^git show( .*)?$|^git branch( -[av])?$|^git remote( -v)?$|^ls( .*)?$|^pwd$|^cat .+$'

advance_step() {
  step_def "$STEP"
  [ -n "$S_OKMSG" ] && { blank; say "${C_CYAN}$S_OKMSG${C_OFF}"; }
  STEP=$((STEP + 1)); save_state
  blank
  if [ "$STEP" -gt "$TOTAL_FLOW" ]; then
    ok "마지막 단계 통과!"
  else
    step_def "$STEP"
    ok "통과!  다음 →  $S_NOW"
    say "  ${C_DIM}$(step_desc "$STEP")${C_OFF}"
  fi
}

handle_input() {
  local cmd="$1" norm
  step_def "$STEP"
  # Enter(빈 입력): edit/action 단계에서는 검증, cmd 단계에서는 할 일 다시 안내
  if [ -z "$cmd" ]; then
    case "$S_TYPE" in
      edit|action)
        blank
        if step_verify "$STEP"; then advance_step; return 0; fi
        return 1 ;;
      *)
        blank
        tip "지금 입력할 명령:  $S_NOW"
        return 1 ;;
    esac
  fi
  norm=$(printf '%s' "$cmd" | tr -s ' ')
  # 1) 이 단계에서 요구하는 명령인가? → 실행 → 결과 검증
  if [ "$S_TYPE" = "cmd" ] && [[ $norm =~ $S_PAT ]]; then
    # git init 단계 특수 처리: clone으로 딸려 온 기존 기록이 있으면 먼저 정리
    if [ "$STEP" -eq 4 ] && pre_existing_repo; then
      blank
      fresh_init_offer
      return 2
    fi
    blank
    ( eval "$cmd" )
    LAST_RC=$?
    blank
    if step_verify "$STEP"; then advance_step; return 0; fi
    return 1
  fi
  # 2) 관찰용 명령은 언제든 OK (진행은 안 됨)
  if [[ $norm =~ $OBSERVE_PAT ]]; then
    blank
    ( eval "$cmd" )
    blank
    say "${C_DIM}(구경 완료! 이 단계의 할 일:  $S_NOW)${C_OFF}"
    return 1
  fi
  # 3) 그 외의 명령은 실행하지 않는다
  blank
  bad "지금 단계의 명령이 아니에요. 이 단계에서는 이것만 실행할 수 있어요:"
  say "     ${C_BOLD}$S_NOW${C_OFF}"
  [ -n "$S_HINT" ] && tip "$S_HINT"
  say "${C_DIM}  (git status / git log / git diff 같은 '구경용' 명령은 언제든 입력해도 돼요)${C_OFF}"
  return 1
}

# ──────────────────────────── 화면 구성 ────────────────────────────

tui_bar() {
  local i=1 bar="" cur
  cur=$(chapter_of "$STEP")
  while [ "$i" -le "$TOTAL_CH" ]; do
    if [ "$i" -lt "$cur" ]; then bar="${bar}■"; else bar="${bar}□"; fi
    i=$((i + 1))
  done
  printf '%s' "$bar"
}

# 현재 챕터의 안내 화면 (상단 영역 내용)
show_current() {
  local cur
  cur=$(chapter_of "$STEP")
  if [ "$cur" -gt "$TOTAL_CH" ]; then
    show_complete
    return
  fi
  say "$LINE"
  say "${C_BOLD} 챕터 $cur/$TOTAL_CH : $(step_title "$cur")${C_OFF}"
  say "$LINE"
  say "$(chapter_intro "$cur")"
  blank
  local range s e i mark text
  range=$(ch_range "$cur"); s=${range%% *}; e=${range##* }
  i=$s
  while [ "$i" -le "$e" ]; do
    step_def "$i"
    if [ "$i" -lt "$STEP" ]; then
      say " ${C_GREEN}✔${C_OFF} ${C_DIM}$S_LIST${C_OFF}"
    elif [ "$i" -eq "$STEP" ]; then
      say " ${C_CYAN}▶${C_OFF} ${C_BOLD}$S_LIST${C_OFF}"
    else
      say " ${C_DIM}· $S_LIST${C_OFF}"
    fi
    i=$((i + 1))
  done
  blank
  step_def "$STEP"
  say " ${C_CYAN}▶ 지금 할 일:${C_OFF}  ${C_BOLD}$S_NOW${C_OFF}"
  say "   ${C_DIM}$(step_desc "$STEP")${C_OFF}"
  if [ "$cur" -eq 1 ] && pre_existing_repo; then
    say " ${C_YELLOW}★ 이 폴더에서 기존 저장소의 기록이 감지됐어요 — git init 단계에서 정리를 도와드려요.${C_OFF}"
  fi
}

show_complete() {
  say "$LINE"
  say "${C_BOLD}${C_GREEN} 🎉 축하합니다! 46단계를 모두 완주했어요! 🎉${C_OFF}"
  say "$LINE"
  say "
여러분이 직접 경험한 것들:

  ✔ 저장소 만들기 (init)            ✔ 기록의 3단계 (add / commit)
  ✔ 변경 확인 (status / diff / log)  ✔ 평행 우주 (branch / switch / merge)
  ✔ GitHub 연결 (remote / push / pull)
  ✔ 협업 요청 (Pull Request)        ✔ 충돌 해결 (conflict)

[더 해 보기]

 · 짝과 함께: 서로의 저장소에 Collaborator로 초대해서 상대 저장소에
   PR을 보내고, 서로의 PR을 리뷰해 보세요. (docs/github-guide.md ④)
 · docs/cheatsheet.md 로 오늘 배운 명령들을 복습하세요.

수고했어요! 이제 여러분의 모든 프로젝트를 Git으로 관리해 보세요. 🚀"
}

show_progress() {
  local cur i range s e done_n total_n
  cur=$(chapter_of "$STEP")
  say "$LINE"
  say "${C_BOLD} 진행 상황${C_OFF}"
  say "$LINE"
  i=1
  while [ "$i" -le "$TOTAL_CH" ]; do
    range=$(ch_range "$i"); s=${range%% *}; e=${range##* }
    total_n=$((e - s + 1))
    if [ "$i" -lt "$cur" ]; then
      say " ${C_GREEN}✔${C_OFF} 챕터 $i. $(step_title "$i")"
    elif [ "$i" -eq "$cur" ]; then
      done_n=$((STEP - s))
      say " ${C_CYAN}▶${C_OFF} 챕터 $i. $(step_title "$i")   ← 지금 여기 ($done_n/$total_n 단계 완료)"
    else
      say " ${C_DIM}· 챕터 $i. $(step_title "$i")${C_OFF}"
    fi
    i=$((i + 1))
  done
  if [ "$cur" -gt "$TOTAL_CH" ]; then
    blank
    say " ${C_GREEN}${C_BOLD}모든 단계 완료! 🎉${C_OFF}"
  fi
}

do_hint() {
  if [ "$STEP" -gt "$TOTAL_FLOW" ]; then
    say "이미 완주했어요! 힌트는 더 필요 없죠. 😎"
    return 0
  fi
  step_def "$STEP"
  blank
  say "${C_YELLOW}💡 힌트${C_OFF}"
  tip "지금 할 일:  $S_NOW"
  tip "$(step_desc "$STEP")"
  [ -n "$S_HINT" ] && tip "$S_HINT"
  case "$S_TYPE" in
    edit)   tip "edit 를 입력하면 메모장이 열려요. 고친 뒤 꼭 '저장'하고, 이 창에서 Enter!" ;;
    action) tip "브라우저에서의 작업이 끝나면 이 창으로 돌아와 Enter 를 누르세요." ;;
  esac
}

do_reset() {
  printf '정말 진행 상황을 처음(챕터 1)으로 되돌릴까요? [y/N] '
  read -r ans 2>/dev/null || ans=""
  case "$ans" in
    y|Y)
      STEP=1; save_state
      ok "진행 상황을 초기화했어요."
      say "참고: git 저장소(.git)와 파일 내용은 그대로 남아 있어요."
      say "완전히 처음부터 하려면 docs/cheatsheet.md 의 '처음부터 다시 시작'을 보세요."
      ;;
    *) say "취소했어요." ;;
  esac
}

# 숨김 명령 — 화면/도움말 어디에도 표시하지 않는다 (강사용, instructor-guide.md 참고).
# 현재 마이크로 단계 하나를 검증 없이 건너뛴다.
do_skip() {
  if [ "$STEP" -gt "$TOTAL_FLOW" ]; then
    say "이미 완주한 상태예요."
    return 0
  fi
  step_def "$STEP"
  printf '단계 %s (%s) 을(를) 검증 없이 건너뛸까요? [y/N] ' "$STEP" "$S_NOW"
  read -r ans 2>/dev/null || ans=""
  case "$ans" in
    y|Y)
      ok "단계 $STEP 을(를) 건너뛰었어요."
      STEP=$((STEP + 1)); save_state
      say "${C_YELLOW}⚠ 이후 단계는 건너뛴 단계의 결과물이 필요할 수 있어요.${C_OFF}"
      ;;
    *) say "취소했어요." ;;
  esac
}

usage() {
  say "이 화면에서 쓸 수 있는 것:"
  say "  git 명령          현재 단계의 명령을 입력하면 실행되고, 맞으면 자동으로 다음 단계!"
  say "  Enter             파일 수정/브라우저 작업 단계에서 '다 했어요' 확인"
  say "  hint              지금 단계의 힌트"
  say "  edit              실습 파일(profile.md)을 메모장으로 열기"
  say "  progress          전체 진행 상황"
  say "  refresh           화면 다시 그리기"
  say "  quit              종료 (진행 상황은 자동 저장)"
}

# ──────────────────────────── TUI: 분할 화면 ────────────────────────────
# 상단: 튜토리얼 안내 (고정) / 하단: 터미널 (여기만 스크롤됨)

SPLIT=0

term_size() {
  set -- $(stty size 2>/dev/null)
  ROWS=${1:-24}; COLS=${2:-80}
}

tui_content() {
  local cur
  cur=$(chapter_of "$STEP")
  if [ "$cur" -le "$TOTAL_CH" ]; then
    say "${C_CYAN} Git·GitHub 튜토리얼${C_OFF}   챕터 [$(tui_bar)] $((cur > TOTAL_CH ? TOTAL_CH : cur))/$TOTAL_CH"
  else
    say "${C_CYAN} Git·GitHub 튜토리얼${C_OFF}   챕터 [$(tui_bar)] 완주! 🎉"
  fi
  show_current
}

tui_layout() {
  term_size
  local content content_h sep
  content=$(tui_content)
  content_h=$(printf '%s\n' "$content" | wc -l)
  if [ -z "${TUTORIAL_FORCE_SPLIT:-}" ]; then
    if [ ! -t 1 ] || [ "$ROWS" -lt $((content_h + 8)) ] || [ "$COLS" -lt 100 ]; then
      SPLIT=0
      return
    fi
  fi
  SPLIT=1
  sep=$((content_h + 1))
  printf '\033[r\033[2J\033[H'
  printf '%s\n' "$content"
  printf '\033[%d;1H' "$sep"
  say "${C_DIM}──── 터미널 ── ▶ 표시된 명령을 입력하세요 ── hint 힌트 · edit 파일 열기 · quit 종료 ────${C_OFF}"
  printf '\033[%d;%dr' $((sep + 1)) "$ROWS"
  printf '\033[%d;1H' $((sep + 1))
}

# 같은 챕터 안에서 단계만 바뀐 경우: 하단 기록을 지우지 않고 상단만 갱신
tui_redraw_top() {
  local content i=1 line
  content=$(tui_content)
  printf '\0337'
  while IFS= read -r line; do
    printf '\033[%d;1H\033[2K%s' "$i" "$line"
    i=$((i + 1))
  done <<< "$content"
  printf '\0338'
}

tui_cleanup() {
  if [ "$SPLIT" -eq 1 ]; then
    printf '\033[r'
    printf '\033[%d;1H' "${ROWS:-24}"
    blank
  fi
}

# ── 순차 모드(폴백): 창이 작을 때 매번 전체 화면을 다시 그린다 ──
tui_draw() {
  printf '\033[2J\033[H'
  tui_content
  blank
  say "$LINE"
  say " ${C_BOLD}▶ 표시된 명령을 입력하면 바로 실행됩니다.${C_OFF}"
  say " ${C_DIM}hint 힌트 · edit 파일 열기 · progress 진행도 · quit 종료${C_OFF}"
}

tui_pause() {
  blank
  printf '%s' "${C_DIM}(Enter 키를 누르면 안내 화면으로 돌아갑니다)${C_OFF}"
  read -r _ 2>/dev/null || true
  blank
}

tui_edit() {
  blank
  if command -v notepad >/dev/null 2>&1; then
    ( notepad "$PROFILE" >/dev/null 2>&1 & )
    say "메모장으로 $PROFILE 파일을 열었어요."
    say "수정하고 ${C_BOLD}저장${C_OFF}한 다음, 이 창으로 돌아와 Enter 를 누르세요."
  else
    say "편한 편집기로 $PROFILE 파일을 직접 열어 주세요."
  fi
}

tui_loop() {
  TUI_MODE=1
  local cmd prev_step prev_ch new_ch hrc
  tui_layout
  while true; do
    if [ "$SPLIT" -eq 0 ]; then
      tui_draw
      blank
    fi
    printf '%s' "${C_BOLD}명령> ${C_OFF}"
    if [ -t 0 ]; then
      read -r -e cmd || break
    else
      read -r cmd || break
    fi
    cmd="${cmd#"${cmd%%[![:space:]]*}"}"
    cmd="${cmd%"${cmd##*[![:space:]]}"}"
    prev_step=$STEP
    prev_ch=$(chapter_of "$STEP")
    hrc=1
    case "$cmd" in
      hint|힌트)           do_hint ;;
      progress|진행도)     blank; show_progress ;;
      edit|편집)           tui_edit ;;
      help|도움말|"?")     blank; usage ;;
      refresh|clear|화면)  tui_layout; continue ;;
      reset)               blank; do_reset ;;
      skip)                blank; do_skip ;;   # 숨김 명령 (화면에 안내하지 않음)
      check|검사)          blank; say "이 튜토리얼은 올바른 명령이 실행되면 자동으로 다음 단계로 넘어가요! (check 불필요)" ;;
      quit|exit|q|종료)    break ;;
      cd|"cd "*)
        blank
        say "이 화면에서는 폴더를 이동할 필요가 없어요 — 이미 실습 폴더 안에 있습니다!" ;;
      *)                   handle_input "$cmd"; hrc=$? ;;
    esac
    if [ "$SPLIT" -eq 1 ]; then
      if [ "$hrc" -eq 2 ]; then
        # clone 잔재 정리 등으로 화면 구성이 달라짐 → 전체 다시 그리기
        blank
        printf '%s' "${C_DIM}(Enter 키를 누르면 화면을 새로 그립니다)${C_OFF}"
        read -r _ 2>/dev/null || true
        tui_layout
      elif [ "$STEP" != "$prev_step" ]; then
        new_ch=$(chapter_of "$STEP")
        if [ "$new_ch" != "$prev_ch" ]; then
          blank
          printf '%s' "${C_DIM}(Enter 키를 누르면 다음 챕터가 열립니다)${C_OFF}"
          read -r _ 2>/dev/null || true
          tui_layout
        else
          tui_redraw_top
        fi
      fi
    else
      tui_pause
      [ "$STEP" != "$prev_step" ] && tui_layout
    fi
  done
  tui_cleanup
  say "튜토리얼을 종료합니다. 진행 상황은 저장되어 있으니 언제든 다시 실행하세요! 👋"
}

# ──────────────────────────── 시작 ────────────────────────────

load_state

case "${1:-tui}" in
  tui)        tui_loop ;;
  show|start) tui_content ;;
  progress)   show_progress ;;
  reset)      do_reset ;;
  skip)       do_skip ;;
  hint)       do_hint ;;
  check)      say "이제 check 명령은 필요 없어요 — 올바른 명령이 실행되면 자동으로 다음 단계로 진행됩니다." ;;
  help|-h|--help) usage ;;
  *) bad "모르는 명령이에요: $1"; blank; usage; exit 1 ;;
esac
