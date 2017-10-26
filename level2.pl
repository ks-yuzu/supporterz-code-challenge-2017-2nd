#!/usr/bin/env perl

# Level.2 - Code Challenge 2017 2nd
#   The repository containing all files including DB data and tests is here:
#   https://github.com/ks-yuzu/supporterz-code-challenge-2017-2nd

use v5.24;
use warnings;
use utf8;
use open IO => qw/:encoding(UTF-8) :std/;

use lib './lib';

use Mojolicious::Lite;
use DBI;
use List::Util qw/sum first/;
use List::MoreUtils qw/pairwise/;
use JSON;
use Path::Tiny;


post '/api/checkout' => sub {
  my $self = shift;
  my $req_param = $self->req->json;

  my $response = process_req( $req_param );

  $self->res->headers->header('Content-Type' => 'application/json');
  $self->render( json => $response );
};

app->start;


sub get_item {
  my ($dbi, $id) = @_;
  my $sth = $dbi->prepare( "select value from items where id=?" );
  $sth->execute( $id );
  my $res = $sth->fetch;
  return defined $res ? $res->[0] : undef;
}


sub get_coupon {
  my ($dbi, $id) = @_;
  my $sth = $dbi->prepare( "select value from coupons where id=?" );
  $sth->execute( $id );
  my $res = $sth->fetch;
  return defined $res ? $res->[0] : undef;
}


sub process_req {
  my $req_param = shift;
  my %orders  = ();  $orders{$_}++  for @{ $req_param->{order}  };
  my %coupons = ();  $coupons{$_}++ for @{ $req_param->{coupon} };

  # データベース
  my $dbi = DBI->connect("dbi:SQLite:dbname=scc_lv2.sqlite");
  create_db($dbi);                      # 無ければ作成される

  # 注文とクーポン ID の有効性チェック
  return +{ ok => JSON::false, message => 'item_not_found' }
    unless is_valid_request($dbi, \%orders, \%coupons);

  # 最適なメニューおよびの組合せを求める
  optimize_orders_and_coupons($dbi, \%orders, \%coupons);

  # 合計金額および明細の算出
  my $details = get_total_value($dbi, \%orders, \%coupons);
  my $amount  = sum map { $_->[1] } @$details;
  my $items   = [ sort map { $_->[0] } @$details ];
  my $coupons = [ sort map { $_->[2] // () } @$details ]; # undef なら削除

  $dbi->disconnect;

  return +{
    ok     => JSON::true,
    amount => $amount,
    item   => $items,
    (@$coupons ? (coupon => $coupons) : ())
  };
}


sub is_valid_request {
  my ($dbi, $orders, $coupons) = @_;

  my $res = {
    items   => [ map { get_item($dbi, $_)   } keys %$orders  ],
    coupons => [ map { get_coupon($dbi, $_) } keys %$coupons ],
  };

  return not (( grep { !defined } @{$res->{items}} ) || ( grep { !defined } @{$res->{coupons}} ));
}


sub optimize_orders_and_coupons {
  my ($dbi, $orders, $coupons) = @_;

  # 適用可能なセットを抽出
  # (セットID, セット要素1 ID, セット要素2 ID, セット要素3 ID, 価格減少, クーポン使用数減少を返す)
  my $available_sets = get_available_set_list($dbi, [keys %$orders], [keys %$coupons]);

  # (クーポンを考慮して) 価格が小さくなるセットのみ抽出
  # 価格が同じ場合は, クーポンの使用枚数が少なくなるセットのみ抽出
  $available_sets = [ grep { $_->[4] >= 0 || ($_->[4] == 0 && $_->[5] > 0) } @$available_sets ];

  # どのセットを適用するか最適化問題を解く
  # 各セットの [6] に, そのセットの適用数が格納される
  $available_sets = optimize_set_menu($orders, $coupons, $available_sets);

  # 品目の決定 (単品を減らして, セットを増やす)
  for my $set ( @$available_sets ) {
    my $num_set = $set->[6];
    $orders->{ $set->[0] } += $num_set;
    $orders->{ $set->[1] } -= $num_set;
    $orders->{ $set->[2] } -= $num_set;
    $orders->{ $set->[3] } -= $num_set;
  }
}


sub get_available_set_list {
  my ($dbi, $orders, $coupons) = @_;

  my $order_placeholders  = join( ',',  ('?') x scalar @$orders );
  my $coupon_placeholders = join( ',',  ('?') x scalar @$coupons );

  my $st = $dbi->prepare( <<EOF
with
ordered_items as (
  select id, value from items where id in ($order_placeholders)
),

used_coupons as (
  select * from coupons where id in ($coupon_placeholders)
),

available_sets as (
  select * from sets
    where elm1 in (select id from ordered_items) -- セットの要素の ID
      and elm2 in (select id from ordered_items) -- セットの要素の ID
      and elm3 in (select id from ordered_items) -- セットの要素の ID
),

enabled_single_coupons as (
  select * from coupons
    where id in (select id from used_coupons)
      and target_id in (select id from ordered_items)
),

enabled_set_coupons as (
  select * from coupons
    where id in (select id from used_coupons)
      and target_id in (select id from available_sets)
),

sets_without_set_coupons as (
  select
    available_sets.id,                  -- セットの ID
    available_sets.elm1,
    available_sets.elm2,
    available_sets.elm3,
    values1.value + values2.value + values3.value
      + ifnull(sum(enabled_single_coupons.value), 0)
      - available_sets.value
      as value_without_set_coupons,     -- セット用クーポン抜きの合計金額
    count(enabled_single_coupons.value)
      as coupon_num_without_set_coupons -- 単品の場合に使用するクーポンの枚数

    from available_sets
      inner join ordered_items as values1 on (available_sets.elm1 = values1.id)
      inner join ordered_items as values2 on (available_sets.elm2 = values2.id)
      inner join ordered_items as values3 on (available_sets.elm3 = values3.id)
      left  join enabled_single_coupons on enabled_single_coupons.target_id in (elm1, elm2, elm3)
    group by
      available_sets.elm1, available_sets.elm2, available_sets.elm3
)

select
  sets_without_set_coupons.id,
  sets_without_set_coupons.elm1,
  sets_without_set_coupons.elm2,
  sets_without_set_coupons.elm3,
  -- セットを適用することで何円安くなるか
  sets_without_set_coupons.value_without_set_coupons - ifnull(enabled_set_coupons.value, 0),
  -- 使用するクーポンが何枚減るか
  sets_without_set_coupons.coupon_num_without_set_coupons - count(enabled_set_coupons.value)

  from sets_without_set_coupons
    left join enabled_set_coupons on enabled_set_coupons.target_id = sets_without_set_coupons.id

  group by                      -- count でまとめない
    sets_without_set_coupons.elm1, sets_without_set_coupons.elm2, sets_without_set_coupons.elm3
;
EOF
  );

  $st->execute( @$orders, @$coupons );

  my $res = $st->fetchall_arrayref;
  return $res;
}


sub get_total_value {
  my ($dbi, $orders, $coupons) = @_;

  my @arg_orders  = map { ($_) x $orders->{$_} } keys %$orders;
  my @arg_coupons = keys %$coupons;

  my $order_placeholders  = '?,' x scalar @arg_orders;
  chop $order_placeholders;  # 最後のコンマを削除
  my $coupon_placeholders = '?,' x scalar @arg_coupons;
  chop $coupon_placeholders; # 最後のコンマを削除

  my $st = $dbi->prepare( <<EOF
with
enabled_coupons as (
  select * from coupons where id in ($coupon_placeholders)
)

select -- ID, クーポン適用単価, 有効クーポンID
  items.id,
  items.value + ifnull(enabled_coupons.value, 0),
  enabled_coupons.id

  from items
    left join enabled_coupons on (items.id = enabled_coupons.target_id)

  where items.id in ($order_placeholders)
;
EOF
  );

  $st->execute( @arg_coupons, @arg_orders );  # 引数順注意
  my $res = $st->fetchall_arrayref;

  return $res;
}


sub optimize_set_menu {
  # 今回のセットの組合せ上, greedy に選択しても問題はないと考えられるが,
  # セットパターンの増加を考慮して整数線形計画問題を解く
  # (実行にはソルバ 'lp_solve' が必要)

  my ($orders, $coupons, $available_sets) = @_;

  path('./opt.lp')->spew(
    make_lp_file($orders, $coupons, $available_sets)
  );

  die "command not found: lp_solve" if not -f 'lp_solve/lp_solve';

  # lp_solve を利用して解く
  my $res_opt = qx|lp_solve/lp_solve opt.lp|;
  my %assign = ($res_opt =~ m/assign_(\d+).*?(\d+)/g);      # 出力のパース
  $assign{$_} == 0 and delete $assign{$_} for keys %assign; # 適用しないセットの削除

  # assign されているもののみ抽出
  my @best_selected_sets;
  for my $set_id ( keys %assign ) {
    my $tmp = $available_sets->[$set_id];
    push @$tmp, $assign{$set_id};
    push @best_selected_sets, $tmp;
  }

  return \@best_selected_sets;
}


sub make_lp_file {
  my ($orders, $coupons, $available_sets) = @_;

  my @lp = ();

  # [ 評価式 ]
  push @lp, 'max:';
  # 価格の低下量 (クーポンよりも優先するため, 1000倍して評価)
  while ( my ($idx, $set) = each @$available_sets ) {
    push @lp, (sprintf '  + %5d000  assign_%05d', $set->[4], $idx);
  }
  # クーポン使用数の低下量
  while ( my ($idx, $set) = each @$available_sets ) {
    push @lp, (sprintf '  + %7d  assign_%05d', $set->[5], $idx);
  }
  push @lp, ';';
  push @lp, "\n";


  # [ 制約条件 ]
  # セット要素の個数
  my %necessary_items = map { $_->[1] => 1, $_->[2] => 1, $_->[3] => 1 } @$available_sets;
  for my $item_id ( sort keys %necessary_items ) {
    push @lp, "st_${item_id}:";
    while ( my ($idx, $set) = each @$available_sets ) {
      push @lp, (sprintf '  + assign_%05d', $idx)
        if $set->[1] == $item_id || $set->[2] == $item_id || $set->[3] == $item_id;
    }
    push @lp, '  <= ' . $orders->{$item_id};
    push @lp, ';';
    push @lp, "\n";
  }

  # 整数制約
  for my $idx ( 0 .. $#$available_sets ) {
    push @lp, (sprintf 'int assign_%05d;', $idx);
  }
  push @lp, "\n";

  return (join "\n", @lp);
}

####################  for debug  ####################
sub create_db {
  my $dbi = shift;
  my %tables_info = (
    items   => ['id', 'category', 'name', 'value'],
    coupons => ['id', 'target_id', 'value'],
    sets    => ['id', 'elm1', 'elm2', 'elm3', 'value'],
  );

  for my $table_name ( keys %tables_info ) {
    my $s = $dbi->prepare(
      "select count(*) from sqlite_master where type='table' and name='$table_name';"
    );
    $s->execute;
    my $f_exists = $s->fetch->[0];

    if ( not $f_exists ) {
      say STDERR "Initialize table $table_name";
      my $data = require "dat/${table_name}.dat";

      my $columns_str = join ',', @{ $tables_info{$table_name} };
      my $holder_str  = join ',', map {'?'} @{ $tables_info{$table_name} };
      say  "create table $table_name ($columns_str)" ;
      $dbi->do( "create table $table_name ($columns_str)" );
      my $sth = $dbi->prepare( "insert into $table_name ($columns_str) values ($holder_str);" );
      for my $row ( @$data ) {
        $sth->execute( @$row );
      }
    }
  }
}
