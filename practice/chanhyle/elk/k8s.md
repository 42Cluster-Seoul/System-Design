## nginx 프로세스, 클라이언트 연결 관련 메트릭 정보 수집

### 1. elasticsearch

```yaml
# elasticsearch-deploy.yaml

apiVersion: v1
kind: ConfigMap
metadata:
  name: elasticsearch-config
  labels:
    app: elasticsearch
data:
  elasticsearch.yml: |-
    network.host: 0.0.0.0
    http.port: 9200
    discovery.type: single-node
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: elasticsearch-deployment
  labels:
    app: elasticsearch
spec:
  replicas: 1
  selector:
    matchLabels:
      app: elasticsearch
  template:
    metadata:
      labels:
        app: elasticsearch
    spec:
      containers:
        - name: elasticsearch
          image: elasticsearch:7.17.18
          env:
            - name: discovery.type
              value: "single-node"
          ports:
            - containerPort: 9200
          volumeMounts:
            - name: config-volume
              mountPath: /usr/share/elasticsearch/config/elasticsearch.yml
              subPath: elasticsearch.yml
      volumes:
        - name: config-volume
          configMap:
            name: elasticsearch-config
---
apiVersion: v1
kind: Service
metadata:
  name: elasticsearch-service
spec:
  selector:
    app: elasticsearch
  ports:
    - protocol: TCP
      name: kibana-port
      port: 9200
      targetPort: 9200
  type: LoadBalancer
```

```shell
k create -f elasticsearch-deploy.yaml

k delete cm elasticsearch-config
k delete deploy elasticsearch-deployment
k delete svc elasticsearch-service
```

- elasticsearch 관련 설정 : `elasticsearch.yml` 파일은 ConfigMap으로 구성하여 컨테이너에 volume mount
- elasticsearch service는 굳이 필요하진 않음

### 2. kibana

```yaml
# kibana-deploy.yaml

apiVersion: v1
kind: ConfigMap
metadata:
  name: kibana-config
  labels:
    app: kibana
data:
  kibana.yml: |-
    server.port: 5601
    server.host: "0.0.0.0"
    elasticsearch.hosts: ["http://${ELASTICSEARCH_SERVICE_SERVICE_HOST}:9200"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kibana-deployment
  labels:
    app: kibana
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kibana
  template:
    metadata:
      labels:
        app: kibana
    spec:
      containers:
        - name: kibana
          image: kibana:7.17.18
          ports:
            - containerPort: 5601
          volumeMounts:
            - name: config-volume
              mountPath: /usr/share/kibana/config/kibana.yml
              subPath: kibana.yml
      volumes:
        - name: config-volume
          configMap:
            name: kibana-config
---
apiVersion: v1
kind: Service
metadata:
  name: kibana-service
spec:
  selector:
    app: kibana
  ports:
    - protocol: TCP
      name: kibana-port
      port: 5601
      targetPort: 5601
  type: LoadBalancer
```

```shell
k create -f kibana-deploy.yaml

k delete cm kibana-config
k delete deploy kibana-deployment
k delete svc kibana-service

curl -XGET http://localhost:9200/_cat/indices?v
```

- elasticsearch와 마찬가지로 설정 파일을 ConfigMap을 이용하여 컨테이너에 적용
- kibana는 k8s 외부에서 접근할 수 있어야 하므로 NodePort(LoadBalancer)를 이용하여 외부로 expose

### 3. metricbeat

```yaml
# metricbeat-kubernetes.yaml

apiVersion: v1
kind: ConfigMap
metadata:
  name: metricbeat-daemonset-config
  namespace: kube-system
  labels:
    k8s-app: metricbeat
data:
  metricbeat.yml: |-
    metricbeat.config.modules:
      # Mounted `metricbeat-daemonset-modules` configmap:
      path: ${path.config}/modules.d/*.yml
      # Reload module configs as they change:
      reload.enabled: false

    processors:
      - add_cloud_metadata:

    cloud.id: ${ELASTIC_CLOUD_ID}
    cloud.auth: ${ELASTIC_CLOUD_AUTH}

    output.elasticsearch:
      hosts: ["http://${ELASTICSEARCH_SERVICE_SERVICE_HOST}:9200"]
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: metricbeat-daemonset-modules
  namespace: kube-system
  labels:
    k8s-app: metricbeat
data:
  system.yml: |-
    - module: system
      period: 10s
      metricsets:
        #- cpu
        #- load
        #- memory
        #- network
        - process
        #- process_summary
        #- core
        #- diskio
        #- socket
      processes: ['nginx']
      #process.include_top_n:
        #by_cpu: 5      # include top 5 processes by CPU
        #by_memory: 5   # include top 5 processes by memory
---
# Deploy a Metricbeat instance per node for node metrics retrieval
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: metricbeat
  namespace: kube-system
  labels:
    k8s-app: metricbeat
spec:
  selector:
    matchLabels:
      k8s-app: metricbeat
  template:
    metadata:
      labels:
        k8s-app: metricbeat
    spec:
      tolerations:
        - key: node-role.kubernetes.io/master
          effect: NoSchedule
      serviceAccountName: metricbeat
      terminationGracePeriodSeconds: 30
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      containers:
        - name: metricbeat
          image: docker.elastic.co/beats/metricbeat:7.17.18
          args: [
              #"-c", "/etc/metricbeat.yml",
              "-e",
              "-system.hostfs=/hostfs",
            ]
          env:
            - name: ELASTICSEARCH_HOST
              value: elasticsearch
            - name: ELASTICSEARCH_PORT
              value: "9200"
            - name: ELASTICSEARCH_USERNAME
              value: elastic
            - name: ELASTICSEARCH_PASSWORD
              value: changeme
            - name: ELASTIC_CLOUD_ID
              value:
            - name: ELASTIC_CLOUD_AUTH
              value:
            - name: NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
          securityContext:
            runAsUser: 0
            # If using Red Hat OpenShift uncomment this:
            #privileged: true
          resources:
            limits:
              memory: 200Mi
            requests:
              cpu: 100m
              memory: 100Mi
          volumeMounts:
            - name: config
              mountPath: /usr/share/metricbeat/metricbeat.yml
              readOnly: true
              subPath: metricbeat.yml
            - name: data
              mountPath: /usr/share/metricbeat/data
            - name: modules
              mountPath: /usr/share/metricbeat/modules.d
              readOnly: true
            - name: proc
              mountPath: /hostfs/proc
              readOnly: true
            - name: cgroup
              mountPath: /hostfs/sys/fs/cgroup
              readOnly: true
      volumes:
        - name: proc
          hostPath:
            path: /proc
        - name: cgroup
          hostPath:
            path: /sys/fs/cgroup
        - name: config
          configMap:
            defaultMode: 0640
            name: metricbeat-daemonset-config
        - name: modules
          configMap:
            defaultMode: 0640
            name: metricbeat-daemonset-modules
        - name: data
          hostPath:
            # When metricbeat runs as non-root user, this directory needs to be writable by group (g+w)
            path: /var/lib/metricbeat-data
            type: DirectoryOrCreate
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: metricbeat
subjects:
  - kind: ServiceAccount
    name: metricbeat
    namespace: kube-system
roleRef:
  kind: ClusterRole
  name: metricbeat
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: metricbeat
  namespace: kube-system
subjects:
  - kind: ServiceAccount
    name: metricbeat
    namespace: kube-system
roleRef:
  kind: Role
  name: metricbeat
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: metricbeat-kubeadm-config
  namespace: kube-system
subjects:
  - kind: ServiceAccount
    name: metricbeat
    namespace: kube-system
roleRef:
  kind: Role
  name: metricbeat-kubeadm-config
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: metricbeat
  labels:
    k8s-app: metricbeat
rules:
  - apiGroups: [""]
    resources:
      - nodes
      - namespaces
      - events
      - pods
      - services
    verbs: ["get", "list", "watch"]
  # Enable this rule only if planing to use Kubernetes keystore
  #- apiGroups: [""]
  #  resources:
  #  - secrets
  #  verbs: ["get"]
  - apiGroups: ["extensions"]
    resources:
      - replicasets
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources:
      - statefulsets
      - deployments
      - replicasets
    verbs: ["get", "list", "watch"]
  - apiGroups: ["batch"]
    resources:
      - jobs
    verbs: ["get", "list", "watch"]
  - apiGroups:
      - ""
    resources:
      - nodes/stats
    verbs:
      - get
  - nonResourceURLs:
      - "/metrics"
    verbs:
      - get
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: metricbeat
  # should be the namespace where metricbeat is running
  namespace: kube-system
  labels:
    k8s-app: metricbeat
rules:
  - apiGroups:
      - coordination.k8s.io
    resources:
      - leases
    verbs: ["get", "create", "update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: metricbeat-kubeadm-config
  namespace: kube-system
  labels:
    k8s-app: metricbeat
rules:
  - apiGroups: [""]
    resources:
      - configmaps
    resourceNames:
      - kubeadm-config
    verbs: ["get"]
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: metricbeat
  namespace: kube-system
  labels:
    k8s-app: metricbeat
```

```shell
k create -f metricbeat-kubernetes.yaml

k delete cm metricbeat-daemonset-config -n kube-system
k delete cm metricbeat-daemonset-modules -n kube-system
k delete ds metricbeat -n kube-system
k delete clusterRoleBinding metricbeat
k delete roleBinding metricbeat -n kube-system
k delete roleBinding metricbeat-kubeadm-config -n kube-system
k delete clusterRole metricbeat
k delete role metricbeat -n kube-system
k delete role metricbeat-kubeadm-config -n kube-system
k delete serviceAccount metricbeat -n kube-system
```

- `kube-system` namespace에 object들 생성
- `metricbeat`는 DaemonSet으로 생성하여 모든 노드에 pod이 생성되도록 함
- `metricbeat-daemonset-config` ConfigMap
  - 메트릭 정보를 어디로 보낼 것인지 설정 : elasticsearch or logstash
- `metricbeat-daemonset-modules` ConfigMap

  - 어떤 메트릭 정보를 어떻게 수집할 것인지 설정
  - system module : 호스트와 특정 프로세스의 cpu, memory 등 메트릭을 수집

- 두 ConfigMap 모두 volume mount path 설정 필요
  - 원래 각각의 config이 있던 path로 덮어쓰기
  - DaemonSet을 실행할 때, `-c` 옵션으로 `/etc/metricbeat.yml`을 포함하는 argument에서 삭제

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: metricbeat-daemonset-modules
  namespace: kube-system
  labels:
    k8s-app: metricbeat
data:
  system.yml: |-
    - module: nginx
      period: 10s
      metricsets: ["stubstatus"]
      enabled: true
      hosts: ["http://localhost:31139"]
      server_status_path: "nginx_status"
```

- nginx module : nginx server의 클라이언트 관련 메트릭을 수집

```config
# /etc/nginx/conf.d/deafult.conf
...

# 추가
location = /nginx_status {
    stub_status;
}
...
```

```shell
nginx -s reload
```

- nginx 컨테이너에서 추가 설정 필요
- `/nginx_status` url로 요청이 온 경우, `stub_status` 옵션을 활성화
  - 해당 옵션은 클라이언트 관련 메트릭 정보를 주는 nginx 내장 모듈
