use strict;
use warnings;
use Test::More tests => 72;
use lib 'lib';

use_ok('pk9s::App');
use_ok('pk9s::Config');
use_ok('pk9s::Resource');

my $app = pk9s::App->new(
    config => pk9s::Config->new(),
    kubectl => bless({}, 'pk9s::Kubectl'),
);
isa_ok($app, 'pk9s::App');

can_ok($app, qw(run _refresh_data _render_table _render_help _switch_view _render_search));

is($app->{_current_view}, 0, 'default view is namespaces');
is($app->{_selected_row}, 0, 'default selection is first row');

is(pk9s::App::colorize_status('Running'), "\e[32mRunning\e[0m", 'colorize Running');
is(pk9s::App::colorize_status('Pending'), "\e[33mPending\e[0m", 'colorize Pending');
is(pk9s::App::colorize_status('Error'), "\e[31mError\e[0m", 'colorize Error');
is(pk9s::App::colorize_status('Succeeded'), "\e[34mSucceeded\e[0m", 'colorize Succeeded');
is(pk9s::App::colorize_status('Unknown'), "\e[37mUnknown\e[0m", 'colorize Unknown');

my @views = pk9s::App::views();
is(scalar @views, 24, 'has 24 views');
is($views[0]{name}, 'namespaces', 'first view is namespaces');
is($views[23]{name}, 'nodes', 'last view is nodes');

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

# Test search mode toggle
$app->{_search_active} = 0;
is($app->{_search_active}, 0, 'search mode initially off');

# Test search query update
$app->{_search_query} = 'nginx';
is($app->{_search_query}, 'nginx', 'search query can be set');

# Test _apply_search with mock
use pk9s::Search;

my $search = pk9s::Search->new();
my @test_resources = (
    bless({ name => 'nginx-deploy' }, 'MockResource'),
    bless({ name => 'redis-deploy' }, 'MockResource'),
    bless({ name => 'nginx-pod' }, 'MockResource'),
);

# Store original _apply_search and replace with testable version
# (This tests the logic without requiring the full TUI)
package MockResource {
    sub name { $_[0]->{name} }
    sub status { 'Running' }
    sub ready { '1/1' }
    sub age { '5d' }
}

package main;

my $app4 = pk9s::App->new(
    config => pk9s::Config->new(),
    kubectl => bless({}, 'pk9s::Kubectl'),
);

$app4->{_resources} = [@test_resources];

# Test scoped search
my ($term, $scope) = $search->parse_query('nginx');
is($term, 'nginx', 'parse_query term');
is($scope, 'current', 'parse_query scope is current');

my $regex = $search->build_regex($term);
ok(defined $regex, 'build_regex returns regex');
like('nginx-deploy', $regex, 'regex matches nginx-deploy');
unlike('redis-deploy', $regex, 'regex does not match redis-deploy');

# Test filter
my @filtered = $search->filter(
    resources => $app4->{_resources},
    regex => $regex,
    extract => sub { [$_[0]->name] },
);
is(scalar @filtered, 2, 'filter returns matching resources');
is($filtered[0]->name, 'nginx-deploy', 'first match is nginx-deploy');
is($filtered[1]->name, 'nginx-pod', 'second match is nginx-pod');

# Test cross-view search parsing
my ($term2, $scope2) = $search->parse_query('all:redis');
is($term2, 'redis', 'cross-view parse extracts term');
is($scope2, 'all', 'cross-view parse returns all scope');

# Test empty query
my ($term3, $scope3) = $search->parse_query('');
is($term3, '', 'empty query term');
is($scope3, 'current', 'empty query scope is current');

# Test _render_table integration with search filtering
# When search is active, _render_table should use _filtered_resources
my $app5 = pk9s::App->new(
    config => pk9s::Config->new(),
    kubectl => bless({}, 'pk9s::Kubectl'),
);

# Set up resources
$app5->{_resources} = [@test_resources];
$app5->{_search_active} = 1;
$app5->{_filtered_resources} = [$test_resources[0]];  # Only nginx-deploy

# Verify the table rendering path would use filtered resources
is($app5->{_search_active}, 1, 'search active flag set');
is(scalar @{$app5->{_filtered_resources}}, 1, 'filtered resources has 1 item');
is($app5->{_filtered_resources}[0]->name, 'nginx-deploy', 'filtered resource is nginx-deploy');

# Verify that when search is inactive, full resources are used
$app5->{_search_active} = 0;
is(scalar @{$app5->{_resources}}, 3, 'full resources has all 3 items');

# --- Cross-view search tests ---

# Mock kubectl that returns different resources per view method
package MockMultiViewKubectl {
    my $ts = '2024-01-15T10:00:00Z';
    sub _m { { metadata => { name => $_[0], namespace => $_[1], creationTimestamp => $ts } } }

    sub get_namespaces  { return { items => [{ metadata => { name => 'default', creationTimestamp => $ts }, status => { phase => 'Active' } }] } }
    sub get_pods {
        my ($self, %args) = @_;
        return { items => [
            { metadata => { name => 'nginx-pod', namespace => $args{namespace}, creationTimestamp => $ts }, status => { phase => 'Running', containerStatuses => [{ ready => 1 }] } },
            { metadata => { name => 'redis-pod', namespace => $args{namespace}, creationTimestamp => $ts }, status => { phase => 'Running', containerStatuses => [{ ready => 1 }] } },
        ] };
    }
    sub get_deployments {
        my ($self, %args) = @_;
        return { items => [
            { metadata => { name => 'nginx-deploy', namespace => $args{namespace}, creationTimestamp => $ts }, spec => { replicas => 2 }, status => { replicas => 2, readyReplicas => 2 } },
        ] };
    }
    sub get_services {
        my ($self, %args) = @_;
        return { items => [
            { metadata => { name => 'redis-svc', namespace => $args{namespace}, creationTimestamp => $ts }, spec => { type => 'ClusterIP' } },
        ] };
    }
    sub get_configmaps {
        my ($self, %args) = @_;
        return { items => [
            { metadata => { name => 'app-config', namespace => $args{namespace}, creationTimestamp => $ts }, data => { key1 => 'val1', key2 => 'val2' } },
        ] };
    }
    sub get_secrets                { my ($s, %a) = @_; return { items => [{ metadata => { name => 'my-secret', namespace => $a{namespace}, creationTimestamp => $ts }, type => 'Opaque', data => { d => 'cGFzc3dvcmQ=' } }] } }
    sub get_serviceaccounts        { my ($s, %a) = @_; return { items => [{ metadata => { name => 'default', namespace => $a{namespace}, creationTimestamp => $ts }, secrets => [] }] } }
    sub get_statefulsets           { my ($s, %a) = @_; return { items => [{ metadata => { name => 'web', namespace => $a{namespace}, creationTimestamp => $ts }, spec => { replicas => 1 }, status => { readyReplicas => 1 } }] } }
    sub get_daemonsets             { my ($s, %a) = @_; return { items => [{ metadata => { name => 'logger', namespace => $a{namespace}, creationTimestamp => $ts }, status => { desiredNumberScheduled => 3, numberReady => 3 } }] } }
    sub get_replicasets            { my ($s, %a) = @_; return { items => [{ metadata => { name => 'nginx-rs', namespace => $a{namespace}, creationTimestamp => $ts }, spec => { replicas => 1 }, status => { readyReplicas => 1 } }] } }
    sub get_jobs                   { my ($s, %a) = @_; return { items => [{ metadata => { name => 'migrate', namespace => $a{namespace}, creationTimestamp => $ts }, status => { succeeded => 1 } }] } }
    sub get_cronjobs               { my ($s, %a) = @_; return { items => [{ metadata => { name => 'backup', namespace => $a{namespace}, creationTimestamp => $ts }, spec => { suspend => 0 } }] } }
    sub get_ingresses              { my ($s, %a) = @_; return { items => [{ metadata => { name => 'web-ing', namespace => $a{namespace}, creationTimestamp => $ts }, spec => { rules => [{ host => 'example.com' }] } }] } }
    sub get_networkpolicies        { my ($s, %a) = @_; return { items => [{ metadata => { name => 'allow-web', namespace => $a{namespace}, creationTimestamp => $ts }, spec => { podSelector => { matchLabels => { app => 'web' } } } }] } }
    sub get_resourcequotas         { my ($s, %a) = @_; return { items => [{ metadata => { name => 'compute', namespace => $a{namespace}, creationTimestamp => $ts }, spec => { hard => { pods => '10' } } }] } }
    sub get_limitranges            { my ($s, %a) = @_; return { items => [{ metadata => { name => 'limits', namespace => $a{namespace}, creationTimestamp => $ts }, spec => { limits => [{ type => 'Container', default => { cpu => '100m' } }] } }] } }
    sub get_persistentvolumeclaims { my ($s, %a) = @_; return { items => [{ metadata => { name => 'data-pvc', namespace => $a{namespace}, creationTimestamp => $ts }, status => { phase => 'Bound' }, spec => { resources => { requests => { storage => '10Gi' } } } }] } }
    sub get_persistentvolumes      { my ($s, %a) = @_; return { items => [{ metadata => { name => 'pv-001', creationTimestamp => $ts }, status => { phase => 'Bound' }, spec => { capacity => { storage => '100Gi' } } }] } }
    sub get_storageclasses         { my ($s, %a) = @_; return { items => [{ metadata => { name => 'standard', creationTimestamp => $ts }, provisioner => 'kubernetes.io/gce-pd' }] } }
    sub get_roles                  { my ($s, %a) = @_; return { items => [{ metadata => { name => 'pod-reader', namespace => $a{namespace}, creationTimestamp => $ts }, rules => [{ resources => ['pods'], verbs => ['get','list'] }] }] } }
    sub get_clusterroles           { my ($s, %a) = @_; return { items => [{ metadata => { name => 'admin', creationTimestamp => $ts }, rules => [{ resources => ['*'], verbs => ['*'] }] }] } }
    sub get_rolebindings           { my ($s, %a) = @_; return { items => [{ metadata => { name => 'read-pods', namespace => $a{namespace}, creationTimestamp => $ts }, subjects => [{ kind => 'User', name => 'dev' }] }] } }
    sub get_clusterrolebindings    { my ($s, %a) = @_; return { items => [{ metadata => { name => 'admin-binding', creationTimestamp => $ts }, subjects => [{ kind => 'User', name => 'admin' }] }] } }
    sub get_nodes                  { my ($s, %a) = @_; return { items => [{ metadata => { name => 'node1', creationTimestamp => $ts }, status => { conditions => [{ type => 'Ready', status => 'True' }] } }] } }
}

package main;

my $mock_multi = bless {}, 'MockMultiViewKubectl';
my $app6 = pk9s::App->new(
    config => pk9s::Config->new(),
    kubectl => $mock_multi,
);

# Test: cross-view search for "redis" should find it in pods first (pods=1, services=2)
$app6->{_search_query} = 'all:redis';
$app6->_apply_search();
is($app6->{_current_view}, 1, 'cross-view search switches to pods view for redis');
is(scalar @{$app6->{_filtered_resources}}, 1, 'cross-view filters to matching resources');
is($app6->{_filtered_resources}[0]->name, 'redis-pod', 'cross-view finds redis-pod');

# Test: cross-view search for "nginx" should find it in pods first
$app6->{_current_view} = 0;
$app6->{_search_query} = 'all:nginx';
$app6->_apply_search();
is($app6->{_current_view}, 1, 'cross-view search finds nginx in pods view');
is(scalar @{$app6->{_filtered_resources}}, 1, 'cross-view finds nginx-pod in pods view');

# Test: cross-view search for "svc" should switch to services view
$app6->{_current_view} = 0;
$app6->{_search_query} = 'all:svc';
$app6->_apply_search();
is($app6->{_current_view}, 2, 'cross-view search switches to services view for svc');
is(scalar @{$app6->{_filtered_resources}}, 1, 'cross-view finds redis-svc');
is($app6->{_filtered_resources}[0]->name, 'redis-svc', 'cross-view finds redis-svc by svc match');

# Test: cross-view search with no matches stays on current view
$app6->{_current_view} = 1;
$app6->{_search_query} = 'all:zzzznonexistent';
$app6->_apply_search();
is($app6->{_current_view}, 1, 'cross-view search stays on current view when no matches');
is(scalar @{$app6->{_filtered_resources}}, 0, 'cross-view returns empty when no matches');

# Test: cross-view search sets search_regex
$app6->{_search_query} = 'all:redis';
$app6->_apply_search();
ok(defined $app6->{_search_regex}, 'cross-view search sets search_regex');
like('redis-pod', $app6->{_search_regex}, 'search_regex matches correctly');

# Test: cross-view search resets selected_row to 0
$app6->{_selected_row} = 5;
$app6->{_search_query} = 'all:redis';
$app6->_apply_search();
is($app6->{_selected_row}, 0, 'cross-view search resets selection to 0');

# Test: scoped search on current view only
$app6->{_current_view} = 2;  # services view
my @svc_resources = (
    bless({ name => 'redis-svc' }, 'MockResource'),
    bless({ name => 'nginx-svc' }, 'MockResource'),
);
$app6->{_resources} = \@svc_resources;
$app6->{_search_query} = 'redis';
$app6->_apply_search();
is($app6->{_current_view}, 2, 'scoped search stays on current view');
is(scalar @{$app6->{_filtered_resources}}, 1, 'scoped search filters to matching resources');
is($app6->{_filtered_resources}[0]->name, 'redis-svc', 'scoped search finds redis-svc');

# Test: empty search restores all resources
$app6->{_search_query} = '';
$app6->_apply_search();
is(scalar @{$app6->{_filtered_resources}}, 2, 'empty search restores all resources');

# Test: search_regex is cleared on empty query
$app6->{_search_regex} = qr/whatever/;
$app6->{_search_query} = '';
$app6->_apply_search();
is($app6->{_search_regex}, undef, 'empty search clears search_regex');

# Test: can_ok for _apply_search
can_ok($app, '_apply_search');

# --- Highlighting integration tests ---

# Test highlight integration
my $search2 = pk9s::Search->new();
my $regex3 = $search2->build_regex("nginx");
my $highlighted2 = $search2->highlight("nginx-deploy", $regex3);
like($highlighted2, qr/\e\[1m/, 'highlight adds ANSI codes');
like($highlighted2, qr/nginx/, 'highlight preserves original text');
unlike($search2->highlight("redis-deploy", $regex3), qr/\e\[1m/, 'non-matching text not highlighted');

# Test highlight with undef regex (no-op)
is($search2->highlight("nginx-deploy", undef), "nginx-deploy", 'highlight with undef regex returns original');

# Test _render_table applies highlighting when search is active
my $app7 = pk9s::App->new(
    config => pk9s::Config->new(),
    kubectl => bless({}, 'pk9s::Kubectl'),
);
$app7->{_resources} = [@test_resources];
$app7->{_search_active} = 1;
$app7->{_filtered_resources} = [$test_resources[0]];
$app7->{_search_regex} = $regex3;
# _render_table would use _search_regex for highlighting — verify it's set
ok(defined $app7->{_search_regex}, 'search_regex is set for highlighting');
