package ExtUtils::CleanShadows;
use strict;
use warnings;

our $VERSION = '0.001000';
$VERSION =~ tr/_//d;

sub import {
  my $class = shift;
  if (@_) {
    my $caller = caller;
    no strict 'refs';
    for (@_) {
      die "$_ is not available"
        unless defined &{"$_"};
    }
    *{"${caller}::$_"} = \&{"$_"} for @_;
  }
  else {
    require ExtUtils::MakeMaker;
    if (!MM->isa('ExtUtils::CleanShadows::MM')) {
      @ExtUtils::CleanShadows::MM::ISA = @MM::ISA;
      @MM::ISA = ('ExtUtils::CleanShadows::MM');
    }
  }
}

sub clean_shadows {
  my ($lib, $arch, $destarch) = @_;
  require File::Find;

  my $arch_files = 0;
  File::Find::find(sub {
    return if $_ eq ".exists";
    if (-f) {
      $File::Find::prune++;
      $arch_files = 1;
    }
  }, $arch);
  return
    if $arch_files;

  File::Find::find(sub {
    return
      unless -f;
    my $rel_path = File::Spec->abs2rel($File::Find::name, $lib);
    my $arch_file = File::Spec->catdir($destarch, $rel_path);
    if (-f $arch_file) {
      unlink $arch_file;
    }
  }, $lib);
}

{
  package ExtUtils::CleanShadows::MM;

  sub install {
    my $self = shift;
    my $install = $self->SUPER::install(@_);
    my $clean = '
pure_perl_install ::
	$(NOECHO) $(CLEAN_SHADOWS) \
		"$(INST_LIB)" "$(INST_ARCHLIB)" "$(DESTINSTALLARCHLIB)"

pure_site_install ::
	$(NOECHO) $(CLEAN_SHADOWS) \
		"$(INST_LIB)" "$(INST_ARCHLIB)" "$(DESTINSTALLSITEARCH)"

pure_vendor_install ::
	$(NOECHO) $(CLEAN_SHADOWS) \
		"$(INST_LIB)" "$(INST_ARCHLIB)" "$(DESTINSTALLVENDORARCH)"
';
    return $clean . $install;
  }

  sub constants {
    my $self = shift;
    my $constants = $self->SUPER::constants(@_);

    require File::Basename;
    require File::Spec;
    my $inc = File::Spec->rel2abs(File::Spec->catdir(File::Basename::dirname(__FILE__), File::Spec->updir));

    my $perl = '$(ABSPERLRUN) ' . $self->quote_literal("-I$inc");
    my $clean_shadows = $self->oneliner(
      'clean_shadows(@ARGV)',
      [$self->quote_literal("-I$inc"), '-MExtUtils::CleanShadows=clean_shadows'],
    );

    $constants .= qq{
CLEAN_SHADOWS = $clean_shadows
};
    return $constants;
  }

}

1;


__END__

=head1 NAME

ExtUtils::CleanShadows - Clean shadows in arch lib

=head1 SYNOPSIS

  use ExtUtils::MakeMaker;
  use ExtUtils::CleanShadows;

  WriteMakefile(
    ...
  );

=head1 DESCRIPTION

This module will remove libraries from the arch install dir that corresponds
to the lib path that is being installed to.  It will not remove files from any
other directories, unlike the UNINST=1 option.  This means it is safe to use
inside a Makefile.PL rather than being a user option.

This module is useful when removing an XS component from an existing module.

=cut
