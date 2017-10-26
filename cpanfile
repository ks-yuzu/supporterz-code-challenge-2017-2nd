requires 'Mojolicious::Lite';
requires 'DBI';
requires 'List::Util';
requires 'List::MoreUtils';
requires 'JSON';
requires 'Path::Tiny';

on test => sub {
  requires 'Test2::V0';
};

on develop => sub {
  requires 'DDP';
};


