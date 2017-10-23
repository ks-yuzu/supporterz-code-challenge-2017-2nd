use strict;
use Test2::V0;
use Test2::Plugin::UTF8;

use LWP::UserAgent;
use Path::Tiny;
use JSON;
use DDP;

use FindBin;
$FindBin::Script =~ /^test(.*).t$/ or ok '0', 'invalid test file name';

my $file = $1 . '.json';

my $uri = 'http://localhost:3000/api/checkout';
my $json = path( 't/in' . $file )->slurp;
my $req = HTTP::Request->new( 'POST', $uri );
$req->header( 'Content-Type' => 'application/json' );
$req->content( $json );

my $ua = LWP::UserAgent->new;
my $res = from_json( $ua->request( $req )->content );
my $exp = from_json( path('t/exp' . $file)->slurp );
# p $res;
# p $exp;

is $res, $exp, 'with invalid item';

done_testing;
