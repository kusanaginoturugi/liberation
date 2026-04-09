# 運用マニュアル

## 修霊合計数の変更

修霊合計数は `system_settings` テーブルの `total_serial_count` で管理しています。
変更すると、超抜報告画面の使用修霊番号グリッドの表示件数も変わります。

### 変更コマンド

```bash
bin/rails 'settings:set_total_serial_count[1700]'
```

`1700` の部分を変更したい件数に置き換えてください。

### 実行例

```bash
bin/rails 'settings:set_total_serial_count[1800]'
```

成功すると以下のように表示されます。

```text
Updated total_serial_count to 1800
```

### 反映確認

現在値を確認するには次を実行します。

```bash
bin/rails runner 'puts SystemSetting.total_serial_count'
```

### 注意事項

- 0 以下の値は設定できません
- コマンド実行後は画面を再読み込みして表示を確認してください
- 本番環境で実行する場合は、対象環境のアプリケーションディレクトリで実行してください

## ログイン

初回セットアップ後は seed で初期ユーザーが作成されます。

### 初期ユーザー

- メールアドレス: `admin@example.com`
- パスワード: `password123`
- 聖院: `共通`

### 初期ユーザーの作成

DB 作成後または初期化後に次を実行します。

```bash
bin/rails db:seed
```

### ログイン手順

1. ブラウザでログイン画面を開きます
2. メールアドレスに `admin@example.com` を入力します
3. パスワードに `password123` を入力します
4. ログイン後、超抜報告画面へ移動します

### パスワード変更方法

運用開始前に初期パスワードを変更してください。

```bash
bin/rails runner 'user = User.find_by!(email: "admin@example.com"); user.update!(password: "new-password-123", password_confirmation: "new-password-123")'
```

### 注意事項

- seed は初期ユーザーが存在しない場合のみパスワードを設定します
- 既存ユーザーに対して `db:seed` を再実行しても、パスワードは上書きしません
- 本番環境では初期パスワードのまま運用しないでください

## 伝道会マスタの差し替え

伝道会マスタは `config/meetings.yml` で管理できます。
差し替え時は既存データを物理削除せず、YAML にない伝道会を `active: false` にします。
そのため過去の超抜報告データは壊れません。

### 変更ファイル

`config/meetings.yml`

```yml
meetings:
  - name: 大江戸
    color_code: "#C8C4C1"
    display_order: 10
    active: true
```

### 使い方

1. `config/meetings.yml` を編集します
2. `meetings` 配列に必要な伝道会を定義します
3. `display_order` で表示順を指定します
4. `active: true` にするとフォームで選択可能になります
5. `active: false` にするとフォームでは選べなくなります
6. 編集後に同期コマンドを実行します

### 同期コマンド

```bash
bin/rails 'meetings:sync[config/meetings.yml]'
```

成功すると以下のように表示されます。

```text
Synced 9 evangelism meetings from config/meetings.yml
```

### 実行例

`札幌` を追加する例:

```yml
meetings:
  - name: 大江戸
    color_code: "#C8C4C1"
    display_order: 10
    active: true
  - name: 札幌
    color_code: "#B9D7EA"
    display_order: 100
    active: true
```

その後、以下を実行します。

```bash
bin/rails 'meetings:sync[config/meetings.yml]'
```

### 一時的に選択不可にする方法

過去データは残したまま、新規入力だけで選べなくしたい場合は `active: false` にします。

```yml
- name: 山梨
  color_code: "#C2B0D9"
  display_order: 90
  active: false
```

### 反映確認

現在の伝道会一覧を確認するには次を実行します。

```bash
bin/rails runner 'pp EvangelismMeeting.order(:display_order, :id).pluck(:name, :active, :display_order)'
```

### 反映ルール

- 同じ `name` の伝道会は更新
- 新しい `name` は追加
- YAML から消えた伝道会は削除せず `active: false`
- フォームのプルダウンには `active: true` の伝道会だけ表示
- 凡例には過去データ確認用として非アクティブな伝道会も表示
