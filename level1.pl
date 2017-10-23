#!/usr/bin/env perl

# Level.1 - Code Challenge 2017 2nd

use v5.24;
use warnings;
use utf8;
use open IO => qw/:encoding(UTF-8) :std/;

use Mojolicious::Lite;
use JSON;

my $item_data = {
  101 => {  name => 'ハンバーガー',         value => '100', category => 'ハンバーガー'  },
  102 => {  name => 'チーズバーガー',       value => '130', category => 'ハンバーガー'  },
  103 => {  name => 'ダブルチーズバーガー', value => '320', category => 'ハンバーガー'  },
  104 => {  name => 'てりやきバーガー',     value => '320', category => 'ハンバーガー'  },
  105 => {  name => 'ビッグバーガー',       value => '380', category => 'ハンバーガー'  },

  201 => {  name => 'ポテトS',              value => '150', category => 'サイドメニュー'  },
  202 => {  name => 'ポテトM',              value => '270', category => 'サイドメニュー'  },
  203 => {  name => 'ポテトL',              value => '320', category => 'サイドメニュー'  },
  204 => {  name => 'サラダ',               value => '280', category => 'サイドメニュー'  },

  301 => {  name => 'コーラS',              value => '100', category => 'ドリンク'  },
  302 => {  name => 'コーラM',              value => '220', category => 'ドリンク'  },
  303 => {  name => 'コーラL',              value => '250', category => 'ドリンク'  },
  304 => {  name => 'オレンジS',            value => '150', category => 'ドリンク'  },
  305 => {  name => 'オレンジM',            value => '240', category => 'ドリンク'  },
  306 => {  name => 'オレンジL',            value => '270', category => 'ドリンク'  },
  307 => {  name => 'ホットコーヒーS',      value => '100', category => 'ドリンク'  },
  308 => {  name => 'ホットコーヒーM',      value => '150', category => 'ドリンク'  },
};

post '/api/checkout' => sub {
  my $self = shift;
  my $req_param = $self->req->json;
  my $orders = $req_param->{order};

  $self->res->headers->header('Content-Type' => 'application/json');

  my $sum = 0;
  for my $order ( @$orders ) {
    if ( not exists $item_data->{$order} ) {
      $self->render( json => +{ ok => JSON::false, message => 'item_not_found' } );
      return;
    }

    $sum += $item_data->{$order}->{value};
  }

  $self->render( json => +{
    ok     => JSON::true,
    amount => $sum,
    items  => $orders,
  });
};

app->start;

