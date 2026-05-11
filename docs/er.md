# ER図 — Todoアプリ

## todos テーブル

| カラム名     | 型        | 制約                       | 意味                  |
|-------------|-----------|---------------------------|----------------------|
| **id**      | integer   | PK, 自動採番                | 主キー（一意のID）       |
| title       | string    | NOT NULL                   | タスクのタイトル          |
| completed   | boolean   | default: false, NOT NULL   | 完了したかどうか         |
| created_at  | datetime  | NOT NULL                   | 作成日時（Rails自動）    |
| updated_at  | datetime  | NOT NULL                   | 更新日時（Rails自動）    |

## 図（ASCII）

```
┌──────────────────────────────┐
│ todos                        │
├──────────────────────────────┤
│ [PK] id        : integer     │
│      title     : string      │  NOT NULL
│      completed : boolean     │  default: false, NOT NULL
│      created_at: datetime    │
│      updated_at: datetime    │
└──────────────────────────────┘
```

## 関係（リレーション）

このアプリは現状テーブルが `todos` 1つだけのため、テーブル間の関係はなし。
今後 `users` テーブルなどが増えたら、`todos.user_id` のような外部キー（FK）でつなぐ予定。

## 用語メモ

- **PK（Primary Key、主キー）**: テーブルの中で各レコードを一意に識別するためのカラム。`todos` では `id`。
- **FK（Foreign Key、外部キー）**: 他のテーブルとつなぐためのカラム。今回はなし。
- **NOT NULL**: 「空っぽの値（NULL）を許可しない」という制約。
- **default**: 「指定がなかったときに自動で入る値」。
