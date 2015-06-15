use strict;
use warnings;
use inc::Module::Install;

all_from 'lib/App/ZooKeeper/CLI.pm';
readme_pod_from 'bin/pzkcli';

install_script 'bin/pzkcli';

homepage   'https://github.com/mark-5/p5-app-zookeeper-cli';
bugtracker 'https://github.com/mark-5/p5-app-zookeeper-cli/issues';
repository 'https://github.com/mark-5/p5-app-zookeeper-cli.git';

clean_files 'MANIFEST', 'META.*';

cpanfile;
WriteAll;
