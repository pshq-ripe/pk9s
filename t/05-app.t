use strict;
use warnings;
use Test::More tests => 29;
use lib 'lib';

use_ok('pk9s::App');
use_ok('pk9s::Config');
use_ok('pk9s::Resource');

my $app = pk9s::App->new(
    config => pk9s::Config->new(),
    kubectl => bless({}, 'pk9s::Kubectl'),
);
isa_ok($app, 'pk9s::App');

can_ok($app, qw(run _refresh_data _render_table _render_help _switch_view));

is($app->{_current_view}, 0, 'default view is pods');
is($app->{_selected_row}, 0, 'default selection is first row');

is(pk9s::App::colorize_status('Running'), "\e[32mRunning\e[0m", 'colorize Running');
is(pk9s::App::colorize_status('Pending'), "\e[33mPending\e[0m", 'colorize Pending');
is(pk9s::App::colorize_status('Error'), "\e[31mError\e[0m", 'colorize Error');
is(pk9s::App::colorize_status('Succeeded'), "\e[34mSucceeded\e[0m", 'colorize Succeeded');
is(pk9s::App::colorize_status('Unknown'), "\e[37mUnknown\e[0m", 'colorize Unknown');

my @views = pk9s::App::views();
is(scalar @views, 4, 'has 4 views');
is($views[0]{name}, 'pods', 'first view is pods');

# Test _clamp_selection
$app->{_resources} = [1, 2, 3, 4, 5];
$app->{_selected_row} = 10;
$app->_clamp_selection();
is($app->{_selected_row}, 4, 'clamp to max');

$app->{_selected_row} = -5;
$app->_clamp_selection();
is($app->{_selected_row}, 0, 'clamp to min');

# Test _switch_view
$app->{_current_view} = 0;
$app->_switch_view(1);
is($app->{_current_view}, 1, 'switch to next view');

$app->_switch_view(1);
is($app->{_current_view}, 2, 'switch to next view again');

$app->_switch_view(-1);
is($app->{_current_view}, 1, 'switch to previous view');

# Test _refresh_data with mock
package MockKubectl {
    use parent 'pk9s::Kubectl';

    sub _run {
        my ($self, @cmd) = @_;
        return ('{
            "apiVersion": "v1",
            "items": [
                {"metadata": {"name": "test-pod", "namespace": "default", "creationTimestamp": "2024-01-15T10:30:00Z"}, "status": {"phase": "Running", "containerStatuses": [{"ready": 1}]}}
            ]
        }', '');
    }
}

package main;

my $mock_kubectl = MockKubectl->new();
my $app2 = pk9s::App->new(
    config => pk9s::Config->new(),
    kubectl => $mock_kubectl,
);

$app2->_refresh_data();
is(scalar @{$app2->{_resources}}, 1, 'refresh loads resources');
is($app2->{_resources}[0]->name, 'test-pod', 'resource has correct name');

# Test timer setup
is($app2->{_refresh_interval}, 5, 'default refresh interval');

my $app3 = pk9s::App->new(
    config => bless({}, 'pk9s::Config'),
    kubectl => bless({}, 'pk9s::Kubectl'),
    refresh_interval => 10,
);
is($app3->{_refresh_interval}, 10, 'custom refresh interval');

# Test _render_help exists
can_ok($app, '_render_help');

# Test show_help flag
$app->{_show_help} = 0;
is($app->{_show_help}, 0, 'help initially hidden');

# Test search state initialization
is($app->{_search_active}, 0, 'search not active by default');
is($app->{_search_query}, '', 'search query empty by default');
is($app->{_search_regex}, undef, 'search regex undef by default');
is(ref $app->{_filtered_resources}, 'ARRAY', 'filtered resources is array');
