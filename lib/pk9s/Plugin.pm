package pk9s::Plugin;
use strict;
use warnings;
use JSON::PP;
use File::Path 'mkpath';

sub new {
    my ($class, %args) = @_;
    my $dir = $args{dir} // "$ENV{HOME}/.pk9s/plugins";
    mkpath($dir) unless -d $dir;

    return bless {
        dir => $dir,
        plugins => [],
    }, $class;
}

sub load_plugins {
    my ($self) = @_;

    opendir my $dh, $self->{dir} or return;
    my @files = grep { /\.json$/ } readdir $dh;
    closedir $dh;

    for my $file (@files) {
        my $path = "$self->{dir}/$file";
        my $plugin = eval { $self->_load_plugin($path) };
        if ($plugin) {
            push @{$self->{plugins}}, $plugin;
        }
    }

    return scalar @{$self->{plugins}};
}

sub _load_plugin {
    my ($self, $path) = @_;

    open my $fh, '<', $path or return undef;
    local $/;
    my $content = <$fh>;
    close $fh;

    my $data = decode_json($content);

    return undef unless $data->{name};
    return undef unless $data->{resources} && @{$data->{resources}};

    return {
        name => $data->{name},
        version => $data->{version} // '1.0.0',
        description => $data->{description} // '',
        resources => $data->{resources},
        actions => $data->{actions} // {},
        keybindings => $data->{keybindings} // {},
        file => $path,
    };
}

sub get_plugins {
    my ($self) = @_;
    return @{$self->{plugins}};
}

sub get_resources {
    my ($self) = @_;
    my @resources;

    for my $plugin (@{$self->{plugins}}) {
        for my $res (@{$plugin->{resources}}) {
            push @resources, {
                plugin => $plugin->{name},
                api => $res->{api},
                columns => $res->{columns},
                extract => $res->{extract},
            };
        }
    }

    return @resources;
}

sub get_actions {
    my ($self, $resource_api) = @_;
    my %actions;

    for my $plugin (@{$self->{plugins}}) {
        for my $res (@{$plugin->{resources}}) {
            if ($res->{api} eq $resource_api) {
                for my $key (keys %{$plugin->{actions}}) {
                    $actions{$key} = $plugin->{actions}{$key};
                }
            }
        }
    }

    return %actions;
}

sub execute_action {
    my ($self, $action, $name, $namespace) = @_;

    my $cmd = $action->{cmd};
    $cmd =~ s/%s/$name/g;
    $cmd =~ s/%n/$namespace/g if $namespace;

    my $output = `$cmd 2>&1`;
    my $exit_code = $? >> 8;

    return {
        output => $output,
        exit_code => $exit_code,
        success => $exit_code == 0,
    };
}

sub create_sample_plugin {
    my ($self) = @_;

    my $sample = {
        name => "sample",
        version => "1.0.0",
        description => "Sample plugin for pk9s",
        resources => [
            {
                api => "configmap",
                columns => ["Name", "Data", "Age"],
                extract => sub {
                    my ($item) = @_;
                    return [
                        $item->{metadata}{name},
                        scalar keys %{$item->{data} // {}},
                        $item->{metadata}{creationTimestamp},
                    ];
                },
            },
        ],
        actions => {
            d => {
                label => "Describe",
                cmd => "kubectl describe configmap %s -n %n",
                confirm => 0,
            },
        },
    };

    my $path = "$self->{dir}/sample.json";
    open my $fh, '>', $path or return;
    print $fh encode_json($sample);
    close $fh;

    return $path;
}

1;
