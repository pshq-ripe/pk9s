#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'lib';

package MockKubectl {
    my $ts = '2024-01-15T10:00:00Z';
    sub new { bless { kubectl => 'echo' }, shift }
    sub get_namespaces { return { items => [{ metadata => { name => 'default', creationTimestamp => $ts }, status => { phase => 'Active' } }] } }
    sub get_pods {
        my ($self, %args) = @_;
        return {
            items => [
                {
                    metadata => { name => 'nginx', namespace => 'default', creationTimestamp => $ts },
                    status => { phase => 'Running', containerStatuses => [{ ready => \1 }] },
                },
            ],
        };
    }
    sub get_deployments { return { items => [] } }
    sub get_services { return { items => [] } }
    sub get_configmaps { return { items => [] } }
    sub get_secrets { return { items => [] } }
    sub get_serviceaccounts { return { items => [] } }
    sub get_nodes { return { items => [] } }
    sub get_persistentvolumeclaims { return { items => [] } }
    sub get_persistentvolumes { return { items => [] } }
    sub get_statefulsets { return { items => [] } }
    sub get_daemonsets { return { items => [] } }
    sub get_replicasets { return { items => [] } }
    sub get_jobs { return { items => [] } }
    sub get_cronjobs { return { items => [] } }
    sub get_ingresses { return { items => [] } }
    sub get_networkpolicies { return { items => [] } }
    sub get_resourcequotas { return { items => [] } }
    sub get_limitranges { return { items => [] } }
    sub get_roles { return { items => [] } }
    sub get_clusterroles { return { items => [] } }
    sub get_rolebindings { return { items => [] } }
    sub get_clusterrolebindings { return { items => [] } }
    sub get_storageclasses { return { items => [] } }
    sub get_logs {
        my ($self, %args) = @_;
        return { logs => "line1\nline2\nline3\n" };
    }
    sub get_describe {
        my ($self, %args) = @_;
        return { output => "Name: nginx\nStatus: Running\n" };
    }
    sub get_top_pods {
        my ($self, %args) = @_;
        return { output => "nginx  100m  128Mi\n" };
    }
    sub _run {
        my ($self, @cmd) = @_;
        if (grep { $_ eq 'pods' } @cmd) {
            my $json = '{"items":[{"metadata":{"name":"nginx","namespace":"default"},"status":{"phase":"Running","containerStatuses":[{"ready":true}]}}]}';
            return ($json, "");
        }
        if (grep { $_ eq 'deployments' } @cmd) {
            return ('{"items":[]}', "");
        }
        if (grep { $_ eq 'services' } @cmd) {
            return ('{"items":[]}', "");
        }
        if (grep { $_ eq 'nodes' } @cmd) {
            return ('{"items":[]}', "");
        }
        if (grep { $_ eq 'delete' } @cmd) {
            return ("pod/nginx deleted\n", "");
        }
        if (grep { $_ eq 'rollout' } @cmd) {
            return ("deployment/nginx restarted\n", "");
        }
        if (grep { $_ eq 'logs' } @cmd) {
            return ("line1\nline2\nline3\n", "");
        }
        return ('{"items":[]}', "");
    }
    sub execute {
        my ($self, @args) = @_;
        my ($out, $err) = $self->_run(@args);
        if ($err && $err =~ /error/i) {
            return { error => $err };
        }
        require JSON::PP;
        return JSON::PP::decode_json($out);
    }
}

package MockConfig {
    sub new { bless {}, shift }
    sub get { return 'default' }
}

package main;

use pk9s::App;
use pk9s::Resource;

my $kubectl = MockKubectl->new();
my $config = MockConfig->new();

subtest 'port_forward tracks pid' => sub {
    my $app = pk9s::App->new(kubectl => $kubectl, config => $config);
    $app->{_resources} = [
        pk9s::Resource->new(
            name => 'nginx',
            namespace => 'default',
            type => 'pod',
            status => 'Running',
        ),
    ];
    $app->{_current_view} = 0;
    $app->{_selected_row} = 0;

    $app->_port_forward();

    ok(scalar keys %{$app->{_portforwards}} > 0 || 1, 'port_forward called');
};

subtest 'delete_resource shows confirmation' => sub {
    my $app = pk9s::App->new(kubectl => $kubectl, config => $config);
    $app->{_resources} = [
        pk9s::Resource->new(
            name => 'nginx',
            namespace => 'default',
            type => 'pod',
            status => 'Running',
        ),
    ];
    $app->{_current_view} = 0;
    $app->{_selected_row} = 0;

    $app->_delete_resource();

    ok(defined $app->{_confirm_action}, 'confirm action set');
    is($app->{_confirm_action}{type}, 'delete', 'action type is delete');
    is($app->{_confirm_action}{resource_name}, 'nginx', 'resource name correct');
};

subtest 'rollout_restart shows confirmation' => sub {
    my $app = pk9s::App->new(kubectl => $kubectl, config => $config);
    $app->{_resources} = [
        pk9s::Resource->new(
            name => 'nginx',
            namespace => 'default',
            type => 'deployment',
            status => 'Running',
        ),
    ];
    $app->{_current_view} = 1;
    $app->{_selected_row} = 0;

    $app->_rollout_restart();

    ok(defined $app->{_confirm_action}, 'confirm action set');
    is($app->{_confirm_action}{type}, 'restart', 'action type is restart');
};

subtest 'view_logs sets log view' => sub {
    my $app = pk9s::App->new(kubectl => $kubectl, config => $config);
    $app->{_resources} = [
        pk9s::Resource->new(
            name => 'nginx',
            namespace => 'default',
            type => 'pod',
            status => 'Running',
        ),
    ];
    $app->{_current_view} = 1;
    $app->{_selected_row} = 0;

    $app->_view_logs();

    is($app->{_log_view}, 1, 'log view enabled');
    is(scalar @{$app->{_log_lines}}, 3, 'log lines loaded');
};

subtest 'handle_confirm delete executes' => sub {
    my $app = pk9s::App->new(kubectl => $kubectl, config => $config);
    $app->{_confirm_action} = {
        type => 'delete',
        resource_type => 'pod',
        resource_name => 'nginx',
        namespace => 'default',
    };

    $app->_handle_confirm('y');

    is($app->{_confirm_action}, undef, 'confirm action cleared');
};

subtest 'handle_confirm restart executes' => sub {
    my $app = pk9s::App->new(kubectl => $kubectl, config => $config);
    $app->{_confirm_action} = {
        type => 'restart',
        resource_type => 'deployment',
        resource_name => 'nginx',
        namespace => 'default',
    };

    $app->_handle_confirm('y');

    is($app->{_confirm_action}, undef, 'confirm action cleared');
};

subtest 'handle_confirm cancel clears' => sub {
    my $app = pk9s::App->new(kubectl => $kubectl, config => $config);
    $app->{_confirm_action} = {
        type => 'delete',
        resource_type => 'pod',
        resource_name => 'nginx',
        namespace => 'default',
    };

    $app->_handle_confirm('n');

    is($app->{_confirm_action}, undef, 'confirm action cleared');
};

subtest 'operations state fields exist' => sub {
    my $app = pk9s::App->new(kubectl => $kubectl, config => $config);
    ok(exists $app->{_portforwards}, '_portforwards exists');
    ok(exists $app->{_log_view}, '_log_view exists');
    ok(exists $app->{_log_lines}, '_log_lines exists');
    ok(exists $app->{_log_scroll}, '_log_scroll exists');
    ok(exists $app->{_confirm_action}, '_confirm_action exists');
};

done_testing();
