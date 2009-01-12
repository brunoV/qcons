use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Bio::Tools::Run::QCons',
    AUTHOR              => 'Bruno Vecchi <vecchi.b@gmail.com>',
    VERSION_FROM        => 'lib/Bio/Tools/Run/QCons.pm',
    ABSTRACT_FROM       => 'lib/Bio/Tools/Run/QCons.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Bio-Tools-Run-QCons-*' },
);
