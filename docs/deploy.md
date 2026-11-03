# デプロイ構成

`main` への push で CI の全ジョブが成功すると、`.github/workflows/ci.yml` の `deploy` ジョブが本番へデプロイする。
本番サーバーの SSH ポートはインターネットに公開しない。GitHub Actions の runner は Tailscale の tailnet に一時参加して接続する。
構成は summa と同じ（summa の `docs/deploy.md` も参照）。

## 接続経路

1. `tailscale/github-action` (v4、commit SHA で固定) が Tailnet Lock で署名済みの認証キーで runner を tailnet に参加させる。キーに設定した `tag:ci` が付き、ジョブ終了後に自動で消える。接続先への ping が通ってからデプロイを始める。
2. runner は CI 専用鍵で `admin@showway-t4g.tailb46b1.ts.net` の `65522` 番へ SSH する。このポートはアプリが動く nspawn コンテナの sshd に届く。
3. コンテナ内の `/home/admin/liberation` で `scripts/deploy.sh` を実行する。

## GitHub Secrets

| 名前 | 内容 |
| --- | --- |
| `TAILSCALE_AUTHKEY` | `tag:ci` 付き、再利用可能・一時端末用の認証キーを Tailnet Lock の署名ノードで署名したもの |
| `EC2_SSH_KEY` | CI 専用 SSH 秘密鍵（ed25519、コメント `liberation-ci`） |
| `AUTHENTIK_CLIENT_SECRET` | Authentik OIDC の client secret |
| `CLOUDFLARE_PDF_TOKEN` | PDF 生成 Worker のトークン |

`AUTHENTIK_CLIENT_SECRET` / `CLOUDFLARE_PDF_TOKEN` は SSH の stdin 経由でコンテナの `/etc/liberation/authentik.env` に書き込み、`liberation.service` の drop-in で読み込ませる。リモートのコマンドライン引数には載せない。

`EC2_HOST` / `EC2_PORT` は公開 SSH ポート時代の名残で、今は使っていない。

## Tailscale 側の設定

- 認証キーは Tailscale の Keys 画面で `Reusable`・`Ephemeral`・`tag:ci` を指定して作り、署名ノードで `tailscale lock sign` を実行する。出力された署名済みキーを `TAILSCALE_AUTHKEY` に登録する。
- 認証キーは最長 90 日で失効する。期限前に新しいキーを作って署名し、GitHub Secret を更新する。
- `acls` は全許可のままなので、`tag:ci` からコンテナの `65522` 番へ届く。`acls` を絞る場合は `tag:ci` → `tag:server:65522` を許可すること。

## 運用メモ

- CI 専用鍵の公開鍵は、コンテナの `admin` の `~/.ssh/authorized_keys` に登録してある。
- 鍵を入れ替えるときは、新しい鍵ペアを作って公開鍵をコンテナに追記し、`gh secret set EC2_SSH_KEY < 秘密鍵` で登録してから、古い公開鍵を `authorized_keys` から消す。
- runner は毎回まっさらなので、ホスト鍵は `StrictHostKeyChecking=accept-new` で受け入れている。接続先ノードの正当性は Tailscale が担保する。
