## KubeConfig

```shell
# podList를 조회하는 kubernetes REST API 방식
$> curl https://my-kube-playground:6443/api/v1/pods —-key admin.key -—cert admin.crt —-cacert ca.crt

# podList를 조회하는 kubectl 방식
$> k get pods —-server my-kube-playground:6443 —-client-key admin.key —-client-certificate admin.crt —-certificate-authority ca.crt
```

- 앞 장에서 배웠던 Client Certificate과 Root Certificate을 옵션에 포함시켜 유저를 인증(Authentication)하는 두 가지 방식
- 이 방법은 매번 하기에 너무 힘들기 때문에 `kubeConfig` 파일에 저장
- `$HOME/.kube/config`
- `k get pods —kubeconfig config` 로 짧게 해결
- kubectl을 사용할 때 증명서나 서버 주소를 명시하지 않아도 되는 이유
- 어떻게 kubectl이 어떤 context를 읽을지 아는가? 여러 컨텍스트가 있는데?
  - `current-context: dev-user@google`로 디폴트를 지정
  - 파일에 들어가서 바꿔도 되지만 아래처럼 CLI로 바꾸는 것도 가능

```shell
$> kubectl config use-context prod-user@production
```

- 클러스터는 내부에 여러 namespaces를 가질 수 있음
  - Context > namespace에서 특정 ns 적용 가능

### 파일 구성 : 세 가지 카테고리

- kind : Config

1. Clusters
   - 접근할 여러 클러스터(개발 클러스터, 배포 클러스터 …)의 종류
2. Contexts

   - Cluster와 User를 이어주는 문맥
   - 어떤 유저가 어떤 클러스터에 접근하는지 알려줌
   - 여기서는 새로운 유저를 추가하거나 설정을 변경하거나 인증하는 작업을 하지 않음
   - 단순히 존재하는 유저/권한과 클러스터를 연결해주는 역할
   - e.g. `Admin@Production`

3. Users
   - User Accounts, 클러스터에 접근을 가지고 있는 유저 계정
   - 유저마다 클러스터마다 권한이 다르기 때문에, 클러스터 별 유저를 짝지을 필요가 있음

- 각각의 설정은 어디 카테고리에?
  - `-—server my-kube-playground:6443` : Clusters
  - `-—client-key admin.key` : Cluster
  - `-—client-certificate admin.crt` : Users
  - `-—certificate-authority ca.crt` : Users
  - `MyKubeAdmin@MyKubePlayground` : Contexts

## 명령어 모음

```shell
$> k config view

# config가 여러 개 있을 때 특정하기 위해
$> kubectl config --kubeconfig=/root/my-kube-config use-context research
```
