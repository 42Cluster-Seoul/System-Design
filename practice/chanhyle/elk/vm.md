## nginx access.log 로그 파일 및 메트릭 정보 수집

### 1. jdk

```shell
sudo apt-get update

# jdk 설치
sudo apt-get install openjdk-8-jdk
java -version

# nginx 설치
sudo apt-get install nginx
```

### 2. elasticsearch

```shell
# elasticsearch 설치
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
sudo apt-get install apt-transport-https
echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee –a /etc/apt/sources.list.d/elastic-7.x.list
sudo apt-get install elasticsearch
```

```shell
# /etc/elasticsearch/elasticsearch.yml

network.host: localhost # 수정
http.port: 9200 # 수정
discovery.type: single-node # 추가
```

```shell
# /etc/elasticsearch/jvm.options

-Xms512m # 추가
-Xmx512m # 추가
```

```shell
sudo systemctl start elasticsearch.service
sudo systemctl enable elasticsearch.service

curl -X GET "localhost:9200"
```

```json
{
  "name": "test",
  "cluster_name": "elasticsearch",
  "cluster_uuid": "PrTln484Rli05y8HP2L7Vg",
  "version": {
    "number": "7.17.18",
    "build_flavor": "default",
    "build_type": "deb",
    "build_hash": "8682172c2130b9a411b1bd5ff37c9792367de6b0",
    "build_date": "2024-02-02T12:04:59.691750271Z",
    "build_snapshot": false,
    "lucene_version": "8.11.1",
    "minimum_wire_compatibility_version": "6.8.0",
    "minimum_index_compatibility_version": "6.0.0-beta1"
  },
  "tagline": "You Know, for Search"
}
```

### 3. kibana

```shell
# kibana 설치
sudo apt-get install kibana
```

```shell
# /etc/kibana/kibana.yml

server.port: 5601 # 수정
server.host: "localhost" # 수정
elasticsearch.hosts: ["http://localhost:9200"] # 수정
```

```shell
sudo systemctl start kibana
sudo systemctl enable kibana

# 브라우저에서 vm 프로세스로 접속
http://192.168.64.19:5601/

curl -XGET http://localhost:9200/_cat/indices?v
```

### 4. filebeat

```shell
# filebeat 설치
sudo apt-get install filebeat
```

```shell
# /etc/filebeat/filebeat.yml

...
# ============================== Filebeat inputs ===============================

filebeat.inputs:

# Each - is an input. Most options can be set at the input level, so
# you can use different inputs for various configurations.
# Below are the input specific configurations.

# filestream is an input for collecting log messages from files.
- type: log

  # Unique ID among all inputs, an ID is required.
  id: nginx-log

  # Change to true to enable this input configuration.
  enabled: true

  # Paths that should be crawled and fetched. Glob based paths.
  paths:
    - /var/log/nginx/access.log
    #- c:\programdata\elasticsearch\logs\*
    #document_type: syslog
...
# ================================== Outputs ===================================

# Configure what output to use when sending the data collected by the beat.

# ---------------------------- Elasticsearch Output ----------------------------
# logstash를 거쳐서 갈 것이기 때문에 주석 해제
#output.elasticsearch:
  # Array of hosts to connect to.
  #hosts: ["localhost:9200"]

  # Protocol - either `http` (default) or `https`.
  #protocol: "https"

  # Authentication credentials - either API key or username/password.
  #api_key: "id:api_key"
  #username: "elastic"
  #password: "changeme"

# ------------------------------ Logstash Output -------------------------------
output.logstash:
  # The Logstash hosts
  enabled : true
  hosts: ["localhost:5044"]

  # Optional SSL. By default is off.
  # List of root certificates for HTTPS server verifications
  #ssl.certificate_authorities: ["/etc/pki/root/ca.pem"]

  # Certificate for SSL client authentication
  #ssl.certificate: "/etc/pki/client/cert.pem"

  # Client Certificate Key
  #ssl.key: "/etc/pki/client/cert.key"
...
```

- inputs
  - path : 수집할 대상(로그 파일)을 지정
  - enabled : true로 설정
- output
  - elasticsearch 관련 주석 처리
  - logstash 관련 주석 해제

```shell
cd modules.d/
mv system.yml system.yml.disabled
```

- 기본 설정으로 `Configured paths: [/var/log/auth.log* /var/log/secure*]` 등 system 관련 파일 또한 관련 로그를 파싱하는데, 이를 해제하면 더 보기 편함

```shell
sudo systemctl start filebeat
sudo systemctl enable filebeat
sudo systemctl restart filebeat
```

### 5. logstash

```shell
# logstash 설치
sudo apt-get install logstash
```

```
# /etc/logstash/logstash.conf

# Sample Logstash configuration for creating a simple
# Beats -> Logstash -> Elasticsearch pipeline.

input {
  beats {
    port => 5044
  }
}

filter {
  grok {
    match => { "message" => "%{COMBINEDAPACHELOG}" }
  }
}


output {
  elasticsearch {
    hosts => ["localhost:9200"]
    index => "%{[@metadata][beat]}-%{[@metadata][version]}-%{+YYYY.MM.dd}"
    user => "elastic"
    password => "3L5xGK9WNSiNVTPT5AHR"
  }
}
```

- filter를 통해 원하는 데이터 구조로 파싱
- output
  - hosts : elasticsearch 로 전송
  - index : 저장할 인덱스 설정(새로 생성도 됨)
  - user, password : elasticsearch에서 id, pw를 설정한 경우에 넣어주어야 함

```yaml
# /etc/logstash/logstash.yaml

# ------------ Pipeline Configuration Settings --------------
#
# Where to fetch the pipeline configuration for the main pipeline
#
path.config: "/etc/logstash/logstash.conf"
#
```

- config file path를 포함시켜야 적용이 됨

```shell
sudo systemctl start logstash
sudo systemctl enable logstash
sudo systemctl status logstash

systemctl restart logstash.service
# restart가 되지 않는 경우 강제로 process kill
ps -ef | grep logstash
kill -9 30898
```

### 6. metricbeat

```shell
# metricbeat 설치
sudo apt-get install metricbeat

sudo systemctl enable metricbeat
sudo systemctl start metricbeat
```

```shell
# metricbeat.yml

metricbeat.modules:
- module: system
  metricsets:
    - cpu
    - memory
    #- network
    #- filesystem
    #- diskio
    #- process
  enabled: true
  period: 30s  # 30초마다 메트릭을 수집하도록 설정

output.logstash:
  # The Logstash hosts
  hosts: ["localhost:5044"]
```

- system 모듈에서 cpu, memory 관련 메트릭 정보 수집
- 메트릭 정보를 logstash로 전송
