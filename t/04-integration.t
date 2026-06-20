use strict;
use warnings;
use Test::More tests => 4;
use lib 'lib';

package MockKubectl {
    use parent 'pk9s::Kubectl';

    sub _run {
        my ($self, @cmd) = @_;

        if (grep { $_ eq 'pods' } @cmd) {
            return ('{
                "apiVersion": "v1",
                "items": [
                    {"metadata": {"name": "pod-1", "namespace": "default"}, "status": {"phase": "Running", "containerStatuses": [{"ready": 1}]}},
                    {"metadata": {"name": "pod-2", "namespace": "kube-system"}, "status": {"phase": "Pending", "containerStatuses": []}}
                ]
            }', '');
        }

        return ('{}', '');
    }
}

package main;

use_ok('pk9s::Kubectl');
use_ok('pk9s::Resource');

my $kubectl = MockKubectl->new();
my $data = $kubectl->get_pods();

my @resources = map {
    pk9s::Resource->normalize($_, 'pod')
} @{$data->{items}};

is(scalar @resources, 2, 'normalized 2 pods');
is($resources[0]->status, 'Running', 'first pod is Running');
