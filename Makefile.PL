use strict;
use warnings;
use inc::Module::Install;

all_from 'lib/ZooKeeper/CLI.pm';
license 'Perl_5';

install_script 'bin/zkcli';

homepage   'https://github.com/mark-5/p5-zookeeper-cli';
bugtracker 'https://github.com/mark-5/p5-zookeeper-cli/issues';
repository 'https://github.com/mark-5/p5-zookeeper-cli.git';

clean_files 'MANIFEST', 'META.*';

cpanfile;
WriteAll;
