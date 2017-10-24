#!/usr/bin/env perl

# Level.2 - Code Challenge 2017 2nd

use v5.24;
use warnings;
use utf8;
use open IO => qw/:encoding(UTF-8) :std/;

use Mojolicious::Lite;
use DBI;
use List::Util qw/sum/;
use JSON;

use DDP;


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
  initialize_db($dbi);

  # 注文とクーポンの ID チェック
  return +{ ok => JSON::false, message => 'item_not_found' }
    unless is_valid_request($dbi, \%orders, \%coupons);

  # 無効クーポンの削除
  delete_unnecessary_coupons($dbi, \%orders, \%coupons);

  # 適用可能なセットと価格差の一覧を作成
  my $available_sets = get_available_set_list($dbi, [keys %orders], [keys %coupons]);
  p $available_sets;
  # TODO: ここ

  # 価格が小さくなるもののみの一覧
  # TODO: == 0 の時はクーポンの数で判定 -> 最適化で？
  $available_sets = [ grep { $_->[4] >= 0 } @$available_sets ];

  # 全セットが適用できるかチェック
  my %cnt = ();
  for my $set ( @{ $available_sets } ) {
    $cnt{ $set->[1] }++;  $cnt{ $set->[2] }++;  $cnt{ $set->[3] }++;
  }

  my $f_applicable_all_sets = ! grep { $orders{$_} < $cnt{$_} } keys %cnt;

  # 最適化 (必要があれば)
  # TODO: == 0 の時はクーポンの数で判定
  if ( not $f_applicable_all_sets ) {
    # TODO: どのセットを適用するか最適化問題を解く
    say STDERR '[error] set optimizeation (unsupported)';
    die "unsupported.";
  }

  # 品目の決定
  for my $set ( @$available_sets ) {
    $orders{ $set->[0] }++;
    $orders{ $set->[1] }--;
    $orders{ $set->[2] }--;
    $orders{ $set->[3] }--;
  }

  # TODO: 合計金額の算出 (DB 側で実行？)
  my $res = get_total_value($dbi, \%orders, \%coupons); # TODO: 命名
  my $amount  = sum map { $_->[1] } @$res;
  my $items   = [ sort map { $_->[0] } @$res ];
  my $coupons = [ sort map { $_->[2] // () } @$res ]; # クーポン欄の undef は削除

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

  # TODO: エラーチェック用に最適化
  my $res = {
    items   => [ map { get_item($dbi, $_)   } keys %$orders  ],
    coupons => [ map { get_coupon($dbi, $_) } keys %$coupons ],
  };

  return not (( grep { !defined } @{$res->{items}} ) || ( grep { !defined } @{$res->{coupons}} ));
}


sub delete_unnecessary_coupons {
  my ($dbi, $orders, $coupons) = @_;
  # TODO: unsupported
}


sub get_available_set_list {
  my ($dbi, $orders, $coupons) = @_;

  my $order_placeholders  = '?,' x scalar @$orders;
  chop $order_placeholders;  # 最後のコンマを削除
  my $coupon_placeholders = '?,' x scalar @$coupons;
  chop $coupon_placeholders; # 最後のコンマを削除

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
    where elm1 in (select id from ordered_items)
      and elm2 in (select id from ordered_items)
      and elm3 in (select id from ordered_items)
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
    available_sets.id,
    available_sets.elm1,
    available_sets.elm2,
    available_sets.elm3,
    values1.value + values2.value + values3.value + sum(enabled_single_coupons.value)
      - available_sets.value as value_without_set_coupons

    from available_sets
      inner join ordered_items as values1 on (available_sets.elm1 = values1.id)
      inner join ordered_items as values2 on (available_sets.elm2 = values2.id)
      inner join ordered_items as values3 on (available_sets.elm3 = values3.id)
      inner join enabled_single_coupons on enabled_single_coupons.target_id in (elm1, elm2, elm3)
    group by
      available_sets.id
)

select
  sets_without_set_coupons.id,
  sets_without_set_coupons.elm1,
  sets_without_set_coupons.elm2,
  sets_without_set_coupons.elm3,
  sets_without_set_coupons.value_without_set_coupons - ifnull(enabled_set_coupons.value, 0)

  from sets_without_set_coupons
    left join enabled_set_coupons on enabled_set_coupons.target_id = sets_without_set_coupons.id
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


####################  for debug  ####################
sub initialize_db {
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
      my $data = require "${table_name}.dat";

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
