# TL;DR

  1. make server_start
  2. make test


# 概要

 Code Challenge 2017 2nd の Level.2 のコードです.
 Gist はディレクトリが push できないため, GitHub にも置いています.
   https://github.com/ks-yuzu/supporterz-code-challenge-2017-2nd


# 依存ファイルについて
- Perl のモジュール
  
    lib ディレクトリ内に全て同梱しています.
  
- lp_solve (ソルバ)

    lp_solve ディレクトリ内に同梱しています.


# 実行方法
## Gist から取得した場合

1. 圧縮ファイルを解凍 (ディレクトリが push できないため)
2. サーバの起動
   - $ bin/morbo level2.pl  (make server_start でも可)
3. テストの実行
   - $ prove -Ilib                                  (普通はこちら. make test でも可)
   - $ for i in `ls t/*.t`; do; perl -Ilib $i; done (prove が動かなければこちら)

## GitHub から取得した場合

1. サーバの起動
   - $ bin/morbo level2.pl  (make server_start でも可)
2. (作成した) テストの実行4. 
   - $ prove -Ilib                                  (普通はこちら. make test でも可)
   - $ for i in `ls t/*.t`; do; perl -Ilib $i; done (prove が動かなければこちら)
