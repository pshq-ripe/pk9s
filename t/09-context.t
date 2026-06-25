#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'lib';
use File::Temp 'tempdir';
use pk9s::Context;

subtest 'new creates context' => sub {
    my $tmpdir = tempdir(CLEANUP => 1);
    my $ctx = pk9s::Context->new(dir => $tmpdir);
    ok(defined $ctx, 'context created');
    ok(-f "$tmpdir/context.db", 'database created');
};

subtest 'log_command stores entry' => sub {
    my $tmpdir = tempdir(CLEANUP => 1);
    my $ctx = pk9s::Context->new(dir => $tmpdir);
    $ctx->log_command('kubectl get pods', 'output', '', 0, 100);

    my $history = $ctx->get_history(limit => 10);
    is(scalar @$history, 1, 'one entry');
    is($history->[0]{command}, 'kubectl get pods', 'command stored');
    is($history->[0]{exit_code}, 0, 'exit code stored');
};

subtest 'log_event stores entry' => sub {
    my $tmpdir = tempdir(CLEANUP => 1);
    my $ctx = pk9s::Context->new(dir => $tmpdir);
    $ctx->log_event('warning', 'default', 'pod', 'nginx', 'OOMKilled');

    my $context = $ctx->get_context(limit => 10);
    is(scalar @$context, 1, 'one entry');
    is($context->[0]{type}, 'warning', 'type stored');
    is($context->[0]{resource_name}, 'nginx', 'resource stored');
};

subtest 'get_context filters by type' => sub {
    my $tmpdir = tempdir(CLEANUP => 1);
    my $ctx = pk9s::Context->new(dir => $tmpdir);
    $ctx->log_event('warning', 'default', 'pod', 'nginx', 'test1');
    $ctx->log_event('error', 'default', 'pod', 'nginx', 'test2');
    $ctx->log_event('warning', 'default', 'pod', 'nginx', 'test3');

    my $warnings = $ctx->get_context(type => 'warning', limit => 10);
    is(scalar @$warnings, 2, 'filtered by type');
};

subtest 'get_context filters by resource' => sub {
    my $tmpdir = tempdir(CLEANUP => 1);
    my $ctx = pk9s::Context->new(dir => $tmpdir);
    $ctx->log_event('warning', 'default', 'pod', 'nginx', 'test1');
    $ctx->log_event('warning', 'default', 'pod', 'redis', 'test2');

    my $nginx = $ctx->get_context(resource => 'nginx', limit => 10);
    is(scalar @$nginx, 1, 'filtered by resource');
};

subtest 'get_history returns recent entries' => sub {
    my $tmpdir = tempdir(CLEANUP => 1);
    my $ctx = pk9s::Context->new(dir => $tmpdir);
    $ctx->log_command('cmd1', '', '', 0, 10);
    $ctx->log_command('cmd2', '', '', 0, 20);
    $ctx->log_command('cmd3', '', '', 0, 30);

    my $history = $ctx->get_history(limit => 2);
    is(scalar @$history, 2, 'returns last 2');
    is($history->[0]{command}, 'cmd2', 'correct order');
    is($history->[1]{command}, 'cmd3', 'correct order');
};

subtest 'clear_old removes old entries' => sub {
    my $tmpdir = tempdir(CLEANUP => 1);
    my $ctx = pk9s::Context->new(dir => $tmpdir);
    $ctx->log_event('warning', 'default', 'pod', 'nginx', 'old');

    $ctx->{dbh}->do('UPDATE context SET timestamp = ? WHERE id = 1', undef, time() - (10 * 86400));

    $ctx->clear_old(7);

    my $context = $ctx->get_context(limit => 10);
    is(scalar @$context, 0, 'old entries removed');
};

subtest 'persists across instances' => sub {
    my $tmpdir = tempdir(CLEANUP => 1);
    my $ctx1 = pk9s::Context->new(dir => $tmpdir);
    $ctx1->log_command('test', '', '', 0, 10);

    my $ctx2 = pk9s::Context->new(dir => $tmpdir);
    my $history = $ctx2->get_history(limit => 10);
    is(scalar @$history, 1, 'data persisted');
};

done_testing();
