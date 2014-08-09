#!/usr/bin/env perl
use strict;
use warnings;
use System::Process;
use Data::Dumper;
use POSIX qw/setsid/;
use Test::More tests => 1;

my $worker_process_name = 'SYSTEM_PROCESS_TEST_BUNDLED_WORKER';
my $processes_count = 3;
$SIG{'CHLD'} = 'IGNORE';
my $pid = fork();

if ($pid) {
    # require Test::More;
    # import Test::More tests => 1;

    sleep 2;
    my $bundle = System::Process::pidinfo pattern => $worker_process_name;

    # print Dumper $bundle;

    my $i = 0;

    for my $object (@$bundle) {
        if ($object->cankill() && $object->command() eq $worker_process_name) {
            $object->kill(POSIX::SIGKILL);
            $i++;
        }
    }

    ok $i eq $processes_count, 'Bundled processes';
    exit 0;
}
else {
    no Test::More;
    for (1 .. $processes_count) {
        unless (fork) {
            setsid;
            fork && exit;
            $0 = $worker_process_name;
            local $SIG{ALRM} = sub {
                exit 0;
            };
            alarm 10;
            while(1){};
        }
    }
}
