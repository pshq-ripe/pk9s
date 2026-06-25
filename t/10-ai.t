#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'lib';
use pk9s::AI;

package MockKubectl {
    sub new { bless { kubectl => 'echo' }, shift }
    sub _run {
        my ($self, @cmd) = @_;
        if (grep { $_ eq 'logs' } @cmd) {
            return ("ERROR: connection refused\n", "");
        }
        if (grep { $_ eq 'events' } @cmd) {
            return ("Warning  BackOff  pod/nginx  Back-off restarting failed container\n", "");
        }
        if (grep { $_ eq 'describe' } @cmd) {
            return ("Name: nginx\nStatus: CrashLoopBackOff\n", "");
        }
        return ("", "");
    }
}

package main;

my $kubectl = MockKubectl->new();

subtest 'new creates AI' => sub {
    my $ai = pk9s::AI->new(kubectl => $kubectl);
    ok(defined $ai, 'AI created');
    is($ai->{model}, 'qwen2.5:7b', 'default model');
};

subtest 'build_prompt includes resource info' => sub {
    my $ai = pk9s::AI->new(kubectl => $kubectl);
    my $prompt = $ai->build_prompt(
        type => 'pod',
        name => 'nginx',
        namespace => 'default',
        logs => 'test logs',
    );

    like($prompt, qr/pod\/nginx/, 'includes resource');
    like($prompt, qr/test logs/, 'includes logs');
};

subtest 'build_prompt includes events' => sub {
    my $ai = pk9s::AI->new(kubectl => $kubectl);
    my $prompt = $ai->build_prompt(
        type => 'pod',
        name => 'nginx',
        namespace => 'default',
        events => 'BackOff event',
    );

    like($prompt, qr/BackOff/, 'includes events');
};

subtest 'build_cluster_prompt includes pods' => sub {
    my $ai = pk9s::AI->new(kubectl => $kubectl);
    my $prompt = $ai->build_cluster_prompt(
        pods => 'nginx  CrashLoopBackOff',
        events => 'Warning events',
    );

    like($prompt, qr/nginx/, 'includes pods');
};

subtest 'call_ollama handles connection failure' => sub {
    my $ai = pk9s::AI->new(
        kubectl => $kubectl,
        endpoint => 'http://localhost:99999',
    );

    my $result = $ai->call_ollama('test prompt');
    ok(exists $result->{error}, 'returns error on connection failure');
};

subtest 'analyze_resource gathers context' => sub {
    my $ai = pk9s::AI->new(
        kubectl => $kubectl,
        endpoint => 'http://localhost:99999',
    );

    my $result = $ai->analyze_resource('pod', 'nginx', 'default');
    ok(exists $result->{error} || exists $result->{response}, 'returns result');
};

done_testing();
