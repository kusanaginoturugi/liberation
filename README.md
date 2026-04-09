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

現在は単一聖院モードで運用しているため、管理者メニューには `伝道会一覧` のみ表示されます。複数聖院運用へ戻す設定は [運用マニュアル](./docs/manual.md) に記載しています。

## Development

Rails サーバーの起動:

```bash
mise run server
```

テスト実行:

```bash
mise run test
```

修霊合計数の変更:

```bash
bin/rails 'settings:set_total_serial_count[1700]'
```

詳細は [運用マニュアル](./docs/manual.md) を参照してください。

伝道会マスタの差し替え:

```bash
bin/rails 'meetings:sync[config/meetings.yml]'
```

個別編集は管理画面、一括差し替えは上記 task を使います。

## Environment

- Ruby `3.4.8`
- Bundler gems are installed into `vendor/bundle`
