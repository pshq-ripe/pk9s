use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'pk9s',
    VERSION_FROM => 'lib/pk9s.pm',
    ABSTRACT     => 'Lightweight Kubernetes TUI in Perl',
    AUTHOR       => 'pk9s contributors',
    LICENSE      => 'perl_5',
    PREREQ_PM    => {
        'JSON::PP'         => 0,
        'IPC::Open3'       => 0,
        'File::Temp'       => 0,
        'Tickit'           => 0,
        'Term::ANSIColor'  => 0,
    },
    TEST_REQUIRES => {
        'Test::More' => 0.96,
    },
    EXE_FILES     => ['bin/pk9s'],
    META_MERGE    => {
        'meta-spec' => { version => 2 },
        resources   => {
            repository => {
                type => 'git',
                url  => 'https://github.com/pshq/pk9s.git',
            },
        },
    },
);
