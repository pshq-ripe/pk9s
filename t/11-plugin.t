#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'lib';
use File::Temp 'tempdir';
use pk9s::Plugin;

subtest 'new creates plugin loader' => sub {
    my $tmpdir = tempdir(CLEANUP => 1);
    my $plugin = pk9s::Plugin->new(dir => $tmpdir);
    ok(defined $plugin, 'plugin loader created');
    ok(-d $tmpdir, 'directory exists');
};

subtest 'load_plugins with empty dir' => sub {
    my $tmpdir = tempdir(CLEANUP => 1);
    my $plugin = pk9s::Plugin->new(dir => $tmpdir);
    my $count = $plugin->load_plugins();
    is($count, 0, 'no plugins loaded');
};

subtest 'load_plugins with valid plugin' => sub {
    my $tmpdir = tempdir(CLEANUP => 1);

    my $plugin_json = '{"name":"test","version":"1.0","description":"Test plugin","resources":[{"api":"test.io/v1","columns":["Name","Status"]}],"actions":{"r":{"label":"Restart","cmd":"kubectl rollout restart %s","confirm":true}}}';

    open my $fh, '>', "$tmpdir/test.json";
    print $fh $plugin_json;
    close $fh;

    my $plugin = pk9s::Plugin->new(dir => $tmpdir);
    my $count = $plugin->load_plugins();
    is($count, 1, 'one plugin loaded');
};

subtest 'get_plugins returns loaded plugins' => sub {
    my $tmpdir = tempdir(CLEANUP => 1);

    my $plugin_json = '{"name":"test2","version":"1.0","resources":[{"api":"test.io/v1","columns":["Name"]}]}';
    open my $fh, '>', "$tmpdir/test2.json";
    print $fh $plugin_json;
    close $fh;

    my $plugin = pk9s::Plugin->new(dir => $tmpdir);
    $plugin->load_plugins();

    my @plugins = $plugin->get_plugins();
    is(scalar @plugins, 1, 'one plugin');
    is($plugins[0]{name}, 'test2', 'correct name');
};

subtest 'get_resources returns plugin resources' => sub {
    my $tmpdir = tempdir(CLEANUP => 1);

    my $plugin_json = '{"name":"test3","resources":[{"api":"flux.io/v1","columns":["Name","Ready"]}]}';
    open my $fh, '>', "$tmpdir/test3.json";
    print $fh $plugin_json;
    close $fh;

    my $plugin = pk9s::Plugin->new(dir => $tmpdir);
    $plugin->load_plugins();

    my @resources = $plugin->get_resources();
    is(scalar @resources, 1, 'one resource');
    is($resources[0]{api}, 'flux.io/v1', 'correct api');
};

subtest 'get_actions returns plugin actions' => sub {
    my $tmpdir = tempdir(CLEANUP => 1);

    my $plugin_json = '{"name":"test4","resources":[{"api":"test.io/v1"}],"actions":{"r":{"label":"Restart"}}}';
    open my $fh, '>', "$tmpdir/test4.json";
    print $fh $plugin_json;
    close $fh;

    my $plugin = pk9s::Plugin->new(dir => $tmpdir);
    $plugin->load_plugins();

    my %actions = $plugin->get_actions('test.io/v1');
    ok(exists $actions{r}, 'action exists');
    is($actions{r}{label}, 'Restart', 'correct label');
};

subtest 'invalid plugin skipped' => sub {
    my $tmpdir = tempdir(CLEANUP => 1);

    open my $fh, '>', "$tmpdir/invalid.json";
    print $fh '{"invalid": true}';
    close $fh;

    my $plugin = pk9s::Plugin->new(dir => $tmpdir);
    my $count = $plugin->load_plugins();
    is($count, 0, 'invalid plugin skipped');
};

done_testing();
