# TF-Flux-SOPS

1. Додаємо Terraform маніфести з минулого завдання

2. Запускаємо `tf init` для ініціалізації Terraform

3. Запускаємо `tf validate`  для перевірки конфігурації

4. Додаємо токен GitHub `export TF_VAR_GITHUB_TOKEN=ghp_VQUBiZTTdfsAtm1cKD3ndqpNdXasdA3C5wwUo2 `

3. Запускаємо `tf apply -var-file=vars.tfvars` для запуску Terraform

4. Налаштовуємо kubectl для доступу до наших ресурсів:`gcloud container clusters get-credentials main --zone us-central1-b --project learning-405310` `tf apply -auto-approve || (tf apply -auto-approve && gcloud container clusters get-credentials main --zone us-central1-b --project learning-405310`)`
5. Створюємо alias для kubectl `alias k=kubectl` та перевіряємо створені ресурси (ноди, неймспейси, поди) `k get no` `k get ns` `k get po -n flux-system`

6. Інсталюємо Flux та перевіряємо передумови для нього `flux check --pre` , `flux logs -f` – безперервний вивід логів

7. Додаємо новий неймспейс kbot через створення маніфесту у репозиторії `gke-flux/clusters/kbot/ns.yaml` :

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: kbot
```

8. Створюємо маніфест GitRepository `gke-flux/clusters/kbot/kbot-gr.yaml`:

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: kbot
  namespace: kbot
spec:
  interval: 1m0s
  ref:
    branch: main
  url: https://github.com/dm-ol/kbot
```

9. Створюємо маніфест Helm release `gke-flux/clusters/kbot/kbot-hr.yaml`:

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: kbot
  namespace: kbot
spec:
  chart:
    spec:
      chart: ./helm
      reconcileStrategy: ChartVersion
      sourceRef:
        kind: GitRepository
        name: kbot
  interval: 1m0s
```

10. Перевіримо процес створення нових об'єктів у неймспейсі "kbot" `k get po -n kbot -w`. Поди створяться, але буде помилка запуску через відсутність secret token.

11. Кодуємо наш токен в Base64: `echo -n 6083582845:AAHMkm7-4lpxKKpvn3yReT3GM_Vdl4OHauA | base64`

12. Створюємо маніфест (вже створюється автоматично) `secret.yaml`:

```yaml
apiVersion: v1
data:
  TELE_TOKEN: NjA4MzU4Mjg0xhpBQUhNa203LTRscHhLS3B2bjs3UmVUM0dNX1ZkbDRPSGF1QQ==
kind: Secret
metadata:
  creationtimestamp: null
  name: kbot
  namespace: kbot
```

13. Встановлюємо SOPS (автоматично): https://github.com/getsops/sops

14. Додаємо до `main.tf` два нових модулі:

```terraform

module "gke-workload-identity" {
  source              = "terraform-google-modules/kubernetes-engine/google//modules/workload-identity"
  use_existing_k8s_sa = true
  name                = "kustomize_controller"
  namespace           = "flux-system"
  project_id          = var.GOOGLE_PROJECT
  cluster_name        = "main"
  location            = var.GOOGLE_REGION
  roles               = ["roles/cloudkms.cryptoKeyEncrypterDecrypter"]
  annotate_k8s_sa     = true

}

module "kms" {
  source          = "terraform-google-modules/kms/google"
  version         = "~> 2.2"
  project_id      = "var.GOOGLE_PROJECT"
  location        = "global"
  keyring         = "sops-flux"
  keys            = ["sops-key-flux"]
  prevent_destroy = false

}

```

15. Запускаємо `tf init` для ініціалізації нових модулів

16. Запускаємо `tf apply -var-file=vars.tfvars` для запуску нових модулів

17. Створюємо патч-маніфест для Service-account `gke-flux/clusters/flux-system/sa-patch.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kustomize-controller
  namespace: flux-system
  annotations:
    iam.gke.io/gcp-service-account: kustomize-controller@learning-405310.iamgserviceaccount.com
```

18. Створюємо патч-маніфест для SOPS `gke-flux/clusters/flux-system/sops-patch.yaml`:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 10m0s
  path: ./clusters
  prune: true
  sourceRef:
    kind: GitRepository
    name: gke-flux
  decryption:
    provider: sops
```

19. Додаєм до `gke-flux/clusters/flux-system/kustomization.yaml` патчі:

```yaml
patches:
  - path: sops-patch.yaml
    target:
      kind: Kustomization
  - path: sa-patch.yaml
    target:
      kind: ServiceAccount
      name: kustomize-controller
```

20. Перевіряємо аннотацію до модуля кастомізації: `k get sa -n flux-system kustomize-controller -o yaml|grep -A5 anno`

21. Перевіряємо наявність KMS ключів: `gcloud config set project learning-405310`

    `gcloud kms keys list --location global --keyring sops-flux`

22. Створюємо ключ в Google KMS і копіюємо його ID: projects/learning-405310/locations/global/keyRings/sops-flux/cryptoKeys/sops-key-flux

23. Створюємо Secret з токеном в Google Secret Manager: projects/307830987280/secrets/TELE_TOKEN/versions/1

24. Відкриваємо доступ до Google KMS з GitHub Actions за допомогою сервісного аккаунту та Workload Identity. Створюємо пул: `gcloud iam workload-identity-pools create "github"   --project="learning-405310"   --location="global"   --display-name="GitHub Actions Pool"` Перевіряємо пул: `gcloud iam workload-identity-pools describe "github" --project="learning-405310" --location="global"  --format="value(name)"` Отримуємо відповідь: `projects/307830987280/locations/global/workloadIdentityPools/github`

     Далі створюємо провайдера: `gcloud iam workload-identity-pools providers create-oidc "actions" --project="learning-405310" --location="global" --workload-identity-pool="github" --display-name="My GitHub repo Provider" --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" --issuer-uri="https://token.actions.githubusercontent.com"`, та перевіряємо створення`gcloud iam workload-identity-pools providers describe "actions" --project="learning-405310" --location="global" --workload-identity-pool="github" --format="value(name)"` і отримуємо відповідь `projects/307830987280/locations/global/workloadIdentityPools/github/providers/actions

25. Зв'язуємо сервісний аккаунт з WI: `export REPO="dm-ol/flux-sops"`, потім  `export WORKLOAD_IDENTITY_POOL_ID="projects/307830987280/locations/global/workloadIdentityPools/git-hub" ` та  `gcloud iam service-accounts add-iam-policy-binding "actions@learning-405310.iam.gserviceaccount.com" --project="learning-405310" --role="roles/iam.workloadIdentityUser" --member="principalSet://iam.googleapis.com/${WORKLOAD_IDENTITY_POOL_ID}/attribute.repository/${REPO}"`.

26. Створюємо workflow для GitHub Actions:

```yaml
name: Encrypt Secret Manifest and Save in Repository

  

on:  push

  

jobs:

  encrypt_and_save:

    runs-on: ubuntu-latest

    permissions:

      contents: write

      pull-requests: write

      id-token: write

    steps:

  

      - name: 'Checkout repository'

        uses: actions/checkout@v4

        with:

          persist-credentials: false # otherwise, the token used is the GITHUB_TOKEN, instead of your personal access token.

          fetch-depth: 0 # otherwise, there would be errors pushing refs to the destination repository.

  

      - name: 'Authenticate to Google Cloud'

        id: 'auth'

        uses: 'google-github-actions/auth@v2'

        with:

          token_format: 'access_token'

          project_id: 'learning-405310'

          workload_identity_provider: 'projects/307830987280/locations/global/workloadIdentityPools/git-hub/providers/actions'

          service_account: 'actions@learning-405310.iam.gserviceaccount.com'

      - name: 'Pull secret from Google Secret Manager'

        id: 'secrets'

        uses: 'google-github-actions/get-secretmanager-secrets@v2'

        with:

          secrets: |-

            token:learning-405310/TELE_TOKEN

      - name: 'Install SOPS'

        run: |

          curl -LO https://github.com/getsops/sops/releases/download/v3.7.3/sops-v3.7.3.linux.amd64

          chmod +x ./sops-v3.7.3.linux.amd64

          sudo mv ./sops-v3.7.3.linux.amd64 /usr/local/bin/sops

  

      - name: 'Create Kubernetes Secret Manifest'

        run: |

          echo -e "apiVersion: v1 \nkind: Secret \nmetadata: \n  creationtimestamp: null \n  name: kbot \n  namespace: kbot \ndata: \n  token: $(echo -n "${{ steps.secrets.outputs.token }}" | tr -d '\n' | base64 -w 0)" > secret.yaml

  

      - name: 'Encrypt Secret Manifest'

        run: |

          sops -e -gcp-kms projects/learning-405310/locations/global/keyRings/sops-flux-2/cryptoKeys/sops-key-flux --encrypted-regex '^(token)$' secret.yaml > secret-enc.yaml

      - name: 'Push secret Manifest to GitHub repository'

        uses: GuillaumeFalourd/git-commit-push@v1.3

        with:

          email: github-actions@github.com

          name: github-actions

          commit_message: "Add encrypted secret manifest"

          # remote_repository: https://github.com/dm-ol/gke-flux

          target_branch: main

          files: secret-enc.yaml

          access_token: ${{ secrets.GITHUB_TOKEN }}

          force: true
```

  

28. Шифруємо файл Secret.yaml (вже автоматично): `sops -e -gcp-kms projects/learning-405310/locations/global/keyRings/sops-flux/cryptoKeys/sops-key-flux --encrypted-regex '^(token)$' secret.yaml > secret-enc.yaml`

29. Переносимо файл secret-enc.yaml до репозиторію `gke-flux/clusters/kbot/secret-enc.yaml` де автоматом його підхвачує flux.

30. Перевіряємо роботу подів і бота.
31. Після перевірки не забуваємо видалити інфраструктуру командою `tf destroy`
