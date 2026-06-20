use strict;
use warnings;
use Test::More tests => 5;
use lib 'lib';

use_ok('pk9s::App');

my $app = pk9s::App->new(
    config => bless({}, 'pk9s::Config'),
    kubectl => bless({}, 'pk9s::Kubectl'),
);
isa_ok($app, 'pk9s::App');

can_ok($app, qw(run _refresh_data _render_table _render_help _switch_view));

is($app->{_current_view}, 0, 'default view is pods');
is($app->{_selected_row}, 0, 'default selection is first row');
