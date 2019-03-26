=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

=pod

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::PostHomologyMerge_conf

=head1 DESCRIPTION

The pipeline combines a few steps that are run after having merged the homology-side
of things in the release database.

=cut


package Bio::EnsEMBL::Compara::PipeConfig::PostHomologyMerge_conf;

use strict;
use warnings;


use Bio::EnsEMBL::Hive::Version 2.4;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;   # For WHEN and INPUT_PLUS


use Bio::EnsEMBL::Compara::PipeConfig::Parts::UpdateMemberNamesDescriptions;
use Bio::EnsEMBL::Compara::PipeConfig::Parts::GeneMemberHomologyStats;
use Bio::EnsEMBL::Compara::PipeConfig::Parts::HighConfidenceOrthologs;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        'pipeline_name'   => $self->o('division') . '_post_homology_merge_'.$self->o('rel_with_suffix'),   # also used to differentiate submitted processes
        'compara_db'      => 'compara_curr',
        'reg_conf'        => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/production_reg_" . $self->o('division') . "_conf.pl",

        'collection'      => 'default',  # The name of the clusterset_id in which to find the trees

        #Pipeline capacities:
        'update_capacity'                           => 5,
        'high_confidence_capacity'                  => 30,
        'high_confidence_batch_size'                => 10,
    };
}


sub hive_meta_table {
    my ($self) = @_;
    return {
        %{$self->SUPER::hive_meta_table},       # here we inherit anything from the base class
        'hive_use_param_stack'  => 1,           # switch on the new param_stack mechanism
    }
}


sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class

        'threshold_levels'  => $self->o('threshold_levels'),

        'do_member_update'      => 0,
        'do_member_stats_gt'    => 0,
        'do_member_stats_fam'   => 1,
        'do_high_confidence'    => 0,
    }
}

sub resource_classes {
    my ($self) = @_;
    my $reg_requirement = '--reg_conf '.$self->o('reg_conf');
    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class

        'patch_import'  => { 'LSF' => ['-C0 -M250 -R"select[mem>250] rusage[mem=250]"', $reg_requirement], 'LOCAL' => ['', $reg_requirement] },
        'patch_import_himem'  => { 'LSF' => ['-C0 -M500 -R"select[mem>500] rusage[mem=500]"', $reg_requirement], 'LOCAL' => ['', $reg_requirement] },
        '500Mb_job'    => { 'LSF' => ['-C0 -M500 -R"select[mem>500] rusage[mem=500]"', $reg_requirement], 'LOCAL' => ['', $reg_requirement] },
        'default_w_reg' => { 'LSF' => ['', $reg_requirement], 'LOCAL' => ['', $reg_requirement] },
        'default' => { 'LSF' => ['', $reg_requirement], 'LOCAL' => ['', $reg_requirement] }, # override default default to always incl reg_conf
    };
}


sub pipeline_analyses {
    my ($self) = @_;

    return [
        {   -logic_name => 'backbone_member_stats',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -input_ids  => [ {
                    'compara_db'    => $self->o('compara_db'),
                } ],
            -flow_into  => {
                '1->A' => [
                    WHEN( '#do_member_stats_gt#'  => [ 'set_default_values' ] ),
                    WHEN( '#do_member_stats_fam#' => [ 'stats_families' ] ),
                ],
                'A->1' => ['backbone_member_update'],
            },
        },

        {   -logic_name => 'backbone_member_update',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => {
                '1->A' => WHEN( '#do_member_update#' => 'species_update_factory' ),
                'A->1' => ['backbone_high_confidence'],
            },
        },

        {   -logic_name => 'backbone_high_confidence',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => {
                '1->A' => WHEN( '#do_high_confidence#' => { 'mlss_id_for_high_confidence_factory' => $self->o('high_confidence_ranges') } ),
                'A->1' => ['backbone_end'],
            },
        },

        {   -logic_name => 'backbone_end',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
        },

        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::GeneMemberHomologyStats::pipeline_analyses_hom_stats($self) },
        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::UpdateMemberNamesDescriptions::pipeline_analyses_member_names_descriptions($self) },
        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::HighConfidenceOrthologs::pipeline_analyses_high_confidence($self) },
    ];
}

1;


