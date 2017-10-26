requires 'Mojolicious::Lite';
requires 'DBI';
requires 'List::Util';
requires 'List::MoreUtils';
requires 'JSON';
requires 'Path::Tiny';

on develop => sub {
  requires 'DDP';
}


