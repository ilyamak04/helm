## Spilo PostgreSQL Helm Chart

Чарт сделан по [видео](https://boosty.to/bigkaa/posts/3af5367c-7742-429b-b3b1-2993579ea62d) Артура Крюкова

Чарт предназначен для развертывания кластера PostgreSQL на базе образа Spilo (Zalando Patroni) в Kubernetes.
Он использует StatefulSet, PVC для хранения данных, Kubernetes RBAC и опциональную подсистему резервного копирования.

### Структура репозитория

- `spilo/Chart.yaml` - метаданные чарта (имя, версия, appVersion, источник).
- `spilo/values.yaml` - основные значения по умолчанию, которые можно переопределять при установке.
- `spilo/templates/` - шаблоны Kubernetes‑манифестов:
  - `sts.yaml` - StatefulSet с кластером Spilo/PostgreSQL.
  - `service.yaml` - основной Service для доступа к кластеру.
  - `servicereplicas.yaml` - опциональный Service для реплик.
  - `serviceheadless.yaml` - headless‑сервис для работы Patroni.
  - `secret.yaml` - Secret с паролями (если не используется внешний Secret).
  - `sa.yaml`, `role.yaml`, `rolebinding.yaml` - ServiceAccount и RBAC‑правила.
  - `configmap.yaml`, `pvc.yaml` - объекты для подсистемы резервного копирования.
  - `_helpers.tpl` - вспомогательные шаблоны (имена, лейблы и т.п.).

### Быстрый старт

Установка чарта из локального каталога:

```bash
helm install my-spilo ./spilo
```

Получить сгенерированные манифесты без установки:

```bash
helm template my-spilo ./spilo
```

Удаление релиза:

```bash
helm uninstall my-spilo
```

### Основные параметры values.yaml

Ниже приведены ключевые параметры, которые чаще всего имеет смысл настраивать.
Все они находятся в файле `spilo/values.yaml` и могут быть переопределены через `--set` или отдельный values‑файл.

#### Образ и реплики

- `image.name` - образ Spilo (по умолчанию `registry.opensource.zalan.do/acid/spilo-15`).
- `image.tag` - тег образа (по умолчанию `3.0-p1`).
- `replicas` - количество Pod’ов в StatefulSet (размер кластера PostgreSQL).

Пример:

```yaml
image:
  name: registry.opensource.zalan.do/acid/spilo-15
  tag: 3.0-p1
  pullPolicy: IfNotPresent

replicas: 3
```

#### Хранение данных

Секция `data` описывает PVC для хранения данных PostgreSQL:

```yaml
data:
  storageClassName: ""
  storage: 10Gi
```

- `storageClassName` - имя StorageClass (если пусто, используется default StorageClass кластера).
- `storage` - запрашиваемый размер тома.

#### ServiceAccount и RBAC

```yaml
serviceAccount:
  name: "testRole"
```

- По умолчанию создается `ServiceAccount` с именем из этого параметра (или из `spilo.fullname`, если поменять логику).
- Для него создаются `Role` и `RoleBinding` с правами на:
  - `configmaps`, `endpoints`, `pods`, `services` - необходимые для работы Patroni через Kubernetes API.

#### Сервисы

Основной сервис:

```yaml
service:
  type: ClusterIP
  name: postgresql
  port: 5432
  nodePort: 32345
  annotations: {}
```

- `type` - тип сервиса (`ClusterIP`, `NodePort`, `LoadBalancer`).
- `port` - порт, на котором сервис будет доступен.
- `nodePort` - используется, если `type=NodePort`.
- `annotations` - произвольные аннотации сервиса.

Сервис для реплик (опциональный):

```yaml
servicereplica:
  enable: false
  type: ClusterIP
  name: postgresql
  port: 5432
  nodePort: 32345
  annotations: {}
```

Если `enable: true` и `replicas > 1`, создается отдельный сервис, направленный на реплики.

#### Секреты и пароли

Секреты могут быть сгенерированы чартом или предоставлены снаружи.

```yaml
secret:
  externalSecretName: ""
  defaultPasswords: {}
  #  superuser: password
  #  replication: password
  #  admin: password
```

Варианты:

- Если `externalSecretName` пуст:
  - Чарт создает Secret с именем `spilo.fullname`.
  - На установке пароли либо берутся из `defaultPasswords`, либо генерируются случайно.
  - На обновлениях существующие значения читаются через `lookup` и не перетираются.
- Если `externalSecretName` указан:
  - Чарт не создает Secret.
  - Pod читает пароли из указанного Secret через `env.valueFrom.secretKeyRef`.

Пример использования фиксированных паролей, создаваемых чартом:

```yaml
secret:
  externalSecretName: ""
  defaultPasswords:
    superuser: myStrongSuperuserPassword
    replication: myReplicationPassword
    admin: myAdminPassword
```

#### Пробы и ресурсы

В чарте предусмотрены liveness/readiness‑пробы и ресурсы, задаваемые через `values.yaml`:

```yaml
probes:
  livenessProbe:
    exec:
      command: [ "psql", "-U", "postgres", "-c", "SELECT 1" ]
    initialDelaySeconds: 60
    periodSeconds: 10
  readinessProbe:
    tcpSocket:
      port: 8008
    initialDelaySeconds: 20
    periodSeconds: 20

resources: {}
```

- `probes` - по умолчанию включены проверки PostgreSQL и Patroni.
- `resources` - можно задать `requests`/`limits` для CPU и памяти.

Пример минимальной настройки ресурсов:

```yaml
resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 1
    memory: 2Gi
```

#### Affinity, tolerations, аннотации

Дополнительные настройки планировщика и метаданных:

```yaml
nodeAffinity: {}
tolerations: []
annotations: {}
podAnnotations: {}
```

- `nodeAffinity` - позволяет привязать Pods к определенным нодам (например, к узлам с SSD).
- `tolerations` - позволяет запускать Pods на нодах с taints.
- `annotations` - аннотации на уровне StatefulSet.
- `podAnnotations` - аннотации на уровне Pod.

#### Резервное копирование

Подсистема backup включается флагом:

```yaml
backup:
  enable: false
  externalPvcName: ""
  dontDeletePvc: false
  crontabTime: "00 01 * * *"
  PVC:
    accessModes:
      - ReadWriteMany
    resources:
      requests:
        storage: 2Gi
```

- При `enable: true` создаются:
  - `ConfigMap` с переменными окружения для скрипта резервного копирования (wal-g).
  - `PersistentVolumeClaim` для хранения бэкапов (либо используется внешний PVC через `externalPvcName`).
- `crontabTime` - расписание выполнения backup‑скрипта (формат crontab).

### Примеры использования

Установка минимальной конфигурации с тремя репликами и дефолтными паролями:

```bash
helm install my-spilo ./spilo \
  --set replicas=3 \
  --set data.storage=20Gi
```

Установка с внешним Secret и собственным StorageClass:

```bash
helm install my-spilo ./spilo \
  --set secret.externalSecretName=my-spilo-secret \
  --set data.storageClassName=fast-ssd \
  --set data.storage=100Gi
```
