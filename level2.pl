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
  my @orders  = @{ $req_param->{order}  };
  my @coupons = @{ $req_param->{coupon} };

  # データベース
  my $dbi = DBI->connect("dbi:SQLite:dbname=scc_lv2.sqlite");
  initialize_db($dbi);
  my $res = {
    items   => [ map { get_item($dbi, $_)   } @orders ],
    coupons => [ map { get_coupon($dbi, $_) } @coupons],
  };

  # TODO: エラーチェック用に最適化
  # エラー処理
  return +{ ok => JSON::false, message => 'item_not_found' }
    if ( grep { not defined $_ } @{$res->{items}} ) || ( grep { not defined $_ } @{$res->{coupons}} );

  get_available_set_list($dbi, \@orders, \@coupons);

  # 適用可能なセットと価格差の一覧を作成
    # 全セット取得
    # 価格が小さくなるもののみの一覧
    # 最適化

  $dbi->disconnect;

  # 合計額の算出 → DB 側でさせる？？？
  my $amount = sum @{ $res->{items} };
  return +{
    ok     => JSON::true,
    amount => $amount,
    item   => \@orders,
  };
}


sub get_available_set_list {
  my ($dbi, $orders, $coupons) = @_;

  my $placeholders = '?,' x scalar @$orders;
  chop $placeholders;                   # 最後のコンマを削除

  my $st = $dbi->prepare( <<EOF
    select * from sets
      where elm1 in ($placeholders)
        and elm2 in ($placeholders)
        and elm3 in ($placeholders);
EOF
);

  $st->execute( @$orders, @$orders, @$orders );

  my $res = $st->fetchall_arrayref;
  p $res;
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
