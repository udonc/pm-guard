# pm-guard — もう「間違えて `npm install`」しない

<p align="center">[ <a href="./README.md">English</a> | <a href="./README.ja.md">日本語</a> ]</p>

Claude が間違ったパッケージマネージャーを使うのを未然に防ぐ [Claude Code](https://docs.anthropic.com/ja/docs/claude-code) プラグイン。

## 機能

- npm, yarn, pnpm, bun, deno に対応（`npx`, `pnpx`, `bunx` も含む）
- 環境変数、`package.json`、ロックファイルからプロジェクトのパッケージマネージャーを自動検出
- `PreToolUse` フックでコマンド実行前にブロック
- 依存ゼロ — 純粋な bash スクリプト、jq も node も不要

## クイックスタート

1. マーケットプレイスを追加:

   ```
   /plugin marketplace add udonc/pm-guard
   ```

2. プラグインをインストール:

   ```
   /plugin install pm-guard@pm-guard
   ```

3. これだけ。pm-guard がロックファイルや `package.json` からパッケージマネージャーを自動検出するので、設定不要。

Claude が間違ったパッケージマネージャーを使おうとすると、ブロックされます:

> This project uses pnpm. Use pnpm commands instead of npm.

## 設定

許可するパッケージマネージャーは以下の優先順位で決まります:

### 1. `PM_GUARD_ALLOWED` 環境変数（最優先）

```bash
PM_GUARD_ALLOWED=pnpm claude
```

### 2. `package.json` の `packageManager` フィールド

```json
{
  "packageManager": "pnpm@9.15.4"
}
```

バージョン部分は無視され、名前だけが使われます。

### 3. ロックファイル検出（最低優先）

| ロックファイル | 検出される PM |
|---|---|
| `pnpm-lock.yaml` | pnpm |
| `yarn.lock` | yarn |
| `package-lock.json` | npm |
| `bun.lock` / `bun.lockb` | bun |
| `deno.lock` | deno |

## 仕組み

pm-guard は `Bash` ツールの `PreToolUse` フックとして動作します。Claude がシェルコマンドを実行しようとすると、フックが次の処理を行います:

1. ツール入力の JSON からコマンドを抽出
2. 許可されたパッケージマネージャーを特定（[設定](#設定)を参照）
3. 単語境界を考慮した正規表現で許可されていないパッケージマネージャーの呼び出しをチェック（`pnpm-lock.yaml` や `.npm/` などの誤検出を防止）
4. 違反があれば `deny` でブロック、なければそのまま実行を許可

パッケージマネージャーを検出できない場合は、警告を出してコマンドの実行を許可します。

## トラブルシューティング

| 問題 | 原因 | 解決策 |
|---|---|---|
| "Could not detect the project's package manager" 警告が出る | ロックファイルがない、`packageManager` フィールドがない、`PM_GUARD_ALLOWED` が未設定 | ロックファイルを追加するか、`package.json` に `packageManager` を設定するか、`PM_GUARD_ALLOWED` を設定する |
| 正しいコマンドがブロックされる | PM の検出が誤っている（例: 別の PM の古いロックファイルが残っている） | 古いロックファイルを削除するか、`PM_GUARD_ALLOWED` で上書きする |
| プラグインが動作しない | インストールされていない、またはロードされていない | `/plugin list` でpm-guard がインストールされているか確認する |

## 開発

```bash
# プラグインをローカルでテスト
claude --plugin-dir ./plugins/pm-guard

# モック入力で check-pm.sh を直接実行
echo '{"tool_input":{"command":"npm install foo"}}' | PM_GUARD_ALLOWED=pnpm ./plugins/pm-guard/hooks/check-pm.sh
```

ビルドステップなし。外部依存のない POSIX 互換 bash で書くこと。

## ライセンス

MIT
