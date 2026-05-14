# M3 おさらい：新規作成でTodoを保存したとき、裏側で何が起きているか

## 全体像

ユーザーがブラウザで `/todos/new` を開いて、フォームに入力し「追加」を押すまでの裏側の流れを、**段階ごと**に追いかける。

---

## 関係する登場人物

| 登場人物 | 場所 | 役割 |
|---|---|---|
| **ブラウザ** | ユーザー側 | URLにアクセスし、フォーム送信する |
| **ルーター（routes.rb）** | `config/routes.rb` | URL を「どのコントローラのどのアクションへ」振り分け |
| **コントローラ** | `app/controllers/todos_controller.rb` | 司令塔。判断と指示 |
| **モデル（Todo）** | `app/models/todo.rb` | データ操作のプロ。SQL生成・バリデーション |
| **ビュー** | `app/views/todos/*.html.erb` | 画面の見た目を描画 |
| **DB（SQLite）** | `storage/development.sqlite3` | 実データの保管場所 |

---

## フェーズ1：フォーム画面を表示する

### ① ブラウザが `/todos/new` にアクセス

ユーザーがブラウザのアドレスバーに `http://localhost:3000/todos/new` を入力する、または「新しいTodoを追加」リンクをクリック。

```
ブラウザ → サーバー：「GET /todos/new」リクエスト
```

### ② ルーターが振り分け

`config/routes.rb` の `resources :todos` から自動生成されたルートテーブルを見て、Rails が判断：

```
GET /todos/new → todos#new に振り分け
```

→ TodosController の `new` アクションが呼ばれる。

### ③ `new` アクションが動く

```ruby
def new
  @todo = Todo.new
end
```

- **`Todo.new`**：メモリ上に「空っぽの新しいTodoオブジェクト」を作る
- **DB には何も書き込まない**（まだ保存しない）
- `@todo` というインスタンス変数に格納（ビューに自動で渡る）

### ④ ビューが描画される

Rails の規約で「アクション名と同じビューを暗黙的に描画」 → `new.html.erb` が選ばれる。

`new.html.erb` の中身：

```erb
<h1>新しいTodoを追加</h1>

<%= render "form" %>

<%= link_to "一覧に戻る", todos_path %>
```

`<%= render "form" %>` で `_form.html.erb`（パーシャル）が展開される。

### ⑤ パーシャル `_form.html.erb` がHTMLを生成

```erb
<%= form_with model: @todo do |form| %>
  ...
  <%= form.text_field :title %>
  <%= form.check_box :completed %>
  <%= form.submit %>
<% end %>
```

`form_with model: @todo` が **`@todo` を見て判定**：

- `@todo.id` が `nil`（=新規Todo）
- だから送信先は **POST /todos**（create アクション宛て）

最終的にブラウザに送られる HTML：

```html
<form action="/todos" method="post">
  <input type="hidden" name="authenticity_token" value="...">   ← CSRFトークン自動生成

  <label for="todo_title">タイトル</label>
  <input type="text" name="todo[title]" value="">

  <input name="todo[completed]" type="hidden" value="0">
  <input type="checkbox" name="todo[completed]" value="1">

  <input type="submit" name="commit" value="Create Todo">
</form>
```

→ ブラウザに**入力フォームが表示**される。

---

## フェーズ2：ユーザーがフォーム送信

### ⑥ ユーザーが入力して「追加」ボタンを押す

- タイトル欄に「散歩する」と入力
- 「追加」ボタンクリック

→ ブラウザは form の `action="/todos"` と `method="post"` を見て、**POSTリクエストを送信**：

```
ブラウザ → サーバー：「POST /todos」
        + 送信データ：
          authenticity_token = "..."
          todo[title] = "散歩する"
          todo[completed] = "0"
          commit = "Create Todo"
```

---

## フェーズ3：サーバー側で保存処理

### ⑦ ルーターが振り分け

```
POST /todos → todos#create に振り分け
```

### ⑧ CSRFトークンの検証（自動）

Rails が `authenticity_token` をチェック：
- このトークンは Rails が**フォーム表示時に自分で発行**したもの
- 第三者の悪意あるサイトから送られたリクエストには付いてない
- 一致しないと拒否（**セキュリティの第一関門**）

通過 → `create` アクションへ。

### ⑨ `create` アクションが動く

```ruby
def create
  @todo = Todo.new(todo_params)
  if @todo.save
    redirect_to todos_path
  else
    render :new, status: :unprocessable_entity
  end
end
```

順番に追う。

### ⑩ Strong Parameters でデータをふるい分け

`todo_params` メソッドが呼ばれる：

```ruby
def todo_params
  params.require(:todo).permit(:title, :completed)
end
```

- `params` には送信された全データが入ってる
  ```ruby
  {
    "authenticity_token" => "...",
    "todo" => { "title" => "散歩する", "completed" => "0" },
    "commit" => "Create Todo"
  }
  ```
- `.require(:todo)` で **`todo` の塊だけ取り出し**
- `.permit(:title, :completed)` で **許可したカラムだけ通す**（他は捨てる）

→ 結果：

```ruby
{ "title" => "散歩する", "completed" => "0" }
```

これが**安全に取り出されたデータ**。攻撃者が `admin: true` などを混ぜても、ここで除外される。

### ⑪ `Todo.new(todo_params)` でメモリ上にTodoを作る

```ruby
@todo = Todo.new(title: "散歩する", completed: "0")
```

- メモリ上にTodoオブジェクトを生成
- 渡された値（title="散歩する"、completed="0"）をセット
- **まだDBには行かない**

### ⑫ `@todo.save` で保存を試みる

ここで実際にDBへの保存が始まる。順番に見る。

#### Step A：バリデーションが走る

モデル（`app/models/todo.rb`）に書かれたルールをチェック：

```ruby
class Todo < ApplicationRecord
  validates :title, presence: true
end
```

- `title` が空っぽじゃないかチェック
- 今回は `title="散歩する"` なので **通過**
- もし空だったら、ここで `save` が `false` を返して終了（DBに行かない）

#### Step B：トランザクション開始

```sql
BEGIN TRANSACTION
```

→ 「これから書き込むよ。途中で失敗したら全部巻き戻すよ」という安全装置をセット。

#### Step C：SQL の INSERT が生成・実行される

ActiveRecord が SQL を組み立てて DB に送る：

```sql
INSERT INTO "todos" ("title", "completed", "created_at", "updated_at")
VALUES ('散歩する', FALSE, '2026-05-12 ...', '2026-05-12 ...')
RETURNING "id"
```

- `title` と `completed` はユーザーが渡した値
- `created_at` と `updated_at` は **ActiveRecord が自動で現在時刻を入れる**
- `RETURNING "id"` で「採番された id を返してね」と DB に頼む

#### Step D：DB がレコードを追加

SQLite が実際に `todos` テーブルに新しい行を追加：

```
todos テーブル：
| id | title       | completed | created_at | updated_at |
|----|-------------|-----------|------------|------------|
| 1  | 牛乳とパン... | true      | ...        | ...        |
| 2  | 公園を散歩... | false     | ...        | ...        |
| 4  | 散歩する     | false     | now()      | now()      |  ← ★ 追加！
```

- DB側で `id` を自動採番（今回は 4）
- 採番された id を Rails に返す

#### Step E：トランザクション確定

```sql
COMMIT TRANSACTION
```

→ 「保存確定。やっぱりナシは無し」。データが永続化される。

#### Step F：`@todo` に id と timestamps が反映される

Rails が DB から返された情報を `@todo` オブジェクトに書き戻す：

```
@todo = #<Todo id: 4, title: "散歩する", completed: false, created_at: "...", updated_at: "...">
```

→ `@todo.save` が **`true` を返す**。

### ⑬ 成功なので redirect_to を実行

```ruby
if @todo.save             # true
  redirect_to todos_path  # ← こっちが実行される
```

Rails が ブラウザに **HTTP 302 レスポンス** を返す：

```
HTTP/1.1 302 Found
Location: http://localhost:3000/todos
```

→ 「ブラウザさん、`/todos` に行ってね」という命令。

---

## フェーズ4：一覧画面に戻って表示

### ⑭ ブラウザが自動で `/todos` を再リクエスト

302 を受け取ったブラウザは、自動的に `GET /todos` をリクエスト。

### ⑮ index アクションが動く

```ruby
def index
  @todos = Todo.all
end
```

- `Todo.all` が走る
- 裏で SQL： `SELECT * FROM todos`
- DBから全件取得（さっき追加した id=4 も含む）
- `@todos` に格納

### ⑯ index.html.erb が描画される

```erb
<ul>
  <% @todos.each do |todo| %>
    <li>
      <%= todo.title %>
      （<%= todo.completed ? "完了" : "未完了" %>）
      ...
    </li>
  <% end %>
</ul>
```

- `@todos` をループして各Todoを `<li>` で表示
- **新しく追加された「散歩する」もここに表示される**

### ⑰ ブラウザに一覧画面が表示

ユーザーから見たら「ボタンを押したらフォーム画面から一覧画面に移動して、新しいTodoが追加された」ように見える。

---

## 全体の流れ図

```
[ユーザー]                                                    [DB]
   |                                                          |
   | 1. GET /todos/new                                        |
   |─────────────────────────────────────→ [Routes]           |
   |                                          |               |
   |                                          | new アクション |
   |                                          |               |
   |                                          | Todo.new      |
   |                                          | （メモリ上）  |
   |                                          |               |
   |                          new.html.erb 描画                |
   | ←─────────────────────────────────────                    |
   |                                                          |
   |（フォーム表示）                                          |
   |                                                          |
   |（ユーザーが入力して「追加」ボタン押す）                  |
   |                                                          |
   | 2. POST /todos + フォームデータ                           |
   |─────────────────────────────────────→ [Routes]           |
   |                                          |               |
   |                                       create アクション   |
   |                                          |               |
   |                                  todo_params で安全化     |
   |                                          |               |
   |                                  Todo.new(...)（メモリ）   |
   |                                          |               |
   |                                       @todo.save         |
   |                                          ↓               |
   |                                  バリデーションOK         |
   |                                          ↓               |
   |                                  BEGIN TRANSACTION       |
   |                                          ↓               |
   |                                  INSERT INTO todos ───────→ 行追加
   |                                          ↓               |
   |                                  COMMIT ──────────────────→ 確定
   |                                          ↓               |
   |                                  302 Found ＋ /todos      |
   | ←──────────────────────────────────────                   |
   |                                                          |
   | 3. GET /todos （自動で）                                  |
   |─────────────────────────────────────→ [Routes]           |
   |                                          |               |
   |                                       index アクション    |
   |                                          |               |
   |                                       Todo.all           |
   |                                          ↓               |
   |                                  SELECT * FROM todos ────→ 全件取得
   |                                          ↓               |
   |                                  index.html.erb 描画      |
   | ←─────────────────────────────────────                    |
   |                                                          |
   |（一覧画面に「散歩する」が表示されてる）                  |
```

---

## サーバーログで実際に見える流れ

```
Started GET "/todos/new" ...
Processing by TodosController#new as HTML
  Rendering todos/new.html.erb within layouts/application
  Rendered todos/_form.html.erb
  Rendered todos/new.html.erb
Completed 200 OK
```

（ここでユーザーがボタンを押す）

```
Started POST "/todos" ...
Processing by TodosController#create as HTML
  Parameters: {"authenticity_token"=>"[FILTERED]", "todo"=>{"title"=>"散歩する", "completed"=>"0"}}
  TRANSACTION (0.0ms)  BEGIN immediate TRANSACTION
  Todo Create (...) INSERT INTO "todos" ("title", "completed", "created_at", "updated_at")
                    VALUES ('散歩する', FALSE, '...', '...') RETURNING "id"
  TRANSACTION (...)  COMMIT TRANSACTION
Redirected to http://localhost:3000/todos
Completed 302 Found
```

（自動でブラウザが `/todos` を取りに行く）

```
Started GET "/todos" ...
Processing by TodosController#index as HTML
  Todo Load (...)  SELECT "todos".* FROM "todos"
  Rendering todos/index.html.erb
Completed 200 OK
```

---

## 主な登場メソッド・キーワード一覧

| メソッド/キーワード | どこで使う？ | 何する？ |
|---|---|---|
| `resources :todos` | routes.rb | 7つの RESTful ルートを一括生成 |
| `Todo.new` | controller (new) | メモリ上に空のTodoを作る（DBに行かない） |
| `Todo.new(todo_params)` | controller (create) | フォームの値でTodoを作る（メモリ上） |
| `@todo.save` | controller (create) | バリデーション → DBに INSERT |
| `params.require(:todo).permit(:title, :completed)` | controller (private) | Strong Parameters。許可カラムだけ通す |
| `validates :title, presence: true` | model | titleが空っぽならsaveを失敗させる |
| `form_with model: @todo` | view | `<form>` を生成。@todoの状態でPOST/PATCH切替 |
| `form.text_field :title` | view | テキスト入力欄を生成 |
| `form.submit` | view | 送信ボタンを生成 |
| `redirect_to todos_path` | controller (create成功) | ブラウザに「/todos に行って」と命令 |
| `render :new, status: :unprocessable_entity` | controller (create失敗) | フォームを再描画。入力値とエラーを保持 |

---

## DBに何が保存されるか（最終結果）

新しいTodoが追加された結果、`todos` テーブルにこんな行が増える：

| id | title | completed | created_at | updated_at |
|---|---|---|---|---|
| 4 | "散歩する" | false | 2026-05-12 ... | 2026-05-12 ... |

- `id`：DB が自動採番
- `title`：ユーザーがフォームに入力した値
- `completed`：チェックボックスの状態（チェック無し → false）
- `created_at` / `updated_at`：ActiveRecord が自動で現在時刻

→ アプリを再起動しても、PCを再起動しても、**このデータは消えない**（永続化）。

---

## 失敗時（titleが空だった場合）

⑫ Step A のバリデーションで `false` が返るパターン。

1. `@todo.save` → `false` を返す
2. `if @todo.save` の **else側**へ
3. `render :new, status: :unprocessable_entity` が実行される
4. **DBにはINSERTが走らない**（ROLLBACKすら不要、トランザクションも開かれない）
5. ブラウザに `new.html.erb` が**もう一度描画されて返る**
6. ただし `@todo` には入力値とエラー情報が残ってる
7. `_form.html.erb` のエラー表示部分がエラーメッセージを表示
8. ユーザーは入力値とエラーを見ながら修正できる

サーバーログ（失敗時）：

```
Started POST "/todos" ...
Processing by TodosController#create as HTML
  Parameters: {... "todo"=>{"title"=>"", ...} ...}
  Rendering todos/new.html.erb         ← フォーム再表示
  Rendered todos/_form.html.erb
Completed 422 Unprocessable Content
  Views: ... | ActiveRecord: 0.0ms (0 queries, 0 cached)   ← ★ DBに一切触れてない
```

`ActiveRecord: 0.0ms (0 queries, 0 cached)` が「**DB操作が起きなかった**証拠」。

---

## 口頭テスト向け 1分要約

「新規Todoを保存する一連の流れは：  

1. ユーザーが `/todos/new` にアクセス → ルーターが `todos#new` に振り分け → `Todo.new` で空オブジェクトを準備 → `new.html.erb` 経由で `_form.html.erb` のフォームを表示。  

2. ユーザーがフォームに入力して送信 → POST /todos → `create` アクションへ。  

3. `create` の中で、Strong Parameters（`params.require(:todo).permit(...)`）でフォーム値を安全に取り出し、`Todo.new(todo_params)` でメモリ上にTodoを作る。`@todo.save` を呼ぶと、モデルのバリデーション（`validates :title, presence: true`）が走り、通過したら ActiveRecord が SQL の INSERT を生成して DB に送る。トランザクション内で実行され、成功すれば COMMIT されてレコードが永続化される。  

4. `@todo.save` が `true` を返すので `redirect_to todos_path` で 302 を返し、ブラウザは自動的に GET /todos を再リクエスト → index アクションが全件取得 → 一覧画面に新しいTodoが表示される。  

5. もしバリデーション失敗（titleが空など）なら、`save` が `false` を返してDBには何も書き込まれず、`render :new` でフォームが再描画される。`@todo` に残った入力値とエラーメッセージが画面に表示される（PRGパターンの『成功→redirect、失敗→render』）」
