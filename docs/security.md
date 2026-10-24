# セキュリティ点検

[www の共通手順](https://github.com/kusanaginoturugi/www/blob/main/docs/security-runbook.md) を Rails アプリ向けに置き換えたもの。

## 構成と攻撃面

- Rails 8.1 (Ruby 3.4.8)、SQLite。本番は Cloudflare 経由で nspawn コンテナの Puma に届く。デプロイは [deploy.md](deploy.md)。
- 認証は Authentik (OIDC)。`AUTHENTIK_CLIENT_SECRET` があるとパスワードログインは使えない。
- ログインなしで見られるもの: 修霊番号一覧、挙行一覧と CSV/印刷用 HTML、挙行予定表と PDF。画面のナビゲーションから辿れるようにしている仕様。
- PDF は Cloudflare Worker `workers/liberation-pdf` (Browser Rendering) が作る。Worker は別の Cloudflare アカウントにあり、この repo の CI ではデプロイしない。
- importmap / Turbo / Stimulus の gem は入っているが、`config/importmap.rb` がなくレイアウトでも読み込んでいない。JS はビュー内の inline script だけ。

## 定期点検

1. GitHub の Security タブで Dependabot alerts、Code scanning (CodeQL: actions / ruby / javascript-typescript)、Secret scanning を見る。
2. CI は週次 (月曜 9:00 JST) にも走り、`bin/brakeman` と `bin/bundler-audit check --update` で新しい advisory を検出する。schedule 実行では deploy しない。
3. gem と GitHub Actions は Dependabot が毎日 PR を出す。Actions は commit SHA で固定する。
4. ローカルで確認するとき:

```sh
export MISE_TRUSTED_CONFIG_PATHS=$PWD; eval "$(mise env -s bash)"
bundle install
bin/brakeman --no-pager -q
bin/bundler-audit check --update
bundle outdated --only-explicit
bin/rails test
SE_CHROME_PATH=/usr/bin/chromium SE_CHROMEDRIVER=/usr/bin/chromedriver bin/rails test:system   # Chrome がない環境
```

## セキュリティヘッダー

- CSP は `config/initializers/content_security_policy.rb`。`script-src 'self' 'nonce-…'` なので、ビューに `<script>` を書くときは `<script nonce="<%= content_security_policy_nonce %>">` にする。付け忘れるとその script は CSP で止まる。`test/integration/security_headers_test.rb` がヘッダーとレイアウトの nonce を、`test/system/admin_navigation_test.rb` がレイアウトと利用者一覧の script が実際に動くことを確認している。
- `style-src` は `'unsafe-inline'` を許可している。ビューが `style=` 属性を使うため。nonce を `style-src` に付けると `'unsafe-inline'` が無効になるので付けない。
- `Permissions-Policy` は `config/application.rb` の `default_headers`。Rails の `permissions_policy` DSL は旧 `Feature-Policy` ヘッダーを出すので使っていない。
- HSTS (`max-age=63072000; includeSubDomains`) は `config.force_ssl` の Rails 既定値。
- `X-Frame-Options: SAMEORIGIN` (Rails 既定) と CSP の `frame-ancestors 'none'` が両方出る。対応ブラウザでは CSP が優先される。
- 反映確認: `curl -sSI https://liberation.showway.biz/ | grep -iE 'content-security|permissions-policy|x-frame|strict-transport'`

## 許容しているリスク・見送り

- ログインなしの CSV に `入力者名` と `備考欄` が含まれる。公開一覧として運用している仕様のため変えていない。
- `config.hosts` (Host ヘッダー検証) は設定していない。前段のリバースプロキシが Host を書き換えるかを確認できておらず、設定すると全リクエストが 403 になるおそれがあるため。メール送信やパスワードリセットのように Host から URL を作る機能はない。
- パスワードログインにレート制限はない。本番は Authentik ログインだけで、パスワードログインは無効になっているため。
- remember me cookie はユーザー ID だけを署名したもので、サーバー側から失効できない。本番の Authentik ログインでは発行しない (`remember_me: false`)。
- ユーザー自身のメールアドレス・パスワード変更に現在のパスワードを求めない。Authentik 運用ではパスワードを使わない。

## 作業履歴

### 2026-10-24

- 依存: `crass` 1.0.7 → 1.0.8 (GHSA-pq4g-8rxf-4g29、CSS サニタイザーのバイパス。`rails-html-sanitizer` 経由)。`sqlite3` 2.9.6 → 2.10.1 (Dependabot PR #37 と同じ)。`bundler-audit` 0.9.3 を追加。`bundle-audit` は 1 件 → 0 件。Brakeman は前後とも警告 0。
- コード:
  - CSV 出力で `= + - @` タブ・CR で始まる文字列に `'` を付ける (数式インジェクション対策)。
  - 挙行予定表と海外超抜の PDF 出力に `rate_limit` (1 分 20 回)。挙行予定表の PDF はログインなしで Cloudflare Browser Rendering を呼べるため。
  - Authentik ログインで、別の Authentik 利用者 (subject) に結び付いたユーザーにメールアドレスだけで結び付けない。
  - PDF Worker で `PDF_TOKEN` が未設定なら 401 を返す (未設定だと `Bearer undefined` で通るため)。本番の Worker は設定済みで、`Bearer undefined` は 401 だった。この修正の Worker への反映は、Worker のある Cloudflare アカウントで `wrangler deploy` が必要。
- ヘッダー: CSP (inline script は nonce)、`Permissions-Policy` を追加。
- GitHub: Actions を commit SHA で固定、`permissions: contents: read`、`persist-credentials: false`、CI の週次実行と `bundler-audit`、deploy のシークレットを Deploy ステップだけに渡す。CodeQL (actions / ruby / javascript-typescript) と Dependency Review を追加。Dependabot alerts (vulnerability-alerts) を有効化。Dependabot security updates は無効のまま。
- 検証: `bin/rails test` 101 件、`test:system` 2 件、rubocop、brakeman が通る。system test は layout の nonce を外すと失敗することを確認した。
