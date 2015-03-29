use strict; use warnings;
use Test::Compile;
use Test::More;

use_ok 'ZooKeeper::CLI';
Test::Compile->new->all_files_ok('bin', 'lib');

done_testing;
