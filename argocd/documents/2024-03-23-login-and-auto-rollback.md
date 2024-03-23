# ArgoCD 를 이용해서 배포하려면 꼭 로그인 해야 하는가?

결론부터 이야기하면 ArgoCD 를 이용해서 배포하려면 로그인 과정이 필요합니다.

이를 이해하기 위해서 ArgoCD 의 구성 요소 먼저 살펴보겠습니다.

## ArgoCD 의 구성 요소

ArgoCD 는 크게 아래의 3가지로 구성되어 있습니다.

1. API Server
   - 웹 UI, CLI, CI/CD 시스템에서 사용하는 API 를 노출하는 gRPC/REST 서버
   - 전반적인 부분 담당
2. Repository Server
   - 애플리케이션의 Git Repository 의 로컬 캐시를 유지하는 서버
3. Application Controller
   - 애플리케이션을 모니터링하고 Current State 를 Desired State 와 비교
   - OutOfSync 감지 및 필요 시 교정 작업 수행

여기서 배포 작업을 할 때는 API Server 를 통해서 진행합니다.

API Server 에 등록된 사용자만 배포 작업을 수행할 수 있습니다.

## ArgoCD 의 계정 종류

API Server 에 사용자를 등록하기 위한 방법은 크게 2가지가 있습니다.

1. 로컬 계정
   - ArgoCD 에서 자체적으로 ConfigMap 로 계정을 관리
   - 관리자가 직접 계정을 생성하고 비밀번호도 전달해줘야 하는 번거로움 있음
2. SSO
   - OIDC 프로토콜을 사용해서 외부 신원 공급자(Google, Github 등)에게 사용자의 정보를 받아서 계정을 생성
   - 1번과 달리 계정을 사용자가 직접 생성하지만, 관리자는 RBAC 을 이용해서 사용자의 권한을 적절하게 제한해야 한다.
   - OAuth 앱을 등록할 때는 관리자의 OAuth 앱 Client ID, Client Secret 을 등록해줘야 한다. (초기 설정)

자료를 찾아보니 IRSA 를 이용해서 사용자를 인증하는 방법도 있는 것 같습니다만, 이 부분은 추가 자료 조사가 필요합니다. (참고 자료: [ArgoCD - Cross Account EKS Cluster 연동](https://cloudest.oopy.io/posting/103))

ArgoCD 에 등록된 계정은 관리자가 정의한 RBAC 에 따라서 제한된 권한을 가질 수 있습니다.

예를 들어, Github 계정으로 로그인 한다면, 조직이나 팀에 따라 다른 권한을 부여하는 것이 가능합니다.

# ArgoCD 배포 중 오류 발생 시 자동 롤백

ArgoCD Rollout 을 이용하면 배포 전략(blue/green, canary, rolling)을 적용할 수 있습니다.

만약, 배포 중 오류가 발생한다면 이전 상태로 되돌려서 서비스를 그대로 유지할 수 있어야 합니다.

배포 실패 시 자동 롤백을 가능하게 하는 것이 Analysis 인데, 이를 이해하기 위해서는 ArgoCD 가 무중단 배포를 위해 거치는 단계를 살펴보겠습니다.

여기서는 blue/green 배포 전략을 사용할 때 거치는 과정을 살펴보겠습니다.

## ArgoCD 의 배포 단계

ArgoCD 는 blue/green 배포를 할 때, 바로 그린 버전(업데이트 버전)을 배포하는 것이 아니라 테스트용 파드를 먼저 실행합니다. 이를 preview service 라고 합니다.

1. 처음 배포가 문제 없이 이루어지면 revision 1 이라는 레플리카셋이 active service(현재 운영 중인 서비스)와 preview service(테스트용 서비스) 를 가리킵니다.

2. Git 저장소에서 서비스의 파드 개수를 조절하는 등 변경이 발생해서 sync 를 수행하면 revision 2 레플리카셋이 생성됩니다. 이때, revision 2 에는 어떠한 파드도 없습니다.

3. 이제 preview service 는 revision 2 레플리카셋을 가리킵니다.

4. revision 2 레플리카셋은 2번에서 발생한 변경 사항에 따라 파드를 실행합니다. (`spec.replicas` 또는 `previewReplicaCount`에 명시된 만큼 파드 생성)

5. 4번에서 파드가 모두 실행되면 `prePromotionAnalysis` 를 수행합니다. 여기서 의미하는 Promotion 은 새로운 버전의 파드로 트래픽을 변경하고, 이전 버전의 트래픽을 끊고 이전 버전의 파드를 삭제하는 것을 의미합니다.

6. `prePromotionAnalysis` 가 성공하면 active service 는 revision 1 에서 revision 2 를 가리킵니다. 만약 실패하면 이전 버전에 해당하는 revision 1 을 그대로 가리키고, 새로 생성한 파드를 삭제합니다.

7. 6번에서 성공했으면 `postPromotionAnalysis` 를 수행합니다. 이 과정도 성공하면 revision 2 레플리카셋을 안정된 상태(stable)로 표시합니다. 마찬가지로 이 과정이 실패하면 6번과 동일하게 이전 버전으로 롤백을 합니다.

## 적용 코드

예시로 아래와 같이 정의한 yaml 파일을 적용했습니다.
여기서는 `prePromotionAnalysis` 를 적용했으며, 이를 위한 템플릿은 `fail` 이름을 가진 것을 사용했습니다.

또한, 배포가 실패하면 자동으로 새롭게 생성했던 리소스를 삭제할 수 있도록 syncPolicy.automated.prune 속성을 true 로 설정했습니다. (이 부분은 조금 더 테스트가 필요.)

```yaml
# blue-green-rollout.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: rollout-bluegreen
spec:
  replicas: 2
  selector:
    matchLabels:
      app: rollout-bluegreen
  template:
    metadata:
      labels:
        app: rollout-bluegreen
    spec:
      containers:
        - name: rollouts-demo
          image: argoproj/rollouts-demo:green
          ports:
            - containerPort: 8080
  strategy:
    blueGreen:
      activeService: rollout-bluegreen-active
      previewService: rollout-bluegreen-preview
      prePromotionAnalysis:
        templates:
          - templateName: fail
  syncPolicy:
    automated:
      prune: true
---
kind: Service
apiVersion: v1
metadata:
  name: rollout-bluegreen-active
spec:
  selector:
    app: rollout-bluegreen
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
      nodePort: 30081
  type: NodePort

---
kind: Service
apiVersion: v1
metadata:
  name: rollout-bluegreen-preview
spec:
  selector:
    app: rollout-bluegreen
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
      nodePort: 30082
  type: NodePort
```

localhost:30081 에는 active 상태의 애플리케이션을, localhost:30082 에는 preview 상태의 애플리케이션을 볼 수 있도록 설정했습니다.

그리고 `prePromotionAnalysis` 템플릿은 아래의 yaml 파일을 적용했습니다.

```yaml
kind: AnalysisTemplate
apiVersion: argoproj.io/v1alpha1
metadata:
  name: fail
spec:
  metrics:
    - name: fail
      count: 2
      interval: 5s
      failureLimit: 1
      provider:
        job:
          spec:
            template:
              spec:
                containers:
                  - name: sleep
                    image: alpine:3.8
                    command: [sh, -c]
                    args: [exit 1]
                restartPolicy: Never
            backoffLimit: 0
```

Analysis 를 수행하고 나서 프로세스의 종료 상태값이 0이 아니면 모두 실패로 간주합니다.

이때, Analysis 를 수행할 때 다양한 서드파티 애플리케이션을 활용할 수 있습니다.

예를 들면, Prometheus 의 메트릭을 수집해서 CPU 사용률이 지나치게 높다면 배포 중에 이상이 있는 것으로 판단을 하도록 설정이 가능합니다.

위의 템플릿은 아래와 같은 과정을 거칩니다.

- 5초 간격(interval)으로 총 2번(count) 작업(job)에 명시된 것을 수행합니다.
- 여기서는 alpine 이미지 컨테이너에서 쉘을 실행하고 나서 바로 exit 1 명령어를 수행해서 컨테이너를 종료합니다.
- 작업이 종료 상태값이 0 이 아닌 1 이기 때문에 실패로 간주하고 업데이트를 위한 배포를 중단합니다.

## 참고자료

- [BlueGreen Deployment Strategy](https://argo-rollouts.readthedocs.io/en/stable/features/bluegreen/) [argo-rollouts]
