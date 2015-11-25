###############################################################################
# Author      : Ethy Cannon 
#               NOTE: developed from scripts written by Taein Lee 
#                     in the Main Lab, Washington State University.
# Name        : load_contact.pm
# Date        : November, 2015
# Description : loader for 'contact' worksheet
###############################################################################

use strict;

our $contact_identifer_ref;

#-----------------------------------------------------------------------------#
# process_contact
#-----------------------------------------------------------------------------#
sub process_contact {
  my ($pg_db, $oBook, $module_ref, $data_info_ref)= @_;
  my %record_new_table= ();
  my %cvterm_id= ();

#TODO: may not want this; seems to only be used to count records inserted
  # pre-processing
#  my $num_record_ref= module_pre_process($module_ref->{MODULE});

  # process excel sheet
  my ($excel_ref, $cvterm_ref, $sp_col_refs, $error)
      = process_excel($oBook, $module_ref->{SHEET}, $data_info_ref);
  if ($error ne '') {
    println("\n$error\n\t[$module_ref->{SHEET}] Abort: process excel sheet...\n\n",'SE');
    exit;
  }
exit;
=cut  
  
  # get cvterm_id
  $cvterm_id{person}      = check_cvterm('person',       $data_info_ref->{CV_ID});
  $cvterm_id{institution}    = check_cvterm('institution',  $data_info_ref->{CV_ID});
  $cvterm_id{lab}        = check_cvterm('lab',          $data_info_ref->{CV_ID});
  $cvterm_id{organization}  = check_cvterm('organization', $data_info_ref->{CV_ID});
  $cvterm_id{database}    = check_cvterm('database',     $data_info_ref->{CV_ID});
  $cvterm_id{company}      = check_cvterm('company',      $data_info_ref->{CV_ID});
  $cvterm_id{first_name}    = check_cvterm('first_name',   $data_info_ref->{CV_ID});
  $cvterm_id{last_name}    = check_cvterm('last_name',    $data_info_ref->{CV_ID});
  $cvterm_id{email}      = check_cvterm('email',        $data_info_ref->{CV_ID});
  $cvterm_id{address}      = check_cvterm('address',      $data_info_ref->{CV_ID});
  $cvterm_id{phone}      = check_cvterm('phone',        $data_info_ref->{CV_ID});
  $cvterm_id{title}      = check_cvterm('title',        $data_info_ref->{CV_ID});
  $cvterm_id{name_code}    = check_cvterm('name_code',    $data_info_ref->{CV_ID});
  $cvterm_id{keywords}    = check_cvterm('keywords',     $data_info_ref->{CV_ID});
  $cvterm_id{alias}      = check_cvterm('alias',        $data_info_ref->{CV_ID});
  $cvterm_id{fax}        = check_cvterm('fax',          $data_info_ref->{CV_ID});
  $cvterm_id{country}      = check_cvterm('country',      $data_info_ref->{CV_ID});
  $cvterm_id{source}      = check_cvterm('source',       $data_info_ref->{CV_ID});
  $cvterm_id{last_update}    = check_cvterm('last_update',  $data_info_ref->{CV_ID});
  $cvterm_id{comments}    = check_cvterm('comments',     $data_info_ref->{CV_ID});
  $cvterm_id{url}        = check_cvterm('url',          $data_info_ref->{CV_ID});
  $error=  check_cvterm_id(\%cvterm_id);
  if ($error) {
    println("\n\t[$module_ref->{SHEET}] Abort: cvterm_id missing : $error\n\n",'SE');
    return;
  }
  
  # insert data
  foreach my $ctr (sort { $a <=> $b } keys %{$excel_ref}) {
    println(sprintf("\n$module_ref->{SHEET} [ROW : %d]\n",$ctr+2),'WE');
    
    # Check data
    if ($excel_ref->{$ctr}{type} eq 'person') {
      if (!($excel_ref->{$ctr}{first_name} && $excel_ref->{$ctr}{last_name})) {
        println("\n\t[$module_ref->{SHEET}] Abort: first_name and last_name must be not empty ($excel_ref->{$ctr}{name})",'SE');
        exit;
      }
    }
    
    # ------------------------------------------- #
    # insert into contact tables
    # ------------------------------------------- #
    # contact_name
    my ($contact_id, $flag_dup) = insert_into_contact($cvterm_id{$excel_ref->{$ctr}{type}}, $excel_ref->{$ctr}{name}, $excel_ref->{$ctr}{reasearch_interest});
    
    # ------------------------------------------- #
    # insert into contactprop tables
    # ------------------------------------------- #
    # institution
    insert_into_contactprop($contact_id, $cvterm_id{institution}, $excel_ref->{$ctr}{institution}) if ($excel_ref->{$ctr}{institution});
    # lab
    insert_into_contactprop($contact_id, $cvterm_id{lab}, $excel_ref->{$ctr}{lab}) if ($excel_ref->{$ctr}{lab});
    # first_name
    insert_into_contactprop($contact_id, $cvterm_id{first_name}, $excel_ref->{$ctr}{first_name}) if ($excel_ref->{$ctr}{first_name});
    # last_name
    insert_into_contactprop($contact_id, $cvterm_id{last_name}, $excel_ref->{$ctr}{last_name}) if ($excel_ref->{$ctr}{last_name});
    # address
    insert_into_contactprop($contact_id, $cvterm_id{address}, $excel_ref->{$ctr}{address}) if ($excel_ref->{$ctr}{address});
    # email
    insert_into_contactprop($contact_id, $cvterm_id{email}, $excel_ref->{$ctr}{email}) if ($excel_ref->{$ctr}{email});
    # phone
    insert_into_contactprop($contact_id, $cvterm_id{phone}, $excel_ref->{$ctr}{phone}) if ($excel_ref->{$ctr}{phone});
    # title
    insert_into_contactprop($contact_id, $cvterm_id{title}, $excel_ref->{$ctr}{title}) if ($excel_ref->{$ctr}{title});
    # fax
    insert_into_contactprop($contact_id, $cvterm_id{fax}, $excel_ref->{$ctr}{fax}) if ($excel_ref->{$ctr}{fax});
    # country
    insert_into_contactprop($contact_id, $cvterm_id{country}, $excel_ref->{$ctr}{country}) if ($excel_ref->{$ctr}{country});
    # source
    insert_into_contactprop($contact_id, $cvterm_id{source}, $excel_ref->{$ctr}{source}) if ($excel_ref->{$ctr}{source});
    # last_update
    insert_into_contactprop($contact_id, $cvterm_id{last_update}, $excel_ref->{$ctr}{last_update}) if ($excel_ref->{$ctr}{last_update});
    # url
    insert_into_contactprop($contact_id, $cvterm_id{url}, $excel_ref->{$ctr}{url}) if ($excel_ref->{$ctr}{url});
    # comments
    insert_into_contactprop($contact_id, $cvterm_id{comments}, $excel_ref->{$ctr}{comments}) if ($excel_ref->{$ctr}{comments});
    insert_into_contactprop($contact_id, $cvterm_id{comments}, $excel_ref->{$ctr}{comment}) if ($excel_ref->{$ctr}{comment});
    
    # name_code
    if ($excel_ref->{$ctr}{name_code}) {
      my $name_code = $data_info_ref->{S_CV_NAME}.'_'.$excel_ref->{$ctr}{name_code};
      insert_into_contactprop($contact_id, $cvterm_id{name_code}, $name_code);
      
      # save name code in hash
      $name_code_ref->{$name_code} = $contact_id;
    }
    
    # alias
    my @aliases= split(/[,;]/, $excel_ref->{$ctr}{alias});
    my $rank= 0;
    foreach my $alias (@aliases) {
      insert_into_contactprop($contact_id, $cvterm_id{alias}, $pg_db->trim_quote($alias), $rank++);
    }
    
    # keywords
    my @keywords= split(/[;,]/, $excel_ref->{$ctr}{keywords});
    $rank= 0;
    foreach my $keyword (@keywords) {
      insert_into_contactprop($contact_id, $cvterm_id{keywords}, $pg_db->trim_quote($keyword), $rank++);
      last if ($rank > 4);
    }
  }
  module_post_process($module_ref->{MODULE}, $num_record_ref);
=cut
}#process_contact
1;
__END__