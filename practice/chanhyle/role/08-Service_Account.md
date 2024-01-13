## Service Account

- SA는 다른 보안 개념(authentication, authorization, RBAC 등..)과 관련이 있음
- CKA에서는 SA와 관련 개념들이 어떻게 작동하는지만 알면 된다(SA 자체를 이해하지 않아도 된다)
- User Account / Service Account : 두 가지 타입의 계정이 존재

### User Account

- 사람에 의해서 사용됨
- Admin : administrative task를 하기 위해서
- Developer : application을 배포(deploy)하기 위해

### Service Account

- machine에 의해서 사용됨
- Application이 클러스터와 소통하기 위해서 사용됨
  - Prometheus : 모니터링 어플리케이션이 성능 메트릭을 위해 kubernetes API를 이용
  - Jenkins : 빌드 툴이 어플리케이션을 배포하기 위해 이용
- e.g.
  - 배포할 때 수행하는 모든 작업은 쿠버네티스 API에 요청을 전송하여 쿠버네티스 클러스터의 포드 목록을 검색하고 웹 페이지에 표시하는 것입니다.
  - 웹 어플리케이션이 쿠버네티스 API에 쿼리하기 위해서는 “인증”이 필요하다. 그래서 SA를 이용한다

```shell
# 생성
$> k create serviceaccount dashboard-sa
# 조회
$> k get serviceaccount
$> K describe serviceaccount dashboard-sa
```

#### 토큰 자동 생성(Deprecated)

- SA가 생성되면 자동적으로 “토큰”을 생성
- 토큰은 외부 앱이 kube API에 인증하는 과정에서 필요하다
- 생성되는 토큰은 만료기간이 없고, 어떤 audience에도 제한받지 않음
- deploy하는 파드가 클러스터 내부에 있다면, 자동으로 default SA를 사용하는 파드에 볼륨 마운트 되는 성질을 가지고 있음
- 생성 과정
  1. 토큰을 먼저 생성하고, 비밀 오브젝트를 생성한 후 거기에 담는다
  2. 이후 SA와 비밀 오브젝트가 링크된다
  3. `k describe secret dashboad-sa-token-kbbdm` 으로 토큰 값을 확인할 수 있다
     - 이후 버전에서는 토큰 이름을 알려주지 않는 듯?
- 이 (베어러) 토큰은 kubernetes API로 REST API 요청을 만들 때 사용될 수 있다

```shell
$> curl https://~:6443/api -insecure —header “Authorization: Bearer ~”
```

- 웹 앱에서 유저가 토큰 필드를 저장하게 하여 인증 수단으로서 요청할 때 사용한다
  (계정당 SA를 발급하게 하는 기능도 필요할 듯?)

### 파드에 토큰 자동 마운트(Deprecated)

- SA를 생성하여
- RBAC을 통해 적절한 권한을 설정하고(여기서는 다루지 않음)
- 토큰을 추출하여 사용자에게 전달하고
- 서드 파티 앱에서 이 토큰을 사용하여 kubernetes REST API를 호출하게 한다

#### 만약 서드 파티 앱이 클러스터 내부에서 배포되었다면?

- 예를 들어, 대시보드, 모니터링 앱이 클러스터에서 배포된다면? **서비스 시크릿 토큰을 서드 파티 앱이 있는 파드 안에 볼륨으로 마운트 함으로써 간단하게 만들 수 있다**
- 일일이 손으로 하지 않아도 되는 과정이 있나?
- 앱이 쉽게 읽을 수 있기 때문에(내부가 아니라면? 외부 디비에서 관리해야 하나?)

#### default SA

- ns마다 생성되어 있음
- 파드가 생성되면, default SA와 토큰이 파드에 “자동으로“ 볼륨 마운트 된다
- Default 토큰은 만료 기간이 없음(토큰은 SA가 존재하는 한 유효함)
- 파드 def에 명시하지 않아도 describe를 해보면, volume에 deafult-token이 존재
- 마운트된 지점은 `/var/run/secrets/kubernetes.io/serviceaccount` (파드 안의 경로)

```shell
$> k exec -it my-kubernetes-dashboad ls /var/run/secrets/kubernetes.io/serviceaccount

# token 파일이 존재
```

- 하지만 default SA는 매우 제한적인 단점이 있다
- 간단한 기본적인 kube API 쿼리에만 허용이 되어 있다

#### 새로운 SA를 파드에 포함하기 위해서는?

- [Pod definition file] Spec > serviceAccountName 항목을 추가하면 됨
- 단, 이미 올라간 파드의 SA는 변경할 수 없음(지우고 새로 파드를 생성해야 적용됨)
- 하지만 배포 환경에서는 pod def를 수정할 수 있지만, “deployments”가 자동으로 rollout 되는 것에 주의
- 즉, deployments가 바뀐 SA를 적용하기 위해 rollout
- 자동으로 default SA가 마운트되게 하지 않으려면?
  - Pod def Spec > automountServiceAccountToken : false 추가

### 1.22

- `tokenRequestedAPI`의 추가
- Audiencd/time/object bound, more secure via kube API
- 따라서, 이제 파드가 생성되면 SA 시크릿 토큰에 의존하지 않음
- tokenRequestedAPI에 의해 만료 시간이 존재하고, projected bolume에 저장되는 토큰을 생성

### 1.24

```shell
$> kubectl create token dashboard-sa
```

- 토큰을 따로 발급해야 함
- SA를 만든다고 해서 자동으로 토큰이 발급되지 않음
- 이전 버전처럼 만료가 없는 토큰을 생성하기 위해서는?

```c
// secret-definition.yml
apiVersion: v1
kind: Secret
type: kubernetes.io/service-account-token
metadata:
	Name: mysecretname
	annotaion:
		kubernetes.io/service-account.name: dashboard-sa
```

- 위의 예에서는 특정 SA와 관련된 만료가 없는 토큰을 생성하는 방법(SA 생성이 전제됨)
- 특별한 상황이 아니면, tokenRequestedAPI이 추천됨

## 명령어 모음

```shell
$> k get sa -n default
$> k describe sa default
$> k get deployments
$> k describe deployments web-dashboard
$> k describe pod web-dashboard-97c9c59f6-rmdbk
$> k create sa dashboard-sa
$> k describe rolebindings / roles
$> kubectl create token dashboard-sa
```
