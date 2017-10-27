# TL;DR

  - Code Challenge 2017 2nd の Level.2
  - 実行方法
    1. make server_start
    2. make test


# 概要

 Code Challenge 2017 2nd の Level.2 のコードです  
 Gist はディレクトリが push できないため, GitHub にも置いています  
   https://github.com/ks-yuzu/supporterz-code-challenge-2017-2nd


# 依存ファイルについて
- Perl のモジュール
  + deps ディレクトリ内に全て同梱しています
  + うまく動作しない時は, 次のコマンドで依存モジュールをリビルドしてください  
    $ rm -rf deps && ./bin/cpanm --local-lib 'deps' --installdeps .
  
- lp_solve (ソルバ)

    - x86\_64\_linux 用を lp\_solve ディレクトリ内に同梱しています  
    - その他の環境の場合は以下のリンクから DL できます  
      https://sourceforge.net/projects/lpsolve/files/lpsolve/5.5.2.5/


# 実行方法
## 同梱の依存モジュールを使用する場合

1. 圧縮ファイルを解凍 (Gist から取得した場合のみ)
2. サーバの起動
   - $ perl -I './deps/lib/perl5' ./deps/bin/morbo level2.pl        (make server_start でも可)
3. テストの実行
   - $ prove -I './deps/lib/perl5'                                  (普通はこちら. make test でも可)
   - $ for i in $(ls t/*.t); do; perl -I './deps/lib/perl5' $i; done (prove が動かなければこちら)


## 同梱のモジュールを使用しない (CPAN が使える環境の) 場合

1. とりあえず deps は削除
   - $ rm -rf deps
2. 足りないモジュールを入れる
   - $ cpanm --installdeps .
3. 実行
   - $ morbo lelve2.pl
4. テスト
   - $ prove
