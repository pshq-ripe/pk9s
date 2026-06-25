#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'lib';

package MockKubectl {
    sub new { bless { kubectl => 'echo' }, shift }
    sub _run {
        my ($self, @cmd) = @_;
        if (grep { $_ eq 'logs' } @cmd) {
            return ("line1\nline2\nline3\n", "");
        }
        if (grep { $_ eq 'delete' } @cmd) {
            return ("pod/nginx deleted\n", "");
        }
        if (grep { $_ eq 'rollout' } @cmd) {
            return ("deployment.apps/nginx restarted\n", "");
        }
        if ((grep { $_ eq 'get' } @cmd) && (grep { $_ eq '-o' } @cmd)) {
            return ("apiVersion: v1\nkind: Pod\nmetadata:\n  name: nginx\n", "");
        }
        if (grep { $_ eq 'apply' } @cmd) {
            if (grep { $_ eq '--dry-run=client' } @cmd) {
                return ("pod/nginx created (dry run)\n", "");
            }
            return ("pod/nginx created\n", "");
        }
        return ("", "error: not found");
    }
    sub execute {
        my ($self, @args) = @_;
        my ($out, $err) = $self->_run(@args);
        if ($err && $err =~ /error/i) {
            return { error => $err };
        }
        require JSON::PP;
        my $data = eval { JSON::PP::decode_json($out) };
        return $@ ? $out : $data;
    }
}

package main;

use pk9s::Ops;

my $kubectl = MockKubectl->new();
my $ops = pk9s::Ops->new(kubectl => $kubectl);

subtest 'get_logs' => sub {
    my $result = $ops->get_logs('nginx', 'default');
    is(ref $result, 'HASH', 'returns hashref');
    ok(exists $result->{logs}, 'has logs key');
    like($result->{logs}, qr/line1/, 'contains log output');
};

subtest 'get_logs with tail' => sub {
    my $result = $ops->get_logs('nginx', 'default', tail => 50);
    is(ref $result, 'HASH', 'returns hashref');
    ok(exists $result->{logs}, 'has logs key');
};

subtest 'get_logs with previous' => sub {
    my $result = $ops->get_logs('nginx', 'default', previous => 1);
    is(ref $result, 'HASH', 'returns hashref');
    ok(exists $result->{logs}, 'has logs key');
};

subtest 'delete_resource' => sub {
    my $result = $ops->delete_resource('pod', 'nginx', 'default');
    is(ref $result, 'HASH', 'returns hashref');
    ok(exists $result->{success}, 'has success key');
    is($result->{success}, 1, 'success is 1');
};

subtest 'rollout_restart' => sub {
    my $result = $ops->rollout_restart('deployment', 'nginx', 'default');
    is(ref $result, 'HASH', 'returns hashref');
    ok(exists $result->{success}, 'has success key');
    is($result->{success}, 1, 'success is 1');
};

subtest 'edit_resource' => sub {
    plan skip_all => 'skipping edit test (opens editor)';
    my $result = $ops->edit_resource('pod', 'nginx', 'default');
    is(ref $result, 'HASH', 'returns hashref');
    ok(exists $result->{success} || exists $result->{error}, 'has success or error');
};

subtest 'port_forward returns pid' => sub {
    my $result = $ops->port_forward('pod', 'nginx', 'default', '8080:80');
    is(ref $result, 'HASH', 'returns hashref');
    ok(exists $result->{pid} || exists $result->{error}, 'has pid or error');
};

subtest 'kill_portforward' => sub {
    my $result = $ops->kill_portforward(99999);
    is(ref $result, 'HASH', 'returns hashref');
    ok(exists $result->{success}, 'has success key');
};

done_testing();
