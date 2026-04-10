# Liberation

超抜報告を登録する Rails アプリケーションです。

## Setup

`mise` を使う場合は、最初にこのプロジェクトを trust してください。

```bash
mise trust
mise install
mise run setup
```

初期ログイン情報と運用手順は [運用マニュアル](./docs/manual.md) を参照してください。

現在は単一聖院モードで運用しています。複数聖院運用へ戻す設定や注意点は [運用マニュアル](./docs/manual.md) を参照してください。
単一聖院モードから複数聖院モードへの切り替えは、設定変更だけでなく画面運用やデータ前提の見直しも必要になるため、システム更新を前提に検討してください。

## Development

Rails サーバーの起動:

```bash
mise run server
```

テスト実行:

```bash
mise run test
```

伝道会マスタの差し替え:

```bash
bin/rails 'meetings:sync[config/meetings.yml]'
```

個別編集は管理画面、一括差し替えは上記 task を使います。

超抜式の追加:

```bash
bin/rails 'events:create[第74回超抜式]'
```

単一聖院モードでは、`修霊合計数` は管理画面の `超抜式一覧` から対象イベントごとに変更します。

CSV 出力:

- `UTF-8`
- `UTF-8(BOM)`
- `SJIS (Windows-31J)`

いずれも画面上部の `CSV出力` メニューから選択できます。

## Environment

- Ruby `3.4.8`
- Bundler gems are installed into `vendor/bundle`
