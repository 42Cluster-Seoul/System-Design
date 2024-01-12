## Authorization

- 인증(Authentication)은 사용자가 누군지 식별하는 것
- 인가(Authorization)는 인증된 사용자가 특정 권한이 있는지 식별하는 것

- 예시

  - Admin : 파드, 노드 접근 가능 / 노드 삭제 가능
  - Developers : 파드, 노드 접근 가능 / 노드 삭제 불가능
  - Bots : 파드, 노드 접근 불가능 / 노드 삭제 불가능

- 위와 같이 특정한 인증된 사용자에 따라 권한을 따로 부여하고 싶은 경우 설정하는 것이 인가 정책

### 4가지 인가 방법

#### 1. Node

- kube-apiServer는 사용자나 kubelet으로부터 요청을 받을 수 있음
- 이러한 작업들은 Node Authorizer라고 하는 오브젝트로부터 핸들링 됨
- 증명서에 system:node라고 붙였던 것은 이러한 Node authorizer 때문

#### 2. ABAC(Attribute-Based Access Control)

- 특정 사용자나 그룹마다 JSON 포맷의 속성을 적어놓는 방식
- 같은 권한이라 하더라도, 모든 사용자나 그룹마다 파일을 만들어야 하기 때문에, 중복 발생
- 수작업으로 해야하고, apiServer를 restart 해야 함
- 다루기가 꽤 힘듦

#### 3. RBAC(Role-Based Access Contorl)

- 유저와 권한 묶음을 직접 연관하는 것이 아니라
- 역할이라는 것을 만들고(권한의 묶음), 모든 유저를 이 역할과 연관시킴
- 수정 사항이 생기면 역할의 내용을 변경하면 됨
- 쿱에서 보편적인 방식

#### 4. Web hook

- 인가를 도와주는 서드 파티 앱
- 요청이 도착하면, open policy agent에게 허용해도 되는지 물어보고
- 해당 앱은 여부를 apiServer에 알려주는 방식

#### 5. Always allow

#### 6. Always deny

### 어디서 변경?

```shell
$> vim /etc/kubernetes/manifest/kube-apiServer.yaml

...
  -—authroization-mode=Node, RBAC, WebHook
...
```

- 각각의 모듈을 comma seperated의 체인 형식으로 진행
- 즉, node에서 실패하면 rbac으로, rbac에서 실패하면 web hook 모듈로 시도
- 체인 앞 쪽에서 성공하면 뒤로 보내지 않음
