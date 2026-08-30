# GitHub 웹 화면 안내

터미널 밖(브라우저)에서 해야 하는 작업들을 순서대로 안내합니다.
튜토리얼의 Step 5~6에서 이 문서를 참조하라는 안내가 나올 때 펼쳐 보세요.

---

## ① 새 저장소(Repository) 만들기 — Step 5에서 사용

1. <https://github.com> 에 로그인합니다.
2. 화면 오른쪽 위의 **`+` 버튼 → New repository** 를 클릭합니다.
3. 다음처럼 입력합니다.
   - **Repository name**: `git-tutorial` (원하는 이름도 OK — 영문 추천)
   - **Public / Private**: 아무거나 괜찮아요. 고민되면 Public.
   - ⚠️ **"Add a README file" 은 체크하지 마세요!**
     (체크하면 GitHub 쪽에 커밋이 먼저 생겨서 push할 때 꼬입니다)
4. 초록색 **Create repository** 버튼을 클릭합니다.
5. 다음 화면에 나오는 `https://github.com/아이디/저장소이름.git` 주소를 복사해 두세요.
   → 이 주소를 터미널에서 `git remote add origin 주소` 에 사용합니다.

> 💡 **처음 push할 때 로그인 창이 떠요.**
> 터미널에서 `git push`를 처음 실행하면 브라우저 창이 열리며 로그인을 요청합니다.
> "Sign in with your browser"를 선택하고 GitHub 계정으로 로그인하면 됩니다.
> 한 번 로그인하면 컴퓨터가 기억해서 다음부터는 묻지 않아요.

---

## ② GitHub 웹에서 파일 직접 수정해 보기 — Step 5의 체험 과제

1. 내 저장소 페이지에서 `profile.md` 파일을 클릭합니다.
2. 오른쪽 위의 **연필 아이콘(✏️ Edit this file)** 을 클릭합니다.
3. 아무 내용이나 한 줄 바꿔 봅니다. (예: 취미를 하나 더 추가)
4. 오른쪽 위 초록색 **Commit changes...** 버튼 → 메시지 확인 → **Commit changes**.
5. 이제 GitHub에는 있는데 내 컴퓨터에는 없는 커밋이 생겼어요!
   터미널로 돌아가 `git pull` 을 실행해 받아옵니다.

---

## ③ Pull Request 만들고 병합하기 — Step 6에서 사용

`git push origin feature/dream` 을 실행한 다음:

1. 브라우저에서 내 저장소 페이지를 새로고침하면, 노란 상자에
   **"feature/dream had recent pushes"** 라는 안내와 함께
   **Compare & pull request** 버튼이 보입니다. 클릭!
   - 안 보이면: 저장소 상단의 **Pull requests 탭 → New pull request** 를 누르고,
     `base: main` ← `compare: feature/dream` 으로 선택하세요.
2. 제목과 설명을 적습니다. (예: "장래 희망 추가")
   실제 협업에서는 여기에 "무엇을, 왜 바꿨는지"를 적어 동료에게 설명해요.
3. **Create pull request** 버튼을 클릭합니다.
4. 만들어진 PR 화면에서 **Files changed 탭**을 눌러 보세요.
   빨간 줄(지워진 내용)과 초록 줄(새 내용)이 보입니다 — `git diff`와 같은 화면이죠!
5. **Conversation 탭**으로 돌아와 초록색 **Merge pull request → Confirm merge** 를 클릭합니다.
6. 병합 완료! 이제 GitHub의 main에는 반영됐지만 내 컴퓨터의 main은 아직 옛날 상태예요.
   터미널에서 main 브랜치로 이동한 뒤 `git pull` 로 받아오세요.

> 💡 (선택) Merge가 끝난 브랜치는 **Delete branch** 버튼으로 정리할 수 있어요.

---

## ④ 짝과 함께 진짜 협업하기 — 심화 과제 (튜토리얼 완주 후)

둘이 한 팀이 되어 해 보세요.

1. **초대하기**: 내 저장소 → **Settings → Collaborators → Add people** 에서
   짝의 GitHub 아이디를 입력해 초대합니다. (짝은 이메일/알림에서 초대를 수락)
2. **짝의 저장소 받아오기**: 짝은 내 저장소를 자기 컴퓨터로 복제합니다.
   ```bash
   git clone https://github.com/친구아이디/저장소이름.git
   cd 저장소이름
   ```
3. **PR 보내기**: 짝은 브랜치를 만들어 `profile.md`에 "친구가 보는 나" 항목을
   추가하고 push한 뒤, PR을 만듭니다.
4. **리뷰하기**: 나는 그 PR의 Files changed에서 내용을 확인하고,
   댓글을 달아 본 뒤 Merge합니다.
5. **자연스러운 충돌 경험**: 둘이 같은 파일의 같은 줄을 각자 브랜치에서 고쳐서
   PR을 두 개 만들어 보세요. 먼저 Merge된 것은 성공하지만,
   두 번째 PR에는 충돌이 표시됩니다 — Step 7에서 배운 방법으로 해결해 보세요!
