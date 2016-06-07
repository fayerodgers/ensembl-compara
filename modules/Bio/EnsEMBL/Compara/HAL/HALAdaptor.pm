# Intended to mimic the registry or compara_db objects for providing compara adaptors.
=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME
=cut

package Bio::EnsEMBL::Compara::HAL::HALAdaptor;

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
#use Bio::EnsEMBL::Compara::HAL::GenomicAlignBlockAdaptor;
#use Bio::EnsEMBL::Compara::HAL::MethodLinkSpeciesSetAdaptor;

die "The environment variable 'PROGRESSIVE_CACTUS_DIR' must be defined to a valid installation of Cactus.\n" unless $ENV{'PROGRESSIVE_CACTUS_DIR'};

use Inline C => Config =>
             LIBS => "-L$ENV{'PROGRESSIVE_CACTUS_DIR'}/submodules/hdf5/lib -L$ENV{'PROGRESSIVE_CACTUS_DIR'}/submodules/hal/lib -L$ENV{'PROGRESSIVE_CACTUS_DIR'}/submodules/sonLib/lib   -lstdc++ -lhdf5 -lhdf5_cpp",
             MYEXTLIB => ["$ENV{'PROGRESSIVE_CACTUS_DIR'}/submodules/hal/lib/halChain.a", "$ENV{'PROGRESSIVE_CACTUS_DIR'}/submodules/hal/lib/halLod.a", "$ENV{'PROGRESSIVE_CACTUS_DIR'}/submodules/hal/lib/halLiftover.a", "$ENV{'PROGRESSIVE_CACTUS_DIR'}/submodules/hal/lib/halLib.a", "$ENV{'PROGRESSIVE_CACTUS_DIR'}/submodules/sonLib/lib/sonLib.a"],
             INC => "-I$ENV{'PROGRESSIVE_CACTUS_DIR'}/submodules/hal/chain/inc/";
#use Inline 'C' => "$ENV{ENSEMBL_CVS_ROOT_DIR}/compara-master/modules/Bio/EnsEMBL/Compara/HAL/HALAdaptorSupport.c";
use Inline 'C' => "$ENV{ENSEMBL_CVS_ROOT_DIR}/ensembl-compara/modules/Bio/EnsEMBL/Compara/HAL/HALAdaptorSupport.c";
             #LIBS => "-L$ENV{'PROGRESSIVE_CACTUS_DIR'}/submodules/hdf5/lib -lstdc++ -lhdf5 -lhdf5_cpp",

=head2 new

  Arg [1]    : list of args to super class constructor
  Example    : $ga_a = Bio::EnsEMBL::Compara::HAL::HALAdaptor->new("/tmp/test.hal");
  Description: Creates a new HALAdaptor from an lod.txt file or hal file.
  Returntype : none
  Exceptions : none

=cut

sub new {
    my($class, $path, $use_hal_genomes) = @_;
    my $self = {};
    bless $self, $class;
    $self->{'path'} = $path;
    $self->{'hal_fd'} = _open_hal($self->path);
    if (defined $use_hal_genomes && $use_hal_genomes) {
        $self->{'use_hal_genomes'} = 1;
    } else {
        $self->{'use_hal_genomes'} = 0;
    }

    #print Dumper $self;

    return $self;
}

sub path {
    my $self = shift;
    return $self->{'path'};
}

sub hal_filehandle {
    my $self = shift;
    return $self->{'hal_fd'};
}

sub genome_name_from_species_and_assembly {
    my ($self, $species_name, $assembly_name) = @_;
    foreach my $genome (_get_genome_names($self->{'hal_fd'})) {
        my $genome_metadata = _get_genome_metadata($self->{'hal_fd'}, $genome);
        if ((exists $genome_metadata->{'ensembl_species'} && $genome_metadata->{'ensembl_species'} eq $species_name) &&
            (exists $genome_metadata->{'ensembl_assembly'} && $genome_metadata->{'ensembl_assembly'} eq $assembly_name)) {
            return $genome;
        }
    }
    die "Could not find genome with metadata indicating it corresponds to ensembl species='".$species_name."', ensembl_assembly='".$assembly_name."'"
}

sub genome_metadata {
    my ($self, $genome) = @_;
    return _get_genome_metadata($self->{'hal_fd'}, $genome);
}

sub ensembl_genomes {
    my $self = shift;
    my @ensembl_genomes = grep { exists($self->genome_metadata($_)->{'ensembl_species'}) && exists($self->genome_metadata($_)->{'ensembl_assembly'}) } $self->genomes();
    return @ensembl_genomes;
}

sub genomes {
    my $self = shift;
    return _get_genome_names($self->{'hal_fd'});
}


1;
