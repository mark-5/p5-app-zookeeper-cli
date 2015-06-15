configure_requires 'Module::Install::CPANfile';
configure_requires 'Module::Install::ReadmePodFromPod';

requires "AE";
requires "Exporter::Tiny";
requires "Getopt::Long::Descriptive";
requires "List::Util";
requires "Moo";
requires "Scalar::Util";
requires "Term::ReadLine";
requires "Text::ParseWords";
requires "Try::Tiny";
requires "ZooKeeper";

test_requires "Test::More";
test_requires "Test::Strict";
