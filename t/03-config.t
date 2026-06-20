use strict;
use warnings;
use Test::More tests => 5;
use lib 'lib';
use File::Temp qw(tempfile);

use_ok('pk9s::Config');

# Test default config
my $config = pk9s::Config->new();
isa_ok($config, 'pk9s::Config');
is($config->get('kubectl'), 'kubectl', 'default kubectl path');
is($config->get('context'), undef, 'default context is undef');

# Test loading from file
my ($fh, $filename) = tempfile(SUFFIX => '.json', UNLINK => 1);
print $fh '{"kubectl":"/usr/local/bin/kubectl","context":"production"}';
close $fh;

my $file_config = pk9s::Config->new(file => $filename);
is($file_config->get('kubectl'), '/usr/local/bin/kubectl', 'loaded kubectl from file');
